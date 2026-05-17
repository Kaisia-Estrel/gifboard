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

async fn get_files(query: &str, page: usize) -> std::io::Result<Vec<Attachment>> {
    let mut attachments = vec![];
    let config = config::read_config()?;
    attachments.append(&mut fetch_from_klippy(&config, page, query).await?);

    Ok(attachments)
}

static DEBOUNCE: LazyLock<Mutex<PrevQuery>> = LazyLock::new(|| Mutex::new(None));
async fn fetch_query_debounced(query: QString, page: usize) -> mpsc::Receiver<QueryMessage> {
    let (tx, rx) = mpsc::channel(1);
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

            match get_files(&query.to_string(), page).await {
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

static THROTTLE: LazyLock<Mutex<()>> = LazyLock::new(|| Mutex::new(()));
pub async fn fetch_query_throttled(query: QString, page: usize) -> mpsc::Receiver<QueryMessage> {
    let (tx, rx) = mpsc::channel(1);
    if let Ok(guard) = THROTTLE.try_lock() {
        match get_files(&query.to_string(), page).await {
            Err(e) => {
                let _ = tx.send(Some(Err(e))).await;
            }
            Ok(files) => {
                let _ = tx.send(Some(Ok(files))).await;
            }
        }
        let _ = tokio::time::sleep(tokio::time::Duration::from_secs_f64(1.0)).await;
        drop(guard);
    } else {
        let _ = tx.send(None).await;
    }

    rx
}

pub async fn fetch_query(
    query: QString,
    page: usize,
    debounced: bool,
) -> std::io::Result<Option<Vec<Attachment>>> {
    let mut rx = if debounced {
        fetch_query_debounced(query, page).await
    } else {
        fetch_query_throttled(query, page).await
    };

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
