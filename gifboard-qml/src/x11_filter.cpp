#include "src/x11_filter.h"

#include <QQmlApplicationEngine>
#include <QtGui/QKeyEvent>
#include <QtGui/QWindow>
#include <X11/Xlib.h>
#include <cstdint>
#include <iostream>

#include "src/keysym_to_QTKey.h"

#undef KeyPress
#undef KeyRelease

bool X11EventFilter::nativeEventFilter(const QByteArray &eventType,
                                       void *message, qintptr *) {
  if (eventType != "xcb_generic_event_t") {
    return false;
  }
  xcb_generic_event_t *ev = static_cast<xcb_generic_event_t *>(message);
  auto type = ev->response_type & ~0x80;
  switch (type) {
  case XCB_KEY_PRESS: {
    auto *key = reinterpret_cast<xcb_key_press_event_t *>(ev);
    if (m_manager) {
      return m_manager->key_received(key->detail, 0);
    } else {
      qWarning() << "X11Manager not found";
      return false;
    }
  } break;
  case XCB_KEY_RELEASE: {
    auto *key = reinterpret_cast<xcb_key_release_event_t *>(ev);
    if (m_manager) {
      return m_manager->key_received(key->detail, 1);
    } else {
      qWarning() << "X11Manager not found";
      return false;
    }
  }
  default:
    return false;
  }
}

void X11EventFilter::registerManager(X11Manager *m) { this->m_manager = m; }

xcb_connection_t *get_x11_connection() {
  if (auto *x11app =
          qGuiApp->nativeInterface<QNativeInterface::QX11Application>()) {
    xcb_connection_t *conn = x11app->connection();
    return conn;
  }
  return nullptr;
}

static X11EventFilter *filter = new X11EventFilter();

void install_x11_event_filter() { qApp->installNativeEventFilter(filter); }
void delete_x11_event_filter() { delete filter; }

X11EventFilter *get_x11_event_filter() { return filter; }

bool inject_key_event(int32_t type, uint32_t keysym, uint32_t modifiers,
                      const QString &text) {

  QEvent::Type qtype = type ? QEvent::Type::KeyPress : QEvent::Type::KeyRelease;
  Qt::KeyboardModifiers qmodifiers =
      static_cast<Qt::KeyboardModifiers>(modifiers);

  QObject *receiver = qApp->focusObject();
  if (!receiver) {
    auto windows = qApp->topLevelWindows();

    if (!windows.empty()) {
      receiver = windows.first();
    }
  }

  if (!receiver) {
    qWarning() << "Cannot inject key event: No Window available.";
    return false;
  }

  Qt::Key key = keysym_to_QTKey(keysym);
  QKeyEvent *event = new QKeyEvent(qtype, key, qmodifiers, text);
  qGuiApp->postEvent(receiver, event);
  return true;
}
