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
        #[qproperty(usize, current_page)]
        type SearchResults = super::SearchResultsRust;

        #[qinvokable]
        #[cxx_name = "queryDebounced"]
        fn query_debounced(self: Pin<&mut Self>, query: &QString);

        #[qinvokable]
        #[cxx_name = "queryThrottled"]
        fn query_throttled(self: Pin<&mut Self>, query: &QString);

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
    pub current_page: usize,
}

use cxx_qt::Threading;
use cxx_qt_lib::QString;
use std::pin::Pin;

impl qobject::SearchResults {
    // Either debounced or throttled
    fn query(self: Pin<&mut Self>, query: &QString, debounced: bool) {
        let qt_thread = self.qt_thread();
        let page = *self.current_page();
        self.set_query_text(query.clone());
        let query_clone = query.clone();

        gifboard_core::TOKIO.spawn(async move {
            match gifboard_core::query::fetch_query(query_clone, page, debounced).await {
                Err(e) => {
                    qt_thread
                        .queue(move |self_async| {
                            self_async.query_error(QString::from(e.to_string()));
                        })
                        .unwrap();
                }
                Ok(None) => {} //caught by throttle
                Ok(Some(attachments)) => {
                    if debounced {
                        println!("Queried (debounced), page {page}");
                    } else {
                        println!("Queried (throttled), page {page}");
                    }
                    qt_thread
                        .queue(move |self_async| self_async.set_current_page(page + 1))
                        .unwrap();
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

    pub fn query_throttled(self: Pin<&mut Self>, query: &QString) {
        Self::query(self, query, false)
    }

    pub fn query_debounced(mut self: Pin<&mut Self>, query: &QString) {
        self.as_mut().set_current_page(0);
        Self::query(self, query, true)
    }
}
