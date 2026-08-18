import 'package:flutter/material.dart';

/// `MaterialApp.scaffoldMessengerKey`에 연결하는 앱 전역 스낵바 창구. 화면(마이페이지 등)이
/// 결과를 기다리는 동안 사용자가 뒤로 가서 그 화면이 dispose돼도, 이 키로 띄우는 스낵바는
/// 앱 루트에 붙어있어서 그대로 표시됨 — `ScaffoldMessenger.of(context)`(화면 로컬)로는 dispose된
/// 화면에서 안전하게 못 띄움. 오래 걸리는 백그라운드 작업(관광지 데이터 재동기화 등)의 결과처럼,
/// "그 작업을 시작한 화면이 아직 떠 있다는 보장이 없는" 메시지에만 이 키를 쓰고, 그 외 즉각적인
/// 화면 내 피드백(닉네임 저장 실패 등)은 기존처럼 `ScaffoldMessenger.of(context)`를 그대로 쓴다.
final rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
