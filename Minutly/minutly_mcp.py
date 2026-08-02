#!/usr/bin/env python3
"""MCP server exposing Minutly meeting transcripts + summaries.

Reads the plaintext sidecars Minutly already writes into its sandbox container.
No app changes, no dependencies. Register with:

    claude mcp add -s user minutly -- python3 /path/to/minutly_mcp.py
"""
import glob
import json
import os
import sys

# ponytail: glob the bundle ID instead of hardcoding it — debug (Ugitech.Minutly),
# release (com.minutly.minutlyapp) and any future rename all match.
CONTAINERS = "~/Library/Containers/*inutly*/Data/Documents"
SUFFIX = "_transcription.txt"


def log(msg):
    """Diagnostics only. Never stdout — that channel is JSON-RPC."""
    sys.stderr.write("[minutly] %s\n" % msg)
    sys.stderr.flush()


def dirs():
    env = os.environ.get("MINUTLY_DIR")
    cands = [os.path.expanduser(env)] if env else glob.glob(os.path.expanduser(CONTAINERS))
    return [d for d in cands if os.path.isdir(d)]


def diagnose():
    """Why did we find nothing? Distinguishes empty from unreadable."""
    lines = []
    for d in glob.glob(os.path.expanduser(CONTAINERS)):
        try:
            n = len([f for f in os.listdir(d) if f.endswith(SUFFIX)])
            lines.append("  %s -> %d transcript(s)" % (d, n))
        except OSError as e:
            lines.append("  %s -> UNREADABLE: %s" % (d, e))
    if not lines:
        lines = ["  no Minutly container under ~/Library/Containers/ — has the app ever recorded?"]
    return "\n".join(lines)


def meetings():
    """[{name, dir, transcript_path, date}], newest first."""
    out = []
    for d in dirs():
        for path in glob.glob(os.path.join(d, "*" + SUFFIX)):
            st = os.stat(path)
            out.append({
                "name": os.path.basename(path)[: -len(SUFFIX)],
                "dir": d,
                "path": path,
                "ts": getattr(st, "st_birthtime", st.st_mtime),
            })
    return sorted(out, key=lambda m: m["ts"], reverse=True)


def date_of(m):
    import datetime
    return datetime.datetime.fromtimestamp(m["ts"]).strftime("%Y-%m-%d %H:%M")


def find(name):
    name = (name or "").lower()
    all_ = meetings()
    exact = [m for m in all_ if m["name"].lower() == name]
    return (exact or [m for m in all_ if name in m["name"].lower()] or [None])[0]


def read(path):
    with open(path, encoding="utf-8", errors="replace") as f:
        return f.read()


def summary_of(m):
    path = os.path.join(m["dir"], m["name"] + "_summary.json")
    if not os.path.exists(path):
        return None
    try:
        return json.loads(read(path))
    except ValueError:
        return None


def render_summary(s):
    """Same shape as ConversationSummary.formattedText() in the Swift app."""
    text = "## Summary\n\n%s\n" % s.get("summary", "")
    tasks = s.get("tasks") or []
    if tasks:
        text += "\n## Tasks\n\n"
        for i, t in enumerate(tasks, 1):
            text += "%d. **%s**\n" % (i, t.get("task", ""))
            for label, key in (("Owner", "owner"), ("Deadline", "deadline"),
                               ("Dependencies", "dependencies"), ("Priority", "priority")):
                if t.get(key):
                    text += "   - %s: %s\n" % (label, t[key])
            text += "\n"
    return text


# --- tools ---------------------------------------------------------------

def list_meetings():
    ms = meetings()
    if not ms:
        return "No meetings found.\n%s" % diagnose()
    lines = []
    for m in ms:
        words = len(read(m["path"]).split())
        lines.append("- %s  (%s, %d words%s)" % (
            m["name"], date_of(m), words, "" if summary_of(m) is None else ", has summary"))
    return "\n".join(lines)


def get_meeting(name, include_transcript=True):
    m = find(name)
    if not m:
        return "No meeting matching %r. Known: %s" % (
            name, ", ".join(x["name"] for x in meetings()) or "(none)")
    out = "# %s\n\n_%s_\n\n" % (m["name"], date_of(m))
    s = summary_of(m)
    out += render_summary(s) if s else "_No summary generated yet._\n"
    if include_transcript:
        out += "\n## Transcript\n\n" + read(m["path"])
    return out


def search_meetings(query):
    q = (query or "").lower()
    if not q:
        return "Empty query."
    chunks = []
    for m in meetings():
        lines = read(m["path"]).splitlines()
        hits = []
        for i, line in enumerate(lines):
            if q in line.lower():
                ctx = lines[max(0, i - 1):i + 2]
                hits.append("  L%d: %s" % (i + 1, " / ".join(x.strip() for x in ctx if x.strip())))
        if hits:
            chunks.append("## %s (%s)\n%s" % (m["name"], date_of(m), "\n".join(hits[:20])))
    return "\n\n".join(chunks) if chunks else "No match for %r." % query


TOOLS = [
    {
        "name": "list_meetings",
        "description": "List all Minutly meeting recordings, newest first, with date, transcript size and whether a summary exists.",
        "inputSchema": {"type": "object", "properties": {}},
    },
    {
        "name": "get_meeting",
        "description": "Get one meeting as Markdown: AI summary, action items, and (optionally) the full transcript with speaker names.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "name": {"type": "string", "description": "Meeting name or any substring of it."},
                "include_transcript": {"type": "boolean", "description": "Include the full transcript. Default true; set false for just the summary."},
            },
            "required": ["name"],
        },
    },
    {
        "name": "search_meetings",
        "description": "Search across all meeting transcripts for a phrase. Returns matching lines with context, grouped by meeting. Use this instead of loading every transcript.",
        "inputSchema": {
            "type": "object",
            "properties": {"query": {"type": "string"}},
            "required": ["query"],
        },
    },
]

HANDLERS = {
    "list_meetings": lambda a: list_meetings(),
    "get_meeting": lambda a: get_meeting(a.get("name"), a.get("include_transcript", True)),
    "search_meetings": lambda a: search_meetings(a.get("query")),
}


# --- JSON-RPC ------------------------------------------------------------

def handle(req):
    """Returns a response dict, or None for notifications."""
    method, rid = req.get("method"), req.get("id")
    if rid is None:
        return None  # notification (notifications/initialized etc.)

    def ok(result):
        return {"jsonrpc": "2.0", "id": rid, "result": result}

    if method == "initialize":
        return ok({
            "protocolVersion": req.get("params", {}).get("protocolVersion", "2024-11-05"),
            "capabilities": {"tools": {}},
            "serverInfo": {"name": "minutly", "version": "1.0.0"},
        })
    if method == "ping":
        return ok({})
    if method == "tools/list":
        return ok({"tools": TOOLS})
    if method == "tools/call":
        p = req.get("params") or {}
        fn = HANDLERS.get(p.get("name"))
        if not fn:
            return {"jsonrpc": "2.0", "id": rid,
                    "error": {"code": -32602, "message": "Unknown tool: %s" % p.get("name")}}
        try:
            text = fn(p.get("arguments") or {})
        except Exception as e:  # surface as tool error, don't kill the server
            log("%s FAILED: %r" % (p.get("name"), e))
            return ok({"content": [{"type": "text", "text": "Error: %s" % e}], "isError": True})
        log("%s %r -> %d chars from %s" % (p.get("name"), p.get("arguments"), len(text), dirs()))
        return ok({"content": [{"type": "text", "text": text}]})
    return {"jsonrpc": "2.0", "id": rid,
            "error": {"code": -32601, "message": "Method not found: %s" % method}}


def serve():
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            resp = handle(json.loads(line))
        except ValueError:
            continue  # ignore junk rather than dying mid-session
        if resp is not None:
            sys.stdout.write(json.dumps(resp) + "\n")
            sys.stdout.flush()


def selftest():
    import tempfile
    d = tempfile.mkdtemp()
    os.environ["MINUTLY_DIR"] = d
    with open(os.path.join(d, "Kepler Sync_transcription.txt"), "w") as f:
        f.write("Ben: we ship the orbit fix\nAmy: agreed\n")
    with open(os.path.join(d, "Kepler Sync_summary.json"), "w") as f:
        json.dump({"summary": "Decided to ship.",
                   "tasks": [{"task": "Ship it", "owner": "Ben", "priority": "high"}]}, f)

    assert [m["name"] for m in meetings()] == ["Kepler Sync"]
    assert "Kepler Sync" in list_meetings() and "has summary" in list_meetings()

    full = get_meeting("kepler")  # substring match
    assert "Decided to ship." in full
    assert "1. **Ship it**" in full and "- Owner: Ben" in full
    assert "orbit fix" in full
    assert "orbit fix" not in get_meeting("Kepler Sync", include_transcript=False)
    assert "No meeting matching" in get_meeting("nope")

    assert "L1:" in search_meetings("ORBIT")  # case-insensitive
    assert "No match" in search_meetings("submarine")

    r = handle({"jsonrpc": "2.0", "id": 7, "method": "tools/call",
                "params": {"name": "search_meetings", "arguments": {"query": "agreed"}}})
    assert r["id"] == 7 and "Kepler Sync" in r["result"]["content"][0]["text"]
    assert handle({"method": "notifications/initialized"}) is None
    assert handle({"id": 1, "method": "bogus"})["error"]["code"] == -32601
    assert len(handle({"id": 1, "method": "tools/list"})["result"]["tools"]) == 3
    print("ok")


if __name__ == "__main__":
    selftest() if "--selftest" in sys.argv else serve()
