import '../config/game_config.dart';

/// "오늘"의 경계는 자정이 아니라 KST 새벽 4시(GameConfig.dailyResetHourKst) — 알 쿨타임 판정
/// (`EggRepository`)과 거리 일별 집계(`DailyDistanceRepository`)가 같은 기준을 써야 게임 내 "오늘"
/// 개념이 서로 어긋나지 않음. 원래 `EggRepository._resetDayKey`에 private로만 있던 걸 공용으로
/// 추출(Document/temp.md 참고).
String resetDayKey(DateTime dt) {
  final shifted = dt.subtract(Duration(hours: GameConfig.dailyResetHourKst));
  return shifted.toIso8601String().split('T').first;
}

/// [resetDayKey]가 만든 "YYYY-MM-DD" 문자열을 그 게임 날짜의 시작 시각(리셋 경계, KST 4시)으로
/// 되돌림 — [dayKey]는 이미 리셋 경계로 shift된 도메인의 날짜라 다시 shift할 필요 없이 리셋
/// 시각만 더하면 됨(주의: `DateTime.parse(dayKey)`에 곧바로 [resetDayStart]를 적용하면 그 자정
/// 시각 자체가 하루 전 게임 날짜에 속해버려 하루 밀리는 계산이 됨 — 반드시 이 함수를 거칠 것).
DateTime resetDayStartFromKey(String dayKey) {
  return DateTime.parse(dayKey).add(Duration(hours: GameConfig.dailyResetHourKst));
}

/// [reference]가 속한 게임 날짜의 시작 시각(DateTime) — [resetDayKey]로 날짜를 구한 뒤
/// [resetDayStartFromKey]로 되돌리는 것과 동일. `DistanceTrackerService`가 "오늘 전체" 구간을
/// 조회할 때 시작 시각을 구하는 용도.
DateTime resetDayStart(DateTime reference) => resetDayStartFromKey(resetDayKey(reference));

/// [start, end) 구간의 [value]를 KST 리셋 시각 경계로 나눠, 구간이 리셋 시각을 넘나들 때 걸친
/// 날짜마다 겹치는 시간 비율만큼 배분 — Health Connect 구간이 며칠치를 한 번에 몰아서 줄 때
/// "동기화한 날"에 전부 잡히지 않도록 함(Document/plan/later.md "구현 시 필요한 것" 절 참고).
List<MapEntry<String, double>> splitByResetDay(DateTime start, DateTime end, double value) {
  if (!end.isAfter(start) || value == 0) return const [];
  final totalMicros = end.difference(start).inMicroseconds;

  final shiftedStart = start.subtract(Duration(hours: GameConfig.dailyResetHourKst));
  final shiftedEnd = end.subtract(Duration(hours: GameConfig.dailyResetHourKst));

  final result = <MapEntry<String, double>>[];
  var cursor = shiftedStart;
  while (cursor.isBefore(shiftedEnd)) {
    final nextMidnight = DateTime(cursor.year, cursor.month, cursor.day + 1);
    final segmentEnd = nextMidnight.isBefore(shiftedEnd) ? nextMidnight : shiftedEnd;
    final segmentMicros = segmentEnd.difference(cursor).inMicroseconds;
    final dayKey = cursor.toIso8601String().split('T').first;
    result.add(MapEntry(dayKey, value * segmentMicros / totalMicros));
    cursor = segmentEnd;
  }
  return result;
}
