# FastAPI Nginx Service

> Minimal FastAPI service built for Stage 1 of the DevOps internship track.

## 🚀 Endpoints

| Method | Path      | Returns                                                        |
|--------|-----------|----------------------------------------------------------------|
| GET    | `/`       | `{"message": "API is running"}`                                |
| GET    | `/health` | `{"status": "healthy", "timestamp": "<ISO8601 UTC>"}`          |
| GET    | `/me`     | Name, email, GitHub profile, and current stage                 |

## 🔌 Port

The app binds to `127.0.0.1:3000` only. It is never exposed directly to the internet — a reverse proxy (Nginx) sits in front of it.

## 💻 Run Locally

To run the application locally, follow these steps:

```bash
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
uvicorn main:app --host 127.0.0.1 --port 3000
```

Then test the endpoints with:

```bash
curl http://127.0.0.1:3000/
curl http://127.0.0.1:3000/health
curl http://127.0.0.1:3000/me
```

## 🐳 Docker Networking Explained

When `docker compose` starts this stack, it creates a private bridge network (`app-network`) that only the containers in this project can join. Each container gets registered by its service name in Docker's built-in DNS server — so `backend` can reach the database simply by calling it `db`, with no hardcoded IP address anywhere in the code or config.

**This matters for two reasons.** First, IPs inside Docker networks aren't stable. A container can get a different internal IP every time it restarts. Service-name DNS means your app never breaks because of that. Second, it keeps environments portable: the exact same `DATABASE_URL=...@db:5432/...` works whether this runs on your laptop or a production server, because `db` always resolves correctly within its own network.

Containers on different Docker networks can't reach each other at all, not just blocked, but genuinely unable to resolve one another's names. This is why the `db` and `adminer` services in this project have no ports mapped to the host: they're reachable only from other containers on `app-network`, never from outside. `proxy` is the only service that gets a published port, because it's the only one that should ever face the public internet. If the database port were exposed directly, anyone who found the server's IP could attempt to connect straight to Postgres, bypassing every layer of the application entirely.

> ⚠️ **Warning:** `docker compose down -v` deletes all named volumes, including the database's data. Once removed, that data cannot be recovered — Postgres will start completely empty on the next `up`. Use plain `docker compose down` (without `-v`) unless you specifically intend to wipe the database.

## 📖 Articles

Read more about why your API isn't ready for the internet yet on these platforms:

- [Dev.to](https://dev.to/tesddev/your-api-isnt-ready-for-the-internet-yet-1ofn)
- [Medium](https://medium.com/@tesleem.amuda/your-api-isnt-ready-for-the-internet-yet-2c6be17f6840?sharedUserId=tesleem.amuda)
- [Hashnode](https://tesddev.hashnode.dev/your-api-isn-t-ready-for-the-internet-yet?utm_source=hashnode&utm_medium=feed)
- [LinkedIn](https://www.linkedin.com/pulse/your-api-isnt-ready-internet-yet-heres-why-thatsgood-tesleem-amuda-v5jie)
