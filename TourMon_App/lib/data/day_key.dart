import '../config/game_config.dart';

/// "오늘"의 경계는 자정이 아니라 KST 새벽 4시(GameConfig.dailyResetHourKst) — 알 쿨타임 판정
/// (`EggRepository`)과 거리 일별 집계(`DailyDistanceRepository`)가 같은 기준을 써야 게임 내 "오늘"
/// 개념이 서로 어긋나지 않음. 원래 `EggRepository._resetDayKey`에 private로만 있던 걸 공용으로
/// 추출(Document/temp.md 참고).
///
/// (거리 측정 이중화 전에는 Health Connect 구간을 날짜별로 재분배하는 `splitByResetDay`/
/// `resetDayStart` 등도 여기 있었으나, GPS 델타·pedometer diff는 적립 시점에 이 함수로 바로 오늘
/// 키를 구하므로 제거됨.)
String resetDayKey(DateTime dt) {
  final shifted = dt.subtract(Duration(hours: GameConfig.dailyResetHourKst));
  return shifted.toIso8601String().split('T').first;
}
