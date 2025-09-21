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
