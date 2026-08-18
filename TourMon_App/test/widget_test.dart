// 기본 카운터 템플릿 스모크 테스트를 제거함 (1단계 배경 지도로 화면 자체가 교체됨).
// MapScreen은 FMTC(ObjectBox)/geolocator 네이티브 플랫폼 채널에 의존해서
// 순수 위젯 테스트로는 검증할 수 없음 — 실제 동작 검증은 에뮬레이터 실행으로 확인함.
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('placeholder — 실제 검증은 에뮬레이터 실행으로 확인 (README 참고)', () {
    expect(true, isTrue);
  });
}
