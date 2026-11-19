import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "sd.siteblock"
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  readonly property string home: Quickshell.env("HOME")
  readonly property string sitesPath: home + "/.config/sd-siteblock/sites"
  property var sites: []
  property real until: 0
  property real now: Date.now() / 1000
  readonly property bool blocking: until > now
  readonly property bool opened: popupOpen
  property bool popupOpen: false
  property real total: 0
  property int picked: 30

  function open() { popupOpen = true }
  function close() { popupOpen = false }
  function closeForPopoutSwitch() { popupOpen = false }
  readonly property bool popoutSwitchClosing: false

  Translations { id: strings; directory: Qt.resolvedUrl("i18n") }

  function save(list) {
    sites = list
    sitesFile.setText(list.join("\n") + "\n")
  }

  function addSite(text) {
    var d = text.trim().toLowerCase().replace(/^https?:\/\//, "").replace(/^www\./, "").replace(/\/.*$/, "")
    if (!/^([a-z0-9-]+\.)+[a-z]{2,}$/.test(d) || sites.indexOf(d) >= 0) return false
    save(sites.concat([d]))
    return true
  }

  function removeSite(d) { save(sites.filter(function(s) { return s !== d })) }

  function start(minutes) {
    if (blocking || !installed || sites.length === 0) return
    blockProc.command = ["sudo", "-n", "/usr/local/bin/siteblock", "on", String(minutes)].concat(sites)
    total = minutes * 60
    picked = minutes
    blockProc.running = true
  }

  function stop() {
    stopProc.running = true
  }

  Process {
    id: stopProc
    command: ["sudo", "-n", "/usr/local/bin/siteblock", "off"]
    onExited: { untilFile.reload(); root.until = 0 }
  }

  FileView {
    id: sitesFile
    path: root.sitesPath
    printErrors: false
    onLoaded: root.sites = text().split("\n").map(function(s) { return s.trim() }).filter(function(s) { return s })
  }

  FileView {
    id: untilFile
    path: "/run/siteblock-until"
    printErrors: false
    onLoaded: { root.now = Date.now() / 1000; root.until = parseInt(text()) || 0 }
    onLoadFailed: { root.now = Date.now() / 1000; root.until = 0 }
  }

  property bool installed: false
  Process {
    id: checkProc
    command: ["test", "-x", "/usr/local/bin/siteblock"]
    running: true
    onExited: function(code) { root.installed = code === 0 }
  }
  Process {
    id: installProc
    command: ["pkexec", "bash", Qt.resolvedUrl("install.sh").toString().replace("file://", "")]
    onExited: checkProc.running = true
  }

  Process { id: mkdir; command: ["mkdir", "-p", root.home + "/.config/sd-siteblock"]; running: true }
  Process {
    id: blockProc
    onExited: function(code) {
      untilFile.reload()
      if (code !== 0) root.bar.run("omarchy-notification-send 'Site Block' 'Helper not installed or sudo rule missing'")
    }
  }

  // Ticks only while blocking, to update the countdown and notice the end.
  Timer {
    interval: 1000
    running: root.blocking
    repeat: true
    onTriggered: { root.now = Date.now() / 1000; if (!root.blocking) untilFile.reload() }
  }

  function clock(t) {
    return Qt.formatTime(new Date(t * 1000), "h:mm")
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.blocking ? "󰌾" : "󰌿"
    active: root.blocking
    tooltipText: root.blocking ? strings.t("blocked").arg(root.clock(root.until)) : strings.t("tooltip")
    onPressed: function() { root.popupOpen = !root.popupOpen; if (root.popupOpen) { untilFile.reload() } }
  }

  readonly property color fg: Commons.Color.popups.text
  readonly property color line: Style.hoverFillFor(fg, Commons.Color.accent)

  function countdown() {
    var left = Math.max(0, Math.round(until - now))
    var h = Math.floor(left / 3600), m = Math.floor((left % 3600) / 60), sec = left % 60
    function pad(n) { return (n < 10 ? "0" : "") + n }
    return (h > 0 ? h + ":" + pad(m) : m) + ":" + pad(sec)
  }

  KeyboardPanel {
    id: panel
    anchorItem: root
    owner: root
    bar: root.bar
    open: root.popupOpen
    centerOnBar: false
    focusTarget: input
    contentWidth: panel.fittedContentWidth(Style.space(300))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    Column {
      id: column
      width: parent.width
      spacing: Style.space(14)

      // Header: title left, state right.
      Item {
        width: parent.width
        height: titleText.implicitHeight
        Text {
          id: titleText
          textFormat: Text.PlainText
          text: strings.t("title")
          color: root.fg
          font.family: Style.font.family
          font.pixelSize: Style.font.subtitle
          font.bold: true
        }
        ToggleSwitch {
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          visible: root.installed
          checked: root.blocking
          interactive: root.blocking || root.sites.length > 0
          onToggled: root.blocking ? root.stop() : root.start(root.picked)
        }
      }

      // Locked: countdown and progress.
      Column {
        width: parent.width
        spacing: Style.space(8)
        visible: root.blocking
        Text {
          textFormat: Text.PlainText
          text: root.countdown()
          color: Commons.Color.accent
          font.family: Style.font.family
          font.pixelSize: Style.space(34)
          font.bold: true
        }
        Rectangle {
          width: parent.width
          height: Style.space(3)
          color: root.line
          Rectangle {
            height: parent.height
            color: Commons.Color.accent
            width: root.total > 0 ? parent.width * Math.max(0, Math.min(1, (root.until - root.now) / root.total)) : parent.width
          }
        }
        Text {
          textFormat: Text.PlainText
          text: strings.t("blocked").arg(root.clock(root.until))
          color: root.fg
          opacity: 0.6
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
        }
      }

      // Setup needed.
      Column {
        width: parent.width
        spacing: Style.space(8)
        visible: !root.installed
        Button {
          text: strings.t("install")
          bordered: true
          onClicked: installProc.running = true
        }
      }

      // Duration picker.
      Row {
        id: durations
        width: parent.width
        spacing: Style.space(6)
        visible: !root.blocking && root.installed
        Repeater {
          model: [15, 30, 60, 120]
          delegate: Rectangle {
            required property int modelData
            width: (durations.width - durations.spacing * 3) / 4
            height: Style.space(40)
            readonly property bool chosen: modelData === root.picked
            color: chosen || area.containsMouse ? Style.selectedFillFor(root.fg, Commons.Color.accent) : "transparent"
            border.width: Math.max(1, Style.space(1))
            border.color: chosen || area.containsMouse ? Commons.Color.accent : root.line
            Column {
              anchors.centerIn: parent
              Text {
                anchors.horizontalCenter: parent.horizontalCenter
                textFormat: Text.PlainText
                text: modelData >= 60 ? String(modelData / 60) : String(modelData)
                color: root.fg
                font.family: Style.font.family
                font.pixelSize: Style.font.subtitle
                font.bold: true
              }
              Text {
                anchors.horizontalCenter: parent.horizontalCenter
                textFormat: Text.PlainText
                text: modelData >= 60 ? "hr" : "min"
                color: root.fg
                opacity: 0.55
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
              }
            }
            MouseArea {
              id: area
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.picked = modelData
            }
          }
        }
      }

      // Sites.
      Column {
        width: parent.width
        spacing: 0
        visible: root.installed

        Text {
          textFormat: Text.PlainText
          text: strings.t("sites")
          color: root.fg
          opacity: 0.5
          bottomPadding: Style.space(6)
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          font.bold: true
          font.letterSpacing: 2
        }

        Repeater {
          model: root.sites
          delegate: Item {
            id: siteRow
            required property string modelData
            width: column.width
            height: Style.space(34)
            Rectangle { width: parent.width; height: 1; color: root.line }
            Text {
              anchors.verticalCenter: parent.verticalCenter
              textFormat: Text.PlainText
              text: siteRow.modelData
              color: root.fg
              font.family: Style.font.family
              font.pixelSize: Style.font.body
            }
            Text {
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              textFormat: Text.PlainText
              text: root.blocking ? "󰌾" : "󰅖"
              color: root.fg
              opacity: root.blocking ? 0.4 : (rm.containsMouse ? 1 : 0.5)
              font.family: Style.font.family
              font.pixelSize: Style.font.body
              MouseArea {
                id: rm
                anchors.fill: parent
                anchors.margins: -Style.space(8)
                hoverEnabled: true
                enabled: !root.blocking
                cursorShape: Qt.PointingHandCursor
                onClicked: root.removeSite(siteRow.modelData)
              }
            }
          }
        }

        Text {
          visible: root.sites.length === 0
          textFormat: Text.PlainText
          text: strings.t("none")
          color: root.fg
          opacity: 0.5
          topPadding: Style.space(4)
          font.family: Style.font.family
          font.pixelSize: Style.font.body
        }
      }

      TextField {
        id: input
        width: parent.width
        visible: root.installed && !root.blocking
        placeholderText: strings.t("add")
        font.family: Style.font.family
        onAccepted: { if (root.addSite(text)) text = "" }
        Keys.onEscapePressed: root.close()
      }
    }
  }
}
