# DocView Capture — releases

Private. Installers only: every GitHub release here is one DocView Capture version (`v1.13.4`) with

- `DocViewCapture-Setup-<version>-offline.exe.partNNN` — DocView Setup in parts (GitHub allows 2 GB per file),
- `DocViewCaptureInstaller.exe` — the small web installer for new installations,
- `DevSoftUK-CodeSigning.cer` — the public code-signing certificate (Dev Soft UK's licence key k2026),
- `latest.json` — the release description read by the web installer and by DocView Capture's in-app updates.

Customers never download from this repository: the DocView download service on
https://docviewcapture.azurewebsites.net/get/ hands out short-lived links (Setup parts only with a valid DocView licence
or a new-installation ticket).

- Publishing a release: `tools/publish-release.ps1` (a copy of the one in the DocView Capture source repository; run it
  from there, after `tools/publish.ps1`, `tools/build-installer.ps1` and `tools/build-web-installer.ps1`).
- For the person who manages the DocView website: [docs/WEBSITE-INTEGRATION.md](docs/WEBSITE-INTEGRATION.md).
