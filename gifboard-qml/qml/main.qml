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

    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.Window

    Shortcut {
        sequence: "Escape"
        onActivated: Qt.quit()
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

    readonly property SearchResults searchResults: SearchResults {
        onQueryError: err => {
            errorDialog.message = err;
            errorDialog.open();
        }

        property var columnHeights: []
        onReceivedResults: (uri, width, height) => {
            if (gifPreviews.columnModels.length === 0)
                return;

            let shortestColumn = 0;
            let minHeight = Infinity;
            let maxHeight = 0;
            let colWidth = gifColumnRepeater.itemAt(0).width;

            for (let i = 0; i < gifPreviews.columnCount; i++) {
                let colView = gifColumnRepeater.itemAt(i);
                let curHeight = colView ? colView.contentHeight : 0;
                if (curHeight < minHeight) {
                    minHeight = curHeight;
                    shortestColumn = i;
                }
                maxHeight = Math.max(maxHeight, curHeight);
                console.log("-----");
                console.log(i);
                console.log(curHeight);
                console.log(shortestColumn);
            }
            gifPreviews.columnModels[shortestColumn].append({
                imageUri: uri,
                imageHeight: height / (width / colWidth)
            });

            gifPreviews.contentHeight = maxHeight;
        }
    }

    onActiveChanged: {
        if (active) {
            searchInput.forceActiveFocus();
        }
    }

    LayerShell.Window.layer: LayerShell.Window.LayerOverlay
    LayerShell.Window.anchors: LayerShell.Window.AnchorTop | LayerShell.Window.AnchorLeft | LayerShell.Window.AnchorRight | LayerShell.Window.AnchorBottom
    LayerShell.Window.exclusionZone: 0

    Column {
        anchors.centerIn: parent

        TextField {
            id: searchInput
            width: font.pixelSize * 50
            onTextEdited: root.searchResults.query(searchInput.text)
        }

        Item {
            width: searchInput.width
            height: 800

            RowLayout {
                id: gifColumns //Yeah
                width: searchInput.width
                height: gifPreviews.height
                spacing: 10

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

                        contentY: gifPreviews.scrollPosition
                        onContentHeightChanged: gifPreviews.updateMaxHeight()

                        model: gifPreviews.columnModels[index]

                        delegate: AnimatedImage {
                            required property string imageUri
                            required property int imageHeight
                            width: column.width
                            height: imageHeight

                            source: imageUri

                            Component.onCompleted: console.log("Instantiated delegate " + model.index)
                            Component.onDestruction: console.log("Culled delegate " + model.index)
                        }
                    }
                }
            }

            Flickable {
                id: gifPreviews
                width: searchInput.width
                height: 800
                contentWidth: searchInput.width
                clip: true

                property real scrollPosition: 0
                onContentYChanged: scrollPosition = contentY

                property int columnCount: 3
                property var columnModels: []

                function updateMaxHeight() {
                    let maxVal = 0;
                    // Check the real contentHeight of each spawned ListView
                    for (let i = 0; i < columnCount; i++) {
                        let columnListView = gifColumnRepeater.itemAt(i);
                        if (columnListView) {
                            maxVal = Math.max(maxVal, columnListView.contentHeight);
                        }
                    }
                    contentHeight = maxVal;
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
}
