/*
 * Copyright (C) 2020 PandaOS Team.
 *
 * Author:     rekols <rekols@foxmail.com>
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

#include "button.h"
#include "decoration.h"
#include "helper.h"

#include <KDecoration3/DecoratedWindow>
#include <KDecoration3/Decoration>

#include <QPainter>
#include <QPainterPath>

Button::Button(KDecoration3::DecorationButtonType type, const QPointer<KDecoration3::Decoration> &decoration, QObject *parent)
    : KDecoration3::DecorationButton(type, decoration, parent)
{
#if KDECORATION_VERSION <= QT_VERSION_CHECK(5, 27, 12)
    auto c = decoration->window().toStrongRef().data();
#else
    auto c = decoration->window();
#endif 

    // The symbols show on every button of the group while any of them is hovered
    connect(this, &KDecoration3::DecorationButton::hoveredChanged, this, [this] {
        if (this->decoration())
            this->decoration()->update();
    });

    switch (type) {
    case KDecoration3::DecorationButtonType::Menu:
        break;
    case KDecoration3::DecorationButtonType::Minimize:
        setVisible(c->isMinimizeable());
        connect(c, &KDecoration3::DecoratedWindow::minimizeableChanged, this, &Button::setVisible);
        break;
    case KDecoration3::DecorationButtonType::Maximize:
        setVisible(c->isMaximizeable());
        connect(c, &KDecoration3::DecoratedWindow::maximizeableChanged, this, &Button::setVisible);
        break;
    case KDecoration3::DecorationButtonType::Close:
        setVisible(c->isCloseable());
        connect(c, &KDecoration3::DecoratedWindow::closeableChanged, this, &Button::setVisible);
        break;
    default:
        setVisible(false);
        break;
    }
}

KDecoration3::DecorationButton *Button::create(KDecoration3::DecorationButtonType type, KDecoration3::Decoration *decoration, QObject *parent)
{
    return new Button(type, decoration, parent);
}

void Button::paint(QPainter *painter, const QRectF &repaintArea)
{
    Q_UNUSED(repaintArea)

    Lingmo::Decoration *decoration = qobject_cast<Lingmo::Decoration *>(this->decoration());

    if (!decoration)
        return;

#if KDECORATION_VERSION <= QT_VERSION_CHECK(5, 27, 12)
    auto c = decoration->window().toStrongRef().data();
#else
    auto c = decoration->window();
#endif
    const QRect &rect = geometry().toRect();

    painter->save();
    painter->setRenderHints(QPainter::Antialiasing, true);

    // Lingmo window controls: coloured circles (grey on an inactive window) that
    // show their symbol while the pointer is over the group
    const qreal dpr = decoration->devicePixelRatio();
    const qreal dotSize = Lingmo::Decoration::buttonDiameter * dpr;
    QRectF dot(0, 0, dotSize, dotSize);
    dot.moveCenter(QRectF(rect).center());

    const bool groupHovered = decoration->isButtonGroupHovered(this);
    const bool dark = decoration->darkMode();
    const bool active = c->isActive();

    QColor accent;
    switch (type()) {
    case KDecoration3::DecorationButtonType::Close:
        accent = QColor(0xF2, 0x55, 0x5A);   // coral
        break;
    case KDecoration3::DecorationButtonType::Minimize:
        accent = QColor(0xF5, 0xA5, 0x24);   // amber
        break;
    case KDecoration3::DecorationButtonType::Maximize:
        accent = QColor(0x2F, 0x7C, 0xF6);   // Lingmo blue
        break;
    case KDecoration3::DecorationButtonType::Menu:
        c->icon().paint(painter, rect);
        painter->restore();
        return;
    default:
        painter->restore();
        return;
    }

    const bool coloured = active || groupHovered;
    const QColor fill = !coloured ? (dark ? QColor(0x4A, 0x4B, 0x57) : QColor(0xD4, 0xD5, 0xDA))
                      : isPressed() ? accent.darker(125)
                      : accent;

    // Fill with a hairline ring a shade darker, so light circles keep an edge on
    // a white title bar
    painter->setPen(QPen(dark ? fill.lighter(115) : fill.darker(112), 0.8 * dpr));
    painter->setBrush(fill);
    painter->drawEllipse(dot.adjusted(0.4 * dpr, 0.4 * dpr, -0.4 * dpr, -0.4 * dpr));

    if (!groupHovered) {
        painter->restore();
        return;
    }

    // Symbols: dark ink on the colour, like the traffic lights people know
    const QColor ink = QColor(0, 0, 0, isPressed() ? 170 : 140);
    QPen pen(ink, 1.4 * dpr, Qt::SolidLine, Qt::RoundCap, Qt::RoundJoin);
    painter->setPen(pen);
    painter->setBrush(Qt::NoBrush);
    const QPointF ctr = dot.center();
    const qreal h = 3.4 * dpr;   // half glyph size

    switch (type()) {
    case KDecoration3::DecorationButtonType::Close:
        painter->drawLine(QPointF(ctr.x() - h, ctr.y() - h), QPointF(ctr.x() + h, ctr.y() + h));
        painter->drawLine(QPointF(ctr.x() + h, ctr.y() - h), QPointF(ctr.x() - h, ctr.y() + h));
        break;
    case KDecoration3::DecorationButtonType::Minimize:
        painter->drawLine(QPointF(ctr.x() - h - 0.5 * dpr, ctr.y()), QPointF(ctr.x() + h + 0.5 * dpr, ctr.y()));
        break;
    case KDecoration3::DecorationButtonType::Maximize: {
        // zoom: two triangles pointing out; restore: pointing in
        painter->setPen(Qt::NoPen);
        painter->setBrush(ink);
        const qreal a = 3.8 * dpr;   // triangle leg
        const qreal g = isChecked() ? 0.6 * dpr : 1.1 * dpr;   // gap along the diagonal
        QPolygonF topRight, bottomLeft;
        if (isChecked()) {
            // restore: corners meet at the centre
            topRight << QPointF(ctr.x() + g, ctr.y() - g) << QPointF(ctr.x() + g + a, ctr.y() - g)
                     << QPointF(ctr.x() + g, ctr.y() - g - a);
            bottomLeft << QPointF(ctr.x() - g, ctr.y() + g) << QPointF(ctr.x() - g - a, ctr.y() + g)
                       << QPointF(ctr.x() - g, ctr.y() + g + a);
        } else {
            const qreal e = a + g;
            topRight << QPointF(ctr.x() + e - a, ctr.y() - e) << QPointF(ctr.x() + e, ctr.y() - e)
                     << QPointF(ctr.x() + e, ctr.y() - e + a);
            bottomLeft << QPointF(ctr.x() - e + a, ctr.y() + e) << QPointF(ctr.x() - e, ctr.y() + e)
                       << QPointF(ctr.x() - e, ctr.y() + e - a);
        }
        painter->drawPolygon(topRight);
        painter->drawPolygon(bottomLeft);
        break;
    }
    default:
        break;
    }

    painter->restore();
}
