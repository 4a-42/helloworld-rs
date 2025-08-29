#![allow(non_upper_case_globals)]
#![allow(non_camel_case_types)]
include!(concat!(env!("OUT_DIR"), "/parg.rs"));

fn main() {
    println!("Loaded clibrary parg version {PARG_VER_MAJOR}.{PARG_VER_MINOR}.{PARG_VER_PATCH}");
    println!("Hello, world!");
}
