from fastapi import FastAPI
from datetime import datetime, timezone

app = FastAPI()

@app.get("/")
def root():
    return {"message": "API is running"}

@app.get("/health")
def health():
    return {
        "status": "healthy",
        "timestamp": datetime.now(timezone.utc).isoformat()
    }

@app.get("/me")
def me():
    return {
        "name": "Tesleem",
        "email": "tesleem.amuda@email.com",
        "github": "https://github.com/tesddev",
        "stage": "Stage 1"
    }
