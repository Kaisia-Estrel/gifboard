#[cxx_qt::bridge]
pub mod qobject {

    unsafe extern "C++" {
        include!("cxx-qt-lib/qstring.h");
        type QString = cxx_qt_lib::QString;
    }

    extern "RustQt" {
        #[qobject]
        #[qml_element]
        #[qproperty(QString, query_text)]
        type SearchResults = super::SearchResultsRust;

        #[qinvokable]
        fn query(self: Pin<&mut Self>, query: &QString);

        #[qsignal]
        #[cxx_name = "queryError"]
        fn query_error(self: Pin<&mut Self>, error: QString);

        #[qsignal]
        #[cxx_name = "receivedResults"]
        fn received_results(self: Pin<&mut Self>, url: QString, width: usize, height: usize);
    }
    impl cxx_qt::Threading for SearchResults {}
}

#[derive(Default)]
pub struct SearchResultsRust {
    pub query_text: QString,
}

use cxx_qt::Threading;
use cxx_qt_lib::QString;
use std::pin::Pin;

impl qobject::SearchResults {
    pub fn query(self: Pin<&mut Self>, query: &QString) {
        let qt_thread = self.qt_thread();
        self.set_query_text(query.clone());
        let query_clone = query.clone();

        gifboard_core::TOKIO.spawn(async move {
            match gifboard_core::query::fetch_query(query_clone).await {
                Err(e) => {
                    qt_thread
                        .queue(move |self_async| {
                            self_async.query_error(QString::from(e.to_string()));
                        })
                        .unwrap();
                }
                Ok(None) => {} //caught by debounce
                Ok(Some(attachments)) => {
                    for attachment in attachments {
                        let output_uri = match attachment.output_uri {
                            gifboard_core::query::AttachmentType::Url(s) => s,
                            gifboard_core::query::AttachmentType::LocalFile(s) => s,
                            gifboard_core::query::AttachmentType::RawJpg => todo!(),
                        };
                        let width = attachment.width;
                        let height = attachment.height;
                        qt_thread
                            .queue(move |self_async| {
                                self_async.received_results(
                                    QString::from(output_uri),
                                    width,
                                    height,
                                );
                            })
                            .unwrap();
                    }
                }
            }
        });
    }
}
