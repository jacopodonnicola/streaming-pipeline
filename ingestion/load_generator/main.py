# genera dati di test e li invia al producer tramite HTTP POST

import logging
import os
import random
import time
import uuid

import requests
from faker import Faker

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("load-generator")

fake = Faker()

PRODUCER_URL = os.getenv("PRODUCER_URL", "http://localhost:8000")
EVENTS_PER_SECOND = float(os.getenv("EVENTS_PER_SECOND", "2"))

PRODUCT_CATEGORIES = ["electronics", "books", "clothing", "home"]
COUNTRIES = ["IT", "FR", "DE", "ES", "US"]

# event_type e relativa probabilità (un funnel realistico: molte view, pochi acquisti)
EVENT_TYPE_WEIGHTS = {
    "page_view": 0.6,
    "add_to_cart": 0.3,
    "purchase": 0.1,
}


def generate_event(user_id: str, session_id: str) -> dict:
    event_type = random.choices(
        population=list(EVENT_TYPE_WEIGHTS.keys()),
        weights=list(EVENT_TYPE_WEIGHTS.values()),
        k=1,
    )[0]

    is_purchase_related = event_type in ("add_to_cart", "purchase")

    return {
        "event_type": event_type,
        "user_id": user_id,
        "session_id": session_id,
        "product_id": f"P-{random.randint(1000, 9999)}",
        "product_category": random.choice(PRODUCT_CATEGORIES),
        "price": round(random.uniform(5, 500), 2) if is_purchase_related else 0.0,
        "quantity": random.randint(1, 3) if is_purchase_related else 0,
        "country": random.choice(COUNTRIES),
    }


def send_event(event: dict) -> None:
    try:
        response = requests.post(f"{PRODUCER_URL}/events", json=event, timeout=5)
        response.raise_for_status()
        logger.info(f"Evento inviato: {event['event_type']} -> {response.json()}")
    except requests.RequestException as e:
        logger.error(f"Errore invio evento: {e}")


def run():
    logger.info(f"Load generator avviato, target: {PRODUCER_URL}, rate: {EVENTS_PER_SECOND} eventi/sec")
    delay = 1.0 / EVENTS_PER_SECOND

    while True:
        # simula sessioni utente: ogni tanto un nuovo utente/sessione, altrimenti riusa gli ultimi
        user_id = str(uuid.uuid4())
        session_id = str(uuid.uuid4())

        event = generate_event(user_id, session_id)
        send_event(event)

        time.sleep(delay + random.uniform(-0.1, 0.1) * delay)


if __name__ == "__main__":
    run()