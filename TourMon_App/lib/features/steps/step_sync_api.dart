import '../auth/authorized_api_client.dart';

/// 6단계 Phase 5 — 걸음수 서버 동기화 (init_plan.md 4-3 "걸음수 서버 동기화" 🔄🔐).
/// 서버 응답의 갱신된 파트너 알 목록은 여기서 굳이 안 씀 — 로컬 sqlite가 이미 진행도 표시의
/// 진짜 기준(init_plan.md: "로컬 SQLite가 항상 진짜 값을 보관")이라 UI 갱신에 필요 없음.
class StepSyncApi {
  const StepSyncApi(this._client);

  final AuthorizedApiClient _client;

  Future<void> sync(int deltaSteps) async {
    final res = await _client.post('/api/steps/sync', body: {'deltaSteps': deltaSteps});
    if (res.statusCode != 200) {
      throw Exception('Step sync failed: ${res.statusCode}');
    }
  }
}
