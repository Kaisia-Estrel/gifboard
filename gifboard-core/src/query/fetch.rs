use std::sync::LazyLock;

use cxx_qt_lib::QString;
use tokio::{
    sync::{Mutex, mpsc},
    task::JoinHandle,
    time,
};

use crate::{config, query::klippy::fetch_from_klippy};

// RawJpg refers to `blur_preview` in the `Attachment` struct
#[derive(Debug)]
pub enum AttachmentType {
    Url(String),
    LocalFile(String),
    RawJpg,
}

#[derive(Debug)]
pub struct Attachment {
    pub output_uri: AttachmentType,
    pub hover_uri: Option<AttachmentType>,
    pub preview_uri: AttachmentType,
    pub blur_preview: Vec<u8>,
    pub height: usize,
    pub width: usize,
}

// Returns `None` if the query was not called due to debounce
// otherwise returns a std::io::result type
type QueryMessage = Option<std::io::Result<Vec<Attachment>>>;
type PrevQuery = Option<(mpsc::Sender<QueryMessage>, JoinHandle<()>)>;
static DEBOUNCE: LazyLock<Mutex<PrevQuery>> = LazyLock::new(|| Mutex::new(None));

async fn get_files(query: &str) -> std::io::Result<Vec<Attachment>> {
    let mut attachments = vec![];
    let config = config::read_config()?;
    attachments.append(&mut fetch_from_klippy(&config, query).await?);

    Ok(attachments)
}

async fn fetch_query_debounce(query: QString) -> mpsc::Receiver<QueryMessage> {
    let (tx, rx) = mpsc::channel(2);
    let mut task = DEBOUNCE.lock().await;

    if let Some((old_tx, old)) = task.take() {
        old.abort();
        let _ = old_tx.send(None).await;
    }

    // Add keyboard debounce so queries only happen 500ms after all edits have stopped
    // to prevent too much api calls
    *task = Some((
        tx.clone(),
        (tokio::spawn(async move {
            time::sleep(time::Duration::from_millis(500)).await;

            match get_files(&query.to_string()).await {
                Err(e) => {
                    let _ = tx.send(Some(Err(e))).await;
                }
                Ok(files) => {
                    let _ = tx.send(Some(Ok(files))).await;
                }
            }
        })),
    ));

    rx
}
pub async fn fetch_query(query: QString) -> std::io::Result<Option<Vec<Attachment>>> {
    let mut rx = fetch_query_debounce(query).await;
    let result = rx
        .recv()
        .await
        .expect("Query rx channel was unexpectedly closed");
    rx.close();
    if let Some(result) = result {
        result.map(Some)
    } else {
        Ok(None) //query caught by debounce
    }
}
