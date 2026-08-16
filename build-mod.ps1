# Builds NovaCraft and copies the mod JAR to the Desktop.
# Newer builds overwrite the previous JAR on the Desktop.
#
# Usage:
#   .\build-mod.ps1                 # full build (tests + detekt)
#   .\build-mod.ps1 -SkipChecks     # fast build, skips tests and detekt
#   .\build-mod.ps1 -Desktop <path> # custom desktop folder

[CmdletBinding()]
param(
    [switch]$SkipChecks,
    [string]$Desktop = "$env:USERPROFILE\Desktop"
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$desktopFolder = if (Test-Path -LiteralPath $Desktop) {
    $Desktop
} else {
    [Environment]::GetFolderPath('Desktop')
}

if (-not $desktopFolder -or -not (Test-Path -LiteralPath $desktopFolder)) {
    Write-Error "Desktop folder not found: '$Desktop'"
    exit 1
}

# Prefer JDK 25 if available (required by the project), otherwise fall back to JAVA_HOME.
$jdk25Candidates = @(
    'C:\Program Files\Zulu\zulu-25',
    'C:\Program Files\Eclipse Adoptium\jdk-25*',
    'C:\Program Files\Microsoft\jdk-25*',
    "$env:USERPROFILE\.jdks\*25*"
)
$jdk = $null
foreach ($pattern in $jdk25Candidates) {
    # The literal path itself may be a valid JDK (Get-ChildItem lists children for existing dirs).
    if (Test-Path -LiteralPath $pattern) {
        if (Test-Path -LiteralPath (Join-Path $pattern 'bin\java.exe')) {
            $jdk = $pattern
            break
        }
    }

    $subDirs = @(Get-ChildItem -Path $pattern -Directory -ErrorAction SilentlyContinue)
    foreach ($candidate in $subDirs) {
        if (Test-Path -LiteralPath (Join-Path $candidate.FullName 'bin\java.exe')) {
            $jdk = $candidate.FullName
            break
        }
    }
    if ($jdk) { break }
}

if ($jdk) {
    $env:JAVA_HOME = $jdk
    Write-Host "Using JDK: $jdk"
} else {
    Write-Host "JDK 25 not found, relying on JAVA_HOME: $env:JAVA_HOME"
}

$gradlew = Join-Path $repoRoot 'gradlew.bat'
if (-not (Test-Path -LiteralPath $gradlew)) {
    Write-Error "gradlew.bat not found in $repoRoot"
    exit 1
}

Write-Host "Building NovaCraft..."
Push-Location $repoRoot
try {
    # Gradle writes progress to stderr; treat native stderr as non-fatal here.
    $ErrorActionPreference = 'Continue'
    if ($SkipChecks) {
        $output = & $gradlew build -x test -x detekt --console=plain 2>&1
    } else {
        $output = & $gradlew build --console=plain 2>&1
    }
    $exitCode = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    $output | ForEach-Object { Write-Host $_ }
    if ($exitCode -ne 0) {
        Write-Error "Gradle build failed with exit code $exitCode"
        exit $exitCode
    }
} finally {
    Pop-Location
}

# Find the built mod JAR (exclude sources and any other artifacts).
$jar = Get-ChildItem -LiteralPath (Join-Path $repoRoot 'build\libs') -Filter 'novacraft-*.jar' |
    Where-Object { $_.Name -notmatch '-sources\.jar$' } |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

if (-not $jar) {
    Write-Error "No built mod JAR found under build\libs"
    exit 1
}

$target = Join-Path $desktopFolder 'NovaCraft.jar'
Copy-Item -LiteralPath $jar.FullName -Destination $target -Force

Write-Host ""
Write-Host "=============================================="
Write-Host "  Build successful: $($jar.Name)"
Write-Host "  Copied to: $target"
Write-Host "=============================================="
