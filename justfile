set shell := ["nu", "-c"]
set script-interpreter := ["nu"]
set dotenv-load
set unstable

shebang := if os() == 'windows' {
    'nu.exe'
} else {
    '/usr/bin/env nu'
}

download_dir := "_downloads"

default:
    just --list

download_deps: _download_parg && (_extract_file "parg-1.0.3.zip")

[script]
_download_parg:
    if not ("{{download_dir}}/parg-1.0.3.zip" | path exists) {
        mkdir {{download_dir}}
        curl -LJ https://github.com/jibsen/parg/archive/refs/tags/v1.0.3.zip -o "{{download_dir}}/parg-1.0.3.zip"
    } else {
        echo "File already exists"
    }

[script]
_extract_file file:
    let filepath = "{{download_dir}}/{{file}}"
    let extract_dir = "{{file}}" | path parse | get stem
    if not ($"{{download_dir}}/($extract_dir)" | path exists) {
        match ("{{file}}" | path parse | get extension) {
            "zip" => {
                7z x -y $filepath -o{{download_dir}}
            }
            _ => {
                7z x -y $filepath -o{{download_dir}}
            }
        }
    } else {
        echo $"Directory {{download_dir}}/($extract_dir) already exists"
    }
