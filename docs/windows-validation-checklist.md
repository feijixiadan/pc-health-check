# Windows Validation Checklist

Use this checklist when validating PC Health Check on real Windows 10 and
Windows 11 machines. Do not close the validation issue until at least one real
Windows 10 run and one real Windows 11 run have been recorded with sanitized
evidence.

## Scope

Validate that the script:

- runs without changing files, settings, startup items, services, browsers, or
  security settings;
- generates TXT and JSON reports by default;
- generates TXT, JSON, and HTML reports when `-HtmlReport` is explicitly used;
- keeps identity redaction effective when `-RedactIdentity` is used;
- gives helpers enough information to decide the next safe support step.

## Test Matrix

Record one row per machine.

| Field | Windows 10 | Windows 11 |
| --- | --- | --- |
| Windows edition and build |  |  |
| PowerShell version |  |  |
| Standard user or admin shell |  |  |
| Device type, such as laptop or desktop |  |  |
| Antivirus status visible in report |  |  |
| Browser extensions detected |  |  |
| `-RedactIdentity` used |  |  |
| `-HtmlReport` used |  |  |
| Result |  |  |

## Commands

Default report:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\pc-health-check.ps1
```

Redacted report for sharing:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\pc-health-check.ps1 -RedactIdentity
```

Redacted HTML report:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\pc-health-check.ps1 -RedactIdentity -HtmlReport
```

Optional open-after-run check:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\pc-health-check.ps1 -RedactIdentity -HtmlReport -OpenReport
```

## Expected Files

Default run:

- `PC-Health-Report-*.txt`
- `PC-Health-Report-*.json`

HTML run:

- `PC-Health-Report-*.txt`
- `PC-Health-Report-*.json`
- `PC-Health-Report-*.html`

The files should appear on the current user's Desktop. If Desktop cannot be
resolved, the script may fall back to the temporary folder.

## Report Checks

For each run, confirm:

- `Quick Findings`, `System`, `Performance`, `Drives`, `Startup Items`,
  `Antivirus`, `Windows Update`, `Browser Check`, `Temporary Folders`, and
  `Next Step Suggestion` appear in the TXT report;
- JSON parses successfully and includes `GeneratedAt`, `Tool`, `Privacy`,
  `System`, `Performance`, `Drives`, `StartupCommands`,
  `WindowsUpdateServices`, `BrowserExtensions`, `TempFolders`, and `Findings`;
- HTML report opens locally when `-HtmlReport` is used;
- HTML report does not load remote scripts, fonts, images, or styles;
- `-OpenReport` opens the TXT report by default and the HTML report when
  `-HtmlReport` is also used.

## Redaction Checks

When `-RedactIdentity` is used, inspect TXT, JSON, and HTML output before
sharing anything publicly. Confirm that the report does not expose:

- computer name;
- Windows username;
- `C:\Users\...` profile paths;
- local temporary folder paths;
- browser extension IDs;
- local identity paths in browser policy values;
- report output paths in console logs or copied snippets.

Useful placeholders include:

- `[redacted]`
- `[redacted-computer]`
- `[redacted-user]`
- `[redacted-user-profile]`
- `[redacted-extension-id-1]`

## Evidence To Keep

For public issues, keep evidence sanitized and minimal:

- Windows edition and build;
- PowerShell version;
- whether the shell was admin or standard user;
- which command was run;
- list of generated file types;
- sanitized first 30 lines of TXT output;
- screenshot of the HTML report with computer name and username hidden;
- notes about warnings, missing sections, or unexpected errors.

Do not upload full raw reports until they have been reviewed. Do not upload
screenshots that expose names, local paths, serial numbers, account names,
browser history, payment data, or personal files.

## Pass Criteria

Mark a machine run as passed only when:

- the command exits successfully;
- expected files are generated;
- required TXT sections are present;
- JSON parses and contains expected top-level keys;
- HTML opens locally when requested;
- redaction removes local identity values when requested;
- no repair, cleanup, install, uninstall, service change, browser change, or
  security setting change occurs.

## Issue Closure Criteria

Close the Windows validation issue only after:

- one Windows 10 machine has a sanitized passing record;
- one Windows 11 machine has a sanitized passing record;
- any discovered limitation is either fixed or documented;
- the public issue includes a maintainer comment linking the validation evidence
  and the latest passing CI run.
