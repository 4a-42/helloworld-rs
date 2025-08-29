extern crate bindgen;
extern crate cc;

use std::{env, path::PathBuf};

const CARGO_MANIFEST_DIR: &'static str = env!("CARGO_MANIFEST_DIR");

fn main() {
    cc::Build::new()
        .file(format!("{CARGO_MANIFEST_DIR}/_downloads/parg-1.0.3/parg.c"))
        .compile("parg");
    println!("cargo:rustc-link-lib=static=parg");

    let bindings = bindgen::Builder::default()
        .header(format!("{CARGO_MANIFEST_DIR}/_downloads/parg-1.0.3/parg.h"))
        .parse_callbacks(Box::new(bindgen::CargoCallbacks::new()))
        .generate()
        .expect("Unable to generate bindings");
    let out_path = PathBuf::from(env::var("OUT_DIR").unwrap());
    bindings
        .write_to_file(out_path.join("parg.rs"))
        .expect("Couldn't write bindings!");
}
