# riceve HTTP → valida → pubblica su Redpanda → risponde

import logging
import os

from confluent_kafka import Producer
from fastapi import FastAPI, HTTPException

from shared.schemas import Event

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("producer")

app = FastAPI(title="streaming-pipeline producer")

KAFKA_BROKER = os.getenv("KAFKA_BROKER", "redpanda:9092")
KAFKA_TOPIC = os.getenv("KAFKA_TOPIC", "events")

producer = Producer({"bootstrap.servers": KAFKA_BROKER})


def delivery_report(err, msg):
    if err is not None:
        logger.error(f"Consegna fallita: {err}")
    else:
        logger.info(f"Evento pubblicato su {msg.topic()} [{msg.partition()}]")


@app.get("/health")
def health():
    return {"status": "ok"}


@app.post("/events")
def publish_event(event: Event):
    try:
        payload = event.model_dump_json().encode("utf-8")
        producer.produce(
            KAFKA_TOPIC,
            key=event.user_id.encode("utf-8"),
            value=payload,
            callback=delivery_report,
        )
        producer.poll(0)
        return {"status": "accepted", "event_id": event.event_id}
    except Exception as e:
        logger.exception("Errore nella pubblicazione dell'evento")
        raise HTTPException(status_code=500, detail=str(e))


@app.on_event("shutdown")
def shutdown():
    producer.flush()