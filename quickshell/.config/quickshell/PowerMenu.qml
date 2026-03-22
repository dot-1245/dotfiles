import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

PopupWindow {
    id: powerPopup
    visible: false
    implicitWidth: 200
    implicitHeight: 340
    color: "transparent"

    required property var parentWindow

    anchor.window: parentWindow
    anchor.rect.x: parentWindow.width - 216
    anchor.rect.y: parentWindow.height - 8

    property real animProgress: 0
    property real animScale: 0.85

    onVisibleChanged: {
        if (visible) {
            animProgress = 0
            animScale = 0.85
            showProgressAnim.start()
            showScaleAnim.start()
        }
    }

    // ムニュッ：translateとscaleを組み合わせ
    NumberAnimation {
        id: showProgressAnim
        target: powerPopup
        property: "animProgress"
        from: 0; to: 1
        duration: 380
        easing.type: Easing.OutBack
        easing.overshoot: 0.8
    }

    NumberAnimation {
        id: showScaleAnim
        target: powerPopup
        property: "animScale"
        from: 0.85; to: 1.0
        duration: 380
        easing.type: Easing.OutBack
        easing.overshoot: 0.8
    }

    NumberAnimation {
        id: hideAnim
        target: powerPopup
        property: "animProgress"
        from: 1; to: 0
        duration: 180
        easing.type: Easing.InBack
        easing.overshoot: 0.5
        onFinished: powerPopup.visible = false
    }

    function toggleVisible() {
        if (powerPopup.visible) {
            hideAnim.start()
        } else {
            powerPopup.visible = true
        }
    }

    // バーとつながるコネクター
    Rectangle {
        anchors.top: parent.top
        anchors.right: parent.right
        width: parent.width
        height: 16
        color: Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.95)
        opacity: powerPopup.animProgress
    }

    Rectangle {
        anchors.fill: parent
        anchors.topMargin: 8
        radius: 24
        color: Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.95)
        clip: true
        opacity: powerPopup.animProgress
        transform: [
            Translate { y: (1 - powerPopup.animProgress) * -24 },
            Scale {
                xScale: powerPopup.animScale
                yScale: powerPopup.animScale
                origin.x: powerPopup.width / 2
                origin.y: 0
            }
        ]

        Column {
            anchors.centerIn: parent
            spacing: 8

            Repeater {
                model: [
                    { icon: "🔒", label: "ロック",    sub: "hyprlock",          cmd: ["hyprlock"] },
                    { icon: "🚪", label: "ログアウト", sub: "セッション終了",     cmd: ["hyprctl", "dispatch", "exit"] },
                    { icon: "💤", label: "スリープ",  sub: "サスペンド",         cmd: ["systemctl", "suspend"] },
                    { icon: "🔄", label: "再起動",    sub: "システム再起動",     cmd: ["systemctl", "reboot"] },
                    { icon: "⏻",  label: "シャットダウン", sub: "電源を切る",    cmd: ["systemctl", "poweroff"] }
                ]

                Rectangle {
                    width: 168
                    height: 52
                    radius: 16
                    color: btnArea.pressed
                        ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.3)
                        : btnArea.containsMouse
                            ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.15)
                            : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.06)

                    Behavior on color { ColorAnimation { duration: 120 } }

                    // 左のアイコンエリア
                    Rectangle {
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        width: 36
                        height: 36
                        radius: 999
                        color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.15)

                        Text {
                            anchors.centerIn: parent
                            text: modelData.icon
                            font.pixelSize: 16
                        }
                    }

                    // テキスト
                    Column {
                        anchors.left: parent.left
                        anchors.leftMargin: 56
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                            text: modelData.label
                            color: Colors.surfaceText
                            font.pixelSize: 13
                            font.weight: Font.Medium
                        }

                        Text {
                            text: modelData.sub
                            color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.5)
                            font.pixelSize: 10
                        }
                    }

                    MouseArea {
                        id: btnArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: proc.running = true
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
