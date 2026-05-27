use std::io;
use reqwest::Url;
use serde::{Deserialize, Serialize};

use crate::{
    config,
    query::fetch::{Attachment, AttachmentType},
};

#[derive(Serialize, Deserialize, Debug)]
pub(crate) struct KlippyResponseFileInfo {
    pub url: String,
    pub width: usize,
    pub height: usize,
    pub size: usize,
}

#[derive(Serialize, Deserialize, Debug)]
pub(crate) struct KlippyResponseFileTypes {
    pub gif: KlippyResponseFileInfo,
    pub webp: KlippyResponseFileInfo,
    pub jpg: KlippyResponseFileInfo,
    pub mp4: KlippyResponseFileInfo,
    pub webm: KlippyResponseFileInfo,
}

#[derive(Serialize, Deserialize, Debug)]
pub(crate) struct KlippyResponseFileQualities {
    pub hd: KlippyResponseFileTypes,
    pub md: KlippyResponseFileTypes,
    pub sm: KlippyResponseFileTypes,
    pub xs: KlippyResponseFileTypes,
}

#[derive(Serialize, Deserialize, Debug)]
pub(crate) struct KlippyResponseResult {
    pub id: u64,
    pub file: KlippyResponseFileQualities,
    pub slug: String,
    pub title: String,
    #[serde(rename = "type")]
    pub result_type: String,
    pub blur_preview: String,
}

#[derive(Serialize, Deserialize, Debug)]
pub(crate) struct KlippyResponseData {
    pub data: Vec<KlippyResponseResult>,
    pub current_page: usize,
    pub per_page: usize,
    pub has_next: bool,
}

#[derive(Serialize, Deserialize, Debug)]
pub(crate) struct KlippyResponse {
    pub result: bool,
    pub data: KlippyResponseData,
}

fn attachment_from_result(
    res: KlippyResponseResult,
    config: &config::Config,
) -> io::Result<Attachment> {
    let preview_uri = match config.preview_quality {
        config::ImageQuality::High if config.play_preview => {
            AttachmentType::Url(res.file.hd.webp.url.clone())
        }
        config::ImageQuality::High => AttachmentType::Url(res.file.hd.jpg.url.clone()),

        config::ImageQuality::Medium if config.play_preview => {
            AttachmentType::Url(res.file.sm.webp.url.clone())
        }
        config::ImageQuality::Medium => AttachmentType::Url(res.file.sm.jpg.url.clone()),

        config::ImageQuality::Low if config.play_preview => {
            AttachmentType::Url(res.file.xs.webp.url.clone())
        }
        config::ImageQuality::Low => AttachmentType::RawJpg,
    };
    let hover_uri = if config.disable_hover {
        None
    } else {
        Some(match config.hover_quality {
            config::ImageQuality::High if config.play_hover => {
                AttachmentType::Url(res.file.hd.webp.url.clone())
            }
            config::ImageQuality::High => AttachmentType::Url(res.file.hd.jpg.url.clone()),

            config::ImageQuality::Medium if config.play_hover => {
                AttachmentType::Url(res.file.md.webp.url.clone())
            }
            config::ImageQuality::Medium => AttachmentType::Url(res.file.md.jpg.url.clone()),

            config::ImageQuality::Low if config.play_hover => {
                AttachmentType::Url(res.file.sm.webp.url.clone())
            }
            config::ImageQuality::Low => AttachmentType::Url(res.file.sm.jpg.url.clone()),
        })
    };

    let output = match config.output_filetype {
        config::Filetype::Gif => res.file.hd.gif,
        config::Filetype::Webp => res.file.hd.webp,
        config::Filetype::Jpg => res.file.hd.jpg,
        config::Filetype::Mp4 => res.file.hd.mp4,
        config::Filetype::Webm => res.file.hd.webm,
    };

    Ok(Attachment {
        output_uri: AttachmentType::Url(output.url),
        hover_uri,
        preview_uri,
        blur_preview: res.blur_preview,
        height: output.height,
        width: output.width,
    })
}

pub(crate) async fn fetch_from_klippy(
    config: &config::Config,
    page: usize,
    query: &str,
) -> std::io::Result<Vec<Attachment>> {
    if let Some(api_key) = config.klippy_api_key.as_ref() {
        let params = [
            ("q", query),
            ("page", &page.to_string()),
            ("per_page", "30"),
        ];
        let client = reqwest::Client::new();
        let url = Url::parse_with_params(
            &format!("https://api.klipy.com/api/v1/{api_key}/gifs/search"),
            &params,
        )
        .map_err(|e| std::io::Error::other(format!("{e}")))?;
        let response_text = client
            .get(url)
            .send()
            .await
            .map_err(|e| std::io::Error::other(format!("{e}")))?
            .text()
            .await
            .map_err(|e| std::io::Error::other(format!("{e}")))?;

        let response: KlippyResponse = serde_json::from_str(&response_text)?;

        if !response.result {
            return Err(std::io::Error::other("Error in Klippy response"));
        }

        Ok(response
            .data
            .data
            .into_iter()
            .map(|res| attachment_from_result(res, config))
            .collect::<io::Result<_>>()?)
    } else {
        Ok(vec![])
    }
}
