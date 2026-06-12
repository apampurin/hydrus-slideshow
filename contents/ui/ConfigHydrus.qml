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

    property string cfg_apiUrl: "http://127.0.0.1:45869"
    property string cfg_accessKey: ""
    property string cfg_searchTags: ""
    property string cfg_fileDomain: "all local files"
    property bool cfg_showThumbnails: true

    // Hydrus API URL
    TextField {
        id: apiUrlField
        Kirigami.FormData.label: i18nc("@label:textbox", "Hydrus API URL:")
        placeholderText: i18n("e.g. http://127.0.0.1:45869")
        text: cfg_apiUrl
        onTextChanged: cfg_apiUrl = text
    }

    // Access Key
    TextField {
        id: accessKeyField
        Kirigami.FormData.label: i18nc("@label:textbox", "Access Key:")
        placeholderText: i18n("Your Hydrus API Access Key")
        text: cfg_accessKey
        echoMode: TextInput.Password
        onTextChanged: cfg_accessKey = text
    }
 
    // File domain
    TextField {
        id: fileDomainField
        Kirigami.FormData.label: i18nc("@label:textbox", "File domain:")
        placeholderText: i18n("e.g. all local files, my tags")
        text: cfg_fileDomain
        onTextChanged: cfg_fileDomain = text
    }

    Label {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        text: i18n("The file service to search. Default: 'all local files'. You can use simple names like 'my tags' or Hydrus service keys.")
        opacity: 0.6
        font.pointSize: 8
    }

    // Search tags
    TextField {
        id: searchTagsField
        Kirigami.FormData.label: i18nc("@label:textbox", "Search tags:")
        placeholderText: i18n("e.g. anime, cute, wallpaper")
        text: cfg_searchTags
        onTextChanged: cfg_searchTags = text
    }

    Label {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        text: i18n("Comma-separated tags to search for.")
        opacity: 0.6
        font.pointSize: 8
    }
 
    // Performance
    CheckBox {
         id: showThumbnailsCheckBox
         text: i18nc("@option:check", "Use thumbnails instead of full images")
        checked: cfg_showThumbnails
        onCheckedChanged: cfg_showThumbnails = checked
    }

    Label {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        text: i18n("Using thumbnails is faster but may show lower resolution images.")
        opacity: 0.6
        font.pointSize: 8
    }
}
