import os
MAG_THRESHOLD = float(os.getenv("MAG_THRESHOLD", "6.0"))

def classify_by_rule(mag: float | None) -> dict:
    if mag is None:
        return {"status": "UNKNOWN", "reason": "mag_none"}
    if mag >= MAG_THRESHOLD:
        return {"status": "ALERT", "reason": f"mag>={MAG_THRESHOLD}"}
    return {"status": "OK", "reason": f"mag<{MAG_THRESHOLD}"}
