pragma ComponentBehavior: Bound
import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Window 2.12
import QtQuick.Layouts

import org.kde.layershell 1.0 as LayerShell

import com.estrel.gifboard 1.0

ApplicationWindow {
    id: root
    title: qsTr("Gifboard")
    visible: true
    color: "transparent"

    flags: Qt.FramelessWindowHint | Qt.Window | Qt.Tool | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.X11BypassWindowManagerHint

    onVisibleChanged: {
        if (visible) {
            x = (Screen.width - width) / 2;
            y = (Screen.height - height) / 2;
            requestActivate();
        }
    }

    property bool onWayland: Qt.platform.pluginName === "wayland"

    Component.onCompleted: {
        if (onWayland) {
            close();
            LayerShell.Window.layer = LayerShell.Window.LayerOverlay;
            LayerShell.Window.anchors = (LayerShell.Window.AnchorTop | LayerShell.Window.AnchorLeft | LayerShell.Window.AnchorRight | LayerShell.Window.AnchorBottom);
            LayerShell.Window.keyboardInteractivity = LayerShell.Window.KeyboardInteractivityExclusive;
            show();
        } else {
            x11Manager.grabInput();
        }
        searchInput.forceActiveFocus();
    }

    Dialog {
        id: errorDialog

        anchors.centerIn: parent
        y: 80
        property string message
        title: "Query Error"

        standardButtons: Dialog.Ok

        contentItem: Text {
            id: messageText
            text: errorDialog.message
        }

        padding: 10

        implicitWidth: messageText.implicitWidth + leftPadding + rightPadding
        implicitHeight: messageText.implicitHeight + topPadding + bottomPadding + header.implicitHeight + footer.implicitHeight
    }

    width: Screen.width - (Screen.width / 4)
    height: Screen.height - (Screen.height / 4)
    // ColumnLayout width extend beyong the width defined in root in some window managers for some reason.
    ColumnLayout {
        width: Screen.width - (Screen.width / 4)
        height: Screen.height - (Screen.height / 4)
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10

        Keys.onEscapePressed: {
            Qt.quit();
        }

        TextField {
            id: searchInput
            Layout.fillWidth: true
            focus: true

            property string lastQuery: ""

            Timer {
                id: inputDebounce
                interval: 500
                repeat: false
                onTriggered: {
                    if (searchInput.text.length > 0 && searchInput.lastQuery != searchInput.text) {
                        root.searchResults.query(searchInput.text, true);
                        searchInput.lastQuery = searchInput.text;
                        root.searchResults.clearResults();
                    }
                }
            }

            onTextEdited: inputDebounce.restart()

            onEditingFinished: {
                if (text.length > 0 && text !== lastQuery) {
                    inputDebounce.stop();
                    root.searchResults.query(searchInput.text, true);
                    root.searchResults.clearResults();
                }
            }
        }

        Item {
            id: gifBrowser
            property var selectedIndices: new Set()

            Layout.fillWidth: true
            Layout.fillHeight: true

            RowLayout {
                id: gifColumns //Yeah
                spacing: 10
                anchors.fill: parent

                Repeater {
                    id: gifColumnRepeater
                    model: gifPreviews.columnCount

                    delegate: ListView {
                        id: column
                        required property int index

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true

                        spacing: 10
                        interactive: false

                        onContentHeightChanged: gifPreviews.updateMaxHeight()

                        model: gifPreviews.columnModels[index]

                        delegate: Item {
                            id: previewImageRoot
                            required property string imagePreviewUri
                            required property string imageHoverUri
                            required property string imageOutputUri
                            required property string blurPreview
                            required property int imageHeight
                            required property int index
                            width: column.width
                            height: imageHeight
                            property bool hovered: false
                            property bool hasHoverImage: imageHoverUri !== ""

                            // Timer so that hoverimages don't all load when flicking through the browser
                            Timer {
                                id: hoverTimer
                                interval: 300
                                repeat: false
                                onTriggered: {
                                    hoverLoader.item.previouslyHovered = true;
                                }
                            }

                            Rectangle {
                                id: previewImageContainer
                                anchors.fill: parent
                                color: "#505F71"
                                border.width: 2
                                border.color: gifBrowser.selectedIndices.has(previewImageRoot.index) ? "red" : "blue"

                                Image {
                                    id: blurPreviewImage
                                    anchors.fill: parent
                                    anchors.margins: previewImageContainer.border.width
                                    fillMode: Image.PreserveAspectFit
                                    visible: previewImage.status != Image.Ready
                                    source: previewImageRoot.blurPreview
                                }

                                AnimatedImage {
                                    id: previewImage
                                    anchors.fill: parent
                                    anchors.margins: previewImageContainer.border.width
                                    fillMode: Image.PreserveAspectFit

                                    property bool loadedPreview: false
                                    asynchronous: true

                                    source: previewImageRoot.imagePreviewUri
                                    playing: true
                                }

                                Loader {
                                    id: hoverLoader
                                    anchors.fill: parent
                                    anchors.margins: previewImageContainer.border.width
                                    active: previewImageRoot.hasHoverImage
                                    sourceComponent: AnimatedImage {
                                        id: hoverImage

                                        anchors.fill: parent
                                        fillMode: Image.PreserveAspectFit

                                        playing: previewImageRoot.hovered

                                        property bool previouslyHovered: false
                                        visible: previewImageRoot.hovered
                                        source: previouslyHovered ? previewImageRoot.imageHoverUri : ""

                                        Rectangle {
                                            id: loadingBar
                                            anchors.left: parent.left
                                            anchors.margins: 10
                                            implicitHeight: 10
                                            color: "blue"

                                            anchors.top: parent.top

                                            state: gifPreviews.contentY >= previewImageRoot.y ? "bottom" : "top"

                                            states: [
                                                State {
                                                    name: "top"
                                                    AnchorChanges {
                                                        target: loadingBar
                                                        anchors.top: parent.top
                                                        anchors.bottom: undefined
                                                    }
                                                },
                                                State {
                                                    name: "bottom"
                                                    AnchorChanges {
                                                        target: loadingBar
                                                        anchors.top: undefined
                                                        anchors.bottom: parent.bottom
                                                    }
                                                }
                                            ]
                                            visible: hoverImage.status != AnimatedImage.Ready

                                            Behavior on width {
                                                NumberAnimation {
                                                    duration: 200
                                                }
                                            }
                                        }
                                        onProgressChanged: {
                                            loadingBar.width = hoverImage.progress * (parent.width - loadingBar.anchors.margins * 2);
                                        }
                                    }
                                }
                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: previewImageContainer.border.width
                                    color: "black"
                                    opacity: previewImageRoot.hovered ? 0 : 0.2

                                    Behavior on opacity {
                                        NumberAnimation {
                                            duration: 150
                                        }
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: previewImageRoot.hasHoverImage
                                propagateComposedEvents: true
                                onEntered: {
                                    previewImageRoot.hovered = true;
                                    hoverLoader.item.currentFrame = previewImage.currentFrame;
                                    hoverTimer.start();
                                }
                                onExited: {
                                    previewImageRoot.hovered = false;
                                    hoverTimer.stop();
                                }
                                onClicked: mouse => {
                                    if (mouse.modifiers & Qt.ShiftModifier) {
                                        if (gifBrowser.selectedIndices.has(previewImageRoot.index)) {
                                            gifBrowser.selectedIndices.delete(previewImageRoot.index);
                                        } else {
                                            gifBrowser.selectedIndices.add(previewImageRoot.index);
                                        }
                                        gifBrowser.selectedIndicesChanged();
                                        mouse.accepted = true;
                                    } else {
                                        root.clipboardManager.copyAsTemp(previewImageRoot.imageOutputUri);
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Flickable {
                id: gifPreviews
                anchors.fill: parent
                contentWidth: searchInput.width
                clip: true

                Timer {
                    id: gifPreviewsThrottler
                    triggeredOnStart: true
                    repeat: false
                    interval: 1500
                    onTriggered: {
                        root.searchResults.query(searchInput.text, false);
                    }
                }

                onContentYChanged: {
                    for (let i = 0; i < columnCount; i++) {
                        let columnListView = gifColumnRepeater.itemAt(i);
                        if (columnListView) {
                            columnListView.contentY = contentY;
                        }
                    }
                    if (contentHeight - contentY < (height * 4) && !gifPreviewsThrottler.running) {
                        gifPreviewsThrottler.start();
                    }
                }

                property int columnCount: 3
                property var columnModels: []

                function updateMaxHeight() {
                    let minVal = Infinity;
                    for (let i = 0; i < columnCount; i++) {
                        let columnListView = gifColumnRepeater.itemAt(i);
                        if (columnListView) {
                            minVal = Math.min(minVal, columnListView.contentHeight);
                        }
                    }
                    contentHeight = minVal;
                }

                Component.onCompleted: {
                    let temp = [];
                    let heights = [];
                    for (let i = 0; i < gifPreviews.columnCount; i++) {
                        temp.push(Qt.createQmlObject("import QtQuick; ListModel {}", gifPreviews));
                        heights.push(0);
                    }
                    columnModels = temp;
                }

                MouseArea {
                    anchors.fill: parent
                    propagateComposedEvents: true
                    onClicked: mouse => {
                        mouse.accepted = false;
                    }
                }
            }
        }
    }

    property ClipboardManager clipboardManager: ClipboardManager {
        onFileCopied: {
            root.visible = false;
            if (root.x11Manager.onX11()) {
                root.x11Manager.ungrabInput();
            }
        }

        onClipboardChanged: {
            Qt.quit();
        }
    }

    property X11Manager x11Manager: X11Manager {}
    property SearchResults searchResults: SearchResults {
        onQueryError: err => {
            errorDialog.message = err;
            errorDialog.open();
        }

        property var columnHeights: []
        property int currentIndex: 0

        function resetHeights() {
            let temp = [];
            for (let i = 0; i < gifPreviews.columnCount; i++) {
                temp.push(0);
            }
            columnHeights = temp;
        }

        onReceivedResult: (output_uri, hover_uri, preview_uri, blur_preview, width, height) => {
            if (gifPreviews.columnModels.length === 0) {
                return;
            }

            if (columnHeights.length !== gifPreviews.columnCount) {
                resetHeights();
            }

            let shortestColumn = 0;
            let minHeight = Infinity;
            let maxHeight = 0;
            let colWidth = gifColumnRepeater.itemAt(0).width;

            for (let i = 0; i < gifPreviews.columnCount; i++) {
                let colHeight = columnHeights[i];
                if (colHeight < minHeight) {
                    minHeight = colHeight;
                    shortestColumn = i;
                }
            }

            gifPreviews.columnModels[shortestColumn].append({
                imageOutputUri: output_uri,
                imageHoverUri: hover_uri,
                imagePreviewUri: preview_uri,
                blurPreview: blur_preview,
                imageHeight: height / (width / colWidth),
                index: currentIndex
            });
            columnHeights[shortestColumn] += height;
            currentIndex++;
        }

        property var clearResults: () => {
            currentIndex = 0;
            resetHeights();
            for (let i = 0; i < gifPreviews.columnCount; i++) {
                gifPreviews.columnModels[i].clear();
            }
        }
    }
}
