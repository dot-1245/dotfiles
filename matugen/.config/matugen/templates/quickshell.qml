pragma Singleton
import QtQuick

QtObject {
    readonly property color primary:        "{{colors.primary.default.hex}}"
    readonly property color primaryText:    "{{colors.on_primary.default.hex}}"
    readonly property color background:     "{{colors.background.default.hex}}"
    readonly property color backgroundText: "{{colors.on_background.default.hex}}"
    readonly property color surface:        "{{colors.surface.default.hex}}"
    readonly property color surfaceText:    "{{colors.on_surface.default.hex}}"
    readonly property color secondary:      "{{colors.secondary.default.hex}}"
    readonly property color secondaryText:  "{{colors.on_secondary.default.hex}}"
    readonly property color errorColor:     "{{colors.error.default.hex}}"
}
