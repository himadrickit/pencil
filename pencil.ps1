#Requires -Version 5.1
<#
.SYNOPSIS
    pencil - manage Windows dotfiles (.graphite) as symlinks. Single-file edition.

.DESCRIPTION
    pencil buy <url>   clone your graphite repo to ~/.graphite
    pencil dot         copy existing configs (charcoals) into ~/.graphite
    pencil write       erase existing links, then symlink graphite -> system paths
    pencil erase       remove the configs from their system paths
    pencil sharp       commit and push ~/.graphite
    pencil make        add "Make Graphite" to the Explorer folder context menu
    pencil adopt <dir> move <dir> into ~/.graphite and symlink it back
    pencil shell       interactive mode (alias: pen)
    pencil help

    The list of graphites is read from graphite.ps1 in the cloned repo
    (graphites.ps1 is accepted as a fallback name). It must define $Graphites.
#>
param(
    [Parameter(Position = 0)][string]$Command,
    [Parameter(Position = 1)][string]$Arg,
    [switch]$Pause   # internal: keeps the elevated window open after relaunch
)

$GraphiteRoot = Join-Path $HOME '.graphite'
$ScriptFile   = $PSCommandPath

# ---------------------------------------------------------------- helpers

function Test-Admin {
    ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Ensure-Admin {
    param([string]$Cmd, [string]$CmdArg)
    if (Test-Admin) { return }
    Write-Warning 'Administrator rights are required (symlinks / registry). Relaunching elevated...'
}

function Get-Graphites {
    foreach ($name in 'graphite.ps1', 'graphites.ps1') {
        $file = Join-Path $GraphiteRoot $name
        if (Test-Path -LiteralPath $file) {
            . $file                       # defines $Graphites
            if (-not $Graphites) { throw "$file did not define `$Graphites" }
            return $Graphites
        }
    }
    throw "graphite.ps1 not found in $GraphiteRoot. Run: pencil buy <url>"
}

# Removes $Path only if it is a link (symlink/junction). Returns $true if removed.
function Remove-Link {
    param([string]$Path)
    $item = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
    if ($item -and $item.LinkType) {
        $item.Delete()
        return $true
    }
    return $false
}

# ---------------------------------------------------------------- commands

function Invoke-Buy {
    param([string]$Url)
    if (-not $Url) { Write-Host 'Usage: pencil buy <url>' -ForegroundColor Yellow; return }
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Host 'git is not installed or not on PATH.' -ForegroundColor Red; return
    }

    if (Test-Path -LiteralPath (Join-Path $GraphiteRoot '.git')) {
        Write-Host "$GraphiteRoot already exists, pulling latest..." -ForegroundColor Cyan
        git -C $GraphiteRoot pull
    }
    elseif (Test-Path -LiteralPath $GraphiteRoot) {
        Write-Host "$GraphiteRoot exists and is not a git repo. Move it away first." -ForegroundColor Red
        return
    }
    else {
        Write-Host "Buying graphite from $Url" -ForegroundColor Cyan
        git clone $Url $GraphiteRoot
    }
    if ($LASTEXITCODE -ne 0) { Write-Host 'git failed.' -ForegroundColor Red; return }

    try {
        $list = Get-Graphites
        Write-Host "Graphite ready: $(@($list).Count) entries. Next: pencil write" -ForegroundColor Green
    } catch {
        Write-Host $_.Exception.Message -ForegroundColor Red
    }
}

function Invoke-Dot {
    $list = Get-Graphites
    foreach ($g in $list) {
        $destination = Join-Path $GraphiteRoot $g.Get
        if (-not (Test-Path -LiteralPath $g.Path)) {
            Write-Host "No Charcoal of $($g.Name)" -ForegroundColor Red
            continue
        }
        if (Test-Path -LiteralPath $destination) {
            Write-Host "Already a Graphite $($g.Name)" -ForegroundColor Green
            continue
        }
        Write-Host "Copying Charcoal of $($g.Name)"
        try {
            New-Item -ItemType Directory -Force -Path (Split-Path $destination -Parent) | Out-Null
            Copy-Item -LiteralPath $g.Path -Destination $destination -Recurse -Force
        } catch {
            Write-Host "Failed $($g.Name): $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    Write-Host 'Making graphite has completed' -ForegroundColor Cyan
}

function Invoke-Erase {
    $list = Get-Graphites
    foreach ($g in $list) {
        if (-not (Test-Path -LiteralPath $g.Path) -and -not (Get-Item -LiteralPath $g.Path -Force -ErrorAction SilentlyContinue)) {
            Write-Host "No Graphite of $($g.Name)" -ForegroundColor Red
            continue
        }
        try {
            if (-not (Remove-Link $g.Path)) {
                Remove-Item -LiteralPath $g.Path -Recurse -Force
            }
        } catch {
            Write-Host "Failed $($g.Name): $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

function Invoke-Write {
    $list = Get-Graphites
    foreach ($g in $list) {
        $source = Join-Path $GraphiteRoot $g.Get
        $target = $g.Path

        if (-not (Test-Path -LiteralPath $source)) {
            Write-Host "No Graphite found for $target" -ForegroundColor Red
            continue
        }

        try {
            # auto-erase: drop any existing link at the target before re-linking
            if (Remove-Link $target) {
                Write-Host "Erased old link $target" -ForegroundColor DarkGray
            }

            # a real file/folder is never deleted here (use `pencil erase` for that)
            if (Test-Path -LiteralPath $target) {
                Write-Host "Skipped $target (real file/folder in the way; run pencil erase)" -ForegroundColor Yellow
                continue
            }

            $parent = Split-Path $target.TrimEnd('\', '/') -Parent
            if ($parent -and -not (Test-Path -LiteralPath $parent)) {
                New-Item -ItemType Directory -Force -Path $parent | Out-Null
            }

            New-Item -ItemType SymbolicLink -Path $target -Target $source | Out-Null
            Write-Host "Created Pencil $($g.Get) -> $target 8>" -ForegroundColor Green
        } catch {
            Write-Host "Failed $($g.Name): $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

function Invoke-Sharp {
    Push-Location $GraphiteRoot
    try {
        git add .
        git commit -m 'Sharped pencil'
        git push
    } finally {
        Pop-Location
    }
}

function Invoke-Make {
    $menuName = 'Make Graphite'
    $key      = "HKCU:\Software\Classes\Directory\shell\$menuName"
    New-Item -Path $key -Force | Out-Null
    New-ItemProperty -Path $key -Name 'Icon' -Value 'powershell.exe' -Force | Out-Null
    New-Item -Path "$key\command" -Force | Out-Null
    Set-ItemProperty -Path "$key\command" -Name '(default)' `
        -Value "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$ScriptFile`" adopt `"%1`""
    Write-Host "Added '$menuName' to the folder context menu." -ForegroundColor Green
}

function Invoke-Adopt {
    param([string]$TargetPath)
    if (-not $TargetPath -or -not (Test-Path -LiteralPath $TargetPath)) {
        Write-Host 'Usage: pencil adopt <existing folder>' -ForegroundColor Yellow; return
    }
    $TargetPath  = (Resolve-Path -LiteralPath $TargetPath).ProviderPath.TrimEnd('\')
    $folderName  = Split-Path $TargetPath -Leaf
    $destination = Join-Path $GraphiteRoot $folderName

    New-Item -ItemType Directory -Force -Path $GraphiteRoot | Out-Null
    if (-not (Test-Path -LiteralPath $destination)) {
        Copy-Item -LiteralPath $TargetPath -Destination $destination -Recurse
    }
    if (-not (Remove-Link $TargetPath)) {
        Remove-Item -LiteralPath $TargetPath -Recurse -Force
    }
    New-Item -ItemType SymbolicLink -Path $TargetPath -Target $destination | Out-Null
    Write-Host "Adopted $TargetPath -> $destination" -ForegroundColor Green
}

function Show-Help {
    Write-Host ' buy <url>: clone your graphite repo into ~/.graphite' -ForegroundColor Cyan
    Write-Host ' dot:       copy configs into .graphite'                 -ForegroundColor Cyan
    Write-Host ' write:     erase old links, then make symlinks'         -ForegroundColor Cyan
    Write-Host ' erase:     remove configs from their system paths'      -ForegroundColor Cyan
    Write-Host ' sharp:     push .graphite'                              -ForegroundColor Cyan
    Write-Host ' make:      add context menu support for .graphite'      -ForegroundColor Cyan
    Write-Host ' adopt <d>: move a folder into .graphite and link back'  -ForegroundColor Cyan
    Write-Host ' shell:     interactive mode (also: pen)'                -ForegroundColor Cyan
}

# ---------------------------------------------------------------- dispatch

function Invoke-Pencil {
    param([string]$Cmd, [string]$CmdArg)
    switch ($Cmd) {
        'buy'   { Invoke-Buy $CmdArg }
        'dot'   { Invoke-Dot }
        'sharp' { Invoke-Sharp }
        'write' { Ensure-Admin 'write' $null;  Invoke-Write }
        'erase' { Ensure-Admin 'erase' $null;  Invoke-Erase }
        'make'  { Ensure-Admin 'make'  $null;  Invoke-Make }
        'adopt' { Ensure-Admin 'adopt' $CmdArg; Invoke-Adopt $CmdArg }
        'help'  { Show-Help }
        default { Write-Host "Unknown command: $Cmd" -ForegroundColor Red }
    }
}

function Start-PenShell {
    Ensure-Admin 'shell' $null
    Write-Host "[Pen] Type 'buy <url>', 'dot', 'write', 'sharp', 'erase', 'make', 'help' or 'fluid'" -ForegroundColor Magenta
    while ($true) {
        $line = Read-Host 'pen>'
        if ($null -eq $line) { break }
        $line = $line.Trim()
        if ($line -eq 'fluid') { break }
        if ($line -eq 'clear') { Clear-Host; continue }
        if ($line -eq '') { continue }
        $cmd, $rest = $line -split '\s+', 2
        try { Invoke-Pencil $cmd $rest } catch { Write-Host $_.Exception.Message -ForegroundColor Red }
    }
    Write-Host '[No Ink]' -ForegroundColor Blue
}

try {
    if (-not $Command) {
        Write-Host 'Usage: pencil buy <url> > dot > write > sharp > help' -ForegroundColor Yellow
    }
    elseif ($Command -in 'shell', 'pen') {
        Start-PenShell
    }
    else {
        Invoke-Pencil $Command $Arg
    }
} catch {
    Write-Host $_.Exception.Message -ForegroundColor Red
} finally {
    if ($Pause) { Read-Host 'Press Enter to close' | Out-Null }
}
