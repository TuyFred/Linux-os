#!/usr/bin/env python3
"""Group 2 OS desktop assistant. The Gemini key never appears in this UI."""
from __future__ import annotations

import json
import os
import signal
import subprocess
import sys
import tempfile
import threading
import urllib.error
import urllib.request
from pathlib import Path

API = "http://127.0.0.1:47321"
CONF_DIR = Path.home() / ".config" / "group2-os"
SETTINGS = CONF_DIR / "assistant-settings.json"
CHATS = CONF_DIR / "chats"
DEFAULTS = {
    "speak_enabled": True,
    "muted": False,
    "auto_read": False,
    "voice": "en",
    "speed": 160,
    "online_search": True,
    "theme": "dark",
}


def load_settings() -> dict:
    data = dict(DEFAULTS)
    try:
        if SETTINGS.is_file():
            raw = json.loads(SETTINGS.read_text(encoding="utf-8"))
            if isinstance(raw, dict):
                for key in DEFAULTS:
                    if key in raw:
                        data[key] = raw[key]
    except (OSError, json.JSONDecodeError):
        pass
    data["speed"] = max(80, min(220, int(data.get("speed") or 160)))
    data["theme"] = "light" if data.get("theme") == "light" else "dark"
    return data


def save_settings(data: dict) -> None:
    CONF_DIR.mkdir(parents=True, exist_ok=True)
    clean = {k: data.get(k, DEFAULTS[k]) for k in DEFAULTS}
    SETTINGS.write_text(json.dumps(clean, indent=2), encoding="utf-8")


class Speech:
    """One speaker at a time. Mute and new playback cancel the current speech."""

    def __init__(self) -> None:
        self.proc: subprocess.Popen | None = None
        self.paused = False

    def _engine(self) -> str | None:
        for name in ("espeak-ng", "espeak", "spd-say"):
            if subprocess.call(["sh", "-c", f"command -v {name}"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL) == 0:
                return name
        return None

    def stop(self) -> None:
        proc = self.proc
        self.proc = None
        self.paused = False
        if not proc or proc.poll() is not None:
            return
        try:
            os.kill(proc.pid, signal.SIGTERM)
        except OSError:
            pass

    def pause(self) -> None:
        proc = self.proc
        if not proc or proc.poll() is not None:
            return
        try:
            os.kill(proc.pid, signal.SIGSTOP)
            self.paused = True
        except OSError:
            pass

    def resume(self) -> None:
        proc = self.proc
        if not proc or proc.poll() is not None:
            self.paused = False
            return
        try:
            os.kill(proc.pid, signal.SIGCONT)
            self.paused = False
        except OSError:
            pass

    def play(self, text: str, voice: str, speed: int, muted: bool, speak_enabled: bool) -> str | None:
        """Return an error message, or None when speech started or was blocked by mute."""
        self.stop()
        if not text.strip():
            return "There is no text to read."
        if muted:
            return "Voice is muted. Unmute to hear speech."
        if not speak_enabled:
            return "Spoken responses are disabled in Settings."
        engine = self._engine()
        if not engine:
            return "Text-to-speech is not installed (espeak-ng or speech-dispatcher)."
        speed = max(80, min(220, int(speed)))
        if engine == "spd-say":
            rate = int((speed - 160) * 1.2)
            cmd = ["spd-say", "-w", "-r", str(rate), "-t", voice or "en", text[:4000]]
        else:
            cmd = [engine, "-v", voice or "en", "-s", str(speed), text[:4000]]
        try:
            self.proc = subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except OSError as exc:
            return f"Could not start speech: {exc}"
        return None

    def voices(self) -> list[str]:
        try:
            out = subprocess.check_output(["espeak-ng", "--voices"], text=True, stderr=subprocess.DEVNULL, timeout=4)
        except (OSError, subprocess.SubprocessError):
            return ["en", "en-us", "en-gb"]
        found = []
        for line in out.splitlines()[1:]:
            parts = line.split()
            if len(parts) >= 4:
                found.append(parts[1])
        return found[:40] or ["en"]


def api_post(path: str, payload: dict, timeout: float = 60) -> dict:
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        API + path, data=data, headers={"Content-Type": "application/json"}, method="POST"
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return json.loads(resp.read().decode("utf-8", errors="ignore"))
    except urllib.error.HTTPError as exc:
        try:
            return json.loads(exc.read().decode("utf-8", errors="ignore"))
        except json.JSONDecodeError:
            return {"ok": False, "error": "api_error", "message": "The assistant service returned an error."}
    except (urllib.error.URLError, TimeoutError, OSError):
        return {
            "ok": False,
            "error": "backend",
            "message": "Cannot reach the assistant backend. Check that it is running and you are online for Gemini.",
        }


def command_exists(cmd: str) -> bool:
    return subprocess.call(
        ["sh", "-c", f"command -v {cmd}"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    ) == 0


def api_health() -> dict:
    try:
        with urllib.request.urlopen(API + "/v1/health", timeout=2) as resp:
            return json.loads(resp.read().decode("utf-8", errors="ignore"))
    except (urllib.error.URLError, TimeoutError, OSError, json.JSONDecodeError):
        return {"ok": False}


def load_engine():
    here = Path(__file__).resolve().parent
    if str(here) not in sys.path:
        sys.path.insert(0, str(here))
    import assistant_engine
    return assistant_engine


def answer_question(messages: list, search: bool) -> dict:
    """Always return a written answer. Offline OS help works with no network."""
    question = ""
    for msg in reversed(messages or []):
        if isinstance(msg, dict) and msg.get("role") == "user":
            question = str(msg.get("text") or "").strip()
            break
    if not question:
        return {"ok": False, "error": "empty", "message": "Please enter a question."}
    local = ""
    engine = None
    try:
        engine = load_engine()
        local = engine.offline_os_answer(question, engine.lang()) or ""
    except Exception:
        local = ""
    health = api_health()
    if health.get("ok") and health.get("key_configured"):
        online = api_post("/v1/ask", {"messages": messages, "search": search}, timeout=25)
        if online.get("ok") and online.get("text"):
            text = online["text"]
            if local and local.strip() not in text:
                text = local.strip() + "\n\n" + text
            online["text"] = text
            online["mode"] = "online"
            return online
    if local:
        return {
            "ok": True,
            "text": local,
            "sources": [],
            "mode": "offline",
        }
    if engine is not None:
        try:
            return {"ok": True, "text": engine.answer(question), "sources": [], "mode": "offline"}
        except Exception:
            pass
    return {
        "ok": True,
        "text": "I can still help with Group 2 OS offline. Ask about install, Wi-Fi, password, shutdown, or restart. Connect to the internet for general questions.",
        "sources": [],
        "mode": "offline",
    }


def selftest() -> int:
    speech = Speech()
    speech.stop()
    msg = speech.play("hello", "en", 160, muted=True, speak_enabled=True)
    assert msg and "muted" in msg.lower()
    assert speech.proc is None
    backup = SETTINGS.read_text(encoding="utf-8") if SETTINGS.is_file() else None
    try:
        save_settings({**DEFAULTS, "muted": True})
        assert load_settings()["muted"] is True
        blob = json.dumps(load_settings())
        assert "AIza" not in blob
    finally:
        if backup is None:
            try:
                SETTINGS.unlink()
            except OSError:
                pass
        else:
            SETTINGS.write_text(backup, encoding="utf-8")
    offline = answer_question([{"role": "user", "text": "how do I install"}], False)
    assert offline.get("ok") and "Install" in offline.get("text", "")
    wifi = answer_question([{"role": "user", "text": "wifi"}], False)
    assert wifi.get("ok") and "Wi-Fi" in wifi.get("text", "")
    print("SELFTEST assistant ui PASS")
    return 0


def zenity_chat() -> None:
    """Open a simple ask window if the full desktop window cannot start."""
    while True:
        try:
            ask = subprocess.run(
                ["zenity", "--entry", "--title=Group 2 Assistant", "--width=480",
                 "--text=Ask a question. Leave this empty or press Cancel to close."],
                capture_output=True, text=True,
            )
        except OSError:
            return
        if ask.returncode != 0:
            return
        question = (ask.stdout or "").strip()
        if not question:
            return
        result = answer_question([{"role": "user", "text": question}], True)
        text = result.get("text") or result.get("message") or "No answer."
        subprocess.run(
            ["zenity", "--info", "--title=Group 2 Assistant", "--width=560", "--text", text[:3000]],
            check=False,
        )


def main() -> None:
    if "--selftest" in sys.argv:
        sys.exit(selftest())
    try:
        import gi
        gi.require_version("Gtk", "3.0")
        from gi.repository import Gdk, GLib, Gtk, Pango
    except Exception:
        zenity_chat()
        return

    class Assistant(Gtk.Window):
        def __init__(self) -> None:
            super().__init__(title="Group 2 Assistant")
            self.set_default_size(1120, 740)
            self.settings = load_settings()
            self.speech = Speech()
            self.history: list[dict] = []
            self.chat_id = "current"
            self.busy = False
            self.recording = False
            self.last_ai = ""
            self._build()
            self.apply_theme()
            self.new_chat(save_current=False)
            self.refresh_status()
            GLib.timeout_add_seconds(5, self.refresh_status)

        def _build(self) -> None:
            root = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
            self.add(root)
            header = Gtk.HeaderBar()
            header.set_show_close_button(True)
            header.set_title("Group 2 Assistant")
            header.set_subtitle("Ask a question")
            self.set_titlebar(header)
            side = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
            side.set_size_request(240, -1)
            side.set_margin_top(16)
            side.set_margin_bottom(16)
            side.set_margin_start(14)
            side.set_margin_end(8)
            side.get_style_context().add_class("sidebar")
            root.pack_start(side, False, False, 0)

            brand = Gtk.Label(label="GROUP 2 OS")
            brand.set_xalign(0)
            brand.get_style_context().add_class("brand")
            sub = Gtk.Label(label="Assistant")
            sub.set_xalign(0)
            sub.get_style_context().add_class("subbrand")
            side.pack_start(brand, False, False, 0)
            side.pack_start(sub, False, False, 0)

            new_btn = Gtk.Button(label="New Chat")
            new_btn.get_style_context().add_class("accent")
            new_btn.connect("clicked", lambda *_: self.new_chat())
            side.pack_start(new_btn, False, False, 0)

            hist_label = Gtk.Label(label="Chat History")
            hist_label.set_xalign(0)
            hist_label.get_style_context().add_class("section")
            side.pack_start(hist_label, False, False, 0)
            self.hist_list = Gtk.ListBox()
            self.hist_list.set_selection_mode(Gtk.SelectionMode.SINGLE)
            self.hist_list.connect("row-activated", self.on_history)
            hist_scroll = Gtk.ScrolledWindow()
            hist_scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
            hist_scroll.add(self.hist_list)
            side.pack_start(hist_scroll, True, True, 0)

            settings_btn = Gtk.Button(label="Settings")
            settings_btn.connect("clicked", self.open_settings)
            side.pack_start(settings_btn, False, False, 0)
            theme_btn = Gtk.Button(label="Dark / Light")
            theme_btn.connect("clicked", self.toggle_theme)
            side.pack_start(theme_btn, False, False, 0)

            main = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
            main.set_margin_top(14)
            main.set_margin_bottom(14)
            main.set_margin_start(12)
            main.set_margin_end(16)
            main.get_style_context().add_class("main")
            root.pack_start(main, True, True, 0)

            top = Gtk.Box(spacing=8)
            self.status = Gtk.Label(label="Checking connection…")
            self.status.set_xalign(0)
            self.status.get_style_context().add_class("status")
            top.pack_start(self.status, True, True, 0)
            self.search_btn = Gtk.ToggleButton(label="Online Search")
            self.search_btn.set_active(bool(self.settings["online_search"]))
            self.search_btn.connect("toggled", self.on_search)
            top.pack_start(self.search_btn, False, False, 0)
            self.mute_btn = Gtk.ToggleButton(label="Mute")
            self.mute_btn.set_active(bool(self.settings["muted"]))
            self.mute_btn.connect("toggled", self.on_mute)
            self._sync_mute_label()
            top.pack_start(self.mute_btn, False, False, 0)
            main.pack_start(top, False, False, 0)

            self.banner = Gtk.Label(label="")
            self.banner.set_xalign(0)
            self.banner.set_line_wrap(True)
            self.banner.get_style_context().add_class("banner")
            self.banner.set_no_show_all(True)
            main.pack_start(self.banner, False, False, 0)

            self.thread = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
            scroll = Gtk.ScrolledWindow()
            scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
            scroll.add(self.thread)
            self.scroll = scroll
            main.pack_start(scroll, True, True, 0)

            voice = Gtk.Box(spacing=6)
            for label, handler in (
                ("Play", self.on_play),
                ("Pause", lambda *_: self.speech.pause()),
                ("Resume", lambda *_: self.speech.resume()),
                ("Stop", lambda *_: self.speech.stop()),
            ):
                btn = Gtk.Button(label=label)
                btn.connect("clicked", handler)
                voice.pack_start(btn, False, False, 0)
            hint = Gtk.Label(label="AI voice  ·  answers stay on screen when muted")
            hint.set_xalign(0)
            hint.get_style_context().add_class("hint")
            voice.pack_start(hint, False, False, 0)
            main.pack_start(voice, False, False, 0)

            ask_label = Gtk.Label(label="Type your question, then press Enter or Send")
            ask_label.set_xalign(0)
            ask_label.get_style_context().add_class("hint")
            main.pack_start(ask_label, False, False, 0)
            entry_row = Gtk.Box(spacing=8)
            self.input = Gtk.TextView()
            self.input.set_wrap_mode(Gtk.WrapMode.WORD_CHAR)
            self.input.set_left_margin(10)
            self.input.set_right_margin(10)
            self.input.set_top_margin(8)
            self.input.set_bottom_margin(8)
            self.input.get_style_context().add_class("composer")
            self.input.connect("key-press-event", self.on_key)
            entry_scroll = Gtk.ScrolledWindow()
            entry_scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
            entry_scroll.set_min_content_height(64)
            entry_scroll.set_max_content_height(120)
            entry_scroll.add(self.input)
            entry_row.pack_start(entry_scroll, True, True, 0)

            self.mic_btn = Gtk.Button(label="Mic")
            self.mic_btn.connect("clicked", self.on_mic)
            read_btn = Gtk.Button(label="Read Text")
            read_btn.connect("clicked", self.on_read_text)
            stop_btn = Gtk.Button(label="Stop Speech")
            stop_btn.connect("clicked", lambda *_: self.speech.stop())
            send_btn = Gtk.Button(label="Send")
            send_btn.get_style_context().add_class("accent")
            send_btn.connect("clicked", lambda *_: self.send())
            for btn in (self.mic_btn, read_btn, stop_btn, send_btn):
                entry_row.pack_start(btn, False, False, 0)
            main.pack_start(entry_row, False, False, 0)

            note = Gtk.Label(
                label="Answers are informational only. Nothing is applied to the system unless you confirm it yourself. Microphone audio is not stored."
            )
            note.set_line_wrap(True)
            note.set_xalign(0)
            note.get_style_context().add_class("hint")
            main.pack_start(note, False, False, 0)

        def css(self) -> str:
            dark = self.settings.get("theme") != "light"
            bg = "#071422" if dark else "#f4f7fb"
            side = "#0b2238" if dark else "#e7eef6"
            fg = "#e8f4ff" if dark else "#102033"
            muted = "#9fc0de" if dark else "#3d5870"
            bubble_ai = "#102a44" if dark else "#ffffff"
            bubble_user = "#1ea7ff"
            line = "#2d6ea8" if dark else "#c5d4e4"
            return f"""
            window {{ background-color: {bg}; }}
            .sidebar {{ background-color: {side}; padding: 12px; }}
            .main {{ background-color: {bg}; }}
            .brand {{ color: #ffffff; font-size: 18px; font-weight: bold; }}
            .subbrand {{ color: #7fd0ff; font-size: 13px; }}
            .section, .status, .hint {{ color: {fg}; }}
            .hint {{ color: {muted}; font-size: 12px; }}
            .banner {{ color: #ffd7a8; background-color: #3a2a12; padding: 8px; border-radius: 8px; }}
            .accent {{ background-color: #1ea7ff; color: white; border-radius: 12px; padding: 8px 14px; }}
            button {{ border-radius: 10px; padding: 8px 12px; }}
            .bubble {{ padding: 12px 14px; border-radius: 16px; border: 1px solid {line}; }}
            .bubble-ai {{ background-color: {bubble_ai}; color: {fg}; }}
            .bubble-user {{ background-color: {bubble_user}; color: white; }}
            .composer, textview {{ background-color: {bubble_ai}; color: {fg}; border-radius: 12px; }}
            """

        def apply_theme(self) -> None:
            try:
                provider = Gtk.CssProvider()
                provider.load_from_data(self.css().encode("utf-8"))
                screen = Gdk.Screen.get_default()
                if screen is not None:
                    Gtk.StyleContext.add_provider_for_screen(
                        screen, provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
                    )
            except Exception:
                return

        def show_banner(self, text: str) -> None:
            if text:
                self.banner.set_text(text)
                self.banner.show()
            else:
                self.banner.hide()

        def refresh_status(self) -> bool:
            health = api_health()
            if health.get("ok") and health.get("key_configured"):
                self.status.set_text("Online  ·  Gemini + Group 2 OS help")
            elif health.get("ok"):
                self.status.set_text("Offline ready  ·  Group 2 OS help  ·  Gemini key missing")
            else:
                self.status.set_text("Offline ready  ·  Group 2 OS help works without internet")
            return True

        def on_search(self, btn) -> None:
            self.settings["online_search"] = btn.get_active()
            save_settings(self.settings)

        def _sync_mute_label(self) -> None:
            self.mute_btn.set_label("Unmute" if self.settings.get("muted") else "Mute")

        def on_mute(self, btn) -> None:
            self.settings["muted"] = btn.get_active()
            save_settings(self.settings)
            self._sync_mute_label()
            if self.settings["muted"]:
                self.speech.stop()

        def toggle_theme(self, *_args) -> None:
            self.settings["theme"] = "light" if self.settings.get("theme") != "light" else "dark"
            save_settings(self.settings)
            self.apply_theme()

        def input_text(self) -> str:
            buf = self.input.get_buffer()
            return buf.get_text(buf.get_start_iter(), buf.get_end_iter(), True).strip()

        def set_input(self, text: str) -> None:
            self.input.get_buffer().set_text(text)

        def on_key(self, _view, event) -> bool:
            if event.keyval in (Gdk.KEY_Return, Gdk.KEY_KP_Enter) and not (event.state & Gdk.ModifierType.SHIFT_MASK):
                self.send()
                return True
            return False

        def add_bubble(self, role: str, text: str, sources: list | None = None) -> None:
            wrap = Gtk.Box()
            frame = Gtk.Frame()
            frame.set_shadow_type(Gtk.ShadowType.NONE)
            frame.get_style_context().add_class("bubble")
            frame.get_style_context().add_class("bubble-user" if role == "user" else "bubble-ai")
            label = Gtk.Label(label=text)
            label.set_line_wrap(True)
            label.set_line_wrap_mode(Pango.WrapMode.WORD_CHAR)
            label.set_selectable(True)
            label.set_xalign(0)
            label.set_max_width_chars(72)
            box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
            box.pack_start(label, False, False, 0)
            if sources:
                for src in sources:
                    link = Gtk.LinkButton.new_with_label(src.get("uri") or "", src.get("title") or src.get("uri") or "")
                    link.set_halign(Gtk.Align.START)
                    box.pack_start(link, False, False, 0)
            frame.add(box)
            if role == "user":
                wrap.pack_end(frame, False, False, 0)
            else:
                wrap.pack_start(frame, False, False, 0)
            self.thread.pack_start(wrap, False, False, 0)
            self.thread.show_all()
            GLib.idle_add(self._scroll_end)

        def _scroll_end(self) -> bool:
            adj = self.scroll.get_vadjustment()
            adj.set_value(adj.get_upper())
            return False

        def new_chat(self, save_current: bool = True) -> None:
            if save_current and self.history:
                self.persist()
            self.history = []
            self.chat_id = str(int(__import__("time").time()))
            self.last_ai = ""
            for child in self.thread.get_children():
                self.thread.remove(child)
            self.add_bubble(
                "model",
                "Welcome to Group 2 Assistant.\n"
                "Offline: Group 2 OS help works with no internet.\n"
                "Online: Gemini answers general questions when you are connected.",
            )
            self.reload_history_list()

        def persist(self) -> None:
            if not self.history:
                return
            CHATS.mkdir(parents=True, exist_ok=True)
            title = next((m["text"][:42] for m in self.history if m["role"] == "user"), "Chat")
            path = CHATS / f"{self.chat_id}.json"
            path.write_text(json.dumps({"title": title, "messages": self.history}, indent=2), encoding="utf-8")
            self.reload_history_list()

        def reload_history_list(self) -> None:
            for row in self.hist_list.get_children():
                self.hist_list.remove(row)
            if not CHATS.is_dir():
                return
            files = sorted(CHATS.glob("*.json"), key=lambda p: p.stat().st_mtime, reverse=True)[:30]
            for path in files:
                try:
                    data = json.loads(path.read_text(encoding="utf-8"))
                except (OSError, json.JSONDecodeError):
                    continue
                row = Gtk.ListBoxRow()
                row.chat_path = str(path)
                label = Gtk.Label(label=data.get("title") or path.stem)
                label.set_xalign(0)
                label.set_ellipsize(Pango.EllipsizeMode.END)
                row.add(label)
                self.hist_list.add(row)
            self.hist_list.show_all()

        def on_history(self, _list, row) -> None:
            path = Path(getattr(row, "chat_path", ""))
            try:
                data = json.loads(path.read_text(encoding="utf-8"))
            except (OSError, json.JSONDecodeError):
                self.show_banner("Could not open that chat.")
                return
            self.persist()
            self.chat_id = path.stem
            self.history = data.get("messages") or []
            for child in self.thread.get_children():
                self.thread.remove(child)
            for msg in self.history:
                self.add_bubble(msg.get("role") or "model", msg.get("text") or "", msg.get("sources"))
            if self.history and self.history[-1].get("role") != "user":
                self.last_ai = self.history[-1].get("text") or ""

        def send(self) -> None:
            text = self.input_text()
            if not text or self.busy:
                if not text:
                    self.show_banner("Please enter a question.")
                return
            self.show_banner("")
            self.set_input("")
            self.history.append({"role": "user", "text": text})
            self.add_bubble("user", text)
            self.busy = True
            self.status.set_text("Thinking…")
            self.add_bubble("model", "Thinking…")
            placeholder = self.thread.get_children()[-1]
            search = bool(self.settings.get("online_search"))
            threading.Thread(target=self._ask, args=(placeholder, search), daemon=True).start()

        def _ask(self, placeholder, search: bool) -> None:
            result = answer_question(self.history, search)
            GLib.idle_add(self._finish_ask, placeholder, result)

        def _finish_ask(self, placeholder, result: dict) -> bool:
            self.busy = False
            self.thread.remove(placeholder)
            if not result.get("ok"):
                message = result.get("message") or "The assistant could not answer."
                self.show_banner(message)
                self.add_bubble("model", message)
                self.refresh_status()
                return False
            text = result.get("text") or ""
            sources = result.get("sources") or []
            note = result.get("search_note")
            if note:
                text = text + "\n\n" + note
            self.history.append({"role": "model", "text": text, "sources": sources})
            self.last_ai = text
            self.add_bubble("model", text, sources)
            self.persist()
            self.refresh_status()
            if self.settings.get("auto_read"):
                err = self.speech.play(
                    text,
                    str(self.settings.get("voice") or "en"),
                    int(self.settings.get("speed") or 160),
                    bool(self.settings.get("muted")),
                    bool(self.settings.get("speak_enabled")),
                )
                if err and not self.settings.get("muted"):
                    self.show_banner(err)
            return False

        def on_play(self, *_args) -> None:
            err = self.speech.play(
                self.last_ai,
                str(self.settings.get("voice") or "en"),
                int(self.settings.get("speed") or 160),
                bool(self.settings.get("muted")),
                bool(self.settings.get("speak_enabled")),
            )
            self.show_banner(err or "")

        def on_read_text(self, *_args) -> None:
            err = self.speech.play(
                self.input_text(),
                str(self.settings.get("voice") or "en"),
                int(self.settings.get("speed") or 160),
                bool(self.settings.get("muted")),
                True,
            )
            self.show_banner(err or "")

        def on_mic(self, *_args) -> None:
            if self.recording:
                return
            if not command_exists("arecord"):
                self.show_banner("Microphone recording is unavailable. Install alsa-utils, then allow microphone access.")
                return
            self.recording = True
            self.mic_btn.set_label("Listening…")
            self.show_banner("Listening… speak, then wait. You can edit the text before sending.")
            threading.Thread(target=self._record, daemon=True).start()

        def _record(self) -> None:
            path = None
            try:
                fd, path = tempfile.mkstemp(prefix="g2-mic-", suffix=".wav")
                os.close(fd)
                proc = subprocess.run(
                    ["arecord", "-q", "-d", "6", "-f", "cd", "-t", "wav", path],
                    stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, timeout=12,
                )
                err = (proc.stderr or b"").decode("utf-8", errors="ignore").lower()
                if proc.returncode != 0 or "permission" in err or "busy" in err or not os.path.getsize(path):
                    GLib.idle_add(self._mic_fail, "Microphone permission was denied or no microphone was found.")
                    return
                import base64
                audio = base64.b64encode(Path(path).read_bytes()).decode("ascii")
                result = api_post("/v1/transcribe", {"audio_b64": audio, "mime": "audio/wav"}, timeout=50)
                if not result.get("ok"):
                    GLib.idle_add(self._mic_fail, result.get("message") or "Speech recognition failed.")
                    return
                GLib.idle_add(self._mic_ok, result.get("text") or "")
            except subprocess.TimeoutExpired:
                GLib.idle_add(self._mic_fail, "Microphone recording timed out.")
            except OSError:
                GLib.idle_add(self._mic_fail, "Could not access the microphone.")
            finally:
                if path:
                    try:
                        os.remove(path)
                    except OSError:
                        pass

        def _mic_fail(self, message: str) -> bool:
            self.recording = False
            self.mic_btn.set_label("Mic")
            self.show_banner(message)
            return False

        def _mic_ok(self, text: str) -> bool:
            self.recording = False
            self.mic_btn.set_label("Mic")
            self.set_input(text)
            self.show_banner("Speech recognized. Edit the text if needed, then press Send.")
            return False

        def open_settings(self, *_args) -> None:
            dialog = Gtk.Dialog(title="Voice Settings", transient_for=self, flags=0)
            dialog.add_button("Close", Gtk.ResponseType.CLOSE)
            box = dialog.get_content_area()
            box.set_spacing(8)
            box.set_margin_start(12)
            box.set_margin_end(12)
            box.set_margin_top(12)

            speak = Gtk.CheckButton(label="Enable spoken AI responses")
            speak.set_active(bool(self.settings["speak_enabled"]))
            auto = Gtk.CheckButton(label="Automatically read new AI answers aloud")
            auto.set_active(bool(self.settings["auto_read"]))
            mute = Gtk.CheckButton(label="Mute voice output")
            mute.set_active(bool(self.settings["muted"]))
            voices = Gtk.ComboBoxText()
            options = self.speech.voices()
            current = str(self.settings.get("voice") or "en")
            if current not in options:
                options.insert(0, current)
            for voice in options:
                voices.append_text(voice)
            voices.set_active(options.index(current) if current in options else 0)
            speed = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, 80, 220, 10)
            speed.set_value(int(self.settings.get("speed") or 160))
            speed.set_hexpand(True)
            for widget, title in (
                (speak, None),
                (auto, None),
                (mute, None),
                (voices, "Voice"),
                (speed, "Speech speed"),
            ):
                if title:
                    box.pack_start(Gtk.Label(label=title, xalign=0), False, False, 0)
                box.pack_start(widget, False, False, 0)
            dialog.show_all()
            dialog.run()
            self.settings["speak_enabled"] = speak.get_active()
            self.settings["auto_read"] = auto.get_active()
            self.settings["muted"] = mute.get_active()
            self.settings["voice"] = voices.get_active_text() or "en"
            self.settings["speed"] = int(speed.get_value())
            save_settings(self.settings)
            self.mute_btn.set_active(bool(self.settings["muted"]))
            if self.settings["muted"]:
                self.speech.stop()
            dialog.destroy()

    try:
        win = Assistant()
        win.connect("destroy", Gtk.main_quit)
        win.set_position(Gtk.WindowPosition.CENTER)
        win.show_all()
        win.banner.hide()
        win.present()
        Gtk.main()
    except Exception as exc:
        try:
            subprocess.run(
                ["zenity", "--error", "--title=Group 2 Assistant", "--width=420",
                 "--text", "The full window could not open. A simple question box will open instead.\n\n" + str(exc)[:400]],
                check=False,
            )
        except OSError:
            pass
        zenity_chat()


if __name__ == "__main__":
    main()
