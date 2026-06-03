#[cxx_qt::bridge]
mod ffi {

    unsafe extern "C++" {
        include!("cxx-qt-lib/qstring.h");
        type QString = cxx_qt_lib::QString;
        type QUrl = cxx_qt_lib::QUrl;
    }

    extern "RustQt" {
        #[qobject]
        #[qml_element]
        #[qproperty(QString, appname, READ = get_appname, WRITE = set_appname)]
        #[qproperty(QString, summary, READ = get_summary, WRITE = set_summary)]
        #[qproperty(QString, body, READ = get_body, WRITE = set_body)]
        #[qproperty(QString, icon, READ = get_icon, WRITE = set_icon)]
        #[qproperty(QString, image, READ = get_image, WRITE = set_image)]
        type Notification = super::NotificationRust;

        fn get_appname(&self) -> QString;
        fn set_appname(self: Pin<&mut Self>, value: QString);

        fn get_summary(&self) -> QString;
        fn set_summary(self: Pin<&mut Self>, value: QString);

        fn get_body(&self) -> QString;
        fn set_body(self: Pin<&mut Self>, value: QString);

        fn get_icon(&self) -> QString;
        fn set_icon(self: Pin<&mut Self>, value: QString);

        fn get_image(&self) -> QString;
        fn set_image(self: Pin<&mut Self>, value: QString);

        #[qinvokable]
        fn show(&self);

        #[qsignal]
        fn shown(self: Pin<&mut Self>);
    }

    impl cxx_qt::Threading for Notification {}
}

use cxx_qt::{CxxQtType, Threading};
use cxx_qt_lib::QString;

#[derive(Default)]
pub struct NotificationRust {
    _notification: notify_rust::Notification,
    _handle: Option<notify_rust::NotificationHandle>,
}

use std::pin::Pin;

impl ffi::Notification {
    fn show(&self) {
        let notif = self._notification.clone();
        let qt_thread = self.qt_thread();
        gifboard_core::TOKIO.spawn(async move {
            let handle = notif.show_async().await.unwrap();
            qt_thread.queue(move |mut self_async| {
                self_async.as_mut().shown();
                self_async.rust_mut()._handle = Some(handle);
            })
        });
    }

    fn get_summary(&self) -> QString {
        QString::from(self._notification.summary.clone())
    }

    fn set_summary(self: Pin<&mut Self>, value: QString) {
        self.rust_mut()._notification.summary(&value.to_string());
    }

    fn get_appname(&self) -> QString {
        QString::from(self._notification.appname.clone())
    }

    fn set_appname(self: Pin<&mut Self>, value: QString) {
        self.rust_mut()._notification.appname(&value.to_string());
    }

    fn get_body(&self) -> QString {
        QString::from(self._notification.body.clone())
    }

    fn set_body(self: Pin<&mut Self>, value: QString) {
        self.rust_mut()._notification.body(&value.to_string());
    }

    fn get_icon(&self) -> QString {
        QString::from(self._notification.icon.clone())
    }

    fn set_icon(self: Pin<&mut Self>, value: QString) {
        self.rust_mut()._notification.icon(&value.to_string());
    }

    fn set_image(self: Pin<&mut Self>, value: QString) {
        self.rust_mut()._notification.image_path(&value.to_string());
    }

    fn get_image(&self) -> QString {
        let path = self._notification.hints.iter().find_map(|x| match x {
            notify_rust::Hint::ImagePath(p) => Some(p),
            _ => None,
        });
        match path {
            Some(path) => QString::from(path),
            None => QString::default(),
        }
    }
}
