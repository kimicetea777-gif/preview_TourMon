// ignore_for_file: avoid_print — CLI 스크립트라 print가 맞는 출력 수단.
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:tourmon_app/features/auth/pkce.dart';

/// Document/temp.md Phase F 사전 점검용 데스크탑 스크립트 — `auth_session.dart`의 `login()`이
/// 하는 일(PKCE 생성 → authorize → 토큰 교환 → id_token 검증)을 폰 없이 먼저 확인한다.
///
/// **검증 못 하는 것**: `flutter_web_auth_2`가 안드로이드에서 Custom Tab을 열고
/// `CallbackActivity`로 콜백을 받는 것 자체 — 이건 안드로이드 OS 레벨 동작이라 이 스크립트로는
/// 확인 불가. 반드시 별도로 에뮬레이터/실기기에서 앱을 직접 띄워 확인할 것.
///
/// 실행:
///   dart run tool/test_oauth_flow.dart --issuer=http://localhost:9001
void main(List<String> args) async {
  final issuer = _argValue(args, '--issuer') ?? 'http://localhost:9001';
  const clientId = 'TourMon-mobile';
  const redirectUri = 'com.tourmon.app:/oauth2redirect';
  const scopes = ['openid', 'profile'];

  final codeVerifier = Pkce.generateCodeVerifier();
  final codeChallenge = Pkce.generateCodeChallenge(codeVerifier);
  final state = Pkce.generateState();
  final nonce = Pkce.generateNonce();

  final authorizeUrl = Uri.parse('$issuer/oauth2/authorize').replace(
    queryParameters: {
      'response_type': 'code',
      'client_id': clientId,
      'redirect_uri': redirectUri,
      'scope': scopes.join(' '),
      'state': state,
      'nonce': nonce,
      'code_challenge': codeChallenge,
      'code_challenge_method': 'S256',
    },
  );

  print('1) 아래 URL을 데스크탑 브라우저에서 열고 로그인하세요:\n');
  print(authorizeUrl);
  print(
    '\n2) 로그인(+ 첫 이용이면 멤버십 동의 화면까지) 완료하면 브라우저가 '
    '"com.tourmon.app:/oauth2redirect?code=...&state=..."로 이동을 "시도"합니다 — '
    '커스텀 스킴이라 데스크탑 브라우저에선 연결 자체는 실패하는 게 정상입니다. '
    '그 상태에서 주소창에 찍힌 전체 URL을 그대로 복사해서 아래에 붙여넣으세요:',
  );

  final callbackInput = stdin.readLineSync()?.trim();
  if (callbackInput == null || callbackInput.isEmpty) {
    stderr.writeln('입력이 없어 종료합니다.');
    exit(1);
  }

  final callbackUri = Uri.parse(callbackInput);
  final returnedState = callbackUri.queryParameters['state'];
  final code = callbackUri.queryParameters['code'];

  if (returnedState != state) {
    stderr.writeln('❌ state 불일치 — 보낸 값: $state / 받은 값: $returnedState');
    exit(1);
  }
  if (code == null) {
    stderr.writeln('❌ code가 콜백 URL에 없음: $callbackInput');
    exit(1);
  }
  print('✅ state 일치 확인');

  print('\n3) 토큰 교환 중...');
  final tokenResponse = await http.post(
    Uri.parse('$issuer/oauth2/token'),
    body: {
      'grant_type': 'authorization_code',
      'code': code,
      'redirect_uri': redirectUri,
      'client_id': clientId,
      'code_verifier': codeVerifier,
    },
  );

  if (tokenResponse.statusCode != 200) {
    stderr.writeln(
      '❌ 토큰 교환 실패 (HTTP ${tokenResponse.statusCode}): ${tokenResponse.body}',
    );
    exit(1);
  }
  print('✅ 토큰 교환 성공 (HTTP 200)');

  final tokens = jsonDecode(tokenResponse.body) as Map<String, dynamic>;
  print('   access_token: ${_truncate(tokens['access_token'] as String?)}');
  print('   refresh_token: ${_truncate(tokens['refresh_token'] as String?)}');

  final idToken = tokens['id_token'] as String?;
  if (idToken == null) {
    print('⚠️  id_token이 응답에 없음 — scope에 openid가 빠졌는지 확인');
    return;
  }

  print('\n4) id_token 검증 중...');
  final claims = _decodeJwtPayload(idToken);
  print('   claims: $claims');

  final errors = <String>[];
  if (claims['nonce'] != nonce) {
    errors.add('nonce 불일치 (보낸 값: $nonce / 받은 값: ${claims['nonce']})');
  }
  if (claims['iss'] != issuer) {
    errors.add('iss 불일치 (예상: $issuer / 받은 값: ${claims['iss']})');
  }
  final audience = claims['aud'];
  final audienceMatches =
      audience == clientId || (audience is List && audience.contains(clientId));
  if (!audienceMatches) {
    errors.add('aud 불일치 (clientId $clientId가 aud에 없음: $audience)');
  }
  final expSeconds = claims['exp'] as int?;
  if (expSeconds == null) {
    errors.add('exp claim 없음');
  } else {
    final expiresAt = DateTime.fromMillisecondsSinceEpoch(
      expSeconds * 1000,
      isUtc: true,
    );
    if (DateTime.now().toUtc().isAfter(expiresAt)) {
      errors.add('id_token 만료됨 (exp: $expiresAt)');
    }
  }

  if (errors.isEmpty) {
    print('✅ id_token 검증 전부 통과 (nonce/iss/aud/exp)');
  } else {
    print('❌ id_token 검증 실패:');
    for (final e in errors) {
      print('   - $e');
    }
    exit(1);
  }

  print('\n🎉 PKCE 생성 → authorize → 토큰 교환 → id_token 검증까지 전부 정상 동작 확인.');
  print('   (flutter_web_auth_2의 안드로이드 콜백 수신 자체는 별도로 에뮬레이터/실기기에서 확인할 것)');
}

String? _argValue(List<String> args, String key) {
  for (final arg in args) {
    if (arg.startsWith('$key=')) return arg.substring(key.length + 1);
  }
  return null;
}

String _truncate(String? value) {
  if (value == null) return 'null';
  return value.length > 24 ? '${value.substring(0, 24)}...' : value;
}

Map<String, dynamic> _decodeJwtPayload(String jwt) {
  final segments = jwt.split('.');
  if (segments.length != 3) {
    throw const FormatException('id_token 형식이 올바르지 않음 (JWT 3-세그먼트 아님)');
  }
  final normalized = base64Url.normalize(segments[1]);
  final payloadJson = utf8.decode(base64Url.decode(normalized));
  return jsonDecode(payloadJson) as Map<String, dynamic>;
}
