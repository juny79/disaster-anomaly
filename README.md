# Disaster Anomaly — Working Skeleton

🌐 **End-to-End Skeleton**:  
USGS 지진 데이터 → PostgreSQL 저장 → Rule-based 판정 → FastAPI API → Web UI

---

## 📌 프로젝트 개요
이 레포지토리는 **재난 이상치 탐지 시스템의 워킹 스켈레톤(Working Skeleton)**입니다.  
아직은 단순한 임계값 룰 기반 판정만 포함하지만, 전체 아키텍처(수집–저장–판정–API–웹)가 **엔드투엔드(End-to-End)**로 연결되어 있습니다.

---

## 🚀 Quickstart

### 1. 환경 변수 설정
```bash
cp .env.example .env
