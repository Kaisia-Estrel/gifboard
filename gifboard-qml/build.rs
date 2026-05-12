use cxx_qt_build::{CxxQtBuilder, QmlModule};
use std::path::PathBuf;
use std::{env, fs};

fn main() {
    // println!("cargo:rerun-if-changed=src/myobject.rs");
    // println!("cargo:rerun-if-changed=qml/main.qml");
    // println!("cargo:rerun-if-changed=src/lib.rs");
    // println!("cargo:rerun-if-changed=build.rs");

    CxxQtBuilder::new_qml_module(QmlModule::new("com.estrel.gifboard").qml_file("qml/main.qml"))
        .qt_module("Network")
        .files(["src/myobject.rs"])
        .build();

    let manifest_dir = PathBuf::from(env::var("CARGO_MANIFEST_DIR").unwrap())
        .parent()
        .unwrap()
        .canonicalize()
        .unwrap();

    let cxxqt_modules = manifest_dir.join("target/cxxqt/qml_modules");
    let qmlls_ini = manifest_dir.join(".qmlls.ini");
    let contents = format!("[General]\nimportPaths={}", cxxqt_modules.to_string_lossy());
    fs::write(qmlls_ini, contents).expect("Failed to write .qmlls.ini");
}
