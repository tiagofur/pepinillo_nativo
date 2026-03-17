from fastapi import FastAPI
from pydantic import BaseModel


app = FastAPI(title='Pepinillo ML Service', version='0.1.0')


class ProductivityPredictionRequest(BaseModel):
    weekday: int
    recent_focus_minutes: float
    streak_days: int


@app.get('/health')
def health() -> dict[str, str]:
    return {'status': 'ok', 'service': 'ml-service'}


@app.post('/predict/productivity')
def predict_productivity(payload: ProductivityPredictionRequest) -> dict[str, str | float]:
    score = (payload.recent_focus_minutes * 0.4) + (payload.streak_days * 1.5)
    if payload.weekday in (1, 2, 3, 4):
        score += 10

    level = 'low'
    if score >= 60:
        level = 'high'
    elif score >= 30:
        level = 'medium'

    return {'level': level, 'score': round(score, 2), 'model': 'stub-v1'}
