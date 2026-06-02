pragma ComponentBehavior: Bound
import QtQuick 2.12

Item {
    id: previewImageRoot

    signal imageCopied(string outputUrl)
    signal select
    signal unselect

    required property Flickable gifFlickable

    required property string imagePreviewUri
    required property string imageHoverUri
    required property string imageOutputUri
    required property string blurPreview
    required property int imageHeight
    required property int imageWidth
    required property int index

    height: imageHeight / (imageWidth / width)

    property bool hovered: false
    property bool selected: false
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
        border.color: previewImageRoot.selected ? "red" : "blue"

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

                    state: previewImageRoot.gifFlickable.contentY >= previewImageRoot.y ? "bottom" : "top"

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
                    visible: hoverImage.status != Image.Ready
                    // Also doesnt make it show if the hoverimage loaded fast enough
                    Behavior on width {
                        NumberAnimation {
                            duration: 50
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
            opacity: (previewImageRoot.selected || previewImageRoot.hovered) ? 0 : 0.2

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
                if (previewImageRoot.selected) {
                    previewImageRoot.selected = false;
                    previewImageRoot.unselect();
                } else {
                    previewImageRoot.selected = true;
                    previewImageRoot.select();
                }
                mouse.accepted = true;
            } else {
                previewImageRoot.imageCopied(previewImageRoot.imageOutputUri);
            }
        }
    }
}
