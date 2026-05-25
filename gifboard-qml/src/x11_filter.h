#include "src/x11_manager.cxxqt.h"

#ifndef X11_FILTER_H
#define X11_FILTER_H

// x11_filter is also included in x11_manager.rs and thus in
// 'src/x11_manager.cxxqt.h'. This whole thing is a horrible recursive include,
// I hate C++ headers.

#include <QtCore/QAbstractNativeEventFilter>
#include <QtGui/QGuiApplication>
#include <QtQml/QQmlEngine>
#include <xcb/xcb.h>
#include <xcb/xproto.h>

class X11EventFilter : public QAbstractNativeEventFilter {
public:
  X11Manager *m_manager = nullptr;

  Q_INVOKABLE void registerManager(X11Manager *m);
  bool nativeEventFilter(const QByteArray &eventType, void *message,
                         qintptr *) override;
};

xcb_connection_t *get_x11_connection();
void install_x11_event_filter();
void delete_x11_event_filter();
X11EventFilter *get_x11_event_filter();

bool inject_key_event(int32_t type, uint32_t keysym, uint32_t modifiers,
                      const QString &text);
#endif
