#!/usr/bin/env sh
# Author: Gilles Biagomba
# Program: GraveDigger.sh
# Description: Securely find, package, and encrypt files of interest.

set -eu
# Fail pipelines if any command fails
set -o pipefail

usage() {
  cat <<USAGE
GraveDigger - Secure file collector

Usage: $(basename "$0") -t EXT [-k NAME_FILTER] -o OUTPUT [-r ROOT] [-m MANIFEST] [-p]

Options:
  -t EXT         File extension to match (e.g., txt, log)
  -k PATTERN     Optional case-insensitive name filter (glob/grep-like)
  -o OUTPUT      Output base name (without extension)
  -r ROOT        Search root directory (default: current directory)
  -m MANIFEST    Manifest file path (default: <EXT>-FILE-MANIFEST.txt)
  -p             Prompt for an encryption password (AES-256, PBKDF2). If omitted, no encryption.
  -h             Show this help and exit

Behavior:
  - Collects matching files using find (no dependency on locate/updatedb).
  - Creates a compressed tarball (.tar.gz) of collected files.
  - If -p is provided, encrypts the tarball to OUTPUT.tar.gz.enc using OpenSSL AES-256 with PBKDF2 and salt.
USAGE
}

# Defaults
FTYPE=""
FILTER=""
OUTBASE=""
ROOT="."
MANIFEST=""
ENCRYPT=0

# Parse options
while getopts ":t:k:o:r:m:ph" opt; do
  case "$opt" in
    t) FTYPE="$OPTARG" ;;
    k) FILTER="$OPTARG" ;;
    o) OUTBASE="$OPTARG" ;;
    r) ROOT="$OPTARG" ;;
    m) MANIFEST="$OPTARG" ;;
    p) ENCRYPT=1 ;;
    h) usage; exit 0 ;;
    :) echo "Error: Option -$OPTARG requires an argument" >&2; usage; exit 2 ;;
    \?) echo "Error: Invalid option -$OPTARG" >&2; usage; exit 2 ;;
  esac
done

if [ -z "$FTYPE" ] || [ -z "$OUTBASE" ]; then
  echo "Error: -t and -o are required" >&2
  usage
  exit 2
fi

if [ -z "$MANIFEST" ]; then
  MANIFEST="${FTYPE}-FILE-MANIFEST.txt"
fi

# Resolve absolute output paths
OUT_TGZ="$(pwd)/${OUTBASE}.tar.gz"
OUT_ENC="${OUT_TGZ}.enc"

# Collect files
echo "Searching in: $ROOT"
echo "Extension: *.$FTYPE"
if [ -n "$FILTER" ]; then echo "Name filter: $FILTER"; fi

# Build find expression
if [ -n "$FILTER" ]; then
  FIND_CMD="find \"$ROOT\" -type f -iname '*.$FTYPE' -iname "
fi

# Generate list safely
tmp_list="$(mktemp)"
trap 'rm -f "$tmp_list"' EXIT INT TERM HUP

if [ -n "$FILTER" ]; then
  # Filter by name (case-insensitive)
  # Using POSIX find with -iname twice: restrict by ext then by FILTER glob
  # Convert FILTER to case-insensitive regex via grep -i on path
  # shellcheck disable=SC2039
  find "$ROOT" -type f \( -iname "*.${FTYPE}" -a -iname "*${FILTER}*" \) -print | sed 's#//#/#g' > "$tmp_list"
else
  find "$ROOT" -type f -iname "*.${FTYPE}" -print | sed 's#//#/#g' > "$tmp_list"
fi

COUNT=$(wc -l < "$tmp_list" | tr -d ' ')
if [ "$COUNT" = "0" ]; then
  echo "No files matched criteria." >&2
  exit 1
fi

# Create manifest
printf '' > "$MANIFEST"
echo "Writing manifest to: $MANIFEST"
cat "$tmp_list" > "$MANIFEST"

echo "Packaging $COUNT file(s) to: $OUT_TGZ"
tar -czf "$OUT_TGZ" -T "$tmp_list"

if [ "$ENCRYPT" -eq 1 ]; then
  echo "Encrypting archive (AES-256, PBKDF2, salt) to: $OUT_ENC"
  # Prompt for password securely
  printf "Enter encryption password: "
  # POSIX sh: use stty to disable echo if available
  if command -v stty >/dev/null 2>&1; then
    saved_stty_state=$(stty -g)
    stty -echo
    # shellcheck disable=SC2162
    read PASS
    stty "$saved_stty_state"
    echo
  else
    # shellcheck disable=SC2162
    read PASS
  fi
  if [ -z "$PASS" ]; then
    echo "No password provided; skipping encryption." >&2
  else
    # Use OpenSSL enc with PBKDF2, pass over FD 3 to avoid argv/env exposure
    # shellcheck disable=SC3037
    exec 3<<<"$PASS"
    if openssl enc -aes-256-cbc -pbkdf2 -salt -pass fd:3 -in "$OUT_TGZ" -out "$OUT_ENC"; then
      echo "Encrypted file: $OUT_ENC"
      # Optionally remove plaintext archive after successful encryption
      rm -f "$OUT_TGZ"
    else
      echo "Encryption failed." >&2
      exit 1
    fi
    # Close FD 3
    exec 3<&-
  fi
fi

echo "Done. Manifest at $MANIFEST"
exit 0
