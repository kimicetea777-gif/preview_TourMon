// monster_species.image_url/animation_url이 R2에 실제로 올라간 객체 키와 반드시 같은 규칙을
// 써야 한다(scripts/monster-art-upload.ts가 그 키로 업로드함) — dexNumber 하나로 두 값을 계산하는
// 규칙을 여기 한 곳에만 두고 scripts/seed.ts와 어드민 몬스터 추가(src/app/api/admin/monsters)가
// 같이 가져다 쓴다. 전에는 이 문자열이 seed.ts에만 있었고 몬스터-아트 업로드 스크립트와는 주석으로만
// "규칙을 맞출 것"이라고 당부하는 관계였음 — 실제로 값을 공유하게 바꿔서 그 위험을 없앴다.
export const ASSET_CDN_BASE_URL = "https://assets.kimicetea.app";

export function monsterArtUrls(dexNumber: number): { imageUrl: string; animationUrl: string } {
  const padded = String(dexNumber).padStart(3, "0");
  return {
    imageUrl: `${ASSET_CDN_BASE_URL}/monsters/img/${padded}.webp`,
    animationUrl: `${ASSET_CDN_BASE_URL}/monsters/ani/${padded}.webp`,
  };
}
