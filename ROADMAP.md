# Roadmap

This roadmap tracks the next maintenance steps for PC Health Check. The project
goal is to stay privacy-first, read-only, and useful for helpers who need a safe
first-pass Windows diagnostic report.

## Near Term

- Validate the script on real Windows 10 and Windows 11 machines.
- Use `docs/windows-validation-checklist.md` to record sanitized real-machine
  validation evidence.
- Add sanitized sample reports from real test runs.
- Improve the JSON report shape so future automation can consume it safely.
- Document known limitations and false-positive cases.

## Privacy And Safety

- Add a redaction mode for computer names, Windows usernames, local paths, and
  browser extension IDs.
- Add a privacy review checklist for report sharing.
- Keep the default workflow offline, read-only, and telemetry-free.
- Avoid collecting documents, browser history, cookies, passwords, payment data,
  environment variables, or registry secrets.

## Report Formats

- Add an optional HTML report for easier reading by non-technical users.
- Keep the plain text report as the default output.
- Add examples for healthy, disk-pressure, memory-pressure, and update-pending
  machines.

## Localization

- Add Chinese documentation for helpers and family IT support scenarios.
- Add localized report labels without changing the underlying diagnostic data.
- Keep English documentation as the primary contributor-facing language.

## Continuous Integration

- Expand the Windows smoke test beyond syntax checks and report generation.
- Verify required report sections in both TXT and JSON outputs.
- Upload sanitized CI report artifacts for every workflow run.
- Add tests for formatting helpers as the script becomes more modular.

## Release Goals

- Publish `v0.1.0` as the first public release.
- Track planned improvements through public GitHub issues.
- Keep release notes short, specific, and clear about privacy boundaries.
