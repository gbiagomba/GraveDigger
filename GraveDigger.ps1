<#
.SYNOPSIS
  Securely find, package, and encrypt files of interest.

.DESCRIPTION
  Collects files by extension (and optional name filter) under a root folder,
  writes a manifest, compresses into a ZIP, and optionally encrypts the archive
  using AES-256 with PBKDF2 and random salt. Secure by default (no passwords on CLI).

.EXAMPLE
  ./GraveDigger.ps1 -Extension log -Output logs-archive -Root . -Encrypt

#>
[CmdletBinding(PositionalBinding = $false)]
param(
  [Parameter(Mandatory)][string]$Extension,
  [Parameter()][string]$NameFilter = '',
  [Parameter(Mandatory)][string]$Output,
  [Parameter()][string]$Root = '.',
  [Parameter()][string]$Manifest,
  [switch]$Encrypt
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Usage {
  @"
GraveDigger.ps1 - Secure file collector

Required:
  -Extension <string>   File extension to match (e.g., txt, log)
  -Output <string>      Output base name (without extension)

Optional:
  -NameFilter <string>  Case-insensitive name inclusion pattern
  -Root <string>        Search root (default: current directory)
  -Manifest <string>    Manifest file path (default: <EXT>-FILE-MANIFEST.txt)
  -Encrypt              Prompt for password and encrypt archive (AES-256)
"@
}

if (-not $PSBoundParameters.ContainsKey('Manifest')) {
  $Manifest = "${Extension}-FILE-MANIFEST.txt"
}

$Root = (Resolve-Path -LiteralPath $Root).Path
$outZip = Join-Path (Get-Location) ("{0}.zip" -f $Output)
$outEnc = "$outZip.enc"

Write-Host "Searching in: $Root"
Write-Host "Extension: *.$Extension"
if ($NameFilter) { Write-Host "Name filter: $NameFilter" }

# Gather files
$filter = "*.{0}" -f $Extension
$files = Get-ChildItem -LiteralPath $Root -Recurse -File -Filter $filter -ErrorAction SilentlyContinue
if ($NameFilter) {
  $files = $files | Where-Object { $_.Name -match [regex]::Escape($NameFilter) }
}

if (-not $files -or $files.Count -eq 0) {
  throw "No files matched criteria."
}

# Manifest
Write-Host "Writing manifest to: $Manifest"
$files | ForEach-Object { $_.FullName } | Set-Content -LiteralPath $Manifest -NoNewline:$false -Encoding UTF8

# Create ZIP preserving relative paths
Write-Host ("Packaging {0} file(s) to: {1}" -f $files.Count, $outZip)
if (Test-Path -LiteralPath $outZip) { Remove-Item -LiteralPath $outZip -Force }

Add-Type -AssemblyName System.IO.Compression.FileSystem
using namespace System.IO
using namespace System.IO.Compression

$zipFileStream = [File]::Open($outZip, [FileMode]::CreateNew)
try {
  $zipArchive = New-Object System.IO.Compression.ZipArchive($zipFileStream, [ZipArchiveMode]::Create, $false)
  try {
    foreach ($f in $files) {
      $relPath = [IO.Path]::GetRelativePath($Root, $f.FullName)
      # Normalize to forward slashes for cross-platform zip readers
      $entryName = $relPath -replace '\\','/'
      [void]$zipArchive.CreateEntryFromFile($f.FullName, $entryName, [CompressionLevel]::Optimal)
    }
  }
  finally {
    $zipArchive.Dispose()
  }
}
finally {
  $zipFileStream.Dispose()
}

if ($Encrypt) {
  # Prompt for password securely
  $secure = Read-Host -AsSecureString -Prompt 'Enter encryption password'
  if (-not $secure) { throw 'No password provided.' }

  function ConvertTo-PlainText([Security.SecureString]$s) {
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($s)
    try { [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
  }

  $pwd = ConvertTo-PlainText $secure

  Write-Host "Encrypting archive (AES-256, PBKDF2, salt) to: $outEnc"
  if (Test-Path -LiteralPath $outEnc) { Remove-Item -LiteralPath $outEnc -Force }

  Add-Type -TypeDefinition @"
using System;
using System.IO;
using System.Security.Cryptography;
public static class GdCrypto {
  public static void Encrypt(string inPath, string outPath, string password) {
    using var rng = RandomNumberGenerator.Create();
    byte[] salt = new byte[16];
    rng.GetBytes(salt);
    using var kdf = new Rfc2898DeriveBytes(password, salt, 200000, HashAlgorithmName.SHA256);
    using var aes = Aes.Create();
    aes.KeySize = 256; aes.BlockSize = 128; aes.Mode = CipherMode.CBC; aes.Padding = PaddingMode.PKCS7;
    aes.Key = kdf.GetBytes(32);
    aes.IV = kdf.GetBytes(16);
    using var fin = File.OpenRead(inPath);
    using var fout = File.Open(outPath, FileMode.CreateNew, FileAccess.Write, FileShare.None);
    // Header: magic(6) + salt(16) + iv(16)
    byte[] magic = System.Text.Encoding.ASCII.GetBytes("GDENC1");
    fout.Write(magic, 0, magic.Length);
    fout.Write(salt, 0, salt.Length);
    fout.Write(aes.IV, 0, aes.IV.Length);
    using var crypto = new CryptoStream(fout, aes.CreateEncryptor(), CryptoStreamMode.Write);
    fin.CopyTo(crypto);
    crypto.FlushFinalBlock();
  }
}
"@

  [GdCrypto]::Encrypt($outZip, $outEnc, $pwd)
  # Remove plaintext archive after successful encryption
  Remove-Item -LiteralPath $outZip -Force
}

Write-Host "Done. Manifest at $Manifest"
