/*
    GrantOS System Monitor — one instrument row: label, load bar,
    right-aligned big value, unit.
    SPDX-License-Identifier: MIT
*/
import QtQuick 2.15

Item {
    id: row
    property string label: ""
    property var value: "--"
    property string unit: ""
    property real frac: -1                 // -1 = no bar
    property color barColor: "#ffffff"
    width: 300
    height: 30

    Text { x: 0; anchors.verticalCenter: parent.verticalCenter
           text: row.label; color: "#9aa0a6"; font.pixelSize: 11 }
    Item {
        x: 74; width: 130; height: 10
        anchors.verticalCenter: parent.verticalCenter
        visible: row.frac >= 0
        Rectangle {
            anchors.fill: parent
            color: "#15181a"
            border.color: Qt.rgba(0, 0, 0, 0.7)
            border.width: 1
            // recessed top shadow inside the track
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 3
                color: Qt.rgba(0, 0, 0, 0.45)
            }
        }
        Rectangle {
            id: fill
            width: parent.width * Math.min(1, Math.max(0, row.frac))
            height: parent.height - 2
            y: 1
            color: row.barColor
            // gloss: bright top half, dark bottom edge
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: parent.height / 2
                color: Qt.rgba(1, 1, 1, 0.28)
            }
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 2
                color: Qt.rgba(0, 0, 0, 0.35)
            }
            // hot tip
            Rectangle {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 2
                visible: parent.width > 4
                color: Qt.rgba(1, 1, 1, 0.75)
            }
        }
    }
    Text {
        id: unitText
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        visible: row.unit !== ""
        text: row.unit; color: "#8b9199"; font.pixelSize: 11
    }
    Text {
        id: valueText
        anchors.right: unitText.left
        anchors.rightMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        text: row.value; color: "#ffffff"; font.pixelSize: 20; font.bold: true
    }
}
