# streaming-pipeline

Pipeline e2e: Redpanda → Producer HTTP → Consumer → MinIO (Parquet) → DataFusion → Streamlit

## Struttura

- `ingestion/producer` — servizio HTTP che pubblica eventi su Redpanda
- `ingestion/consumer` — consuma da Redpanda, scrive Parquet su MinIO
- `storage` — configurazione MinIO, init bucket
- `transformation` — query engine DataFusion sui Parquet in MinIO
- `viz` — dashboard Streamlit
- `shared` — config, schemi e utility condivisi tra servizi

## Setup locale (dev)
uv sync

## Avvio stack
docker compose up -d
