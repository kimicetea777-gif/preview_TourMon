/// 개발용 디버그 오버레이(줌 레벨 표시, 거리 주입 버튼 등) — 하드코딩 금지 원칙에 따라
/// 이 파일 한 곳에 모음. 실행 시점에 --dart-define=DEBUG_MODE=true 로 켬(기본 false라
/// 프로덕션 빌드 명령어에 이 플래그를 안 넣으면 자동으로 꺼짐, 별도 코드 제거 불필요).
class DebugConfig {
  DebugConfig._();

  static const bool isEnabled = bool.fromEnvironment('DEBUG_MODE');
}
