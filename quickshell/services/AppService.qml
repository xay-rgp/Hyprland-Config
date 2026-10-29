// Desktop entry index for the app launcher (and app-name lookups elsewhere).
//
// Quickshell has no application database, so this parses .desktop files itself.
// Doing it in one `awk` pass over the XDG directories is both faster and far
// more robust than instantiating a FileView per file (which silently stopped
// after the first entry).
//
// Emits one tab-separated record per app:
//   id \t name \t exec \t icon \t comment \t keywords
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../state"

QtObject {
    id: root

    property var apps: []        // { id, name, exec, icon, comment, keywords }
    property bool loaded: false

    property string _buf: ""

    property Process _scan: Process {
        command: ["bash", "-c", root._script()]
        stdout: SplitParser {
            onRead: function (line) {
                if (line !== "")
                    root._buf += line + "\n"
            }
        }
        onExited: function (code) {
            if (code === 0)
                root._parse(root._buf)
            root._buf = ""
            root.loaded = true
        }
    }

    readonly property var dataDirs: {
        var home = Quickshell.env("XDG_DATA_HOME")
                   || ((Quickshell.env("HOME") || "") + "/.local/share")
        var dirs = Quickshell.env("XDG_DATA_DIRS") || "/usr/local/share:/usr/share"
        // User dir first so a local override of the same desktop id wins.
        return [home].concat(dirs.split(":"))
    }

    function _script() {
        var parts = []
        for (var i = 0; i < root.dataDirs.length; i++)
            parts.push("'" + root.dataDirs[i] + "/applications'")

        // One awk program handles every file at once. `id` is the basename; the
        // first occurrence of an id wins (user dirs are listed first).
        // NOTE: awk cannot break a line in the middle of a condition, and the
        // program is assembled as a JS string — so keep each logical statement
        // on ONE line here rather than relying on line continuation.
        var awk = [
            'function flush() {',
            '  if (id == "" || type != "Application" || nodisp == "true" || hidden == "true" || name == "" || exec == "") return',
            '  if (id in seen) return',
            '  seen[id] = 1',
            '  gsub(/;/, " ", kw)',
            '  printf "%s\\t%s\\t%s\\t%s\\t%s\\t%s\\n", id, name, exec, icon, comment, kw',
            '}',
            'FNR == 1 { flush(); id = FILENAME; sub(/^.*\\//, "", id); type=""; nodisp=""; hidden=""; name=""; exec=""; icon=""; comment=""; kw=""; ine=0 }',
            '$0 == "[Desktop Entry]" { ine = 1; next }',
            '/^\\[/ { ine = 0; next }',
            'ine {',
            '  i = index($0, "=")',
            '  if (i == 0) next',
            '  k = substr($0, 1, i - 1)',
            '  v = substr($0, i + 1)',
            '  if (k ~ /\\[/) next',
            '  if (k == "Type") type = v',
            '  else if (k == "NoDisplay") nodisp = v',
            '  else if (k == "Hidden") hidden = v',
            '  else if (k == "Name" && name == "") name = v',
            '  else if (k == "Exec" && exec == "") exec = v',
            '  else if (k == "Icon" && icon == "") icon = v',
            '  else if (k == "Comment" && comment == "") comment = v',
            '  else if (k == "Keywords" && kw == "") kw = v',
            '}',
            'END { flush() }'
        ].join("\n")

        // The awk program must reach awk with REAL newlines. JSON.stringify
        // would emit literal "\n" escapes inside double quotes, which bash
        // passes through unchanged and awk does not interpret — the whole
        // program then collapses to one useless line, yielding zero apps.
        // Single quotes preserve the newlines literally.
        // NUL-delimit the file list: desktop files can have spaces in their
        // names (e.g. Steam games), and a whitespace-split xargs makes awk
        // fatally fail on the fragments, discarding every app.
        return "find " + parts.join(" ") + " -maxdepth 1 -name '*.desktop' -type f -print0 2>/dev/null"
             + " | sort -z | xargs -0 -r awk '" + awk + "'"
    }

    function _parse(raw) {
        if (!raw) {
            root.apps = []
            return
        }
        var out = []
        var lines = raw.split("\n")
        for (var i = 0; i < lines.length; i++) {
            var f = lines[i].split("\t")
            if (f.length < 4)
                continue
            out.push({
                id:       f[0],
                name:     f[1],
                exec:     f[2],
                icon:     f[3] || "",
                comment:  f[4] || "",
                keywords: f[5] || ""
            })
        }
        out.sort(function (a, b) {
            return a.name.toLowerCase() < b.name.toLowerCase() ? -1 : 1
        })
        root.apps = out
    }

    function load() {
        if (_scan.running)
            return
        _scan.running = true
    }

    function search(query) {
        var q = (query || "").toLowerCase()
        if (q === "")
            return root.apps
        var out = []
        for (var i = 0; i < root.apps.length; i++) {
            var a = root.apps[i]
            if (a.name.toLowerCase().indexOf(q) !== -1
                || a.keywords.toLowerCase().indexOf(q) !== -1)
                out.push(a)
        }
        return out
    }

    property Process _run: Process {}

    function launch(app) {
        if (!app || !app.exec)
            return
        // Strip desktop-entry field codes (%u %U %f ...) then launch detached so
        // it survives this process.
        var cmd = app.exec.replace(/%[uUfFdDnNickvm]/g, "").trim()
        _run.command = ["bash", "-c", "setsid " + cmd + " >/dev/null 2>&1 &"]
        _run.running = true
        ShellState.closeAll()
    }
}
