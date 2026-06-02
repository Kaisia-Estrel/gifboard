pragma ComponentBehavior: Bound

import QtQuick 2.12
import QtQuick.Layouts
import com.estrel.gifboard
import QtQuick.Controls

Item {
    id: gifBrowser
    required property TextField searchInput
    required property ClipboardManager clipboardManager

    property int columnCount: 3
    property double columnWidth: 70
    property var columnModels: []
    property var selectedIndices: new Set()

    signal query(string query)

    Layout.fillWidth: true
    Layout.fillHeight: true

    RowLayout {
        id: gifColumns //Yeah
        spacing: 10
        anchors.fill: parent

        Repeater {
            id: gifColumnRepeater
            model: gifBrowser.columnCount

            delegate: ListView {
                id: column
                required property int index
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                spacing: 10
                interactive: false

                onContentHeightChanged: gifFlickable.updateMaxHeight()

                model: gifBrowser.columnModels[index]

                delegate: PreviewImage {
                    gifFlickable: gifFlickable

                    width: column.width

                    Layout.fillWidth: true

                    onImageCopied: imageOutputUri => {
                        gifBrowser.clipboardManager.copyAsTemp(imageOutputUri);
                    }

                    onSelect: {
                        gifBrowser.selectedIndices.add(index);
                    }

                    onUnselect: {
                        gifBrowser.selectedIndices.delete(index);
                    }
                }
            }
        }
    }

    Flickable {
        id: gifFlickable
        anchors.fill: parent
        contentWidth: gifBrowser.width
        clip: true

        Timer {
            id: gifFlickableThrottler
            triggeredOnStart: true
            repeat: false
            interval: 1500
            onTriggered: {
                gifBrowser.query(gifBrowser.searchInput.text);
            }
        }

        onContentYChanged: {
            for (let i = 0; i < gifBrowser.columnCount; i++) {
                let columnListView = gifColumnRepeater.itemAt(i);
                if (columnListView) {
                    columnListView.contentY = contentY;
                }
            }
            if (contentHeight - contentY < (height * 4) && !gifFlickableThrottler.running) {
                gifFlickableThrottler.start();
            }
        }

        function updateMaxHeight() {
            let minVal = Infinity;
            for (let i = 0; i < gifBrowser.columnCount; i++) {
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
            for (let i = 0; i < gifBrowser.columnCount; i++) {
                temp.push(Qt.createQmlObject("import QtQuick; ListModel {}", gifFlickable));
                heights.push(0);
            }
            gifBrowser.columnModels = temp;
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
