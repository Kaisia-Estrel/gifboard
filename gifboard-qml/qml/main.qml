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

        GifBrowser {
            id: gifBrowser
            searchInput: searchInput
            clipboardManager: root.clipboardManager

            onQuery: query => {
                root.searchResults.query(query, false);
            }
        }
    }

    property ClipboardManager clipboardManager: ClipboardManager {

        property var notif: Notification {
            summary: "Attachment Copied"
            body: "You can paste the image from the clipboard."
        }

        onUrlsCopied: urls => {
            notif.show();
            root.visible = false;
            if (root.x11Manager.onX11()) {
                root.x11Manager.ungrabInput();
            }
        }

        // event only actives if gifboard has already copied
        // gifboard stays open in the background until a new selection is made
        onReleasedOwnership: {
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
            for (let i = 0; i < gifBrowser.columnCount; i++) {
                temp.push(0);
            }
            columnHeights = temp;
        }

        onReceivedResult: (output_uri, hover_uri, preview_uri, blur_preview, width, height) => {
            if (gifBrowser.columnModels.length === 0) {
                return;
            }

            if (columnHeights.length !== gifBrowser.columnCount) {
                resetHeights();
            }

            let shortestColumn = 0;
            let minHeight = Infinity;
            let maxHeight = 0;

            for (let i = 0; i < gifBrowser.columnCount; i++) {
                let colHeight = columnHeights[i];
                if (colHeight < minHeight) {
                    minHeight = colHeight;
                    shortestColumn = i;
                }
            }

            gifBrowser.columnModels[shortestColumn].append({
                imageOutputUri: new URL(output_uri),
                imageHoverUri: new URL(hover_uri),
                imagePreviewUri: new URL(preview_uri),
                blurPreview: blur_preview,
                imageHeight: height,
                imageWidth: width,
                index: currentIndex
            });
            columnHeights[shortestColumn] += height;
            currentIndex++;
        }

        property var clearResults: () => {
            currentIndex = 0;
            resetHeights();
            for (let i = 0; i < gifBrowser.columnCount; i++) {
                gifBrowser.columnModels[i].clear();
            }
        }
    }
}
