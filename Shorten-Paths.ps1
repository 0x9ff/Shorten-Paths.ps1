<#
.SYNOPSIS
    Clean up file and folder names for SharePoint / OneDrive migration (Windows/PowerShell).

.DESCRIPTION
    Removes illegal characters, collapses spaces / " _ ", strips trailing _N suffixes,
    deletes system/junk files (Thumbs.db, .DS_Store, ~$*, ._* ), logs everything,
    optionally truncates long names. Supports -DryRun and multi-pass processing.
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Path,

    [switch]$DryRun,

    [int]$MaxPathLength = 260,
    [int]$MaxNameLength = 128,
    [int]$TruncateTo    = 50,

    [string]$LogFile = "long_paths_report.txt"
)

# ---------- Helpers ----------------------------------------------------------

$IllegalPattern = '[~"#%&*{}\\:<>?/+|,]+|\.{2,}|^[\.\-]|[\.\-]$'

function Test-HasIllegalChars {
    param([string]$Name)
    return $Name -match $IllegalPattern -or $Name -match '^\s|\s$'
}

function Test-IsSpecialFile {
    param([string]$Name)
    return $Name -match '^~\$' -or
           $Name -eq '.DS_Store' -or
           $Name -eq 'Thumbs.db' -or
           $Name -like '._*'
}

function Get-SpecialFileType {
    param([string]$Name)
    if ($Name -match '^~\$')   { return 'Shadow/Lock File' }
    if ($Name -eq '.DS_Store') { return '.DS_Store File' }
    if ($Name -eq 'Thumbs.db') { return 'Thumbs.db File' }
    if ($Name -like '._*')     { return 'AppleDouble/._ File' }
    return 'Special File'
}

function Clean-Name {
    param([string]$Name)
    $cleaned = [regex]::Replace($Name, $IllegalPattern, '_')
    $cleaned = $cleaned -replace '^[\.\s\-]+|[\.\s\-]+$', ''
    if ([string]::IsNullOrWhiteSpace($cleaned)) { $cleaned = 'renamed_file' }
    return $cleaned
}

function Clean-Suffixes {
    param([string]$Name)
    $cleaned = [regex]::Replace($Name, '\s+', ' ')
    $cleaned = [regex]::Replace($cleaned, ' _ ', '_')
    $cleaned = [regex]::Replace($cleaned, '(_[0-9]+)+$', '')
    if ([string]::IsNullOrWhiteSpace($cleaned)) { $cleaned = 'renamed_file' }
    return $cleaned
}

function Get-UniqueName {
    param(
        [string]$OriginalName,
        [string]$Directory,
        [string]$Extension,
        [int]$CurrentPathLength
    )

    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($OriginalName)
    $cleaned  = Clean-Name $baseName
    $cleaned  = Clean-Suffixes $cleaned

    if ($cleaned -eq $baseName -and $CurrentPathLength -le $MaxPathLength -and $baseName.Length -le $MaxNameLength) {
        return $OriginalName
    }

    $finalBase = $cleaned
    if ($CurrentPathLength -gt $MaxPathLength -or $baseName.Length -gt $MaxNameLength) {
        $finalBase = $cleaned.Substring(0, [Math]::Min($TruncateTo, $cleaned.Length))
        $finalBase = [regex]::Replace($finalBase, '[^a-zA-Z0-9_\-]', '')
        if ([string]::IsNullOrWhiteSpace($finalBase)) { $finalBase = 'renamed_file' }
    }

    $candidate = $finalBase + $Extension
    $counter   = 1
    while (Test-Path (Join-Path $Directory $candidate)) {
        if ((Join-Path $Directory $candidate) -eq (Join-Path $Directory $OriginalName)) { break }
        $candidate = "${finalBase}_${counter}${Extension}"
        $counter++
    }
    return $candidate
}

function Test-IsCompliant {
    param([string]$Name, [int]$PathLength)
    if (Test-HasIllegalChars $Name) { return $false }
    if ($Name -match '_ +_' -or $Name -match '  +') { return $false }
    if ($Name.Length -gt $MaxNameLength) { return $false }
    if ($PathLength -gt $MaxPathLength) { return $false }
    return $true
}

function Write-Log {
    param([string]$Message, [switch]$Console)
    $Message | Add-Content -Path $LogFile -Encoding UTF8
    if ($Console) { Write-Host $Message }
}

# ---------- Main -------------------------------------------------------------

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -LiteralPath $Path).Path

if (-not (Test-Path -LiteralPath $root -PathType Container)) {
    Write-Error "Directory does not exist: $Path"
    exit 1
}

# Fresh log
"" | Set-Content -Path $LogFile -Encoding UTF8

Write-Log "Scanning directory: $root" -Console
Write-Log "Logging everything to $LogFile" -Console
Write-Log "Special files that will be deleted: Thumbs.db, .DS_Store, ~`$*, ._*" -Console

if ($DryRun) {
    Write-Log ">>> DRY-RUN MODE - no changes will be made <<<" -Console
}

$totalProcessed = 0
$totalChanged   = 0
$pass           = 0

do {
    $pass++
    $itemsProcessed = 0
    $itemsChanged   = 0

    Write-Log "`n===== Starting pass $pass =====" -Console

    # Deepest first
    $items = Get-ChildItem -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue |
             Sort-Object { $_.FullName.Length } -Descending

    foreach ($item in $items) {

        $itemPath = $item.FullName
        $pathLen  = $itemPath.Length
        $name     = $item.Name

        # Progress indicator
        Write-Host "Working on: $itemPath" -ForegroundColor DarkGray

        if (-not (Test-Path -LiteralPath $itemPath)) {
            Write-Log "Skipping (no longer exists): $itemPath"
            continue
        }

        if (Test-IsCompliant -Name $name -PathLength $pathLen) {
            Write-Log "Skipping (already compliant): $itemPath"
            $itemsProcessed++
            $totalProcessed++
            continue
        }

        # ---- Delete special / junk files ----
        if (Test-IsSpecialFile $name) {
            $reason = Get-SpecialFileType $name
            Write-Log "Item: $itemPath"
            Write-Log "Reason: $reason"

            if ($DryRun) {
                $msg = "[DRY-RUN] Would delete $reason -> $name"
                Write-Log $msg -Console
            }
            else {
                try {
                    Remove-Item -LiteralPath $itemPath -Force -ErrorAction Stop
                    $msg = "DELETED $reason -> $name"
                    Write-Log $msg -Console
                    $itemsChanged++
                    $totalChanged++
                }
                catch {
                    Write-Log "FAILED to delete $reason '$name' : $_" -Console
                }
            }
            Write-Log "------------------------"
            $itemsProcessed++
            $totalProcessed++
            continue
        }

        # ---- Rename logic ----
        $needsWork = ($pathLen -gt $MaxPathLength) -or
                     ($name.Length -gt $MaxNameLength) -or
                     (Test-HasIllegalChars $name) -or
                     ($name -match '_ +_') -or
                     ($name -match '  +')

        if (-not $needsWork) { continue }

        Write-Log "Item: $itemPath"
        if ($pathLen -gt $MaxPathLength -or $name.Length -gt $MaxNameLength) {
            Write-Log "Path Length: $pathLen | Name Length: $($name.Length)"
            Write-Log "Reason: Long Path or Name"
        }
        elseif (Test-HasIllegalChars $name) {
            Write-Log "Reason: Illegal Characters"
        }
        elseif ($name -match '_ +_') {
            Write-Log "Reason: Space-Underscore-Space"
        }
        elseif ($name -match '  +') {
            Write-Log "Reason: Multiple Spaces"
        }

        $ext = if ($item.PSIsContainer) { '' } else { $item.Extension }
        $dir = if ($item.PSIsContainer) { Split-Path -Parent $itemPath } else { $item.DirectoryName }

        $newName = Get-UniqueName -OriginalName $name -Directory $dir -Extension $ext -CurrentPathLength $pathLen

        if ($newName -eq $name) {
            Write-Log "No rename needed for '$name'"
            Write-Log "------------------------"
            $itemsProcessed++
            $totalProcessed++
            continue
        }

        if ($DryRun) {
            $msg = "[DRY-RUN] Would rename '$name' -> '$newName'"
            Write-Log $msg -Console
        }
        else {
            try {
                Rename-Item -LiteralPath $itemPath -NewName $newName -ErrorAction Stop
                $msg = "RENAMED '$name' -> '$newName'"
                Write-Log $msg -Console
                $itemsChanged++
                $totalChanged++
            }
            catch {
                Write-Log "FAILED to rename '$name' : $_" -Console
            }
        }
        Write-Log "------------------------"
        $itemsProcessed++
        $totalProcessed++
    }

    Write-Log "Pass $pass finished - processed $itemsProcessed, changed $itemsChanged" -Console

    if ($DryRun) { break }

} while ($itemsChanged -gt 0)

Write-Log "`n===== FINAL SUMMARY =====" -Console
Write-Log "Total items processed : $totalProcessed" -Console
Write-Log "Total changes made    : $totalChanged" -Console
Write-Log "Detailed log saved to : $((Resolve-Path $LogFile).Path)" -Console

Write-Host "`nDone. Check the log file for the full history of every action."
