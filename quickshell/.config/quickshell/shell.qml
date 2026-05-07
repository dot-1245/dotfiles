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

    NotificationServer {
        id: notifServer
        actionsSupported: true; imageSupported: true; bodySupported: true; keepOnReload: true
        onNotification: notif => { notif.tracked = true }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "activewindow") {
                const parts = event.parse(2)
                windowTitle = parts[1] ?? ""
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
            implicitHeight: 40
            color: "transparent"
            margins.top: 8

            Rectangle {
                id: bar
                anchors.fill: parent
                radius: 16
                color: Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.85)

                // --- [左側] ワークスペース ---
                Row {
                    id: leftArea
                    anchors.left: parent.left
                    anchors.leftMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    Repeater {
                        model: Hyprland.workspaces
                        delegate: Rectangle {
                            width: modelData.id === Hyprland.focusedWorkspace?.id ? 38 : 26
                            height: 26; radius: 13
                            color: modelData.id === Hyprland.focusedWorkspace?.id ? Colors.primary : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.15)
                            Text {
                                anchors.centerIn: parent; text: modelData.id
                                color: Colors.surfaceText; font.pixelSize: 11
                            }
                            MouseArea { anchors.fill: parent; onClicked: modelData.activate() }
                        }
                    }
                }

                // --- [右側] 音楽・時計・ボタン (右端に固定) ---
                Row {
                    id: rightArea
                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 12

                    // MPRIS (バー上の表示ロジックをControlCenterに統合)
                    Repeater {
                        model: Mpris.players
                        delegate: Rectangle {
                            // 再生中のもの、または最初のプレイヤーを表示
                            visible: modelData.playbackState === MprisPlaybackState.Playing || index === 0
                            width: visible ? 180 : 0
                            height: 32; radius: 10
                            color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.15)
                            clip: true

                            Row {
                                anchors.fill: parent; anchors.margins: 4; spacing: 8
                                
                                Rectangle {
                                    width: 24; height: 24; radius: 5
                                    color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.2)
                                    clip: true
                                    Image {
                                        id: barArtImg
                                        anchors.fill: parent
                                        source: modelData.trackArtUrl ?? ""
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                        visible: source !== ""
                                    }
                                    Text {
                                        anchors.centerIn: parent; text: "♪"
                                        font.pixelSize: 12; color: Colors.primary
                                        visible: !barArtImg.visible
                                    }
                                }

                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    Text { 
                                        text: modelData.trackTitle || "Music"
                                        font.pixelSize: 9; font.weight: Font.Bold; color: Colors.surfaceText
                                        width: 130; elide: Text.ElideRight 
                                    }
                                    Text { 
                                        text: modelData.trackArtists || "Unknown"
                                        font.pixelSize: 8; opacity: 0.7; color: Colors.surfaceText
                                        width: 130; elide: Text.ElideRight 
                                    }
                                }
                            }

                            Rectangle {
                                anchors.bottom: parent.bottom; height: 2; color: Colors.primary
                                width: parent.width * (modelData.length > 0 ? (modelData.position / modelData.length) : 0)
                            }

                            MouseArea { 
                                anchors.fill: parent
                                onClicked: controlCenter.toggleVisible() 
                            }
                        }
                    }

                    // 時計・通知・電源
                    Row {
                        spacing: 14; anchors.verticalCenter: parent.verticalCenter
                        Text { text: silentMode ? "🔕" : "🔔"; font.pixelSize: 14; color: Colors.surfaceText; MouseArea { anchors.fill: parent; onClicked: controlCenter.toggleVisible() } }
                        Text { text: Qt.formatDateTime(new Date(), "hh:mm"); color: Colors.surfaceText; font.pixelSize: 13; MouseArea { anchors.fill: parent; onClicked: controlCenter.toggleVisible() } }
                        Text { text: "⏻"; font.pixelSize: 16; color: Colors.surfaceText; MouseArea { anchors.fill: parent; onClicked: powerPopup.toggleVisible() } }
                    }
                }

                // --- [中央] アイコンとタイトル ---
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10
                    // 左右のエリアを侵害しないよう計算
                    width: Math.min(bar.width - (leftArea.width + rightArea.width + 100), 500)
                    clip: true

                    Image {
                        width: 20; height: 20
                        anchors.verticalCenter: parent.verticalCenter
                        source: Hyprland.focusedClient?.class ? "image://icon/" + Hyprland.focusedClient.class : ""
                        fillMode: Image.PreserveAspectFit
                        onStatusChanged: if (status === Image.Error) source = "image://icon/application-x-executable" 
                    }

                    Text {
                        text: windowTitle
                        anchors.verticalCenter: parent.verticalCenter
                        color: Colors.surfaceText; font.pixelSize: 13; font.weight: Font.Medium
                        elide: Text.ElideRight
                        width: parent.width - 30
                    }
                }
            }

            // ポップアップコンポーネント
            ControlCenter { 
                id: controlCenter; visible: false; parentWindow: panel; notificationServer: notifServer
                function toggleVisible() { this.visible = !this.visible }
            }
            PowerMenu { id: powerPopup; visible: false; parentWindow: panel }
            AppLauncher { id: launcher; parentWindow: panel }
            WallpaperSelector { id: wallpaperSelector; parentWindow: panel }
            ToastOverlay { screen: panel.screen; notificationServer: notifServer; silentMode: silentMode }
        }
    }
}
