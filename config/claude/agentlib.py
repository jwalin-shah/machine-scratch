#!/opt/homebrew/bin/python3
"""agentlib — small, dependency-free helpers for observable agent scripts.

Three primitives, usable two ways:

  As a library (Python):
      import agentlib
      agentlib.log("claude-launch", "starting", level="info")
      r = agentlib.ping("https://api.tokenrouter.com/v1/models")
      key = agentlib.resolve_secret("/providers", "TOKENROUTER_CC_API_KEY")

  As a CLI (any shell script):
      agentlib.py ping  https://api.tokenrouter.com/v1/models
      agentlib.py log   my-script "did the thing" --level warn
      agentlib.py secret /providers TOKENROUTER_CC_API_KEY

Design rules:
  - stdlib only (this is bootstrap-path code; no pip deps, ever)
  - logging never raises and never blocks the caller
  - ping distinguishes *unreachable* (connection/DNS/timeout -> dead) from
    *reachable-but-erroring* (any HTTP status -> host is up). Callers that want
    "block only when truly dead" key off `reachable`, not `status`.
  - secrets are resolved, never logged
"""
import os
import socket
import subprocess
import sys
import time
import urllib.error
import urllib.request
from datetime import datetime

DEFAULT_LOGFILE = "~/.claude/logs/agent.log"


def log(component, msg, level="info", logfile=None):
    """Emit a timestamped line to stderr and append it to a logfile.

    Never raises: a broken logfile path degrades to stderr-only.
    """
    ts = datetime.now().strftime("%Y-%m-%dT%H:%M:%S")
    line = f"{ts} [{component}] {level.upper()}: {msg}"
    sys.stderr.write(line + "\n")
    sys.stderr.flush()
    lf = os.path.expanduser(logfile or DEFAULT_LOGFILE)
    try:
        os.makedirs(os.path.dirname(lf), exist_ok=True)
        with open(lf, "a") as f:
            f.write(line + "\n")
    except Exception:
        pass  # logging must never break the caller
    return line


def ping(url, timeout=5.0):
    """GET `url` and report reachability + latency.

    Returns dict: {reachable, status, latency_ms, error}.
      - reachable=True  -> we got *some* HTTP response (even 401/404/500). Host up.
      - reachable=False -> connection refused / DNS / timeout. Host effectively dead.
    """
    start = time.monotonic()
    try:
        req = urllib.request.Request(url, method="GET")
        with urllib.request.urlopen(req, timeout=timeout) as r:
            ms = (time.monotonic() - start) * 1000
            return {"reachable": True, "status": r.status,
                    "latency_ms": round(ms, 1), "error": None}
    except urllib.error.HTTPError as e:
        # An HTTP status code means the host answered -> reachable.
        ms = (time.monotonic() - start) * 1000
        return {"reachable": True, "status": e.code,
                "latency_ms": round(ms, 1), "error": None}
    except (urllib.error.URLError, socket.timeout, ConnectionError, OSError) as e:
        ms = (time.monotonic() - start) * 1000
        reason = getattr(e, "reason", e)
        return {"reachable": False, "status": None,
                "latency_ms": round(ms, 1), "error": str(reason)}


def resolve_secret(path, field, env_fallback=None, env_section="dev", timeout=8):
    """Resolve a secret value: env override first, then Infisical `--plain`.

    `path`/`field` mirror the existing convention: `infisical secrets --path <path>
    --env <env_section> --plain` prints `FIELD=value` lines. Returns the value or
    None. The value is returned, never logged here.
    """
    if env_fallback:
        v = os.environ.get(env_fallback)
        if v:
            return v
    try:
        r = subprocess.run(
            ["infisical", "secrets", "--path", path, "--env", env_section, "--plain"],
            capture_output=True, text=True, timeout=timeout,
        )
        for line in r.stdout.splitlines():
            if line.startswith(field + "="):
                return line.split("=", 1)[1].strip().strip('"')
    except Exception:
        pass
    return None


def _cli(argv):
    import argparse
    ap = argparse.ArgumentParser(prog="agentlib", description=__doc__.splitlines()[0])
    sub = ap.add_subparsers(dest="cmd", required=True)

    p = sub.add_parser("ping", help="GET a URL; report reachability + latency")
    p.add_argument("url")
    p.add_argument("--timeout", type=float, default=5.0)

    l = sub.add_parser("log", help="timestamped line to stderr + logfile")
    l.add_argument("component")
    l.add_argument("msg")
    l.add_argument("--level", default="info")
    l.add_argument("--logfile")

    s = sub.add_parser("secret", help="resolve a secret from env/Infisical")
    s.add_argument("path")
    s.add_argument("field")
    s.add_argument("--env", default="dev")
    s.add_argument("--fallback", help="env var to check before Infisical")

    a = ap.parse_args(argv)

    if a.cmd == "ping":
        r = ping(a.url, a.timeout)
        if r["reachable"]:
            print(f"OK status={r['status']} {r['latency_ms']}ms")
            return 0
        print(f"DEAD {r['error']} ({r['latency_ms']}ms)")
        return 1
    if a.cmd == "log":
        log(a.component, a.msg, a.level, a.logfile)
        return 0
    if a.cmd == "secret":
        v = resolve_secret(a.path, a.field, env_fallback=a.fallback, env_section=a.env)
        if v is None:
            return 1
        print(v)
        return 0
    return 2


if __name__ == "__main__":
    sys.exit(_cli(sys.argv[1:]))
