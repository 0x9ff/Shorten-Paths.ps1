# Shorten-Paths.ps1

PowerShell script to clean up file and folder names before migrating local folders to **SharePoint** or **OneDrive**.

This is a native Windows port of the original Bash script [`shorten_paths.sh`](https://github.com/0x9ff/shorten_paths.sh).

---

## Overview

`Shorten-Paths.ps1` is designed to prepare local folders for upload to SharePoint / OneDrive by fixing common issues that cause migration failures:

- Illegal characters
- Multiple spaces and awkward spacing
- Trailing numeric suffixes (`_1`, `_1_1`, etc.)
- System and junk files
- Excessively long file or folder names

The script processes the directory tree recursively, works from the deepest paths upward, supports a full dry-run mode, and creates a detailed log of every action.

---

## Features

- **Removes illegal characters** for SharePoint/OneDrive  
  (`~ " # % & * { } \ : < > ? / + | ,` + leading/trailing `.` and `-`)

- **Cleans spacing issues**
  - Collapses multiple consecutive spaces into a single space
  - Replaces `" _ "` with a single underscore (`_`)

- **Removes trailing numeric suffixes**  
  Examples: `Foto_1.jpg` → `Foto.jpg`, `Document_1_2.pdf` → `Document.pdf`

- **Deletes common junk / system files**
  - `Thumbs.db`
  - `.DS_Store`
  - Office lock files (`~$*`)
  - macOS AppleDouble files (`._*`)

- **Handles long paths and long names**
  - Logs paths longer than 260 characters (configurable)
  - Logs names longer than 128 characters (configurable)
  - Can truncate names (default target: 50 characters + extension)

- **Multi-pass processing**  
  Processes deepest paths first and repeats until no more changes are needed (important when parent folders are renamed).

- **Dry-run mode**  
  Simulates every action without modifying any files.

- **Live progress**  
  Shows the path currently being processed in the console.

- **Detailed logging**  
  Every skip, delete, rename (or dry-run equivalent) is written to a log file.

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
