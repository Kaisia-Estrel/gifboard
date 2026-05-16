use cxx_qt::casting::Upcast;
use cxx_qt_lib::QGuiApplication;
use cxx_qt_lib::QQmlApplicationEngine;
use cxx_qt_lib::QQmlEngine;
use cxx_qt_lib::QUrl;
use std::pin::Pin;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    gifboard_qml::register_types();
    let config_path = xdg::BaseDirectories::new().place_config_file("gifboard.json")?;
    if !config_path.exists() {
        eprintln!(
            "No config file found, creating one at {}",
            config_path.display()
        );
        gifboard_core::config::create_base_config()?;
    }

    // return Ok(());

    let mut app = QGuiApplication::new();
    let mut engine = QQmlApplicationEngine::new();

    // Load the QML path into the engine
    if let Some(engine) = engine.as_mut() {
        engine.load(&QUrl::from("qrc:/qt/qml/com/estrel/gifboard/qml/main.qml"));
    }

    if let Some(engine) = engine.as_mut() {
        let engine: Pin<&mut QQmlEngine> = engine.upcast_pin();
        // Listen to a signal from the QML Engine
        engine
            .on_quit(|_| {
                println!("QML Quit!");
            })
            .release();
    }

    // Start the app
    if let Some(app) = app.as_mut() {
        app.exec();
    }
    Ok(())
}
