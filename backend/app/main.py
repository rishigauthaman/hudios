"""PriceHUD's public HTTPS API.

The API deliberately separates the desktop MT5 terminal from Android clients:
the terminal pushes quotes with an agent credential, while apps read the latest
quote with a per-device token.  Never put either server credential in the app.
"""

from __future__ import annotations

import hashlib
import hmac
import os
import secrets
from contextlib import asynccontextmanager
from datetime import UTC, datetime, timedelta
from typing import Annotated

from fastapi import Depends, FastAPI, Header, HTTPException, Response, status
from fastapi.responses import HTMLResponse
from pydantic import BaseModel, Field, field_validator
from sqlalchemy import Boolean, DateTime, Float, Integer, String, create_engine, select
from sqlalchemy.orm import DeclarativeBase, Mapped, Session, mapped_column, sessionmaker


SUPPORTED_SYMBOLS = {"XAUUSD", "EURUSD", "GBPUSD", "USDJPY"}


class Settings:
    database_url = os.getenv("DATABASE_URL", "sqlite:///./pricehud.db")
    admin_api_key = os.getenv("ADMIN_API_KEY", "")
    agent_api_key = os.getenv("AGENT_API_KEY", "")
    token_pepper = os.getenv("TOKEN_PEPPER", "")
    quote_stale_seconds = int(os.getenv("QUOTE_STALE_SECONDS", "30"))

    def validate(self) -> None:
        missing = [
            name
            for name, value in (
                ("ADMIN_API_KEY", self.admin_api_key),
                ("AGENT_API_KEY", self.agent_api_key),
                ("TOKEN_PEPPER", self.token_pepper),
            )
            if len(value) < 24
        ]
        if missing:
            raise RuntimeError(f"Missing or weak environment secrets: {', '.join(missing)}")


settings = Settings()
engine_options: dict[str, object] = {"pool_pre_ping": True}
if settings.database_url.startswith("sqlite"):
    engine_options["connect_args"] = {"check_same_thread": False}
engine = create_engine(settings.database_url, **engine_options)
SessionLocal = sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)


class Base(DeclarativeBase):
    pass


class Quote(Base):
    __tablename__ = "quotes"

    symbol: Mapped[str] = mapped_column(String(12), primary_key=True)
    bid: Mapped[float] = mapped_column(Float)
    ask: Mapped[float] = mapped_column(Float)
    midpoint: Mapped[float] = mapped_column(Float)
    time_msc: Mapped[int] = mapped_column(Integer)
    updated_at: Mapped[datetime] = mapped_column(DateTime)


class ActivationCode(Base):
    __tablename__ = "activation_codes"

    code_hash: Mapped[str] = mapped_column(String(64), primary_key=True)
    remaining_activations: Mapped[int] = mapped_column(Integer)
    expires_at: Mapped[datetime] = mapped_column(DateTime)
    created_at: Mapped[datetime] = mapped_column(DateTime)


class Device(Base):
    __tablename__ = "devices"

    id: Mapped[str] = mapped_column(String(48), primary_key=True)
    token_hash: Mapped[str] = mapped_column(String(64), unique=True, index=True)
    label: Mapped[str] = mapped_column(String(80))
    disabled: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime)
    last_seen_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)


class QuoteInput(BaseModel):
    symbol: str
    bid: float = Field(gt=0)
    ask: float = Field(gt=0)
    time_msc: int = Field(gt=0)

    @field_validator("symbol")
    @classmethod
    def valid_symbol(cls, value: str) -> str:
        symbol = value.upper().strip()
        if symbol not in SUPPORTED_SYMBOLS:
            raise ValueError("Unsupported symbol")
        return symbol

    @field_validator("ask")
    @classmethod
    def ask_is_not_lower_than_bid(cls, ask: float, info) -> float:
        bid = info.data.get("bid")
        if bid is not None and ask < bid:
            raise ValueError("Ask must be at least bid")
        return ask


class QuoteBatch(BaseModel):
    quotes: list[QuoteInput] = Field(min_length=1, max_length=len(SUPPORTED_SYMBOLS))


class ActivationCodeInput(BaseModel):
    max_activations: int = Field(default=10, ge=1, le=10000)
    expires_in_days: int = Field(default=30, ge=1, le=365)


class ActivationInput(BaseModel):
    activation_code: str = Field(min_length=8, max_length=128)
    device_label: str = Field(default="PriceHUD Android", min_length=1, max_length=80)


def utcnow() -> datetime:
    return datetime.now(UTC).replace(tzinfo=None)


def secret_hash(value: str) -> str:
    return hashlib.sha256(f"{settings.token_pepper}:{value}".encode()).hexdigest()


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


Db = Annotated[Session, Depends(get_db)]


def require_secret(actual: str | None, expected: str, name: str) -> None:
    if not actual or not hmac.compare_digest(actual, expected):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=f"Invalid {name}")


def require_admin(x_admin_key: Annotated[str | None, Header()] = None) -> None:
    require_secret(x_admin_key, settings.admin_api_key, "administrator key")


def require_agent(x_agent_key: Annotated[str | None, Header()] = None) -> None:
    require_secret(x_agent_key, settings.agent_api_key, "agent key")


def current_device(
    db: Db,
    authorization: Annotated[str | None, Header()] = None,
) -> Device:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Device authorization required")
    token = authorization.removeprefix("Bearer ").strip()
    if len(token) < 32:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Device authorization required")
    device = db.scalar(select(Device).where(Device.token_hash == secret_hash(token)))
    if not device or device.disabled:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Device authorization required")
    device.last_seen_at = utcnow()
    db.commit()
    return device


@asynccontextmanager
async def lifespan(_: FastAPI):
    settings.validate()
    Base.metadata.create_all(bind=engine)
    yield


app = FastAPI(title="PriceHUD API", docs_url=None, redoc_url=None, lifespan=lifespan)


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.post("/v1/admin/activation-codes", dependencies=[Depends(require_admin)])
def create_activation_code(payload: ActivationCodeInput, db: Db) -> dict[str, object]:
    code = f"PH-{secrets.token_urlsafe(18).upper()}"
    activation = ActivationCode(
        code_hash=secret_hash(code),
        remaining_activations=payload.max_activations,
        expires_at=utcnow() + timedelta(days=payload.expires_in_days),
        created_at=utcnow(),
    )
    db.add(activation)
    db.commit()
    return {"activation_code": code, "expires_at": activation.expires_at, "max_activations": payload.max_activations}


@app.post("/v1/devices/activate", status_code=status.HTTP_201_CREATED)
def activate_device(payload: ActivationInput, db: Db) -> dict[str, str]:
    activation = db.get(ActivationCode, secret_hash(payload.activation_code.strip().upper()))
    if not activation or activation.expires_at < utcnow() or activation.remaining_activations < 1:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Activation code is invalid or expired")
    token = secrets.token_urlsafe(36)
    device = Device(
        id=secrets.token_urlsafe(18),
        token_hash=secret_hash(token),
        label=payload.device_label.strip(),
        disabled=False,
        created_at=utcnow(),
    )
    activation.remaining_activations -= 1
    db.add(device)
    db.commit()
    return {"access_token": token, "token_type": "Bearer"}


@app.delete("/v1/devices/me", status_code=status.HTTP_204_NO_CONTENT)
def revoke_current_device(device: Annotated[Device, Depends(current_device)], db: Db) -> Response:
    device.disabled = True
    db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@app.post("/v1/agent/quotes", dependencies=[Depends(require_agent)], status_code=status.HTTP_204_NO_CONTENT)
def publish_quotes(payload: QuoteBatch, db: Db) -> Response:
    now = utcnow()
    for input_quote in payload.quotes:
        quote = db.get(Quote, input_quote.symbol)
        if quote is None:
            quote = Quote(
                symbol=input_quote.symbol,
                bid=input_quote.bid,
                ask=input_quote.ask,
                midpoint=(input_quote.bid + input_quote.ask) / 2,
                time_msc=input_quote.time_msc,
                updated_at=now,
            )
            db.add(quote)
        elif input_quote.time_msc >= quote.time_msc:
            quote.bid = input_quote.bid
            quote.ask = input_quote.ask
            quote.midpoint = (input_quote.bid + input_quote.ask) / 2
            quote.time_msc = input_quote.time_msc
            quote.updated_at = now
    db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@app.get("/v1/quotes/{symbol}")
def read_quote(symbol: str, _: Annotated[Device, Depends(current_device)], db: Db) -> dict[str, object]:
    normalized = symbol.upper().strip()
    if normalized not in SUPPORTED_SYMBOLS:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Unsupported symbol")
    quote = db.get(Quote, normalized)
    if not quote or quote.updated_at < utcnow() - timedelta(seconds=settings.quote_stale_seconds):
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail="Live MT5 quote is temporarily unavailable")
    return {
        "symbol": quote.symbol,
        "bid": quote.bid,
        "ask": quote.ask,
        "midpoint": quote.midpoint,
        "time_msc": quote.time_msc,
        "updated_at": quote.updated_at,
    }


@app.get("/privacy", response_class=HTMLResponse, include_in_schema=False)
def privacy() -> str:
    return """<!doctype html><html><head><meta charset='utf-8'><title>PriceHUD Privacy Policy</title></head><body><main><h1>PriceHUD Privacy Policy</h1><p>PriceHUD processes an app-generated device authorization token and technical request data to deliver price quotes. It does not process brokerage credentials or place trades. Device access can be revoked from the app.</p><p>The publisher must replace this draft with its business contact details and complete Google Play's Data safety form before release.</p></main></body></html>"""
