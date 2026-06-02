use cxx_qt::casting::Upcast;
use cxx_qt_lib::QGuiApplication;
use cxx_qt_lib::QQmlApplicationEngine;
use cxx_qt_lib::QQmlEngine;
use cxx_qt_lib::QString;
use cxx_qt_lib::QUrl;
use std::pin::Pin;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    gifboard_qml::register_types();

    // return Ok(());

    let mut app = QGuiApplication::new();
    let mut engine = QQmlApplicationEngine::new();

    // Load the QML path into the engine
    if let Some(engine) = engine.as_mut() {
        // Direct loading of the QML file to avoid repeated recompiling of `gifboard-qml`
        #[cfg(debug_assertions)]
        {
            let gifboard_app_dir = std::path::PathBuf::from(env!("CARGO_MANIFEST_DIR"));
            let cargo_dir = gifboard_app_dir.parent().unwrap();
            let untracked_dir = &cargo_dir.join("untracked");

            if !untracked_dir.exists() {
                eprintln!("untracked/ doesnt exist, creating...");
                std::fs::create_dir(&untracked_dir).unwrap();
            }

            let untracked_file = move |file: &str, untracked: &str| {
                let file = cargo_dir.join(file);
                let untracked_path = untracked_dir.join(untracked);

                if !untracked_path.exists() {
                    eprintln!(
                        "'{}' doesnt exist, creating...",
                        untracked_path.to_string_lossy()
                    )
                }
                std::fs::copy(file, untracked_path).expect("Failed to copy to untracked path");
            };
            untracked_file("gifboard-qml/qml/main.qml", "main.qml");

            engine.load(&QUrl::from_local_file(&QString::from(
                untracked_dir.join("main.qml").to_str().unwrap(),
            )));
        }
        #[cfg(not(debug_assertions))]
        {
            engine.load(&QUrl::from("qrc:/qt/qml/com/estrel/gifboard/qml/main.qml"));
        }
    }

    if gifboard_qml::x11_manager::on_x11() {
        unsafe {
            gifboard_qml::x11_manager::ffi::install_x11_event_filter();
        }
    }

    if let Some(engine) = engine.as_mut() {
        let engine: Pin<&mut QQmlEngine> = engine.upcast_pin();
        // Listen to a signal from the QML Engine
        engine
            .on_quit(|_| {
                println!("QML Quit!");
                unsafe { gifboard_qml::x11_manager::ffi::delete_x11_event_filter() };
            })
            .release();
    }

    // Start the app
    if let Some(app) = app.as_mut() {
        app.exec();
    }
    Ok(())
}
