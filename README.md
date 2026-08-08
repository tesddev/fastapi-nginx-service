# fastapi-nginx-service

Minimal FastAPI service built for Stage 1 of the DevOps internship track.

## Endpoints

| Method | Path      | Returns                                                        |
|--------|-----------|-----------------------------------------------------------------|
| GET    | `/`       | `{"message": "API is running"}`                                |
| GET    | `/health` | `{"status": "healthy", "timestamp": "<ISO8601 UTC>"}`           |
| GET    | `/me`     | Name, email, GitHub profile, and current stage                 |

## Port

The app binds to `127.0.0.1:3000` only. It is never exposed directly to
the internet — a reverse proxy (Nginx) sits in front of it.

## Run Locally

\`\`\`bash
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
uvicorn main:app --host 127.0.0.1 --port 3000
```

Then test with:

```bash
curl http://127.0.0.1:3000/
curl http://127.0.0.1:3000/health
curl http://127.0.0.1:3000/me
```

## Articles

- [Dev.to: Your API isn't ready for the internet yet](https://dev.to/tesddev/your-api-isnt-ready-for-the-internet-yet-1ofn)
- [Medium: Your API isn't ready for the internet yet](https://medium.com/@tesleem.amuda/your-api-isnt-ready-for-the-internet-yet-2c6be17f6840?sharedUserId=tesleem.amuda)
- [Hashnode: Your API isn't ready for the internet yet](https://tesddev.hashnode.dev/your-api-isn-t-ready-for-the-internet-yet?utm_source=hashnode&utm_medium=feed)
- [LinkedIn: Your API isn't ready for the internet yet](https://www.linkedin.com/pulse/your-api-isnt-ready-internet-yet-heres-why-thatsgood-tesleem-amuda-v5jie)
