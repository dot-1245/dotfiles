import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

PopupWindow {
    id: launcher
    visible: false
    color: "transparent"

    required property var parentWindow

    anchor.window: parentWindow
    anchor.rect.x: Math.round((parentWindow.width - card.width) / 2)
    anchor.rect.y: Math.round(parentWindow.screen.height * 0.12)

    implicitWidth:  card.width
    implicitHeight: card.height

    // ──────────────────────── アニメーション ────────────────────────
    property real animProgress: 0
    property real animScale:    0.94

    onVisibleChanged: {
        if (visible) {
            searchField.text = ""
            searchField.forceActiveFocus()
            animProgress = 0
            animScale    = 0.94
            showProgressAnim.start()
            showScaleAnim.start()
        }
    }

    NumberAnimation { id: showProgressAnim; target: launcher; property: "animProgress"; from: 0; to: 1; duration: 240; easing.type: Easing.OutCubic }
    NumberAnimation { id: showScaleAnim;    target: launcher; property: "animScale";    from: 0.94; to: 1.0; duration: 240; easing.type: Easing.OutCubic }
    NumberAnimation {
        id: hideAnim
        target: launcher; property: "animProgress"
        from: 1; to: 0; duration: 160; easing.type: Easing.InCubic
        onFinished: launcher.visible = false
    }

    function toggleVisible() {
        if (launcher.visible) hideAnim.start()
        else launcher.visible = true
    }

    // ──────────────────────── アプリデータ ────────────────────────
    property var  appList: []
    property int  cursor:  0
    property bool isSearching: searchField.text !== ""

    ListModel { id: filteredModel }

    function updateFilter() {
        filteredModel.clear()
        const q = searchField.text.toLowerCase()
        if (q === "") { cursor = 0; return }
        let n = 0
        for (const app of appList) {
            if (n >= 9) break
            if (app.name.toLowerCase().includes(q) || app.comment.toLowerCase().includes(q)) {
                filteredModel.append(app)
                n++
            }
        }
        cursor = 0
    }

    // XDG .desktop ファイルから取得
    Process {
        id: appFetcher
        running: true
        command: [
            "python3", "-c",
`
import os, json, glob, re
from configparser import ConfigParser

seen = set()
apps = []
for d in ["/usr/share/applications", os.path.expanduser("~/.local/share/applications")]:
    for path in sorted(glob.glob(d + "/*.desktop")):
        p = ConfigParser(strict=False, interpolation=None)
        try: p.read(path, encoding="utf-8")
        except: continue
        if "Desktop Entry" not in p: continue
        e = p["Desktop Entry"]
        if e.get("type", "") != "Application": continue
        if e.get("nodisplay", "false").lower() == "true": continue
        name = e.get("name", "").strip()
        if not name or name in seen: continue
        seen.add(name)
        exec_cmd = re.sub(r" ?%[a-zA-Z]", "", e.get("exec", "")).strip()
        apps.append({
            "name":    name,
            "exec":    exec_cmd,
            "icon":    e.get("icon", ""),
            "comment": e.get("comment", "")
        })

apps.sort(key=lambda x: x["name"].lower())
print(json.dumps(apps, ensure_ascii=False))
`
        ]
        stdout: SplitParser {
            onRead: data => {
                try {
                    launcher.appList = JSON.parse(data)
                } catch(e) { console.warn("[AppLauncher] parse error:", e) }
            }
        }
    }

    Process { id: launchProc; running: false; command: [] }

    function launchApp(app) {
        launchProc.command = ["bash", "-c", app.exec + " &disown"]
        launchProc.running = true
        hideAnim.start()
    }

    // ──────────────────────── UI ────────────────────────
    Rectangle {
        id: card

        // グリッド計算
        readonly property int   gridCols:    6
        readonly property real  cellW:       Math.floor((card.width - 24) / gridCols)  // ~99
        readonly property real  cellH:       96
        readonly property real  gridNatural: launcher.appList.length > 0
            ? Math.ceil(launcher.appList.length / gridCols) * cellH
            : cellH
        readonly property real  gridCapped:  Math.min(gridNatural, launcher.parentWindow.screen.height * 0.56)

        width:  620
        height: Math.min(contentCol.implicitHeight + 20, launcher.parentWindow.screen.height * 0.80)
        radius: 24
        color:  Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.96)
        clip:   true

        opacity: launcher.animProgress
        transform: [
            Translate { y: (1 - launcher.animProgress) * -20 },
            Scale {
                xScale: launcher.animScale; yScale: launcher.animScale
                origin.x: card.width / 2;  origin.y: card.height / 2
            }
        ]

        Column {
            id: contentCol
            width: card.width - 24
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 12
            spacing: 8

            // ── 検索バー ──
            Rectangle {
                width: parent.width; height: 52; radius: 16
                color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.07)

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 16; anchors.rightMargin: 14
                    spacing: 12

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "🔍"; font.pixelSize: 15; opacity: 0.4
                    }

                    TextInput {
                        id: searchField
                        width: parent.width - 44; height: parent.height
                        font.pixelSize: 15
                        color: Colors.surfaceText
                        selectionColor:    Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.45)
                        selectedTextColor: Colors.surfaceText
                        verticalAlignment: TextInput.AlignVCenter
                        clip: true

                        onTextChanged: launcher.updateFilter()

                        Keys.onEscapePressed: hideAnim.start()
                        Keys.onReturnPressed: {
                            if (filteredModel.count > 0)
                                launcher.launchApp(filteredModel.get(launcher.cursor))
                        }
                        Keys.onDownPressed: launcher.cursor = Math.min(launcher.cursor + 1, filteredModel.count - 1)
                        Keys.onUpPressed:   launcher.cursor = Math.max(launcher.cursor - 1, 0)

                        Text {
                            anchors.fill: parent
                            text: "アプリを検索…"
                            color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.3)
                            font.pixelSize: 15; verticalAlignment: Text.AlignVCenter
                            visible: searchField.text === ""
                        }
                    }
                }
            }

            // ── グリッドモード（検索なし）──
            Item {
                width:   parent.width
                height:  card.gridCapped
                visible: !launcher.isSearching && launcher.appList.length > 0
                clip:    true

                GridView {
                    id: appGrid
                    anchors.fill: parent
                    cellWidth:  card.cellW
                    cellHeight: card.cellH
                    model:      launcher.appList.length
                    clip:       true
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Item {
                        width: card.cellW; height: card.cellH
                        property var app: launcher.appList[index]

                        Rectangle {
                            anchors.fill: parent; anchors.margins: 4; radius: 18
                            color: cellArea.pressed
                                ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.28)
                                : cellArea.containsMouse
                                    ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.13)
                                    : "transparent"
                            Behavior on color { ColorAnimation { duration: 100 } }

                            Column {
                                anchors.centerIn: parent
                                spacing: 5

                                Item {
                                    width: 44; height: 44
                                    anchors.horizontalCenter: parent.horizontalCenter

                                    Image {
                                        id: gridIcon
                                        anchors.fill: parent
                                        sourceSize: Qt.size(44, 44)
                                        fillMode: Image.PreserveAspectFit
                                        source: app.icon.startsWith("/") ? app.icon : ("image://xdgicon/" + app.icon)
                                        asynchronous: true
                                    }
                                    Text {
                                        anchors.centerIn: parent; text: "📦"; font.pixelSize: 26
                                        visible: gridIcon.status !== Image.Ready
                                    }
                                }

                                Text {
                                    width: card.cellW - 8
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: app.name
                                    color: Colors.surfaceText
                                    font.pixelSize: 10
                                    horizontalAlignment: Text.AlignHCenter
                                    elide: Text.ElideRight
                                    maximumLineCount: 2
                                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                                }
                            }

                            MouseArea {
                                id: cellArea; anchors.fill: parent; hoverEnabled: true
                                onClicked: launcher.launchApp(app)
                            }
                        }
                    }
                }
            }

            // ── リストモード（検索あり）──
            Column {
                width: parent.width; spacing: 2
                visible: launcher.isSearching && filteredModel.count > 0

                Repeater {
                    model: filteredModel

                    Rectangle {
                        id: listRow
                        width: contentCol.width; height: 52; radius: 12

                        readonly property bool isActive: launcher.cursor === index

                        color: isActive
                            ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.18)
                            : rowArea.containsMouse
                                ? Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.06)
                                : "transparent"
                        Behavior on color { ColorAnimation { duration: 80 } }

                        Rectangle {
                            x: 0; width: 3; height: 24; radius: 999
                            anchors.verticalCenter: parent.verticalCenter
                            color:   Colors.primary
                            opacity: listRow.isActive ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 80 } }
                        }

                        MouseArea {
                            id: rowArea; anchors.fill: parent; hoverEnabled: true
                            onEntered: launcher.cursor = index
                            onClicked: launcher.launchApp(model)
                        }

                        Row {
                            anchors { fill: parent; leftMargin: 14; rightMargin: 12 }
                            spacing: 12

                            Item {
                                width: 32; height: 32; anchors.verticalCenter: parent.verticalCenter
                                Image {
                                    id: listIcon; anchors.fill: parent; sourceSize: Qt.size(32, 32)
                                    fillMode: Image.PreserveAspectFit
                                    source: model.icon.startsWith("/") ? model.icon : ("image://xdgicon/" + model.icon)
                                    asynchronous: true
                                }
                                Text { anchors.centerIn: parent; text: "📦"; font.pixelSize: 20; visible: listIcon.status !== Image.Ready }
                            }

                            Column {
                                width: parent.width - 32 - 12 - (listRow.isActive ? 26 : 0)
                                anchors.verticalCenter: parent.verticalCenter; spacing: 2
                                Text {
                                    width: parent.width; text: model.name
                                    color: listRow.isActive ? Colors.primary : Colors.surfaceText
                                    font.pixelSize: 13; font.weight: Font.Medium; elide: Text.ElideRight
                                    Behavior on color { ColorAnimation { duration: 80 } }
                                }
                                Text {
                                    width: parent.width; text: model.comment
                                    color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.45)
                                    font.pixelSize: 10; elide: Text.ElideRight
                                    visible: model.comment !== ""
                                }
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter; text: "↵"; font.pixelSize: 12
                                color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.65)
                                visible: listRow.isActive
                            }
                        }
                    }
                }
            }

            // ── 検索結果なし ──
            Item {
                width: parent.width; height: 52
                visible: launcher.isSearching && filteredModel.count === 0
                Text {
                    anchors.centerIn: parent
                    text: `"${searchField.text}" が見つかりません`
                    color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.35)
                    font.pixelSize: 13
                }
            }

            // ── ヒント ──
            Item {
                width: parent.width; height: 30
                Text {
                    anchors.centerIn: parent
                    text: launcher.isSearching
                        ? "↑↓ 移動  •  Enter 起動  •  Esc 閉じる"
                        : "入力で検索  •  クリックまたは Enter で起動  •  Esc 閉じる"
                    color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.22)
                    font.pixelSize: 11
                }
            }
        }
    }
}
