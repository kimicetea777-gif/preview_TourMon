/// Health Connect 전환(Document/temp.md "통합 결정") — DB/로컬은 meters(int)로 저장하고, 화면
/// 표시에서만 km로 변환. 소수점 1자리로 통일(진행바/알 정보/지도 패널 공용).
String formatKm(num meters) => (meters / 1000).toStringAsFixed(1);
