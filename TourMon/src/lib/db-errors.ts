/**
 * Postgres unique_violation(SQLSTATE 23505) 여부.
 *
 * drizzle 0.45는 쿼리 실패를 `DrizzleQueryError`로 감싸고 원본 postgres-js 에러를 `.cause`에
 * 둔다(래핑이 여러 겹일 수 있음). postgres-js 에러는 항상 `.code`에 SQLSTATE 문자열을 담으므로,
 * cause 체인을 몇 겹 벗겨가며 코드만 확인한다(모듈 인스턴스가 갈려도 안전하도록 instanceof 대신
 * 덕 타이핑).
 */
export function isUniqueViolation(err: unknown): boolean {
  let e: unknown = err;
  for (let i = 0; i < 5 && e != null; i++) {
    if (typeof e === "object" && (e as { code?: unknown }).code === "23505") {
      return true;
    }
    e = (e as { cause?: unknown }).cause;
  }
  return false;
}
