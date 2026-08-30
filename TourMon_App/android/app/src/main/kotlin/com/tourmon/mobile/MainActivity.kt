package com.tourmon.mobile

import io.flutter.embedding.android.FlutterFragmentActivity

// `health` 패키지(Health Connect 전환, Document/temp.md "통합 결정")가 권한 요청 시
// `(activity as androidx.activity.ComponentActivity).registerForActivityResult(...)`를 호출함 —
// 기존 FlutterActivity는 androidx.activity.ComponentActivity를 상속하지 않아서
// ClassCastException으로 플러그인 등록 자체가 실패함(health 패키지 예제도 이 이유로
// FlutterFragmentActivity 사용, 2026-08-19 에뮬레이터에서 직접 확인). FlutterFragmentActivity는
// androidx.fragment.app.FragmentActivity → ComponentActivity를 상속해서 이 문제가 없고, Flutter가
// 공식적으로 문서화한 안전한 대체제(다른 플러그인과의 호환성 문제 없음).
class MainActivity : FlutterFragmentActivity()
