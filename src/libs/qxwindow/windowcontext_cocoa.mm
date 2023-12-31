/**
 * Copyright (C) 2023-2024 maminjie <canpool@163.com>
 * SPDX-License-Identifier: Apache-2.0
**/
#include "windowcontext_p.h"

#include <objc/runtime.h>
#include <AppKit/AppKit.h>

#include <Cocoa/Cocoa.h>

#include <QtGui/QGuiApplication>

#include "windowkit_p.h"
#include "systemwindow_p.h"

// https://forgetsou.github.io/2020/11/06/macos%E5%BC%80%E5%8F%91-%E5%85%B3%E9%97%AD-%E6%9C%80%E5%B0%8F%E5%8C%96-%E5%85%A8%E5%B1%8F%E5%B1%85%E4%B8%AD%E5%A4%84%E7%90%86(%E4%BB%BFMac%20QQ)/
// https://nyrra33.com/2019/03/26/changing-titlebars-height/

QX_WINDOW_BEGIN_NAMESPACE

struct NSWindowProxy;

using ProxyList = QHash<WId, NSWindowProxy *>;
Q_GLOBAL_STATIC(ProxyList, g_proxyList);

using ProxyList2 = QHash<NSWindow *, NSWindowProxy *>;
Q_GLOBAL_STATIC(ProxyList2, g_proxyIndexes);

QX_WINDOW_END_NAMESPACE

struct QWK_NSWindowDelegate {
public:
    enum NSEventType {
        WillEnterFullScreen,
        DidEnterFullScreen,
        WillExitFullScreen,
        DidExitFullScreen,
        DidResize,
    };

    virtual ~QWK_NSWindowDelegate() = default;
    virtual void windowEvent(NSEventType eventType) = 0;
};

//
// Objective C++ Begin
//

@interface QWK_NSWindowObserver : NSObject {
}
@end

@implementation QWK_NSWindowObserver

- (id)init {
    self = [super init];
    if (self) {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(windowWillEnterFullScreen:)
                                                     name:NSWindowWillEnterFullScreenNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(windowDidEnterFullScreen:)
                                                     name:NSWindowDidEnterFullScreenNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(windowWillExitFullScreen:)
                                                     name:NSWindowWillExitFullScreenNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(windowDidExitFullScreen:)
                                                     name:NSWindowDidExitFullScreenNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(windowDidResize:)
                                                     name:NSWindowDidResizeNotification
                                                   object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [super dealloc];
}

- (void)windowWillEnterFullScreen:(NSNotification *)notification {
    auto nswindow = reinterpret_cast<NSWindow *>(notification.object);
    if (auto proxy = QWK::g_proxyIndexes->value(nswindow)) {
        reinterpret_cast<QWK_NSWindowDelegate *>(proxy)->windowEvent(
            QWK_NSWindowDelegate::WillEnterFullScreen);
    }
}

- (void)windowDidEnterFullScreen:(NSNotification *)notification {
    auto nswindow = reinterpret_cast<NSWindow *>(notification.object);
    if (auto proxy = QWK::g_proxyIndexes->value(nswindow)) {
        reinterpret_cast<QWK_NSWindowDelegate *>(proxy)->windowEvent(
            QWK_NSWindowDelegate::DidEnterFullScreen);
    }
}

- (void)windowWillExitFullScreen:(NSNotification *)notification {
    auto nswindow = reinterpret_cast<NSWindow *>(notification.object);
    if (auto proxy = QWK::g_proxyIndexes->value(nswindow)) {
        reinterpret_cast<QWK_NSWindowDelegate *>(proxy)->windowEvent(
            QWK_NSWindowDelegate::WillExitFullScreen);
    }
}

- (void)windowDidExitFullScreen:(NSNotification *)notification {
    auto nswindow = reinterpret_cast<NSWindow *>(notification.object);
    if (auto proxy = QWK::g_proxyIndexes->value(nswindow)) {
        reinterpret_cast<QWK_NSWindowDelegate *>(proxy)->windowEvent(
            QWK_NSWindowDelegate::DidExitFullScreen);
    }
}

- (void)windowDidResize:(NSNotification *)notification {
    auto nswindow = reinterpret_cast<NSWindow *>(notification.object);
    if (auto proxy = QWK::g_proxyIndexes->value(nswindow)) {
        reinterpret_cast<QWK_NSWindowDelegate *>(proxy)->windowEvent(
            QWK_NSWindowDelegate::DidResize);
    }
}

@end

//
// Objective C++ End
//

QX_WINDOW_BEGIN_NAMESPACE

struct NSWindowProxy : public QWK_NSWindowDelegate {
    enum class BlurMode {
        Dark,
        Light,
        None,
    };

    NSWindowProxy(NSWindow *macWindow) {
        nswindow = macWindow;
        g_proxyIndexes->insert(nswindow, this);
    }

    ~NSWindowProxy() override {
        g_proxyIndexes->remove(nswindow);
    }

    // Delegate
    void windowEvent(NSEventType eventType) override {
        switch (eventType) {
            case WillExitFullScreen: {
                if (!screenRectCallback || !systemButtonVisible)
                    return;

                // The system buttons will stuck at their default positions when the
                // exit-fullscreen animation is running, we need to hide them until the
                // animation finishes
                for (const auto &button : systemButtons()) {
                    button.hidden = true;
                }
                break;
            }

            case DidExitFullScreen: {
                if (!screenRectCallback || !systemButtonVisible)
                    return;

                for (const auto &button : systemButtons()) {
                    button.hidden = false;
                }
                updateSystemButtonRect();
                break;
            }

            case DidResize: {
                if (!screenRectCallback || !systemButtonVisible) {
                    return;
                }
                updateSystemButtonRect();
                break;
            }

            default:
                break;
        }
    }

    // System buttons visibility
    void setSystemButtonVisible(bool visible) {
        systemButtonVisible = visible;
        for (const auto &button : systemButtons()) {
            button.hidden = !visible;
        }

        if (!screenRectCallback || !visible) {
            return;
        }
        updateSystemButtonRect();
    }

    // System buttons area
    void setScreenRectCallback(const ScreenRectCallback &callback) {
        screenRectCallback = callback;

        if (!callback || !systemButtonVisible) {
            return;
        }
        updateSystemButtonRect();
    }

    void updateSystemButtonRect() {
        const auto &buttons = systemButtons();
        const auto &leftButton = buttons[0];
        const auto &midButton = buttons[1];
        const auto &rightButton = buttons[2];

        auto titlebar = rightButton.superview;
        int titlebarHeight = titlebar.frame.size.height;

        auto spacing = midButton.frame.origin.x - leftButton.frame.origin.x;
        auto width = midButton.frame.size.width;
        auto height = midButton.frame.size.height;

        auto viewSize =
            nswindow.contentView ? nswindow.contentView.frame.size : nswindow.frame.size;
        QPoint center = screenRectCallback(QSize(viewSize.width, titlebarHeight)).center();

        // The origin of the NSWindow coordinate system is in the lower left corner, we
        // do the necessary transformations
        center.ry() = titlebarHeight - center.y();

        // Mid button
        NSPoint centerOrigin = {
            center.x() - width / 2,
            center.y() - height / 2,
        };
        [midButton setFrameOrigin:centerOrigin];

        // Left button
        NSPoint leftOrigin = {
            centerOrigin.x - spacing,
            centerOrigin.y,
        };
        [leftButton setFrameOrigin:leftOrigin];

        // Right button
        NSPoint rightOrigin = {
            centerOrigin.x + spacing,
            centerOrigin.y,
        };
        [rightButton setFrameOrigin:rightOrigin];
    }

    inline std::array<NSButton *, 3> systemButtons() {
        NSButton *closeBtn = [nswindow standardWindowButton:NSWindowCloseButton];
        NSButton *minimizeBtn = [nswindow standardWindowButton:NSWindowMiniaturizeButton];
        NSButton *zoomBtn = [nswindow standardWindowButton:NSWindowZoomButton];
        return {closeBtn, minimizeBtn, zoomBtn};
    }

    inline int titleBarHeight() const {
        NSButton *closeBtn = [nswindow standardWindowButton:NSWindowCloseButton];
        return closeBtn.superview.frame.size.height;
    }

    // Blur effect
    bool setBlurEffect(BlurMode mode) {
        static Class visualEffectViewClass = NSClassFromString(@"NSVisualEffectView");
        if (!visualEffectViewClass)
            return false;

        NSVisualEffectView *effectView = nil;
        NSView *const view = [nswindow contentView];
        for (NSView *subview in [[view superview] subviews]) {
            if ([subview isKindOfClass:visualEffectViewClass]) {
                effectView = reinterpret_cast<NSVisualEffectView *>(subview);
            }
        }
        if (effectView == nil) {
            return false;
        }

        static const auto originalMaterial = effectView.material;
        static const auto originalBlendingMode = effectView.blendingMode;
        static const auto originalState = effectView.state;

        if (mode == BlurMode::None) {
            effectView.material = originalMaterial;
            effectView.blendingMode = originalBlendingMode;
            effectView.state = originalState;
            effectView.appearance = nil;
        } else {
            effectView.material = NSVisualEffectMaterialUnderWindowBackground;
            effectView.blendingMode = NSVisualEffectBlendingModeBehindWindow;
            effectView.state = NSVisualEffectStateFollowsWindowActiveState;

            if (mode == BlurMode::Dark) {
                effectView.appearance =
                    [NSAppearance appearanceNamed:@"NSAppearanceNameVibrantDark"];
            } else {
                effectView.appearance =
                    [NSAppearance appearanceNamed:@"NSAppearanceNameVibrantLight"];
            }
        }
        return true;
    }

    // System title bar
    void setSystemTitleBarVisible(const bool visible) {
        NSView *nsview = [nswindow contentView];
        if (!nsview) {
            return;
        }

        nsview.wantsLayer = YES;
        nswindow.styleMask |= NSWindowStyleMaskResizable;
        if (visible) {
            nswindow.styleMask &= ~NSWindowStyleMaskFullSizeContentView;
        } else {
            nswindow.styleMask |= NSWindowStyleMaskFullSizeContentView;
        }
        nswindow.titlebarAppearsTransparent = (visible ? NO : YES);
        nswindow.titleVisibility = (visible ? NSWindowTitleVisible : NSWindowTitleHidden);
        nswindow.hasShadow = YES;
        // nswindow.showsToolbarButton = NO;
        nswindow.movableByWindowBackground = NO;
        nswindow.movable = NO; // This line causes the window in the wrong position when
                                // become fullscreen.
        //  For some unknown reason, we don't need the following hack in Qt versions below or
        //  equal to 6.2.4.
#if (QT_VERSION > QT_VERSION_CHECK(6, 2, 4))
        [nswindow standardWindowButton:NSWindowCloseButton].hidden = (visible ? NO : YES);
        [nswindow standardWindowButton:NSWindowMiniaturizeButton].hidden = (visible ? NO : YES);
        [nswindow standardWindowButton:NSWindowZoomButton].hidden = (visible ? NO : YES);
#endif
    }

    static void replaceImplementations() {
        Method method = class_getInstanceMethod(windowClass, @selector(setStyleMask:));
        oldSetStyleMask = reinterpret_cast<setStyleMaskPtr>(
            method_setImplementation(method, reinterpret_cast<IMP>(setStyleMask)));

        method =
            class_getInstanceMethod(windowClass, @selector(setTitlebarAppearsTransparent:));
        oldSetTitlebarAppearsTransparent =
            reinterpret_cast<setTitlebarAppearsTransparentPtr>(method_setImplementation(
                method, reinterpret_cast<IMP>(setTitlebarAppearsTransparent)));

#if 0
        method = class_getInstanceMethod(windowClass, @selector(canBecomeKeyWindow));
        oldCanBecomeKeyWindow = reinterpret_cast<canBecomeKeyWindowPtr>(method_setImplementation(method, reinterpret_cast<IMP>(canBecomeKeyWindow)));

        method = class_getInstanceMethod(windowClass, @selector(canBecomeMainWindow));
        oldCanBecomeMainWindow = reinterpret_cast<canBecomeMainWindowPtr>(method_setImplementation(method, reinterpret_cast<IMP>(canBecomeMainWindow)));
#endif

        method = class_getInstanceMethod(windowClass, @selector(sendEvent:));
        oldSendEvent = reinterpret_cast<sendEventPtr>(
            method_setImplementation(method, reinterpret_cast<IMP>(sendEvent)));

        // Alloc
        windowObserver = [[QWK_NSWindowObserver alloc] init];
    }

    static void restoreImplementations() {
        Method method = class_getInstanceMethod(windowClass, @selector(setStyleMask:));
        method_setImplementation(method, reinterpret_cast<IMP>(oldSetStyleMask));
        oldSetStyleMask = nil;

        method =
            class_getInstanceMethod(windowClass, @selector(setTitlebarAppearsTransparent:));
        method_setImplementation(method,
                                    reinterpret_cast<IMP>(oldSetTitlebarAppearsTransparent));
        oldSetTitlebarAppearsTransparent = nil;

#if 0
        method = class_getInstanceMethod(windowClass, @selector(canBecomeKeyWindow));
        method_setImplementation(method, reinterpret_cast<IMP>(oldCanBecomeKeyWindow));
        oldCanBecomeKeyWindow = nil;

        method = class_getInstanceMethod(windowClass, @selector(canBecomeMainWindow));
        method_setImplementation(method, reinterpret_cast<IMP>(oldCanBecomeMainWindow));
        oldCanBecomeMainWindow = nil;
#endif

        method = class_getInstanceMethod(windowClass, @selector(sendEvent:));
        method_setImplementation(method, reinterpret_cast<IMP>(oldSendEvent));
        oldSendEvent = nil;

        // Delete
        [windowObserver release];
        windowObserver = nil;
    }

    static inline const Class windowClass = [NSWindow class];

protected:
    static BOOL canBecomeKeyWindow(id obj, SEL sel) {
        if (g_proxyIndexes->contains(reinterpret_cast<NSWindow *>(obj))) {
            return YES;
        }

        if (oldCanBecomeKeyWindow) {
            return oldCanBecomeKeyWindow(obj, sel);
        }

        return YES;
    }

    static BOOL canBecomeMainWindow(id obj, SEL sel) {
        if (g_proxyIndexes->contains(reinterpret_cast<NSWindow *>(obj))) {
            return YES;
        }

        if (oldCanBecomeMainWindow) {
            return oldCanBecomeMainWindow(obj, sel);
        }

        return YES;
    }

    static void setStyleMask(id obj, SEL sel, NSWindowStyleMask styleMask) {
        if (g_proxyIndexes->contains(reinterpret_cast<NSWindow *>(obj))) {
            styleMask |= NSWindowStyleMaskFullSizeContentView;
        }

        if (oldSetStyleMask) {
            oldSetStyleMask(obj, sel, styleMask);
        }
    }

    static void setTitlebarAppearsTransparent(id obj, SEL sel, BOOL transparent) {
        if (g_proxyIndexes->contains(reinterpret_cast<NSWindow *>(obj))) {
            transparent = YES;
        }

        if (oldSetTitlebarAppearsTransparent) {
            oldSetTitlebarAppearsTransparent(obj, sel, transparent);
        }
    }

    static void sendEvent(id obj, SEL sel, NSEvent *event) {
        if (oldSendEvent) {
            oldSendEvent(obj, sel, event);
        }

#if 0
        const auto nswindow = reinterpret_cast<NSWindow *>(obj);
        const auto it = instances.find(nswindow);
        if (it == instances.end()) {
            return;
        }

        NSWindowProxy *proxy = it.value();
        if (event.type == NSEventTypeLeftMouseDown) {
            proxy->lastMouseDownEvent = event;
            QCoreApplication::processEvents();
            proxy->lastMouseDownEvent = nil;
        }
#endif
    }

private:
    Q_DISABLE_COPY(NSWindowProxy)

    NSWindow *nswindow = nil;

    bool systemButtonVisible = true;
    ScreenRectCallback screenRectCallback;

    static inline QWK_NSWindowObserver *windowObserver = nil;

    // NSEvent *lastMouseDownEvent = nil;

    using setStyleMaskPtr = void (*)(id, SEL, NSWindowStyleMask);
    static inline setStyleMaskPtr oldSetStyleMask = nil;

    using setTitlebarAppearsTransparentPtr = void (*)(id, SEL, BOOL);
    static inline setTitlebarAppearsTransparentPtr oldSetTitlebarAppearsTransparent = nil;

    using canBecomeKeyWindowPtr = BOOL (*)(id, SEL);
    static inline canBecomeKeyWindowPtr oldCanBecomeKeyWindow = nil;

    using canBecomeMainWindowPtr = BOOL (*)(id, SEL);
    static inline canBecomeMainWindowPtr oldCanBecomeMainWindow = nil;

    using sendEventPtr = void (*)(id, SEL, NSEvent *);
    static inline sendEventPtr oldSendEvent = nil;
};

static inline NSWindow *mac_getNSWindow(const WId windowId) {
    const auto nsview = reinterpret_cast<NSView *>(windowId);
    return [nsview window];
}

static inline NSWindowProxy *ensureWindowProxy(const WId windowId) {
    if (g_proxyList->isEmpty()) {
        NSWindowProxy::replaceImplementations();
    }

    auto it = g_proxyList->find(windowId);
    if (it == g_proxyList->end()) {
        NSWindow *nswindow = mac_getNSWindow(windowId);
        const auto proxy = new NSWindowProxy(nswindow);
        it = g_proxyList->insert(windowId, proxy);
    }
    return it.value();
}

static inline void releaseWindowProxy(const WId windowId) {
    if (auto proxy = g_proxyList->take(windowId)) {
        proxy->setSystemTitleBarVisible(true);
        delete proxy;
    } else {
        return;
    }

    if (g_proxyList->isEmpty()) {
        NSWindowProxy::restoreImplementations();
    }
}

class CocoaWindowEventFilter : public WindowSharedEventFilter {
public:
    explicit CocoaWindowEventFilter(WindowContext *context);
    ~CocoaWindowEventFilter() override;

    enum WindowStatus {
        Idle,
        WaitingRelease,
        PreparingMove,
        Moving,
    };

protected:
    bool sharedEventFilter(QObject *object, QEvent *event) override;

private:
    WindowContext *m_context;
    bool m_cursorShapeChanged;
    WindowStatus m_windowStatus;
};

CocoaWindowEventFilter::CocoaWindowEventFilter(WindowContext *context)
    : m_context(context), m_cursorShapeChanged(false), m_windowStatus(Idle) {
    m_context->installSharedEventFilter(this);
}

CocoaWindowEventFilter::~CocoaWindowEventFilter() = default;

bool CocoaWindowEventFilter::sharedEventFilter(QObject *obj, QEvent *event) {
    Q_UNUSED(obj)

    auto type = event->type();
    if (type < QEvent::MouseButtonPress || type > QEvent::MouseMove) {
        return false;
    }
    auto host = m_context->host();
    auto window = m_context->window();
    auto delegate = m_context->delegate();
    auto me = static_cast<const QMouseEvent *>(event);

    QPoint scenePos = getMouseEventScenePos(me);
    QPoint globalPos = getMouseEventGlobalPos(me);

    bool inTitleBar = m_context->isInTitleBarDraggableArea(scenePos);
    switch (type) {
        case QEvent::MouseButtonPress: {
            switch (me->button()) {
                case Qt::LeftButton: {
                    if (inTitleBar) {
                        // If we call startSystemMove() now but release the mouse without actual
                        // movement, there will be no MouseReleaseEvent, so we defer it when the
                        // mouse is actually moving for the first time
                        m_windowStatus = PreparingMove;
                        event->accept();
                        return true;
                    }
                    break;
                }
                case Qt::RightButton: {
                    m_context->showSystemMenu(globalPos);
                    break;
                }
                default:
                    break;
            }
            m_windowStatus = WaitingRelease;
            break;
        }

        case QEvent::MouseButtonRelease: {
            switch (m_windowStatus) {
                case PreparingMove:
                case Moving: {
                    m_windowStatus = Idle;
                    event->accept();
                    return true;
                }
                case WaitingRelease: {
                    m_windowStatus = Idle;
                    break;
                }
                default: {
                    if (inTitleBar) {
                        event->accept();
                        return true;
                    }
                    break;
                }
            }
            break;
        }

        case QEvent::MouseMove: {
            switch (m_windowStatus) {
                case Moving: {
                    return true;
                }
                case PreparingMove: {
                    m_windowStatus = Moving;
                    startSystemMove(window);
                    event->accept();
                    return true;
                }
                default:
                    break;
            }
            break;
        }

        case QEvent::MouseButtonDblClick: {
            if (me->button() == Qt::LeftButton && inTitleBar &&
                !delegate->isHostSizeFixed(host)) {
                Qt::WindowStates windowState = delegate->getWindowState(host);
                if (!(windowState & Qt::WindowFullScreen)) {
                    if (windowState & Qt::WindowMaximized) {
                        delegate->setWindowState(host, windowState & ~Qt::WindowMaximized);
                    } else {
                        delegate->setWindowState(host, windowState | Qt::WindowMaximized);
                    }
                    event->accept();
                    return true;
                }
            }
            break;
        }

        default:
            break;
    }
    return false;
}

WindowContextCocoa::WindowContextCocoa() : WindowContext() {
    cocoaWindowEventFilter = std::make_unique<CocoaWindowEventFilter>(this);
}

WindowContextCocoa::~WindowContextCocoa() {
    releaseWindowProxy(windowId);
}

QString WindowContextCocoa::key() const {
    return QStringLiteral("cocoa");
}

void WindowContextCocoa::virtual_hook(int id, void *data) {
    switch (id) {
        case SystemButtonAreaChangedHook: {
            ensureWindowProxy(windowId)->setScreenRectCallback(m_systemButtonAreaCallback);
            return;
        }

        default:
            break;
    }
    WindowContext::virtual_hook(id, data);
}

QVariant WindowContextCocoa::windowAttribute(const QString &key) const {
    if (key == QStringLiteral("title-bar-height")) {
        if (!m_windowHandle)
            return 0;
        return ensureWindowProxy(windowId)->titleBarHeight();
    }
    return WindowContext::windowAttribute(key);
}

void WindowContextCocoa::winIdChanged() {
    // If the original window id is valid, remove all resources related
    if (windowId) {
        releaseWindowProxy(windowId);
        windowId = 0;
    }

    if (!m_windowHandle) {
        return;
    }

    // Allocate new resources
    windowId = m_windowHandle->winId();
    ensureWindowProxy(windowId)->setSystemTitleBarVisible(false);
}

bool WindowContextCocoa::windowAttributeChanged(const QString &key, const QVariant &attribute,
                                                const QVariant &oldAttribute) {
    Q_UNUSED(oldAttribute)

    if (key == QStringLiteral("no-system-buttons")) {
        if (attribute.type() != QVariant::Bool)
            return false;
        ensureWindowProxy(windowId)->setSystemButtonVisible(!attribute.toBool());
        return true;
    }

    if (key == QStringLiteral("blur-effect")) {
        auto mode = NSWindowProxy::BlurMode::None;
        if (attribute.type() == QVariant::Bool) {
            if (attribute.toBool()) {
                NSString *osxMode =
                    [[NSUserDefaults standardUserDefaults] stringForKey:@"AppleInterfaceStyle"];
                mode = [osxMode isEqualToString:@"Dark"] ? NSWindowProxy::BlurMode::Dark
                                                            : NSWindowProxy::BlurMode::Light;
            }
        } else if (attribute.type() == QVariant::String) {
            auto value = attribute.toString();
            if (value == QStringLiteral("dark")) {
                mode = NSWindowProxy::BlurMode::Dark;
            } else if (value == QStringLiteral("light")) {
                mode = NSWindowProxy::BlurMode::Light;
            } else if (value == QStringLiteral("none")) {
                // ...
            } else {
                return false;
            }
        } else {
            return false;
        }
        return ensureWindowProxy(windowId)->setBlurEffect(mode);
    }

    return false;
}

QX_WINDOW_END_NAMESPACE
