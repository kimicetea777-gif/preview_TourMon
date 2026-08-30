import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // Docker 배포용 — .next/standalone에 실행에 필요한 node_modules까지 트리쉐이킹해서 담아줘서
  // 프로덕션 이미지에 devDependencies/전체 node_modules를 복사할 필요가 없어짐 (Document/how_to_build.md 참고)
  output: "standalone",
};

export default nextConfig;
