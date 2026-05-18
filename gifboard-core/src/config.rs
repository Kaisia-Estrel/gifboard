use serde::{Deserialize, Serialize};
use std::io;
use std::io::Write;
use std::{fs::File, path::PathBuf};

#[derive(Debug, Serialize, Deserialize)]
pub enum ImageQuality {
    High,
    Medium,
    Low,
}

#[derive(Debug, Serialize, Deserialize)]
pub enum Filetype {
    Gif,
    Webp,
    Jpg,
    Mp4,
    Webm,
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(default)]
pub struct Config {
    pub klippy_api_key: Option<String>,
    pub attachment_paths: Vec<PathBuf>,
    pub saved_file_output: Option<PathBuf>,
    pub default_output_quality: ImageQuality,
    pub hover_quality: ImageQuality,
    pub preview_quality: ImageQuality,
    pub output_filetype: Filetype,
    pub play_preview: bool,
    pub play_hover: bool,
    pub disable_hover: bool,
}

impl Default for Config {
    fn default() -> Self {
        Self {
            klippy_api_key: None,
            attachment_paths: vec![],
            saved_file_output: None,
            default_output_quality: ImageQuality::High,
            hover_quality: ImageQuality::High,
            preview_quality: ImageQuality::Low,
            output_filetype: Filetype::Webp,
            play_preview: true,
            play_hover: true,
            disable_hover: false,
        }
    }
}

pub fn create_base_config() -> io::Result<()> {
    let config_path = xdg::BaseDirectories::new()
        .get_config_file("gifboard.json")
        .ok_or(io::Error::new(
            io::ErrorKind::NotFound,
            "XDG_CONFIG_HOME not set or ~/.config not found",
        ))?;
    let config_json = serde_json::to_string_pretty(&Config::default())?;
    let mut file = File::create(&config_path)?;
    file.write_all(config_json.as_bytes())
}

pub fn read_config() -> io::Result<Config> {
    let config_path = xdg::BaseDirectories::new()
        .get_config_file("gifboard.json")
        .ok_or(io::Error::new(
            io::ErrorKind::NotFound,
            "XDG_CONFIG_HOME not set or ~/.config not found",
        ))?;

    if !config_path.exists() {
        eprintln!(
            "No config file found, creating one at {}",
            config_path.display()
        );
        create_base_config()?;
    }

    let config_str = std::fs::read_to_string(&config_path)?;
    let config: Config = serde_json::from_str(&config_str).map_err(|err| {
        let error = format!(
            "Parse error when parsing config file: '{err}'\nEdit or Delete the file at '{}'",
            config_path.display()
        );
        io::Error::new(io::ErrorKind::InvalidInput, error)
    })?;
    Ok(config)
}
