import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/api_config.dart';
import 'auth_session.dart';

/// 6단계 Phase 2 — 로그인된 사용자의 API 호출 공용 헬퍼. Authorization 헤더를 자동으로 붙이고,
/// 401을 받으면 반응형으로 [AuthSession]을 갱신한 뒤 1회 재시도(Document/temp.md "access token
/// 갱신 전략" 갈림길 기록). 지금은 `/api/auth/*`에서만 쓰지만, Phase 3에서 회원 전용 라우트가
/// 늘어나면(eggs/acquire 등) 그대로 재사용할 수 있게 범용으로 만들어둠.
class AuthorizedApiClient {
  // 7단계 — locale은 옵션(null이면 쿼리파라미터를 안 붙이고 서버 기본값(ko)에 맡김). 번역된
  // 응답이 필요 없는 호출부(예: 걸음수 동기화)는 안 넘겨도 되고, 넘기면 이 클라이언트로 나가는
  // 모든 요청에 `?locale=`이 중앙으로 붙음(Document/temp.md Phase C — 호출부 개별 수정 불필요).
  AuthorizedApiClient(this._session, {this.locale});

  final AuthSession _session;
  final String? locale;

  Future<http.Response> get(String path) => _send('GET', path);

  Future<http.Response> post(String path, {Object? body}) =>
      _send('POST', path, body: body);

  Future<http.Response> _send(String method, String path, {Object? body}) async {
    var uri = Uri.parse('${ApiConfig.requireBaseUrl}$path');
    if (locale != null) {
      uri = uri.replace(queryParameters: {...uri.queryParameters, 'locale': locale});
    }
    var res = await _request(method, uri, body);

    if (res.statusCode == 401 && await _session.refreshOnUnauthorized()) {
      res = await _request(method, uri, body);
    }
    return res;
  }

  Future<http.Response> _request(String method, Uri uri, Object? body) {
    final headers = {
      'Content-Type': 'application/json',
      if (_session.accessToken != null)
        'Authorization': 'Bearer ${_session.accessToken}',
    };
    switch (method) {
      case 'GET':
        return http.get(uri, headers: headers).timeout(ApiConfig.requestTimeout);
      case 'POST':
        return http
            .post(uri, headers: headers, body: body != null ? jsonEncode(body) : null)
            .timeout(ApiConfig.requestTimeout);
      default:
        throw UnsupportedError('Unsupported method: $method');
    }
  }
}

class UserProfile {
  final String id;
  final String nickname;

  UserProfile({required this.id, required this.nickname});

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      nickname: json['nickname'] as String,
    );
  }
}

/// Phase 1의 `GET /api/auth/me` / `POST /api/auth/profile` 라우트 클라이언트.
class AuthApi {
  const AuthApi(this._client);

  final AuthorizedApiClient _client;

  /// 아직 온보딩(닉네임 입력) 전이면 null(서버가 404 `needsOnboarding` 반환).
  Future<UserProfile?> fetchProfile() async {
    final res = await _client.get('/api/auth/me');
    if (res.statusCode == 404) return null;
    if (res.statusCode != 200) {
      throw Exception('Failed to fetch profile: ${res.statusCode}');
    }
    return UserProfile.fromJson(
      jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>,
    );
  }

  Future<UserProfile> upsertProfile(String nickname) async {
    final res = await _client.post(
      '/api/auth/profile',
      body: {'nickname': nickname},
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to save profile: ${res.statusCode}');
    }
    return UserProfile.fromJson(
      jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>,
    );
  }
}
