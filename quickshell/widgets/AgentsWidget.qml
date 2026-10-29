// Agents: usage per tab — the Claude subscription, the OpenCode Go
// subscription, and what went through the Bifrost gateway. Data from
// AgentUsageService; the subscriptions refresh every minute while this is
// open, Bifrost every 30 min (cached on disk). R or the refresh button fetches now; Tab /
// Shift+Tab switch tabs. On the Claude tab, Left / Right pick an account and
// Enter switches Claude Code to it (or saves it, when it's a new one).
import QtQuick
import "../theme"
import "../state"
import "../services"
import "../components"

Item {
    id: root

    property bool active: false

    readonly property var claude: AgentUsageService.claude
    // Claude accounts: the picked one (claudePick) is shown, defaulting to
    // the one Claude Code is signed in with.
    readonly property var claudeAccounts: claude && claude.accounts ? claude.accounts : []
    property string claudePick: ""
    readonly property int claudeIndex: {
        var i = claudeAccounts.findIndex(function (a) { return a.uuid === claudePick })
        if (i < 0) i = claudeAccounts.findIndex(function (a) { return a.active })
        return Math.max(0, i)
    }
    readonly property var account: claudeAccounts.length ? claudeAccounts[claudeIndex] : null
    readonly property bool accountOk: !!account && account.ok
    function pickAccount(step) {
        var n = claudeAccounts.length
        if (n > 1) claudePick = claudeAccounts[(claudeIndex + step + n) % n].uuid
    }
    // The header's button: save the signed-in account if it's new, else
    // switch to the picked one.
    function accountButton() {
        if (!account) return
        if (!account.saved) AgentUsageService.addClaudeAccount()
        else if (!account.active) AgentUsageService.useClaudeAccount(account.uuid)
    }
    readonly property var opencode: AgentUsageService.opencode
    readonly property var bifrost: AgentUsageService.bifrost

    // `busy` says which fetch the footer's spinner follows.
    readonly property var tabs: [
        { id: "claude",   name: "Claude",   icon: "\u273b", page: claudePage },
        { id: "opencode", name: "OpenCode", icon: "\uf120", page: opencodePage },
        { id: "bifrost",  name: "Bifrost",  icon: "\uf0e8", page: bifrostPage }
    ]
    readonly property var busy: ({
        claude: AgentUsageService.claudeBusy,
        opencode: AgentUsageService.opencodeBusy,
        bifrost: AgentUsageService.bifrostBusy
    })

    // Remembered in ShellState, so the widget reopens on the last tab.
    readonly property int current: Math.max(0, tabs.findIndex(function (t) {
        return t.id === ShellState.agentsTab
    }))
    function select(i) { ShellState.agentsTab = root.tabs[i].id }

    // "johnsmith99@example.com" -> "john•••••99@example.com": enough to tell
    // accounts apart, not enough to read off the screen.
    function maskEmail(email) {
        if (!email) return ""
        var at = email.lastIndexOf("@")
        if (at < 1) return email
        var user = email.slice(0, at)
        if (user.length <= 3) return user.charAt(0) + "•••" + email.slice(at)
        var head = Math.min(4, Math.ceil(user.length / 3))
        var tail = user.length > 8 ? 2 : 0
        return user.slice(0, head) + "•".repeat(user.length - head - tail)
               + user.slice(user.length - tail) + email.slice(at)
    }

    readonly property int pad: 18

    implicitWidth: 580
    implicitHeight: column.implicitHeight + pad * 2

    focus: active
    onActiveChanged: {
        AgentUsageService.watching = active
        if (active) root.forceActiveFocus()
    }
    Component.onDestruction: AgentUsageService.watching = false

    Keys.onPressed: function (event) {
        if (event.key === Qt.Key_R) {
            AgentUsageService.refresh()
            event.accepted = true
        } else if (root.tabs[root.current].id === "claude"
                   && (event.key === Qt.Key_Left || event.key === Qt.Key_Right
                       || event.key === Qt.Key_H || event.key === Qt.Key_L)) {
            root.pickAccount(event.key === Qt.Key_Right || event.key === Qt.Key_L ? 1 : -1)
            event.accepted = true
        } else if (root.tabs[root.current].id === "claude"
                   && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
            root.accountButton()
            event.accepted = true
        } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_J) {
            root.select((root.current + 1) % root.tabs.length)
            event.accepted = true
        } else if (event.key === Qt.Key_Backtab || event.key === Qt.Key_K) {
            root.select((root.current - 1 + root.tabs.length) % root.tabs.length)
            event.accepted = true
        }
    }

    // Ticks the "resets in" / "updated" labels.
    property date now: new Date()
    Timer {
        interval: 20000
        running: root.active
        repeat: true
        triggeredOnStart: true
        onTriggered: root.now = new Date()
    }

    // ── Formatting ──────────────────────────────────────────────────────────
    function tokens(n) {
        if (n >= 1e9) return (n / 1e9).toFixed(1) + "B"
        if (n >= 1e6) return (n / 1e6).toFixed(1) + "M"
        if (n >= 1e3) return (n / 1e3).toFixed(n >= 1e4 ? 0 : 1) + "k"
        return String(n)
    }
    function money(n) {
        return "$" + (n >= 100 ? n.toFixed(0) : n.toFixed(2))
    }
    function percent(n) {
        return (n >= 99.95 ? "100" : n.toFixed(1)) + "%"
    }
    function count(n) {
        return n >= 1e4 ? tokens(n) : String(n)
    }
    // "in 3h 12m", or the day and time when it's more than a day off.
    function resets(iso) {
        if (!iso) return ""
        var t = new Date(iso)
        var mins = Math.max(0, Math.round((t - root.now) / 60000))
        if (mins >= 24 * 60) return "Resets " + Qt.formatDateTime(t, "ddd HH:mm")
        var h = Math.floor(mins / 60), m = mins % 60
        return "Resets in " + (h > 0 ? h + "h " : "") + m + "m"
    }
    function ago(d) {
        var s = Math.round((root.now - d) / 1000)
        if (d.getTime() === 0) return "never"
        if (s < 60) return "just now"
        if (s < 3600) return Math.floor(s / 60) + "m ago"
        return Math.floor(s / 3600) + "h ago"
    }
    function severityColor(w) {
        if (!w) return Theme.accent
        if (w.percent >= 100 || w.severity === "critical") return Theme.urgent
        if (w.percent >= 75 || w.severity === "warning") return Theme.warning
        return Theme.accent
    }

    // ── Pieces ──────────────────────────────────────────────────────────────
    component Card: Rectangle {
        default property alias content: inner.data
        property alias spacing: inner.spacing

        width: parent.width
        height: inner.implicitHeight + 32
        radius: 16
        color: Theme.surface

        Column {
            id: inner
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
            spacing: 14
        }
    }

    component CardHeader: Row {
        property string glyph
        property color glyphColor: Theme.accent
        property string title
        property string chip
        property string note

        width: parent.width
        spacing: 10

        Rectangle {
            width: 30
            height: 30
            radius: 9
            color: Qt.rgba(parent.glyphColor.r, parent.glyphColor.g, parent.glyphColor.b, 0.16)
            Text {
                anchors.centerIn: parent
                text: parent.parent.glyph
                color: parent.parent.glyphColor
                font.family: Theme.fontFamily
                font.pixelSize: 16
                font.bold: true
            }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: parent.title
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize + 1
            font.bold: true
        }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            visible: parent.chip !== ""
            width: chipText.implicitWidth + 14
            height: 20
            radius: 10
            color: Theme.hover
            Text {
                id: chipText
                anchors.centerIn: parent
                text: parent.parent.chip
                color: Theme.subtext1
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall - 1
                font.bold: true
            }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: text !== ""
            text: parent.note
            color: Theme.subtext0
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
        }
    }

    // A ring that fills to `percent`, with the number in the middle.
    component Gauge: Item {
        id: gauge

        property var    win: null        // { percent, resets_at, severity }
        property string label
        property int    columns: 2
        readonly property real percent: win ? win.percent : 0
        readonly property color tint: root.severityColor(win)

        property real shown: 0
        Behavior on shown { NumberAnimation { duration: 700; easing.type: Easing.OutCubic } }
        onPercentChanged: shown = percent
        Component.onCompleted: shown = percent

        width: (parent.width - parent.spacing * (columns - 1)) / columns
        height: 150

        Canvas {
            id: ring
            width: 104
            height: 104
            anchors.horizontalCenter: parent.horizontalCenter

            property real value: Math.min(100, gauge.shown)
            property color tint: gauge.tint
            onValueChanged: requestPaint()
            onTintChanged: requestPaint()

            onPaint: {
                var ctx = getContext("2d")
                var c = width / 2, r = c - 6, start = Math.PI * 0.75, sweep = Math.PI * 1.5
                ctx.reset()
                ctx.lineCap = "round"
                ctx.lineWidth = 8
                ctx.strokeStyle = Theme.hover
                ctx.beginPath()
                ctx.arc(c, c, r, start, start + sweep)
                ctx.stroke()
                if (value > 0) {
                    ctx.strokeStyle = tint
                    ctx.beginPath()
                    ctx.arc(c, c, r, start, start + sweep * value / 100)
                    ctx.stroke()
                }
            }

            Column {
                anchors.centerIn: parent
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: gauge.win ? Math.round(gauge.shown) + "%" : "–"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 24
                    font.bold: true
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "used"
                    color: Theme.subtext0
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall - 1
                }
            }
        }

        Text {
            id: gaugeLabel
            anchors { top: ring.bottom; topMargin: -4; horizontalCenter: parent.horizontalCenter }
            text: gauge.label
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            font.bold: true
        }
        Text {
            anchors { top: gaugeLabel.bottom; topMargin: 2; horizontalCenter: parent.horizontalCenter }
            text: gauge.win ? root.resets(gauge.win.resets_at) : ""
            color: Theme.subtext0
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
        }
    }

    // A thin labelled meter, for per-model limits and the model list.
    component Meter: Item {
        property string label
        property string value
        property real   fraction: 0
        property color  tint: Theme.accent

        width: parent.width
        height: 30

        Text {
            anchors { left: parent.left; top: parent.top }
            text: parent.label
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            elide: Text.ElideRight
            width: parent.width - valueText.implicitWidth - 12
        }
        Text {
            id: valueText
            anchors { right: parent.right; top: parent.top }
            text: parent.value
            color: Theme.subtext0
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
        }
        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; bottomMargin: 2 }
            height: 5
            radius: 3
            color: Theme.hover
            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, parent.parent.fraction))
                height: parent.height
                radius: 3
                color: parent.parent.tint
                Behavior on width { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
            }
        }
    }

    component Stat: Column {
        property string label
        property string today
        property string week

        width: (parent.width - parent.spacing * 3) / 4
        spacing: 2

        Text {
            text: parent.label
            color: Theme.subtext0
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall - 1
            font.capitalization: Font.AllUppercase
            font.letterSpacing: 0.6
        }
        Text {
            text: parent.today
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeLarge + 2
            font.bold: true
        }
        Text {
            text: parent.week + " this week"
            color: Theme.subtext0
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall - 1
        }
    }

    component Message: Text {
        width: parent.width
        color: Theme.subtext1
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        wrapMode: Text.Wrap
        lineHeight: 1.15
    }

    // Shown in place of a page's numbers when its source has no data yet,
    // failed, or needs a keyring entry (the command to add it).
    component Status: Message {
        property var    data: null
        property string label
        property string keyAttrs     // secret-tool commands, one per line, for setup
        property string loadingText: "Loading…"

        visible: !data || !data.ok
        textFormat: Text.StyledText
        text: !data ? loadingText
            : data.setup
              ? "Add " + label + " to the keyring" + (keyAttrs.indexOf("\n") >= 0 ? "s" : "") + ":<br><br><font color='"
                + Theme.text + "'>" + keyAttrs.split("\n").join("<br>") + "</font>"
            : data.error || ""
    }

    // ── Pages ───────────────────────────────────────────────────────────────
    Component {
        id: claudePage

        Card {
            // Header, with the picked account's state at the right end:
            // signed in, or a button to switch Claude Code to it, or to save
            // it when Claude Code is signed in to one that isn't saved yet.
            Item {
                width: parent.width
                height: 30

                CardHeader {
                    glyph: "✻"
                    glyphColor: Theme.text
                    title: "Claude"
                    chip: root.account && root.account.plan ? root.account.plan.charAt(0).toUpperCase() + root.account.plan.slice(1) : ""
                    note: root.account ? root.maskEmail(root.account.email) : ""
                }

                Text {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    visible: !!root.account && root.account.active && root.account.saved
                    text: "Signed in"
                    color: Theme.subtext0
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                }

                Rectangle {
                    readonly property bool adding: !!root.account && !root.account.saved
                    readonly property bool switching: AgentUsageService.accountAction !== ""

                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    visible: !!root.account && (adding || !root.account.active)
                    width: useText.implicitWidth + 24
                    height: 28
                    radius: 14
                    color: useArea.containsMouse && !switching ? Theme.accent : Theme.hover
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

                    Text {
                        id: useText
                        anchors.centerIn: parent
                        text: parent.adding ? (parent.switching ? "Adding…" : "Add account")
                            : parent.switching ? "Switching…" : "Use this account"
                        color: useArea.containsMouse && !parent.switching ? Theme.crust : Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        font.bold: true
                    }

                    MouseArea {
                        id: useArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.accountButton()
                    }
                }
            }

            // Account picker (● = the one Claude Code is signed in with),
            // only when there's more than one to pick from.
            TabBar {
                visible: root.claudeAccounts.length > 1
                tabs: root.claudeAccounts.map(function (a) {
                    return { name: a.label, icon: a.active ? "\u25cf" : "" }
                })
                current: root.claudeIndex
                onSelected: function (i) { root.claudePick = root.claudeAccounts[i].uuid }
            }

            Message {
                visible: AgentUsageService.accountError !== ""
                text: AgentUsageService.accountError
                color: Theme.urgent
            }

            // The whole source failing (no accounts), else the picked account.
            Status { data: root.claude && root.claude.ok ? root.account : root.claude }

            Row {
                width: parent.width
                spacing: 12
                visible: root.accountOk

                Gauge { label: "Session"; win: root.accountOk ? root.account.session : null }
                Gauge { label: "Weekly";  win: root.accountOk ? root.account.weekly : null }
            }

            // Per-model weekly limits, on plans that have them.
            Repeater {
                model: root.accountOk ? root.account.models : []
                Meter {
                    required property var modelData
                    label: modelData.name + " weekly"
                    value: Math.round(modelData.percent) + "% · " + root.resets(modelData.resets_at)
                    fraction: modelData.percent / 100
                    tint: root.severityColor(modelData)
                }
            }

            Message {
                visible: root.accountOk && root.account.extra.enabled
                text: root.accountOk
                      ? "Extra usage on · " + root.money(root.account.extra.used)
                        + (root.account.extra.limit ? " of " + root.money(root.account.extra.limit) : "") + " spent"
                      : ""
            }
        }
    }

    Component {
        id: opencodePage

        Card {
            CardHeader {
                glyph: ""
                glyphColor: Theme.text
                title: "OpenCode"
                chip: "Go"
            }

            Status {
                data: root.opencode
                label: "an OpenCode API key"
                keyAttrs: 'secret-tool store --label="OpenCode API key" service opencode key api-key'
            }

            Row {
                width: parent.width
                spacing: 8
                visible: !!root.opencode && root.opencode.ok

                Gauge { columns: 3; label: "Rolling"; win: root.opencode ? root.opencode.rolling : null }
                Gauge { columns: 3; label: "Weekly";  win: root.opencode ? root.opencode.weekly : null }
                Gauge { columns: 3; label: "Monthly"; win: root.opencode ? root.opencode.monthly : null }
            }
        }
    }

    Component {
        id: bifrostPage

        Card {
            CardHeader {
                glyph: ""
                glyphColor: Theme.blue
                title: "Bifrost"
                chip: "Gateway"
                note: root.bifrost && root.bifrost.ok
                      ? Math.round(root.bifrost.today.latency / 100) / 10 + "s avg latency today"
                      : ""
            }

            Status {
                data: root.bifrost
                label: "the Bifrost admin login"
                keyAttrs: 'secret-tool store --label="Bifrost admin username" service bifrost key admin-username\n'
                          + 'secret-tool store --label="Bifrost admin password" service bifrost key admin-password'
                loadingText: "Loading… (the weekly stats take a few seconds)"
            }

            Row {
                width: parent.width
                spacing: 12
                visible: !!root.bifrost && root.bifrost.ok

                Stat {
                    label: "Requests"
                    today: root.bifrost && root.bifrost.ok ? root.count(root.bifrost.today.requests) : ""
                    week:  root.bifrost && root.bifrost.ok ? root.count(root.bifrost.week.requests) : ""
                }
                Stat {
                    label: "Tokens"
                    today: root.bifrost && root.bifrost.ok ? root.tokens(root.bifrost.today.tokens) : ""
                    week:  root.bifrost && root.bifrost.ok ? root.tokens(root.bifrost.week.tokens) : ""
                }
                Stat {
                    label: "Output"
                    today: root.bifrost && root.bifrost.ok ? root.tokens(root.bifrost.today.completion) : ""
                    week:  root.bifrost && root.bifrost.ok ? root.tokens(root.bifrost.week.completion) : ""
                }
                // Subscription providers (opencode-go) log no cost, so show
                // the success rate instead of a row of $0.00.
                Stat {
                    readonly property bool costed: !!root.bifrost && root.bifrost.ok && root.bifrost.week.cost >= 0.01
                    label: costed ? "Cost" : "Success"
                    today: !root.bifrost || !root.bifrost.ok ? ""
                         : costed ? root.money(root.bifrost.today.cost)
                         : root.percent(root.bifrost.today.success)
                    week:  !root.bifrost || !root.bifrost.ok ? ""
                         : costed ? root.money(root.bifrost.week.cost)
                         : root.percent(root.bifrost.week.success)
                }
            }

            // Top models this week, by tokens.
            Column {
                width: parent.width
                spacing: 8
                visible: !!root.bifrost && root.bifrost.ok && root.bifrost.models.length > 0

                Text {
                    text: "Top models · 7 days"
                    color: Theme.subtext0
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall - 1
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: 0.6
                }

                Repeater {
                    model: root.bifrost && root.bifrost.ok ? root.bifrost.models : []
                    Meter {
                        required property var modelData
                        required property int index
                        label: modelData.model + (modelData.provider ? "  ·  " + modelData.provider : "")
                        value: root.tokens(modelData.tokens) + " · " + modelData.requests + " req"
                               + (modelData.cost > 0 ? " · " + root.money(modelData.cost) : "")
                        fraction: root.bifrost.models[0].tokens > 0 ? modelData.tokens / root.bifrost.models[0].tokens : 0
                        tint: Theme.blue
                        opacity: 1 - index * 0.12
                    }
                }
            }
        }
    }

    // ── Layout ──────────────────────────────────────────────────────────────
    Column {
        id: column
        anchors { top: parent.top; left: parent.left; right: parent.right; margins: root.pad }
        spacing: 14

        // Header: title + tabs
        Item {
            width: parent.width
            height: 36

            Text {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                text: "Agents"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLarge + 2
                font.bold: true
            }

            TabBar {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                tabs: root.tabs
                current: root.current
                onSelected: function (i) { root.select(i) }
            }
        }

        // The current tab's page: fades and nudges up into place.
        Item {
            width: parent.width
            height: page.item ? page.item.height : 0

            Loader {
                id: page
                width: parent.width
                sourceComponent: root.tabs[root.current].page
                onLoaded: enter.restart()
            }

            ParallelAnimation {
                id: enter
                NumberAnimation { target: page; property: "opacity"; from: 0; to: 1; duration: Theme.animDuration; easing.type: Easing.OutCubic }
                NumberAnimation { target: page; property: "y"; from: 10; to: 0; duration: Theme.animDuration; easing.type: Easing.OutCubic }
            }
        }

        // Footer: freshness + refresh
        Row {
            anchors.right: parent.right
            spacing: 8

            readonly property bool spinning: !!root.busy[root.tabs[root.current].id]

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: parent.spinning ? "Updating…" : "Updated " + root.ago(AgentUsageService.fetchedAt)
                color: Theme.subtext0
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
            }

            Rectangle {
                width: 28
                height: 28
                radius: 14
                color: refreshArea.containsMouse ? Theme.hover : "transparent"

                Icon {
                    id: refreshIcon
                    anchors.centerIn: parent
                    text: ""
                    color_: refreshArea.containsMouse ? Theme.text : Theme.subtext0
                    font.pixelSize: 13

                    RotationAnimation on rotation {
                        running: refreshIcon.parent.parent.spinning
                        loops: Animation.Infinite
                        from: 0; to: 360
                        duration: 900
                        onRunningChanged: if (!running) refreshIcon.rotation = 0
                    }
                }

                MouseArea {
                    id: refreshArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: AgentUsageService.refresh()
                }
            }
        }
    }
}
