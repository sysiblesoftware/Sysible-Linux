/* Minimal Sysible Linux install slideshow */
import QtQuick 2.0;
import calamares.slideshow 1.0;

Presentation {
    id: presentation

    Timer {
        interval: 8000
        running: true
        repeat: true
        onTriggered: presentation.goToNextSlide()
    }

    Slide {
        Rectangle {
            anchors.fill: parent
            color: "#0d1117"
            Text {
                anchors.centerIn: parent
                horizontalAlignment: Text.AlignHCenter
                color: "#e6edf3"
                font.pixelSize: 22
                text: "Installing Sysible Linux\n\nThe engineering & automation workstation."
            }
        }
    }
}
