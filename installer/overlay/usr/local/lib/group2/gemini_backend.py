#!/usr/bin/env python3
"""Group 2 OS Gemini backend.

The API key is read only on this process from a root-only file.
Responses never include the key. This service does not run shell
commands or change system files.
"""
from __future__ import annotations

import base64
import json
import os
import re
import ssl
import sys
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

HOST = "127.0.0.1"
PORT = 47321
MAX_QUESTION = 8000
MAX_AUDIO_BYTES = 8 * 1024 * 1024
MODELS = (
    "gemini-2.5-flash",
    "gemini-2.0-flash",
    "gemini-flash-latest",
)
KEY_FILES = (
    Path("/etc/group2-os/secrets/gemini-api-key"),
    Path(os.environ.get("GROUP2_GEMINI_KEY_FILE", "")),
)

SYSTEM = (
    "You are Group 2 Assistant on Group 2 OS, a Linux desktop. "
    "Slogan: LEARN • BUILD • CREATE • TOGETHER. "
    "Members: Fred Tuyishime, Tuyishimire Innocent, Armand Ikirezi, "
    "Ineza shami Lamick, Gabiro Vladmir Brenn, Irakoze Aline, Niyonkuru Tajidini. "
    "Live Try password is group2. After Install, users log in with the account they created. "
    "Install steps: boot menu Try or Install Group 2 OS; language, keyboard, Wi-Fi; "
    "disk (alongside, erase, or manual — warn that erase deletes data); "
    "name, computer name, username, password, time zone such as Africa/Kigali; "
    "Install, Restart, remove USB, log in, then updates. "
    "Sign Out and Restart return to the login screen. "
    "Answer clearly. Use headings, lists, and fenced code blocks when helpful. "
    "You only give information. Never claim you changed files, ran terminal commands, "
    "or applied system settings. If a system change would be needed, tell the user "
    "to confirm and do it themselves. "
    "If online search was not actually used, do not invent source links."
)


def load_key() -> str:
    for path in KEY_FILES:
        if not path or not str(path):
            continue
        try:
            if path.is_file():
                key = path.read_text(encoding="utf-8", errors="ignore").strip()
                if key:
                    return key
        except OSError:
            continue
    env = os.environ.get("GROUP2_GEMINI_KEY", "").strip()
    return env


def redact(text: str) -> str:
    key = load_key()
    out = text or ""
    if key:
        out = out.replace(key, "[redacted]")
    out = re.sub(r"AIza[0-9A-Za-z\-_]{20,}", "[redacted]", out)
    return out


def classify_http(code: int, body: str) -> str:
    low = (body or "").lower()
    if code == 429 or "resource_exhausted" in low or "rate limit" in low:
        return "rate_limit"
    if code in (404, 400) and ("model" in low or "not found" in low):
        return "model_unavailable"
    if code in (401, 403) or "api key" in low or "permission" in low:
        return "api_auth"
    if "search" in low and ("not supported" in low or "invalid" in low or "unknown" in low):
        return "search_unavailable"
    return "api_error"


def user_message(code: str) -> str:
    return {
        "rate_limit": "Gemini rate limit reached. Wait a moment and try again.",
        "model_unavailable": "The Gemini model is unavailable right now. Try again shortly.",
        "api_auth": "The assistant backend could not authenticate with Gemini. Check the server key configuration.",
        "search_unavailable": "Online search is not available for this model right now. The answer was not generated with live search.",
        "offline": "No internet connection. Check Wi-Fi, then try again.",
        "empty": "Please enter a question.",
        "too_long": "That question is too long. Please shorten it.",
        "backend": "The assistant backend is not running.",
        "audio": "Speech recognition failed. Check the microphone and try again.",
        "mic_permission": "Microphone permission was denied or no microphone was found.",
    }.get(code, "The assistant could not complete that request.")


def _post(url: str, payload: dict, timeout: float = 45) -> tuple[int, dict | str]:
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=data,
        headers={"Content-Type": "application/json", "User-Agent": "Group2OS-Assistant/2.0"},
        method="POST",
    )
    ctx = ssl.create_default_context()
    try:
        with urllib.request.urlopen(req, timeout=timeout, context=ctx) as resp:
            raw = resp.read().decode("utf-8", errors="ignore")
            return resp.status, json.loads(raw)
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="ignore")
        return exc.code, body
    except (urllib.error.URLError, TimeoutError, OSError) as exc:
        return 0, str(exc)


def _extract(data: dict) -> tuple[str, list[dict]]:
    cands = data.get("candidates") or []
    if not cands:
        return "", []
    parts = ((cands[0].get("content") or {}).get("parts") or [])
    text = "\n".join(p.get("text", "") for p in parts if p.get("text")).strip()
    sources = []
    meta = cands[0].get("groundingMetadata") or {}
    for chunk in meta.get("groundingChunks") or []:
        web = chunk.get("web") or {}
        uri = web.get("uri")
        if uri:
            sources.append({"title": web.get("title") or uri, "uri": uri})
    return text, sources


def generate(messages: list[dict], search: bool) -> dict:
    question = ""
    for msg in reversed(messages):
        if msg.get("role") == "user":
            question = (msg.get("text") or "").strip()
            break
    if not question:
        return {"ok": False, "error": "empty", "message": user_message("empty")}
    if len(question) > MAX_QUESTION:
        return {"ok": False, "error": "too_long", "message": user_message("too_long")}
    key = load_key()
    if not key:
        return {"ok": False, "error": "api_auth", "message": user_message("api_auth")}

    contents = []
    for msg in messages[-20:]:
        role = "user" if msg.get("role") == "user" else "model"
        text = (msg.get("text") or "").strip()
        if text:
            contents.append({"role": role, "parts": [{"text": text[:MAX_QUESTION]}]})
    payload = {
        "systemInstruction": {"parts": [{"text": SYSTEM}]},
        "contents": contents,
        "generationConfig": {"temperature": 0.4, "maxOutputTokens": 1200},
    }
    if search:
        payload["tools"] = [{"google_search": {}}]

    last_kind = "api_error"
    last_detail = ""
    for model in MODELS:
        url = (
            "https://generativelanguage.googleapis.com/v1beta/models/"
            f"{model}:generateContent?key={key}"
        )
        used_search = search
        code, body = _post(url, payload)
        if code == 0:
            return {"ok": False, "error": "offline", "message": user_message("offline")}
        if isinstance(body, str):
            kind = classify_http(code, body)
            tool_error = search and any(word in body.lower() for word in ("search", "tool", "grounding"))
            if kind == "search_unavailable" or tool_error:
                payload.pop("tools", None)
                used_search = False
                code, body = _post(url, payload)
                if isinstance(body, str):
                    kind = classify_http(code, body)
                    last_kind, last_detail = kind, redact(body)[:300]
                    if kind == "model_unavailable":
                        continue
                    return {
                        "ok": False,
                        "error": kind,
                        "message": user_message(kind),
                        "search_used": False,
                    }
            else:
                last_kind, last_detail = kind, redact(body)[:300]
                if kind == "model_unavailable":
                    continue
                return {"ok": False, "error": kind, "message": user_message(kind)}
        text, sources = _extract(body if isinstance(body, dict) else {})
        if not text:
            last_kind = "api_error"
            continue
        result = {
            "ok": True,
            "text": text,
            "model": model,
            "search_used": bool(used_search and sources),
            "sources": sources if used_search else [],
        }
        if search and not sources:
            result["search_note"] = (
                "Online search was requested. No source links were returned, "
                "so this answer is not marked as a live web search."
            )
            result["search_used"] = False
        return result
    return {
        "ok": False,
        "error": last_kind,
        "message": user_message(last_kind),
        "detail": last_detail[:180],
    }


def transcribe(audio_b64: str, mime: str = "audio/wav") -> dict:
    if not audio_b64:
        return {"ok": False, "error": "audio", "message": user_message("audio")}
    try:
        raw = base64.b64decode(audio_b64, validate=False)
    except Exception:
        return {"ok": False, "error": "audio", "message": user_message("audio")}
    if len(raw) > MAX_AUDIO_BYTES:
        return {"ok": False, "error": "audio", "message": "Recording is too long. Try a shorter question."}
    key = load_key()
    if not key:
        return {"ok": False, "error": "api_auth", "message": user_message("api_auth")}
    payload = {
        "contents": [{
            "role": "user",
            "parts": [
                {"text": "Transcribe the speech exactly. Return only the transcript, with no extra commentary."},
                {"inline_data": {"mime_type": mime or "audio/wav", "data": audio_b64}},
            ],
        }],
        "generationConfig": {"temperature": 0, "maxOutputTokens": 400},
    }
    for model in MODELS:
        url = (
            "https://generativelanguage.googleapis.com/v1beta/models/"
            f"{model}:generateContent?key={key}"
        )
        code, body = _post(url, payload, timeout=40)
        if code == 0:
            return {"ok": False, "error": "offline", "message": user_message("offline")}
        if isinstance(body, str):
            kind = classify_http(code, body)
            if kind == "model_unavailable":
                continue
            return {"ok": False, "error": kind, "message": user_message("audio")}
        text, _ = _extract(body if isinstance(body, dict) else {})
        text = text.strip().strip('"')
        if text:
            return {"ok": True, "text": text}
    return {"ok": False, "error": "audio", "message": user_message("audio")}


class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt: str, *args) -> None:
        return

    def _send(self, status: int, payload: dict) -> None:
        raw = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(raw)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(raw)

    def do_GET(self) -> None:  # noqa: N802
        if self.path.split("?", 1)[0] != "/v1/health":
            self._send(404, {"ok": False, "error": "backend", "message": "Not found"})
            return
        self._send(200, {
            "ok": True,
            "service": "group2-gemini",
            "key_configured": bool(load_key()),
            "bind": HOST,
        })

    def do_POST(self) -> None:  # noqa: N802
        path = self.path.split("?", 1)[0]
        length = int(self.headers.get("Content-Length") or 0)
        if length > MAX_AUDIO_BYTES + 100000:
            self._send(413, {"ok": False, "error": "audio", "message": "Request too large"})
            return
        try:
            data = json.loads(self.rfile.read(length).decode("utf-8", errors="ignore") or "{}")
        except json.JSONDecodeError:
            self._send(400, {"ok": False, "error": "api_error", "message": "Invalid request"})
            return
        if path == "/v1/ask":
            messages = data.get("messages") if isinstance(data.get("messages"), list) else []
            clean = []
            for item in messages:
                if not isinstance(item, dict):
                    continue
                role = "user" if item.get("role") == "user" else "model"
                text = str(item.get("text") or "")
                clean.append({"role": role, "text": text})
            result = generate(clean, bool(data.get("search")))
            self._send(200 if result.get("ok") else 502, result)
            return
        if path == "/v1/transcribe":
            result = transcribe(str(data.get("audio_b64") or ""), str(data.get("mime") or "audio/wav"))
            self._send(200 if result.get("ok") else 502, result)
            return
        self._send(404, {"ok": False, "error": "backend", "message": "Not found"})


def serve() -> None:
    httpd = ThreadingHTTPServer((HOST, PORT), Handler)
    print(f"group2-gemini listening on http://{HOST}:{PORT}", flush=True)
    httpd.serve_forever()


def selftest() -> int:
    assert classify_http(429, "rate") == "rate_limit"
    assert classify_http(404, "model not found") == "model_unavailable"
    assert classify_http(0, "") == "api_error"
    assert "AIza" not in redact("key AIzaSyEXAMPLEKEY1234567890abcd")
    assert user_message("offline")
    empty = generate([], False)
    assert empty["error"] == "empty"
    # Public health shape must not contain a key.
    blob = json.dumps({"ok": True, "key_configured": bool(load_key())})
    assert "AIza" not in blob
    if os.environ.get("GROUP2_GEMINI_LIVE") == "1":
        live = generate([{"role": "user", "text": "Reply with exactly: GROUP2_OK"}], False)
        if not live.get("ok") or "GROUP2_OK" not in live.get("text", ""):
            print("LIVE_FAIL", live.get("error"), live.get("message"), flush=True)
            return 1
        print("LIVE_OK", live.get("model"), flush=True)
    print("SELFTEST gemini backend PASS")
    return 0


def main() -> None:
    if "--selftest" in sys.argv:
        sys.exit(selftest())
    if "--serve" in sys.argv:
        serve()
        return
    print("Usage: gemini_backend.py --serve | --selftest", file=sys.stderr)
    sys.exit(2)


if __name__ == "__main__":
    main()
