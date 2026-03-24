import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Services.Notifications

PopupWindow {
    id: controlCenter
    visible: false
    color: "transparent"

    required property var parentWindow
    required property var notificationServer

    // バーから生えてくる感じ：上角をバーの角に合わせる
    anchor.window: parentWindow
    anchor.rect.x: parentWindow.width - implicitWidth
    anchor.rect.y: parentWindow.height
    implicitWidth: parentWindow.screen.width * 0.25
    implicitHeight: Math.min(innerCol.implicitHeight + 48, parentWindow.screen.height * 0.8)

    // アニメーション用プロパティ
    property real animProgress: 0
    property real animScale: 0.9

    onVisibleChanged: {
        if (visible) {
            animProgress = 0
            animScale = 0.9
            showAnim.start()
            showScaleAnim.start()
        }
    }

    NumberAnimation {
        id: showAnim
        target: controlCenter
        property: "animProgress"
        from: 0; to: 1
        duration: 380
        easing.type: Easing.OutBack
        easing.overshoot: 0.7
    }

    NumberAnimation {
        id: showScaleAnim
        target: controlCenter
        property: "animScale"
        from: 0.9; to: 1.0
        duration: 380
        easing.type: Easing.OutBack
        easing.overshoot: 0.7
    }

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    Rectangle {
        anchors.fill: parent
        anchors.topMargin: 8
        radius: 20
        color: Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.95)
        clip: true
        opacity: controlCenter.animProgress
        transform: [
            Translate { y: (1 - controlCenter.animProgress) * -24 },
            Scale {
                xScale: controlCenter.animScale
                yScale: controlCenter.animScale
                origin.x: controlCenter.width / 2
                origin.y: 0
            }
        ]

        Flickable {
            anchors.fill: parent
            contentHeight: innerCol.implicitHeight + 32
            clip: true

            Column {
                id: innerCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 16
                spacing: 16

                // ── 音量セクション ──
                Column {
                    width: parent.width
                    spacing: 10

                    // ヘッダー行
                    Item {
                        width: parent.width
                        height: 28

                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: "音量"
                            color: Colors.surfaceText
                            font.pixelSize: 12
                            font.weight: Font.Medium
                            opacity: 0.7
                        }

                        Text {
                            id: volLabel
                            anchors.right: muteBtn.left
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            text: Math.round((Pipewire.defaultAudioSink?.audio?.volume ?? 0) * 100) + "%"
                            color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.6)
                            font.pixelSize: 11
                        }

                        Rectangle {
                            id: muteBtn
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: 28
                            height: 28
                            radius: 999
                            color: (Pipewire.defaultAudioSink?.audio?.muted ?? false)
                                ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.25)
                                : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.08)

                            Text {
                                anchors.centerIn: parent
                                text: (Pipewire.defaultAudioSink?.audio?.muted ?? false) ? "🔇" : "🔊"
                                font.pixelSize: 13
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    if (Pipewire.defaultAudioSink?.audio)
                                        Pipewire.defaultAudioSink.audio.muted = !Pipewire.defaultAudioSink.audio.muted
                                }
                            }
                        }
                    }

                    // スライダー
                    Item {
                        width: parent.width
                        height: 20

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            height: 4
                            radius: 999
                            color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.2)

                            Rectangle {
                                width: parent.width * Math.min(Pipewire.defaultAudioSink?.audio?.volume ?? 0, 1.0)
                                height: parent.height
                                radius: 999
                                color: Colors.primary
                                Behavior on width { NumberAnimation { duration: 100 } }
                            }
                        }

                        Rectangle {
                            x: (parent.width - width) * Math.min(Pipewire.defaultAudioSink?.audio?.volume ?? 0, 1.0)
                            anchors.verticalCenter: parent.verticalCenter
                            width: 16
                            height: 16
                            radius: 999
                            color: Colors.primary
                            Behavior on x { NumberAnimation { duration: 100 } }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: mouse => {
                                if (Pipewire.defaultAudioSink?.audio)
                                    Pipewire.defaultAudioSink.audio.volume = Math.max(0, Math.min(1, mouse.x / width))
                            }
                            onPositionChanged: mouse => {
                                if (pressed && Pipewire.defaultAudioSink?.audio)
                                    Pipewire.defaultAudioSink.audio.volume = Math.max(0, Math.min(1, mouse.x / width))
                            }
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.1)
                }

                // ── 音楽セクション ──
                Column {
                    width: parent.width
                    spacing: 10

                    Text {
                        text: "音楽"
                        color: Colors.surfaceText
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        opacity: 0.7
                    }

                    Text {
                        width: parent.width
                        text: "再生なし"
                        color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.4)
                        font.pixelSize: 13
                        horizontalAlignment: Text.AlignHCenter
                        visible: musicManager.playerList.length === 0
                    }

                    Item {
                        id: musicManager
                        width: parent.width
                        height: 0
                        visible: false

                        property var playerList: []
                        property int activeIndex: 0
                        property var activePlayer: playerList.length > 0 ? playerList[activeIndex] : null

                        Repeater {
                            model: Mpris.players
                            Item {
                                required property var modelData

                                Component.onCompleted: {
                                    const list = [...musicManager.playerList]
                                    list.push(modelData)
                                    musicManager.playerList = list
                                    if (modelData.playbackState === MprisPlaybackState.Playing)
                                        musicManager.activeIndex = list.length - 1
                                }

                                Component.onDestruction: {
                                    const list = musicManager.playerList.filter(p => p !== modelData)
                                    musicManager.playerList = list
                                    if (musicManager.activeIndex >= list.length)
                                        musicManager.activeIndex = Math.max(0, list.length - 1)
                                }

                                Connections {
                                    target: modelData
                                    function onPlaybackStateChanged() {
                                        if (modelData.playbackState === MprisPlaybackState.Playing) {
                                            const idx = musicManager.playerList.indexOf(modelData)
                                            if (idx !== -1) musicManager.activeIndex = idx
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Item {
                        width: parent.width
                        height: 96
                        visible: musicManager.playerList.length > 0

                        Rectangle {
                            id: musicThumb
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            width: 64
                            height: 64
                            radius: 10
                            color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.2)
                            clip: true

                            Image {
                                id: musicThumbImg
                                anchors.fill: parent
                                source: musicManager.activePlayer?.trackArtUrl ?? ""
                                fillMode: Image.PreserveAspectCrop
                                visible: source !== ""
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "♪"
                                color: Colors.primary
                                font.pixelSize: 22
                                visible: !musicThumbImg.visible
                            }
                        }

                        Column {
                            anchors.left: musicThumb.right
                            anchors.leftMargin: 10
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 4

                            Text {
                                width: parent.width
                                text: musicManager.activePlayer?.identity ?? ""
                                color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.9)
                                font.pixelSize: 10
                                font.weight: Font.Medium
                                elide: Text.ElideRight
                                visible: musicManager.playerList.length > 1
                            }

                            Text {
                                width: parent.width
                                text: musicManager.activePlayer?.trackTitle ?? ""
                                color: Colors.surfaceText
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }

                            Text {
                                width: parent.width
                                text: musicManager.activePlayer?.trackArtists ?? ""
                                color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.7)
                                font.pixelSize: 11
                                elide: Text.ElideRight
                            }

                            Rectangle {
                                width: parent.width
                                height: 3
                                radius: 999
                                color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.2)

                                Rectangle {
                                    width: parent.width * (
                                        musicManager.activePlayer?.position && musicManager.activePlayer?.length
                                        ? musicManager.activePlayer.position / musicManager.activePlayer.length : 0
                                    )
                                    height: parent.height
                                    radius: 999
                                    color: Colors.primary
                                    Behavior on width { NumberAnimation { duration: 500 } }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: mouse => {
                                        if (musicManager.activePlayer?.canSeek)
                                            musicManager.activePlayer.position = (mouse.x / width) * musicManager.activePlayer.length
                                    }
                                }
                            }

                            Row {
                                spacing: 6

                                Rectangle {
                                    width: 24; height: 24; radius: 999
                                    color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.08)
                                    visible: musicManager.playerList.length > 1
                                    Text { anchors.centerIn: parent; text: "‹"; color: Colors.surfaceText; font.pixelSize: 16 }
                                    MouseArea { anchors.fill: parent; onClicked: musicManager.activeIndex = (musicManager.activeIndex - 1 + musicManager.playerList.length) % musicManager.playerList.length }
                                }

                                Rectangle {
                                    width: 28; height: 28; radius: 999
                                    color: musicManager.activePlayer?.shuffle ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.25) : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.08)
                                    visible: musicManager.activePlayer?.canControl ?? false
                                    Text { anchors.centerIn: parent; text: "⇄"; color: musicManager.activePlayer?.shuffle ? Colors.primary : Colors.surfaceText; font.pixelSize: 12 }
                                    MouseArea { anchors.fill: parent; onClicked: { if (musicManager.activePlayer) musicManager.activePlayer.shuffle = !musicManager.activePlayer.shuffle } }
                                }

                                Rectangle {
                                    width: 32; height: 32; radius: 999
                                    color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.08)
                                    visible: musicManager.activePlayer?.canGoPrevious ?? false
                                    Text { anchors.centerIn: parent; text: "⏮"; color: Colors.surfaceText; font.pixelSize: 12 }
                                    MouseArea { anchors.fill: parent; onClicked: musicManager.activePlayer?.previous() }
                                }

                                Rectangle {
                                    width: 40; height: 40; radius: 999
                                    color: Colors.primary
                                    Text { anchors.centerIn: parent; text: musicManager.activePlayer?.playbackState === MprisPlaybackState.Playing ? "⏸" : "▶"; color: Colors.primaryText; font.pixelSize: 15 }
                                    MouseArea { anchors.fill: parent; onClicked: musicManager.activePlayer?.togglePlaying() }
                                }

                                Rectangle {
                                    width: 32; height: 32; radius: 999
                                    color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.08)
                                    visible: musicManager.activePlayer?.canGoNext ?? false
                                    Text { anchors.centerIn: parent; text: "⏭"; color: Colors.surfaceText; font.pixelSize: 12 }
                                    MouseArea { anchors.fill: parent; onClicked: musicManager.activePlayer?.next() }
                                }

                                Rectangle {
                                    width: 28; height: 28; radius: 999
                                    color: musicManager.activePlayer?.loopState !== MprisLoopState.None
                                        ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.25)
                                        : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.08)
                                    visible: musicManager.activePlayer?.canControl ?? false
                                    Text { anchors.centerIn: parent; text: musicManager.activePlayer?.loopState === MprisLoopState.Track ? "🔂" : "🔁"; color: musicManager.activePlayer?.loopState !== MprisLoopState.None ? Colors.primary : Colors.surfaceText; font.pixelSize: 11 }
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            if (!musicManager.activePlayer) return
                                            switch (musicManager.activePlayer.loopState) {
                                                case MprisLoopState.None: musicManager.activePlayer.loopState = MprisLoopState.Playlist; break
                                                case MprisLoopState.Playlist: musicManager.activePlayer.loopState = MprisLoopState.Track; break
                                                case MprisLoopState.Track: musicManager.activePlayer.loopState = MprisLoopState.None; break
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    width: 24; height: 24; radius: 999
                                    color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.08)
                                    visible: musicManager.playerList.length > 1
                                    Text { anchors.centerIn: parent; text: "›"; color: Colors.surfaceText; font.pixelSize: 16 }
                                    MouseArea { anchors.fill: parent; onClicked: musicManager.activeIndex = (musicManager.activeIndex + 1) % musicManager.playerList.length }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.1)
                }

                // ── 通知セクション ──
                Column {
                    width: parent.width
                    spacing: 8

                    // ヘッダー行
                    Item {
                        width: parent.width
                        height: 20

                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: "通知"
                            color: Colors.surfaceText
                            font.pixelSize: 12
                            font.weight: Font.Medium
                            opacity: 0.7
                        }

                        Text {
                            id: clearAllBtn
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: "すべて消去"
                            color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.8)
                            font.pixelSize: 11

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    const notifs = notificationServer.trackedNotifications
                                    const count = notifs.count
                                    for (let i = count - 1; i >= 0; i--) {
                                        const n = notifs.get(i)
                                        if (n) n.tracked = false
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        width: parent.width
                        text: "通知なし"
                        color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.4)
                        font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter
                        visible: notificationServer.trackedNotifications.count === 0
                    }

                    Repeater {
                        model: notificationServer.trackedNotifications

                        Rectangle {
                            required property var modelData

                            width: parent.width
                            height: notifCol.implicitHeight + 16
                            radius: 12
                            color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.05)

                            Rectangle {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                anchors.margins: 3
                                width: 2
                                radius: 999
                                color: modelData.urgency === NotificationUrgency.Critical
                                    ? Colors.errorColor
                                    : Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.5)
                            }

                            Column {
                                id: notifCol
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 8
                                anchors.leftMargin: 14
                                spacing: 2

                                Item {
                                    width: parent.width
                                    height: 16

                                    Image {
                                        id: notifIcon
                                        width: 14; height: 14
                                        source: modelData.appIcon ?? ""
                                        visible: (modelData.appIcon ?? "") !== ""
                                        fillMode: Image.PreserveAspectFit
                                        anchors.left: parent.left
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Text {
                                        anchors.left: notifIcon.visible ? notifIcon.right : parent.left
                                        anchors.leftMargin: notifIcon.visible ? 6 : 0
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData.appName ?? ""
                                        color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.5)
                                        font.pixelSize: 10
                                    }

                                    Text {
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "✕"
                                        color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.3)
                                        font.pixelSize: 10

                                        MouseArea {
                                            anchors.fill: parent
                                            anchors.margins: -4
                                            onClicked: modelData.dismiss()
                                        }
                                    }
                                }

                                Text {
                                    width: parent.width
                                    text: modelData.summary ?? ""
                                    color: Colors.surfaceText
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                    elide: Text.ElideRight
                                    visible: (modelData.summary ?? "") !== ""
                                }

                                Text {
                                    width: parent.width
                                    text: modelData.body ?? ""
                                    color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.7)
                                    font.pixelSize: 11
                                    wrapMode: Text.WordWrap
                                    maximumLineCount: 2
                                    elide: Text.ElideRight
                                    visible: (modelData.body ?? "") !== ""
                                    textFormat: Text.PlainText
                                }
                            }
                        }
                    }
                }

                Item { width: 1; height: 4 }
            }
        }
    }
}
