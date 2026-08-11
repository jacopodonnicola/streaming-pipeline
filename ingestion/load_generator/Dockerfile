FROM python:3.12-slim

WORKDIR /app

RUN pip install --no-cache-dir uv

COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --group load_generator --no-install-project

COPY ingestion/load_generator ./ingestion/load_generator

ENV PATH="/app/.venv/bin:$PATH"

CMD ["python", "-m", "ingestion.load_generator.main"]