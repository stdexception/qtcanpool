/**
 * Copyleft (C) 2024 maminjie <canpool@163.com>
 * SPDX-License-Identifier: MulanPSL-2.0
 **/
#pragma once

#include "qxdock_global.h"
#include <QWidget>

QX_DOCK_BEGIN_NAMESPACE

class DockWidget;
class DockContainer;
class DockSideTab;

class DockAutoHideContainerPrivate;

class QX_DOCK_EXPORT DockAutoHideContainer : public QWidget
{
    Q_OBJECT
public:
    using Super = QWidget;
public:
    DockAutoHideContainer(DockWidget *w, Qx::DockSideBarArea area, DockContainer *parent);
    virtual ~DockAutoHideContainer();

    DockSideTab *autoHideTab() const;

    void addDockWidget(DockWidget *w);

    DockContainer *dockContainer() const;

    Qx::DockSideBarArea sideBarArea() const;

    void collapseView(bool enable);
    void toggleCollapseState();

    Qt::Orientation orientation() const;

protected:
    virtual bool eventFilter(QObject *watched, QEvent *event) override;
    virtual void resizeEvent(QResizeEvent *event) override;
    virtual void leaveEvent(QEvent *event) override;
    virtual bool event(QEvent *event) override;

    void updateSize();

private:
    QX_DECLARE_PRIVATE(DockAutoHideContainer)
};

QX_DOCK_END_NAMESPACE
