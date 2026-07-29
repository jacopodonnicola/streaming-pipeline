FROM python:3.12-slim

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir uv

COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --group producer --no-install-project

COPY shared ./shared
COPY ingestion/producer ./ingestion/producer

ENV PATH="/app/.venv/bin:$PATH"

EXPOSE 8000

CMD ["uvicorn", "ingestion.producer.main:app", "--host", "0.0.0.0", "--port", "8000"]