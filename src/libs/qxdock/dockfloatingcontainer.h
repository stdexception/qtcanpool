/**
 * Copyleft (C) 2024 maminjie <canpool@163.com>
 * SPDX-License-Identifier: MulanPSL-2.0
**/
#pragma once

#include "qxdock_global.h"
#include "dockfloatingwidget.h"

#include <QWidget>
#define DockFloatingContainerBase QWidget

QX_DOCK_BEGIN_NAMESPACE

class DockWindow;
class DockPanel;
class DockWidget;
class DockContainer;

class DockFloatingContainerPrivate;

class QX_DOCK_EXPORT DockFloatingContainer : public DockFloatingContainerBase
                                           , public DockFloatingWidget
{
    Q_OBJECT
public:
    using Super = DockFloatingContainerBase;
public:
    explicit DockFloatingContainer(DockWindow *window);
    explicit DockFloatingContainer(DockPanel *panel);
    virtual ~DockFloatingContainer();

    bool isClosable() const;

    DockContainer *dockContainer() const;

    DockWidget *topLevelDockWidget() const;
    QList<DockWidget *> dockWidgets() const;

    void finishDropOperation();

private Q_SLOTS:
    void onDockAreasAddedOrRemoved();

protected:
    virtual void startFloating(const QPoint &dragStartMousePos, const QSize &size,
        Qx::DockDragState dragState, QWidget *mouseEventHandler) override;
    virtual void finishDragging() override;
    void moveFloating() override;

    void deleteContent();
    void updateWindowTitle();

protected:
    virtual void closeEvent(QCloseEvent *event) override;
    virtual void hideEvent(QHideEvent *event) override;
    virtual void showEvent(QShowEvent *event) override;

#ifdef Q_OS_WIN
    /**
     * Native event filter for handling WM_MOVING messages on Windows
     */
#if (QT_VERSION < QT_VERSION_CHECK(6, 0, 0))
    virtual bool nativeEvent(const QByteArray &eventType, void *message, long *result) override;
#else
    virtual bool nativeEvent(const QByteArray &eventType, void *message, qintptr *result) override;
#endif
#endif

private:
    QX_DECLARE_PRIVATE(DockFloatingContainer)
    friend class DockWindow;
    friend class DockWidget;
};

QX_DOCK_END_NAMESPACE
