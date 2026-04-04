FROM python:3.12-slim

RUN pip install --no-cache-dir fastapi "uvicorn[standard]" requests

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && curl -fsSL https://get.docker.com | sh \
    && rm -rf /var/lib/apt/lists/*

COPY update_whatsapp_version.py /app/update_whatsapp_version.py
COPY server.py /app/server.py

WORKDIR /app
CMD ["uvicorn", "server:app", "--host", "0.0.0.0", "--port", "8002"]
