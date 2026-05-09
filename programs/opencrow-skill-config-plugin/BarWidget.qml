import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Modules.Bar.Extras
import qs.Services.UI
import qs.Widgets

// Bar pill that lights up when there's at least one pending input
// request. The auto-show in Main.qml usually means the user doesn't
// need to click it — but if they dismissed the panel and another
// request arrives, the lit icon is the recovery affordance.
Item {
  id: root

  property var pluginApi: null
  property var main: pluginApi?.mainInstance || null

  property ShellScreen screen
  property string widgetId: ""
  property string section: ""

  readonly property int pendingCount: main?.pending?.length ?? 0
  readonly property bool active: pendingCount > 0

  readonly property string currentIcon: active ? "key" : "key-off"
  readonly property color iconColor:
    active ? Color.mPrimary : Color.mOnSurfaceVariant

  implicitWidth: pill.width
  implicitHeight: pill.height

  BarPill {
    id: pill
    screen: root.screen
    oppositeDirection: BarService.getPillDirection(root)
    icon: root.currentIcon
    autoHide: true
    customTextIconColor: root.iconColor
    text: root.active ? String(root.pendingCount) : ""

    onClicked: {
      if (pluginApi) pluginApi.togglePanel(root.screen, root);
    }
  }
}
