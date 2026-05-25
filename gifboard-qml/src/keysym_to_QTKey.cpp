#include <algorithm>
#include <cstdint>
#include <sstream>
#include <type_traits>

#include <QChar>
#include <QDebug>
#include <Qt>
#include <xkbcommon/xkbcommon-keysyms.h>
#include <xkbcommon/xkbcommon.h>

struct XKBQTPair {
  uint32_t xkb;
  Qt::Key qt;

  bool operator<(const XKBQTPair &other) const { return xkb < other.xkb; }
  bool operator<=(const XKBQTPair &other) const { return xkb <= other.xkb; }
};

template <uint32_t XkbKey, Qt::Key QtKey> struct Xkb2Qt {
  static constexpr XKBQTPair pair = {XkbKey, QtKey};

  template <uint32_t OtherXKbKey, Qt::Key OtherQtKey>
  inline constexpr bool
  operator<(const Xkb2Qt<OtherXKbKey, OtherQtKey> &other) const {
    return pair.xkb < other.pair.xkb;
  }

  template <uint32_t OtherXKbKey, Qt::Key OtherQtKey>
  inline constexpr bool
  operator>=(const Xkb2Qt<OtherXKbKey, OtherQtKey> &other) const {
    return pair.xkb >= other.pair.xkb;
  }
};

struct Nil {};

template <typename X, typename XS> struct Cons {};

template <typename... Ts> struct List;

template <typename X, typename... XS> struct List<X, XS...> {
  using cons_list = Cons<X, typename List<XS...>::cons_list>;
};

template <typename X> struct List<X> {
  using cons_list = Cons<X, Nil>;
};

template <> struct List<> {
  using cons_list = Nil;
};

template <typename List, template <class> class F> struct Filter {
  using type = Filter<typename List::cons_list, F>::type;
};

template <template <class> class F> struct Filter<Nil, F> {
  using type = Nil;
};

template <typename X, typename XS, template <class> class F>
struct Filter<Cons<X, XS>, F> {
  using type =
      std::conditional<F<X>::out, Cons<X, typename Filter<XS, F>::type>,
                       typename Filter<XS, F>::type>::type;
};

template <typename L, typename R> struct GTE {
  static const bool out = L{} >= R{};
};

template <typename L, typename R> struct LT {
  static const bool out = L{} < R{};
};

template <typename L, typename R> struct Append {
  using type = Append<typename L::cons_list, typename R::cons_list>::type;
};

template <typename X, typename XS> struct Append<Nil, Cons<X, XS>> {
  using type = Cons<X, XS>;
};

template <typename X, typename XS, typename R> struct Append<Cons<X, XS>, R> {
  using type = Cons<X, typename Append<XS, R>::type>;
};

template <typename List> struct Qsort {
  using type = Qsort<typename List::cons_list>::type;
};

template <> struct Qsort<Nil> {
  using type = Nil;
};

template <typename X, typename XS> struct Qsort<Cons<X, XS>> {
private:
  template <typename Y> using LTPartial = LT<Y, X>;
  template <typename Y> using GTEPartial = GTE<Y, X>;
  using l = Qsort<typename Filter<XS, LTPartial>::type>::type;
  using r = Qsort<typename Filter<XS, GTEPartial>::type>::type;
  using m = Cons<X, r>;

public:
  using type = Append<l, m>::type;
};
using list =
    List<std::integral_constant<int, 1>, std::integral_constant<int, 7>,
         std::integral_constant<int, 5>, std::integral_constant<int, 2>,
         std::integral_constant<int, 8>, std::integral_constant<int, 9>,
         std::integral_constant<int, 4>>;

template <typename T> struct ToList;

template <> struct ToList<Nil> {
  using type = List<>;
};

template <typename X, typename XS> struct ToList<Cons<X, XS>> {
private:
  using tail_list = ToList<XS>::type;
  template <typename... Ts> static List<X, Ts...> helper(List<Ts...>);

public:
  using type = decltype(helper(std::declval<tail_list>()));
};

using foo = Qsort<list>::type;
using foo_l = ToList<foo>::type;

template <typename ListT> struct ToArray;

template <typename... Args> struct ToArray<List<Args...>> {
  static constexpr std::array<XKBQTPair, sizeof...(Args)> data{Args::pair...};
};

template <typename... Args> struct ToSortedArray {

  using sorted = ToList<typename Qsort<List<Args...>>::type>::type;

  static constexpr auto data = ToArray<sorted>::data;
};

static constexpr const auto KeyTbl = ToSortedArray<
    Xkb2Qt<XKB_KEY_ISO_Left_Tab, Qt::Key_Backtab>,
    Xkb2Qt<XKB_KEY_BackSpace, Qt::Key_Backspace>,
    Xkb2Qt<XKB_KEY_Tab, Qt::Key_Tab>, Xkb2Qt<XKB_KEY_Clear, Qt::Key_Delete>,
    Xkb2Qt<XKB_KEY_Return, Qt::Key_Return>,
    Xkb2Qt<XKB_KEY_Pause, Qt::Key_Pause>,
    Xkb2Qt<XKB_KEY_Sys_Req, Qt::Key_SysReq>,
    Xkb2Qt<XKB_KEY_Escape, Qt::Key_Escape>, Xkb2Qt<XKB_KEY_Home, Qt::Key_Home>,
    Xkb2Qt<XKB_KEY_Left, Qt::Key_Left>, Xkb2Qt<XKB_KEY_Up, Qt::Key_Up>,
    Xkb2Qt<XKB_KEY_Right, Qt::Key_Right>, Xkb2Qt<XKB_KEY_Down, Qt::Key_Down>,
    Xkb2Qt<XKB_KEY_Prior, Qt::Key_PageUp>,
    Xkb2Qt<XKB_KEY_Next, Qt::Key_PageDown>, Xkb2Qt<XKB_KEY_End, Qt::Key_End>,
    Xkb2Qt<XKB_KEY_Print, Qt::Key_Print>,
    Xkb2Qt<XKB_KEY_Insert, Qt::Key_Insert>,
    Xkb2Qt<XKB_KEY_Shift_L, Qt::Key_Shift>,
    Xkb2Qt<XKB_KEY_Shift_R, Qt::Key_Shift>,
    Xkb2Qt<XKB_KEY_Control_L, Qt::Key_Control>,
    Xkb2Qt<XKB_KEY_Control_R, Qt::Key_Control>,
    Xkb2Qt<XKB_KEY_Caps_Lock, Qt::Key_CapsLock>,
    Xkb2Qt<XKB_KEY_Shift_Lock, Qt::Key_Shift>,
    Xkb2Qt<XKB_KEY_Meta_L, Qt::Key_Meta>, Xkb2Qt<XKB_KEY_Meta_R, Qt::Key_Meta>,
    Xkb2Qt<XKB_KEY_Alt_L, Qt::Key_Alt>, Xkb2Qt<XKB_KEY_Alt_R, Qt::Key_Alt>,
    Xkb2Qt<XKB_KEY_Num_Lock, Qt::Key_NumLock>,
    Xkb2Qt<XKB_KEY_Scroll_Lock, Qt::Key_ScrollLock>,
    Xkb2Qt<XKB_KEY_Super_L, Qt::Key_Super_L>,
    Xkb2Qt<XKB_KEY_Super_R, Qt::Key_Super_R>,
    Xkb2Qt<XKB_KEY_Delete, Qt::Key_Delete>,
    Xkb2Qt<0x1005FF60, Qt::Key_SysReq>, // hardcoded Sun SysReq
    Xkb2Qt<0x1007ff00, Qt::Key_SysReq>, // hardcoded X386 SysReq
    Xkb2Qt<XKB_KEY_Menu, Qt::Key_Menu>,
    Xkb2Qt<XKB_KEY_Hyper_L, Qt::Key_Hyper_L>,
    Xkb2Qt<XKB_KEY_Hyper_R, Qt::Key_Hyper_R>,
    Xkb2Qt<XKB_KEY_Help, Qt::Key_Help>,
    Xkb2Qt<0x1000FF74, Qt::Key_Backtab>, // hardcoded HP backtab
    Xkb2Qt<0x1005FF10, Qt::Key_F11>,     // hardcoded Sun F36
    Xkb2Qt<0x1005FF11, Qt::Key_F12>,     // hardcoded Sun

    // numeric and function keypad keys

    Xkb2Qt<XKB_KEY_KP_Space, Qt::Key_Space>,
    Xkb2Qt<XKB_KEY_KP_Tab, Qt::Key_Tab>,
    Xkb2Qt<XKB_KEY_KP_Enter, Qt::Key_Enter>,
    Xkb2Qt<XKB_KEY_KP_Home, Qt::Key_Home>,
    Xkb2Qt<XKB_KEY_KP_Left, Qt::Key_Left>, Xkb2Qt<XKB_KEY_KP_Up, Qt::Key_Up>,
    Xkb2Qt<XKB_KEY_KP_Right, Qt::Key_Right>,
    Xkb2Qt<XKB_KEY_KP_Down, Qt::Key_Down>,
    Xkb2Qt<XKB_KEY_KP_Prior, Qt::Key_PageUp>,
    Xkb2Qt<XKB_KEY_KP_Next, Qt::Key_PageDown>,
    Xkb2Qt<XKB_KEY_KP_End, Qt::Key_End>,
    Xkb2Qt<XKB_KEY_KP_Begin, Qt::Key_Clear>,
    Xkb2Qt<XKB_KEY_KP_Insert, Qt::Key_Insert>,
    Xkb2Qt<XKB_KEY_KP_Delete, Qt::Key_Delete>,
    Xkb2Qt<XKB_KEY_KP_Equal, Qt::Key_Equal>,
    Xkb2Qt<XKB_KEY_KP_Multiply, Qt::Key_Asterisk>,
    Xkb2Qt<XKB_KEY_KP_Add, Qt::Key_Plus>,
    Xkb2Qt<XKB_KEY_KP_Separator, Qt::Key_Comma>,
    Xkb2Qt<XKB_KEY_KP_Subtract, Qt::Key_Minus>,
    Xkb2Qt<XKB_KEY_KP_Decimal, Qt::Key_Period>,
    Xkb2Qt<XKB_KEY_KP_Divide, Qt::Key_Slash>,

    // special non-XF86 function keys

    Xkb2Qt<XKB_KEY_Undo, Qt::Key_Undo>, Xkb2Qt<XKB_KEY_Redo, Qt::Key_Redo>,
    Xkb2Qt<XKB_KEY_Find, Qt::Key_Find>, Xkb2Qt<XKB_KEY_Cancel, Qt::Key_Cancel>,

    // International input method support keys

    // International & multi-key character composition
    Xkb2Qt<XKB_KEY_ISO_Level3_Shift, Qt::Key_AltGr>,
    Xkb2Qt<XKB_KEY_Multi_key, Qt::Key_Multi_key>,
    Xkb2Qt<XKB_KEY_Codeinput, Qt::Key_Codeinput>,
    Xkb2Qt<XKB_KEY_SingleCandidate, Qt::Key_SingleCandidate>,
    Xkb2Qt<XKB_KEY_MultipleCandidate, Qt::Key_MultipleCandidate>,
    Xkb2Qt<XKB_KEY_PreviousCandidate, Qt::Key_PreviousCandidate>,

    // Misc Functions
    Xkb2Qt<XKB_KEY_Mode_switch, Qt::Key_Mode_switch>,
    Xkb2Qt<XKB_KEY_script_switch, Qt::Key_Mode_switch>,

    // Japanese keyboard support
    Xkb2Qt<XKB_KEY_Kanji, Qt::Key_Kanji>,
    Xkb2Qt<XKB_KEY_Muhenkan, Qt::Key_Muhenkan>,
    // Xkb2Qt<XKB_KEY_Henkan_Mode,           Qt::Key_Henkan_Mode>,
    Xkb2Qt<XKB_KEY_Henkan_Mode, Qt::Key_Henkan>,
    Xkb2Qt<XKB_KEY_Henkan, Qt::Key_Henkan>,
    Xkb2Qt<XKB_KEY_Romaji, Qt::Key_Romaji>,
    Xkb2Qt<XKB_KEY_Hiragana, Qt::Key_Hiragana>,
    Xkb2Qt<XKB_KEY_Katakana, Qt::Key_Katakana>,
    Xkb2Qt<XKB_KEY_Hiragana_Katakana, Qt::Key_Hiragana_Katakana>,
    Xkb2Qt<XKB_KEY_Zenkaku, Qt::Key_Zenkaku>,
    Xkb2Qt<XKB_KEY_Hankaku, Qt::Key_Hankaku>,
    Xkb2Qt<XKB_KEY_Zenkaku_Hankaku, Qt::Key_Zenkaku_Hankaku>,
    Xkb2Qt<XKB_KEY_Touroku, Qt::Key_Touroku>,
    Xkb2Qt<XKB_KEY_Massyo, Qt::Key_Massyo>,
    Xkb2Qt<XKB_KEY_Kana_Lock, Qt::Key_Kana_Lock>,
    Xkb2Qt<XKB_KEY_Kana_Shift, Qt::Key_Kana_Shift>,
    Xkb2Qt<XKB_KEY_Eisu_Shift, Qt::Key_Eisu_Shift>,
    Xkb2Qt<XKB_KEY_Eisu_toggle, Qt::Key_Eisu_toggle>,
    // Xkb2Qt<XKB_KEY_Kanji_Bangou,          Qt::Key_Kanji_Bangou>,
    // Xkb2Qt<XKB_KEY_Zen_Koho,              Qt::Key_Zen_Koho>,
    // Xkb2Qt<XKB_KEY_Mae_Koho,              Qt::Key_Mae_Koho>,
    Xkb2Qt<XKB_KEY_Kanji_Bangou, Qt::Key_Codeinput>,
    Xkb2Qt<XKB_KEY_Zen_Koho, Qt::Key_MultipleCandidate>,
    Xkb2Qt<XKB_KEY_Mae_Koho, Qt::Key_PreviousCandidate>,

    // Korean keyboard support
    Xkb2Qt<XKB_KEY_Hangul, Qt::Key_Hangul>,
    Xkb2Qt<XKB_KEY_Hangul_Start, Qt::Key_Hangul_Start>,
    Xkb2Qt<XKB_KEY_Hangul_End, Qt::Key_Hangul_End>,
    Xkb2Qt<XKB_KEY_Hangul_Hanja, Qt::Key_Hangul_Hanja>,
    Xkb2Qt<XKB_KEY_Hangul_Jamo, Qt::Key_Hangul_Jamo>,
    Xkb2Qt<XKB_KEY_Hangul_Romaja, Qt::Key_Hangul_Romaja>,
    // Xkb2Qt<XKB_KEY_Hangul_Codeinput, Qt::Key_Hangul_Codeinput>,
    Xkb2Qt<XKB_KEY_Hangul_Codeinput, Qt::Key_Codeinput>,
    Xkb2Qt<XKB_KEY_Hangul_Jeonja, Qt::Key_Hangul_Jeonja>,
    Xkb2Qt<XKB_KEY_Hangul_Banja, Qt::Key_Hangul_Banja>,
    Xkb2Qt<XKB_KEY_Hangul_PreHanja, Qt::Key_Hangul_PreHanja>,
    Xkb2Qt<XKB_KEY_Hangul_PostHanja, Qt::Key_Hangul_PostHanja>,
    Xkb2Qt<XKB_KEY_Hangul_SingleCandidate, Qt::Key_SingleCandidate>,
    Xkb2Qt<XKB_KEY_Hangul_MultipleCandidate, Qt::Key_MultipleCandidate>,
    Xkb2Qt<XKB_KEY_Hangul_PreviousCandidate, Qt::Key_PreviousCandidate>,
    Xkb2Qt<XKB_KEY_Hangul_Special, Qt::Key_Hangul_Special>,
    // Xkb2Qt<XKB_KEY_Hangul_switch,         Qt::Key_Hangul_switch>,
    Xkb2Qt<XKB_KEY_Hangul_switch, Qt::Key_Mode_switch>,

    // dead keys
    Xkb2Qt<XKB_KEY_dead_grave, Qt::Key_Dead_Grave>,
    Xkb2Qt<XKB_KEY_dead_acute, Qt::Key_Dead_Acute>,
    Xkb2Qt<XKB_KEY_dead_circumflex, Qt::Key_Dead_Circumflex>,
    Xkb2Qt<XKB_KEY_dead_tilde, Qt::Key_Dead_Tilde>,
    Xkb2Qt<XKB_KEY_dead_macron, Qt::Key_Dead_Macron>,
    Xkb2Qt<XKB_KEY_dead_breve, Qt::Key_Dead_Breve>,
    Xkb2Qt<XKB_KEY_dead_abovedot, Qt::Key_Dead_Abovedot>,
    Xkb2Qt<XKB_KEY_dead_diaeresis, Qt::Key_Dead_Diaeresis>,
    Xkb2Qt<XKB_KEY_dead_abovering, Qt::Key_Dead_Abovering>,
    Xkb2Qt<XKB_KEY_dead_doubleacute, Qt::Key_Dead_Doubleacute>,
    Xkb2Qt<XKB_KEY_dead_caron, Qt::Key_Dead_Caron>,
    Xkb2Qt<XKB_KEY_dead_cedilla, Qt::Key_Dead_Cedilla>,
    Xkb2Qt<XKB_KEY_dead_ogonek, Qt::Key_Dead_Ogonek>,
    Xkb2Qt<XKB_KEY_dead_iota, Qt::Key_Dead_Iota>,
    Xkb2Qt<XKB_KEY_dead_voiced_sound, Qt::Key_Dead_Voiced_Sound>,
    Xkb2Qt<XKB_KEY_dead_semivoiced_sound, Qt::Key_Dead_Semivoiced_Sound>,
    Xkb2Qt<XKB_KEY_dead_belowdot, Qt::Key_Dead_Belowdot>,
    Xkb2Qt<XKB_KEY_dead_hook, Qt::Key_Dead_Hook>,
    Xkb2Qt<XKB_KEY_dead_horn, Qt::Key_Dead_Horn>,
    Xkb2Qt<XKB_KEY_dead_stroke, Qt::Key_Dead_Stroke>,
    Xkb2Qt<XKB_KEY_dead_abovecomma, Qt::Key_Dead_Abovecomma>,
    Xkb2Qt<XKB_KEY_dead_abovereversedcomma, Qt::Key_Dead_Abovereversedcomma>,
    Xkb2Qt<XKB_KEY_dead_doublegrave, Qt::Key_Dead_Doublegrave>,
    Xkb2Qt<XKB_KEY_dead_belowring, Qt::Key_Dead_Belowring>,
    Xkb2Qt<XKB_KEY_dead_belowmacron, Qt::Key_Dead_Belowmacron>,
    Xkb2Qt<XKB_KEY_dead_belowcircumflex, Qt::Key_Dead_Belowcircumflex>,
    Xkb2Qt<XKB_KEY_dead_belowtilde, Qt::Key_Dead_Belowtilde>,
    Xkb2Qt<XKB_KEY_dead_belowbreve, Qt::Key_Dead_Belowbreve>,
    Xkb2Qt<XKB_KEY_dead_belowdiaeresis, Qt::Key_Dead_Belowdiaeresis>,
    Xkb2Qt<XKB_KEY_dead_invertedbreve, Qt::Key_Dead_Invertedbreve>,
    Xkb2Qt<XKB_KEY_dead_belowcomma, Qt::Key_Dead_Belowcomma>,
    Xkb2Qt<XKB_KEY_dead_currency, Qt::Key_Dead_Currency>,
    Xkb2Qt<XKB_KEY_dead_a, Qt::Key_Dead_a>,
    Xkb2Qt<XKB_KEY_dead_A, Qt::Key_Dead_A>,
    Xkb2Qt<XKB_KEY_dead_e, Qt::Key_Dead_e>,
    Xkb2Qt<XKB_KEY_dead_E, Qt::Key_Dead_E>,
    Xkb2Qt<XKB_KEY_dead_i, Qt::Key_Dead_i>,
    Xkb2Qt<XKB_KEY_dead_I, Qt::Key_Dead_I>,
    Xkb2Qt<XKB_KEY_dead_o, Qt::Key_Dead_o>,
    Xkb2Qt<XKB_KEY_dead_O, Qt::Key_Dead_O>,
    Xkb2Qt<XKB_KEY_dead_u, Qt::Key_Dead_u>,
    Xkb2Qt<XKB_KEY_dead_U, Qt::Key_Dead_U>,
    Xkb2Qt<XKB_KEY_dead_small_schwa, Qt::Key_Dead_Small_Schwa>,
    Xkb2Qt<XKB_KEY_dead_capital_schwa, Qt::Key_Dead_Capital_Schwa>,
    Xkb2Qt<XKB_KEY_dead_greek, Qt::Key_Dead_Greek>,
/* The following four XKB_KEY_dead keys got removed in libxkbcommon 1.6.0
The define check is kind of version check here. */
#ifdef XKB_KEY_dead_lowline
    Xkb2Qt<XKB_KEY_dead_lowline, Qt::Key_Dead_Lowline>,
    Xkb2Qt<XKB_KEY_dead_aboveverticalline, Qt::Key_Dead_Aboveverticalline>,
    Xkb2Qt<XKB_KEY_dead_belowverticalline, Qt::Key_Dead_Belowverticalline>,
    Xkb2Qt<XKB_KEY_dead_longsolidusoverlay, Qt::Key_Dead_Longsolidusoverlay>,
#endif
    Xkb2Qt<XKB_KEY_XF86Back, Qt::Key_Back>,
    Xkb2Qt<XKB_KEY_XF86Forward, Qt::Key_Forward>,
    Xkb2Qt<XKB_KEY_XF86Stop, Qt::Key_Stop>,
    Xkb2Qt<XKB_KEY_XF86Refresh, Qt::Key_Refresh>,
    Xkb2Qt<XKB_KEY_XF86Favorites, Qt::Key_Favorites>,
    Xkb2Qt<XKB_KEY_XF86AudioMedia, Qt::Key_LaunchMedia>,
    Xkb2Qt<XKB_KEY_XF86OpenURL, Qt::Key_OpenUrl>,
    Xkb2Qt<XKB_KEY_XF86HomePage, Qt::Key_HomePage>,
    Xkb2Qt<XKB_KEY_XF86Search, Qt::Key_Search>,
    Xkb2Qt<XKB_KEY_XF86AudioLowerVolume, Qt::Key_VolumeDown>,
    Xkb2Qt<XKB_KEY_XF86AudioMute, Qt::Key_VolumeMute>,
    Xkb2Qt<XKB_KEY_XF86AudioRaiseVolume, Qt::Key_VolumeUp>,
    Xkb2Qt<XKB_KEY_XF86AudioPlay, Qt::Key_MediaPlay>,
    Xkb2Qt<XKB_KEY_XF86AudioStop, Qt::Key_MediaStop>,
    Xkb2Qt<XKB_KEY_XF86AudioPrev, Qt::Key_MediaPrevious>,
    Xkb2Qt<XKB_KEY_XF86AudioNext, Qt::Key_MediaNext>,
    Xkb2Qt<XKB_KEY_XF86AudioRecord, Qt::Key_MediaRecord>,
    Xkb2Qt<XKB_KEY_XF86AudioPause, Qt::Key_MediaPause>,
    Xkb2Qt<XKB_KEY_XF86Mail, Qt::Key_LaunchMail>,
    Xkb2Qt<XKB_KEY_XF86MyComputer, Qt::Key_LaunchMedia>,
    Xkb2Qt<XKB_KEY_XF86Memo, Qt::Key_Memo>,
    Xkb2Qt<XKB_KEY_XF86ToDoList, Qt::Key_ToDoList>,
    Xkb2Qt<XKB_KEY_XF86Calendar, Qt::Key_Calendar>,
    Xkb2Qt<XKB_KEY_XF86PowerDown, Qt::Key_PowerDown>,
    Xkb2Qt<XKB_KEY_XF86ContrastAdjust, Qt::Key_ContrastAdjust>,
    Xkb2Qt<XKB_KEY_XF86Standby, Qt::Key_Standby>,
    Xkb2Qt<XKB_KEY_XF86MonBrightnessUp, Qt::Key_MonBrightnessUp>,
    Xkb2Qt<XKB_KEY_XF86MonBrightnessDown, Qt::Key_MonBrightnessDown>,
    Xkb2Qt<XKB_KEY_XF86KbdLightOnOff, Qt::Key_KeyboardLightOnOff>,
    Xkb2Qt<XKB_KEY_XF86KbdBrightnessUp, Qt::Key_KeyboardBrightnessUp>,
    Xkb2Qt<XKB_KEY_XF86KbdBrightnessDown, Qt::Key_KeyboardBrightnessDown>,
    Xkb2Qt<XKB_KEY_XF86PowerOff, Qt::Key_PowerOff>,
    Xkb2Qt<XKB_KEY_XF86WakeUp, Qt::Key_WakeUp>,
    Xkb2Qt<XKB_KEY_XF86Eject, Qt::Key_Eject>,
    Xkb2Qt<XKB_KEY_XF86ScreenSaver, Qt::Key_ScreenSaver>,
    Xkb2Qt<XKB_KEY_XF86WWW, Qt::Key_WWW>,
    Xkb2Qt<XKB_KEY_XF86Sleep, Qt::Key_Sleep>,
    Xkb2Qt<XKB_KEY_XF86LightBulb, Qt::Key_LightBulb>,
    Xkb2Qt<XKB_KEY_XF86Shop, Qt::Key_Shop>,
    Xkb2Qt<XKB_KEY_XF86History, Qt::Key_History>,
    Xkb2Qt<XKB_KEY_XF86AddFavorite, Qt::Key_AddFavorite>,
    Xkb2Qt<XKB_KEY_XF86HotLinks, Qt::Key_HotLinks>,
    Xkb2Qt<XKB_KEY_XF86BrightnessAdjust, Qt::Key_BrightnessAdjust>,
    Xkb2Qt<XKB_KEY_XF86Finance, Qt::Key_Finance>,
    Xkb2Qt<XKB_KEY_XF86Community, Qt::Key_Community>,
    Xkb2Qt<XKB_KEY_XF86AudioRewind, Qt::Key_AudioRewind>,
    Xkb2Qt<XKB_KEY_XF86BackForward, Qt::Key_BackForward>,
    Xkb2Qt<XKB_KEY_XF86ApplicationLeft, Qt::Key_ApplicationLeft>,
    Xkb2Qt<XKB_KEY_XF86ApplicationRight, Qt::Key_ApplicationRight>,
    Xkb2Qt<XKB_KEY_XF86Book, Qt::Key_Book>, Xkb2Qt<XKB_KEY_XF86CD, Qt::Key_CD>,
    Xkb2Qt<XKB_KEY_XF86Calculater, Qt::Key_Calculator>,
    Xkb2Qt<XKB_KEY_XF86Calculator, Qt::Key_Calculator>,
    Xkb2Qt<XKB_KEY_XF86Clear, Qt::Key_Clear>,
    Xkb2Qt<XKB_KEY_XF86ClearGrab, Qt::Key_ClearGrab>,
    Xkb2Qt<XKB_KEY_XF86Close, Qt::Key_Close>,
    Xkb2Qt<XKB_KEY_XF86Copy, Qt::Key_Copy>,
    Xkb2Qt<XKB_KEY_XF86Cut, Qt::Key_Cut>,
    Xkb2Qt<XKB_KEY_XF86Display, Qt::Key_Display>,
    Xkb2Qt<XKB_KEY_XF86DOS, Qt::Key_DOS>,
    Xkb2Qt<XKB_KEY_XF86Documents, Qt::Key_Documents>,
    Xkb2Qt<XKB_KEY_XF86Excel, Qt::Key_Excel>,
    Xkb2Qt<XKB_KEY_XF86Explorer, Qt::Key_Explorer>,
    Xkb2Qt<XKB_KEY_XF86Game, Qt::Key_Game>, Xkb2Qt<XKB_KEY_XF86Go, Qt::Key_Go>,
    Xkb2Qt<XKB_KEY_XF86iTouch, Qt::Key_iTouch>,
    Xkb2Qt<XKB_KEY_XF86LogOff, Qt::Key_LogOff>,
    Xkb2Qt<XKB_KEY_XF86Market, Qt::Key_Market>,
    Xkb2Qt<XKB_KEY_XF86Meeting, Qt::Key_Meeting>,
    Xkb2Qt<XKB_KEY_XF86MenuKB, Qt::Key_MenuKB>,
    Xkb2Qt<XKB_KEY_XF86MenuPB, Qt::Key_MenuPB>,
    Xkb2Qt<XKB_KEY_XF86MySites, Qt::Key_MySites>,
    Xkb2Qt<XKB_KEY_XF86New, Qt::Key_New>,
    Xkb2Qt<XKB_KEY_XF86News, Qt::Key_News>,
    Xkb2Qt<XKB_KEY_XF86OfficeHome, Qt::Key_OfficeHome>,
    Xkb2Qt<XKB_KEY_XF86Open, Qt::Key_Open>,
    Xkb2Qt<XKB_KEY_XF86Option, Qt::Key_Option>,
    Xkb2Qt<XKB_KEY_XF86Paste, Qt::Key_Paste>,
    Xkb2Qt<XKB_KEY_XF86Phone, Qt::Key_Phone>,
#ifdef XKB_KEY_XF86PickupPhone
    Xkb2Qt<XKB_KEY_XF86PickupPhone, Qt::Key_Call>,
#endif
#ifdef XKB_KEY_XF86HangupPhone
    Xkb2Qt<XKB_KEY_XF86HangupPhone, Qt::Key_Hangup>,
#endif
    Xkb2Qt<XKB_KEY_XF86Reply, Qt::Key_Reply>,
    Xkb2Qt<XKB_KEY_XF86Reload, Qt::Key_Reload>,
    Xkb2Qt<XKB_KEY_XF86RotateWindows, Qt::Key_RotateWindows>,
    Xkb2Qt<XKB_KEY_XF86RotationPB, Qt::Key_RotationPB>,
    Xkb2Qt<XKB_KEY_XF86RotationKB, Qt::Key_RotationKB>,
    Xkb2Qt<XKB_KEY_XF86Save, Qt::Key_Save>,
    Xkb2Qt<XKB_KEY_XF86Send, Qt::Key_Send>,
    Xkb2Qt<XKB_KEY_XF86Spell, Qt::Key_Spell>,
    Xkb2Qt<XKB_KEY_XF86SplitScreen, Qt::Key_SplitScreen>,
    Xkb2Qt<XKB_KEY_XF86Support, Qt::Key_Support>,
    Xkb2Qt<XKB_KEY_XF86TaskPane, Qt::Key_TaskPane>,
    Xkb2Qt<XKB_KEY_XF86Terminal, Qt::Key_Terminal>,
    Xkb2Qt<XKB_KEY_XF86Tools, Qt::Key_Tools>,
    Xkb2Qt<XKB_KEY_XF86Travel, Qt::Key_Travel>,
    Xkb2Qt<XKB_KEY_XF86Video, Qt::Key_Video>,
    Xkb2Qt<XKB_KEY_XF86Word, Qt::Key_Word>,
    Xkb2Qt<XKB_KEY_XF86Xfer, Qt::Key_Xfer>,
    Xkb2Qt<XKB_KEY_XF86ZoomIn, Qt::Key_ZoomIn>,
    Xkb2Qt<XKB_KEY_XF86ZoomOut, Qt::Key_ZoomOut>,
    Xkb2Qt<XKB_KEY_XF86Away, Qt::Key_Away>,
    Xkb2Qt<XKB_KEY_XF86Messenger, Qt::Key_Messenger>,
    Xkb2Qt<XKB_KEY_XF86WebCam, Qt::Key_WebCam>,
    Xkb2Qt<XKB_KEY_XF86MailForward, Qt::Key_MailForward>,
    Xkb2Qt<XKB_KEY_XF86Pictures, Qt::Key_Pictures>,
    Xkb2Qt<XKB_KEY_XF86Music, Qt::Key_Music>,
    Xkb2Qt<XKB_KEY_XF86Battery, Qt::Key_Battery>,
    Xkb2Qt<XKB_KEY_XF86Bluetooth, Qt::Key_Bluetooth>,
    Xkb2Qt<XKB_KEY_XF86WLAN, Qt::Key_WLAN>,
    Xkb2Qt<XKB_KEY_XF86UWB, Qt::Key_UWB>,
    Xkb2Qt<XKB_KEY_XF86AudioForward, Qt::Key_AudioForward>,
    Xkb2Qt<XKB_KEY_XF86AudioRepeat, Qt::Key_AudioRepeat>,
    Xkb2Qt<XKB_KEY_XF86AudioRandomPlay, Qt::Key_AudioRandomPlay>,
    Xkb2Qt<XKB_KEY_XF86Subtitle, Qt::Key_Subtitle>,
    Xkb2Qt<XKB_KEY_XF86AudioCycleTrack, Qt::Key_AudioCycleTrack>,
    Xkb2Qt<XKB_KEY_XF86Time, Qt::Key_Time>,
    Xkb2Qt<XKB_KEY_XF86Select, Qt::Key_Select>,
    Xkb2Qt<XKB_KEY_XF86View, Qt::Key_View>,
    Xkb2Qt<XKB_KEY_XF86TopMenu, Qt::Key_TopMenu>,
    Xkb2Qt<XKB_KEY_XF86Red, Qt::Key_Red>,
    Xkb2Qt<XKB_KEY_XF86Green, Qt::Key_Green>,
    Xkb2Qt<XKB_KEY_XF86Yellow, Qt::Key_Yellow>,
    Xkb2Qt<XKB_KEY_XF86Blue, Qt::Key_Blue>,
    Xkb2Qt<XKB_KEY_XF86Bluetooth, Qt::Key_Bluetooth>,
    Xkb2Qt<XKB_KEY_XF86Suspend, Qt::Key_Suspend>,
    Xkb2Qt<XKB_KEY_XF86Hibernate, Qt::Key_Hibernate>,
    Xkb2Qt<XKB_KEY_XF86TouchpadToggle, Qt::Key_TouchpadToggle>,
    Xkb2Qt<XKB_KEY_XF86TouchpadOn, Qt::Key_TouchpadOn>,
    Xkb2Qt<XKB_KEY_XF86TouchpadOff, Qt::Key_TouchpadOff>,
    Xkb2Qt<XKB_KEY_XF86AudioMicMute, Qt::Key_MicMute>,
    Xkb2Qt<XKB_KEY_XF86Keyboard, Qt::Key_Keyboard>,
    Xkb2Qt<XKB_KEY_XF86Launch0, Qt::Key_Launch0>,
    Xkb2Qt<XKB_KEY_XF86Launch1, Qt::Key_Launch1>,
    Xkb2Qt<XKB_KEY_XF86Launch2, Qt::Key_Launch2>,
    Xkb2Qt<XKB_KEY_XF86Launch3, Qt::Key_Launch3>,
    Xkb2Qt<XKB_KEY_XF86Launch4, Qt::Key_Launch4>,
    Xkb2Qt<XKB_KEY_XF86Launch5, Qt::Key_Launch5>,
    Xkb2Qt<XKB_KEY_XF86Launch6, Qt::Key_Launch6>,
    Xkb2Qt<XKB_KEY_XF86Launch7, Qt::Key_Launch7>,
    Xkb2Qt<XKB_KEY_XF86Launch8, Qt::Key_Launch8>,
    Xkb2Qt<XKB_KEY_XF86Launch9, Qt::Key_Launch9>,
    Xkb2Qt<XKB_KEY_XF86LaunchA, Qt::Key_LaunchA>,
    Xkb2Qt<XKB_KEY_XF86LaunchB, Qt::Key_LaunchB>,
    Xkb2Qt<XKB_KEY_XF86LaunchC, Qt::Key_LaunchC>,
    Xkb2Qt<XKB_KEY_XF86LaunchD, Qt::Key_LaunchD>,
    Xkb2Qt<XKB_KEY_XF86LaunchE, Qt::Key_LaunchE>,
    Xkb2Qt<XKB_KEY_XF86LaunchF, Qt::Key_LaunchF>>::data;

static void qt_UCSConvertCase(uint32_t code, xkb_keysym_t *lower,
                              xkb_keysym_t *upper) {
  *lower = QChar::toLower(code);
  *upper = QChar::toUpper(code);
}

static void xkbcommon_XConvertCase(xkb_keysym_t sym, xkb_keysym_t *lower,
                                   xkb_keysym_t *upper) {
  /* Latin 1 keysym */
  if (sym < 0x100) {
    qt_UCSConvertCase(sym, lower, upper);
    return;
  }

  /* Unicode keysym */
  if ((sym & 0xff000000) == 0x01000000) {
    qt_UCSConvertCase((sym & 0x00ffffff), lower, upper);
    *upper |= 0x01000000;
    *lower |= 0x01000000;
    return;
  }

  /* Legacy keysym */

  *lower = sym;
  *upper = sym;

  switch (sym >> 8) {
  case 1: /* Latin 2 */
    /* Assume the KeySym is a legal value (ignore discontinuities) */
    if (sym == XKB_KEY_Aogonek)
      *lower = XKB_KEY_aogonek;
    else if (sym >= XKB_KEY_Lstroke && sym <= XKB_KEY_Sacute)
      *lower += (XKB_KEY_lstroke - XKB_KEY_Lstroke);
    else if (sym >= XKB_KEY_Scaron && sym <= XKB_KEY_Zacute)
      *lower += (XKB_KEY_scaron - XKB_KEY_Scaron);
    else if (sym >= XKB_KEY_Zcaron && sym <= XKB_KEY_Zabovedot)
      *lower += (XKB_KEY_zcaron - XKB_KEY_Zcaron);
    else if (sym == XKB_KEY_aogonek)
      *upper = XKB_KEY_Aogonek;
    else if (sym >= XKB_KEY_lstroke && sym <= XKB_KEY_sacute)
      *upper -= (XKB_KEY_lstroke - XKB_KEY_Lstroke);
    else if (sym >= XKB_KEY_scaron && sym <= XKB_KEY_zacute)
      *upper -= (XKB_KEY_scaron - XKB_KEY_Scaron);
    else if (sym >= XKB_KEY_zcaron && sym <= XKB_KEY_zabovedot)
      *upper -= (XKB_KEY_zcaron - XKB_KEY_Zcaron);
    else if (sym >= XKB_KEY_Racute && sym <= XKB_KEY_Tcedilla)
      *lower += (XKB_KEY_racute - XKB_KEY_Racute);
    else if (sym >= XKB_KEY_racute && sym <= XKB_KEY_tcedilla)
      *upper -= (XKB_KEY_racute - XKB_KEY_Racute);
    break;
  case 2: /* Latin 3 */
    /* Assume the KeySym is a legal value (ignore discontinuities) */
    if (sym >= XKB_KEY_Hstroke && sym <= XKB_KEY_Hcircumflex)
      *lower += (XKB_KEY_hstroke - XKB_KEY_Hstroke);
    else if (sym >= XKB_KEY_Gbreve && sym <= XKB_KEY_Jcircumflex)
      *lower += (XKB_KEY_gbreve - XKB_KEY_Gbreve);
    else if (sym >= XKB_KEY_hstroke && sym <= XKB_KEY_hcircumflex)
      *upper -= (XKB_KEY_hstroke - XKB_KEY_Hstroke);
    else if (sym >= XKB_KEY_gbreve && sym <= XKB_KEY_jcircumflex)
      *upper -= (XKB_KEY_gbreve - XKB_KEY_Gbreve);
    else if (sym >= XKB_KEY_Cabovedot && sym <= XKB_KEY_Scircumflex)
      *lower += (XKB_KEY_cabovedot - XKB_KEY_Cabovedot);
    else if (sym >= XKB_KEY_cabovedot && sym <= XKB_KEY_scircumflex)
      *upper -= (XKB_KEY_cabovedot - XKB_KEY_Cabovedot);
    break;
  case 3: /* Latin 4 */
    /* Assume the KeySym is a legal value (ignore discontinuities) */
    if (sym >= XKB_KEY_Rcedilla && sym <= XKB_KEY_Tslash)
      *lower += (XKB_KEY_rcedilla - XKB_KEY_Rcedilla);
    else if (sym >= XKB_KEY_rcedilla && sym <= XKB_KEY_tslash)
      *upper -= (XKB_KEY_rcedilla - XKB_KEY_Rcedilla);
    else if (sym == XKB_KEY_ENG)
      *lower = XKB_KEY_eng;
    else if (sym == XKB_KEY_eng)
      *upper = XKB_KEY_ENG;
    else if (sym >= XKB_KEY_Amacron && sym <= XKB_KEY_Umacron)
      *lower += (XKB_KEY_amacron - XKB_KEY_Amacron);
    else if (sym >= XKB_KEY_amacron && sym <= XKB_KEY_umacron)
      *upper -= (XKB_KEY_amacron - XKB_KEY_Amacron);
    break;
  case 6: /* Cyrillic */
    /* Assume the KeySym is a legal value (ignore discontinuities) */
    if (sym >= XKB_KEY_Serbian_DJE && sym <= XKB_KEY_Serbian_DZE)
      *lower -= (XKB_KEY_Serbian_DJE - XKB_KEY_Serbian_dje);
    else if (sym >= XKB_KEY_Serbian_dje && sym <= XKB_KEY_Serbian_dze)
      *upper += (XKB_KEY_Serbian_DJE - XKB_KEY_Serbian_dje);
    else if (sym >= XKB_KEY_Cyrillic_YU && sym <= XKB_KEY_Cyrillic_HARDSIGN)
      *lower -= (XKB_KEY_Cyrillic_YU - XKB_KEY_Cyrillic_yu);
    else if (sym >= XKB_KEY_Cyrillic_yu && sym <= XKB_KEY_Cyrillic_hardsign)
      *upper += (XKB_KEY_Cyrillic_YU - XKB_KEY_Cyrillic_yu);
    break;
  case 7: /* Greek */
    /* Assume the KeySym is a legal value (ignore discontinuities) */
    if (sym >= XKB_KEY_Greek_ALPHAaccent && sym <= XKB_KEY_Greek_OMEGAaccent)
      *lower += (XKB_KEY_Greek_alphaaccent - XKB_KEY_Greek_ALPHAaccent);
    else if (sym >= XKB_KEY_Greek_alphaaccent &&
             sym <= XKB_KEY_Greek_omegaaccent &&
             sym != XKB_KEY_Greek_iotaaccentdieresis &&
             sym != XKB_KEY_Greek_upsilonaccentdieresis)
      *upper -= (XKB_KEY_Greek_alphaaccent - XKB_KEY_Greek_ALPHAaccent);
    else if (sym >= XKB_KEY_Greek_ALPHA && sym <= XKB_KEY_Greek_OMEGA)
      *lower += (XKB_KEY_Greek_alpha - XKB_KEY_Greek_ALPHA);
    else if (sym >= XKB_KEY_Greek_alpha && sym <= XKB_KEY_Greek_omega &&
             sym != XKB_KEY_Greek_finalsmallsigma)
      *upper -= (XKB_KEY_Greek_alpha - XKB_KEY_Greek_ALPHA);
    break;
  case 0x13: /* Latin 9 */
    if (sym == XKB_KEY_OE)
      *lower = XKB_KEY_oe;
    else if (sym == XKB_KEY_oe)
      *upper = XKB_KEY_OE;
    else if (sym == XKB_KEY_Ydiaeresis)
      *lower = XKB_KEY_ydiaeresis;
    break;
  }
}

static bool isLatin1(xkb_keysym_t sym) { return sym >= 0x20 && sym <= 0xff; }

static xkb_keysym_t qxkbcommon_xkb_keysym_to_upper(xkb_keysym_t ks) {
  xkb_keysym_t lower, upper;

  xkbcommon_XConvertCase(ks, &lower, &upper);

  return upper;
}

Qt::Key keysym_to_QTKey(xkb_keysym_t keysym) {
  if (keysym >= XKB_KEY_F1 && keysym <= XKB_KEY_F35) {
    return static_cast<Qt::Key>(Qt::Key_F1 + (keysym - XKB_KEY_F1));
  } else if (keysym >= XKB_KEY_KP_0 && keysym <= XKB_KEY_KP_9) {
    return static_cast<Qt::Key>(Qt::Key_0 + (keysym - XKB_KEY_KP_0));
  } else if (isLatin1(keysym)) {
    Qt::Key qtKey =
        static_cast<Qt::Key>(qxkbcommon_xkb_keysym_to_upper(keysym));
    if (!isLatin1(qtKey)) {
      return static_cast<Qt::Key>(keysym);
    } else {
      return qtKey;
    }
  } else {
    const XKBQTPair pair{keysym, static_cast<Qt::Key>(0)};
    auto it = std::lower_bound(KeyTbl.cbegin(), KeyTbl.cend(), pair);
    if (it != KeyTbl.end() && !(pair < *it)) {
      return it->qt;
    }
  }

  std::stringstream ss;
  ss << "0x" << std::hex << keysym;
  qWarning() << "Unknown keysym: " << ss.str();
  return Qt::Key_unknown;
}
