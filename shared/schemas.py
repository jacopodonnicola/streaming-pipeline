from datetime import datetime, timezone
from enum import Enum
from uuid import uuid4

from pydantic import BaseModel, Field


class EventType(str, Enum):
    PAGE_VIEW = "page_view"
    ADD_TO_CART = "add_to_cart"
    PURCHASE = "purchase"


class ProductCategory(str, Enum):
    ELECTRONICS = "electronics"
    BOOKS = "books"
    CLOTHING = "clothing"
    HOME = "home"


class Event(BaseModel):
    event_id: str = Field(default_factory=lambda: str(uuid4()))
    event_type: EventType
    timestamp: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
    user_id: str
    session_id: str
    product_id: str
    product_category: ProductCategory
    price: float = Field(ge=0)
    quantity: int = Field(ge=0)
    country: str