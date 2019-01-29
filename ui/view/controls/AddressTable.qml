import QtQuick 2.11
import QtQuick.Controls 1.4
import QtQuick.Controls 2.3
import "."

CustomTableView {
    id: rootControl

    property int rowHeight: 69
    property int resizableWidth: parent.width - actions.width
    property var parentModel
    property bool isExpired: false
    property var editDialog
    anchors.fill: parent
    frameVisible: false
    selectionMode: SelectionMode.NoSelection
    backgroundVisible: false    

    TableViewColumn {
        role: parentModel.nameRole
        title: qsTr("Comment")
        width: 150 * rootControl.resizableWidth / 750
        resizable: false
        movable: false
    }

    TableViewColumn {
        role: parentModel.addressRole
        title: qsTr("Address")
        width: 150 *  rootControl.resizableWidth / 750
        movable: false
        resizable: false
        delegate: Item {
            Item {
                width: parent.width
                height: rootControl.rowHeight
                clip:true

                SFLabel {
                    font.pixelSize: 14
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 20
                    elide: Text.ElideMiddle
                    anchors.verticalCenter: parent.verticalCenter
                    text: styleData.value
                    color: Style.white
                    copyMenuEnabled: true
                    onCopyText: parentModel.copyToClipboard(text)
                }
            }
        }
    }

    TableViewColumn {
        role: parentModel.categoryRole
        title: qsTr("Category")
        width: 150 *  rootControl.resizableWidth / 750
        resizable: false
        movable: false
    }

    TableViewColumn {
        role: parentModel.expirationRole
        title: qsTr("Expiration date")
        width: 150 *  rootControl.resizableWidth / 750
        resizable: false
        movable: false
    }

    TableViewColumn {
        role:parentModel.createdRole
        title: qsTr("Created")
        width: 150 *  rootControl.resizableWidth / 750
        resizable: false
        movable: false
    }

    TableViewColumn {
        id: actions
        title: ""
        width: 40
        movable: false
        resizable: false
        delegate: txActions
    }

    rowDelegate: Item {

        height: rootControl.rowHeight

        anchors.left: parent.left
        anchors.right: parent.right

        Rectangle {
            anchors.fill: parent

            color: styleData.selected ? Style.bright_sky_blue : Style.light_navy
            visible: styleData.selected ? true : styleData.alternate
        }
    }

    itemDelegate: TableItem {
        text: styleData.value
        elide: styleData.elideMode
    }

    Component {
        id: txActions
        Item {
            Item {
                width: parent.width
                height: rootControl.rowHeight

                Row{
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10
                    CustomToolButton {
                        icon.source: "qrc:/assets/icon-actions.svg"
                        ToolTip.text: qsTr("Actions")
                        onClicked: {
                            contextMenu.address = rootControl.model[styleData.row].address;
                            contextMenu.addressItem = rootControl.model[styleData.row];
                            contextMenu.popup();
                        }
                    }
                }
            }
        }
    }

    ContextMenu {
        id: contextMenu
        modal: true
        dim: false
        property string address
        property var addressItem
        Action {
            text: qsTr("edit address")
            icon.source: "qrc:/assets/icon-edit.svg"
            onTriggered: {
                editDialog.addressItem = contextMenu.addressItem;
                editDialog.open();
            }
        }
        Action {
            text: qsTr("delete address")
            icon.source: "qrc:/assets/icon-delete.svg"
            onTriggered: {
                viewModel.deleteAddress(contextMenu.address);
            }
        }
    }
}