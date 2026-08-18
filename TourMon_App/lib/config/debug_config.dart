/// 개발용 디버그 오버레이(줌 레벨 표시, 알 획득 반경 원 등) — 하드코딩 금지 원칙에 따라
/// 이 파일 한 곳에 모음. 실행 시점에 --dart-define=DEBUG_MODE=true 로 켬(기본 false라
/// 프로덕션 빌드 명령어에 이 플래그를 안 넣으면 자동으로 꺼짐, 별도 코드 제거 불필요).
class DebugConfig {
  DebugConfig._();

  static const bool isEnabled = bool.fromEnvironment('DEBUG_MODE');

  /// 서버 EGG_ACQUISITION_RADIUS_METERS(TourMon/src/lib/game-config.ts)와 반드시 같은 값으로
  /// 유지할 것 — 서버 값이 바뀌면 여기도 같이 고쳐야 함. 실제 알 획득 판정은 항상 서버가 하고
  /// (tourism_spot_sheet.dart 주석 참고) 이 값은 순수 디버그 시각화 전용이라, 클라이언트 로직에
  /// "값을 중복 보관하지 않는다" 원칙의 의도적 예외임.
  static const double eggAcquisitionRadiusMeters = 30;
}
