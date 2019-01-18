import QtQuick 2.11
import QtQuick.Controls 1.2
import QtQuick.Controls 2.4
import QtQuick.Controls.Styles 1.2
import QtGraphicalEffects 1.0
import QtQuick.Layouts 1.3
import Beam.Wallet 1.0
import "controls"

Item {
    id: root
    anchors.fill: parent

    WalletViewModel {
        id: viewModel
        onSendMoneyVerified: {
            walletView.enabled = true
            console.log("onSendMoneyVerified");
            walletView.pop();
        }

        onCantSendToExpired: {
            walletView.enabled = true
            console.log("can't send to expired address");
            cantSendToExpiredDialog.open();
        }
    }

    property bool toSend: false

    Dialog {
        id: cantSendToExpiredDialog

        modal: true

        width: 300
        height: 160

        x: (parent.width - width) / 2
        y: (parent.height - height) / 2
        visible: false
        
        background: Rectangle {
            radius: 10
            color: Style.dark_slate_blue
            anchors.fill: parent
        }

        contentItem: Column {
            anchors.fill: parent
            anchors.margins: 30

            spacing: 40

            SFText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("Can't send to the expired address.")
                color: Style.white
                font.pixelSize: 14
                font.styleName: "Bold"; font.weight: Font.Bold
            }

            PrimaryButton {
                text: qsTr("ok")
                anchors.horizontalCenter: parent.horizontalCenter
                icon.source: "qrc:/assets/icon-done.svg"
                onClicked: cantSendToExpiredDialog.close()
            }
        }
    }

    ConfirmationDialog {
        id: confirmationDialog
        okButtonColor: Style.heliotrope
        okButtonText: qsTr("send")
        okButtonIconSource: "qrc:/assets/icon-send-blue.svg"
        cancelButtonIconSource: "qrc:/assets/icon-cancel-white.svg"

        property alias addressText: addressLabel.text
        property alias amountText: amountLabel.text
        property alias feeText: feeLabel.text

        contentItem: Item {
            id: sendConfirmationContent
            ColumnLayout {
                anchors.fill: parent
                spacing: 30

                SFText {
                    id: title
                    Layout.alignment: Qt.AlignHCenter
                    Layout.minimumHeight: 21
                    Layout.leftMargin: 68
                    Layout.rightMargin: 68
                    Layout.topMargin: 14
                    font.pixelSize: 18
                    font.styleName: "Bold";
                    font.weight: Font.Bold
                    color: Style.white
                    text: qsTr("Please review the transaction details")
                }

                GridLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.leftMargin: 18
                    Layout.rightMargin: 18
                    columnSpacing: 14
                    rowSpacing: 12
                    columns: 2
                    rows: 3

                    SFText {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumHeight: 16
                        font.pixelSize: 14
                        color: Style.disable_text_color
                        text: qsTr("Recipient:")
                        verticalAlignment: Text.AlignTop
                    }

                    SFText {
                        id: addressLabel
                        Layout.fillWidth: true
                        Layout.maximumWidth: 290
                        Layout.minimumHeight: 16
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        font.pixelSize: 14
                        color: Style.white
                    }

                    SFText {
                        Layout.row: 2
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumHeight: 16
                        Layout.bottomMargin: 3
                        font.pixelSize: 14
                        color: Style.disable_text_color
                        text: qsTr("Amount:")
                        verticalAlignment: Text.AlignBottom
                    }

                    SFText {
                        id: amountLabel
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumHeight: 29
                        font.pixelSize: 24
                        color: Style.heliotrope
                        verticalAlignment: Text.AlignBottom
                    }

                    SFText {
                        Layout.row: 3
                        Layout.fillWidth: true
                        Layout.minimumHeight: 16
                        font.pixelSize: 14
                        color: Style.disable_text_color
                        text: qsTr("Transaction fee:")
                    }

                    SFText {
                        id: feeLabel
                        Layout.fillWidth: true
                        Layout.minimumHeight: 16
                        font.pixelSize: 14
                        color: Style.white
                    }
                }
            }
        }

        onAccepted: {
            viewModel.sendMoney();
            walletView.enabled = false;
        }
    }

    ConfirmationDialog {
        id: invalidAddressDialog
        okButtonText: qsTr("got it")
    }

    ConfirmationDialog {
        id: deleteTransactionDialog
        okButtonText: qsTr("delete")
    }

    SFText {
        font.pixelSize: 36
        color: Style.white
        text: qsTr("Wallet")
    }

    StatusBar {
        id: status_bar
        model: statusbarModel
    }

    /////////////////////////////////////////////////////////////
    /// Receive layout //////////////////////////////////////////
    /////////////////////////////////////////////////////////////

    Component {
        id: receive_layout
        Item {
            
            property Item defaultFocusItem: myAddressName

            ColumnLayout {
                anchors.fill: parent
                anchors.topMargin: 73
                anchors.bottomMargin: 30
                spacing: 30

                SFText {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.minimumHeight: 21
                    font.pixelSize: 18
                    font.styleName: "Bold"; font.weight: Font.Bold
                    color: Style.white
                    text: qsTr("Receive Beam")
                }

                RowLayout {
                    Layout.fillWidth: true

                    Item {
                        Layout.fillWidth: true
                        // TODO: find better solution, because it's bad
                        Layout.minimumHeight: 220
                        Column {
                            anchors.fill: parent
                            spacing: 10

                            SFText {
                                font.pixelSize: 14
                                font.styleName: "Bold"; font.weight: Font.Bold
                                color: Style.white
                                text: qsTr("My address")
                            }

                            SFTextInput {
                                id: myAddressID
                                width: parent.width
                                font.pixelSize: 14
                                color: Style.disable_text_color
                                readOnly: true
                                activeFocusOnTab: false
                                text: viewModel.newReceiverAddr
                            }

                            Row {
                                spacing: 10
                                SFText {
                                    font.pixelSize: 14
                                    font.italic: true
                                    color: Style.white
                                    text: qsTr("Expires:")
                                }
                                CustomComboBox {
                                    id: expiresControl
                                    width: 100
                                    height: 20
                                    anchors.top: parent.top
                                    anchors.topMargin: -3

                                    currentIndex: viewModel.expires

                                    Binding {
                                        target: viewModel
                                        property: "expires"
                                        value: expiresControl.currentIndex
                                    }

                                    model: ["24 hours", "never"]
                                }
                            }

                            SFText {
                                font.pixelSize: 14
                                font.styleName: "Bold"; font.weight: Font.Bold
                                color: Style.white
                                text: qsTr("Comment")
                            }

                            SFTextInput {
                                id: myAddressName
                                font.pixelSize: 14
                                width: parent.width
                                color: Style.white
                                focus: true
                                text: viewModel.newReceiverName
                            }

                            Binding {
                                target: viewModel
                                property: "newReceiverName"
                                value: myAddressName.text
                            }
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        // TODO: find better solution, because it's bad
                        Layout.minimumHeight: 220
                        Column {
                            anchors.fill: parent
                            Image {
                                anchors.horizontalCenter: parent.horizontalCenter
                                fillMode: Image.Pad
                        
                                source: viewModel.newReceiverAddrQR
                            }
                            SFText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                font.pixelSize: 14
                                font.italic: true
                                color: Style.white
                                text: qsTr("Scan to send")
                            }
                        }
                    }
                }

                SFText {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.minimumHeight: 16
                    font.pixelSize: 14
                    color: Style.white
                    text: qsTr("Send this address to the sender over an external secure channel")
                }
                Row {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.minimumHeight: 40

                    spacing: 19

                    CustomButton {
                        text: qsTr("close")
                        palette.buttonText: Style.white
                        icon.source: "qrc:/assets/icon-cancel-white.svg"
                        onClicked: {
                            walletView.pop();
                        }
                    }

                    CustomButton {
                        text: qsTr("copy")
                        palette.buttonText: Style.marine
                        icon.color: Style.marine
                        palette.button: Style.bright_teal
                        icon.source: "qrc:/assets/icon-copy.svg"
                        onClicked: {
                            viewModel.copyToClipboard(myAddressID.text);
                        }
                    }
                }

                Component.onDestruction: {
                    // TODO: "Save" may be deleted in future, when we'll have editor for own addresses.
                    viewModel.saveNewAddress();
                }

                Item {
                    Layout.fillHeight: true
                }
            }
        }
    }

    /////////////////////////////////////////////////////////////
    /// Send layout /////////////////////////////////////////////
    /////////////////////////////////////////////////////////////

    Component {
        id: send_layout
        Item {
            property Item defaultFocusItem: receiverAddrInput

            Component.onCompleted: {
                receiverAddrInput.text = "";
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.topMargin: 73
                anchors.bottomMargin: 30

                SFText {
                    Layout.alignment: Qt.AlignHCenter
                    font.pixelSize: 18
                    font.styleName: "Bold"; font.weight: Font.Bold
                    color: Style.white
                    text: qsTr("Send Beam")
                }

                Item {
                    Layout.fillHeight: true
                    Layout.minimumHeight: 10
                    Layout.maximumHeight: 30
                }

                RowLayout {
                    Layout.fillWidth: true
                    //Layout.topMargin: 50

                    spacing: 70

                    Item {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                        height: childrenRect.height

                        ColumnLayout {
                            width: parent.width

                            spacing: 12

                            SFText {
                                font.pixelSize: 14
                                font.styleName: "Bold"; font.weight: Font.Bold
                                color: Style.white
                                text: qsTr("Send To:")
                            }

                            SFTextInput {
                                Layout.fillWidth: true

                                id: receiverAddrInput
                                font.pixelSize: 14
                                color: Style.white
                                text: viewModel.receiverAddr

                                validator: RegExpValidator { regExp: /[0-9a-fA-F]{1,80}/ }
                                selectByMouse: true

                                placeholderText: qsTr("Please specify contact")

                                onTextChanged : {
                                    receiverAddressError.visible = receiverAddrInput.text.length > 0 && !viewModel.isValidReceiverAddress(receiverAddrInput.text)
                                }
                            }

                            SFText {
                                Layout.alignment: Qt.AlignTop
                                id: receiverAddressError
                                color: Style.validator_color
                                font.pixelSize: 10
                                text: qsTr("Invalid address")
                                visible: false
                            }

                            SFText {
                                id: receiverName
                                color: Style.white
                                font.pixelSize: 14
                                font.styleName: "Bold"; font.weight: Font.Bold
                            }

                            Binding {
                                target: viewModel
                                property: "receiverAddr"
                                value: receiverAddrInput.text
                            }
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                        height: childrenRect.height

                        ColumnLayout {
                            width: parent.width

                            spacing: 12

                            SFText {
                                font.pixelSize: 14
                                font.styleName: "Bold"; font.weight: Font.Bold
                                color: Style.white
                                text: qsTr("Transaction amount")
                            }

                            RowLayout {
                                Layout.fillWidth: true

                                ColumnLayout {
                                    Layout.fillWidth: true

                                    SFTextInput {
                                        Layout.fillWidth: true

                                        id: amount_input

                                        font.pixelSize: 36
                                        font.styleName: "Light"; font.weight: Font.Light
                                        color: Style.heliotrope

                                        property double amount: 0

                                        validator: RegExpValidator { regExp: /^(([1-9][0-9]{0,7})|(1[0-9]{8})|(2[0-4][0-9]{7})|(25[0-3][0-9]{6})|(0))(\.[0-9]{0,7}[1-9])?$/ }
                                        selectByMouse: true
                                    
                                        onTextChanged: {
                                            if (focus) {
                                                amount = text ? text : 0;
                                            }
                                        }

                                        onFocusChanged: {
                                            if (amount > 0) {
                                                // QLocale::FloatingPointShortest = -128
                                                text = focus ? amount : amount.toLocaleString(Qt.locale(), 'f', -128);
                                            }
                                        }
                                    }

                                    Item {
                                        Layout.minimumHeight: 16
                                        Layout.fillWidth: true

                                        SFText {
                                            text: "Maximum available amount is " + viewModel.available + " B"
                                            color: Style.validator_color
                                            font.pixelSize: 14
                                            font.styleName: "Italic"
                                            visible: !viewModel.isEnoughMoney
                                        }
                                    }

                                    Binding {
                                        target: viewModel
                                        property: "sendAmount"
                                        value: amount_input.amount
                                    }
                                }

                                SFText {
                                    font.pixelSize: 24
                                    color: Style.white
                                    text: qsTr("BEAM")
                                }
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true

                    spacing: 70

                    Item {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                        height: childrenRect.height

                        ColumnLayout {
                            width: parent.width

                            spacing: 12

                            SFText {
                                font.pixelSize: 14
                                font.styleName: "Bold"; font.weight: Font.Bold
                                color: Style.white
                                text: qsTr("Comment")
                            }

                            SFTextInput {
                                id: comment_input
                                Layout.fillWidth: true

                                font.pixelSize: 14
                                color: Style.white

                                maximumLength: 1024
                                selectByMouse: true
                            }

                            Binding {
                                target: viewModel
                                property: "comment"
                                value: comment_input.text
                            }
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                        height: childrenRect.height

                        ColumnLayout {
                            width: parent.width

                            spacing: 12

                            SFText {
                                font.pixelSize: 14
                                font.styleName: "Bold"; font.weight: Font.Bold
                                color: Style.white
                                text: qsTr("Transaction fee")
                            }

                            RowLayout {
                                Layout.fillWidth: true

                                ColumnLayout {
                                    Layout.fillWidth: true

                                    SFTextInput {
                                        Layout.fillWidth: true
                                        id: fee_input

                                        font.pixelSize: 36
                                        font.styleName: "Light"; font.weight: Font.Light
                                        color: Style.heliotrope

                                        text: viewModel.defaultFeeInGroth.toLocaleString(Qt.locale(), 'f', -128)

                                        property int amount: viewModel.defaultFeeInGroth

                                        validator: IntValidator {bottom: 0}
                                        maximumLength: 15
                                        selectByMouse: true
                                    
                                        onTextChanged: {
                                            if (focus) {
                                                amount = text ? text : 0;
                                            }
                                        }

                                        onFocusChanged: {
                                            if (amount >= 0) {
                                                // QLocale::FloatingPointShortest = -128
                                                text = focus ? amount : amount.toLocaleString(Qt.locale(), 'f', -128);
                                            }
                                        }
                                    }
                                }

                                SFText {
                                    font.pixelSize: 24
                                    color: Style.white
                                    text: qsTr("GROTH")
                                }
                            }

                            Binding {
                                target: viewModel
                                property: "feeGrothes"
                                //value: feeSlider.value
                                value: fee_input.amount
                            }

                            Item {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignTop
                                Layout.topMargin: 20
                                height: 96

                                Item {
                                    anchors.fill: parent

                                    RowLayout {
                                        anchors.fill: parent
                                        readonly property int margin: 15
                                        anchors.leftMargin: margin
                                        anchors.rightMargin: margin
                                        spacing: margin

                                        Item {
                                            Layout.fillWidth: true
                                            Layout.alignment: Qt.AlignCenter
                                            height: childrenRect.height

                                            ColumnLayout {
                                                width: parent.width
                                                spacing: 10

                                                SFText {
                                                    Layout.alignment: Qt.AlignHCenter
                                                    font.pixelSize: 18
                                                    font.styleName: "Bold"; font.weight: Font.Bold
                                                    color: Style.bluey_grey
                                                    text: qsTr("Remaining")
                                                }

                                                RowLayout
                                                {
                                                    Layout.alignment: Qt.AlignHCenter
                                                    spacing: 6
                                                    clip: true

                                                    SFText {
                                                        font.pixelSize: 24
                                                        font.styleName: "Light"; font.weight: Font.Light
                                                        color: Style.bluey_grey
                                                        text: viewModel.actualAvailable
                                                    }

                                                    SvgImage {
                                                        Layout.topMargin: 4
                                                        sourceSize: Qt.size(16, 24)
                                                        source: "qrc:/assets/b-grey.svg"
                                                    }
                                                }
                                            }
                                        }

                                        Rectangle {
                                            id: separator
                                            Layout.fillHeight: true
                                            Layout.topMargin: 10
                                            Layout.bottomMargin: 10
                                            width: 1
                                            color: Style.bluey_grey
                                        }

                                        Item {
                                            Layout.fillWidth: true
                                            Layout.alignment: Qt.AlignCenter
                                            height: childrenRect.height

                                            ColumnLayout {
                                                width: parent.width
                                                spacing: 10

                                                SFText {
                                                    Layout.alignment: Qt.AlignHCenter
                                                    font.pixelSize: 18
                                                    font.styleName: "Bold"; font.weight: Font.Bold
                                                    color: Style.bluey_grey
                                                    text: qsTr("Change")
                                                }

                                                RowLayout
                                                {
                                                    Layout.alignment: Qt.AlignHCenter
                                                    spacing: 6
                                                    clip: true

                                                    SFText {
                                                        font.pixelSize: 24
                                                        font.styleName: "Light"; font.weight: Font.Light
                                                        color: Style.bluey_grey
                                                        text: viewModel.change
                                                    }

                                                    SvgImage {
                                                        Layout.topMargin: 4
                                                        sourceSize: Qt.size(16, 24)
                                                        source: "qrc:/assets/b-grey.svg"
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                                Rectangle {
                                    anchors.fill: parent
                                    radius: 10
                                    color: Style.white
                                    opacity: 0.1
                                }
                            }
                        }
                    }
                }

                Item {
                    Layout.fillHeight: true
                    Layout.minimumHeight: 10
                    Layout.maximumHeight: 30
                }

                Row {
                    Layout.alignment: Qt.AlignHCenter

                    spacing: 30

                    CustomButton {
                        text: qsTr("back")
                        icon.source: "qrc:/assets/icon-back.svg"
                        onClicked: {
                            walletView.pop();
                        }
                    }

                    CustomButton {
                        text: qsTr("send")
                        palette.buttonText: Style.marine
                        palette.button: Style.heliotrope
                        icon.source: "qrc:/assets/icon-send-blue.svg"
                        enabled: {viewModel.isEnoughMoney && amount_input.amount > 0 && receiverAddrInput.acceptableInput }
                        onClicked: {
                            if (viewModel.isValidReceiverAddress(viewModel.receiverAddr)) {
                                confirmationDialog.addressText = viewModel.receiverAddr;
                                confirmationDialog.amountText = amount_input.amount.toLocaleString(Qt.locale(), 'f', -128) + " " + qsTr("BEAM");
                                confirmationDialog.feeText = fee_input.amount.toLocaleString(Qt.locale(), 'f', -128) + " " + qsTr("GROTH");

                                confirmationDialog.open();
                            } else {
                                var message = "Address %1 is invalid";
                                invalidAddressDialog.text = message.arg(viewModel.receiverAddr);
                                invalidAddressDialog.open();
                            }
                        }
                    }
                }

                Item {
                    Layout.fillHeight: true
                }
            }
        }
    }

    Component {
        id: wallet_layout
        Item {            
            
            Row{
                anchors.top: parent.top
                anchors.right: parent.right
                spacing: 19

                CustomButton {
                    palette.button: Style.bright_sky_blue
                    palette.buttonText: Style.marine
                    icon.source: "qrc:/assets/icon-receive-blue.svg"
                    text: qsTr("receive")

                    onClicked: {
                        viewModel.generateNewAddress();
                        walletView.push(receive_layout);
                    }
                }

                CustomButton {
                    palette.button: Style.heliotrope
                    palette.buttonText: Style.marine
                    icon.source: "qrc:/assets/icon-send-blue.svg"
                    text: qsTr("send")

                    onClicked: {
                        walletView.push(send_layout);
                    }
                }
            }

            Item {
                y: 97
                height: 206

                anchors.left: parent.left
                anchors.right: parent.right

                RowLayout {

                    id: wide_panels

                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: parent.height

                    spacing: 30

                    AvailablePanel {
                        Layout.maximumWidth: 700
                        Layout.minimumWidth: 350
                        Layout.fillHeight: true
                        Layout.fillWidth: true

                        value: viewModel.available
                        onCopyValueText: viewModel.copyToClipboard(value)
                    }

                    SecondaryPanel {
                        Layout.minimumWidth: 350
                        Layout.fillHeight: true
                        Layout.fillWidth: true

                        title: qsTr("In progress")
                        receiving: viewModel.receiving
                        sending: viewModel.sending
                        maturing: viewModel.maturing

                        onCopyValueText: viewModel.copyToClipboard(value)
                    }
                }
            }

            Item
            {
                y: 320

                anchors.left: parent.left
                anchors.right: parent.right

                SFText {
                    x: 30

                    font {
                        pixelSize: 18
                        styleName: "Bold"; weight: Font.Bold
                    }

                    color: Style.white

                    text: qsTr("Transactions")
                }
            }

            Rectangle {
                anchors.fill: parent;
                anchors.topMargin: 394+46-33

                color: "#0a344d"
            }

            CustomTableView {

                id: transactionsView

                anchors.fill: parent
                anchors.topMargin: 394-33
                Layout.bottomMargin: 9

                property int rowHeight: 69

                frameVisible: false
                selectionMode: SelectionMode.NoSelection
                backgroundVisible: false

                sortIndicatorVisible: true
                sortIndicatorColumn: 1
                sortIndicatorOrder: Qt.DescendingOrder

                Binding{
                    target: viewModel
                    property: "sortRole"
                    value: transactionsView.getColumn(transactionsView.sortIndicatorColumn).role
                }

                Binding{
                    target: viewModel
                    property: "sortOrder"
                    value: transactionsView.sortIndicatorOrder
                }

                property int resizableWidth: parent.width - incomeColumn.width - actionsColumn.width

                TableViewColumn {
                    id: incomeColumn
                    role: viewModel.incomeRole
                    width: 40
                    elideMode: Text.ElideRight
                    movable: false
                    resizable: false
                    delegate: Item {

                        Item {
                            width: parent.width
                            height: transactionsView.rowHeight

                            clip:true

                            SvgImage {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.horizontalCenter: parent.horizontalCenter
                                source: styleData.value ? "qrc:/assets/icon-received.svg" : "qrc:/assets/icon-sent.svg"
                            }
                        }
                    }
                }

                TableViewColumn {
                    role: viewModel.dateRole
                    title: qsTr("Date | time")
                    width: 160 * transactionsView.resizableWidth / 960
                    elideMode: Text.ElideRight
                    resizable: false
                    movable: false
                    delegate: Item {
                        Item {
                            width: parent.width
                            height: transactionsView.rowHeight
                            clip:true

                            SFLabel {
                                font.pixelSize: 14
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.leftMargin: 20
                                elide: Text.ElideRight
                                anchors.verticalCenter: parent.verticalCenter
                                text: styleData.value
                                color: Style.white
                                copyMenuEnabled: true
                                onCopyText: viewModel.copyToClipboard(text)
                            }
                        }
                    }
                }

                TableViewColumn {
                    role: viewModel.userRole
                    title: qsTr("Address")
                    width: 400 * transactionsView.resizableWidth / 960
                    elideMode: Text.ElideMiddle
                    resizable: false
                    movable: false
                    delegate: Item {
                        Item {
                            width: parent.width
                            height: transactionsView.rowHeight
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
                                onCopyText: viewModel.copyToClipboard(text)
                            }
                        }
                    }
                }

                TableViewColumn {
                    role: viewModel.amountRole
                    title: qsTr("Amount")
                    width: 200 * transactionsView.resizableWidth / 960
                    elideMode: Text.ElideRight
                    movable: false
                    resizable: false
                    delegate: Item {
                        Item {
                            width: parent.width
                            height: transactionsView.rowHeight
                            property bool income: (styleData.row >= 0) ? viewModel.transactions[styleData.row].income : false
                            SFLabel {
                                anchors.leftMargin: 20
                                anchors.right: parent.right
                                anchors.left: parent.left
                                color: parent.income ? Style.bright_sky_blue : Style.heliotrope
                                elide: Text.ElideRight
                                anchors.verticalCenter: parent.verticalCenter
                                text: "<font size='6'>" + (parent.income ? "+ " : "- ") + styleData.value + "</font>"
                                textFormat: Text.StyledText
                                font.styleName: "Light"; font.weight: Font.Thin
                                copyMenuEnabled: true
                                onCopyText: viewModel.copyToClipboard(styleData.value)
                            }
                        }
                    }
                }

                TableViewColumn {
                    role: viewModel.statusRole
                    title: qsTr("Status")
                    width: 200 * transactionsView.resizableWidth / 960
                    elideMode: Text.ElideRight
                    movable: false
                    resizable: false
                    delegate: Item {
                        Item {
                            width: parent.width
                            height: transactionsView.rowHeight

                            clip:true

                            SFLabel {
                                font.pixelSize: 14
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.leftMargin: 20
                                color: {
                                    if(styleData.value === "sent")
                                        Style.heliotrope
                                    else if(styleData.value === "received")
                                        Style.bright_sky_blue
                                    else Style.white
                                }
                                elide: Text.ElideRight
                                anchors.verticalCenter: parent.verticalCenter
                                text: styleData.value
                                copyMenuEnabled: true
                                onCopyText: viewModel.copyToClipboard(text)
                            }
                        }
                    }
                }

                TableViewColumn {
                    id: actionsColumn
                    role: "status"
                    title: ""
                    width: 40
                    movable: false
                    resizable: false
                    delegate: txActions
                }

                model: viewModel.transactions

                Component {
                    id: txActions
                    Item {
                        Item {
                            width: parent.width
                            height: transactionsView.rowHeight

                            Row{
                                anchors.right: parent.right
                                anchors.rightMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 10
                                CustomToolButton {
                                    icon.source: "qrc:/assets/icon-actions.svg"
                                    ToolTip.text: qsTr("Actions")
                                    onClicked: {
                                        txContextMenu.transaction = viewModel.transactions[styleData.row];
                                        txContextMenu.popup();
                                    }
                                }
                            }
                        }
                    }
                }

                ContextMenu {
                    id: txContextMenu
                    modal: true
                    dim: false
                    property TxObject transaction
                    Action {
                        text: qsTr("copy address")
                        icon.source: "qrc:/assets/icon-copy.svg"
                        onTriggered: {
                            if (!!txContextMenu.transaction)
                            {
                                viewModel.copyToClipboard(txContextMenu.transaction.user);
                            }
                        }
                    }
                    Action {
                        text: qsTr("cancel")
                        onTriggered: {
                           viewModel.cancelTx(txContextMenu.transaction);
                        }
                        enabled: !!txContextMenu.transaction && txContextMenu.transaction.canCancel
                        icon.source: "qrc:/assets/icon-cancel.svg"
                    }
                    Action {
                        text: qsTr("delete")
                        icon.source: "qrc:/assets/icon-delete.svg"
                        enabled: !!txContextMenu.transaction && txContextMenu.transaction.canDelete
                        onTriggered: {
                            deleteTransactionDialog.text = qsTr("The transaction will be deleted. This operation can not be undone");
                            deleteTransactionDialog.open();
                        }
                    }
                    Connections {
                        target: deleteTransactionDialog
                        onAccepted: {
                            viewModel.deleteTx(txContextMenu.transaction);
                        }
                    }
                }

                rowDelegate: Item {
                    height: transactionsView.rowHeight
                    id: rowItem
                    property bool collapsed: true

                    width: parent.width

                    Column {
                        id: rowColumn
                        width: parent.width
                        Rectangle {
                            height: transactionsView.rowHeight
                            width: parent.width
                            color: styleData.alternate ? "transparent" : Style.light_navy
                        }
                        Item {
                            id: txDetails
                            height: 0
                            visible: height > 0
                            width: parent.width
                            clip: true

                            property int maximumHeight: 200 + commentTx.contentHeight

                            onMaximumHeightChanged: {
                                if (!rowItem.collapsed) {
                                    rowItem.height = maximumHeight + transactionsView.rowHeight
                                    txDetails.height = maximumHeight
                                }
                            }

                            Rectangle {
                                anchors.fill: parent
                                color: Style.bright_sky_blue
                                opacity: 0.1
                            }
                            RowLayout {
                                anchors.fill: parent
                                GridLayout {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    Layout.maximumWidth: transactionsView.width - 2 * Layout.margins
                                    Layout.margins: 30
                                    columns: 2
                                    columnSpacing: 44
                                    rowSpacing: 14

                                    SFText {
                                        font.pixelSize: 14
                                        color: Style.white
                                        text: qsTr("General transaction info")
                                        font.styleName: "Bold"; font.weight: Font.Bold
                                        Layout.columnSpan: 2
                                    }

                                    SFText {
                                        Layout.row: 1
                                        font.pixelSize: 14
                                        color: Style.bluey_grey
                                        text: qsTr("Sending address:")
                                    }
                                    SFLabel {
                                        copyMenuEnabled: true
                                        font.pixelSize: 14
                                        color: Style.white
                                        text: {
                                            if(!!viewModel.transactions[styleData.row])
                                            {
                                                return viewModel.transactions[styleData.row].sendingAddress;
                                            }
                                            return "";
                                        }
                                        onCopyText: viewModel.copyToClipboard(text)
                                    }

                                    SFText {
                                        Layout.row: 2
                                        font.pixelSize: 14
                                        color: Style.bluey_grey
                                        text: qsTr("Receiving address:")
                                    }
                                    SFLabel {
                                        copyMenuEnabled: true
                                        font.pixelSize: 14
                                        color: Style.white
                                        text: {
                                            if(!!viewModel.transactions[styleData.row])
                                            {
                                                return viewModel.transactions[styleData.row].receivingAddress;
                                            }
                                            return "";
                                        }                      
                                        onCopyText: viewModel.copyToClipboard(text)
                                    }

                                    SFText {
                                        Layout.row: 3
                                        font.pixelSize: 14
                                        color: Style.bluey_grey
                                        text: qsTr("Transaction fee:")
                                    }
                                    SFLabel {
                                        copyMenuEnabled: true
                                        font.pixelSize: 14
                                        color: Style.white
                                        text:{
                                            if(!!viewModel.transactions[styleData.row])
                                            {
                                                return viewModel.transactions[styleData.row].fee;
                                            }
                                            return "";
                                        }
                                        onCopyText: viewModel.copyToClipboard(text)
                                    }

                                    SFText {
                                       Layout.row: 4
                                        font.pixelSize: 14
                                        color: Style.bluey_grey
                                        text: qsTr("Comment:")
                                    }
                                    SFLabel {
                                        id: commentTx
                                        copyMenuEnabled: true
                                        font.pixelSize: 14
                                        color: Style.white
                                        text: {
                                            if(!!viewModel.transactions[styleData.row])
                                            {
                                                return viewModel.transactions[styleData.row].comment;
                                            }
                                            return "";
                                        }
                                        font.styleName: "Italic"
                                        Layout.fillWidth: true
                                        wrapMode : Text.Wrap
                                        elide: Text.ElideRight
                                        onCopyText: viewModel.copyToClipboard(text)
                                    }
                                    SFText {
                                       Layout.row: 5
                                        font.pixelSize: 14
                                        color: Style.bluey_grey
                                        text: qsTr("Kernel ID:")
                                    }
                                    SFLabel {
                                        id: kernelID
                                        copyMenuEnabled: true
                                        font.pixelSize: 14
                                        color: Style.white
                                        text: {
                                            if(!!viewModel.transactions[styleData.row])
                                            {
                                                return viewModel.transactions[styleData.row].kernelID;
                                            }
                                            return "";
                                        }
                                        font.styleName: "Italic"
                                        Layout.fillWidth: true
                                        wrapMode : Text.Wrap
                                        elide: Text.ElideRight
                                        onCopyText: viewModel.copyToClipboard(text)
                                    }
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                }
                            }
                        }
                    }

                    MouseArea {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        height: transactionsView.rowHeight
                        width: parent.width

                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: {
                            if (styleData.row === undefined 
                             || styleData.row < 0
                             || styleData.row >= viewModel.transactions.length)
                            {
                                return;
                            }
                            if (mouse.button === Qt.RightButton )
                            {
                                txContextMenu.transaction = viewModel.transactions[styleData.row];
                                txContextMenu.popup();
                            }
                            else if (mouse.button === Qt.LeftButton && !!viewModel.transactions[styleData.row])
                            {
                                if (parent.collapsed)
                                {
                                    expand.start()
                                }
                                else 
                                {
                                    collapse.start()
                                }
                                parent.collapsed = !parent.collapsed;
                            }
                        }
                    }

                    ParallelAnimation {
                        id: expand
                        running: false

                        property int expandDuration: 200

                        NumberAnimation {
                            target: rowItem
                            easing.type: Easing.Linear
                            property: "height"
                            to: transactionsView.rowHeight + txDetails.maximumHeight
                            duration: expand.expandDuration
                        }

                        NumberAnimation {
                            target: txDetails
                            easing.type: Easing.Linear
                            property: "height"
                            to: txDetails.maximumHeight
                            duration: expand.expandDuration
                        }
                    }

                    ParallelAnimation {
                        id: collapse
                        running: false

                        property int collapseDuration: 200

                        NumberAnimation {
                            target: rowItem
                            easing.type: Easing.Linear
                            property: "height"
                            to: transactionsView.rowHeight
                            duration: collapse.collapseDuration
                        }

                        NumberAnimation {
                            target: txDetails
                            easing.type: Easing.Linear
                            property: "height"
                            to: 0
                            duration: collapse.collapseDuration
                        }
                    }
                }

                itemDelegate: Item {
                    Item {
                        width: parent.width
                        height: transactionsView.rowHeight
                        TableItem {
                            text: styleData.value
                            elide: styleData.elideMode
                        }
                    }
                }
            }
        }
    }

    StackView {
        id: walletView
        anchors.fill: parent
        initialItem: wallet_layout

        pushEnter: Transition {
            enabled: false
        }
        pushExit: Transition {
            enabled: false
        }
        popEnter: Transition {
            enabled: false
        }
        popExit: Transition {
            enabled: false
        }

        onCurrentItemChanged: {
            if (currentItem && currentItem.defaultFocusItem) {
                walletView.currentItem.defaultFocusItem.forceActiveFocus();
            }
        }
    }

    Component.onCompleted: {
        if (root.toSend) {
            walletView.push(send_layout);
            root.toSend = false;
        }
    }    
}
