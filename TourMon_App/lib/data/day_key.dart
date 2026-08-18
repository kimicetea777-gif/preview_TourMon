import '../config/game_config.dart';

/// "오늘"의 경계는 자정이 아니라 KST 새벽 4시(GameConfig.dailyResetHourKst) — 알 쿨타임 판정
/// (`EggRepository`)과 걸음수 일별 집계(`DailyStepsRepository`)가 같은 기준을 써야 게임 내 "오늘"
/// 개념이 서로 어긋나지 않음. 원래 `EggRepository._resetDayKey`에 private로만 있던 걸 공용으로
/// 추출(Document/temp.md 참고).
String resetDayKey(DateTime dt) {
  final shifted = dt.subtract(Duration(hours: GameConfig.dailyResetHourKst));
  return shifted.toIso8601String().split('T').first;
}
