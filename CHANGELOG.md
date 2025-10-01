# Changelog

All notable changes to this project will be documented in this file.

## v3.0.0 - 2025-10-01

- Rewrite `GraveDigger.sh` with secure defaults, robust CLI flags, and AES‑256 encryption (OpenSSL, PBKDF2, salt).
- Add cross-platform `GraveDigger.ps1` with .NET AES‑256 encryption and manifest support.
- Replace `locate/updatedb` dependency with portable `find`.
- Add Makefile, Dockerfile, updated README, and .gitignore.
- Add GitHub Actions CI: test on Linux/macOS/Windows; publish artifacts on tags.
