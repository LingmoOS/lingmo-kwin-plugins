#include "x11shadow.h"

#include <QGuiApplication>
#include <xcb/xcb.h>

static xcb_atom_t internAtom(const char *name, bool only_if_exists)
{
    if (!name || *name == 0)
        return XCB_NONE;

    if (QGuiApplication::platformName() != "xcb")
        return XCB_NONE;
    
    // 获取 XCB 连接
    auto *connection = static_cast<xcb_connection_t *>(QGuiApplication::platformNativeInterface()->nativeResourceForIntegration("connection"));

    xcb_intern_atom_cookie_t cookie = xcb_intern_atom(connection, only_if_exists, strlen(name), name);
    xcb_intern_atom_reply_t *reply = xcb_intern_atom_reply(connection, cookie, nullptr);

    if (!reply)
        return XCB_NONE;

    xcb_atom_t atom = reply->atom;
    free(reply);

    return atom;
}

X11Shadow::X11Shadow(QObject *parent)
    : QObject(parent)
{
    m_atom_net_wm_shadow = internAtom("_KDE_NET_WM_SHADOW", false);
    m_atom_net_wm_window_type = internAtom("_NET_WM_WINDOW_TYPE", false);
}
