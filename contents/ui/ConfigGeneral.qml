/*
 *  SPDX-FileCopyrightText: 2024 Hydrus Network Slideshow
 *
 *  SPDX-License-Identifier: GPL-2.0-or-later
 */

import QtQuick 2.7
import QtQuick.Controls 2.5
import QtQuick.Layouts 1.12
import org.kde.kirigami 2.4 as Kirigami

Kirigami.FormLayout {
    id: root
    anchors.left: parent.left
    anchors.right: parent.right

    property alias cfg_randomize: randomizeCheckBox.checked
    property alias cfg_pauseOnMouseOver: pauseOnMouseOverCheckBox.checked
    property alias cfg_leftClickOpenImage: leftClickOpenImageCheckBox.checked
    property alias cfg_interval: intervalSpinBox.value
    property alias cfg_fillMode: fillModeCombo.currentIndex

    // Interval
    SpinBox {
        id: intervalSpinBox
        Kirigami.FormData.label: i18nc("@label", "Change picture every (seconds):")
        from: 1
        to: 3600
        value: 10
    }
 
    // Fill mode
    ComboBox {
        id: fillModeCombo
        Kirigami.FormData.label: i18nc("@label:listbox", "Image fill mode:")
        model: [
            i18nc("@item:inlistbox", "Stretch"),
            i18nc("@item:inlistbox", "Preserve aspect fit"),
            i18nc("@item:inlistbox", "Preserve aspect crop"),
            i18nc("@item:inlistbox", "Tile"),
            i18nc("@item:inlistbox", "Tile vertically"),
            i18nc("@item:inlistbox", "Tile horizontally"),
            i18nc("@item:inlistbox", "Pad")
        ]
        currentIndex: 1
    }

    Item {
        Kirigami.FormData.isSection: false
    }

    CheckBox {
         id: randomizeCheckBox
         text: i18nc("@option:check", "Randomize order")
    }

    CheckBox {
        id: pauseOnMouseOverCheckBox
        text: i18nc("@option:check", "Pause slideshow when cursor is over image")
    }

    CheckBox {
        id: leftClickOpenImageCheckBox
        text: i18nc("@option:check", "Click on image to open in external application")
    }
}
