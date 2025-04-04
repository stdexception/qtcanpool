﻿/**
 * Copyleft (C) 2023-2025 maminjie <canpool@163.com>
 * SPDX-License-Identifier: MIT
**/
#pragma once

#include "qxribbon_global.h"
#include <QWidget>

QX_RIBBON_BEGIN_NAMESPACE

class WindowButtonGroupPrivate;

class QX_RIBBON_EXPORT WindowButtonGroup : public QWidget
{
    Q_OBJECT
public:
    explicit WindowButtonGroup(QWidget *parent, Qt::WindowFlags flags = Qt::WindowFlags());
    ~WindowButtonGroup();

    void updateWindowFlags(Qt::WindowFlags flags);

    void setIconScale(qreal scale = 0.5);
    void setWindowStates(Qt::WindowStates s);

    virtual QSize sizeHint() const Q_DECL_OVERRIDE;

    QWidget *widgetForMaximizeButton() const;

    /** default is disabled */
    bool signalIsEnabled() const;

public Q_SLOTS:
    void setSignalEnabled(bool enable);

Q_SIGNALS:
    void buttonMinimizeClicked();
    void buttonMaximzieClicked();
    void buttonCloseClicked();

private:
    QX_DECLARE_PRIVATE(WindowButtonGroup)
};

QX_RIBBON_END_NAMESPACE
