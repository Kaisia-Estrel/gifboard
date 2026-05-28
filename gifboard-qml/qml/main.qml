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
            searchInput.forceActiveFocus();
        }
    }

    onActiveFocusItemChanged: {
        if (activeFocusItem !== searchInput) {
            searchInput.forceActiveFocus();
        }
    }

    property bool onWayland: Qt.platform.pluginName === "wayland"

    Component.onCompleted: {
        if (onWayland) {
            close();
            LayerShell.Window.layer = LayerShell.Window.LayerOverlay;
            LayerShell.Window.anchors = (LayerShell.Window.AnchorTop | LayerShell.Window.AnchorLeft | LayerShell.Window.AnchorRight | LayerShell.Window.AnchorBottom);
            LayerShell.Window.exclusionZone = 0;
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
                            required property int imageHeight
                            width: column.width
                            height: imageHeight
                            property bool hovered: false
                            property bool hasHoverImage: imageHoverUri !== ""

                            Rectangle {
                                anchors.fill: parent
                                color: "#505F71"
                            }

                            AnimatedImage {
                                id: previewImage

                                anchors.fill: parent
                                fillMode: Image.PreserveAspectFit

                                source: previewImageRoot.imagePreviewUri
                                playing: true

                                opacity: (hoverLoader.item.status != AnimatedImage.Ready || !previewImageRoot.hasHoverImage || !previewImageRoot.hovered) ? 1 : 0

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: 240
                                    }
                                }
                            }

                            Loader {
                                id: hoverLoader
                                anchors.fill: parent
                                active: previewImageRoot.hasHoverImage
                                sourceComponent: AnimatedImage {
                                    id: hoverImage

                                    anchors.fill: parent
                                    fillMode: Image.PreserveAspectFit

                                    playing: previewImageRoot.hovered

                                    property bool previouslyHovered: false

                                    source: previouslyHovered ? previewImageRoot.imageHoverUri : ""

                                    opacity: previewImageRoot.hovered ? 1 : 0

                                    Behavior on opacity {
                                        NumberAnimation {
                                            duration: 240
                                        }
                                    }
                                }
                            }

                            // Timer so that hoverimages don't all loud when flicking through the browser
                            Timer {
                                id: hoverTimer
                                interval: 300
                                repeat: false
                                onTriggered: {
                                    hoverLoader.item.previouslyHovered = true;
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: previewImageRoot.hasHoverImage
                                onEntered: {
                                    previewImageRoot.hovered = true;
                                    hoverLoader.item.currentFrame = previewImage.currentFrame;
                                    hoverTimer.start();
                                }
                                onExited: {
                                    previewImageRoot.hovered = false;
                                    hoverTimer.stop();
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
                        console.log("Throttled");
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
            }
        }
    }

    property X11Manager x11Manager: X11Manager {}
    property SearchResults searchResults: SearchResults {
        onQueryError: err => {
            errorDialog.message = err;
            errorDialog.open();
        }

        property var columnHeights: []

        function resetHeights() {
            let temp = [];
            for (let i = 0; i < gifPreviews.columnCount; i++) {
                temp.push(0);
            }
            columnHeights = temp;
        }

        onReceivedResult: (output_uri, hover_uri, preview_uri, width, height) => {
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
                imageHeight: height / (width / colWidth)
            });
            columnHeights[shortestColumn] += height;
        }

        property var clearResults: () => {
            resetHeights();
            for (let i = 0; i < gifPreviews.columnCount; i++) {
                gifPreviews.columnModels[i].clear();
            }
        }
    }
}
