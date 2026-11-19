# Download DocView Capture — website integration

For the person who manages the DocView demo website. Nothing on the website needs to change when a new version comes
out: the link below always gives the newest stable version.

## 1. The download button

Point the **Download DocView Capture** button at:

```
https://docviewcapture.azurewebsites.net/get/DocViewCaptureInstaller.exe
```

This is the small DocView Capture Installer (a few tens of MB). When the visitor runs it, it shows the newest version,
the licence agreement and the options, then downloads and installs DocView Capture itself.

## 2. "Latest version" line (copy and paste)

Shows "Latest version 1.13.4 – released 19 Nov 2026" next to the button, and stays as plain text if the call fails.

```html
<p id="dv-latest-version">The latest version of DocView Capture</p>
<script>
  (function () {
    var target = document.getElementById('dv-latest-version');
    fetch('https://docviewcapture.azurewebsites.net/get/latest.json')
      .then(function (r) { if (!r.ok) { throw new Error(r.status); } return r.json(); })
      .then(function (release) {
        var date = new Date(release.publishedAt).toLocaleDateString('en-GB', { day: 'numeric', month: 'short', year: 'numeric' });
        target.textContent = 'Latest version ' + release.version + ' \u2013 released ' + date;
      })
      .catch(function () { /* keep the plain text */ });
  })();
</script>
```

The address allows calls from any website (CORS), and its answer is cached for five minutes.

## 3. Suggested page text

> **Download DocView Capture**
>
> [System requirements: to be completed — e.g. Windows 10/11 or Windows Server 2019 or later, 64-bit, 8 GB RAM
> (16 GB recommended), 20 GB free disk space.]
>
> About 2 GB download – requires administrator rights.
>
> **IT teams:** need an offline installer? Run `DocViewCaptureInstaller.exe /layout:D:\DocViewSetup` to download and
> check the full setup into a folder, then install from there on computers without internet access.
> `/quiet` installs without questions.
>
> Questions? Call +44 7886 864921.

## 4. Windows SmartScreen

DocView Capture's installers are signed by Dev Soft UK Ltd with its own certificate. Windows does not know that
certificate yet, so SmartScreen may show "Windows protected your PC" (choose **More info › Run anyway**) or "Unknown
publisher" until the program builds a reputation. An EV code-signing certificate from a public certificate authority
avoids this warning from the first download.
