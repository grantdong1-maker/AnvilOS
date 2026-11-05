/*
    GrantOS System Monitor — rugged-tablet style hardware + process overlay.
    Frameless, always-on-top, draggable. Tabs: Overview (sensors + graphs)
    and Processes (live table with end-task). Data + kill channel come from
    /usr/share/grantos-monitor/collect.py.
    Runs on the Qt6 qml6 runtime in the image; versioned imports keep it
    Qt5-compatible too (useful for quick host previews).
    SPDX-License-Identifier: MIT
*/
import QtQuick 2.15
import QtQuick.Window 2.15

Window {
    id: win
    width: 660
    height: 470
    visible: true
    title: "System Monitor"
    color: "transparent"
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.Tool
    x: 40
    y: 40

    // ---- palette ----------------------------------------------------------
    readonly property color ember: "#d67a3c"
    readonly property color labelCol: "#9aa0a6"
    readonly property color valueCol: "#ffffff"
    readonly property color unitCol: "#8b9199"
    readonly property color barBg: "#22262a"
    readonly property color gridCol: "#1d2124"
    readonly property int chamfer: 26

    property int tab: 0                    // 0 = overview, 1 = processes

    function loadColor(v) {
        if (v === undefined || v === null) return "#555a60"
        if (v < 60) return "#39f900"
        if (v < 90) return "#fdfd09"
        return "#b22222"
    }

    // hex + alpha -> CSS rgba() (Qt.alpha is Qt6-only; Canvas accepts strings)
    function rgba(hex, a) {
        var r = parseInt(hex.substr(1, 2), 16)
        var g = parseInt(hex.substr(3, 2), 16)
        var b = parseInt(hex.substr(5, 2), 16)
        return "rgba(" + r + "," + g + "," + b + "," + a + ")"
    }

    // ---- data -------------------------------------------------------------
    property var d: ({})
    property var procs: []
    property string sortKey: "cpu"
    property bool sortDesc: true
    property int sel: -1
    property var hist: ({ gpu: [], cpu: [], temp: [], clk: [] })
    readonly property string dataPath: "file:///run/user/1000/grantos-monitor.json"
    readonly property string dataFallback: "file:///tmp/grantos-monitor.json"
    property bool useFallback: false

    function resort() {
        var a = (win.d.processes || []).slice()
        var k = win.sortKey
        a.sort(function (x, y) {
            var v = (k === "name") ? String(x.name).localeCompare(String(y.name))
                                   : (x[k] - y[k])
            return win.sortDesc ? -v : v
        })
        win.procs = a
    }

    function poll() {
        var x = new XMLHttpRequest()
        x.open("GET", (useFallback ? dataFallback : dataPath) + "?t=" + Date.now(), false)
        try { x.send() } catch (e) { return }
        if (x.responseText === "") {
            if (!useFallback) { useFallback = true; poll() }
            return
        }
        try { d = JSON.parse(x.responseText) } catch (e) { return }
        var g = d.gpu || {}, c = d.cpu || {}
        function push(a, v, n) {
            if (v === undefined || v === null) return
            a.push(v)
            if (a.length > n) a.shift()
        }
        push(hist.gpu, g.load, 120)
        push(hist.cpu, c.load, 120)
        push(hist.temp, g.temp, 120)
        push(hist.clk, g.coreClk, 120)
        resort()
        graph.requestPaint()
    }

    function kill(sig) {
        if (win.sel < 0 || !win.procs[win.sel]) return
        var x = new XMLHttpRequest()
        x.open("POST", "http://127.0.0.1:47823/kill?pid=" + win.procs[win.sel].pid + "&sig=" + sig, false)
        try { x.send("") } catch (e) {}
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: win.poll()
    }

    // ---- chamfered panel background ----------------------------------------
    Canvas {
        id: panel
        anchors.fill: parent
        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            var c = win.chamfer
            function path(inset) {
                var i = inset
                ctx.beginPath()
                ctx.moveTo(c + i, i)
                ctx.lineTo(width - c - i, i)
                ctx.lineTo(width - i, c + i)
                ctx.lineTo(width - i, height - c - i)
                ctx.lineTo(width - c - i, height - i)
                ctx.lineTo(c + i, height - i)
                ctx.lineTo(i, height - c - i)
                ctx.lineTo(i, c + i)
                ctx.closePath()
            }

            // drop shadow — tight, not wide (impeccable: edge OR shadow)
            ctx.save()
            ctx.shadowColor = Qt.rgba(0, 0, 0, 0.6)
            ctx.shadowBlur = 10
            ctx.shadowOffsetY = 3
            path(1.5)
            ctx.fillStyle = "#0a0b0d"
            ctx.fill()
            ctx.restore()

            // body: vertical metal gradient
            path(1.5)
            var g = ctx.createLinearGradient(0, 0, 0, height)
            g.addColorStop(0, Qt.rgba(0.14, 0.16, 0.18, 0.95))
            g.addColorStop(0.45, Qt.rgba(0.07, 0.08, 0.09, 0.95))
            g.addColorStop(1, Qt.rgba(0.045, 0.05, 0.06, 0.96))
            ctx.fillStyle = g
            ctx.fill()

            // interior shading, clipped to the panel
            ctx.save()
            path(1.5)
            ctx.clip()
            // metallic header band with hard scribe line
            var hg = ctx.createLinearGradient(0, 0, 0, 46)
            hg.addColorStop(0, Qt.rgba(1, 1, 1, 0.08))
            hg.addColorStop(0.55, Qt.rgba(1, 1, 1, 0.02))
            hg.addColorStop(0.57, Qt.rgba(0, 0, 0, 0.18))
            hg.addColorStop(1, Qt.rgba(0, 0, 0, 0.28))
            ctx.fillStyle = hg
            ctx.fillRect(0, 0, width, 46)
            // accent rule under the header: ember segment + grey hairline
            ctx.fillStyle = "#d67a3c"
            ctx.fillRect(18, 45, 192, 3)
            ctx.fillStyle = Qt.rgba(255, 255, 255, 0.08)
            ctx.fillRect(214, 46, width - 232, 1)
            // diagonal sheen across the body
            var sg = ctx.createLinearGradient(0, 0, width, height * 0.7)
            sg.addColorStop(0, Qt.rgba(1, 1, 1, 0.0))
            sg.addColorStop(0.32, Qt.rgba(1, 1, 1, 0.035))
            sg.addColorStop(0.5, Qt.rgba(1, 1, 1, 0.0))
            ctx.fillStyle = sg
            ctx.fillRect(0, 0, width, height)
            // floor shadow at the bottom edge
            var fg = ctx.createLinearGradient(0, height - 40, 0, height)
            fg.addColorStop(0, Qt.rgba(0, 0, 0, 0))
            fg.addColorStop(1, Qt.rgba(0, 0, 0, 0.35))
            ctx.fillStyle = fg
            ctx.fillRect(0, height - 40, width, 40)
            ctx.restore()

            // ember trim: dark base + bright core, no glow (impeccable:
            // "dark mode with glowing accents" — keep edges quiet)
            ctx.save()
            path(1.5)
            ctx.strokeStyle = "#a3541f"
            ctx.lineWidth = 6
            ctx.stroke()
            path(1.5)
            ctx.strokeStyle = "#d67a3c"
            ctx.lineWidth = 3
            ctx.stroke()
            // inner bevel highlight just inside the trim
            path(7)
            ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.06)
            ctx.lineWidth = 1
            ctx.stroke()
            ctx.restore()

            // bright ticks on the four chamfer cuts
            ctx.strokeStyle = "#f0954f"
            ctx.lineWidth = 2
            var t = c * 0.28
            ctx.beginPath(); ctx.moveTo(t, c - t); ctx.lineTo(c - t, t); ctx.stroke()
            ctx.beginPath(); ctx.moveTo(width - c + t, t); ctx.lineTo(width - t, c - t); ctx.stroke()
            ctx.beginPath(); ctx.moveTo(width - t, height - c + t); ctx.lineTo(width - c + t, height - t); ctx.stroke()
            ctx.beginPath(); ctx.moveTo(c - t, height - t); ctx.lineTo(t, height - c + t); ctx.stroke()

            // rivets with sphere shading
            var rv = [[c + 12, 18], [width - c - 18, 18],
                      [c + 12, height - 24], [width - c - 18, height - 24]]
            for (var i = 0; i < 4; i++) {
                var x = rv[i][0], y = rv[i][1]
                var rg = ctx.createRadialGradient(x, y, 0.5, x + 1, y + 1, 4.5)
                rg.addColorStop(0, "#7a828c")
                rg.addColorStop(0.6, "#3a4046")
                rg.addColorStop(1, "#181b1e")
                ctx.fillStyle = rg
                ctx.beginPath()
                ctx.arc(x, y, 4, 0, 2 * Math.PI)
                ctx.fill()
                ctx.strokeStyle = Qt.rgba(0, 0, 0, 0.55)
                ctx.lineWidth = 1
                ctx.stroke()
            }

            // notch tab: ember gradient + dark edge
            ctx.beginPath()
            ctx.moveTo(c, 0)
            ctx.lineTo(c + 178, 0)
            ctx.lineTo(c + 158, 20)
            ctx.lineTo(c, 20)
            ctx.closePath()
            var tg = ctx.createLinearGradient(0, 0, 0, 20)
            tg.addColorStop(0, "#ef8f47")
            tg.addColorStop(1, "#a85a20")
            ctx.fillStyle = tg
            ctx.fill()
            ctx.strokeStyle = "#6e3a12"
            ctx.lineWidth = 1
            ctx.stroke()
        }
        Component.onCompleted: requestPaint()
        onWidthChanged: requestPaint()
    }

    // drag to move — declared early so tabs/close buttons stay clickable on top
    MouseArea {
        anchors.left: parent.left
        anchors.right: parent.right
        height: 42
        property real lastX: 0
        property real lastY: 0
        onPressed: { lastX = mouse.x; lastY = mouse.y }
        onPositionChanged: {
            if (!pressed) return
            win.x += mouse.x - lastX
            win.y += mouse.y - lastY
        }
    }

    Text {
        x: win.chamfer + 10
        y: 2
        text: "SYSTEM MONITOR"
        font.pixelSize: 13
        font.bold: true
        color: "#0f1113"
    }

    // tabs
    Row {
        x: 218
        y: 26
        spacing: 18
        Repeater {
            model: ["OVERVIEW", "PROCESSES"]
            Item {
                width: tabText.width
                height: 20
                Text {
                    id: tabText
                    text: modelData
                    color: win.tab === index ? "#ffffff" : win.labelCol
                    font.pixelSize: 13
                    font.bold: win.tab === index
                }
                Rectangle {
                    visible: win.tab === index
                    width: tabText.width
                    height: 2
                    color: win.ember
                    anchors.bottom: parent.bottom
                }
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { win.tab = index; win.sel = -1 }
                }
            }
        }
    }

    Text {
        anchors.right: parent.right
        anchors.rightMargin: win.chamfer + 26
        y: 26
        text: win.d.time || ""
        color: win.unitCol
        font.pixelSize: 13
    }

    Rectangle {
        id: closeBtn
        anchors.right: parent.right
        anchors.rightMargin: 10
        y: 22
        width: 20
        height: 20
        color: closeMa.containsMouse ? "#b22222" : "transparent"
        border.color: "#555a60"
        Text {
            anchors.centerIn: parent
            text: "\u00d7"
            color: "#c8ccd1"
            font.pixelSize: 16
        }
        MouseArea {
            id: closeMa
            anchors.fill: parent
            hoverEnabled: true
            onClicked: Qt.exit(0)
        }
    }

    // ---- accessors ----------------------------------------------------------
    function g(field) { return win.d.gpu && win.d.gpu[field] !== undefined ? win.d.gpu[field] : null }
    function c(field) { return win.d.cpu && win.d.cpu[field] !== undefined ? win.d.cpu[field] : null }
    function str(v)   { return v === null || v === undefined ? "--" : v }

    property int gpuLoad: g("load") === null ? 0 : Math.round(g("load"))
    property int cpuLoad: c("load") === null ? 0 : Math.round(c("load"))
    property string cpuMhzStr: c("mhz") === null ? "--" : (c("mhz") / 1000).toFixed(1)
    property real ramFrac: win.d.ram ? Math.min(1, win.d.ram.used / win.d.ram.total) : -1
    property string ramStr: win.d.ram ? win.d.ram.used.toFixed(1) : "--"
    property string diskStr: win.d.disk ? win.d.disk.read.toFixed(0) + "/" + win.d.disk.write.toFixed(0) : "--"
    property string netStr: win.d.net ? win.d.net.rx.toFixed(1) + "/" + win.d.net.tx.toFixed(1) : "--"
    property real vramFrac: win.d.gpu && win.d.gpu.vramTotal ? Math.min(1, win.d.gpu.vramUsed / win.d.gpu.vramTotal) : -1
    property string vramStr: win.d.gpu && win.d.gpu.vramTotal ? win.d.gpu.vramUsed.toFixed(1) : "--"

    // ==================== TAB 0: OVERVIEW ====================
    Item {
        id: overview
        anchors.fill: parent
        visible: win.tab === 0

        Column {
            x: 18
            y: 52
            spacing: 4
            StatRow { label: "GPU";  frac: gpuLoad / 100; barColor: win.loadColor(gpuLoad)
                      value: g("load") === null ? "--" : gpuLoad; unit: "%" }
            StatRow { label: "CORE"; value: str(g("coreClk")); unit: "MHz" }
            StatRow { label: "MEM";  value: str(g("memClk"));  unit: "MHz" }
            StatRow { label: "VOLT"; value: str(g("volt"));    unit: "V" }
            StatRow { label: "TEMP"; frac: g("temp") === null ? -1 : Math.min(1, g("temp") / 110)
                      barColor: win.loadColor(Math.min(100, g("temp") === null ? 0 : g("temp") / 1.1))
                      value: str(g("temp")); unit: "\u00b0C" }
            StatRow { label: "POWER"; value: str(g("power")); unit: "W" }
            StatRow { label: "FAN";  frac: g("fan") === null ? -1 : Math.min(1, g("fan") / 100)
                      barColor: unitCol; value: str(g("fan")); unit: "%" }
            StatRow { label: "VRAM"; frac: vramFrac; barColor: win.ember
                      value: vramStr; unit: "GB" }
        }

        Column {
            x: 342
            y: 52
            spacing: 4
            StatRow { label: "CPU"; frac: cpuLoad / 100; barColor: win.loadColor(cpuLoad)
                      value: c("load") === null ? "--" : cpuLoad; unit: "%" }
            StatRow { label: "MHZ"; value: cpuMhzStr; unit: "GHz" }
            StatRow { label: "TEMP"; value: str(c("temp")); unit: "\u00b0C" }
            StatRow { label: "RAM"; frac: ramFrac; barColor: "#c8ccd1"
                      value: ramStr; unit: "GB" }
            StatRow { label: "DISK"; value: diskStr; unit: "MB/s" }
            StatRow { label: "NET"; value: netStr; unit: "Mb/s" }
            Item {
                width: 300
                height: 46
                Text { text: "CORES"; color: win.labelCol; font.pixelSize: 11 }
                Row {
                    anchors.bottom: parent.bottom
                    spacing: 3
                    Repeater {
                        model: win.d.cpu && win.d.cpu.cores ? win.d.cpu.cores : []
                        Rectangle {
                            width: 12
                            height: 30
                            color: "#15181a"
                            border.color: Qt.rgba(0, 0, 0, 0.6)
                            Rectangle {
                                width: parent.width - 2
                                height: (parent.height - 2) * Math.min(1, modelData / 100)
                                anchors.bottom: parent.bottom
                                anchors.horizontalCenter: parent.horizontalCenter
                                color: win.loadColor(modelData)
                                Rectangle {
                                    anchors.top: parent.top
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    height: parent.height / 2
                                    color: Qt.rgba(1, 1, 1, 0.22)
                                }
                            }
                        }
                    }
                }
            }
        }

        Canvas {
            id: graph
            x: 18
            y: 340
            width: 624
            height: 78
            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                // recessed well background
                var bg = ctx.createLinearGradient(0, 0, 0, height)
                bg.addColorStop(0, "#050607")
                bg.addColorStop(0.25, "#0b0d0f")
                bg.addColorStop(1, "#0e1113")
                ctx.fillStyle = bg
                ctx.fillRect(0, 0, width, height)
                ctx.strokeStyle = win.gridCol
                for (var gy = 0; gy <= height; gy += height / 4) {
                    ctx.beginPath(); ctx.moveTo(4, gy); ctx.lineTo(width - 4, gy); ctx.stroke()
                }
                function pts(a, scaleMax) {
                    var p = []
                    for (var i = 0; i < a.length; i++) {
                        var v = Math.min(1, a[i] / scaleMax)
                        p.push([width * i / 119, height - v * (height - 8) - 4])
                    }
                    return p
                }
                function series(a, color, scaleMax, area) {
                    if (a.length < 2) return
                    var p = pts(a, scaleMax)
                    if (area) {
                        var ag = ctx.createLinearGradient(0, 0, 0, height)
                        ag.addColorStop(0, win.rgba(color, 0.28))
                        ag.addColorStop(1, win.rgba(color, 0.02))
                        ctx.beginPath()
                        ctx.moveTo(p[0][0], height)
                        for (var i = 0; i < p.length; i++) ctx.lineTo(p[i][0], p[i][1])
                        ctx.lineTo(p[p.length - 1][0], height)
                        ctx.closePath()
                        ctx.fillStyle = ag
                        ctx.fill()
                    }
                    ctx.strokeStyle = color
                    ctx.lineWidth = 2
                    ctx.beginPath()
                    for (var j = 0; j < p.length; j++) {
                        if (j === 0) ctx.moveTo(p[j][0], p[j][1]); else ctx.lineTo(p[j][0], p[j][1])
                    }
                    ctx.stroke()
                }
                series(win.hist.clk, "#d67a3c", 3000, false)
                series(win.hist.temp, "#b22222", 110, false)
                series(win.hist.cpu, "#fdfd09", 100, false)
                series(win.hist.gpu, "#39f900", 100, true)
            }
        }

        Row {
            x: 34
            y: 424
            spacing: 14
            Repeater {
                model: [["GPU", "#39f900"], ["CPU", "#fdfd09"],
                        ["TEMP", "#b22222"], ["CLK", "#d67a3c"]]
                Text { text: modelData[0]; color: modelData[1]; font.pixelSize: 10 }
            }
        }
    }

    // ==================== TAB 1: PROCESSES ====================
    Item {
        id: procsTab
        anchors.fill: parent
        visible: win.tab === 1

        // recessed well behind the table
        Rectangle {
            x: 18
            y: 52
            width: 624
            height: 354
            color: "#0c0e10"
            border.color: Qt.rgba(0, 0, 0, 0.65)
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 12
                color: Qt.rgba(0, 0, 0, 0.35)
            }
        }

        // header row (click NAME / CPU / MEM to sort)
        Item {
            id: header
            x: 18
            y: 52
            width: 624
            height: 22
            Repeater {
                model: [
                    { key: "name", label: "NAME", x: 8,  w: 250, right: false },
                    { key: "pid",  label: "PID",  x: 268, w: 60, right: true },
                    { key: "cpu",  label: "CPU%", x: 340, w: 70, right: true },
                    { key: "mem",  label: "MEM MB", x: 420, w: 90, right: true }
                ]
                Item {
                    x: modelData.x
                    y: 0
                    width: modelData.w
                    height: 22
                    Text {
                        id: hText
                        anchors.right: modelData.right ? parent.right : undefined
                        anchors.left: modelData.right ? undefined : parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.label
                        color: win.sortKey === modelData.key ? win.ember : win.labelCol
                        font.pixelSize: 11
                        font.bold: win.sortKey === modelData.key
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            var k = modelData.key
                            if (win.sortKey === k) win.sortDesc = !win.sortDesc
                            else { win.sortKey = k; win.sortDesc = (k !== "name") }
                            win.resort()
                        }
                    }
                }
            }
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: win.barBg }
        }

        ListView {
            id: list
            x: 18
            y: 76
            width: 624
            height: 330
            clip: true
            model: win.procs

            delegate: Rectangle {
                width: list.width
                height: 22
                color: index === win.sel ? "#2a2f34" : (index % 2 ? "#14171a" : "#181b1e")
                property Gradient selG: Gradient {
                    GradientStop { position: 0.0; color: "#343a41" }
                    GradientStop { position: 1.0; color: "#21252a" }
                }
                gradient: index === win.sel ? selG : null
                Rectangle { anchors.left: parent.left; width: 2; height: parent.height
                            color: win.ember; visible: index === win.sel }
                Text { x: 8; width: 250; anchors.verticalCenter: parent.verticalCenter
                       text: modelData.name; color: "#e6e8ea"
                       font.pixelSize: 12; elide: Text.ElideRight }
                Text { x: 268; width: 60; anchors.verticalCenter: parent.verticalCenter
                       horizontalAlignment: Text.AlignRight
                       text: modelData.pid; color: win.labelCol; font.pixelSize: 12 }
                Text { x: 340; width: 70; anchors.verticalCenter: parent.verticalCenter
                       horizontalAlignment: Text.AlignRight
                       text: modelData.cpu.toFixed(1)
                       color: win.loadColor(modelData.cpu); font.pixelSize: 12 }
                Text { x: 420; width: 90; anchors.verticalCenter: parent.verticalCenter
                       horizontalAlignment: Text.AlignRight
                       text: modelData.mem.toFixed(1); color: "#c8ccd1"; font.pixelSize: 12 }
                MouseArea {
                    anchors.fill: parent
                    onClicked: win.sel = index
                    onDoubleClicked: win.kill(15)
                }
            }
        }

        // end-task bar
        Row {
            x: 18
            y: 418
            spacing: 10
            Repeater {
                model: [["END TASK", 15], ["KILL", 9]]
                Rectangle {
                    width: 110
                    height: 26
                    color: ma.containsMouse ? "#22272b" : "#121518"
                    border.color: modelData[1] === 9 ? "#b22222" : win.ember
                    // gloss + bottom shade
                    Rectangle {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: parent.height / 2
                        color: Qt.rgba(1, 1, 1, 0.05)
                    }
                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 6
                        color: Qt.rgba(0, 0, 0, 0.30)
                    }
                    Text {
                        anchors.centerIn: parent
                        text: modelData[0]
                        color: win.sel >= 0 ? "#ffffff" : "#555a60"
                        font.pixelSize: 11
                        font.bold: true
                    }
                    MouseArea {
                        id: ma
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: win.sel >= 0
                        onClicked: win.kill(modelData[1])
                    }
                }
            }
        }

        Text {
            x: 260
            y: 423
            color: win.labelCol
            font.pixelSize: 10
            text: win.sel >= 0 && win.procs[win.sel]
                  ? "PID " + win.procs[win.sel].pid + " \u00b7 " + win.procs[win.sel].name
                  : "select a process \u00b7 double-click = END TASK"
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 24
            y: 423
            color: win.unitCol
            font.pixelSize: 10
            text: (win.procs ? win.procs.length : 0) + " processes"
        }
    }

    // ---- preview/snap mode (testing only) -----------------------------------
    // /tmp/grantos-hud-snap containing "1" (overview) or "2" (processes):
    // render once, save a PNG, exit.
    Timer {
        id: snapTimer
        interval: 800
        onTriggered: {
            win.contentItem.grabToImage(function (r) {
                r.saveToFile("/tmp/grantos-hud-preview" + (win.tab === 1 ? "-procs" : "") + ".png")
                Qt.exit(0)
            })
        }
    }

    Component.onCompleted: {
        poll()
        var probe = new XMLHttpRequest()
        probe.open("GET", "file:///tmp/grantos-hud-snap", false)
        try { probe.send() } catch (e) { return }
        if (probe.responseText.indexOf("1") === -1 && probe.responseText.indexOf("2") === -1) return
        if (probe.responseText.indexOf("2") !== -1) win.tab = 1
        var g0 = (win.d.gpu || {}), c0 = (win.d.cpu || {})
        for (var i = 0; i < 120; i++) {
            hist.gpu.push(g0.load === undefined ? 60 : 60 + 25 * Math.sin(i / 9) + (i % 7))
            hist.cpu.push(35 + 20 * Math.sin(i / 6 + 2) + (i % 5))
            hist.temp.push(60 + 12 * Math.sin(i / 14))
            hist.clk.push(1750 + 180 * Math.sin(i / 11 + 1))
        }
        graph.requestPaint()
        snapTimer.running = true
    }
}
