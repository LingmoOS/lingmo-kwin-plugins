// KWin 6 scripting API: windows instead of clients, frameGeometry instead of geometry
function forceFullScreen(window) {
    window.frameGeometry = workspace.clientArea(KWin.ScreenArea, window);
}

function setupConnection(window) {
    if (window.resourceClass != "lingmo-launcher"
            || window.resourceName != "lingmo-launcher" || window.dialog) {
        return;
    }

    forceFullScreen(window);
    window.frameGeometryChanged.connect(function () {
        forceFullScreen(window);
    });
}

workspace.windowAdded.connect(setupConnection);
// connect all existing windows
workspace.windowList().forEach(setupConnection);
