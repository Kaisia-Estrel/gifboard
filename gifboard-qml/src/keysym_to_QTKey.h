#pragma once

#include <Qt>
#include <xkbcommon/xkbcommon.h>

Qt::Key keysym_to_QTKey(xkb_keysym_t keysym);
