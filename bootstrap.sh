#!/usr/bin/env bash
set -e

# 프로젝트 기본 디렉토리 구조 생성
mkdir -p collector model api web db tests .github/workflows .vscode

# -------------------------
# 환경 변수 예시 파일
# -------------------------
cat > .env.example <<'EOT'
POSTGRES_USER=app
POSTGRES_PASSWORD=app_pw
POSTGRES_DB=disaster
POSTGRES_HOST=postgres
POSTGRES_PORT=5432
API_HOST=0.0.0.0
API_PORT=8000
MAG_THRESHOLD=6.0
EOT

# -------------------------
# Python requirements
# -------------------------
cat > requirements.txt <<'EOT'
fastapi
uvicorn[standard]
psycopg2-binary
requests
pydantic
EOT

# -------------------------
# README
# -------------------------
cat > README.md <<'EOT'
# Disaster Anomaly — Working Skeleton
USGS 수집 → Postgres 저장 → 룰 기반 판정 → FastAPI → 웹

## Quickstart
cp .env.example .env
docker compose up --build
# Web: http://localhost:8080
# API: curl -X POST http://localhost:8000/predict -H "Content-Type: application/json" -d '{"use_latest": true}'
EOT

# -------------------------
# DB init
# -------------------------
cat > db/init.sql <<'EOT'
CREATE TABLE IF NOT EXISTS quakes (
  id TEXT PRIMARY KEY,
  time TIMESTAMPTZ,
  mag DOUBLE PRECISION,
  place TEXT,
  lon DOUBLE PRECISION,
  lat DOUBLE PRECISION,
  raw JSONB
);
CREATE INDEX IF NOT EXISTS quakes_time_idx ON quakes(time DESC);
EOT

# -------------------------
# Collector
# -------------------------
cat > collector/main.py <<'EOT'
import os, requests, psycopg2, json
from datetime import datetime, timezone

PG = dict(
    dbname=os.getenv("POSTGRES_DB"),
    user=os.getenv("POSTGRES_USER"),
    password=os.getenv("POSTGRES_PASSWORD"),
    host=os.getenv("POSTGRES_HOST", "postgres"),
    port=os.getenv("POSTGRES_PORT", "5432"),
)

USGS_URL = "https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/all_hour.geojson"

def get_one_event():
    r = requests.get(USGS_URL, timeout=10)
    r.raise_for_status()
    features = r.json().get("features", [])
    return features[0] if features else None

def upsert_event(conn, f):
    pid = f["id"]
    props = f.get("properties") or {}
    geom = f.get("geometry") or {}
    coords = geom.get("coordinates") or [None, None]
    lon, lat = (coords[0], coords[1]) if len(coords)>=2 else (None, None)
    t_ms = props.get("time")
    t = datetime.fromtimestamp(t_ms/1000, tz=timezone.utc) if t_ms else None
    mag = props.get("mag")
    place = props.get("place")

    with conn.cursor() as cur:
        cur.execute("""
            INSERT INTO quakes (id, time, mag, place, lon, lat, raw)
            VALUES (%s,%s,%s,%s,%s,%s,%s)
            ON CONFLICT (id) DO NOTHING
        """, (pid, t, mag, place, lon, lat, json.dumps(f)))
    conn.commit()

def main():
    ev = get_one_event()
    if not ev:
        print("[collector] no events")
        return
    conn = psycopg2.connect(**PG)
    upsert_event(conn, ev)
    conn.close()
    print("[collector] inserted 1 event")

if __name__ == "__main__":
    main()
EOT

# -------------------------
# Model (Rule-based)
# -------------------------
cat > model/rule.py <<'EOT'
import os
MAG_THRESHOLD = float(os.getenv("MAG_THRESHOLD", "6.0"))

def classify_by_rule(mag: float | None) -> dict:
    if mag is None:
        return {"status": "UNKNOWN", "reason": "mag_none"}
    if mag >= MAG_THRESHOLD:
        return {"status": "ALERT", "reason": f"mag>={MAG_THRESHOLD}"}
    return {"status": "OK", "reason": f"mag<{MAG_THRESHOLD}"}
EOT

# -------------------------
# API
# -------------------------
cat > api/app.py <<'EOT'
import os, psycopg2
from fastapi import FastAPI
from pydantic import BaseModel
from model.rule import classify_by_rule

app = FastAPI()

PG = dict(
    dbname=os.getenv("POSTGRES_DB"),
    user=os.getenv("POSTGRES_USER"),
    password=os.getenv("POSTGRES_PASSWORD"),
    host=os.getenv("POSTGRES_HOST", "postgres"),
    port=os.getenv("POSTGRES_PORT", "5432"),
)

class PredictIn(BaseModel):
    use_latest: bool = True

@app.get("/health")
def health():
    return {"ok": True}

@app.post("/predict")
def predict(_: PredictIn):
    conn = psycopg2.connect(**PG)
    with conn.cursor() as cur:
        cur.execute("SELECT mag, place, time FROM quakes ORDER BY time DESC LIMIT 1")
        row = cur.fetchone()
    conn.close()
    if not row:
        return {"status":"UNKNOWN", "reason":"no_data"}

    mag, place, time = row
    out = classify_by_rule(mag)
    return {"prediction": out, "event": {"mag": mag, "place": place, "time": str(time)}}
EOT

# -------------------------
# Web
# -------------------------
cat > web/index.html <<'EOT'
<!doctype html>
<html>
  <body>
    <h2>Disaster Anomaly — Working Skeleton</h2>
    <button id="btn">Check Latest</button>
    <pre id="out"></pre>
    <script>
      document.getElementById('btn').onclick = async () => {
        const r = await fetch('http://localhost:8000/predict', {
          method:'POST',
          headers:{'Content-Type':'application/json'},
          body: JSON.stringify({use_latest:true})
        });
        const j = await r.json();
        document.getElementById('out').textContent = JSON.stringify(j, null, 2);
      };
    </script>
  </body>
</html>
EOT

# -------------------------
# Test
# -------------------------
cat > tests/test_smoke.py <<'EOT'
def test_truth():
    assert True
EOT

# -------------------------
# Docker Compose
# -------------------------
cat > docker-compose.yml <<'EOT'
version: "3.9"
services:
  postgres:
    image: postgres:15
    env_file: .env
    environment:
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: ${POSTGRES_DB}
    volumes:
      - pgdata:/var/lib/postgresql/data
      - ./db/init.sql:/docker-entrypoint-initdb.d/init.sql:ro
    ports:
      - "5432:5432"
    healthcheck:
      test: ["CMD-SHELL","pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"]
      interval: 5s
      timeout: 3s
      retries: 10

  collector:
    image: python:3.11-slim
    depends_on:
      postgres:
        condition: service_healthy
    env_file: .env
    working_dir: /app
    volumes:
      - ./collector:/app/collector
      - ./requirements.txt:/app/requirements.txt
    command: bash -lc "pip install -r requirements.txt && python collector/main.py"
    restart: "no"

  api:
    image: python:3.11-slim
    depends_on:
      postgres:
        condition: service_healthy
    env_file: .env
    working_dir: /app
    volumes:
      - ./api:/app/api
      - ./model:/app/model
      - ./requirements.txt:/app/requirements.txt
    command: bash -lc "pip install -r requirements.txt && uvicorn api.app:app --host 0.0.0.0 --port ${API_PORT}"
    ports:
      - "8000:8000"

  web:
    image: python:3.11-slim
    depends_on:
      - api
    working_dir: /app
    volumes:
      - ./web:/app/web
    command: bash -lc "python -m http.server 8080 --directory web"
    ports:
      - "8080:8080"

volumes:
  pgdata:
EOT

# -------------------------
# GitHub Actions
# -------------------------
cat > .github/workflows/ci.yml <<'EOT'
name: CI
on:
  push:
    branches: [ main ]
  pull_request:

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.11'
      - run: pip install -r requirements.txt pytest
      - run: pytest -q
EOT

# -------------------------
# VSCode Settings
# -------------------------
cat > .vscode/extensions.json <<'EOT'
{
  "recommendations": [
    "ms-python.python",
    "ms-python.vscode-pylance",
    "ms-azuretools.vscode-docker",
    "ms-vscode.makefile-tools"
  ]
}
EOT

cat > .vscode/settings.json <<'EOT'
{
  "files.eol": "\n",
  "editor.formatOnSave": true,
  "python.analysis.typeCheckingMode": "basic"
}
EOT

cat > .vscode/tasks.json <<'EOT'
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "compose up",
      "type": "shell",
      "command": "docker compose up --build",
      "problemMatcher": []
    },
    {
      "label": "compose down",
      "type": "shell",
      "command": "docker compose down -v",
      "problemMatcher": []
    },
    {
      "label": "curl predict",
      "type": "shell",
      "command": "curl -X POST http://localhost:8000/predict -H \"Content-Type: application/json\" -d '{\"use_latest\": true}'",
      "problemMatcher": []
    }
  ]
}
EOT

# -------------------------
# Gitignore
# -------------------------
cat > .gitignore <<'EOT'
.env
__pycache__/
*.pyc
.vscode/.ropeproject
.pgdata/
EOT

echo "[ok] project scaffold created."

