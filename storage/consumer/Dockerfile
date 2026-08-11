FROM python:3.12-slim

WORKDIR /app

RUN pip install --no-cache-dir uv

COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --group consumer --no-install-project

COPY shared ./shared
COPY storage/consumer ./storage/consumer

ENV PATH="/app/.venv/bin:$PATH"

CMD ["python", "-m", "storage.consumer.main"]