---
name: rust
description: General Rust conventions and best practices. Use when writing or reviewing Rust code.
---

# Rust Conventions

- Run `cargo fmt --check`, `cargo check`, and `cargo clippy` after edits.
- Run `cargo test` after logic changes.
- Prefer clear ownership and borrowing over unnecessary cloning.
- Use `Result` and `?` for recoverable errors.
- Avoid `unwrap()` and `expect()` outside tests or proven invariants.
- Use `anyhow` for application errors and `thiserror` for typed library errors.
