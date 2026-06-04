use std::{env, fs, path::PathBuf};

use cxx_qt_build::{CxxQtBuilder, QmlModule};

fn main() {
    let manifest_dir = PathBuf::from(env::var("CARGO_MANIFEST_DIR").unwrap())
        .parent()
        .unwrap()
        .canonicalize()
        .unwrap();

    println!("cargo::rerun-if-env-changed=PKG_CONFIG_PATH");
    pkg_config::Config::new().atleast_version("6.11").probe("Qt6Core").unwrap();

    unsafe {
        #[cfg(not(debug_assertions))]
        let builder = {
            CxxQtBuilder::new_qml_module(QmlModule::new("com.estrel.gifboard").qml_files([
                "qml/main.qml",
                "qml/PreviewImage.qml",
                "qml/GifBrowser.qml",
            ]))
        };

        #[cfg(debug_assertions)]
        let builder = {
            CxxQtBuilder::new_qml_module(
                QmlModule::new("com.estrel.gifboard").qml_files(["qml/main.qml"]),
            )
        };

        builder
            .qt_module("Network")
            .qt_module("Gui")
            .files([
                "src/search_results.rs",
                "src/x11_manager.rs",
                "src/clipboard.rs",
                "src/notification.rs",
            ])
            .cpp_file("src/x11_filter.h")
            .cpp_file("src/x11_filter.cpp")
            .cpp_file("src/keysym_to_QTKey.cpp")
            .cpp_file("src/keysym_to_QTKey.h")
            .cpp_file("src/clipboard.h")
            .cc_builder(|cc| {
                cc.flag_if_supported("-std=c++20");
            })
            .build();
    }

    let cxxqt_modules = manifest_dir.join("target/cxxqt/qml_modules");
    let qmlls_ini = manifest_dir.join(".qmlls.ini");
    let contents = format!(
        "
[General]
importPaths={0}
buildDir={0}
no-cmake-calls=true
        ",
        cxxqt_modules.to_string_lossy()
    );
    fs::write(qmlls_ini, contents).expect("Failed to write .qmlls.ini");
}
