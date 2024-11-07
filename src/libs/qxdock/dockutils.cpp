/**
 * Copyleft (C) 2024 maminjie <canpool@163.com>
 * SPDX-License-Identifier: MulanPSL-2.0
**/

#include "dockutils.h"
#include "dockmanager.h"
#include "docksplitter.h"

#include <QPainter>

QX_DOCK_BEGIN_NAMESPACE

namespace internal {

QPixmap createTransparentPixmap(const QPixmap &source, qreal opacity)
{
    QPixmap transparentPixmap(source.size());
    transparentPixmap.fill(Qt::transparent);
    QPainter p(&transparentPixmap);
    p.setOpacity(opacity);
    p.drawPixmap(0, 0, source);
    return transparentPixmap;
}

void setButtonIcon(QAbstractButton *b, QStyle::StandardPixmap pixmap, Qx::DockIcon iconId)
{
    // First we try to use custom icons if available
    QIcon Icon = DockManager::iconProvider().customIcon(iconId);
    if (!Icon.isNull()) {
        b->setIcon(Icon);
        return;
    }

#if defined(Q_OS_UNIX) && !defined(Q_OS_MACOS)
    b->setIcon(b->style()->standardIcon(pixmap));
#else
    // The standard icons does not look good on high DPI screens so we create
    // our own "standard" icon here.
    QPixmap normalPixmap = b->style()->standardPixmap(pixmap, 0, b);
    Icon.addPixmap(createTransparentPixmap(normalPixmap, 0.25), QIcon::Disabled);
    Icon.addPixmap(normalPixmap, QIcon::Normal);
    b->setIcon(Icon);
#endif
}

DockInsertParam dockAreaInsertParameters(Qx::DockWidgetArea area)
{
    switch (area) {
    case Qx::TopDockWidgetArea: return DockInsertParam(Qt::Vertical, false);
    case Qx::RightDockWidgetArea: return DockInsertParam(Qt::Horizontal, true);
    case Qx::CenterDockWidgetArea:
    case Qx::BottomDockWidgetArea: return DockInsertParam(Qt::Vertical, true);
    case Qx::LeftDockWidgetArea: return DockInsertParam(Qt::Horizontal, false);
    default: DockInsertParam(Qt::Vertical, false);
    } // switch (area)

    return DockInsertParam(Qt::Vertical, false);
}

void repolishStyle(QWidget *w, RepolishChildOptions options)
{
    if (!w) {
        return;
    }
    w->style()->unpolish(w);
    w->style()->polish(w);

    if (RepolishIgnoreChildren == options) {
        return;
    }

    QList<QWidget*> childrens = w->findChildren<QWidget *>(QString(),
        (RepolishDirectChildren == options) ? Qt::FindDirectChildrenOnly : Qt::FindChildrenRecursively);

    for (auto c : childrens) {
        c->style()->unpolish(c);
        c->style()->polish(c);
    }
}

void hideEmptyParentSplitters(DockSplitter *splitter)
{
    while (splitter && splitter->isVisible()) {
        if (!splitter->hasVisibleContent()) {
            splitter->hide();
        }
        splitter = internal::findParent<DockSplitter *>(splitter);
    }
}

} // internal

QX_DOCK_END_NAMESPACE
