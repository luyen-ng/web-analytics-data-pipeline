FROM python:3.12-slim
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app.py generator.py ./
ENV API_RATE_LIMIT_PER_MINUTE=300
EXPOSE 8000
CMD ["python", "app.py"]