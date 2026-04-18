import QtQuick
import Quickshell
import Quickshell.Io

PopupWindow {
    id: wallpaperSelector
    visible: false
    color: "transparent"

    required property var parentWindow

    anchor.window: parentWindow
    anchor.rect.x: Math.round((parentWindow.width - card.width) / 2)
    anchor.rect.y: Math.round(parentWindow.screen.height * 0.11)

    implicitWidth:  card.width
    implicitHeight: card.height

    // ──────────────────────── アニメーション ────────────────────────
    property real animProgress: 0
    property real animScale:    0.94

    onVisibleChanged: {
        if (visible) {
            imageList = []
            if (!imageFetcher.running)
                imageFetcher.running = true
            animProgress = 0
            animScale    = 0.94
            showProgressAnim.start()
            showScaleAnim.start()
        }
    }

    NumberAnimation { id: showProgressAnim; target: wallpaperSelector; property: "animProgress"; from: 0; to: 1; duration: 240; easing.type: Easing.OutCubic }
    NumberAnimation { id: showScaleAnim;    target: wallpaperSelector; property: "animScale";    from: 0.94; to: 1.0; duration: 240; easing.type: Easing.OutCubic }
    NumberAnimation {
        id: hideAnim
        target: wallpaperSelector; property: "animProgress"
        from: 1; to: 0; duration: 160; easing.type: Easing.InCubic
        onFinished: wallpaperSelector.visible = false
    }

    function toggleVisible() {
        if (wallpaperSelector.visible) hideAnim.start()
        else wallpaperSelector.visible = true
    }

    // ──────────────────────── 画像データ ────────────────────────
    property var    imageList:        []
    property string currentWallpaper: ""
    property bool   isApplying:       false

    // ~/Pictures を再帰スキャン
    Process {
        id: imageFetcher
        running: false
        command: [
            "bash", "-c",
            `find "$HOME/dotfiles/wallpaper/.config/wallpaper" -maxdepth 4 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \\) | sort`
        ]
        stdout: SplitParser {
            onRead: data => {
                const path = data.trim()
                if (path !== "")
                    wallpaperSelector.imageList = [...wallpaperSelector.imageList, path]
            }
        }
    }

    // awww で壁紙適用
    Process {
        id: applyProc
        running: false
        command: []
        onRunningChanged: {
            if (!running) wallpaperSelector.isApplying = false
        }
    }

    function applyWallpaper(path) {
        if (isApplying) return
        isApplying    = true
        currentWallpaper = path
        applyProc.command = ["awww", "img", path, "--transition-type", "wipe", "--transition-duration", "1"]
        applyProc.running = true
    }

    // ──────────────────────── UI ────────────────────────
    Rectangle {
        id: card

        // グリッド計算
        readonly property int  cols:    4
        readonly property real cellW:   Math.floor((card.width - 24) / cols)  // ~164
        readonly property real cellH:   148
        readonly property real gridNat: wallpaperSelector.imageList.length > 0
            ? Math.ceil(wallpaperSelector.imageList.length / cols) * cellH
            : 100
        readonly property real gridH:   Math.min(gridNat, wallpaperSelector.parentWindow.screen.height * 0.60)

        width:  680
        height: Math.min(56 + gridH + 20, wallpaperSelector.parentWindow.screen.height * 0.80)
        radius: 24
        color:  Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.96)
        clip:   true

        opacity: wallpaperSelector.animProgress
        transform: [
            Translate { y: (1 - wallpaperSelector.animProgress) * -20 },
            Scale {
                xScale: wallpaperSelector.animScale; yScale: wallpaperSelector.animScale
                origin.x: card.width / 2;           origin.y: card.height / 2
            }
        ]

        // ── ヘッダー ──
        Item {
            id: header
            width: card.width; height: 56
            anchors.top: parent.top

            Row {
                anchors.left: parent.left; anchors.leftMargin: 20
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Text {
                    text: "🖼"; font.pixelSize: 15
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: "壁紙を選択"
                    color: Colors.surfaceText
                    font.pixelSize: 14; font.weight: Font.Medium
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Row {
                anchors.right: parent.right; anchors.rightMargin: 20
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10

                // 適用中インジケーター
                Rectangle {
                    width: applyLabel.implicitWidth + 16; height: 24; radius: 999
                    color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.18)
                    visible: wallpaperSelector.isApplying

                    Text {
                        id: applyLabel
                        anchors.centerIn: parent
                        text: "適用中…"
                        color: Colors.primary
                        font.pixelSize: 11
                    }
                }

                Text {
                    text: wallpaperSelector.imageList.length === 0
                        ? (imageFetcher.running ? "読み込み中…" : "")
                        : wallpaperSelector.imageList.length + " 枚"
                    color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.38)
                    font.pixelSize: 12
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            // 区切り線
            Rectangle {
                anchors.bottom: parent.bottom; width: parent.width; height: 1
                color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.08)
            }
        }

        // ── グリッド ──
        Item {
            id: gridWrapper
            anchors.top: header.bottom
            anchors.left: parent.left;  anchors.leftMargin:  12
            anchors.right: parent.right; anchors.rightMargin: 12
            height: card.gridH
            clip: true

            // 空の状態
            Text {
                anchors.centerIn: parent
                text: imageFetcher.running ? "画像を読み込み中…" : "~/Pictures に画像が見つかりません"
                color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.35)
                font.pixelSize: 13
                visible: wallpaperSelector.imageList.length === 0
            }

            GridView {
                anchors.fill: parent
                cellWidth:  card.cellW
                cellHeight: card.cellH
                model:      wallpaperSelector.imageList.length
                clip:       true
                boundsBehavior: Flickable.StopAtBounds
                visible:    wallpaperSelector.imageList.length > 0

                delegate: Item {
                    width: card.cellW; height: card.cellH

                    property string imgPath: wallpaperSelector.imageList[index]
                    property string imgName: imgPath.split("/").pop()
                    property bool   isSelected: wallpaperSelector.currentWallpaper === imgPath

                    Rectangle {
                        anchors.fill: parent; anchors.margins: 5; radius: 16

                        // ホバー背景
                        color: thumbArea.containsMouse
                            ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.10)
                            : "transparent"
                        Behavior on color { ColorAnimation { duration: 120 } }

                        // サムネイル枠
                        Rectangle {
                            id: thumbFrame
                            anchors.top:    parent.top;    anchors.topMargin:    6
                            anchors.left:   parent.left;   anchors.leftMargin:   6
                            anchors.right:  parent.right;  anchors.rightMargin:  6
                            height: parent.height - 28
                            radius: 12
                            color:  Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.06)
                            clip:   true

                            // サムネイル画像
                            Image {
                                id: thumb
                                anchors.fill: parent
                                source:      "file://" + imgPath
                                fillMode:    Image.PreserveAspectCrop
                                sourceSize:  Qt.size(220, 160)
                                asynchronous: true
                            }

                            // 読み込み中フォールバック
                            Text {
                                anchors.centerIn: parent; text: "🖼"; font.pixelSize: 28
                                color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.18)
                                visible: thumb.status !== Image.Ready
                            }

                            // 選択中オーバーレイ
                            Rectangle {
                                anchors.fill: parent
                                color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.28)
                                visible: isSelected

                                Text {
                                    anchors.centerIn: parent; text: "✓"
                                    font.pixelSize: 22; font.weight: Font.Bold
                                    color: Colors.primary
                                }
                            }

                            // 選択中ボーダー
                            Rectangle {
                                anchors.fill: parent; radius: parent.radius
                                color: "transparent"
                                border.color: Colors.primary
                                border.width: isSelected ? 2 : 0
                                Behavior on border.width { NumberAnimation { duration: 120 } }
                            }
                        }

                        // ファイル名
                        Text {
                            anchors.bottom:      parent.bottom; anchors.bottomMargin: 4
                            anchors.left:        parent.left;   anchors.leftMargin:   6
                            anchors.right:       parent.right;  anchors.rightMargin:  6
                            text:  imgName
                            color: isSelected
                                ? Colors.primary
                                : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.6)
                            font.pixelSize: 10
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideMiddle
                            Behavior on color { ColorAnimation { duration: 120 } }
                        }

                        MouseArea {
                            id: thumbArea; anchors.fill: parent; hoverEnabled: true
                            onClicked: wallpaperSelector.applyWallpaper(imgPath)
                        }
                    }
                }
            }
        }
    }
}
