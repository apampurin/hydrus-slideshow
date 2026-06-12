/*
 *  Hydrus Network Slideshow - Plasma widget
 *
 *  Based on org.kde.plasma.mediaframe
 *  SPDX-FileCopyrightText: 2015 Lars Pontoppidan <dev.larpon@gmail.com>
 *
 *  SPDX-License-Identifier: GPL-2.0-or-later
 */

import QtQuick 2.5
import QtQuick.Layouts 1.1

import org.kde.draganddrop 2.0 as DragDrop

import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.components 3.0 as PlasmaComponents3

Item {
    id: main

    Plasmoid.preferredRepresentation: plasmoid.fullRepresentation

    Plasmoid.switchWidth: PlasmaCore.Units.gridUnit * 5
    Plasmoid.switchHeight: PlasmaCore.Units.gridUnit * 5

    Plasmoid.backgroundHints: PlasmaCore.Types.DefaultBackground | PlasmaCore.Types.ConfigurableBackground

    width: PlasmaCore.Units.gridUnit * 20
    height: PlasmaCore.Units.gridUnit * 13

    // -----------------------------------------------------------------------
    // Hydrus API state
    // -----------------------------------------------------------------------
    property string hydrusApiUrl: plasmoid.configuration.apiUrl || "http://127.0.0.1:45869"
    property string hydrusAccessKey: plasmoid.configuration.accessKey || ""
    property string hydrusSearchTags: plasmoid.configuration.searchTags || ""
    property string hydrusDisplayTags: plasmoid.configuration.displayTags || ""
    property string hydrusFileDomain: plasmoid.configuration.fileDomain || "all local files"
    property bool hydrusShowThumbnails: plasmoid.configuration.showThumbnails !== false

    // Image list and navigation state
    property var fileHashes: []
    property var fileHashToTags: ({})
    property int currentImageIndex: -1
    property var history: []
    property var future: []

    // Loading state
    property bool loading: false
    property bool hasFetched: false
    property string errorMessage: ""

    // For the UI
    property string activeSource: ""
    property string transitionSource: ""

    readonly property bool pause: overlayMouseArea.containsMouse && plasmoid.configuration.pauseOnMouseOver
    readonly property int itemCount: fileHashes.length
    readonly property bool hasItems: fileHashes.length > 0

    // -----------------------------------------------------------------------
    // Slideshow timer
    // -----------------------------------------------------------------------
    Timer {
        id: nextTimer
        interval: (plasmoid.configuration.interval || 10) * 1000
        repeat: true
        running: hasItems && !pause && !loading
        onTriggered: nextItem()
    }

    // -----------------------------------------------------------------------
    // Hydrus API interaction
    // -----------------------------------------------------------------------
    function fetchImages() {
        console.log("Hydrus: fetchImages")

        var tags = hydrusSearchTags.split(',').map(function(t) { return t.trim() }).filter(function(t) { return t !== "" })

        if (!hydrusApiUrl || !hydrusAccessKey || tags.length === 0) {
            loading = false
            hasFetched = true
            console.log("Hydrus: not configured, tags:", JSON.stringify(tags))
            return
        }

        loading = true
        activeSource = ""

        // Build URL for search
        // file_service_key is not passed: Hydrus uses "all my files" by default.
        // Passing a service name like "all local files" fails because Hydrus expects a hex service key.
        var url = hydrusApiUrl + "/get_files/search_files?tags=" + encodeURIComponent(JSON.stringify(tags)) +
                  "&return_hashes=true&return_file_ids=false"

        console.log("Hydrus: fetch URL:", url)
        console.log("Hydrus: access key length:", hydrusAccessKey ? hydrusAccessKey.length : 0)

        var xhr = new XMLHttpRequest()
        xhr.open("GET", url)
        xhr.setRequestHeader("Hydrus-Client-API-Access-Key", hydrusAccessKey)
        console.log("Hydrus: request header set: Hydrus-Client-API-Access-Key")

        xhr.onload = function() {
            console.log("Hydrus: response status:", xhr.status)
            console.log("Hydrus: response text:", xhr.responseText)
            if (xhr.status === 200) {
                try {
                    var resp = JSON.parse(xhr.responseText)
                    console.log("Hydrus: parsed response:", JSON.stringify(resp))
                    fileHashes = resp.hashes || []

                    if (fileHashes.length > 0) {
                        // If randomize, shuffle the array
                        if (plasmoid.configuration.randomize) {
                            shuffleArray(fileHashes)
                        }
                        history = []
                        future = []
                        currentImageIndex = 0
                        setActiveSource(getImageUrl(fileHashes[0]))
                        hasFetched = true
                    } else {
                        hasFetched = true
                        console.log("Hydrus: no images found for tags")
                    }
                } catch(e) {
                    console.error("Hydrus: JSON parse error", e)
                }
            } else {
                console.error("Hydrus: HTTP error", xhr.status, xhr.responseText)
            }
            loading = false
        }

        xhr.onerror = function() {
            loading = false
            hasFetched = true
            console.error("Hydrus: Network error - could not reach", hydrusApiUrl)
        }

        xhr.send()
    }

    function getImageUrl(hash) {
        if (hydrusShowThumbnails) {
            return hydrusApiUrl + "/get_files/thumbnail?hash=" + hash +
                   "&Hydrus-Client-API-Access-Key=" + hydrusAccessKey
        } else {
            return hydrusApiUrl + "/get_files/file?hash=" + hash +
                   "&Hydrus-Client-API-Access-Key=" + hydrusAccessKey
        }
    }

    function shuffleArray(arr) {
        for (var i = arr.length - 1; i > 0; i--) {
            var j = Math.floor(Math.random() * (i + 1));
            var tmp = arr[i];
            arr[i] = arr[j];
            arr[j] = tmp;
        }
    }

    // -----------------------------------------------------------------------
    // Navigation
    // -----------------------------------------------------------------------
    function nextItem() {
        if (!hasItems) {
            console.warn("Hydrus: No items to navigate")
            return
        }

        var active = activeSource

        // Record history
        if (itemCount > 1) {
            if (history.length > 50) history.shift() // limit history
            history.push(fileHashes[currentImageIndex])
        }

        // If we have future items, use those first
        if (future.length > 0) {
            currentImageIndex = fileHashes.indexOf(future.pop())
            if (currentImageIndex < 0) currentImageIndex = 0
        } else {
            // Otherwise advance linearly
            currentImageIndex = (currentImageIndex + 1) % fileHashes.length
        }

        setActiveSource(getImageUrl(fileHashes[currentImageIndex]))
    }

    function previousItem() {
        if (history.length === 0 || !hasItems) return

        // Push current to future
        future.push(fileHashes[currentImageIndex])

        // Pop from history
        var prevHash = history.pop()
        currentImageIndex = fileHashes.indexOf(prevHash)
        if (currentImageIndex < 0) currentImageIndex = 0

        setActiveSource(getImageUrl(fileHashes[currentImageIndex]))
    }

    // -----------------------------------------------------------------------
    // Image transitions
    // -----------------------------------------------------------------------
    function setActiveSource(source) {
        if (itemCount > 1) {
            // Fade transition
            transitionSource = source
            faderAnimation.restart()
        } else {
            transitionSource = source
            activeSource = source
        }
    }

    // -----------------------------------------------------------------------
    // Lifecycle
    // -----------------------------------------------------------------------
    Component.onCompleted: {
        console.log("Hydrus widget loaded")
        // Start fetching images immediately
        fetchImages()
    }

    // Re-fetch on config changes
    Connections {
        target: plasmoid.configuration

        function onApiUrlChanged() { 
            console.log("API URL changed")
            fetchImages() 
        }
        function onAccessKeyChanged() { 
            console.log("Access key changed")
            fetchImages() 
        }
        function onSearchTagsChanged() { 
            console.log("Search tags changed")
            fetchImages() 
        }
        function onDisplayTagsChanged() { /* handled by display */ }
        function onShowThumbnailsChanged() {
            // Rebuild URLs for current image
            if (fileHashes.length > 0 && currentImageIndex >= 0) {
                setActiveSource(getImageUrl(fileHashes[currentImageIndex]))
            }
        }
        function onIntervalChanged() {
            nextTimer.interval = (plasmoid.configuration.interval || 10) * 1000
        }
        function onRandomizeChanged() { /* takes effect on next fetch */ }
        function onFillModeChanged() { /* handled by fillMode binding */ }
        function onFileDomainChanged() {
            console.log("File domain changed")
            fetchImages()
        }
    }


    // -----------------------------------------------------------------------
    // UI Layout
    // -----------------------------------------------------------------------

    // Background
    Rectangle {
        anchors.fill: parent
        color: PlasmaCore.Theme.backgroundColor

        // Loading indicator
        PlasmaComponents3.BusyIndicator {
            anchors.centerIn: parent
            running: loading
            visible: loading
            z: 10
        }
    }

    // Image display area with fade transition
    Item {
        id: itemView
        anchors.fill: parent

        Item {
            id: imageView
            visible: hasItems
            anchors.fill: parent

            // Prevents reloading image too often when resizing
            Timer {
                id: imageReloadTimer
                interval: 250
                running: false
                onTriggered: {
                    frontImage.sourceSize.width = width
                    frontImage.sourceSize.height = height
                }
            }

            // Back buffer image (for transition)
            Image {
                id: bufferImage
                anchors.fill: parent
                fillMode: plasmoid.configuration.fillMode
                opacity: 0
                cache: false
                source: transitionSource
                asynchronous: true
                autoTransform: true
            }

            // Front image (visible)
            Image {
                id: frontImage
                anchors.fill: parent
                fillMode: plasmoid.configuration.fillMode
                cache: false
                source: activeSource
                asynchronous: true
                autoTransform: true

                onWidthChanged: imageReloadTimer.restart()
                onHeightChanged: imageReloadTimer.restart()

                sourceSize.width: width
                sourceSize.height: height

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (plasmoid.configuration.leftClickOpenImage && activeSource) {
                            // Extract hash from URL to open in hydrus client
                            var hash = extractHashFromUrl(activeSource)
                            if (hash) {
                                Qt.openUrlExternally(hydrusApiUrl + "/get_files/file?hash=" + hash +
                                    "&Hydrus-Client-API-Access-Key=" + hydrusAccessKey)
                            }
                        }
                    }
                    enabled: plasmoid.configuration.leftClickOpenImage
                }
            }
        }

        // Helper: extract hash from our URL format
        function extractHashFromUrl(url) {
            if (!url) return ""
            var match = url.match(/hash=([a-f0-9]+)/i)
            return match ? match[1] : ""
        }

        // Empty state
        Column {
            anchors.centerIn: parent
            spacing: PlasmaCore.Units.smallSpacing
            visible: !loading && !hasItems

            PlasmaComponents3.Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: {
                    if (!hydrusApiUrl || !hydrusAccessKey) {
                        return i18n("API not configured")
                    } else if (hydrusSearchTags.trim() === "") {
                        return i18n("No search tags configured")
                    } else {
                        return i18n("No images found")
                    }
                }
                opacity: 0.6
            }

            PlasmaComponents3.Label {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: errorMessage !== ""
                text: errorMessage
                opacity: 0.5
                font.pointSize: 8
                color: "red"
            }
        }

        // Configure button (when no items)
        PlasmaComponents3.Button {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: PlasmaCore.Units.gridUnit * 2
            visible: !loading && !hasItems && hydrusSearchTags.trim() === ""
            icon.name: "configure"
            text: i18nc("@action:button", "Configure…")
            onClicked: {
                plasmoid.action("configure").trigger()
            }
        }
    }

    // -----------------------------------------------------------------------
    // Fade transition animation
    // -----------------------------------------------------------------------
    SequentialAnimation {
        id: faderAnimation

        ParallelAnimation {
            OpacityAnimator { target: frontImage; from: 1; to: 0; duration: PlasmaCore.Units.veryLongDuration }
            OpacityAnimator { target: bufferImage; from: 0; to: 1; duration: PlasmaCore.Units.veryLongDuration }
        }
        ScriptAction {
            script: {
                var ts = transitionSource
                activeSource = ts
                frontImage.opacity = 1
                transitionSource = ""
                bufferImage.opacity = 0
            }
        }
    }

    // -----------------------------------------------------------------------
    // Overlay with navigation controls
    // -----------------------------------------------------------------------
    Item {
        id: overlay
        anchors.fill: parent
        visible: hasItems
        opacity: overlayMouseArea.containsMouse ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: PlasmaCore.Units.longDuration }
        }

        // Previous button
        PlasmaComponents3.Button {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: PlasmaCore.Units.smallSpacing
            enabled: history.length > 0
            visible: main.itemCount > 1
            icon.name: "arrow-left"
            onClicked: {
                nextTimer.stop()
                previousItem()
            }
        }

        // Next button
        PlasmaComponents3.Button {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.rightMargin: PlasmaCore.Units.smallSpacing
            enabled: hasItems
            visible: main.itemCount > 1
            icon.name: "arrow-right"
            onClicked: {
                nextTimer.stop()
                nextItem()
            }
        }

        // Bottom buttons row
        Row {
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottomMargin: PlasmaCore.Units.smallSpacing
            spacing: PlasmaCore.Units.smallSpacing

            // Open in Hydrus client
            PlasmaComponents3.Button {
                icon.name: "document-preview"
                onClicked: {
                    if (activeSource) {
                        var hash = itemView.extractHashFromUrl(activeSource)
                        if (hash) {
                            Qt.openUrlExternally(hydrusApiUrl + "/get_files/file?hash=" + hash +
                                "&Hydrus-Client-API-Access-Key=" + hydrusAccessKey)
                        }
                    }
                }
            }
        }

        // Mouse area for hover detection
        MouseArea {
            id: overlayMouseArea
            anchors.fill: parent
            hoverEnabled: true
            propagateComposedEvents: true
            onPressed: mouse.accepted = false
            onDoubleClicked: mouse.accepted = false
        }
    }

    // -----------------------------------------------------------------------
    // Drag & Drop support
    // -----------------------------------------------------------------------
    DragDrop.DropArea {
        id: dropArea
        anchors.fill: parent

        onDrop: {
            var mimeData = event.mimeData
            if (mimeData.hasUrls) {
                var urls = mimeData.urls
                for (var i = 0, j = urls.length; i < j; ++i) {
                    var url = urls[i]
                    console.log("Hydrus: dropped", url)
                    // For now, just accept drops but don't add local files
                    // (we could convert URLs to tags in the future)
                }
            }
            event.accept(Qt.CopyAction)
        }
    }

    // -----------------------------------------------------------------------
    // External data (e.g. from other plasmoids / KDE Connect)
    // -----------------------------------------------------------------------
    Connections {
        target: plasmoid
        function onExternalData(mimetype, data) {
            if (mimetype === "text/plain") {
                // If someone sends us tags, add them to search
                console.log("Hydrus: external data", mimetype, data)
            }
        }
    }
}