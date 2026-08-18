import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;

import '../../config/api_config.dart';
import '../../config/auth_config.dart';
import 'pkce.dart';

/// 사용자가 로그인 중 브라우저/Custom Tab을 취소했을 때만 던져지는 예외 — 호출부(UI)가 이걸
/// 네트워크 오류 등 진짜 실패와 구분해서 조용히 처리(에러 스낵바 없이 그냥 중단)할 수 있게 함.
class AuthCancelledException implements Exception {
  const AuthCancelledException();
}

/// 6단계 Phase 2 → Phase 3(flutter_web_auth_2 마이그레이션) — 로그인 세션의 단일 진실 공급원.
/// `main.dart`에서 `ChangeNotifierProvider`로 앱 전역에 노출(Document/temp.md "전역 상태 관리
/// 방식" 갈림길, 옵션 B 채택).
///
/// access token은 메모리에만 유지하고, refresh token만 `flutter_secure_storage`
/// (Keychain/Keystore)에 영구 저장 — 앱 재시작 시 [tryRestoreSession]으로 조용히 재로그인 시도.
/// 토큰 갱신은 반응형(401 받으면 그때 [refreshOnUnauthorized] 호출) —
/// `Document/temp.md` "access token 갱신 전략" 갈림길 기록 참고.
///
/// PKCE 생성 → 브라우저 열기(`flutter_web_auth_2`) → 코드 받기 → `/oauth2/token` 코드 교환은
/// 전부 수동 HTTP로 직접 구현 — `flutter_appauth`가 내부적으로 해주던 PKCE 생성, state/nonce
/// 검증, id_token claim 검증도 전부 여기서 직접 수행함(Document/temp.md Phase D 참고).
class AuthSession extends ChangeNotifier {
  AuthSession({http.Client? httpClient, FlutterSecureStorage? secureStorage})
    : _httpClient = httpClient ?? http.Client(),
      _secureStorage = secureStorage ?? const FlutterSecureStorage();

  static const _refreshTokenStorageKey = 'as_refresh_token';

  final http.Client _httpClient;
  final FlutterSecureStorage _secureStorage;

  String? _accessToken;
  String? _refreshToken;
  String? _idToken;

  // 로그인 전 걸어놓은 여러 API 호출이 동시에 401을 받아 각자 refresh를 시도하면, AS가 refresh
  // token을 회전(rotate)시키는 경우 먼저 끝난 쪽이 갱신한 토큰을 나중에 끝난 쪽이 무효한 옛
  // refresh token으로 덮어써서 invalid_grant를 받는 경합이 생길 수 있음 — 진행 중인 refresh를
  // 재사용해서 이를 막음.
  Future<bool>? _pendingRefresh;

  // logout()마다 1씩 증가 — 진행 중이던 refresh가 그 이후에 응답을 받으면(예: 느린 네트워크 중
  // 사용자가 로그아웃을 누름) 이미 낡은 시도이므로 결과를 버리고 방금 지운 세션을 되살리지 않게
  // 하는 용도.
  int _sessionEpoch = 0;

  // login()의 실제 겹침 방지 가드 — AccountButton의 `_busy`는 위젯 로컬 state라 위젯이
  // 리빌드/재생성되면 초기화돼버려서, 이전 login()이 AuthSession(싱글턴)에서 여전히 진행 중인데도
  // 버튼이 다시 눌릴 수 있음. flutter_appauth 시절엔 이게 AppAuth-Android의 state 소실 버그와
  // 맞물려 실제 장애를 일으켰는데, flutter_web_auth_2로 교체하면서 그 근본 원인 자체는 없어짐 —
  // 이제는 순수하게 "동시에 두 번 로그인 시도" 방지를 위한 방어적 가드.
  bool _isAuthenticating = false;
  bool get isAuthenticating => _isAuthenticating;

  bool get isLoggedIn => _accessToken != null;
  String? get accessToken => _accessToken;

  Uri get _authorizeEndpoint =>
      Uri.parse('${AuthConfig.requireIssuer}/oauth2/authorize');
  Uri get _tokenEndpoint =>
      Uri.parse('${AuthConfig.requireIssuer}/oauth2/token');
  Uri get _endSessionEndpoint =>
      Uri.parse('${AuthConfig.requireIssuer}/connect/logout');

  /// 앱 시작 시 1회 호출 — 저장된 refresh token이 있으면 조용히 재로그인 시도.
  /// [refreshOnUnauthorized]를 통해서 호출 — 이 시도가 끝나기 전에 사용자가 로그인 버튼을
  /// 누르는 등 다른 경로로 refresh가 겹치면, `_refresh()`를 직접 불렀을 때 같은 refresh
  /// token으로 두 요청이 동시에 나가서(AS가 회전형이라 하나는 invalid_grant로 실패) 방금 성공한
  /// 세션이 지워질 수 있음 — dedup을 반드시 거쳐야 함.
  Future<void> tryRestoreSession() async {
    final storedRefreshToken = await _secureStorage.read(
      key: _refreshTokenStorageKey,
    );
    if (storedRefreshToken == null) return;
    _refreshToken = storedRefreshToken;
    await refreshOnUnauthorized();
  }

  /// 로그인 진입점. refresh token이 남아있으면(예: [tryRestoreSession]이 신호 약함 등 일시적
  /// 오류로 실패했던 경우 — [_refresh]는 이런 경우 token을 지우지 않고 그대로 둠) 먼저 그걸로
  /// 조용히 재시도하고, 성공하면 브라우저를 띄우지 않고 바로 끝남. refresh token이 없거나(진짜
  /// 로그아웃 상태) 그 재시도마저 실패하면 시스템 브라우저(Custom Tabs/ASWebAuthenticationSession)로
  /// 로그인 화면을 띄움.
  ///
  /// 사용자가 브라우저 로그인을 취소하면 [AuthCancelledException]을 던짐(호출부가 에러가 아닌
  /// 정상 취소로 구분해서 처리). 그 외 실패(state/nonce/id_token 검증 실패, 네트워크/토큰 교환
  /// 오류)는 그대로 예외가 전파됨 — 어느 경로로 끝나든 [_isAuthenticating] 가드는 아래 finally에서
  /// 예외 없이 해제됨.
  Future<void> login() async {
    if (_isAuthenticating) return;
    _isAuthenticating = true;
    notifyListeners();
    try {
      if (_refreshToken != null && await refreshOnUnauthorized()) {
        return;
      }

      final codeVerifier = Pkce.generateCodeVerifier();
      final codeChallenge = Pkce.generateCodeChallenge(codeVerifier);
      final state = Pkce.generateState();
      final nonce = Pkce.generateNonce();

      final authorizeUrl = _authorizeEndpoint.replace(
        queryParameters: {
          'response_type': 'code',
          'client_id': AuthConfig.clientId,
          'redirect_uri': AuthConfig.redirectUri,
          'scope': AuthConfig.scopes.join(' '),
          'state': state,
          'nonce': nonce,
          'code_challenge': codeChallenge,
          'code_challenge_method': 'S256',
        },
      );

      final String callbackUrl;
      try {
        callbackUrl = await FlutterWebAuth2.authenticate(
          url: authorizeUrl.toString(),
          callbackUrlScheme: AuthConfig.redirectScheme,
        );
      } on PlatformException catch (e) {
        if (e.code == 'CANCELED') throw const AuthCancelledException();
        rethrow;
      }

      final callbackParams = Uri.parse(callbackUrl).queryParameters;
      if (callbackParams['state'] != state) {
        throw StateError('Login callback state does not match the request — possible CSRF');
      }
      final code = callbackParams['code'];
      if (code == null) {
        throw StateError('Login callback is missing the authorization code: $callbackUrl');
      }

      final tokenResponse = await _httpClient
          .post(
            _tokenEndpoint,
            body: {
              'grant_type': 'authorization_code',
              'code': code,
              'redirect_uri': AuthConfig.redirectUri,
              'client_id': AuthConfig.clientId,
              'code_verifier': codeVerifier,
            },
          )
          .timeout(ApiConfig.requestTimeout);
      if (tokenResponse.statusCode != 200) {
        throw StateError(
          'Token exchange failed (HTTP ${tokenResponse.statusCode}): ${tokenResponse.body}',
        );
      }

      final tokens = jsonDecode(tokenResponse.body) as Map<String, dynamic>;
      final idToken = tokens['id_token'] as String?;
      if (idToken != null) {
        _verifyIdToken(idToken, expectedNonce: nonce);
      }

      _applyTokenResponse(
        accessToken: tokens['access_token'] as String,
        refreshToken: tokens['refresh_token'] as String?,
        idToken: idToken,
      );
      await _persistRefreshToken();
      // 방금 브라우저 PKCE 플로우를 새로 완료한 시점(=이 계정이 이 기기에서 방금 로그인함)에서만
      // 부름 — _refresh()(조용한 토큰 갱신, 같은 기기가 세션을 이어가는 것)에서는 절대 안 부름.
      // 실패해도(네트워크 등) 로그인 자체는 막지 않음 — "1기기 제한"은 게임 밸런스용 정책이지
      // 로그인 성패를 좌우할 보안 경계가 아니므로.
      unawaited(_revokeOtherDeviceSessions());
    } finally {
      _isAuthenticating = false;
      notifyListeners();
    }
  }

  /// 같은 계정 · 같은 client(TourMon-mobile)로 로그인된 다른 기기의 세션을 서버에서 폐기 —
  /// `SingleDeviceSessionController`(Auth_Server) 참고. Refresh token만 폐기되므로, 그 기기가 이미
  /// 들고 있는 access token은 자기 만료 시각(최대 45분)까지는 계속 유효함 — 즉시 차단은 아님.
  Future<void> _revokeOtherDeviceSessions() async {
    try {
      final res = await _httpClient
          .delete(
            Uri.parse('${AuthConfig.requireIssuer}/api/sessions/others'),
            headers: {'Authorization': 'Bearer $_accessToken'},
          )
          .timeout(ApiConfig.requestTimeout);
      if (res.statusCode != 204) {
        developer.log('다른 기기 세션 폐기 실패: HTTP ${res.statusCode}', name: 'AuthSession');
      }
    } catch (e) {
      developer.log('다른 기기 세션 폐기 실패: $e', name: 'AuthSession');
    }
  }

  /// API 클라이언트가 401을 받았을 때 호출 — 갱신 성공 시 true, refresh token도 만료/폐기됐으면
  /// false(호출부가 이어서 [logout] 처리). 이미 진행 중인 갱신이 있으면 그 결과를 그대로 공유.
  Future<bool> refreshOnUnauthorized() =>
      _pendingRefresh ??= _refresh().whenComplete(() => _pendingRefresh = null);

  Future<bool> _refresh() async {
    final refreshToken = _refreshToken;
    if (refreshToken == null) return false;
    // 이 refresh가 네트워크 응답을 기다리는 동안 사용자가 로그아웃을 누르는 등으로 세션이
    // 먼저 바뀌면, 뒤늦게 도착한 결과를 적용해서 방금 지운 세션을 되살리면 안 됨 — 시작 시점의
    // epoch을 기억해뒀다가 응답이 왔을 때 여전히 같은 epoch인지 확인.
    final epoch = _sessionEpoch;
    try {
      final response = await _httpClient
          .post(
            _tokenEndpoint,
            body: {
              'grant_type': 'refresh_token',
              'refresh_token': refreshToken,
              'client_id': AuthConfig.clientId,
            },
          )
          .timeout(ApiConfig.requestTimeout);
      if (epoch != _sessionEpoch) return false;

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200) {
        // AS가 refresh token을 명시적으로 거부한 경우(만료/폐기/회전으로 무효화)에만 세션을 지움.
        // invalid_grant가 아닌 나머지(야외 보행 중 신호 약함 등 일시적 네트워크/서버 오류 —
        // init_plan.md 4-1의 access token TTL 연장 사유와 동일한 문제)는 저장된 refresh token을
        // 그대로 두고 실패만 알림 — 다음 시도(다음 API 호출의 401, 또는 다음 앱 실행의
        // tryRestoreSession)에서 복구 가능.
        if (body['error'] == 'invalid_grant') {
          await logout();
        }
        return false;
      }

      final idToken = body['id_token'] as String?;
      _applyTokenResponse(
        accessToken: body['access_token'] as String,
        refreshToken: body['refresh_token'] as String?,
        idToken: idToken,
      );
      await _persistRefreshToken();
      return true;
    } catch (_) {
      return false;
    }
  }

  void _applyTokenResponse({
    required String accessToken,
    required String? refreshToken,
    required String? idToken,
  }) {
    _accessToken = accessToken;
    // 서버가 새 refresh token을 안 내려주면(rotation 미적용) 기존 값 유지.
    if (refreshToken != null) {
      _refreshToken = refreshToken;
    }
    if (idToken != null) {
      _idToken = idToken;
    }
    notifyListeners();
  }

  Future<void> _persistRefreshToken() async {
    final refreshToken = _refreshToken;
    if (refreshToken == null) return;
    await _secureStorage.write(
      key: _refreshTokenStorageKey,
      value: refreshToken,
    );
  }

  /// 로컬 세션 정리(항상 수행) + AS RP-Initiated Logout(best-effort, `connect/logout`) —
  /// AS `application.yml`의 `TourMon-mobile.post-logout-redirect-uris`가 이 용도로 이미
  /// 등록돼 있음. AS가 응답 없어도(오프라인 등) 로컬 로그아웃 자체는 항상 성공해야 하므로
  /// end session 요청 실패는 무시.
  Future<void> logout() async {
    _sessionEpoch++;
    final idToken = _idToken;
    _accessToken = null;
    _refreshToken = null;
    _idToken = null;
    await _secureStorage.delete(key: _refreshTokenStorageKey);
    notifyListeners();

    if (idToken == null) return;
    try {
      final postLogoutRedirectUri = '${AuthConfig.redirectScheme}:/oauth2logout';
      final logoutUrl = _endSessionEndpoint.replace(
        queryParameters: {
          'id_token_hint': idToken,
          'post_logout_redirect_uri': postLogoutRedirectUri,
        },
      );
      await FlutterWebAuth2.authenticate(
        url: logoutUrl.toString(),
        callbackUrlScheme: AuthConfig.redirectScheme,
      );
    } catch (_) {
      // AS 세션이 로컬에 남아도 다음 로그인 시 계정 선택/재인증 화면이 다시 뜨는 정도의
      // 불편일 뿐 — 로컬 로그아웃(위에서 이미 완료)이 무너지면 안 되므로 여기서 흡수.
      // (사용자가 로그아웃 확인 브라우저 화면을 그냥 닫는 경우도 이 catch로 흡수됨)
    }
  }
}

/// id_token(JWT)의 두 번째 세그먼트(payload)를 디코딩. `dart:convert`의 `base64Url.decode()`는
/// 문자열 길이가 4의 배수가 아니면(JWT는 보통 `=` 패딩이 제거된 채로 옴) `FormatException`을
/// 던지므로, `base64Url.normalize()`로 먼저 패딩을 보정함(Document/temp.md Phase D 참고).
Map<String, dynamic> _decodeJwtPayload(String jwt) {
  final segments = jwt.split('.');
  if (segments.length != 3) {
    throw const FormatException('Malformed id_token (not a 3-segment JWT)');
  }
  final normalized = base64Url.normalize(segments[1]);
  final payloadJson = utf8.decode(base64Url.decode(normalized));
  return jsonDecode(payloadJson) as Map<String, dynamic>;
}

/// `flutter_appauth`가 내부적으로 해주던 id_token claim 검증을 직접 구현.
/// nonce(replay 방지), iss(발급자가 우리 AS 맞는지), aud(우리 clientId 맞는지),
/// exp(만료 안 됐는지) — 서명 검증은 back-channel(HTTPS 직접 POST)로 받은 응답이라 생략.
void _verifyIdToken(String idToken, {required String expectedNonce}) {
  final claims = _decodeJwtPayload(idToken);

  if (claims['nonce'] != expectedNonce) {
    throw StateError('id_token nonce mismatch — possible replay attack');
  }

  if (claims['iss'] != AuthConfig.requireIssuer) {
    throw StateError(
      'id_token iss mismatch — expected: ${AuthConfig.requireIssuer}, actual: ${claims['iss']}',
    );
  }

  final audience = claims['aud'];
  final audienceMatches = audience == AuthConfig.clientId ||
      (audience is List && audience.contains(AuthConfig.clientId));
  if (!audienceMatches) {
    throw StateError('id_token aud mismatch — clientId(${AuthConfig.clientId}) not in aud');
  }

  final expSeconds = claims['exp'] as int?;
  if (expSeconds == null) {
    throw StateError('id_token is missing the exp claim');
  }
  final expiresAt = DateTime.fromMillisecondsSinceEpoch(
    expSeconds * 1000,
    isUtc: true,
  );
  if (DateTime.now().toUtc().isAfter(expiresAt)) {
    throw StateError('id_token has expired');
  }
}
