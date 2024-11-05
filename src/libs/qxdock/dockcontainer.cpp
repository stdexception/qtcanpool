/**
 * Copyleft (C) 2024 maminjie <canpool@163.com>
 * SPDX-License-Identifier: MulanPSL-2.0
 **/

#include "dockcontainer.h"
#include "dockwindow.h"
#include "docksplitter.h"
#include "dockpanel.h"

#include <QGridLayout>

QX_DOCK_BEGIN_NAMESPACE

class DockContainerPrivate
{
public:
    QX_DECLARE_PUBLIC(DockContainer)
public:
    DockContainerPrivate();

    void init();
    void createRootSplitter();

    DockSplitter *newSplitter(Qt::Orientation orientation, QWidget *parent = nullptr);

    DockPanel *addDockWidgetToContainer(Qx::DockWidgetArea area, DockWidget *w);
    DockPanel *addDockWidgetToPanel(Qx::DockWidgetArea area, DockWidget *w, DockPanel *targetPanel, int index = -1);

public:
    DockWindow *m_window = nullptr;
    QGridLayout *m_layout = nullptr;
    DockSplitter *m_rootSplitter = nullptr;
};

DockContainerPrivate::DockContainerPrivate()
{

}

void DockContainerPrivate::init()
{
    Q_Q(DockContainer);

    m_layout = new QGridLayout();
    m_layout->setContentsMargins(0, 0, 0, 0);
    m_layout->setSpacing(0);
    m_layout->setColumnStretch(1, 1);
    m_layout->setRowStretch(1, 1);
    q->setLayout(m_layout);
}

void DockContainerPrivate::createRootSplitter()
{
    if (m_rootSplitter) {
        return;
    }
    m_rootSplitter = newSplitter(Qt::Horizontal);
    // Add it to the center - the 0 and 2 indexes are used for the SideTabBar widgets
    m_layout->addWidget(m_rootSplitter, 1, 1);
}

DockSplitter *DockContainerPrivate::newSplitter(Qt::Orientation orientation, QWidget *parent)
{
    DockSplitter *s = new DockSplitter(orientation, parent);
    s->setChildrenCollapsible(false);
    return s;
}

DockPanel *DockContainerPrivate::addDockWidgetToContainer(Qx::DockWidgetArea area, DockWidget *w)
{
    Q_Q(DockContainer);
    DockPanel *panel = new DockPanel(m_window, q);
    panel->addDockWidget(w);
    return panel;
}

DockPanel *DockContainerPrivate::addDockWidgetToPanel(Qx::DockWidgetArea area, DockWidget *w,
                                                      DockPanel *targetPanel, int index)
{
    return targetPanel;
}

DockContainer::DockContainer(DockWindow *window, QWidget *parent)
    : QWidget(parent)
{
    Q_ASSERT(window);
    QX_INIT_PRIVATE(DockContainer)

    Q_D(DockContainer);
    d->m_window = window;
    d->init();

    if (window != this) {
        d->m_window->registerDockContainer(this);
        createRootSplitter();
    }
}

DockContainer::~DockContainer()
{
    QX_FINI_PRIVATE()
}

DockPanel *DockContainer::addDockWidget(Qx::DockWidgetArea area, DockWidget *w, DockPanel *p, int index)
{
    Q_D(DockContainer);
    w->setDockWindow(d->m_window);

    DockPanel *panel = nullptr;
    if (p) {
        panel = d->addDockWidgetToPanel(area, w, p, index);
    } else {
        panel = d->addDockWidgetToContainer(area, w);
    }
    return panel;
}

void DockContainer::createRootSplitter()
{
    Q_D(DockContainer);
    d->createRootSplitter();
}

QX_DOCK_END_NAMESPACE
