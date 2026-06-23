# PC Health Check

A privacy-first, read-only Windows diagnostic tool for helpers, family IT support, community volunteers, and small repair shops.

The tool collects basic performance and system signals, then writes a plain text report and a JSON report to the current user's Desktop. It does not delete files, change settings, disable startup items, install software, or upload data.

## Why This Exists

Many non-technical users describe every computer issue as "slow". Helpers often need a safe first-pass report before deciding whether the problem is CPU load, memory pressure, disk space, startup items, Windows Update, antivirus conflicts, browser extensions, or old hardware.

This project is designed to make that first pass safer:

- read-only by default;
- no network calls;
- no telemetry;
- clear consent text;
- plain text output that a non-expert can read;
- JSON output for maintainers who want to build automation later.

## Quick Start

1. Download or clone this repository on a Windows PC.
2. Double-click `run-pc-health-check.cmd`.
3. Wait for the report to finish.
4. Open the generated `PC-Health-Report-*.txt` file on the Desktop.

PowerShell alternative:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\pc-health-check.ps1 -OpenReport
```

For reports that may be shared outside the device owner's private support
conversation, run with identity redaction:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\pc-health-check.ps1 -RedactIdentity -OpenReport
```

Optional HTML report:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\pc-health-check.ps1 -RedactIdentity -HtmlReport -OpenReport
```

Chinese helper docs:

- [中文快速开始](docs/zh-CN/quick-start.md)
- [报告分享与隐私检查](docs/zh-CN/report-sharing.md)

## What It Collects

- Windows version, uptime, device model, and admin status.
- CPU load, memory usage, disk free space, and disk activity.
- Top memory processes.
- Startup item count and names.
- Running automatic services, limited to a capped list.
- Antivirus and Windows Defender status.
- Windows Update service status and recent hotfixes.
- Pending reboot signals.
- Chrome and Edge extension counts and extension IDs.
- Approximate temporary folder size with a file scan limit.

## Report Formats

The script always writes a plain text report and a JSON report. Use
`-HtmlReport` to also write a local HTML report for easier reading by
non-technical helpers. The HTML report is self-contained: it uses inline styles,
no JavaScript, no external assets, and no network calls.

## Privacy Notes

Reports may contain local device information such as computer name, Windows username, startup command paths, process names, device model, and browser extension IDs. Review a report before sharing it publicly.

Use `-RedactIdentity` when a report may be shared in an issue, chat, email, or
other place outside the device owner's private support conversation. In this
mode the script redacts the computer name, Windows username, known user profile
paths, temporary folder paths, startup command user, browser extension IDs,
local identity paths found inside registry policy values, and console output
paths. It keeps counts and diagnostic signals where possible.

The script intentionally avoids collecting:

- documents, photos, browser history, cookies, passwords, chat logs, or payment data;
- file contents;
- environment variables;
- registry secrets;
- network uploads.

## Safety Boundaries

This tool is diagnostic only. After reading the report, a human should decide what to do next. Do not delete files, disable startup items, uninstall software, reset browsers, or change security settings without explicit user confirmation.

## Project Roadmap

- Add report redaction mode.
- Add localized report templates.
- Add HTML report output.
- Add optional signed release artifacts.
- Add tests for report formatting logic.
- Add issue templates for false positives and privacy concerns.

## License

MIT
