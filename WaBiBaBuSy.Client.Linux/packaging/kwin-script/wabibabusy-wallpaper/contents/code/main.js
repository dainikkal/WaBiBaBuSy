// KWin script (Plasma 6): keeps WaBiBaBuSy wallpaper windows above plasmashell's desktop, still below every app.
// A click on the bare desktop activates plasmashell's desktop window, which KWin raises to the top of the desktop
// layer, over the wallpaper. The client raises its windows back on its own, but under Wayland it cannot see the
// native-Wayland plasmashell — KWin sees both, so the fix lives here. Matters most for BiBaBo: the bomb seat's
// terminals are drawn on the wallpaper and take the player's clicks.

const WM_CLASS = "wabibabusy-wallpaper";
const TITLE = "WaBiBaBuSy Wallpaper";

function isWallpaper(w) {
    return w.resourceClass === WM_CLASS || w.resourceName === WM_CLASS || w.caption === TITLE;
}

let raising = false;

function keepWallpaperOnTop() {
    if (raising || typeof workspace.raiseWindow !== "function")
        return;
    const stack = workspace.stackingOrder;   // bottom → top
    let lowestOwn = -1, highestForeignDesktop = -1;
    for (let i = 0; i < stack.length; i++) {
        const w = stack[i];
        if (isWallpaper(w)) {
            if (lowestOwn < 0) lowestOwn = i;
        } else if (w.desktopWindow) {
            highestForeignDesktop = i;
        }
    }
    if (lowestOwn < 0 || highestForeignDesktop < lowestOwn)
        return;

    raising = true;   // raiseWindow restacks synchronously; don't re-enter from stackingOrderChanged
    try {
        for (const w of stack.filter(isWallpaper))
            workspace.raiseWindow(w);
    } finally {
        raising = false;
    }
}

workspace.stackingOrderChanged.connect(keepWallpaperOnTop);
workspace.windowActivated.connect(keepWallpaperOnTop);
workspace.windowAdded.connect(keepWallpaperOnTop);
keepWallpaperOnTop();
