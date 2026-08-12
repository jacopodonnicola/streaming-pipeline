# streaming-pipeline
Pipeline: LoadGenerator → Redpanda → Producer HTTP → Consumer → MinIO (Parquet)

## Struttura
- `ingestion/load_generator` - servizio HTTP che genera eventi casuali e li invia al producer
- `ingestion/producer` — servizio HTTP che pubblica eventi su Redpanda
- `ingestion/consumer` — consuma da Redpanda, scrive Parquet su MinIO
- `storage` — configurazione MinIO, init bucket
- `shared` — config, schemi e utility condivisi tra servizi

### Setup locale (dev)
uv sync

### Avvio stack
docker compose -f docker-compose.yml up -d

### Log combinati dei servizi applicativi 
docker compose logs -f producer load-generator consumer