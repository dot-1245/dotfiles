import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

PanelWindow {
    id: powerMenu
    anchors.left: true
    anchors.top: true
    anchors.bottom: true
    implicitWidth: shown ? 200 : 0
    color: "transparent"
    exclusiveZone: 0

    property bool shown: false

    function show() { shown = true }
    function hide() { shown = false }

    Behavior on implicitWidth {
        NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(
            Colors.surface.r,
            Colors.surface.g,
            Colors.surface.b,
            0.95
        )

        // 外クリックで閉じる
        MouseArea {
            anchors.fill: parent
            onClicked: powerMenu.shown = false
        }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 12
            opacity: powerMenu.shown ? 1 : 0

            Behavior on opacity {
                NumberAnimation { duration: 150 }
            }

            Repeater {
                model: [
                    { text: "🔒 Lock",     cmd: ["hyprlock"] },
                    { text: "🚪 Logout",   cmd: ["hyprctl", "dispatch", "exit"] },
                    { text: "💤 Suspend",  cmd: ["systemctl", "suspend"] },
                    { text: "🔄 Reboot",   cmd: ["systemctl", "reboot"] },
                    { text: "⏻ Shutdown", cmd: ["systemctl", "poweroff"] },
                ]

                Rectangle {
                    Layout.preferredWidth: 160
                    Layout.preferredHeight: 48
                    radius: 12
                    color: Qt.rgba(
                        Colors.primary.r,
                        Colors.primary.g,
                        Colors.primary.b,
                        btnHover.containsMouse ? 0.9 : 0.5
                    )

                    MouseArea {
                        id: btnHover
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: proc.running = true
                    }

                    Text {
                        anchors.centerIn: parent
                        text: modelData.text
                        color: "white"
                        font.pixelSize: 14
                    }

                    Process {
                        id: proc
                        command: modelData.cmd
                    }
                }
            }
        }
    }
}
