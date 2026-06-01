#[cxx_qt::bridge]
pub mod ffi {

    #[repr(i32)]
    pub enum QClipboardMode {
        Clipboard = 0,
        Selection = 1,
        FindBuffer = 2,
    }

    unsafe extern "C++" {
        include!("cxx-qt-lib/qstring.h");
        include!("cxx-qt-lib/qurl.h");
        include!("cxx-qt-lib/qlist.h");
        type QString = cxx_qt_lib::QString;
        type QUrl = cxx_qt_lib::QUrl;
        type QList_QUrl = cxx_qt_lib::QList<QUrl>;

        include!("src/clipboard.h");
        type QMimeData;
        type QClipboardMode;

        #[rust_name = "set_urls"]
        fn setUrls(self: Pin<&mut QMimeData>, urls: &QList_QUrl);

        // fn text(self: &QMimeData) -> QString;
        // fn urls(self: &QMimeData) -> QList_QUrl;

        #[rust_name = "get_app_clipboard"]
        pub fn getAppClipboard() -> *mut QClipboard;

        pub fn QMimeData_New() -> UniquePtr<QMimeData>;
    }

    unsafe extern "C++Qt" {
        #[qobject]
        type QClipboard;
        #[rust_name = "set_text"]
        pub fn setText(self: Pin<&mut QClipboard>, text: &QString, mode: QClipboardMode);

        #[allow(clippy::missing_safety_doc)]
        #[rust_name = "set_mime_data_unsafe"]
        pub unsafe fn setMimeData(
            self: Pin<&mut QClipboard>,
            src: *mut QMimeData,
            mode: QClipboardMode,
        );

        #[rust_name = "owns_clipboard"]
        pub fn ownsClipboard(self: &QClipboard) -> bool;

        #[rust_name = "mime_data"]
        pub fn mimeData(self: &QClipboard, mode: QClipboardMode) -> *const QMimeData;

        #[qsignal]
        #[rust_name = "data_changed"]
        fn dataChanged(self: Pin<&mut QClipboard>);

    }

    unsafe extern "RustQt" {
        #[qobject]
        #[qml_element]
        type ClipboardManager = super::ClipboardManagerRust;

        #[qinvokable]
        #[cxx_name = "copyAsTemp"]
        fn copy_as_temp(self: Pin<&mut Self>, url: &QString);

        #[qsignal]
        #[cxx_name = "fileCopied"]
        fn file_copied(self: Pin<&mut Self>);

        #[qsignal]
        #[cxx_name = "clipboardChanged"]
        fn clipboard_changed(self: Pin<&mut Self>);
    }

    impl cxx_qt::Threading for ClipboardManager {}
}

impl ffi::QMimeData {
    fn new() -> cxx::UniquePtr<Self> {
        ffi::QMimeData_New()
    }
}
impl ffi::QClipboard {
    fn set_mime_data(
        self: Pin<&mut Self>,
        mime_data: cxx::UniquePtr<ffi::QMimeData>,
        mode: ffi::QClipboardMode,
    ) {
        unsafe { self.set_mime_data_unsafe(mime_data.into_raw(), mode) }
    }
}

use crate::clipboard::ffi::QClipboardMode;
use cxx_qt::Threading;
use std::pin::Pin;

pub struct ClipboardManagerRust {
    qclipboard: *mut ffi::QClipboard,
}

impl Default for ClipboardManagerRust {
    fn default() -> Self {
        let qclipboard_ptr = ffi::get_app_clipboard();
        Self {
            qclipboard: qclipboard_ptr,
        }
    }
}

impl ffi::ClipboardManager {
    #[allow(clippy::mut_from_ref)]
    fn clipboard_pin(&self) -> Pin<&mut ffi::QClipboard> {
        let qclipboard =
            unsafe { self.qclipboard.as_mut() }.expect("QGuiApplication::clipboard is null");

        unsafe { Pin::new_unchecked(qclipboard) }
    }

    fn copy_as_temp(self: Pin<&mut Self>, url: &ffi::QString) {
        let mut clipboard = self.clipboard_pin();
        let rx = gifboard_core::clipboard::save_url_to_temp(url);
        let file_uri = rx.blocking_recv().unwrap();
        let mut mime_data = ffi::QMimeData::new();
        mime_data
            .as_mut()
            .unwrap()
            .set_urls(&vec![ffi::QUrl::from(&file_uri)].into());
        clipboard
            .as_mut()
            .set_mime_data(mime_data, QClipboardMode::Clipboard);
        println!("Copied to clipboard: {}", file_uri);

        let qt_thread = self.qt_thread();
        let conn = clipboard.on_data_changed(move |clipboard| {
            if !clipboard.owns_clipboard() {
                qt_thread
                    .queue(|self_async| {
                        self_async.clipboard_changed();
                    })
                    .unwrap();
            }
        });
        std::mem::forget(conn);
        self.file_copied();
    }
}
