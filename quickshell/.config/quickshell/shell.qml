import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.Notifications

ShellRoot {
    property string windowTitle: ""
    property var urgentWorkspaces: []
    property bool silentMode: false

    function luminance(color) {
        return 0.299 * color.r + 0.587 * color.g + 0.114 * color.b
    }
    function textColor(bgColor) {
        return luminance(bgColor) > 0.5 ? "#000000" : "#ffffff"
    }

    // 通知サーバー
    NotificationServer {
        id: notifServer
        actionsSupported: true
        imageSupported: true
        bodySupported: true
        keepOnReload: true

        onNotification: notif => {
            notif.tracked = true
        }
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

    Variants {
        model: Quickshell.screens

        delegate: PanelWindow {
            id: panel
            required property var modelData
            screen: modelData
            anchors.top: true
            implicitWidth: screen.width * 0.99
            implicitHeight: 36
            color: "transparent"
            margins.top: 8

            // トーストオーバーレイ（スクリーンごと）
            ToastOverlay {
                screen: panel.screen
                notificationServer: notifServer
                silentMode: silentMode
            }

            ControlCenter {
                id: controlCenter
                visible: false
                parentWindow: panel
                notificationServer: notifServer

                NumberAnimation {
                    id: hideAnim
                    target: controlCenter
                    property: "animProgress"
                    from: 1; to: 0
                    duration: 180
                    easing.type: Easing.InBack
                    easing.overshoot: 0.5
                    onFinished: controlCenter.visible = false
                }

                function toggleVisible() {
                    if (controlCenter.visible) {
                        hideAnim.start()
                    } else {
                        controlCenter.visible = true
                    }
                }
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

                            Item {
                                implicitHeight: 24
                                implicitWidth: wsIndicator.implicitWidth
                                anchors.verticalCenter: parent?.verticalCenter

                                property bool isActive: modelData.id === Hyprland.focusedWorkspace?.id
                                property bool isUrgent: urgentWorkspaces.includes(modelData.id)

                                Rectangle {
                                    id: wsIndicator
                                    anchors.verticalCenter: parent.verticalCenter
                                    implicitHeight: 24
                                    implicitWidth: isActive ? 36 : 24
                                    radius: 999

                                    color: isUrgent
                                        ? Colors.errorColor
                                        : isActive
                                            ? Colors.primary
                                            : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.15)

                                    Behavior on implicitWidth {
                                        NumberAnimation {
                                            duration: 300
                                            easing.type: Easing.OutBack
                                            easing.overshoot: 0.5
                                        }
                                    }

                                    Behavior on color {
                                        ColorAnimation { duration: 200 }
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.id
                                        color: isActive || isUrgent
                                            ? (luminance(wsIndicator.color) > 0.5 ? "#000000" : "#ffffff")
                                            : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.7)
                                        font.pixelSize: 11
                                        font.weight: isActive ? Font.Medium : Font.Normal

                                        Behavior on color {
                                            ColorAnimation { duration: 200 }
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: modelData.activate()
                                    }
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

                    // 右: 音楽 + 通知バッジ + 時計 + 電源
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
                                    onClicked: controlCenter.toggleVisible()
                                }
                            }
                        }

                        // 通知バッジ
                        Item {
                            width: 20
                            height: 20
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                                anchors.centerIn: parent
                                text: silentMode ? "🔕" : "🔔"
                                font.pixelSize: 13
                                opacity: notifServer.trackedNotifications.count > 0 || silentMode ? 1.0 : 0.4
                            }

                            Rectangle {
                                anchors.right: parent.right
                                anchors.top: parent.top
                                width: 14
                                height: 14
                                radius: 999
                                color: Colors.errorColor
                                visible: notifServer.trackedNotifications.count > 0 && !silentMode

                                Text {
                                    anchors.centerIn: parent
                                    text: notifServer.trackedNotifications.count
                                    color: Colors.primaryText
                                    font.pixelSize: 9
                                    font.weight: Font.Bold
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -4
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onClicked: mouse => {
                                    if (mouse.button === Qt.RightButton) {
                                        silentMode = !silentMode
                                    } else {
                                        controlCenter.toggleVisible()
                                    }
                                }
                            }
                        }

                        // 時計
                        Text {
                            id: clockText
                            text: Qt.formatDateTime(new Date(), "hh:mm")
                            color: textColor(bar.color)
                            font.pixelSize: 13
                            MouseArea {
                                anchors.fill: parent
                                onClicked: controlCenter.toggleVisible()
                            }

                            Timer {
                                interval: 1000
                                running: true
                                repeat: true
                                onTriggered: clockText.text = Qt.formatDateTime(new Date(), "hh:mm")
                            }
                        }

                        // 電源ボタン
                        Text {
                            text: "⏻"
                            color: textColor(bar.color)
                            font.pixelSize: 16
                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -8
                                onClicked: powerPopup.toggleVisible()
                            }
                        }
                    }
                }
            }
        }
    }
}
