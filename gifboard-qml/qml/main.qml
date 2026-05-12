import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Window 2.12

import org.kde.layershell 1.0 as LayerShell

import com.estrel.gifboard 1.0

ApplicationWindow {
    id: root
    title: qsTr("Gifboard")
    visible: true
    // visibility: Window.AutomaticVisibility
    color: palette.window

    height: 180
    width: 540
    LayerShell.Window.layer: LayerShell.Window.LayerOverlay
    LayerShell.Window.anchors: LayerShell.Window.AnchorNone
    LayerShell.Window.exclusionZone: 0

    Component.onCompleted: {}

    readonly property MyObject myObject: MyObject {
        number: 1
        string: qsTr("My String with my number: %1").arg(number)
    }

    Column {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10

        Label {
            text: qsTr("Number: %1").arg(root.myObject.number)
            color: palette.text
        }

        Label {
            text: qsTr("String: %1").arg(root.myObject.string)
            color: palette.text
        }

        Button {
            text: qsTr("Increment Number")

            onClicked: root.myObject.incrementNumber()
        }

        Button {
            text: qsTr("Say Hi!")

            onClicked: root.myObject.sayHi(root.myObject.string, root.myObject.number)
        }

        Button {
            text: qsTr("Quit")

            onClicked: Qt.quit()
        }
    }
}
