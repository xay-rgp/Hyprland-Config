#!/usr/bin/env python3
"""Usage stats for the Agents widget, printed as one JSON object.

  claude   Claude subscription limits (session / weekly) for every signed-in
           account, from `claude-account usage` (dotfiles-bin), which owns
           the tokens and knows which ones are safe to refresh.

  opencode OpenCode Go subscription limits (rolling 5-hour / weekly /
           monthly), from opencode.ai/zen/go/v1/usage — the same numbers as
           the Go page in the OpenCode console. Takes an OpenCode API key from
           the keyring (see quickshell/.secrets).

  bifrost  Request / token / cost stats from the homelab Bifrost gateway
           (opencode goes through it). The admin API takes a session token
           from /api/session/login; every login creates a new 30-day session,
           so the token is cached in $XDG_RUNTIME_DIR and only renewed on 401.
           Credentials come from the keyring (see quickshell/.secrets).

Each section carries `ok` and, when not ok, `error` (a short line for the
widget), so one source failing never hides another.

The 7-day Bifrost queries are slow (~15 s each on a busy week: the server
scans every log row, and rankings also computes the previous week for
trends), so its three calls run in parallel with a generous timeout, and the
shell fetches it on its own, less often, so Claude never waits on it. Each
good result is also written to ~/.cache/quickshell/bifrost.json, which the
shell loads on start instead of waiting for the first fetch.

Usage: agent-usage.py [claude] [opencode] [bifrost]   (default: all)

Env: BIFROST_URL overrides the gateway address (default: the in-cluster
service, so admin credentials never leave the machine).
"""
import datetime as dt
import json
import os
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor
import urllib.error
import urllib.parse
import urllib.request

HOME = os.path.expanduser("~")
CLAUDE_ACCOUNT = os.path.join(HOME, ".local", "bin", "claude-account")
BIFROST_URL = os.environ.get("BIFROST_URL", "http://10.43.226.225:8080").rstrip("/")
RUNTIME = os.environ.get("XDG_RUNTIME_DIR") or "/tmp"
TOKEN_FILE = os.path.join(RUNTIME, "quickshell", "bifrost-token")
CACHE_DIR = os.environ.get("XDG_CACHE_HOME") or os.path.join(HOME, ".cache")
BIFROST_CACHE = os.path.join(CACHE_DIR, "quickshell", "bifrost.json")
TIMEOUT = 8
BIFROST_TIMEOUT = 45


class Unauthorized(Exception):
    pass


def http(url, headers=None, body=None, method=None, timeout=TIMEOUT):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method, headers=headers or {})
    if data is not None:
        req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return json.load(r), r.headers
    except urllib.error.HTTPError as e:
        if e.code == 401:
            raise Unauthorized() from None
        raise RuntimeError(f"HTTP {e.code}") from None
    except urllib.error.URLError as e:
        raise RuntimeError(f"unreachable ({e.reason})") from None
    except TimeoutError:
        raise RuntimeError("timed out") from None


# ── Claude ──────────────────────────────────────────────────────────────────
def claude():
    try:
        r = subprocess.run([CLAUDE_ACCOUNT, "usage"], capture_output=True, text=True, timeout=60)
        return json.loads(r.stdout)
    except FileNotFoundError:
        return {"ok": False, "error": "claude-account isn't installed (dotfiles-bin)"}
    except (subprocess.TimeoutExpired, ValueError):
        return {"ok": False, "error": "claude-account usage failed"}


# ── Keyring ─────────────────────────────────────────────────────────────────
def secret(key, service="bifrost"):
    try:
        return subprocess.run(["secret-tool", "lookup", "service", service, "key", key],
                              capture_output=True, text=True, timeout=5).stdout.strip()
    except (OSError, subprocess.TimeoutExpired):
        return ""


# ── OpenCode Go ─────────────────────────────────────────────────────────────
def opencode():
    key = secret("api-key", service="opencode")
    if not key:
        return {"ok": False, "setup": True, "error": "Add an OpenCode API key to the keyring"}
    try:
        u, _ = http("https://opencode.ai/zen/go/v1/usage",
                    {"Authorization": "Bearer " + key, "User-Agent": "quickshell-agents"})
    except Unauthorized:
        return {"ok": False, "error": "OpenCode rejected the API key"}
    except RuntimeError as e:
        # 403 = the key's workspace has no Go subscription.
        msg = "No OpenCode Go subscription on this key" if str(e) == "HTTP 403" else f"OpenCode {e}"
        return {"ok": False, "error": msg}

    def win(w):
        if not w:
            return None
        return {"percent": w.get("percent", 0), "resets_at": w.get("resetsAt"),
                "severity": "critical" if w.get("status") == "rate-limited" else "normal"}

    usage = u.get("usage") or {}
    return {"ok": True, "rolling": win(usage.get("rolling")),
            "weekly": win(usage.get("weekly")), "monthly": win(usage.get("monthly"))}


# ── Bifrost ─────────────────────────────────────────────────────────────────
def cached_token():
    try:
        with open(TOKEN_FILE) as f:
            return f.read().strip()
    except OSError:
        return ""


def login():
    user, password = secret("admin-username"), secret("admin-password")
    if not user or not password:
        raise PermissionError("no credentials")
    try:
        _, headers = http(BIFROST_URL + "/api/session/login",
                          body={"username": user, "password": password}, method="POST")
    except Unauthorized:
        raise PermissionError("login rejected") from None
    # The token only comes back as a cookie.
    for cookie in headers.get_all("Set-Cookie") or []:
        name, _, rest = cookie.partition("=")
        if name.strip() == "token":
            token = rest.split(";", 1)[0]
            os.makedirs(os.path.dirname(TOKEN_FILE), exist_ok=True)
            fd = os.open(TOKEN_FILE, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
            with os.fdopen(fd, "w") as f:
                f.write(token)
            return token
    raise RuntimeError("login returned no token")


def bifrost_get(path, params, token):
    return http(f"{BIFROST_URL}{path}?{urllib.parse.urlencode(params)}",
                {"Authorization": "Bearer " + token}, timeout=BIFROST_TIMEOUT)[0]


def stats(s):
    return {
        "requests": s.get("total_requests", 0),
        "tokens": s.get("total_tokens", 0),
        "prompt": s.get("prompt_tokens", 0),
        "completion": s.get("completion_tokens", 0),
        "cost": s.get("total_cost", 0),
        "success": s.get("user_facing_success_rate") or s.get("success_rate", 0),
        "latency": s.get("average_latency", 0),
    }


def bifrost():
    now = dt.datetime.now().astimezone()
    midnight = now.replace(hour=0, minute=0, second=0, microsecond=0)
    today = {"start_time": midnight.isoformat(), "end_time": now.isoformat()}
    week = {"period": "7d"}

    def fetch(token):
        calls = [("/api/logs/stats", today), ("/api/logs/stats", week),
                 ("/api/logs/rankings", week)]
        with ThreadPoolExecutor(len(calls)) as pool:
            futures = [pool.submit(bifrost_get, path, params, token) for path, params in calls]
            return [f.result() for f in futures]

    try:
        token = cached_token() or login()
        try:
            t, w, r = fetch(token)
        except Unauthorized:
            t, w, r = fetch(login())
    except PermissionError as e:
        if str(e) == "no credentials":
            return {"ok": False, "setup": True,
                    "error": "Add the Bifrost admin login to the keyring"}
        return {"ok": False, "error": "Bifrost rejected the admin login"}
    except (RuntimeError, Unauthorized) as e:
        return {"ok": False, "error": f"Bifrost {e or 'unauthorized'}"}

    models = [{
        "model": m.get("model", ""),
        "provider": m.get("provider", ""),
        "requests": m.get("total_requests", 0),
        "tokens": m.get("total_tokens", 0),
        "cost": m.get("total_cost", 0),
    } for m in (r.get("rankings") or [])]
    models.sort(key=lambda m: m["tokens"], reverse=True)

    return {"ok": True, "today": stats(t), "week": stats(w), "models": models[:5]}


if __name__ == "__main__":
    sources = {"claude": claude, "opencode": opencode, "bifrost": bifrost}
    which = sys.argv[1:] or list(sources)
    out = {"fetched_at": dt.datetime.now().astimezone().isoformat()}
    for name in which:
        out[name] = sources[name]()
    # Bifrost is slow, so the shell keeps its last good result on disk and
    # shows it straight away on the next start.
    if "bifrost" in which and out["bifrost"].get("ok"):
        try:
            os.makedirs(os.path.dirname(BIFROST_CACHE), exist_ok=True)
            tmp = BIFROST_CACHE + ".tmp"
            with open(tmp, "w") as f:
                json.dump({"fetched_at": out["fetched_at"], "bifrost": out["bifrost"]}, f)
            os.replace(tmp, BIFROST_CACHE)
        except OSError:
            pass
    json.dump(out, sys.stdout)
