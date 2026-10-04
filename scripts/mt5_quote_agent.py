"""Push read-only MT5 quotes to PriceHUD's public HTTPS API.

Run this on the Windows PC or Windows VPS that has the MT5 terminal installed.
The app never connects back to this machine.
"""

import json
import os
import time
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

import MetaTrader5 as mt5


SYMBOLS = ("XAUUSD", "EURUSD", "GBPUSD", "USDJPY")
TERMINAL = os.environ.get("PRICEHUD_MT5_TERMINAL", r"C:\\Users\\pc\\AppData\\Roaming\\MetaTrader 5\\terminal64.exe")
API_URL = os.environ.get("PRICEHUD_API_URL", "").rstrip("/")
AGENT_API_KEY = os.environ.get("PRICEHUD_AGENT_API_KEY", "")
INTERVAL_SECONDS = max(float(os.environ.get("PRICEHUD_AGENT_INTERVAL", "1")), 0.5)


def post_quotes(quotes: list[dict[str, object]]) -> None:
    body = json.dumps({"quotes": quotes}, separators=(",", ":")).encode()
    request = Request(
        f"{API_URL}/v1/agent/quotes",
        data=body,
        headers={
            "Content-Type": "application/json",
            "X-Agent-Key": AGENT_API_KEY,
            "User-Agent": "PriceHUD-MT5-Agent/1.0",
        },
        method="POST",
    )
    with urlopen(request, timeout=8) as response:
        if response.status != 204:
            raise RuntimeError(f"API returned {response.status}")


def read_quotes() -> list[dict[str, object]]:
    quotes: list[dict[str, object]] = []
    for symbol in SYMBOLS:
        if not mt5.symbol_select(symbol, True):
            continue
        tick = mt5.symbol_info_tick(symbol)
        if tick is None or tick.bid <= 0 or tick.ask <= 0:
            continue
        quotes.append({"symbol": symbol, "bid": tick.bid, "ask": tick.ask, "time_msc": tick.time_msc})
    return quotes


def main() -> None:
    if not API_URL.startswith("https://"):
        raise RuntimeError("PRICEHUD_API_URL must be the public HTTPS API URL")
    if len(AGENT_API_KEY) < 24:
        raise RuntimeError("Set PRICEHUD_AGENT_API_KEY to the server's agent secret")
    if not mt5.initialize(path=TERMINAL, timeout=15000):
        raise RuntimeError(f"MT5 connection failed: {mt5.last_error()}")
    print("PriceHUD MT5 quote agent started", flush=True)
    try:
        while True:
            quotes = read_quotes()
            if quotes:
                try:
                    post_quotes(quotes)
                except (HTTPError, URLError, TimeoutError, RuntimeError) as error:
                    print(f"PriceHUD API unavailable: {error}", flush=True)
            time.sleep(INTERVAL_SECONDS)
    finally:
        mt5.shutdown()


if __name__ == "__main__":
    main()
