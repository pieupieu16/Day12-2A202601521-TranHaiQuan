# Multi-stage production-ready Dockerfile for Day 12 Agent

# Stage 1: Build dependency wheels
FROM python:3.11-slim AS builder

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# Stage 2: Runtime image
FROM python:3.11-slim AS runtime

WORKDIR /app

# Non-root user setup
RUN useradd -m -u 1000 appuser && chown -R appuser /app

# Copy installed dependencies from builder stage
COPY --from=builder /install /usr/local

# Copy application source code
COPY app ./app
COPY utils ./utils

USER appuser

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')"

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
