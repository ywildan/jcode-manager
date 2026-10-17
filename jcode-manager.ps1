<#
.SYNOPSIS
    Launcher Windows buat jcode-manager.py.

.DESCRIPTION
    Nyari Python yang ada (py launcher atau python), terus ngejalanin
    script utamanya. Semua argumen diterusin apa adanya.

.CONTOH
    .\jcode-manager.ps1                # buka menu
    .\jcode-manager.ps1 --list
    .\jcode-manager.ps1 --add mygw --base-url https://api.example.com/v1 --api-key sk-xxx --model gpt-4o

.CATATAN
    Kalau kena execution policy, jalanin:
      powershell -ExecutionPolicy Bypass -File .\jcode-manager.ps1
#>

[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ManagerArgs
)

$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$script = Join-Path $here 'jcode-manager.py'

if (-not (Test-Path $script)) {
    Write-Error "jcode-manager.py nggak ketemu di $here"
    exit 1
}

function Test-PythonUsable {
    param([string]$Exe, [string[]]$Prefix)
    try {
        $out = & $Exe @($Prefix) '-c' 'import sys; sys.exit(0 if sys.version_info >= (3, 8) else 1)' 2>$null
        return ($LASTEXITCODE -eq 0)
    } catch {
        return $false
    }
}

$python = $null
$prefix = @()

if ($env:JCODE_MANAGER_PYTHON) {
    if (Test-PythonUsable -Exe $env:JCODE_MANAGER_PYTHON -Prefix @()) {
        $python = $env:JCODE_MANAGER_PYTHON
    }
}

if (-not $python) {
    foreach ($candidate in @('python3', 'python')) {
        if (Get-Command $candidate -ErrorAction SilentlyContinue) {
            if (Test-PythonUsable -Exe $candidate -Prefix @()) {
                $python = $candidate
                break
            }
        }
    }
}

if (-not $python -and (Get-Command 'py' -ErrorAction SilentlyContinue)) {
    if (Test-PythonUsable -Exe 'py' -Prefix @('-3')) {
        $python = 'py'
        $prefix = @('-3')
    }
}

if (-not $python) {
    Write-Host 'Python 3.8+ nggak ketemu.' -ForegroundColor Red
    Write-Host ''
    Write-Host 'Install dulu, contoh:'
    Write-Host '  winget install Python.Python.3.12'
    Write-Host '  atau download: https://www.python.org/downloads/windows/'
    Write-Host ''
    Write-Host "Alternatif tanpa Python: pakai 'jcode provider add' dari CLI jcode."
    exit 1
}

& $python @prefix $script @ManagerArgs
exit $LASTEXITCODE
