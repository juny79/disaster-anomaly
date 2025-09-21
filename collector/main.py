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
