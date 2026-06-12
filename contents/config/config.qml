/*
 *  SPDX-FileCopyrightText: 2024 Hydrus Network Slideshow
 *
 *  SPDX-License-Identifier: GPL-2.0-or-later
 */

import QtQuick 2.1

import org.kde.plasma.configuration 2.0

ConfigModel {
    ConfigCategory {
         name: i18nc("@title", "General")
         icon: "image"
         source: "ConfigGeneral.qml"
    }
    ConfigCategory {
         name: i18nc("@title", "Hydrus API")
         icon: "network-connect"
         source: "ConfigHydrus.qml"
    }
}
