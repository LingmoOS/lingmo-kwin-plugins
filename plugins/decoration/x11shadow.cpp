#include "x11shadow.h"

#include <QGuiApplication>
#include <xcb/xcb.h>
#include <X11/Xlib-xcb.h>

static xcb_atom_t internAtom(const char *name, bool only_if_exists)
{
    if (!name || *name == 0)
        return XCB_NONE;

    auto isPlatformX11 = qGuiApp->nativeInterface<QNativeInterface::QX11Application>();
    if (!isPlatformX11)
        return XCB_NONE;


    // 获取QX11Application的实例
    QNativeInterface::QX11Application *x11App = qApp->nativeInterface<QNativeInterface::QX11Application>();

    // 获取Display类型的显示指针
    Display *displayID = x11App->display();

    // 从Display转换为xcb_connection_t类型的连接
    xcb_connection_t *connection = XGetXCBConnection(displayID);

    xcb_intern_atom_cookie_t cookie = xcb_intern_atom(connection, only_if_exists, strlen(name), name);
    xcb_intern_atom_reply_t *reply = xcb_intern_atom_reply(connection, cookie, 0);

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
