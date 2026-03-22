import QtQuick
import Quickshell
import Quickshell.Services.Notifications

PanelWindow {
    id: toastOverlay

    required property var notificationServer
    property bool silentMode: false

    anchors.right: true
    anchors.top: true
    anchors.bottom: true
    implicitWidth: 340
    color: "transparent"
    exclusiveZone: -1

    // 通知がないかサイレント時は入力を透過
    visible: !silentMode && notificationServer.trackedNotifications.count > 0

    // countの変化をバインディングで監視してgroupedNotifsを更新
    property int notifCount: notificationServer.trackedNotifications.count
    onNotifCountChanged: rebuildGroups()

    property var groupedNotifs: ({})

    function rebuildGroups() {
        const groups = {}
        const model = notificationServer.trackedNotifications
        for (let i = 0; i < model.count; i++) {
            const n = model.get(i)
            if (!n) continue
            const key = n.appName || "unknown"
            if (!groups[key]) groups[key] = []
            groups[key].push(n)
        }
        groupedNotifs = groups
    }

    Component.onCompleted: rebuildGroups()

    Column {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 12
        spacing: 8

        Repeater {
            model: Object.keys(toastOverlay.groupedNotifs)

            delegate: Rectangle {
                required property var modelData

                property string appKey: modelData
                property var notifs: toastOverlay.groupedNotifs[appKey] ?? []
                property var latest: notifs.length > 0 ? notifs[notifs.length - 1] : null

                width: 316
                height: toastInner.implicitHeight + 24
                radius: 16
                color: Colors.surface
                opacity: 0
                x: 20

                Component.onCompleted: {
                    slideInAnim.start()
                    fadeInAnim.start()
                    scaleInAnim.start()
                }

                NumberAnimation {
                    id: slideInAnim
                    target: parent
                    property: "x"
                    from: 80
                    to: 0
                    duration: 400
                    easing.type: Easing.OutBack
                    easing.overshoot: 0.6
                }

                NumberAnimation {
                    id: fadeInAnim
                    target: parent
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: 250
                    easing.type: Easing.OutCubic
                }

                NumberAnimation {
                    id: scaleInAnim
                    target: parent
                    property: "scale"
                    from: 0.88
                    to: 1.0
                    duration: 400
                    easing.type: Easing.OutBack
                    easing.overshoot: 0.6
                }

                Behavior on height {
                    NumberAnimation { duration: 150 }
                }

                Timer {
                    interval: (latest?.expireTimeout ?? 0) > 0
                        ? latest.expireTimeout * 1000
                        : 5000
                    running: latest !== null
                    onTriggered: {
                        if (latest) latest.expire()
                    }
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.margins: 4
                    width: 3
                    radius: 999
                    color: (latest?.urgency ?? 0) === NotificationUrgency.Critical
                        ? Colors.errorColor
                        : Colors.primary
                }

                Column {
                    id: toastInner
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 12
                    anchors.leftMargin: 20
                    spacing: 4

                    Item {
                        width: parent.width
                        height: 16

                        Image {
                            id: toastIcon
                            width: 16; height: 16
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            source: latest?.appIcon ?? ""
                            visible: (latest?.appIcon ?? "") !== ""
                            fillMode: Image.PreserveAspectFit
                        }

                        Text {
                            anchors.left: toastIcon.visible ? toastIcon.right : parent.left
                            anchors.leftMargin: toastIcon.visible ? 6 : 0
                            anchors.verticalCenter: parent.verticalCenter
                            text: appKey
                            color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.6)
                            font.pixelSize: 11
                            font.weight: Font.Medium
                        }

                        Rectangle {
                            anchors.left: toastIcon.visible ? toastIcon.right : parent.left
                            anchors.leftMargin: (toastIcon.visible ? toastIcon.width + 6 : 0) + 60
                            anchors.verticalCenter: parent.verticalCenter
                            width: countBadge.implicitWidth + 8
                            height: 16
                            radius: 999
                            color: Colors.primary
                            visible: notifs.length > 1

                            Text {
                                id: countBadge
                                anchors.centerIn: parent
                                text: notifs.length
                                color: Colors.primaryText
                                font.pixelSize: 10
                                font.weight: Font.Bold
                            }
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: "✕"
                            color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.4)
                            font.pixelSize: 11

                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -4
                                onClicked: {
                                    const list = [...notifs]
                                    list.forEach(n => { if (n) n.dismiss() })
                                }
                            }
                        }
                    }

                    Text {
                        width: parent.width
                        text: latest?.summary ?? ""
                        color: Colors.surfaceText
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                        visible: (latest?.summary ?? "") !== ""
                    }

                    Text {
                        width: parent.width
                        text: latest?.body ?? ""
                        color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.8)
                        font.pixelSize: 12
                        wrapMode: Text.WordWrap
                        maximumLineCount: 3
                        elide: Text.ElideRight
                        visible: (latest?.body ?? "") !== ""
                        textFormat: Text.PlainText
                    }

                    Column {
                        width: parent.width
                        spacing: 2
                        visible: notifs.length > 1

                        Repeater {
                            model: notifs.slice(0, notifs.length - 1).reverse()

                            Text {
                                required property var modelData

                                width: parent.width
                                text: "• " + (modelData.summary ?? "")
                                color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.4)
                                font.pixelSize: 11
                                elide: Text.ElideRight
                                visible: (modelData.summary ?? "") !== ""
                            }
                        }
                    }

                    Item { width: 1; height: 4 }
                }
            }
        }
    }
}
