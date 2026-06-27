# Roadmap

This roadmap tracks the next maintenance steps for PC Health Check. The project
goal is to stay privacy-first, read-only, and useful for helpers who need a safe
first-pass Windows diagnostic report.

## Near Term

- Validate the script on a real Windows 10 machine.
- Keep the public Windows 11 validation note linked from issue #1.
- Use `docs/windows-validation-checklist.md` to record sanitized real-machine
  validation evidence.
- Add sanitized sample reports from real test runs.
- Improve the JSON report shape so future automation can consume it safely.
- Document known limitations and false-positive cases.

## Completed In 0.2.0

- Added `-RedactIdentity` for computer names, Windows usernames, local identity
  paths, browser extension IDs, and shareable report paths.
- Added a privacy review checklist for report sharing.
- Added optional self-contained HTML report output with no JavaScript, external
  assets, or network calls.
- Added Chinese helper quick start and report sharing guidance.
- Expanded Windows CI smoke tests to verify TXT, JSON, HTML, and redaction
  behavior.
- Added a Windows 10/11 validation checklist.
- Recorded one real Windows 11 validation run in issue #1.

## Privacy And Safety

- Keep the default workflow offline, read-only, and telemetry-free.
- Avoid collecting documents, browser history, cookies, passwords, payment data,
  environment variables, or registry secrets.

## Report Formats

- Keep the plain text report as the default output.
- Add examples for healthy, disk-pressure, memory-pressure, and update-pending
  machines.

## Localization

- Add localized report labels without changing the underlying diagnostic data.
- Keep English documentation as the primary contributor-facing language.

## Continuous Integration

- Upload sanitized CI report artifacts for every workflow run.
- Add tests for formatting helpers as the script becomes more modular.

## Release Goals

- Publish `v0.2.0` with the completed privacy, report format, localization,
  CI, and validation checklist improvements.
- Track planned improvements through public GitHub issues.
- Keep release notes short, specific, and clear about privacy boundaries.
