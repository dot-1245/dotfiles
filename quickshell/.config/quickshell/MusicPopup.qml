import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris

PopupWindow {
    id: popup
    visible: false
    implicitWidth: 400
    implicitHeight: 160
    color: "transparent"

    required property var parentWindow
    anchor.window: parentWindow
    anchor.rect.x: parentWindow.width - 420
    anchor.rect.y: parentWindow.height + 4

    property var activePlayer: null

    Repeater {
        model: Mpris.players
        Item {
            Component.onCompleted: {
                if (modelData.playbackState === MprisPlaybackState.Playing) {
                    popup.activePlayer = modelData
                } else if (popup.activePlayer === null ||
                           popup.activePlayer.playbackState !== MprisPlaybackState.Playing) {
                    popup.activePlayer = modelData
                }
            }
            Connections {
                target: modelData
                function onPlaybackStateChanged() {
                    if (modelData.playbackState === MprisPlaybackState.Playing) {
                        popup.activePlayer = modelData
                    }
                }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: 24
        color: Colors.surface

        Image {
            anchors.fill: parent
            source: popup.activePlayer?.trackArtUrl ?? ""
            fillMode: Image.PreserveAspectCrop
            visible: source !== ""
            opacity: 0.6
        }

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.4)
            radius: 24
        }

        Text {
            anchors.centerIn: parent
            text: "再生なし"
            color: "white"
            font.pixelSize: 16
            visible: popup.activePlayer === null
        }

        Item {
            anchors.fill: parent
            anchors.margins: 16
            visible: popup.activePlayer !== null

            // 右上: 再生/一時停止ボタン
            Rectangle {
                anchors.right: parent.right
                anchors.top: parent.top
                width: 40
                height: 40
                radius: 999
                color: Qt.rgba(1, 1, 1, 0.2)
                z: 1

                Text {
                    anchors.centerIn: parent
                    text: popup.activePlayer?.playbackState === MprisPlaybackState.Playing ? "⏸" : "▶"
                    color: "white"
                    font.pixelSize: 20
                }

                MouseArea {
                    anchors.fill: parent
                    z: 1
                    onClicked: popup.activePlayer?.togglePlaying()
                }
            }

            // 曲名・アーティスト
            Column {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.rightMargin: 56
                anchors.bottom: bottomRow.top
                anchors.bottomMargin: 8
                spacing: 4

                Text {
                    width: parent.width
                    text: popup.activePlayer?.trackTitle || ""
                    color: "white"
                    font.pixelSize: 16
                    font.bold: true
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: popup.activePlayer?.trackArtists || ""
                    color: Qt.rgba(1, 1, 1, 0.8)
                    font.pixelSize: 13
                    elide: Text.ElideRight
                }
            }

            // 下部: ⏮ [プログレスバー] ⏭
            Item {
                id: bottomRow
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 24

                Text {
                    id: prevBtn
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "⏮"
                    color: "white"
                    font.pixelSize: 18
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -8
                        onClicked: popup.activePlayer?.previous()
                    }
                }

                Rectangle {
                    anchors.left: prevBtn.right
                    anchors.leftMargin: 8
                    anchors.right: nextBtn.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    height: 4
                    radius: 999
                    color: Qt.rgba(1, 1, 1, 0.3)

                    Rectangle {
                        width: parent.width * (
                            popup.activePlayer?.position && popup.activePlayer?.length
                            ? popup.activePlayer.position / popup.activePlayer.length
                            : 0
                        )
                        height: parent.height
                        radius: 999
                        color: "white"
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: mouse => {
                            if (popup.activePlayer?.canSeek) {
                                popup.activePlayer.position = (mouse.x / width) * popup.activePlayer.length
                            }
                        }
                    }
                }

                Text {
                    id: nextBtn
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "⏭"
                    color: "white"
                    font.pixelSize: 18
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -8
                        onClicked: popup.activePlayer?.next()
                    }
                }
            }
        }
    }
}
