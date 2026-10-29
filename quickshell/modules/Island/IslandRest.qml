import QtQuick
import "../../theme"

Text {
    property date now: new Date()
    text: Qt.formatDateTime(now, "h:mm:ss AP")
    color: Theme.text
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSizeLarge
    font.bold: true
}
