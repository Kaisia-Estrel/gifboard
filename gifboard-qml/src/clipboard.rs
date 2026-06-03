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
        include!("cxx-qt-lib/qstringlist.h");
        include!("cxx-qt-lib/qurl.h");
        include!("cxx-qt-lib/qlist.h");
        type QString = cxx_qt_lib::QString;
        type QStringList = cxx_qt_lib::QStringList;
        type QUrl = cxx_qt_lib::QUrl;
        type QList_QUrl = cxx_qt_lib::QList<QUrl>;

        include!("src/clipboard.h");
        type QMimeData;
        type QClipboardMode;

        #[rust_name = "set_urls"]
        fn setUrls(self: Pin<&mut QMimeData>, urls: &QList_QUrl);

        #[rust_name = "set_text"]
        fn setText(self: Pin<&mut QMimeData>, text: &QString);

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
        #[cxx_name = "copyUrls"]
        fn copy_urls(self: Pin<&mut ClipboardManager>, urls: QList_QUrl);

        #[qinvokable]
        #[cxx_name = "copyUrlsToTmp"]
        fn copy_urls_to_tmp(self: Pin<&mut ClipboardManager>, urls: QList_QUrl);

        #[qinvokable]
        #[cxx_name = "copyUrlsToLocal"]
        fn copy_urls_to_local(self: Pin<&mut ClipboardManager>, urls: QList_QUrl);

        #[qsignal]
        #[cxx_name = "urlsCopied"]
        fn urls_copied(self: Pin<&mut Self>, urls: QStringList);

        #[qsignal]
        #[cxx_name = "releasedOwnership"]
        fn released_ownership(self: Pin<&mut Self>);
    }

    impl cxx_qt::Threading for ClipboardManager {}
}

impl ffi::QMimeData {
    fn new() -> cxx::UniquePtr<ffi::QMimeData> {
        ffi::QMimeData_New()
    }
    fn new_with_urls(urls: &ffi::QList_QUrl) -> cxx::UniquePtr<Self> {
        let mut mimedata = Self::new();
        mimedata.as_mut().expect("Mimedata is null").set_urls(urls);
        mimedata
    }
    fn new_with_text(text: &ffi::QString) -> cxx::UniquePtr<Self> {
        let mut mimedata = Self::new();
        mimedata.as_mut().expect("Mimedata is null").set_text(text);
        mimedata
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
use crate::clipboard::ffi::QMimeData;
use cxx_qt::CxxQtType;
use cxx_qt::Threading;
use cxx_qt_lib::QString;
use cxx_qt_lib::QStringList;
use std::pin::Pin;

pub struct ClipboardManagerRust {
    qclipboard: *mut ffi::QClipboard,
    // Guard is not directly used but instead
    // ownership is claimed to ensure lifetime
    // lasts the lifetime of this struct
    guard: Option<cxx_qt_lib::QMetaObjectConnectionGuard>,
}

impl Default for ClipboardManagerRust {
    fn default() -> Self {
        let qclipboard_ptr = ffi::get_app_clipboard();
        Self {
            qclipboard: qclipboard_ptr,
            guard: None,
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

    fn clipboard_with_mime_data(
        &self,
        mime_data: cxx::UniquePtr<QMimeData>,
    ) -> Pin<&mut ffi::QClipboard> {
        let mut clipboard = self.clipboard_pin();
        clipboard
            .as_mut()
            .set_mime_data(mime_data, QClipboardMode::Clipboard);
        clipboard
    }

    fn capture_guard(self: Pin<&mut Self>, guard: cxx_qt_lib::QMetaObjectConnectionGuard) {
        self.rust_mut().guard = Some(guard);
    }

    fn copy_urls(mut self: Pin<&mut Self>, urls: ffi::QList_QUrl) {
        let mut list = QStringList::default();
        for i in urls.into_iter() {
            list.append(i.to_qstring());
        }
        let text = list.join(&QString::from("\n"));

        let clipboard = self.clipboard_with_mime_data(QMimeData::new_with_text(&text));
        let qt_thread = self.qt_thread();
        let guard = clipboard.on_data_changed(move |clipboard| {
            if !clipboard.owns_clipboard() {
                qt_thread
                    .queue(|self_async| {
                        self_async.released_ownership();
                    })
                    .unwrap();
            }
        });
        // capture lifetime of guard so it may be called for the lifetime of the program
        self.as_mut().capture_guard(guard);
        let mut paths = ffi::QStringList::default();
        for i in urls.into_iter() {
            paths.append(i.to_local_file_or_default());
        }
        self.as_mut().urls_copied(paths);
    }

    fn copy_urls_to_tmp(self: Pin<&mut Self>, urls: ffi::QList_QUrl) {
        let rx = gifboard_core::clipboard::save_url_to_temp(urls);
        let qt_thread = self.qt_thread();
        gifboard_core::TOKIO.spawn(async move {
            match rx.await {
                Ok(Ok(urls)) => {
                    qt_thread
                        .queue(move |mut self_async| {
                            let clipboard = self_async
                                .clipboard_with_mime_data(QMimeData::new_with_urls(&urls));
                            let qt_thread = self_async.qt_thread();
                            let guard = clipboard.on_data_changed(move |clipboard| {
                                if !clipboard.owns_clipboard() {
                                    qt_thread
                                        .queue(|self_async| self_async.released_ownership())
                                        .unwrap();
                                }
                            });

                            self_async.as_mut().capture_guard(guard);
                            let mut paths = ffi::QStringList::default();
                            for i in urls.into_iter() {
                                paths.append(i.to_local_file_or_default());
                            }
                            self_async.as_mut().urls_copied(paths);
                        })
                        .unwrap();
                }
                Ok(Err(e)) => todo!("Handle errors: {}", e),
                Err(e) => todo!("Handle errors: {}", e),
            }
        });
    }

    fn copy_urls_to_local(self: Pin<&mut Self>, urls: ffi::QList_QUrl) {
        todo!("Local copy {:?}", urls);
    }
}
