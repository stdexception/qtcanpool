﻿#include "mainwindow.h"
#include <QApplication>
#include <QDebug>
#include <QElapsedTimer>
#include <QStyle>
#include <QStyleFactory>

// 重定向qdebug的打印
void log_out_put(QtMsgType type, const QMessageLogContext &context, const QString &msg);

/**
 * @brief 重定向qdebug的打印
 * @param type
 * @param context
 * @param msg
 */
void log_out_put(QtMsgType type, const QMessageLogContext &context, const QString &msg)
{
    QByteArray localMsg = msg.toLocal8Bit();

    switch (type) {
    case QtDebugMsg:
        fprintf(stdout, "[Debug] %s (%s:%u, %s)\n", localMsg.constData(), context.file, context.line, context.function);
        break;
    case QtInfoMsg:
        fprintf(stdout, "[Info] %s (%s:%u, %s)\n", localMsg.constData(), context.file, context.line, context.function);
        break;
    case QtWarningMsg:
        fprintf(stdout, "[Warning] %s (%s:%u, %s)\n", localMsg.constData(), context.file, context.line,
                context.function);
        break;
    case QtCriticalMsg:
        fprintf(stdout, "[Critical] %s (%s:%u, %s)\n", localMsg.constData(), context.file, context.line,
                context.function);
        break;
    case QtFatalMsg:
        fprintf(stdout, "[Fatal] %s (%s:%u, %s)\n", localMsg.constData(), context.file, context.line, context.function);
        abort();
        break;
    default:
        fprintf(stdout, "[Debug] %s (%s:%u, %s)\n", localMsg.constData(), context.file, context.line, context.function);
        break;
    }
#ifndef QT_NO_DEBUG_OUTPUT
    fflush(stdout);
#endif
}

int main(int argc, char *argv[])
{
#if (QT_VERSION < QT_VERSION_CHECK(6, 0, 0))
#if (QT_VERSION >= QT_VERSION_CHECK(5, 6, 0))
    QApplication::setAttribute(Qt::AA_EnableHighDpiScaling);
#endif
    QApplication::setAttribute(Qt::AA_UseHighDpiPixmaps);
#if (QT_VERSION >= QT_VERSION_CHECK(5, 14, 0))
    QApplication::setHighDpiScaleFactorRoundingPolicy(Qt::HighDpiScaleFactorRoundingPolicy::PassThrough);
#endif
#endif

#if (QT_VERSION >= QT_VERSION_CHECK(6, 7, 0))
#ifdef Q_OS_WINDOWS
    // When tested on Windows11 and Qt6.8.1, the default style is windows11,
    // and the qss of ribbon does not work well, so for compatibility, set the style to windowsvista
    QApplication::setStyle("windowsvista");
    qDebug() << "Current style: " << QApplication::style()->objectName();
    qDebug() << "Supported styles: " << QStyleFactory::keys();
#endif
#endif

    QApplication a(argc, argv);
    qInstallMessageHandler(log_out_put);
    QFont f = a.font();

    f.setFamily("Microsoft YaHei");
    a.setFont(f);

    QElapsedTimer cost;

    cost.start();

    MainWindow w;
    w.showMaximized();

    qDebug() << "window build cost:" << cost.elapsed() << " ms";

    return (a.exec());
}
