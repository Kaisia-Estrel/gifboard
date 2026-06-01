#pragma once

#include <QtCore/QMimeData>
#include <QtGui/QClipboard>
#include <QtGui/QGuiApplication>
#include <memory>

using QClipboardMode = QClipboard::Mode;

inline QClipboard *getAppClipboard() { return QGuiApplication::clipboard(); }

inline std::unique_ptr<QMimeData> QMimeData_New() {
  return std::unique_ptr<QMimeData>(new QMimeData);
}
