import QtQuick 2.2
import Sailfish.Silica 1.0
import Sailfish.Pickers 1.0

import '../generic/utils.js' as QmlJs
import '../components' as PlatformComponents
import '../generic' as GenericComponents

Page {
    id: page
    property bool isDarkTheme: Theme.colorScheme === Theme.LightOnDark
    property bool isAppLoaded: false
    property string seabassFilePath

    allowedOrientations: Orientation.All

    GenericComponents.EditorApi {
        id: api
        filePath: seabassFilePath
        isReadOnly: filePath === QmlJs.DEFAULT_FILE_PATH
        forceReadOnly: filePath === QmlJs.DEFAULT_FILE_PATH

        onMessageSent: function(jsonMessage) {
            webView.experimental.postMessage(jsonMessage)
        }

        onIsReadOnlyChanged: {
            if (isReadOnly) {
                Qt.inputMethod.hide()
            }
        }

        onAppLoaded: function (data) {
            isAppLoaded = true
            console.log(JSON.stringify(data))
            toolbar.open = data.isSailfishToolbarOpened
        }
    }

    onIsDarkThemeChanged: {
        if (!isAppLoaded) {
            return
        }

        api.isDarkTheme = isDarkTheme
    }

    onOrientationChanged: fixResize()

    // #region LAYOUT

    SilicaWebView {
        id: webView
        url: '../html/index.html'

        anchors.top: page.top
        anchors.bottom: toolbar.open ? toolbar.top : page.bottom
        width: page.width

        experimental.transparentBackground: true
        experimental.deviceWidth: getDeviceWidth()
        experimental.preferences.navigatorQtObjectEnabled: true
        experimental.onMessageReceived: {
            var msg = JSON.parse(message.data)
            api.handleMessage(msg.action, msg.data)
        }

        PullDownMenu {
            busy: api.isSaveInProgress
            MenuItem {
                text: qsTr("Open file...")
                onClicked: pageStack.push(filePickerPage)
            }
            MenuItem {
                enabled: !api.isSaveInProgress
                visible: !api.isReadOnly
                text: api.isSaveInProgress ? qsTr("Saving...") : qsTr("Save")
                onClicked: api.requestSaveFile()
            }
        }

        PushUpMenu {
            MenuItem {
                text: qsTr(toolbar.open ? "Hide toolbar" : "Show toolbar")
                onClicked: {
                    toolbar.open = !toolbar.open
                    api.postMessage('setPreferences', {
                        isSailfishToolbarOpened: toolbar.open
                    })
                }
            }
            MenuItem {
                text: qsTr('About')
                onClicked: pageStack.push(Qt.resolvedUrl("About.qml"))
            }
        }
    }

    DockedPanel {
        id: toolbar
        dock: Dock.Bottom
        width: parent.width
        height: Theme.itemSizeMedium
        focus: false

        PlatformComponents.Toolbar {
            hasUndo: api.hasUndo
            hasRedo: api.hasRedo
            readOnly: api.isReadOnly
            readOnlyEnabled: !api.forceReadOnly

            onUndo: api.postMessage('undo')
            onRedo: api.postMessage('redo')
            onToggleReadOnly: api.postMessage('toggleReadOnly')
            onNavigateDown: api.postMessage('navigateDown')
            onNavigateUp: api.postMessage('navigateUp')
            onNavigateLeft: api.postMessage('navigateLeft')
            onNavigateRight: api.postMessage('navigateRight')
            onNavigateLineStart: api.postMessage('navigateLineStart')
            onNavigateLineEnd: api.postMessage('navigateLineEnd')
            onNavigateFileStart: api.postMessage('navigateFileStart')
            onNavigateFileEnd: api.postMessage('navigateFileEnd')
        }
    }

    Component {
        id: filePickerPage
        FilePickerPage {
            onSelectedContentPropertiesChanged: {
                if (!selectedContentProperties.filePath) {
                    return
                }

                api.filePath = selectedContentProperties.filePath
            }
        }
    }

    /**
     * Displays error message
     * @param {Error} error - error object
     * @param {string} [errorMessage] - error message to display
     * @returns {undefined}
     */
    function displayError(error, errorMessage) {
        console.error(error, errorMessage)
        pageStack.completeAnimation()
        pageStack.push(Qt.resolvedUrl("ErrorDialog.qml"), {
            "text": errorMessage || error.message
        })
    }

    /**
     * Returns HTML device-width scaled correctly for the current device
     * @returns {int} - device width in CSS pixels
     */
    function getDeviceWidth() {
        const deviceWidth = page.orientation === Orientation.Portrait
            ? Screen.width
            : Screen.height
        return deviceWidth / Theme.pixelRatio / (540 / 320)
    }

    /**
     * Simple hak to fix issue with WebView not resized properly automatically when changing device orientation.
     * @returns {undefined}
     */
    function fixResize() {
        webView.experimental.deviceWidth = getDeviceWidth()
        page.x = 1
        page.x = 0
    }

    // #endregion JS_FUNCTIONS
}
