/**
 * Copyleft (C) 2024 maminjie <canpool@163.com>
 * SPDX-License-Identifier: MulanPSL-2.0
 **/
#pragma once

#include "qxdock_global.h"
#include <QWidget>

QX_DOCK_BEGIN_NAMESPACE

class DockWindow;
class DockContainer;
class DockPanel;
class DockTab;

class DockWidgetPrivate;

class QX_DOCK_EXPORT DockWidget : public QWidget
{
    Q_OBJECT
public:
    enum DockWidgetFeature {
        DockWidgetClosable = 0x001,
        DockWidgetMovable = 0x002,
        DockWidgetFloatable = 0x004,
        NoTab = 0x080,
        DefaultDockWidgetFeatures = DockWidgetClosable | DockWidgetMovable | DockWidgetFloatable,
        NoDockWidgetFeatures = 0x000
    };
    Q_DECLARE_FLAGS(DockWidgetFeatures, DockWidgetFeature)

    enum ToggleViewActionMode {
        ActionModeToggle,
        ActionModeShow
    };

public:
    explicit DockWidget(const QString &title, QWidget *parent = nullptr);
    ~DockWidget();

    DockTab *tab() const;

    DockWidgetFeatures features() const;

    DockContainer *dockContainer() const;

    bool isClosed() const;

    QAction *toggleViewAction() const;
    void setToggleViewAction(QAction *action);
    void setToggleViewActionMode(ToggleViewActionMode mode);
    void setToggleViewActionChecked(bool checked);

    virtual QList<QAction *> titleBarActions() const;

public Q_SLOTS:
    void toggleView(bool open = true);

Q_SIGNALS:
    void viewToggled(bool open);
    void closed();

protected:
    void setDockWindow(DockWindow *window);
    void setDockPanel(DockPanel *panel);
    void setClosedState(bool closed);
    void toggleViewInternal(bool open);

private:
    QX_DECLARE_PRIVATE(DockWidget)
    friend class DockContainer;
    friend class DockPanel;
};

QX_DOCK_END_NAMESPACE
