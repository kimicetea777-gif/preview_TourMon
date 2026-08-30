# Next.js standalone 빌드 — Document/how_to_build.md 배포 절차 참고
FROM node:22-alpine AS deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci

FROM node:22-alpine AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
# `next build`가 라우트를 분석하면서 각 API route 모듈을 import하는데, 일부 모듈(src/lib/auth.ts,
# src/db/index.ts, src/lib/deletion-sync/*)이 모듈 최상위에서 process.env를 즉시 읽어 없으면 throw함
# (fail-fast 설계, 하드코딩 금지 원칙의 반대급부). 그래서 실제 값이 아니어도 빌드 타임엔 "존재하기만
#하면" 되는 더미값이 필요 — 이 ENV는 이 builder 스테이지에서만 쓰이고 최종 runner 스테이지로
# 넘어가지 않으므로(별도 FROM), 진짜 시크릿은 여기 안 들어가고 실제 값은 컨테이너 기동 시
# docker-compose.yml의 env_file(.env)로만 주입된다.
ENV DATABASE_URL=postgresql://build:build@localhost:5432/build
ENV AS_ISSUER_URL=http://build-placeholder.invalid
ENV AS_DELETION_SYNC_CLIENT_ID=build-placeholder
ENV AS_DELETION_SYNC_CLIENT_SECRET=build-placeholder
RUN npm run build

FROM node:22-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production
ENV HOSTNAME=0.0.0.0
ENV PORT=3000

COPY --from=builder /app/public ./public
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static

EXPOSE 3000
CMD ["node", "server.js"]
