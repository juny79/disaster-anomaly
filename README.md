# Disaster Anomaly — Working Skeleton

🌐 End-to-End Skeleton: USGS 지진 데이터 → PostgreSQL 저장 → Rule-based 판정 → FastAPI API → Web UI

## 📌 프로젝트 개요
재난 이상치 탐지 시스템의 워킹 스켈레톤(Working Skeleton)입니다.  
현재는 단순 임계값 룰 기반 판정만 포함하지만, 전체 아키텍처(수집–저장–판정–API–웹)가 엔드투엔드(End-to-End)로 연결되어 있습니다.

## 🚀 Quickstart
1. 환경 변수 설정  
   cp .env.example .env

2. 실행  
   docker compose up --build

3. 확인  
   - Web UI: http://localhost:8080  
   - API 호출:  
     curl -X POST http://localhost:8000/predict -H "Content-Type: application/json" -d '{"use_latest": true}'

   예시 응답:  
   {  
     "prediction": {"status": "OK", "reason": "mag<6.0"},  
     "event": {"mag": 4.8, "place": "near Tokyo", "time": "2025-09-21 10:00:00+00"}  
   }

## 📂 폴더 구조
.  
├── collector/       # 데이터 수집기 (USGS API → Postgres 저장)  
├── model/           # 룰 기반 판정 (추후 ML 모델로 확장 예정)  
├── api/             # FastAPI API 서버  
├── web/             # 간단한 웹 프론트엔드  
├── db/              # 초기 스키마 (init.sql)  
├── tests/           # pytest 스모크 테스트  
├── docker-compose.yml  
├── requirements.txt  
└── .env.example  

## 🔮 향후 확장 계획
- Collector → 주기적 수집, 다중 데이터 소스 (KMA, GPM 등)  
- Model → 룰 기반 → 머신러닝 기반 이상치 탐지  
- API → 이벤트 리스트, 통계 API 추가  
- Web → 지도 기반 시각화, 실시간 대시보드  
- 알림 → Slack / Telegram / Email 연동  

## 🤝 기여 방법
1. Fork / Clone 후 브랜치 생성  
2. 기능 추가 및 테스트 작성  
3. Pull Request 생성
