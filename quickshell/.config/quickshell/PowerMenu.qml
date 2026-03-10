import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

PopupWindow {
    id: powerPopup
    visible: false
    implicitWidth: 160
    implicitHeight: 280
    color: "transparent"

    required property var parentWindow
    anchor.window: parentWindow
    anchor.rect.x: parentWindow.width - 180
    anchor.rect.y: parentWindow.height + 4

    Rectangle {
        anchors.fill: parent
        radius: 16
        color: Qt.rgba(
            Colors.surface.r,
            Colors.surface.g,
            Colors.surface.b,
            0.95
        )

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 8

            Repeater {
                model: [
                    { text: "🔒 Lock",     cmd: ["hyprlock"] },
                    { text: "🚪 Logout",   cmd: ["hyprctl", "dispatch", "exit"] },
                    { text: "💤 Suspend",  cmd: ["systemctl", "suspend"] },
                    { text: "🔄 Reboot",   cmd: ["systemctl", "reboot"] },
                    { text: "⏻ Shutdown", cmd: ["systemctl", "poweroff"] },
                ]

                Rectangle {
                    Layout.preferredWidth: 140
                    Layout.preferredHeight: 44
                    radius: 12
                    color: Qt.rgba(
                        Colors.primary.r,
                        Colors.primary.g,
                        Colors.primary.b,
                        btnHover.containsMouse ? 0.8 : 0.4
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
