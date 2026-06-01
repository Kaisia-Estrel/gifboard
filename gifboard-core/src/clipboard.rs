use std::io::Write;

use crate::TOKIO;

use tokio::sync::oneshot::Receiver;

pub fn save_url_to_temp<S>(url: S) -> Receiver<String>
where
    S: Into<String>,
{
    let url = reqwest::Url::parse(&url.into()).unwrap();
    let filename = url.path_segments().unwrap().next_back().unwrap();
    let filepath = std::env::temp_dir().join(filename);
    let mut file = if filepath.exists() {
        std::fs::remove_file(&filepath).unwrap();
        std::fs::File::create_new(&filepath).unwrap()
    } else {
        std::fs::File::create_new(&filepath).unwrap()
    };

    let (tx, rx) = tokio::sync::oneshot::channel();
    TOKIO.spawn(async move {
        let client = reqwest::Client::new();
        let bytes = client.get(url).send().await.unwrap().bytes().await.unwrap();
        file.write_all(&bytes).unwrap();
        tx.send(format!("file://{}", filepath.to_string_lossy()))
            .unwrap();
    });

    rx
}
