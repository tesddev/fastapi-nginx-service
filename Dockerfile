# ---------- Stage 1: builder ----------
FROM python:3.12-slim-bookworm AS builder

WORKDIR /app

# Copy only requirements first — this is a caching trick.
# Docker caches each layer; if requirements.txt hasn't changed,
# this pip install layer is reused instead of re-run on every build.
COPY requirements.txt .

RUN python -m venv /app/.venv && \
    /app/.venv/bin/pip install --no-cache-dir --upgrade pip && \
    /app/.venv/bin/pip install --no-cache-dir -r requirements.txt

# ---------- Stage 2: runtime ----------
FROM python:3.12-slim-bookworm

LABEL maintainer="Tesleem <you@email.com>" \
      version="1.0" \
      description="FastAPI service - Stage 2 containerized deployment"

# Upgrade system packages to fix known HIGH vulnerabilities (e.g. libpcre2-8-0)
RUN apt-get update \
    && apt-get upgrade -y --no-install-recommends \
    && rm -rf /var/lib/apt/lists/* \
    && adduser --disabled-password --gecos '' appuser \
    && pip install --no-cache-dir --upgrade "setuptools>=78.1.1"

WORKDIR /app

# Copy ONLY the virtual env built in the builder stage — not pip's cache,
# not build tools, not anything else that stage touched.
COPY --from=builder /app/.venv /app/.venv

# Copy application code last. This matters for layer caching: code changes
# far more often than dependencies, so putting COPY . . after the pip install
# means a code-only change doesn't invalidate (and re-run) the dependency layer.
COPY main.py .

ENV PATH="/app/.venv/bin:$PATH"

USER appuser

EXPOSE 3000

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "3000"]