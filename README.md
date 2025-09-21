# Disaster Anomaly — Working Skeleton
USGS 수집 → Postgres 저장 → 룰 기반 판정 → FastAPI → 웹

## Quickstart
cp .env.example .env
docker compose up --build
# Web: http://localhost:8080
# API: curl -X POST http://localhost:8000/predict -H "Content-Type: application/json" -d '{"use_latest": true}'
