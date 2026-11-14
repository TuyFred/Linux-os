#!/usr/bin/env python3
"""Group 2 Assistant engine: offline OS knowledge + online any-question answers."""
from __future__ import annotations

import json
import os
import re
import ssl
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

HELP_DIR = Path("/usr/share/group2-os/help")
I18N_HINT = Path.home() / ".config" / "group2-os" / "lang"
API_KEY_FILE = Path.home() / ".config" / "group2-os" / "online-api-key"
API_URL_FILE = Path.home() / ".config" / "group2-os" / "online-api-url"


def lang() -> str:
    if I18N_HINT.is_file():
        v = I18N_HINT.read_text(encoding="utf-8", errors="ignore").strip().lower()
        if v.startswith("rw"):
            return "rw"
    env = os.environ.get("GROUP2_LANG", "").lower()
    if env.startswith("rw"):
        return "rw"
    return "en"


def online() -> bool:
    try:
        req = urllib.request.Request(
            "https://connectivitycheck.gstatic.com/generate_204",
            method="HEAD",
        )
        with urllib.request.urlopen(req, timeout=3) as r:
            return True
    except Exception:
        try:
            with urllib.request.urlopen("https://1.1.1.1", timeout=3) as r:
                return True
        except Exception:
            return False


def os_context() -> str:
    parts = [
        "You are Group 2 Assistant on Group 2 OS (Linux desktop remaster).",
        "Slogan: LEARN • BUILD • CREATE • TOGETHER.",
        "Members: Fred Tuyishime, Tuyishimire Innocent, Armand Ikirezi, Ineza shami Lamick, Gabiro Vladmir Brenn, Irakoze Aline, Niyonkuru Tajidini.",
        "Live USB password: group2. After Install use the account created in the installer.",
        "Install: Step4 Try/Install + open Install Group 2 OS; Step5 language/keyboard/Wi-Fi; Step6 disk (alongside/erase/manual); Step7 account+timezone (e.g. Kigali); Step8 Install, Restart, remove USB, login, updates.",
        "Apps: Group 2 Tools, Appearance, System Health, Monitor, Optimizer, Security, How Built, Language.",
        "VirtualBox: VBoxSVGA, 3D off, Optical first; safe graphics menu if black screen.",
    ]
    try:
        parts.append(Path("/etc/os-release").read_text(encoding="utf-8", errors="ignore")[:400])
    except Exception:
        pass
    try:
        import platform
        import socket

        parts.append(f"hostname={socket.gethostname()} kernel={platform.release()}")
    except Exception:
        pass
    return "\n".join(parts)


OS_PATTERNS = [
    (r"wifi|wi-?fi|network|internet|urusobe|interineti", "wifi"),
    (r"password|ijambo|login|group2", "password"),
    (r"terminal|bash|shell|command|amabwiriza", "terminal"),
    (r"install|kwimura|installer|setup|iso|rufus|usb", "install"),
    (r"restart|reboot|kongera|tangira", "restart"),
    (r"logout|sign.?out|log.?out|gusohoka", "logout"),
    (r"switch.?user|guhindura", "switch"),
    (r"wallpaper|theme|dark|light|appearance|imiterere", "wall"),
    (r"member|abanyamuryango|tajidini", "members"),
    (r"about|kernel|memory|ram", "about"),
    (r"health|ubuzima|diagnose|monitor", "health"),
    (r"security|firewall|umutekano|privacy", "security"),
    (r"optimize|cache|disk.?space|kunosha", "optimize"),
    (r"how.?built|ukubatswe|built", "built"),
    (r"kinyarwanda|language|ururimi", "lang"),
    (r"virtualbox|vmware|vbox|safe.?graphics", "vbox"),
    (r"create.?user|add.?user|new.?user", "user"),
    (r"update|upgrade|apt", "update"),
]


def offline_os_answer(q: str, lng: str) -> str | None:
    ql = q.lower().strip()
    key = None
    for pat, name in OS_PATTERNS:
        if re.search(pat, ql):
            key = name
            break

    en = {
        "wifi": "Wi-Fi: click the network icon (top-right) -> choose your network -> enter password. Or Settings -> Network -> Wi-Fi.",
        "password": "Live USB password is: group2. After Install, use the password you created in the installer.",
        "terminal": "Open Terminal from the dock. Real bash shell. Examples: ls, cd, pwd. After Install: sudo apt update.",
        "install": (
            "Install Group 2 OS — required steps:\n"
            "Step 4 Start: Boot menu -> Try or Install Group 2 OS -> open Install Group 2 OS.\n"
            "Step 5 Configure: language, keyboard, Wi-Fi if available, installation type / optional software.\n"
            "Step 6 Disk: install alongside Windows (if supported), OR erase disk and install, OR manual partitioning. "
            "WARNING: erase permanently deletes files — back up first.\n"
            "Step 7 Account: name, computer name, username, password, time zone (e.g. Kigali, Rwanda).\n"
            "Step 8 Finish: click Install -> wait -> Restart -> remove USB/ISO -> log in with YOUR password -> "
            "connect internet and install updates.\n"
            "After Install, Sign Out and Restart return to the Group 2 OS login (autologin off).\n"
            "VirtualBox: VBoxSVGA, 3D Off, Optical first; after install set Hard Disk first."
        ),
        "restart": "System menu (top-right) -> Power -> Restart. Group 2 OS boots to the login screen (Sign In). Autologin is disabled so Restart always shows login.",
        "logout": "System menu -> Log Out (Sign Out). You return to the Group 2 OS login screen with live date/time. Switch User also returns to login.",
        "switch": "System menu -> Switch User. Create extra accounts in Group 2 Accounts first (Administrator or Standard user).",
        "wall": "Open Appearance or Settings -> Appearance for wallpapers, dark and light themes.",
        "members": "Desktop folders: Fred Tuyishime, Tuyishimire Innocent, Armand Ikirezi, Ineza shami Lamick, Gabiro Vladmir Brenn, Irakoze Aline, Niyonkuru Tajidini.",
        "about": "Open About Group 2 OS for kernel, memory, and storage on this computer.",
        "health": "Open System Health or Smart System Monitor from Group 2 Tools.",
        "security": "Open Security & Privacy Center for firewall, updates, and privacy tips.",
        "optimize": "Open One-Click Optimizer to clear safe caches and free disk space.",
        "built": "Open How Group 2 OS Was Built (English or Kinyarwanda guide + Terminal demo).",
        "lang": "Open Language / Ururimi to switch English or Kinyarwanda for Group 2 apps.",
        "vbox": "VirtualBox: VBoxSVGA (not VMSVGA), 3D Off, 128MB video, Optical first. Black screen -> boot menu Group 2 OS (VirtualBox / safe graphics).",
        "user": "Open Group 2 Accounts while signed in as an administrator. Choose Administrator (system changes and new accounts) or Standard user (desktop only). The Install account is an Administrator. Sign Out to see the new login.",
        "update": "After Install in Terminal: sudo apt update && sudo apt upgrade.",
    }
    rw = {
        "wifi": "Wi-Fi: kanda ikimenyetso cy'urusobe (hejuru iburyo) -> hitamo urusobe -> andika ijambo ry'ibanga. Cyangwa Settings -> Network -> Wi-Fi.",
        "password": "Ijambo ry'ibanga rya Live USB ni: group2. Nyuma yo kwimura, koresha ijambo ry'ibanga wihaye muri installer.",
        "terminal": "Fungura Terminal ku dock. Amabwiriza: ls, cd, pwd. Nyuma yo kwimura: sudo apt update.",
        "install": (
            "Kwimura Group 2 OS — intambwe zose:\n"
            "Intambwe 4: Hitamo Try or Install Group 2 OS, fungura Install Group 2 OS.\n"
            "Intambwe 5: Ururimi, keyboard, Wi-Fi, ubwoko bwo kwimura.\n"
            "Intambwe 6: Hamwe na Windows, cyangwa gusiba disiki, cyangwa manual. GUSIBA BIRASIBA AMADOSIYE.\n"
            "Intambwe 7: Amazina, username, ijambo ry'ibanga, time zone (Kigali).\n"
            "Intambwe 8: Install -> Restart -> kuramo USB -> login na konti yawe -> updates.\n"
            "Nyuma yo kwimura, Sign Out na Restart bisubiza ku login ya Group 2 OS."
        ),
        "restart": "Menu -> Power -> Restart. Usubira ku login ya Group 2 OS (Sign In). Nta autologin.",
        "logout": "Menu -> Log Out (Sign Out). Usubira ku login ya Group 2 OS n'isaha n'itariki.",
        "switch": "Menu -> Switch User. Banza wongereho umukoresha muri Settings -> Users.",
        "wall": "Fungura Appearance cyangwa Settings -> Appearance (wallpaper, dark, light).",
        "members": "Abanyamuryango ku Desktop: Fred, Innocent, Armand, Ineza, Gabiro, Aline, Niyonkuru Tajidini.",
        "about": "Fungura About Group 2 OS urebe kernel, memori, n'ububiko.",
        "health": "Fungura Ubuzima bwa Sisitemu cyangwa Igenzura muri Group 2 Tools.",
        "security": "Fungura Umutekano n'Ibanga.",
        "optimize": "Fungura Kunosha Sisitemu.",
        "built": "Fungura Uko Group 2 OS Yubatswe.",
        "lang": "Fungura Ururimi / Language.",
        "vbox": "VirtualBox: VBoxSVGA, 3D Off, Optical mbere. Niba hashushe: VirtualBox / safe graphics.",
        "user": "Fungura Konti za Group 2 uri umuyobozi. Hitamo Administrator cyangwa Standard user. Konti yo mu kwimura ni Administrator.",
        "update": "Nyuma yo kwimura: sudo apt update && sudo apt upgrade.",
    }
    table = rw if lng == "rw" else en
    if key and key in table:
        return table[key]

    # Keyword file
    path = HELP_DIR / f"assistant-answers.{lng}.txt"
    if not path.is_file():
        path = HELP_DIR / "assistant-answers.en.txt"
    if path.is_file():
        for line in path.read_text(encoding="utf-8", errors="ignore").splitlines():
            line = line.strip()
            if not line or line.startswith("#") or "|" not in line:
                continue
            keys, ans = line.split("|", 1)
            for k in keys.split(","):
                k = k.strip().lower()
                if k and k in ql:
                    return ans.strip()
    if re.search(r"hello|hi|muraho|help|ufasha", ql):
        if lng == "rw":
            return "Ndi Umufasha wa Group 2. Mbaza ku OS (Wi-Fi, kwimura…) offline. Niba ufite interineti, nabaza ikibazo icyo ari cyo cyose."
        return (
            "I am Group 2 Assistant. Offline I guide Group 2 OS (Wi-Fi, install, Terminal…). "
            "When online I can also answer any general question, using Group 2 OS info when relevant."
        )
    return None


def http_get_json(url: str, timeout: float = 10.0):
    ctx = ssl.create_default_context()
    req = urllib.request.Request(
        url,
        headers={
            "User-Agent": "Group2OS-Assistant/1.0 (Linux; educational desktop OS)",
            "Accept": "application/json",
        },
    )
    with urllib.request.urlopen(req, timeout=timeout, context=ctx) as resp:
        return json.loads(resp.read().decode("utf-8", errors="ignore"))


def duckduckgo(q: str) -> str | None:
    url = "https://api.duckduckgo.com/?" + urllib.parse.urlencode(
        {"q": q, "format": "json", "no_html": 1, "skip_disambig": 1}
    )
    try:
        data = http_get_json(url)
    except Exception:
        return None
    abstract = (data.get("AbstractText") or "").strip()
    if abstract:
        src = data.get("AbstractURL") or "DuckDuckGo"
        return f"{abstract}\n\n(Source: {src})"
    for topic in data.get("RelatedTopics") or []:
        if isinstance(topic, dict) and topic.get("Text"):
            return topic["Text"]
        if isinstance(topic, dict) and topic.get("Topics"):
            for t in topic["Topics"]:
                if isinstance(t, dict) and t.get("Text"):
                    return t["Text"]
    answer = (data.get("Answer") or "").strip()
    if answer:
        return answer
    return None


def wikipedia(q: str, lng: str) -> str | None:
    lang_code = "rw" if lng == "rw" else "en"
    # Search
    search_url = (
        f"https://{lang_code}.wikipedia.org/w/api.php?"
        + urllib.parse.urlencode(
            {"action": "opensearch", "search": q, "limit": 1, "namespace": 0, "format": "json"}
        )
    )
    try:
        data = http_get_json(search_url)
        if not data or len(data) < 2 or not data[1]:
            if lang_code != "en":
                return wikipedia(q, "en")
            return None
        title = data[1][0]
        sum_url = (
            f"https://{lang_code}.wikipedia.org/api/rest_v1/page/summary/"
            + urllib.parse.quote(title)
        )
        summary = http_get_json(sum_url)
        extract = (summary.get("extract") or "").strip()
        if extract:
            return f"{extract}\n\n(Source: Wikipedia — {title})"
    except Exception:
        if lang_code != "en":
            return wikipedia(q, "en")
    return None


def llm_online(q: str, lng: str) -> str | None:
    """Optional: OpenAI-compatible API if user saved a key."""
    key = os.environ.get("GROUP2_API_KEY") or os.environ.get("OPENAI_API_KEY") or os.environ.get("GROQ_API_KEY")
    if not key and API_KEY_FILE.is_file():
        key = API_KEY_FILE.read_text(encoding="utf-8", errors="ignore").strip()
    if not key:
        return None
    url = os.environ.get("GROUP2_API_URL")
    if not url and API_URL_FILE.is_file():
        url = API_URL_FILE.read_text(encoding="utf-8", errors="ignore").strip()
    if not url:
        # Groq-compatible default if GROQ key style; else OpenAI
        if key.startswith("gsk_"):
            url = "https://api.groq.com/openai/v1/chat/completions"
            model = "llama-3.1-8b-instant"
        else:
            url = "https://api.openai.com/v1/chat/completions"
            model = "gpt-4o-mini"
    else:
        model = os.environ.get("GROUP2_API_MODEL", "gpt-4o-mini")

    system = os_context() + (
        "\nAnswer clearly and briefly. If the question is about Group 2 OS, prefer OS facts. "
        "If general knowledge, answer helpfully. "
        + ("Reply in Kinyarwanda when possible." if lng == "rw" else "Reply in English.")
    )
    payload = {
        "model": model,
        "messages": [
            {"role": "system", "content": system},
            {"role": "user", "content": q},
        ],
        "temperature": 0.4,
        "max_tokens": 500,
    }
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=data,
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {key}",
            "User-Agent": "Group2OS-Assistant/1.0",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=25) as resp:
            out = json.loads(resp.read().decode("utf-8", errors="ignore"))
        return out["choices"][0]["message"]["content"].strip()
    except Exception as e:
        return f"(Online AI key present but request failed: {e})"


def answer(q: str) -> str:
    lng = lang()
    q = (q or "").strip()
    if not q:
        return "Please enter a question." if lng == "en" else "Nyamuneka andika ikibazo."

    local = offline_os_answer(q, lng)
    is_os = local is not None and not re.search(
        r"what is|who is|why is|how does|define|capital|history|science", q.lower()
    )
    # Prefer local OS answers for OS intents; still allow online enrichment for general questions
    net = online()

    if local and any(
        re.search(p, q.lower())
        for p, _ in OS_PATTERNS
        if _ in {
            "wifi",
            "password",
            "terminal",
            "install",
            "restart",
            "logout",
            "switch",
            "wall",
            "members",
            "vbox",
            "user",
            "update",
            "built",
            "lang",
            "health",
            "security",
            "optimize",
            "about",
        }
    ):
        # Strong OS question → local first; if online add a short tip line
        if net:
            return local + (
                "\n\n[Online] Connected — ask any other general question too."
                if lng == "en"
                else "\n\n[Interineti] Uri kumurongo — nabaza ikindi kibazo icyo ari cyo cyose."
            )
        return local + (
            "\n\n[Offline] Only Group 2 OS help is available until you connect to the internet."
            if lng == "en"
            else "\n\n[Offline] Ubufasha bwa Group 2 OS gusa kugeza uhujwe na interineti."
        )

    if net:
        # Try LLM if configured, else DuckDuckGo + Wikipedia, blend with OS context when relevant
        llm = llm_online(q, lng)
        if llm and not llm.startswith("(Online AI key"):
            prefix = ""
            if local:
                prefix = f"[Group 2 OS note]\n{local}\n\n[Online answer]\n"
            return prefix + llm

        ddg = duckduckgo(q)
        wiki = wikipedia(q, lng)
        chunks = []
        if local:
            chunks.append(("[Group 2 OS]\n" if lng == "en" else "[Group 2 OS]\n") + local)
        if ddg:
            chunks.append(ddg)
        if wiki and wiki != ddg:
            chunks.append(wiki)
        if llm:  # error message from llm
            chunks.append(llm)
        if chunks:
            return "\n\n".join(chunks)
        return (
            "You are online, but no detailed answer was found. Try rephrasing, or save an API key:\n"
            "mkdir -p ~/.config/group2-os && echo YOUR_KEY > ~/.config/group2-os/online-api-key\n"
            "(OpenAI or Groq key enables full any-question AI.)"
            if lng == "en"
            else "Uri kumurongo, ariko nta gisubizo gihagije. Ongera uandike ikibazo, cyangwa shyira API key muri ~/.config/group2-os/online-api-key"
        )

    if local:
        return local + (
            "\n\n[Offline] Connect to the internet to ask any general question."
            if lng == "en"
            else "\n\n[Offline] Huza interineti kugira ngo ubaze ikibazo icyo ari cyo cyose."
        )

    return (
        "I do not have that offline. Connect to Wi-Fi — when online I can answer general questions "
        "and still use Group 2 OS information for install and system help."
        if lng == "en"
        else "Nta gisubizo offline. Huza Wi-Fi — iyo ufite interineti nabaza ikibazo icyo ari cyo cyose, nkoresheje amakuru ya Group 2 OS ku buryo bwo kwimura na sisitemu."
    )


def main() -> None:
    if len(sys.argv) > 1 and sys.argv[1] == "--selftest":
        a = answer("how do I install")
        assert "Install" in a or "Kwimura" in a
        b = answer("wifi")
        assert "Wi-Fi" in b or "Wi-Fi" in b or "urusobe" in b.lower() or "Wi-Fi" in b
        print("SELFTEST engine PASS")
        print("online=", online())
        return
    q = " ".join(sys.argv[1:]).strip()
    if not q and not sys.stdin.isatty():
        q = sys.stdin.read().strip()
    if not q:
        print("Usage: group2-assistant-engine 'your question'", file=sys.stderr)
        sys.exit(2)
    print(answer(q))


if __name__ == "__main__":
    main()
