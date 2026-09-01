# Shorten-Paths.ps1

PowerShell script to clean up file and folder names before migrating local folders to **SharePoint** or **OneDrive**.

This is a native Windows port of the original Bash script [shorten_paths.sh](https://github.com/0x9ff/shorten_paths.sh).

---

## Overview

`Shorten-Paths.ps1` prepares local folders for upload to SharePoint / OneDrive by fixing common issues that cause migration failures:

- Illegal characters
- Multiple spaces and awkward spacing
- Trailing numeric suffixes (`_1`, `_1_1`, etc.)
- System and junk files
- Excessively long file or folder names

The script processes the directory tree recursively, works from the deepest paths upward, supports a full dry-run mode, and creates a detailed log of every action.

---

## Features

- Removes illegal characters for SharePoint/OneDrive (`~ " # % & * { } \ : < > ? / + | ,` + leading/trailing `.` and `-`)
- Collapses multiple spaces and replaces `" _ "` with a single underscore
- Removes trailing numeric suffixes (`_1`, `_1_1`, etc.)
- Deletes common junk/system files:
  - `Thumbs.db`
  - `.DS_Store`
  - Office lock files (`~$*`)
  - macOS AppleDouble files (`._*`)
- Handles long paths and long names (with optional truncation)
- Multi-pass processing (deepest paths first)
- Dry-run mode
- Live progress output
- Detailed logging of every action

---

## Requirements

- Windows 10, Windows 11, or Windows Server
- PowerShell 5.1 or newer (PowerShell 7+ recommended)
- Read/write permissions on the target folder

---

## Installation

1. Download `Shorten-Paths.ps1`

2. (Recommended) Unblock the file after download:

```powershell
Unblock-File .\Shorten-Paths.ps1
```

3. (Optional) Allow script execution for the current session:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

---

## Usage

### Syntax

```powershell
.\Shorten-Paths.ps1 -Path <directory> [-DryRun] [-MaxPathLength <int>] [-MaxNameLength <int>] [-TruncateTo <int>] [-LogFile <filename>]
```

### Examples

**Dry-run (strongly recommended first):**

```powershell
.\Shorten-Paths.ps1 -Path "D:\Migrate\LAVORI" -DryRun
```

**Real run:**

```powershell
.\Shorten-Paths.ps1 -Path "D:\Migrate\LAVORI"
```

**Custom limits:**

```powershell
.\Shorten-Paths.ps1 -Path "D:\Migrate\LAVORI" -MaxPathLength 240 -MaxNameLength 100 -TruncateTo 40
```

---

## Parameters

| Parameter         | Default                  | Description                                      |
|-------------------|--------------------------|--------------------------------------------------|
| `-Path`           | *(Required)*             | Root directory to process                        |
| `-DryRun`         |                          | Simulate only – no renames or deletions          |
| `-MaxPathLength`  | `260`                    | Maximum allowed full path length                 |
| `-MaxNameLength`  | `128`                    | Maximum allowed file/folder name length          |
| `-TruncateTo`     | `50`                     | Target length when truncating a name             |
| `-LogFile`        | `long_paths_report.txt`  | Name of the log file                             |

---

## What the Script Does

1. Scans the entire directory tree recursively
2. Processes items from the deepest paths first
3. Deletes junk/system files (`Thumbs.db`, `.DS_Store`, `~$*`, `._*`)
4. Cleans illegal characters, multiple spaces, and trailing `_N` suffixes
5. Truncates names that exceed the configured limits (while keeping them unique)
6. Logs every action with the reason
7. Repeats in multiple passes until no more changes are needed
8. In dry-run mode only one pass is performed

---

## Logging

All actions are written to the log file (default: `long_paths_report.txt`):

- Full path of every item
- Reason for the action
- Whether the item was skipped, deleted, renamed, or would have been changed
- Summary after each pass + final summary

The log is created in the same folder where you run the script.

---

## Important Notes

- **Always run with `-DryRun` first** and review the log carefully.
- Make a full backup before running the real version.
- Renames and deletions are permanent.
- Windows still has path length limitations. Enable long path support if needed.
- Extremely deep folder structures may still require some manual cleanup.

---

## Credits

- Original Bash version: [0x9ff/shorten_paths.sh](https://github.com/0x9ff/shorten_paths.sh) (generated with Grok 3)
- PowerShell port and improvements: created with **Grok 4** (xAI)

---

## License

This script is provided as-is, free to use and modify.  
No warranty is implied. Always test with `-DryRun` and back up your data.
```- Read/write permissions on the target folder

---

## Installation

1. Download `Shorten-Paths.ps1`
2. (Recommended) Unblock the file after download:
   ```powershell
   Unblock-File .\Shorten-Paths.ps1
