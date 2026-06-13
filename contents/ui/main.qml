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
    
    // Cached service key
    property string resolvedServiceKey: ""
    property int currentRating: 0 // 0: unset, 1: like, -1: dislike

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
    // Reconnection timer - retries connection every 10 seconds when no items
    // -----------------------------------------------------------------------
    Timer {
        id: reconnectTimer
        interval: 10000
        repeat: true
        running: !hasItems && hasFetched && !loading
        onTriggered: {
            console.log("Hydrus: attempting reconnection...")
            fetchImages()
        }
    }

    // -----------------------------------------------------------------------
    // Image URL helpers
    // -----------------------------------------------------------------------
    function getImageUrl(hash) {
        if (hydrusShowThumbnails) {
            return hydrusApiUrl + "/get_files/thumbnail?hash=" + hash +
                   "&Hydrus-Client-API-Access-Key=" + hydrusAccessKey
        } else {
            return hydrusApiUrl + "/get_files/file?hash=" + hash +
                   "&Hydrus-Client-API-Access-Key=" + hydrusAccessKey
        }
    }

    // -----------------------------------------------------------------------
    // Resolve file domain name -> service key (async, caches result)
    // -----------------------------------------------------------------------
    function resolveServiceKey() {
        if (!hydrusFileDomain || hydrusFileDomain === "" || hydrusFileDomain === "all local files") {
            resolvedServiceKey = ""
            console.log("Hydrus: using default file domain, no service key needed")
            return
        }

        console.log("Hydrus: resolving service key for domain:", hydrusFileDomain)

        var svcXhr = new XMLHttpRequest()
        var svcUrl = hydrusApiUrl + "/get_services"
        svcXhr.open("GET", svcUrl)
        svcXhr.setRequestHeader("Hydrus-Client-API-Access-Key", hydrusAccessKey)

        svcXhr.onload = function() {
            if (svcXhr.status === 200) {
                try {
                    var svcResp = JSON.parse(svcXhr.responseText)
                    var servicesObj = svcResp.services
                    if (!servicesObj) {
                        console.error("Hydrus: unexpected services response, no 'services' key")
                        resolvedServiceKey = ""
                        return
                    }

                    function hexDecode(str) {
                        var result = ""
                        for (var i = 0; i < str.length; i += 2) {
                            result += String.fromCharCode(parseInt(str.substring(i, i+2), 16))
                        }
                        return result
                    }

                    var found = false

                    // Handle object with hex-encoded category keys
                    if (typeof servicesObj === "object" && !Array.isArray(servicesObj)) {
                        var keys = Object.keys(servicesObj)
                        for (var ki = 0; ki < keys.length; ki++) {
                            var catKey = keys[ki]
                            var catVal = servicesObj[catKey]

                            // Single service object
                            if (catVal && typeof catVal === "object" && !Array.isArray(catVal)) {
                                var svcName = catVal.name || hexDecode(catKey)
                                if (svcName === hydrusFileDomain) {
                                    resolvedServiceKey = catVal.service_key || catVal.key || catKey
                                    found = true
                                    break
                                }
                            }
                            // Array of service objects
                            else if (Array.isArray(catVal)) {
                                for (var idx = 0; idx < catVal.length; idx++) {
                                    var svc = catVal[idx]
                                    var svcName2 = svc.name || hexDecode(catKey)
                                    if (svcName2 === hydrusFileDomain) {
                                        resolvedServiceKey = svc.service_key || svc.key || catKey
                                        found = true
                                        break
                                    }
                                }
                                if (found) break
                            }
                        }
                    }
                    // Handle flat array
                    else if (Array.isArray(servicesObj)) {
                        for (var si = 0; si < servicesObj.length; si++) {
                            var s = servicesObj[si]
                            if (s.name === hydrusFileDomain) {
                                resolvedServiceKey = s.service_key || s.key
                                found = true
                                break
                            }
                        }
                    }

                    if (found) {
                        console.log("Hydrus: resolved service key for", hydrusFileDomain)
                    } else {
                        console.warn("Hydrus: service not found:", hydrusFileDomain + ".")
                        console.log("Hydrus: You can also use hex service key directly.")
                        resolvedServiceKey = ""
                    }
                } catch(e) {
                    console.error("Hydrus: error parsing services response:", e)
                    resolvedServiceKey = ""
                }
            } else {
                console.error("Hydrus: error fetching services:", svcXhr.status, svcXhr.responseText)
                resolvedServiceKey = ""
            }
        }

        svcXhr.onerror = function() {
            console.error("Hydrus: network error fetching services")
            resolvedServiceKey = ""
        }

        svcXhr.send()
    }

    // -----------------------------------------------------------------------
    // Resolve rating service key by name (async, calls callback with result)
    // -----------------------------------------------------------------------
    function getRatingServiceKeyAsync(callback) {
        var ratingServiceName = plasmoid.configuration.ratingServiceName;
        if (!ratingServiceName) {
            console.warn("Hydrus: Rating service name not configured.");
            callback("");
            return;
        }

        console.log("Hydrus: resolving rating service key for:", ratingServiceName);

        var svcXhr = new XMLHttpRequest();
        var svcUrl = hydrusApiUrl + "/get_services";
        svcXhr.open("GET", svcUrl);
        svcXhr.setRequestHeader("Hydrus-Client-API-Access-Key", hydrusAccessKey);

        svcXhr.onload = function() {
            if (svcXhr.status === 200) {
                try {
                    var svcResp = JSON.parse(svcXhr.responseText);
                    var servicesObj = svcResp.services;
                    if (!servicesObj) {
                        console.error("Hydrus: unexpected services response, no 'services' key");
                        callback("");
                        return;
                    }

                    function hexDecode(str) {
                        var result = "";
                        for (var i = 0; i < str.length; i += 2) {
                            result += String.fromCharCode(parseInt(str.substring(i, i+2), 16));
                        }
                        return result;
                    }

                    var found = false;
                    var foundServiceKey = "";

                    // Handle object with hex-encoded category keys
                    if (typeof servicesObj === "object" && !Array.isArray(servicesObj)) {
                        var keys = Object.keys(servicesObj);
                        for (var ki = 0; ki < keys.length; ki++) {
                            var catKey = keys[ki];
                            var catVal = servicesObj[catKey];

                            // Single service object
                            if (catVal && typeof catVal === "object" && !Array.isArray(catVal)) {
                                var svcName = catVal.name || hexDecode(catKey);
                                if (svcName === ratingServiceName) {
                                    foundServiceKey = catVal.service_key || catVal.key || catKey;
                                    found = true;
                                    break;
                                }
                            }
                            // Array of service objects
                            else if (Array.isArray(catVal)) {
                                for (var idx = 0; idx < catVal.length; idx++) {
                                    var svc = catVal[idx];
                                    var svcName2 = svc.name || hexDecode(catKey);
                                    if (svcName2 === ratingServiceName) {
                                        foundServiceKey = svc.service_key || svc.key || catKey;
                                        found = true;
                                        break;
                                    }
                                }
                                if (found) break;
                            }
                        }
                    }
                    // Handle flat array
                    else if (Array.isArray(servicesObj)) {
                        for (var si = 0; si < servicesObj.length; si++) {
                            var s = servicesObj[si];
                            if (s.name === ratingServiceName) {
                                foundServiceKey = s.service_key || s.key;
                                found = true;
                                break;
                            }
                        }
                    }

                    if (found) {
                        console.log("Hydrus: resolved rating service key for", ratingServiceName);
                        callback(foundServiceKey);
                    } else {
                        console.warn("Hydrus: rating service not found:", ratingServiceName + ".");
                        console.log("Hydrus: You can also use hex service key directly.");
                        callback("");
                    }
                } catch(e) {
                    console.error("Hydrus: error parsing services response for rating service:", e);
                    callback("");
                }
            } else {
                console.error("Hydrus: error fetching services for rating:", svcXhr.status, svcXhr.responseText);
                callback("");
            }
        }

        svcXhr.onerror = function() {
            console.error("Hydrus: network error fetching services for rating");
            callback("");
        }

        svcXhr.send();
    }

    // -----------------------------------------------------------------------
    // Set rating for the current image
    // -----------------------------------------------------------------------
    // For Like/Dislike services, convert 1 -> true (like), -1 -> false (dislike), 0 -> null (unset)
    function setRating(rating) {
        if (!hasItems || currentImageIndex < 0) {
            console.warn("Hydrus: No item to rate.");
            return;
        }

        var hash = fileHashes[currentImageIndex];
        var ratingServiceName = plasmoid.configuration.ratingServiceName;

        if (!ratingServiceName) {
            console.warn("Hydrus: Rating service name not configured. Cannot set rating.");
            return;
        }

        // Get the rating service key asynchronously
        getRatingServiceKeyAsync(function(serviceKey) {
            if (!serviceKey) {
                console.warn("Hydrus: Could not resolve service key for rating service '" + ratingServiceName + "'. Ensure the service name is correct in configuration.");
                return;
            }

            // Convert numeric rating to boolean for Like/Dislike services
            var apiRating;
            if (rating === 1) {
                apiRating = true;  // like
            } else if (rating === -1) {
                apiRating = false; // dislike
            } else {
                apiRating = null;  // unset
            }

            // Construct the URL according to the documentation: POST /edit_ratings/set_rating
            var url = hydrusApiUrl + "/edit_ratings/set_rating";

            console.log("Hydrus: Setting rating for hash", hash, "to", apiRating, "using service key", serviceKey);

            var xhr = new XMLHttpRequest();
            xhr.open("POST", url);
            xhr.setRequestHeader("Content-Type", "application/json");
            xhr.setRequestHeader("Hydrus-Client-API-Access-Key", hydrusAccessKey);

            // Send parameters as JSON body, using 'rating_service_key' as per documentation
            xhr.send(JSON.stringify({
                "hash": hash,
                "rating": apiRating,
                "rating_service_key": serviceKey
            }));

            xhr.onload = function() {
                if (xhr.status === 200) {
                    console.log("Hydrus: Rating set successfully.");
                } else {
                    console.error("Hydrus: Error setting rating:", xhr.status, xhr.responseText);
                }
            }

            xhr.onerror = function() {
                console.error("Hydrus: Network error setting rating.");
            }
        });
    }

    // -----------------------------------------------------------------------
    // Tag parsing with OR support (| within comma-separated groups)
    //   e.g. "cat|dog, blue" -> [["cat","dog"], "blue"]
    //   each top-level element is AND-ed, arrays are OR-ed
    // -----------------------------------------------------------------------
    // Tag parsing with OR support (| within comma-separated groups)
    //   e.g. "cat|dog, blue" -> [["cat","dog"], "blue"]
    //   each top-level element is AND-ed, arrays are OR-ed
    // -----------------------------------------------------------------------
    function parseTags(tagsString) {
        var tags = []
        var groups = tagsString.split(',')
        for (var i = 0; i < groups.length; i++) {
            var group = groups[i].trim()
            if (group === "") continue

            var orTags = group.split('|')
            if (orTags.length > 1) {
                var orGroup = []
                for (var j = 0; j < orTags.length; j++) {
                    var tag = orTags[j].trim()
                    if (tag !== "") {
                        orGroup.push(tag)
                    }
                }
                if (orGroup.length > 0) {
                    tags.push(orGroup)
                }
            } else {
                var tag = group.trim()
                if (tag !== "") {
                    tags.push([tag])
                }
            }
        }
        return tags
    }

    // -----------------------------------------------------------------------
    // Fetch images from Hydrus API
    // -----------------------------------------------------------------------
    function doSearch() {
        console.log("Hydrus: doSearch")

        var tags = parseTags(hydrusSearchTags)

        if (!hydrusApiUrl || !hydrusAccessKey || tags.length === 0) {
            loading = false
            hasFetched = true
            console.log("Hydrus: not configured, tags:", JSON.stringify(tags))
            return
        }

        loading = true
        activeSource = ""

        // Build proper JSON array for Hydrus API
        // The API expects a JSON array where OR groups are nested arrays:
        // e.g. ["skirt", ["space bounty hunter", "jane raider"], "system:height > 1000"]
        var tagsArray = [];
        for (var i = 0; i < tags.length; i++) {
            var group = tags[i];
            if (group.length === 1) {
                // Single tag (AND condition)
                tagsArray.push(group[0]);
            } else {
                // OR condition within the group — keep as nested array
                tagsArray.push(group);
            }
        }
        var tagsParam = JSON.stringify(tagsArray);

        var url = hydrusApiUrl + "/get_files/search_files?tags=" +
                  encodeURIComponent(tagsParam) +
                  "&return_hashes=true&return_file_ids=false";

        // If a specific domain is configured (not "all local files"), use the resolved key
        if (hydrusFileDomain && hydrusFileDomain !== "all local files" && resolvedServiceKey) {
            console.log("Hydrus: using service key:", resolvedServiceKey)
            url += "&file_service_key=" + encodeURIComponent(resolvedServiceKey)
        } else {
            console.log("Hydrus: using default file domain")
        }

        console.log("Hydrus: fetch URL:", url)
        console.log("Hydrus: access key length:", hydrusAccessKey ? hydrusAccessKey.length : 0)

        var xhr = new XMLHttpRequest()
        xhr.open("GET", url)
        xhr.setRequestHeader("Hydrus-Client-API-Access-Key", hydrusAccessKey)

        xhr.onload = function() {
            console.log("Hydrus: response status:", xhr.status)
            if (xhr.status === 200) {
                try {
                    var resp = JSON.parse(xhr.responseText)
                    fileHashes = resp.hashes || []
                    console.log("Hydrus: received", fileHashes.length, "image hashes")

                    if (fileHashes.length > 0) {
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

    // -----------------------------------------------------------------------
    // fetchImages: resolve service key (if needed), then search
    // -----------------------------------------------------------------------
    function fetchImages() {
        console.log("Hydrus: fetchImages")

        // Pre-resolve service key asynchronously, then do search
        // We delay search slightly to give the service key resolution time to complete
        resolveServiceKey()

        // Do the search after a short delay to let the async service lookup complete
        deferredSearch.restart()
    }

    // Timer to allow async service key resolution to complete before searching
    Timer {
        id: deferredSearch
        interval: 500
        repeat: false
        onTriggered: doSearch()
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
            console.log("File domain changed. Current domain:", plasmoid.configuration.fileDomain)
            // This is for image sources, not ratings. We don't reset resolvedServiceKey here.
            // fetchImages() // No need to re-fetch images just because file domain changed if it's not related to ratings
        }

        function onRatingServiceNameChanged() {
            console.log("Rating service name changed. Current rating service:", plasmoid.configuration.ratingServiceName)
            // Rating service key is now resolved on-demand by getRatingServiceKeyAsync,
            // so we don't need to resolve anything here.
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

            // Like button
            PlasmaComponents3.Button {
                icon.name: "emblem-favorite" // Or a custom like icon if available
                onClicked: {
                    main.setRating(1); // 1 for like
                }
            }

            // Dislike button
            PlasmaComponents3.Button {
                icon.name: "dialog-cancel" // Иконка для dislike (отрицательное действие)
                onClicked: {
                    main.setRating(-1); // -1 for dislike
                }
            }

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