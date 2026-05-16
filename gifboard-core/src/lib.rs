use std::sync::LazyLock;

pub mod config;
pub mod query;

pub static TOKIO: LazyLock<tokio::runtime::Runtime> =
    LazyLock::new(|| tokio::runtime::Runtime::new().expect("Failed to create tokio runtime"));
