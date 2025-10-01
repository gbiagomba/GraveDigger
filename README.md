```
  ________                           ________  .__                            
 /  _____/___________ ___  __ ____   \______ \ |__| ____   ____   ___________ 
/   \  __\_  __ \__  \\  \/ // __ \   |    |  \|  |/ ___\ / ___\_/ __ \_  __ \
\    \_\  \  | \// __ \\   /\  ___/   |    `   \  / /_/  > /_/  >  ___/|  | \/
 \______  /__|  (____  /\_/  \___  > /_______  /__\___  /\___  / \___  >__|   
        \/           \/          \/          \/  /_____//_____/      \/       
```

GraveDigger securely searches for files, packages them, and optionally encrypts the archive for exfiltration or backup. This rewrite improves security, portability, and automation.

What's new in v3.0.0
- Secure by default: no plaintext passwords on the command line; AES‑256 + PBKDF2 + salt when encryption is enabled.
- No `locate/updatedb` dependency; uses `find` for portability.
- Non-interactive CLI flags; still supports interactive password prompt when requested.
- Cross-platform: POSIX shell script and a PowerShell port.
- CI builds/tests on Linux, macOS (x64/arm64), and Windows; releases on tags.

Usage (POSIX shell)
- Find and package `.log` files under current directory, write manifest, do NOT encrypt:
  `./GraveDigger.sh -t log -o logs-archive -r .`
- Same, but filter filenames containing "error" and encrypt the archive (prompts for password):
  `./GraveDigger.sh -t log -k error -o prod-errors -r /var/log -p`

Options (POSIX shell)
- `-t EXT`: File extension to match (e.g., `txt`, `log`).
- `-k PATTERN`: Optional case-insensitive name inclusion filter.
- `-o OUTPUT`: Output base name (no extension).
- `-r ROOT`: Search root directory (default: `.`).
- `-m MANIFEST`: Manifest file path (default: `<EXT>-FILE-MANIFEST.txt`).
- `-p`: Prompt for password and encrypt the tarball with AES‑256 (PBKDF2 + salt). Produces `<OUTPUT>.tar.gz.enc`.

Usage (PowerShell)
- Find and package `.txt` files under `C:\\Data`, filter names with `pii`, and encrypt:
  `./GraveDigger.ps1 -Extension txt -NameFilter pii -Output pii-dump -Root C:\\Data -Encrypt`

Artifacts
- Shell: outputs `<OUTPUT>.tar.gz` or `<OUTPUT>.tar.gz.enc` if encrypted.
- PowerShell: outputs `<OUTPUT>.zip` or `<OUTPUT>.zip.enc` if encrypted.
- Both produce a manifest listing collected files.

Docker
- Build: `docker build -t gravedigger:latest .`
- Run (read-only scan of `/data` inside container):
  `docker run --rm -v "$PWD:/data:ro" -w /data gravedigger:latest -t log -o logs -r /data`
  Add `-p` to enable encryption (password prompted in the container).

Makefile
- `make test`: Create sample files and run both scripts locally.
- `make package`: Create a release tarball containing scripts and docs.
- `make docker-build`: Build the Docker image.

Security Notes
- The shell script uses OpenSSL AES‑256 with PBKDF2 and salt. The password is read securely and not exposed via argv or environment.
- The PowerShell script uses .NET `Aes` with PBKDF2 and random salt. The plaintext archive is removed after successful encryption in both implementations.
- Decryption (shell): `openssl enc -d -aes-256-cbc -pbkdf2 -in <archive>.tar.gz.enc -out <archive>.tar.gz` then extract.
- Decryption (PowerShell): a complementary decrypt helper can be added on request.

Development
- CI runs on Linux, macOS (x64/arm64), and Windows. Pushing a tag like `v3.0.0` publishes a release with artifacts.
