import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Mpris

ShellRoot {
    property string windowTitle: ""
    property var urgentWorkspaces: []

    function luminance(color) {
        return 0.299 * color.r + 0.587 * color.g + 0.114 * color.b
    }
    function textColor(bgColor) {
        return luminance(bgColor) > 0.5 ? "#000000" : "#ffffff"
    }

    Process {
        id: getUrgentWs
        property string addr: ""
        command: ["hyprctl", "clients", "-j"]

        stdout: SplitParser {
            splitMarker: ""
            onRead: data => {
                try {
                    const clients = JSON.parse(data)
                    const client = clients.find(c => c.address.endsWith(getUrgentWs.addr))
                    if (client) {
                        const wsId = client.workspace.id
                        if (!urgentWorkspaces.includes(wsId)) {
                            urgentWorkspaces = [...urgentWorkspaces, wsId]
                        }
                    }
                } catch(e) {}
            }
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "activewindow") {
                const parts = event.parse(2)
                windowTitle = parts[1] ?? ""
                urgentWorkspaces = urgentWorkspaces.filter(id => id !== Hyprland.focusedWorkspace?.id)
            }
            if (event.name === "urgent") {
                getUrgentWs.addr = event.parse(1)[0]
                getUrgentWs.running = true
            }
        }
    }

    PanelWindow {
        id: panel
        anchors.top: true
        implicitWidth: screen.width * 0.99
        implicitHeight: 36
        color: "transparent"
        margins.top: 8

        MusicPopup {
            id: musicPopup
            visible: false
            parentWindow: panel
        }

        PowerMenu {
            id: powerPopup
            visible: false
            parentWindow: panel
        }

        Rectangle {
            id: bar
            anchors.fill: parent
            radius: 999
            color: Qt.rgba(
                Colors.surface.r,
                Colors.surface.g,
                Colors.surface.b,
                0.85
            )

            Item {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12

                // 左: ワークスペース
                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    Repeater {
                        model: Hyprland.workspaces
                        Rectangle {
                            id: wsRect
                            implicitWidth: 24
                            implicitHeight: 24
                            radius: 999
                            color: urgentWorkspaces.includes(modelData.id)
                                ? Colors.errorColor
                                : modelData.id === Hyprland.focusedWorkspace?.id
                                    ? Colors.primary
                                    : Colors.surface

                            Text {
                                anchors.centerIn: parent
                                text: modelData.id
                                color: textColor(wsRect.color)
                                font.pixelSize: 12
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: modelData.activate()
                            }
                        }
                    }
                }

                // 中央: ウィンドウタイトル
                Text {
                    anchors.centerIn: parent
                    width: parent.width * 0.4
                    text: windowTitle
                    color: textColor(bar.color)
                    font.pixelSize: 13
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                }

                // 右: 音楽 + 時計 + 電源
                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 12

                    Repeater {
                        model: Mpris.players
                        Text {
                            text: "🎵 " + modelData.trackTitle
                            color: textColor(bar.color)
                            font.pixelSize: 13
                            MouseArea {
                                anchors.fill: parent
                                onClicked: musicPopup.visible = !musicPopup.visible
                            }
                        }
                    }

                    Text {
                        text: Qt.formatDateTime(new Date(), "hh:mm")
                        color: textColor(bar.color)
                        font.pixelSize: 13
                    }

                    // 電源ボタン
                    Text {
                        text: "⏻"
                        color: textColor(bar.color)
                        font.pixelSize: 16
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -8
                            onClicked: powerMenu.shown = !powerMenu.shown

                        }
                    }
                }
            }
        }
    }
}
