import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris

PopupWindow {
    id: popup
    visible: false
    implicitWidth: 400
    implicitHeight: 168
    color: "transparent"

    required property var parentWindow
    anchor.window: parentWindow
    anchor.rect.x: parentWindow.width - 420
    anchor.rect.y: parentWindow.height + 4

    property var playerList: []
    property int activeIndex: 0
    property var activePlayer: playerList.length > 0 ? playerList[activeIndex] : null

    Repeater {
        model: Mpris.players

        Item {
            required property var modelData
            required property int index

            Component.onCompleted: {
                const list = [...popup.playerList]
                list.push(modelData)
                popup.playerList = list

                if (modelData.playbackState === MprisPlaybackState.Playing) {
                    popup.activeIndex = list.length - 1
                }
            }

            Component.onDestruction: {
                const list = popup.playerList.filter(p => p !== modelData)
                popup.playerList = list
                if (popup.activeIndex >= list.length) {
                    popup.activeIndex = Math.max(0, list.length - 1)
                }
            }

            Connections {
                target: modelData
                function onPlaybackStateChanged() {
                    if (modelData.playbackState === MprisPlaybackState.Playing) {
                        const idx = popup.playerList.indexOf(modelData)
                        if (idx !== -1) popup.activeIndex = idx
                    }
                }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: -1
        radius: 28
        color: Qt.rgba(0, 0, 0, 0.3)
        z: -1
    }

    Rectangle {
        id: card
        anchors.fill: parent
        radius: 28
        color: Colors.surface

        Image {
            anchors.fill: parent
            source: popup.activePlayer?.trackArtUrl ?? ""
            fillMode: Image.PreserveAspectCrop
            visible: source !== ""
            opacity: 0.15
        }

        Item {
            anchors.fill: parent

            Text {
                anchors.centerIn: parent
                text: "再生なし"
                color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.5)
                font.pixelSize: 14
                visible: popup.activePlayer === null
            }

            Item {
                anchors.fill: parent
                anchors.margins: 16
                visible: popup.activePlayer !== null

                Text {
                    id: leftArrow
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "‹"
                    color: popup.playerList.length > 1 ? Colors.surfaceText : "transparent"
                    font.pixelSize: 24
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -8
                        enabled: popup.playerList.length > 1
                        onClicked: popup.activeIndex = (popup.activeIndex - 1 + popup.playerList.length) % popup.playerList.length
                    }
                }

                Text {
                    id: rightArrow
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "›"
                    color: popup.playerList.length > 1 ? Colors.surfaceText : "transparent"
                    font.pixelSize: 24
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -8
                        enabled: popup.playerList.length > 1
                        onClicked: popup.activeIndex = (popup.activeIndex + 1) % popup.playerList.length
                    }
                }

                Rectangle {
                    id: thumbContainer
                    anchors.left: leftArrow.right
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: 80
                    height: 80
                    radius: 12
                    color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.2)
                    clip: true

                    Image {
                        id: thumbImage
                        anchors.fill: parent
                        source: popup.activePlayer?.trackArtUrl ?? ""
                        fillMode: Image.PreserveAspectCrop
                        visible: source !== ""
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "♪"
                        color: Colors.primary
                        font.pixelSize: 28
                        visible: !thumbImage.visible
                    }
                }

                Column {
                    anchors.left: thumbContainer.right
                    anchors.leftMargin: 12
                    anchors.right: rightArrow.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    Text {
                        width: parent.width
                        text: popup.activePlayer?.identity ?? ""
                        color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.9)
                        font.pixelSize: 10
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                        visible: popup.playerList.length > 1
                    }

                    Text {
                        width: parent.width
                        text: popup.activePlayer?.trackTitle || ""
                        color: Colors.surfaceText
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: popup.activePlayer?.trackArtists || ""
                        color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.7)
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }

                    Rectangle {
                        width: parent.width
                        height: 3
                        radius: 999
                        color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.2)

                        Rectangle {
                            width: parent.width * (
                                popup.activePlayer?.position && popup.activePlayer?.length
                                ? popup.activePlayer.position / popup.activePlayer.length
                                : 0
                            )
                            height: parent.height
                            radius: 999
                            color: Colors.primary
                            Behavior on width { NumberAnimation { duration: 500 } }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: mouse => {
                                if (popup.activePlayer?.canSeek)
                                    popup.activePlayer.position = (mouse.x / width) * popup.activePlayer.length
                            }
                        }
                    }

                    Row {
                        spacing: 6

                        Rectangle {
                            width: 28; height: 28; radius: 999
                            color: popup.activePlayer?.shuffle
                                ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.25)
                                : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.08)
                            visible: popup.activePlayer?.canControl ?? false
                            Text {
                                anchors.centerIn: parent
                                text: "⇄"
                                color: popup.activePlayer?.shuffle ? Colors.primary : Colors.surfaceText
                                font.pixelSize: 13
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: { if (popup.activePlayer) popup.activePlayer.shuffle = !popup.activePlayer.shuffle }
                            }
                        }

                        Rectangle {
                            width: 32; height: 32; radius: 999
                            color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.08)
                            visible: popup.activePlayer?.canGoPrevious ?? false
                            Text {
                                anchors.centerIn: parent
                                text: "⏮"
                                color: Colors.surfaceText
                                font.pixelSize: 13
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: popup.activePlayer?.previous()
                            }
                        }

                        Rectangle {
                            width: 40; height: 40; radius: 999
                            color: Colors.primary
                            Text {
                                anchors.centerIn: parent
                                text: popup.activePlayer?.playbackState === MprisPlaybackState.Playing ? "⏸" : "▶"
                                color: Colors.primaryText
                                font.pixelSize: 16
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: popup.activePlayer?.togglePlaying()
                            }
                        }

                        Rectangle {
                            width: 32; height: 32; radius: 999
                            color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.08)
                            visible: popup.activePlayer?.canGoNext ?? false
                            Text {
                                anchors.centerIn: parent
                                text: "⏭"
                                color: Colors.surfaceText
                                font.pixelSize: 13
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: popup.activePlayer?.next()
                            }
                        }

                        Rectangle {
                            width: 28; height: 28; radius: 999
                            color: popup.activePlayer?.loopState !== MprisLoopState.None
                                ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.25)
                                : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.08)
                            visible: popup.activePlayer?.canControl ?? false
                            Text {
                                anchors.centerIn: parent
                                text: popup.activePlayer?.loopState === MprisLoopState.Track ? "🔂" : "🔁"
                                color: popup.activePlayer?.loopState !== MprisLoopState.None ? Colors.primary : Colors.surfaceText
                                font.pixelSize: 12
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    if (!popup.activePlayer) return
                                    switch (popup.activePlayer.loopState) {
                                        case MprisLoopState.None:     popup.activePlayer.loopState = MprisLoopState.Playlist; break
                                        case MprisLoopState.Playlist: popup.activePlayer.loopState = MprisLoopState.Track; break
                                        case MprisLoopState.Track:    popup.activePlayer.loopState = MprisLoopState.None; break
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
