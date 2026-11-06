import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls 2.15

// GrantOS login screen: chamfered gunmetal card with two-tone ember trim,
// matching the System Monitor / boot art language. No decorative glow.
Rectangle {
    id: root
    width: Screen.width
    height: Screen.height
    color: "#0b0d0e"

    Image {
        anchors.fill: parent
        source: "background.png"
        fillMode: Image.PreserveAspectCrop
        cache: false
    }
    Rectangle { anchors.fill: parent; color: Qt.rgba(0, 0, 0, 0.25) }

    function chamfer(ctx, x, y, w, h, c) {
        ctx.beginPath()
        ctx.moveTo(x + c, y)
        ctx.lineTo(x + w - c, y)
        ctx.lineTo(x + w, y + c)
        ctx.lineTo(x + w, y + h - c)
        ctx.lineTo(x + w - c, y + h)
        ctx.lineTo(x + c, y + h)
        ctx.lineTo(x, y + h - c)
        ctx.lineTo(x, y + c)
        ctx.closePath()
    }

    function doLogin() {
        if (!userModel || userModel.count === 0)
            return
        var i = userList.currentIndex >= 0 ? userList.currentIndex : 0
        sddm.login(userModel.get(i).name, passInput.text,
                   sessionCombo.currentIndex)
    }

    Item {
        id: card
        width: 430
        height: 372
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -16

        Canvas {
            id: bg
            anchors.fill: parent
            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                chamfer(ctx, 2, 2, width - 4, height - 4, 16)
                ctx.fillStyle = Qt.rgba(15 / 255, 17 / 255, 19 / 255, 0.93)
                ctx.fill()
                chamfer(ctx, 2, 2, width - 4, height - 4, 16)
                ctx.strokeStyle = "#a3541f"
                ctx.lineWidth = 5
                ctx.stroke()
                chamfer(ctx, 2, 2, width - 4, height - 4, 16)
                ctx.strokeStyle = "#d67a3c"
                ctx.lineWidth = 2
                ctx.stroke()
                // header accent rule: ember segment + grey hairline
                ctx.fillStyle = "#d67a3c"
                ctx.fillRect(18, 78, 150, 3)
                ctx.fillStyle = Qt.rgba(1, 1, 1, 0.08)
                ctx.fillRect(172, 79, width - 190, 1)
            }
        }

        Image {
            x: 18; y: 16
            width: 46; height: 46
            source: "logo.png"
            smooth: true
        }
        Column {
            x: 74; y: 18
            spacing: 2
            Text {
                text: "GrantOS"
                color: "#e8eaeb"
                font.pixelSize: 22
                font.bold: true
                font.family: "Inter"
                font.letterSpacing: 2
            }
            Text {
                text: "1.0 — anvil"
                color: "#8b9296"
                font.pixelSize: 11
                font.family: "Inter"
                font.letterSpacing: 3
            }
        }
        Text {
            id: clock
            anchors.right: parent.right
            anchors.rightMargin: 20
            y: 26
            text: Qt.formatTime(new Date(), "hh:mm")
            color: "#c7cbcd"
            font.pixelSize: 15
            font.family: "Inter"
            Timer {
                running: true
                repeat: true
                interval: 10000
                onTriggered: clock.text = Qt.formatTime(new Date(), "hh:mm")
            }
        }

        // user selection (single-user GrantOS: one chip; still handles more)
        ListView {
            id: userList
            model: userModel
            x: 18
            width: parent.width - 36
            y: 96
            height: count > 1 ? Math.min(count, 3) * 44 : 44
            spacing: 4
            currentIndex: 0
            delegate: Item {
                width: userList.width
                height: 40
                Rectangle {
                    anchors.fill: parent
                    color: ListView.isCurrentItem ? "#1d2124" : "#17191b"
                    border.color: ListView.isCurrentItem ? "#d67a3c" : "#2a2f33"
                    border.width: 1
                }
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    spacing: 10
                    Image {
                        width: 26; height: 26
                        source: icon
                        fillMode: Image.PreserveAspectCrop
                        cache: false
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: displayName
                        color: "#e8eaeb"
                        font.pixelSize: 14
                        font.family: "Inter"
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: userList.currentIndex = index
                }
            }
        }

        Rectangle {
            id: passBox
            x: 18
            y: userList.y + userList.height + 12
            width: parent.width - 36
            height: 40
            color: "#101315"
            border.color: passInput.activeFocus ? "#d67a3c" : "#2a2f33"
            border.width: passInput.activeFocus ? 2 : 1
            Text {
                visible: passInput.text.length === 0
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 12
                text: sddm.tr["Password"]
                color: "#6d7478"
                font.pixelSize: 13
                font.family: "Inter"
            }
            TextInput {
                id: passInput
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                verticalAlignment: TextInput.AlignVCenter
                echoMode: TextInput.Password
                passwordCharacter: "\u2022"
                color: "#e8eaeb"
                selectionColor: "#d67a3c"
                font.pixelSize: 14
                font.family: "Inter"
                clip: true
                onAccepted: root.doLogin()
            }
        }

        Rectangle {
            id: loginBtn
            x: 18
            y: passBox.y + passBox.height + 14
            width: parent.width - 36
            height: 40
            color: btnArea.containsMouse ? "#e08a4a" : "#d67a3c"
            border.color: "#a3541f"
            border.width: 2
            Text {
                anchors.centerIn: parent
                text: "LOG IN"
                color: "#0f1113"
                font.pixelSize: 14
                font.bold: true
                font.family: "Inter"
                font.letterSpacing: 3
            }
            MouseArea {
                id: btnArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.doLogin()
            }
        }

        Row {
            x: 18
            y: loginBtn.y + loginBtn.height + 12
            spacing: 14
            ComboBox {
                id: sessionCombo
                model: sessionModel
                currentIndex: sessionModel && sessionModel.lastIndex >= 0
                              ? sessionModel.lastIndex : 0
                textRole: "name"
                width: 170
                height: 30
                font.family: "Inter"
                font.pixelSize: 11
            }
            Repeater {
                model: [
                    { text: "SUSPEND",  enabled: sddm.canSuspend,  act: "suspend" },
                    { text: "REBOOT",   enabled: sddm.canReboot,   act: "reboot" },
                    { text: "SHUT DOWN", enabled: sddm.canPowerOff, act: "powerOff" }
                ]
                Text {
                    visible: modelData.enabled
                    text: modelData.text
                    color: pmArea.containsMouse ? "#d67a3c" : "#8b9296"
                    font.pixelSize: 11
                    font.bold: true
                    font.family: "Inter"
                    font.letterSpacing: 1
                    MouseArea {
                        id: pmArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: sddm[modelData.act]()
                    }
                }
            }
        }
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            passBox.border.color = "#c0392b"
            passInput.text = ""
        }
    }

    Component.onCompleted: passInput.forceActiveFocus()
}
