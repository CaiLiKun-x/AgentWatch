"""Shared utilities for AgentWatch."""

import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any
from urllib.parse import quote, urlparse


def read_stdin_json() -> dict[str, Any] | None:
    """Read JSON from stdin. Returns None when stdin is empty or unparseable."""
    if sys.stdin.isatty():
        return None
    raw = sys.stdin.read().strip()
    if not raw:
        return None
    try:
        return json.loads(raw)
    except json.JSONDecodeError as exc:
        # Gracefully log and return None — never crash a Claude Code hook.
        ts = datetime.now(timezone.utc).isoformat()
        print(f"[AgentWatch] WARN {ts} — bad stdin JSON: {exc}", file=sys.stderr)
        return None


def timestamp_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def format_local_time(value: str, include_date: bool = False) -> str:
    """Format an ISO timestamp in the user's local timezone."""
    if not value:
        return ""
    try:
        dt = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        fallback = value[:19].replace("T", " ")
        return fallback if include_date or len(fallback) < 19 else fallback[-8:]
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    local_dt = dt.astimezone()
    return local_dt.strftime("%Y-%m-%d %H:%M:%S" if include_date else "%H:%M:%S")


def flatten_strings(obj: Any, acc: list[str] | None = None) -> list[str]:
    """Recursively collect every string value in a nested dict/list."""
    if acc is None:
        acc = []
    if isinstance(obj, str):
        acc.append(obj)
    elif isinstance(obj, dict):
        for v in obj.values():
            flatten_strings(v, acc)
    elif isinstance(obj, list):
        for item in obj:
            flatten_strings(item, acc)
    return acc


def _sanitise_text(text: str) -> str:
    """Collapse whitespace for log-friendly output."""
    return " ".join(text.split())


def url_encode(text: str) -> str:
    """Percent-encode *text* for use in a Bark URL path segment."""
    return quote(text, safe="")


def mask_key(key: str) -> str:
    """Return a masked version of a key for safe logging."""
    if not key:
        return "(empty)"
    if len(key) <= 8:
        return "*" * len(key)
    return key[:4] + "*" * (len(key) - 8) + key[-4:]


def parse_bark_input(value: str) -> tuple[str | None, str]:
    """Parse user input that may be a full Bark URL or a bare key.

    Returns (server, key):
    - If *value* is a URL like https://api.day.app/XXX/..., extracts the
      host+scheme as server and the first path segment as key.
    - If *value* looks like a bare key, returns (None, value).

    If the input is empty or clearly invalid, raises ValueError.
    """
    value = value.strip()
    if not value:
        raise ValueError("Empty input — nothing to parse.")

    # Detect URL: starts with http:// or https://
    if re.match(r"^https?://", value, re.IGNORECASE):
        parsed = urlparse(value)
        server = f"{parsed.scheme}://{parsed.netloc}"
        # Extract the first non-empty path segment as the key.
        path = parsed.path.strip("/")
        if not path:
            raise ValueError("URL has no path — cannot extract Bark key.")
        key = path.split("/")[0]
        if not key or len(key) < 8:
            raise ValueError(f"Extracted key '{key}' looks too short to be valid.")
        return server, key

    # Bare key — validate roughly.
    # Bark keys are alphanumeric, typically 10-64 chars.
    if not re.match(r"^[a-zA-Z0-9_-]+$", value):
        raise ValueError(
            "Input does not look like a valid Bark URL or key. "
            "Paste the full Bark URL from the app, or the key alone."
        )
    if len(value) < 8:
        raise ValueError(f"Key '{value}' is too short to be valid.")
    return None, value
