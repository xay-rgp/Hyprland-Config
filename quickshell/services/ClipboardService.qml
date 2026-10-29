// Clipboard history, backed by cliphist (already fed by the wl-paste watchers
// in Hyprland's autostart).
//
// Listing is `cliphist list`; restoring is `cliphist decode <id> | wl-copy`,
// run as a shell pipeline so binary (image) entries work too.
//
// Image entries get a thumbnail: after each listing, the newest images are
// decoded once into thumbDir (keyed by cliphist id, which never changes for
// an entry), and files for entries that are gone are pruned.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    // { id, preview, isImage, thumb, imgW, imgH, kind }
    // kind: "image" | "url" | "color" | "secret" | "text"
    property var entries: []
    property int maxPreview: 80
    property bool available: true

    readonly property string thumbDir: Quickshell.env("HOME") + "/.cache/quickshell/cliphist"
    // Only the newest images get thumbnails; older ones keep the text label.
    readonly property int maxThumbs: 60
    // Bumped when a decode pass finishes, so Images retry files that were
    // still missing when their delegate was created.
    property int thumbsRevision: 0
    // False while a decode pass is running, so Images don't try (and warn
    // about) files that haven't been written yet.
    property bool thumbsReady: false

    // ── Listing ─────────────────────────────────────────────────────────────
    property string _buf: ""

    property Process _list: Process {
        command: ["cliphist", "list"]
        // Without an explicit stdout reader the output is discarded and the
        // list always looked empty.
        stdout: SplitParser {
            onRead: function (line) {
                if (line !== "")
                    root._buf += line + "\n"
            }
        }
        onExited: function (code) {
            if (code !== 0) {
                root.available = false
                root.entries = []
                root._buf = ""
                return
            }
            root.available = true
            root._parse(root._buf)
            root._buf = ""
        }
    }

    function refresh() {
        if (_list.running)
            return
        root._buf = ""
        _list.running = true
    }

    function _parse(raw) {
        if (!raw) {
            root.entries = []
            root._decodeThumbs([])      // history wiped: prune every thumbnail
            return
        }
        var out = []
        var thumbs = []
        var lines = raw.split("\n")
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i]
            if (line === "")
                continue
            // "42<TAB>the text" — images show as "42<TAB>[[ binary data ... ]]"
            var tab = line.indexOf("\t")
            if (tab === -1)
                continue
            var id = line.substring(0, tab)
            var body = line.substring(tab + 1)
            // "[[ binary data 18 KiB png 402x537 ]]"
            var m = body.match(/^\[\[ binary data (.+?) (\w+) (\d+)x(\d+) \]\]$/)
            var isImage = body.indexOf("[[ binary data") === 0
            var thumb = ""
            var preview = body.substring(0, root.maxPreview)
            if (isImage) {
                preview = m ? m[2].toUpperCase() + " \u00b7 " + m[3] + "\u00d7" + m[4] + " \u00b7 " + m[1]
                            : "Image"
                if (m && thumbs.length < root.maxThumbs) {
                    var ext = m[2].toLowerCase().replace(/[^a-z0-9]/g, "")
                    thumb = root.thumbDir + "/" + id + "." + ext
                    thumbs.push(id + "." + ext)
                }
            }
            out.push({
                id: id, isImage: isImage, preview: preview, thumb: thumb,
                kind: isImage ? "image" : root.kindOf(body),
                imgW: m ? parseInt(m[3], 10) : 0,
                imgH: m ? parseInt(m[4], 10) : 0
            })
        }
        root.entries = out
        root._decodeThumbs(thumbs)
    }

    // What a text entry looks like, so the widget can draw it to suit:
    // "secret" entries (API keys, tokens) are masked rather than shown.
    readonly property var _secretPatterns: [
        /^(sk|pk|rk)[-_][A-Za-z0-9_-]{16,}$/,          // OpenAI, Stripe, Anthropic
        /^oc_sk_[A-Za-z0-9_]{16,}$/,                   // OpenCode
        /^(ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9]{20,}$/,    // GitHub
        /^github_pat_[A-Za-z0-9_]{20,}$/,
        /^xox[abposr]-[A-Za-z0-9-]{10,}$/,             // Slack
        /^AKIA[0-9A-Z]{16}$/,                          // AWS access key id
        /^AIza[0-9A-Za-z_-]{30,}$/,                    // Google API key
        /^glpat-[A-Za-z0-9_-]{20,}$/,                  // GitLab
        /^eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}$/,  // JWT
        /^-----BEGIN [A-Z ]*PRIVATE KEY-----/
    ]

    function kindOf(text) {
        var t = text.trim()
        for (var i = 0; i < root._secretPatterns.length; i++)
            if (root._secretPatterns[i].test(t)) return "secret"
        // A long unbroken run of letters AND digits (and nothing else) is
        // almost always a token of some sort.
        if (t.length >= 32 && /^[A-Za-z0-9_\-+/=.]+$/.test(t) && /[0-9]/.test(t)
                && /[a-z]/.test(t) && /[A-Z]/.test(t) && !/^[0-9a-f]+$/.test(t))
            return "secret"
        // A short unbroken string mixing upper, lower, digits and symbols
        // reads like a password.
        if (t.length >= 10 && t.length <= 64 && !/\s/.test(t) && /[A-Z]/.test(t) && /[a-z]/.test(t)
                && /[0-9]/.test(t) && /[^A-Za-z0-9]/.test(t) && !/^https?:/.test(t)
                && !/[(){}\[\];,<>"'`]/.test(t))
            return "secret"
        if (/^https?:\/\/\S+$/.test(t)) return "url"
        if (/^(#[0-9a-fA-F]{3}|#[0-9a-fA-F]{6}|#[0-9a-fA-F]{8})$/.test(t)) return "color"
        return "text"
    }

    // ── Thumbnails ──────────────────────────────────────────────────────────
    property Process _thumbs: Process {
        onExited: {
            root.thumbsRevision++
            root.thumbsReady = true
        }
    }

    // Decode missing thumbnails, and delete ones whose entry is gone. Each
    // arg is "<id>.<ext>", with both parts already reduced to [0-9]/[a-z0-9].
    function _decodeThumbs(names) {
        if (_thumbs.running)
            return
        root.thumbsReady = false
        _thumbs.command = ["bash", "-c",
            'dir="$1"; shift; mkdir -p "$dir" || exit 1; ' +
            'declare -A keep; ' +
            'for n in "$@"; do keep[$n]=1; f="$dir/$n"; ' +
            '  if [ ! -s "$f" ]; then ' +
            '    cliphist decode "${n%%.*}" > "$f.tmp" 2>/dev/null && mv -f "$f.tmp" "$f"; ' +
            '    rm -f "$f.tmp"; fi; done; ' +
            'for f in "$dir"/*; do [ -e "$f" ] || continue; ' +
            '  [ -n "${keep[${f##*/}]}" ] || rm -f "$f"; done',
            "_", root.thumbDir].concat(names)
        _thumbs.running = true
    }

    // ── Actions ─────────────────────────────────────────────────────────────
    // Commands run one at a time; ones issued meanwhile (a few quick
    // deletes) queue up rather than being dropped.
    property var _queue: []

    property Process _action: Process {
        onExited: function () {
            if (root._queue.length > 0) root._next()
            else root.refresh()
        }
    }

    function _run(cmd) {
        root._queue = root._queue.concat([cmd])
        if (!_action.running) _next()
    }

    function _next() {
        var cmd = root._queue[0]
        root._queue = root._queue.slice(1)
        _action.command = ["bash", "-c", cmd]
        _action.running = true
    }

    function copyEntry(id) {
        // Shell quote the id defensively — it always comes from cliphist, but
        // it is still interpolated into a command string.
        var safe = String(id).replace(/[^0-9]/g, "")
        if (safe === "")
            return
        _run("cliphist decode " + safe + " | wl-copy")
    }

    function deleteEntry(id) {
        var safe = String(id).replace(/[^0-9]/g, "")
        if (safe === "")
            return
        // `cliphist delete` ignores arguments: it reads "<id>\t…" lines from
        // stdin, like `cliphist list` prints them.
        // Drop it from the list now; the re-list after the command confirms.
        root.entries = root.entries.filter(function (e) { return e.id !== String(id) })
        _run("printf '%s\\t\\n' " + safe + " | cliphist delete")
    }

    function clearAll() {
        root.entries = []
        _run("cliphist wipe")
    }
}
