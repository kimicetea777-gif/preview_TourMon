# 배경 지도 데이터 파이프라인 (1단계)

Protomaps 공개 벡터 PMTiles → 서울+인천 bbox 추출 → tileserver-gl 래스터 렌더링 → PMTiles 패키징 → R2 업로드 → 로컬 서빙까지의 전체 과정. 결정 배경은 `Document/temp_2.md` 참고.

## 사전 준비 (최초 1회)

1. go-pmtiles Windows 바이너리를 `bin/pmtiles.exe`로 다운로드 (Go 설치 불필요):
   ```
   https://github.com/protomaps/go-pmtiles/releases 에서
   go-pmtiles_<버전>_Windows_x86_64.zip 다운받아 압축 해제 → bin/pmtiles.exe
   ```
2. mbutil 설치: `pip install mbutil`
3. tileserver-gl Docker 이미지 pull: `docker pull maptiler/tileserver-gl`
4. `tileserver/fonts`, `tileserver/sprites` 빈 디렉터리가 있어야 함 (tileserver-gl이 시작 시 존재 여부만 체크, 실제로는 style.json이 Protomaps 공개 CDN의 폰트/스프라이트를 참조하므로 내용은 비어 있어도 됨)

## 실행 순서

```bash
npm run map:extract   # 1. Protomaps 공개 빌드에서 서울+인천 bbox 벡터 PMTiles 추출
npm run map:style     # 2. 호스팅 스타일 API에서 style.json 생성 (로컬 데이터 소스로 치환)

# 3. tileserver-gl 기동 (Windows Git Bash에서는 MSYS_NO_PATHCONV=1 필수 —
#    안 붙이면 컨테이너 경로 /data가 Windows 경로로 잘못 치환됨)
export MSYS_NO_PATHCONV=1
docker run --rm -d --name tourmon-tileserver \
  -v "$(pwd)/scripts/map-pipeline:/data" \
  -p 8090:8080 \
  maptiler/tileserver-gl --config /data/tileserver/config.json

# http://localhost:8090/ 에서 미리보기로 스타일이 정상 렌더링되는지 먼저 확인할 것

npm run map:render    # 4. z0-16 전체 타일을 tileserver-gl에 순회 요청해서 PNG로 저장 (약 3~4분, 26,623타일)
docker stop tourmon-tileserver

npm run map:package   # 5. PNG 디렉터리 → MBTiles(mbutil) → raster PMTiles(pmtiles convert)
npm run map:upload    # 6. R2 버킷(tourmon-assets)에 업로드
```

## 로컬 개발용 서빙

`docker-compose.yml`의 `pmtiles-server` 서비스가 `data/seoul-incheon-raster.pmtiles`를 XYZ HTTP로 서빙:

```bash
docker compose up -d pmtiles-server
# http://localhost:8080/seoul-incheon-raster/{z}/{x}/{y}.png
```

Flutter에서 접근 시 플랫폼별 호스트가 다름 (TourMon_App/lib/config/map_config.dart 참고):

| 환경 | `--dart-define=TILE_SERVER_BASE_URL=` |
|---|---|
| Android 에뮬레이터 | `http://10.0.2.2:8080` |
| iOS 시뮬레이터 | `http://localhost:8080` |
| 실기기 (같은 LAN) | `http://<개발 PC LAN IP>:8080` |

```bash
flutter run --dart-define=TILE_SERVER_BASE_URL=http://10.0.2.2:8080
```

## 범위/한계 (현재 상태)

- bbox: `config.ts`의 `BBOX` — 서울+인천 도심+강화도, 원거리 도서 제외
- 줌 레벨: z0-16만 렌더링, z17+는 Flutter `TileLayer`의 `maxNativeZoom`으로 오버줌(업스케일) 처리 — 더 높은 해상도가 필요해지면 이 파이프라인을 z17+ 대상으로 재실행(디테일 패스)
- 로컬 개발 환경까지만 구성됨 — mini-PC/cloudflared 프로덕션 배포는 별도 후속 작업
- `data/`, `bin/`은 git에 커밋되지 않음 (`.gitignore`) — R2가 원본 저장소, 재현이 필요하면 위 순서를 다시 실행

## 검증 완료 (2026-08-14 기준)

- 26,623개 타일 렌더링, 실패 0건
- R2 업로드 후 `pmtiles show`로 원격 파일 무결성 확인
- Android 에뮬레이터(API 37)에서 지도 렌더링 정상, 앱 재시작 후에도 pmtiles-server 중지 상태에서 FMTC 로컬 캐시로 정상 렌더링 확인
- GPS 마커: 에뮬레이터에서 위치 권한 요청까지는 정상 확인. 이후 뜨는 "Location Accuracy" 안내는 Google Play 서비스가 띄우는 에뮬레이터 환경 특유의 시스템 다이얼로그로, 앱 코드와 무관 — 실기기에서는 보통 발생하지 않거나 한 번에 넘어감
