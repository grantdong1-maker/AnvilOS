/*
    GrantOS session startup splash.
    Based on KDE's breeze Splash.qml (SPDX-FileCopyrightText: 2014 Marco Martin
    <mart@kde.org>, SPDX-License-Identifier: GPL-2.0-or-later), rebranded:
    anvil mark, GrantOS caption, no KDE branding.
*/

import QtQuick
import org.kde.kirigami 2 as Kirigami

Rectangle {
    id: root
    color: "#17191b"

    property int stage

    onStageChanged: {
        if (stage == 2) {
            introAnimation.running = true;
        } else if (stage == 5) {
            introAnimation.target = busyIndicator;
            introAnimation.from = 1;
            introAnimation.to = 0;
            introAnimation.running = true;
        }
    }

    Item {
        id: content
        anchors.fill: parent
        opacity: 0

        Image {
            id: logo
            anchors.centerIn: parent
            width: parent.width * 0.42
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            source: "/usr/share/grantos-art/plymouth-logo.png"
        }

        Image {
            id: busyIndicator
            y: parent.height - (parent.height - logo.y) / 2 - height/2
            anchors.horizontalCenter: parent.horizontalCenter
            asynchronous: true
            source: "images/busywidget.svgz"
            sourceSize.height: Kirigami.Units.gridUnit * 2
            sourceSize.width: Kirigami.Units.gridUnit * 2
            RotationAnimator on rotation {
                from: 0
                to: 360
                duration: 2000
                loops: Animation.Infinite
                running: Kirigami.Units.longDuration > 1
            }
        }

        Text {
            anchors {
                bottom: parent.bottom
                horizontalCenter: parent.horizontalCenter
                margins: Kirigami.Units.gridUnit
            }
            color: "#8b9199"
            text: "GrantOS 1.0 \u2014 anvil"
        }
    }

    OpacityAnimator {
        id: introAnimation
        running: false
        target: content
        from: 0
        to: 1
        duration: Kirigami.Units.veryLongDuration * 2
        easing.type: Easing.InOutQuad
    }
}
