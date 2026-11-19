<#
.SYNOPSIS
    Publishes a DocView Capture release to the private GitHub releases repository (UPD-01..UPD-04).

.DESCRIPTION
    1. Signs DocView Setup and the web installer with Dev Soft UK's code-signing certificate (the licence key k2026;
       'docview-licence codesign-cert' once per Windows account), unless they already carry that signature.
    2. Checks both signatures: intact and made with the pinned key (the same rule as the updater and installer).
    3. Splits Setup into parts (GitHub allows 2 GB per file), with a SHA-256 for each part and for the whole file.
    4. Writes latest.json: version, channel, date, release notes (the CHANGELOG section), free space needed, the Setup
       and its parts, and the web installer ("bootstrapper").
    5. Creates the GitHub release v<version> and uploads the parts, DocViewCaptureInstaller.exe, the public certificate
       and, last, latest.json (an existing release is updated with --clobber).
    Customers never download from GitHub directly: the DocView download service (https://docviewcapture.azurewebsites.net/get/...)
    hands out short-lived links, and only for a valid licence or a new-installation ticket.

.EXAMPLE
    ./tools/publish-release.ps1 -Version 1.13.4 -BootstrapperPath dist\installer\web\DocViewCaptureInstaller.exe
#>
[CmdletBinding()]
param(
    [string]$Version = ([xml](Get-Content (Join-Path $PSScriptRoot '..\Directory.Build.props'))).Project.PropertyGroup[0].Version,
    [string]$SetupPath,
    [Parameter(Mandatory)] [string]$BootstrapperPath,
    [string]$Repository = 'devsoft-uk/DocViewCaptureSetup',
    [long]$PartSize = 500MB,
    [switch]$Beta,
    [switch]$SkipUpload
)
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if (-not $SetupPath) { $SetupPath = Join-Path $root "dist\installer\$Version\DocViewCapture-Setup-$Version-offline.exe" }
$SetupPath = [IO.Path]::GetFullPath($SetupPath)
$BootstrapperPath = [IO.Path]::GetFullPath($BootstrapperPath)
$licenceTool = Join-Path $root 'dist\tools\docview-licence.exe'
$gh = Join-Path $env:LOCALAPPDATA 'Programs\gh\bin\gh.exe'
if (-not (Test-Path $gh)) { $gh = 'gh' }
# Dev Soft UK's key (k2026) as Windows shows a signer's public key: the pin of DocView.Update.Core and the update task.
$pinned = '040c837ff2a5fe6f4fba46f8f5845d5b2d2a6e377d2f70a8b0ef19dda7a2634e45b05f056e9f4c7b7a0cc6c087fbf2d4daf11e64a29ddaa7ecba4fb2160b93362e'

function Test-DevSoftSignature([string] $path) {
    $sig = Get-AuthenticodeSignature -LiteralPath $path
    if ($sig.Status -in 'NotSigned', 'HashMismatch', 'NotSupportedFileFormat', 'Incompatible' -or -not $sig.SignerCertificate) { return $false }
    $key = ($sig.SignerCertificate.PublicKey.EncodedKeyValue.RawData | ForEach-Object { $_.ToString('x2') }) -join ''
    return $key -eq $pinned
}

foreach ($file in $SetupPath, $BootstrapperPath) {
    if (-not (Test-Path $file)) { throw "$file is missing." }
    if (-not (Test-DevSoftSignature $file)) {
        Write-Host "== signing $([IO.Path]::GetFileName($file))"
        & $licenceTool sign $file --description $(if ($file -eq $SetupPath) { 'DocView Capture Setup' } else { 'DocView Capture Installer' })
        if ($LASTEXITCODE -ne 0) { throw "$file could not be signed: run '$licenceTool codesign-cert' once on this Windows account." }
    }
    if (-not (Test-DevSoftSignature $file)) { throw "$file is not signed with Dev Soft UK's key." }
}
Write-Host '== signatures checked'

$out = Join-Path $root "dist\release\$Version"
if (Test-Path $out) { Remove-Item $out -Recurse -Force }
New-Item -ItemType Directory -Force $out | Out-Null
$setupName = [IO.Path]::GetFileName($SetupPath)
$parts = @()
$buffer = New-Object byte[] (4MB)
$reader = [IO.File]::OpenRead($SetupPath)
try {
    $index = 0
    while ($reader.Position -lt $reader.Length) {
        $index++
        $name = '{0}.part{1:000}' -f $setupName, $index
        $path = Join-Path $out $name
        $output = [IO.File]::Create($path)
        try {
            $left = [Math]::Min($PartSize, $reader.Length - $reader.Position)
            while ($left -gt 0) {
                $read = $reader.Read($buffer, 0, [int][Math]::Min($buffer.Length, $left))
                $output.Write($buffer, 0, $read)
                $left -= $read
            }
        } finally { $output.Dispose() }
        $parts += [ordered]@{ name = $name; size = (Get-Item $path).Length; sha256 = (Get-FileHash $path -Algorithm SHA256).Hash.ToLowerInvariant() }
    }
} finally { $reader.Dispose() }
Write-Host "== $($parts.Count) part(s)"

# The release notes: this version's CHANGELOG section.
$changelog = Get-Content (Join-Path $root 'CHANGELOG.md') -Raw -Encoding UTF8
$notes = if ($changelog -match "(?ms)^## $([regex]::Escape($Version))[^\n]*\n(.*?)(?=^## |\z)") { $Matches[1].Trim() } else { "DocView Capture $Version" }
$setupSize = (Get-Item $SetupPath).Length
$signer = (Get-AuthenticodeSignature -LiteralPath $SetupPath).SignerCertificate.Thumbprint
$bootstrapperVersion = (Get-Item $BootstrapperPath).VersionInfo.ProductVersion
$manifest = [ordered]@{
    version = $Version
    channel = $(if ($Beta) { 'beta' } else { 'stable' })
    publishedAt = (Get-Date).ToUniversalTime().ToString('o')
    releaseNotes = $notes
    requiredFreeSpaceBytes = [long]($setupSize * 3)
    setup = [ordered]@{ fileName = $setupName; size = $setupSize; sha256 = (Get-FileHash $SetupPath -Algorithm SHA256).Hash.ToLowerInvariant(); signerThumbprint = $signer; parts = $parts }
    bootstrapper = [ordered]@{ fileName = 'DocViewCaptureInstaller.exe'; version = $bootstrapperVersion; size = (Get-Item $BootstrapperPath).Length; sha256 = (Get-FileHash $BootstrapperPath -Algorithm SHA256).Hash.ToLowerInvariant() }
}
$latest = Join-Path $out 'latest.json'
[IO.File]::WriteAllText($latest, ($manifest | ConvertTo-Json -Depth 6), (New-Object Text.UTF8Encoding $false))
Copy-Item $BootstrapperPath (Join-Path $out 'DocViewCaptureInstaller.exe')
$cer = Join-Path $out 'DevSoftUK-CodeSigning.cer'
[IO.File]::WriteAllBytes($cer, (Get-AuthenticodeSignature -LiteralPath $SetupPath).SignerCertificate.Export('Cert'))
$notesFile = Join-Path $out 'release-notes.md'
[IO.File]::WriteAllText($notesFile, $notes, (New-Object Text.UTF8Encoding $false))
Write-Host "== latest.json written ($out)"
if ($SkipUpload) { return }

$tag = "v$Version"
& $gh release view $tag --repo $Repository *> $null
if ($LASTEXITCODE -ne 0) {
    $flags = @('release', 'create', $tag, '--repo', $Repository, '--title', "DocView Capture $Version", '--notes-file', $notesFile)
    if ($Beta) { $flags += '--prerelease' } else { $flags += '--latest' }
    & $gh @flags
    if ($LASTEXITCODE -ne 0) { throw 'The GitHub release could not be created.' }
}
foreach ($part in $parts) {
    & $gh release upload $tag (Join-Path $out $part.name) --repo $Repository --clobber
    if ($LASTEXITCODE -ne 0) { throw "Upload of $($part.name) failed." }
}
& $gh release upload $tag (Join-Path $out 'DocViewCaptureInstaller.exe') $cer --repo $Repository --clobber
if ($LASTEXITCODE -ne 0) { throw 'Upload of the web installer failed.' }
# latest.json last: until it is there, the release is not offered.
& $gh release upload $tag $latest --repo $Repository --clobber
if ($LASTEXITCODE -ne 0) { throw 'Upload of latest.json failed.' }
Write-Host "== published $tag to $Repository"
