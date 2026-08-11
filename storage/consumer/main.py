# legge da Redpanda → batcha per event_type → scrive Parquet su MinIO

import io
import logging
import os
import signal
import sys
from collections import defaultdict

import pyarrow as pa
import pyarrow.parquet as pq
from confluent_kafka import Consumer
from minio import Minio

from shared.schemas import Event

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("consumer")

KAFKA_BROKER = os.getenv("KAFKA_BROKER", "redpanda:9092")
KAFKA_TOPIC = os.getenv("KAFKA_TOPIC", "events")
KAFKA_GROUP_ID = os.getenv("KAFKA_GROUP_ID", "consumer-parquet-writer")

MINIO_ENDPOINT = os.getenv("MINIO_ENDPOINT", "minio:9000")
MINIO_ROOT_USER = os.getenv("MINIO_ROOT_USER")
MINIO_ROOT_PASSWORD = os.getenv("MINIO_ROOT_PASSWORD")
MINIO_BUCKET = os.getenv("MINIO_BUCKET", "pipeline-data")

BATCH_SIZE = int(os.getenv("BATCH_SIZE", "100"))

# buffer di eventi validati (dict) raggruppati per event_type
batches: dict[str, list[dict]] = defaultdict(list)

running = True


def handle_shutdown(signum, frame):
    global running
    logger.info("Segnale di shutdown ricevuto, chiudo dopo il poll corrente...")
    running = False


signal.signal(signal.SIGTERM, handle_shutdown)
signal.signal(signal.SIGINT, handle_shutdown)


def build_minio_client() -> Minio:
    return Minio(
        MINIO_ENDPOINT,
        access_key=MINIO_ROOT_USER,
        secret_key=MINIO_ROOT_PASSWORD,
        secure=False,
    )


def flush_batch(minio_client: Minio, event_type: str) -> None:
    """Scrive su MinIO il batch accumulato per un dato event_type e lo svuota."""
    records = batches[event_type]
    if not records:
        return

    table = pa.Table.from_pylist(records)

    buffer = io.BytesIO()
    pq.write_table(table, buffer)
    buffer.seek(0)
    size = buffer.getbuffer().nbytes

    # timestamp del primo evento del batch, usato solo per rendere univoco/ordinabile il nome file
    first_ts = records[0]["timestamp"]
    filename = f"{first_ts.strftime('%Y%m%dT%H%M%S%f')}.parquet"
    object_name = f"event_type={event_type}/{filename}"

    minio_client.put_object(
        MINIO_BUCKET,
        object_name,
        data=buffer,
        length=size,
        content_type="application/octet-stream",
    )
    logger.info(f"Scritto batch: {len(records)} eventi -> s3://{MINIO_BUCKET}/{object_name}")

    batches[event_type] = []


def main() -> None:
    consumer = Consumer(
        {
            "bootstrap.servers": KAFKA_BROKER,
            "group.id": KAFKA_GROUP_ID,
            "auto.offset.reset": "earliest",
            "enable.auto.commit": False,
        }
    )
    consumer.subscribe([KAFKA_TOPIC])

    minio_client = build_minio_client()

    logger.info(f"Consumer avviato: topic={KAFKA_TOPIC} group={KAFKA_GROUP_ID} batch_size={BATCH_SIZE}")

    try:
        while running:
            msg = consumer.poll(timeout=1.0)
            if msg is None:
                continue
            if msg.error():
                logger.error(f"Errore Kafka: {msg.error()}")
                continue

            try:
                event = Event.model_validate_json(msg.value())
            except Exception:
                logger.exception("Evento non valido, scartato")
                continue

            record = event.model_dump()
            batches[event.event_type.value].append(record)

            if len(batches[event.event_type.value]) >= BATCH_SIZE:
                try:
                    flush_batch(minio_client, event.event_type.value)
                    consumer.commit(asynchronous=False)
                except Exception:
                    logger.exception(f"Errore nello scrivere il batch per {event.event_type.value}, retry al prossimo giro")
    finally:
        # flush finale dei batch parziali rimasti in memoria prima di uscire
        for event_type in list(batches.keys()):
            try:
                flush_batch(minio_client, event_type)
            except Exception:
                logger.exception(f"Errore nel flush finale per {event_type}")
        consumer.commit(asynchronous=False)
        consumer.close()
        logger.info("Consumer chiuso")


if __name__ == "__main__":
    main()