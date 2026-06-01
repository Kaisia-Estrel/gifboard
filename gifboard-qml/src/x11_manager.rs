#[cxx_qt::bridge]
pub mod ffi {

    unsafe extern "C++" {
        include!(<xcb/xcb.h>);
        type xcb_connection_t;

        include!("src/x11_filter.h");
        type X11EventFilter;

        include!("cxx-qt-lib/qstring.h");
        type QString = cxx_qt_lib::QString;

        #[allow(clippy::missing_safety_doc)]
        unsafe fn get_x11_connection() -> *mut xcb_connection_t;

        #[allow(clippy::missing_safety_doc)]
        pub unsafe fn install_x11_event_filter();

        #[allow(clippy::missing_safety_doc)]
        pub unsafe fn delete_x11_event_filter();

        #[allow(clippy::missing_safety_doc)]
        pub(crate) unsafe fn registerManager(self: Pin<&mut X11EventFilter>, m: *mut X11Manager);

        #[allow(clippy::missing_safety_doc)]
        unsafe fn get_x11_event_filter() -> *mut X11EventFilter;

        fn inject_key_event(qtype: i32, keysym: u32, modifiers: u32, text: &QString) -> bool;
    }

    extern "RustQt" {
        #[qobject]
        #[qml_element]
        type X11Manager = super::X11ManagerRust;

        #[qinvokable]
        #[cxx_name = "grabInput"]
        fn grab_input(self: Pin<&mut Self>);

        #[qinvokable]
        #[cxx_name = "ungrabInput"]
        fn ungrab_input(self: Pin<&mut Self>);

        #[qinvokable]
        #[cxx_name = "onX11"]
        fn on_x11(self: Pin<&mut Self>) -> bool;

        #[qsignal]
        #[cxx_name = "keyPressed"]
        fn key_pressed(self: Pin<&mut Self>, keycode: u8);

        #[cxx_name = "key_received"]
        fn key_received(self: Pin<&mut Self>, keycode: u8, response_type: u8) -> bool;
    }
}

use std::pin::Pin;

pub struct X11State {
    conn: xcb::Connection,
    state: xkbcommon::xkb::State,
}

pub struct X11ManagerRust {
    x11: Option<X11State>,
}

pub fn on_x11() -> bool {
    let conn = unsafe { ffi::get_x11_connection().cast::<xcb::ffi::xcb_connection_t>() };
    !conn.is_null()
}

use cxx_qt::CxxQtType;
use cxx_qt_lib::{KeyboardModifier, QFlags};
use xkbcommon::xkb;

use crate::x11_manager::ffi::X11Manager;

impl Default for X11ManagerRust {
    fn default() -> Self {
        let conn = unsafe { ffi::get_x11_connection().cast::<xcb::ffi::xcb_connection_t>() };
        if conn.is_null() {
            return Self { x11: None };
        }
        let conn = unsafe { xcb::Connection::from_raw_conn_and_extensions_no_drop(conn, &[], &[]) };

        let xkbver = conn
            .wait_for_reply(conn.send_request(&xcb::xkb::UseExtension {
                wanted_major: xkb::x11::MIN_MAJOR_XKB_VERSION,
                wanted_minor: xkb::x11::MIN_MINOR_XKB_VERSION,
            }))
            .expect("Failed to request XKB extension");

        assert!(
            xkbver.supported(),
            "required xcb-xkb-{}-{} is not supported",
            xkb::x11::MIN_MAJOR_XKB_VERSION,
            xkb::x11::MIN_MINOR_XKB_VERSION
        );

        let xkb_context = xkb::Context::new(xkb::CONTEXT_NO_FLAGS);
        let device_id = xkb::x11::get_core_keyboard_device_id(&conn);
        let xkb_keymap = xkb::x11::keymap_new_from_device(
            &xkb_context,
            &conn,
            device_id,
            xkb::KEYMAP_COMPILE_NO_FLAGS,
        );
        Self {
            x11: Some(X11State {
                conn,
                state: xkb::State::new(&xkb_keymap),
            }),
        }
    }
}

impl ffi::X11Manager {
    fn on_x11(self: Pin<&mut Self>) -> bool {
        on_x11()
    }
    fn key_received(self: Pin<&mut Self>, keycode: xcb::x::Keycode, qtype: u8) -> bool {
        let keycode = xkb::Keycode::new(keycode.into());
        let direction = if qtype == 0 {
            xkb::KeyDirection::Down
        } else {
            xkb::KeyDirection::Up
        };
        let mut binding = self.rust_mut();
        let state = &mut binding.x11.as_mut().expect("No X11 Connection").state;

        state.update_key(keycode, direction);
        let mut modifiers: QFlags<KeyboardModifier> = QFlags::new();
        if state.mod_name_is_active(xkb::MOD_NAME_SHIFT, xkb::STATE_MODS_DEPRESSED) {
            modifiers |= KeyboardModifier::ShiftModifier;
        }
        if state.mod_name_is_active(xkb::MOD_NAME_ALT, xkb::STATE_MODS_DEPRESSED) {
            modifiers |= KeyboardModifier::AltModifier;
        }
        if state.mod_name_is_active(xkb::MOD_NAME_CTRL, xkb::STATE_MODS_DEPRESSED) {
            modifiers |= KeyboardModifier::ControlModifier;
        }
        let keysym = state.key_get_one_sym(keycode);
        let text = ffi::QString::from(state.key_get_utf8(keycode));

        ffi::inject_key_event(qtype.into(), keysym.into(), modifiers.to_int(), &text)
    }

    fn ungrab_input(self: Pin<&mut Self>) {
        let conn = &self.x11.as_ref().expect("No X11 Connection").conn;
        let _ = conn.send_request(&xcb::x::UngrabKeyboard {
            time: xcb::x::CURRENT_TIME,
        });
        dbg!("Ungrabbed Keyboard");
    }

    fn grab_input(self: Pin<&mut Self>) {
        let conn = &self.x11.as_ref().expect("No X11 Connection").conn;
        let setup = conn.get_setup();
        let screen = setup.roots().next().expect("No Screen Found");

        let cookie = conn.send_request(&xcb::x::GrabKeyboard {
            owner_events: true,
            grab_window: screen.root(),
            time: xcb::x::CURRENT_TIME,
            pointer_mode: xcb::x::GrabMode::Async,
            keyboard_mode: xcb::x::GrabMode::Async,
        });
        let reply = conn
            .wait_for_reply(cookie)
            .expect("GrabKeyboard did not succeed");
        assert!(
            reply.status() == xcb::x::GrabStatus::Success,
            "GrabKeyboard did not succeed"
        );

        let filter = unsafe { ffi::get_x11_event_filter() };
        if let Some(filter) = unsafe { filter.as_mut() } {
            let pin = unsafe { std::pin::Pin::new_unchecked(filter) };
            let manager_ptr: *mut X11Manager = unsafe { self.get_unchecked_mut() };
            unsafe { pin.registerManager(manager_ptr) };
        } else {
            panic!("Could not get a filter")
        }
    }
}
