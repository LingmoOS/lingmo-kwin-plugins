/*
 * Copyright (C) 2026 LingmoOS Team.
 *
 * Author:     devalexandre <alexandre@dev2learn.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

// Hot corners for the actions KWin can't run itself on Lingmo. lingmo-settings
// writes the corners (KWin ElectricBorder numbers) to kwinrc [Script-linghotcorners]:
//   Launcher=7      toggles lingmo-launcher
//   LockScreen=3    locks the screen through lingmo-session
var actions = {
    Launcher: function () {
        callDBus("com.lingmo.Launcher", "/Launcher", "com.lingmo.Launcher", "toggle");
    },
    LockScreen: function () {
        callDBus("com.lingmo.Session", "/Session", "com.lingmo.Session", "lockScreen");
    }
};

var registered = [];

function borders(key) {
    var value = readConfig(key, "");
    var list = Array.isArray(value) ? value : String(value).split(",");
    var result = [];
    for (var i = 0; i < list.length; ++i) {
        var border = parseInt(list[i], 10);
        // 0..7 are the screen edges and corners, 8 and up mean none
        if (!isNaN(border) && border >= 0 && border < 8)
            result.push(border);
    }
    return result;
}

function update() {
    for (var i = 0; i < registered.length; ++i)
        unregisterScreenEdge(registered[i]);
    registered = [];

    for (var key in actions) {
        var list = borders(key);
        for (var j = 0; j < list.length; ++j) {
            if (registered.indexOf(list[j]) >= 0)
                continue;
            registerScreenEdge(list[j], actions[key]);
            registered.push(list[j]);
        }
    }
}

// lingmo-settings changes the corners and asks KWin to reconfigure
options.configChanged.connect(update);
update();
