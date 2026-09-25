<#
.SYNOPSIS
  make_deterministic_zip.ps1 -- byte-reproducible ZIP archives (USEFUL-2).

.DESCRIPTION
  Builds a .zip whose bytes depend only on the input file contents:
    * entries are emitted in ordinal-sorted relative-path order
    * every entry timestamp is fixed to the release epoch (SOURCE_DATE_EPOCH,
      normally the tagged commit's %ct)
    * paths are stored with forward slashes, no top-level directory is added
    * the archive comment, entry comments and external attributes are cleared

  Used by both the GitHub and the GitLab Windows packaging jobs so the two
  pipelines converge on one ZIP implementation (Compress-Archive embeds
  entry timestamps and sorts case-insensitively, so it cannot be made
  reproducible).

  Remaining known nondeterminism: the DEFLATE stream itself is produced by
  .NET and may differ between .NET major versions. Byte identity is
  guaranteed for a fixed runner image, not across arbitrary .NET upgrades.

.EXAMPLE
  pwsh scripts/make_deterministic_zip.ps1 -InputDir instdir -OutputPath release-assets/app.zip -Epoch 1700000000
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$InputDir,
    [Parameter(Mandatory = $true)][string]$OutputPath,
    [int]$Epoch = 0
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $InputDir -PathType Container)) {
    throw "make_deterministic_zip: input directory not found: $InputDir"
}
$inputRoot = (Resolve-Path -LiteralPath $InputDir).Path
$outDir = Split-Path -Path $OutputPath -Parent
if ($outDir -and -not (Test-Path -LiteralPath $outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}

if ($Epoch -le 0) {
    $envEpoch = $env:SOURCE_DATE_EPOCH
    if ($envEpoch -and $envEpoch -match '^\d+$') { $Epoch = [int]$envEpoch }
}
if ($Epoch -le 0) { $Epoch = 0 }

# ZIP timestamps cannot predate 1980-01-01.
$epochOffset = [TimeSpan]::FromSeconds($Epoch)
if ($epochOffset.TotalSeconds -lt 315532800) {
    $stamp = [DateTimeOffset]::new(1980, 1, 1, 0, 0, 0, [TimeSpan]::Zero)
} else {
    $stamp = [DateTimeOffset]::new(1970, 1, 1, 0, 0, 0, [TimeSpan]::Zero).Add($epochOffset)
}

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

# Ordinal (culture-independent) ordering: culture-based sorting can differ
# between .NET/ICU versions, which would break byte reproducibility.
$files = @(Get-ChildItem -LiteralPath $inputRoot -Recurse -File |
    ForEach-Object {
        $rel = $_.FullName.Substring($inputRoot.Length).TrimStart('\', '/') -replace '\\', '/'
        [pscustomobject]@{ Rel = $rel; Src = $_.FullName }
    })
[System.Array]::Sort($files, [System.Comparison[object]]{
    param($a, $b)
    [string]::CompareOrdinal($a.Rel, $b.Rel)
})

if (-not $files) { throw "make_deterministic_zip: no files found under $InputDir" }

$tmp = "$OutputPath.tmp"
if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force }

$zip = [System.IO.Compression.ZipFile]::Open($tmp, [System.IO.Compression.ZipArchiveMode]::Create)
try {
    foreach ($f in $files) {
        $entry = $zip.CreateEntry($f.Rel, [System.IO.Compression.CompressionLevel]::Optimal)
        $entry.LastWriteTime = $stamp
        $entry.ExternalAttributes = 0
        $entry.Comment = ''
        $src = [System.IO.File]::OpenRead($f.Src)
        try {
            $dst = $entry.Open()
            try { $src.CopyTo($dst) } finally { $dst.Dispose() }
        } finally { $src.Dispose() }
    }
    $zip.Comment = ''
} finally {
    $zip.Dispose()
}

Move-Item -LiteralPath $tmp -Destination $OutputPath -Force
Write-Host "make_deterministic_zip: wrote $OutputPath ($($files.Count) entries, epoch=$Epoch)"
