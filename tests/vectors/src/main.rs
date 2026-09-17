//! Generates `components/hash/HashVectors.roc` and `tests/layout/expected`.

use std::path::PathBuf;

fn main() {
    std::fs::write(vectors_path(), trantor_hash_vectors::render()).expect("write HashVectors.roc");
    std::fs::write(layout_path(), trantor_hash_vectors::layout::expected()).expect("write tests/layout/expected");
}

fn layout_path() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../layout/expected")
}

fn vectors_path() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../../components/hash/HashVectors.roc")
}
