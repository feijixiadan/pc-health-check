# Report Interpretation Guide

This guide helps maintainers and helpers read `PC-Health-Report-*.txt`.

## Start Here

Read these sections first:

1. `Quick Findings`
2. `Performance`
3. `Drives`
4. `Startup Items`
5. `Antivirus`
6. `Windows Update`
7. `Browser Check`

## Common Findings

### High CPU

Signal:

```text
CPU load >= 80%
```

Suggested next step:

Check Task Manager before changing anything. Do not end system processes. Look for stuck apps, antivirus scans, Windows Update, installers, downloads, games, or browser tabs.

### High Memory Usage

Signal:

```text
UsedMemoryPercent >= 85%
```

Suggested next step:

Close unnecessary apps, reduce browser tabs, and review startup apps. If high usage is normal for the workload, consider adding RAM instead of removing software.

### Low C Drive Free Space

Signal:

```text
C: free space < 15%
```

Suggested next step:

Use Windows Storage settings or Disk Cleanup. Do not delete personal files without explicit confirmation.

### Many Startup Items

Signal:

```text
Startup item count >= 20
```

Suggested next step:

Review startup items with the device owner. Disable only items they understand and agree to disable.

### Pending Reboot

Signal:

```text
Pending reboot: True
```

Suggested next step:

Ask the device owner to save work, restart, wait for updates to finish, then run the report again.

### Browser Extension or Policy Concerns

Signals:

```text
Many Chrome or Edge extensions
Browser policy/homepage keys found
```

Suggested next step:

Open the browser extension page with the owner present. Review unfamiliar extensions and homepage/search settings.

### Multiple Antivirus Products

Signal:

```text
Multiple antivirus products detected
```

Suggested next step:

Confirm which product the owner intends to use. Multiple active security suites can cause performance problems.

## Safety Rules

- Do not handle passwords, payment codes, or personal accounts for the owner.
- Do not delete personal files.
- Do not disable security software without explicit confirmation.
- Do not claim the report proves hardware failure; it is only a first-pass signal.
- Run the report again after any repair workflow to compare before and after.
