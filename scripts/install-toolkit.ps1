<#
.SYNOPSIS
    ⚡ Spring-React CRUD Toolkit & Accelerator
    Automated Integration Script (PowerShell)

.DESCRIPTION
    Automates copying and integrating the toolkit's backend (main & test)
    and frontend components into a target Spring Boot + React project.
    Refactors package declarations and imports to match target project structure.

.AUTHOR
    Ignacio Gutiérrez Serrera (@Ignacio0407)
    Email: ignaciogutierrezserrera@gmail.com
#>

[CmdletBinding()]
param (
    [Parameter(Position = 0)]
    [string]$TargetProject,

    [Parameter(Position = 1)]
    [string]$TargetPackage,

    [switch]$IncludeFrontend,
    [switch]$SkipTests,
    [switch]$DryRun,
    [switch]$Force,
    [switch]$NonInteractive
)

# Set UTF-8 encoding for console output
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Write-Banner {
    Write-Host "======================================================================" -ForegroundColor Cyan
    Write-Host "  [+] Spring-React CRUD Toolkit - Project Integrator (PowerShell)" -ForegroundColor Cyan
    Write-Host "  Author: Ignacio Gutiérrez Serrera (@Ignacio0407)" -ForegroundColor Cyan
    Write-Host "======================================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Find-ToolkitRoot {
    $scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $PSCommandPath }
    if ($scriptDir) {
        if (Test-Path (Join-Path $scriptDir "backend\src\main\java\toolkit")) {
            return (Resolve-Path $scriptDir).Path
        }
        $parentDir = Split-Path -Parent $scriptDir
        if (Test-Path (Join-Path $parentDir "backend\src\main\java\toolkit")) {
            return (Resolve-Path $parentDir).Path
        }
    }
    $cwd = (Get-Location).Path
    if (Test-Path (Join-Path $cwd "backend\src\main\java\toolkit")) {
        return (Resolve-Path $cwd).Path
    }
    if (Test-Path (Join-Path $cwd "spring-react-crud-toolkit\backend\src\main\java\toolkit")) {
        return (Resolve-Path (Join-Path $cwd "spring-react-crud-toolkit")).Path
    }
    throw "Could not locate spring-react-crud-toolkit root directory."
}

function Get-SiblingProjects([string]$ToolkitRoot) {
    $parent = Split-Path -Parent $ToolkitRoot
    $siblings = @()
    Get-ChildItem -Directory $parent | ForEach-Object {
        if ($_.Name -ne (Split-Path -Leaf $ToolkitRoot) -and -not $_.Name.StartsWith(".")) {
            $hasBackend = (Test-Path (Join-Path $_.FullName "pom.xml")) -or (Test-Path (Join-Path $_.FullName "backend\pom.xml")) -or (Test-Path (Join-Path $_.FullName "build.gradle"))
            $hasFrontend = (Test-Path (Join-Path $_.FullName "package.json")) -or (Test-Path (Join-Path $_.FullName "frontend\package.json"))
            $hasSrc = Test-Path (Join-Path $_.FullName "src")
            if ($hasBackend -or $hasFrontend -or $hasSrc) {
                $siblings += $_
            }
        }
    }
    return $siblings
}

function Detect-TargetBackend([string]$TargetDir) {
    $opt1Main = Join-Path $TargetDir "backend\src\main\java"
    $opt1Test = Join-Path $TargetDir "backend\src\test\java"
    if (Test-Path $opt1Main) {
        return @{ MainJava = $opt1Main; TestJava = $opt1Test }
    }

    $opt2Main = Join-Path $TargetDir "src\main\java"
    $opt2Test = Join-Path $TargetDir "src\test\java"
    if (Test-Path $opt2Main) {
        return @{ MainJava = $opt2Main; TestJava = $opt2Test }
    }

    throw "Could not find Java source directory in '$TargetDir'. Expected 'src/main/java' or 'backend/src/main/java'."
}

function Detect-BasePackage([string]$MainJavaDir) {
    $javaFiles = Get-ChildItem -Path $MainJavaDir -Filter "*.java" -Recurse -File
    foreach ($file in $javaFiles) {
        try {
            $content = [System.IO.File]::ReadAllText($file.FullName, [System.Text.Encoding]::UTF8)
            if ($content -match "@SpringBootApplication") {
                if ($content -match "(?m)^\s*package\s+([a-zA-Z0-9_.]+)\s*;") {
                    return $matches[1]
                }
            }
        } catch {
            continue
        }
    }
    return $null
}

function Transform-JavaContent([string]$content, [string]$targetPackage) {
    # 1. Package declarations: package toolkit... -> package <targetPackage>...
    $content = [System.Text.RegularExpressions.Regex]::Replace(
        $content,
        "(?m)^(\s*package\s+)toolkit(\b|(?=\.))",
        "`${1}$targetPackage"
    )

    # 2. Imports: import [static] toolkit... -> import [static] <targetPackage>...
    $content = [System.Text.RegularExpressions.Regex]::Replace(
        $content,
        "(?m)^(\s*import\s+(?:static\s+)?)toolkit(\b|(?=\.))",
        "`${1}$targetPackage"
    )

    # 3. Fully qualified code references to toolkit packages
    $content = [System.Text.RegularExpressions.Regex]::Replace(
        $content,
        "(?<=[^\w\.])toolkit\.(configuration|controller|exception|model|repository|security|service|user)",
        "$targetPackage.`$1"
    )

    return $content
}

function Copy-AndRefactorTree([string]$SrcToolkitDir, [string]$DstRootDir, [string]$TargetPackage, [bool]$IsDryRun, [bool]$IsForce) {
    $pkgRelPath = $TargetPackage.Replace('.', [System.IO.Path]::DirectorySeparatorChar)
    $dstPkgDir = Join-Path $DstRootDir $pkgRelPath
    $count = 0

    $javaFiles = Get-ChildItem -Path $SrcToolkitDir -Filter "*.java" -Recurse -File
    foreach ($srcFile in $javaFiles) {
        $relPath = $srcFile.FullName.Substring($SrcToolkitDir.Length).TrimStart([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
        $dstFile = Join-Path $dstPkgDir $relPath

        if ((Test-Path $dstFile) -and -not $IsForce) {
            Write-Host "  [EXISTS] $dstFile (skipping, use -Force to overwrite)" -ForegroundColor Yellow
            continue
        }

        $count++
        if ($IsDryRun) {
            Write-Host "  [DRY-RUN] Would copy: $($srcFile.Name) -> $dstFile" -ForegroundColor Cyan
            continue
        }

        $content = [System.IO.File]::ReadAllText($srcFile.FullName, [System.Text.Encoding]::UTF8)
        $transformed = Transform-JavaContent -content $content -targetPackage $TargetPackage

        $parent = Split-Path -Parent $dstFile
        if (-not (Test-Path $parent)) {
            New-Item -ItemType Directory -Path $parent -Force | Out-Null
        }

        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($dstFile, $transformed, $utf8NoBom)
        $shortDst = $dstFile.Substring($DstRootDir.Length).TrimStart([System.IO.Path]::DirectorySeparatorChar)
        Write-Host "  [OK] $relPath -> $shortDst" -ForegroundColor Green
    }

    return $count
}

function Copy-Frontend([string]$ToolkitRoot, [string]$TargetDir, [bool]$IsDryRun, [bool]$IsForce) {
    $srcFront = Join-Path $ToolkitRoot "frontend\src"
    if (-not (Test-Path $srcFront)) {
        Write-Host "  [WARN] Source frontend/src not found." -ForegroundColor Yellow
        return 0
    }

    if (Test-Path (Join-Path $TargetDir "frontend\src")) {
        $dstFront = Join-Path $TargetDir "frontend\src"
    } elseif ((Test-Path (Join-Path $TargetDir "src\components")) -or (Test-Path (Join-Path $TargetDir "package.json"))) {
        $dstFront = Join-Path $TargetDir "src"
    } else {
        $dstFront = Join-Path $TargetDir "frontend\src"
    }

    $count = 0
    $subfolders = @("components", "interfaces", "services", "util")
    foreach ($sub in $subfolders) {
        $srcSub = Join-Path $srcFront $sub
        if (-not (Test-Path $srcSub)) { continue }

        $files = Get-ChildItem -Path $srcSub -Recurse -File
        foreach ($file in $files) {
            $rel = $file.FullName.Substring($srcFront.Length).TrimStart([System.IO.Path]::DirectorySeparatorChar)
            $dstFile = Join-Path $dstFront $rel

            if ((Test-Path $dstFile) -and -not $IsForce) { continue }

            $count++
            if ($IsDryRun) {
                Write-Host "  [DRY-RUN] Would copy frontend: $rel -> $dstFile" -ForegroundColor Cyan
            } else {
                $parent = Split-Path -Parent $dstFile
                if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
                Copy-Item -Path $file.FullName -Destination $dstFile -Force
                Write-Host "  [OK] Frontend: $rel" -ForegroundColor Green
            }
        }
    }
    return $count
}

# --- Main Flow ---
Write-Banner

$toolkitRoot = Find-ToolkitRoot
Write-Host "Source Toolkit: " -NoNewline
Write-Host "$toolkitRoot" -ForegroundColor White

$parentDir = Split-Path -Parent $toolkitRoot
$targetDirPath = $null

if ($TargetProject) {
    if ([System.IO.Path]::IsPathRooted($TargetProject) -and (Test-Path $TargetProject)) {
        $targetDirPath = (Resolve-Path $TargetProject).Path
    } elseif (Test-Path (Join-Path $parentDir $TargetProject)) {
        $targetDirPath = (Resolve-Path (Join-Path $parentDir $TargetProject)).Path
    } elseif (Test-Path $TargetProject) {
        $targetDirPath = (Resolve-Path $TargetProject).Path
    } else {
        Write-Error "Target project '$TargetProject' not found."
        exit 1
    }
} elseif (-not $NonInteractive -and [Environment]::UserInteractive) {
    $siblings = Get-SiblingProjects -ToolkitRoot $toolkitRoot
    Write-Host "`nDetected projects in parent folder ($parentDir):" -ForegroundColor Cyan
    for ($i = 0; $i -lt $siblings.Count; $i++) {
        $sib = $siblings[$i]
        $isSpring = (Test-Path (Join-Path $sib.FullName "pom.xml")) -or (Test-Path (Join-Path $sib.FullName "src\main\java"))
        $label = if ($isSpring) { " [Spring Boot detected]" } else { "" }
        Write-Host "  [$($i + 1)] $($sib.Name)" -NoNewline
        Write-Host $label -ForegroundColor Green
    }
    Write-Host "  [$($siblings.Count + 1)] Enter custom path manually"

    $choice = Read-Host "`nSelect target project [1-$($siblings.Count + 1)]"
    if ($choice -match '^\d+$') {
        $idx = [int]$choice
        if ($idx -ge 1 -and $idx -le $siblings.Count) {
            $targetDirPath = $siblings[$idx - 1].FullName
        } elseif ($idx -eq ($siblings.Count + 1)) {
            $custom = Read-Host "Enter path to target project"
            $targetDirPath = (Resolve-Path $custom).Path
        }
    } else {
        $targetDirPath = (Resolve-Path $choice).Path
    }
} else {
    Write-Error "Target project must be specified using -TargetProject in non-interactive mode."
    exit 1
}

if (-not $targetDirPath -or -not (Test-Path $targetDirPath)) {
    Write-Error "Invalid target project directory."
    exit 1
}

Write-Host "Target Project: " -NoNewline
Write-Host "$targetDirPath" -ForegroundColor White

$backend = Detect-TargetBackend -TargetDir $targetDirPath
$mainJava = $backend.MainJava
$testJava = $backend.TestJava

Write-Host "Target main java: " -NoNewline
Write-Host "$mainJava" -ForegroundColor Gray
Write-Host "Target test java: " -NoNewline
Write-Host "$testJava" -ForegroundColor Gray

$detectedBasePkg = Detect-BasePackage -MainJavaDir $mainJava
$defaultPkg = if ($detectedBasePkg) { "$detectedBasePkg.toolkit" } else { "toolkit" }

$finalPkg = $TargetPackage
if (-not $finalPkg) {
    if (-not $NonInteractive -and [Environment]::UserInteractive) {
        Write-Host "`nDetected base package: " -NoNewline -ForegroundColor Cyan
        $displayBase = if ($detectedBasePkg) { $detectedBasePkg } else { 'None' }
        Write-Host "$displayBase" -ForegroundColor White
        $userPkg = Read-Host "Enter target package for toolkit classes [$defaultPkg]"
        $finalPkg = if ($userPkg) { $userPkg } else { $defaultPkg }
    } else {
        $finalPkg = $defaultPkg
    }
}

Write-Host "Target Package: " -NoNewline
Write-Host "$finalPkg" -ForegroundColor Green

$doFrontend = $IncludeFrontend.IsPresent
if (-not $doFrontend -and -not $NonInteractive -and [Environment]::UserInteractive) {
    $resp = Read-Host "`nAlso copy React frontend components & utilities? [y/N]"
    $doFrontend = ($resp -match '^(y|yes|s|si|sí)$')
}

Write-Host "`nStarting Integration..." -ForegroundColor Cyan
if ($DryRun) {
    Write-Host "Running in DRY-RUN mode. No files will be modified.`n" -ForegroundColor Yellow
}

# 1. Backend main
$srcMainToolkit = Join-Path $toolkitRoot "backend\src\main\java\toolkit"
Write-Host "`n[1/3] Processing Backend Main Classes..." -ForegroundColor Cyan
$mainCount = Copy-AndRefactorTree -SrcToolkitDir $srcMainToolkit -DstRootDir $mainJava -TargetPackage $finalPkg -IsDryRun $DryRun.IsPresent -IsForce $Force.IsPresent

# 2. Backend test
$testCount = 0
if (-not $SkipTests) {
    $srcTestToolkit = Join-Path $toolkitRoot "backend\src\test\java\toolkit"
    Write-Host "`n[2/3] Processing Backend Test Suites..." -ForegroundColor Cyan
    $testCount = Copy-AndRefactorTree -SrcToolkitDir $srcTestToolkit -DstRootDir $testJava -TargetPackage $finalPkg -IsDryRun $DryRun.IsPresent -IsForce $Force.IsPresent

    $srcTestRes = Join-Path $toolkitRoot "backend\src\test\resources\application.properties"
    $dstTestResDir = Join-Path (Split-Path -Parent $testJava) "resources"
    $dstTestRes = Join-Path $dstTestResDir "application.properties"
    if (Test-Path $srcTestRes) {
        if (-not (Test-Path $dstTestRes) -or $Force) {
            if ($DryRun) {
                Write-Host "  [DRY-RUN] Would copy test application.properties -> $dstTestRes" -ForegroundColor Cyan
            } else {
                if (-not (Test-Path $dstTestResDir)) { New-Item -ItemType Directory -Path $dstTestResDir -Force | Out-Null }
                Copy-Item -Path $srcTestRes -Destination $dstTestRes -Force
                Write-Host "  [OK] Copied test application.properties -> $dstTestRes" -ForegroundColor Green
            }
        }
    }
} else {
    Write-Host "`n[2/3] Backend Test Suites skipped (-SkipTests)." -ForegroundColor Yellow
}

# 3. Frontend
$frontCount = 0
if ($doFrontend) {
    Write-Host "`n[3/3] Processing Frontend UI Components & Utils..." -ForegroundColor Cyan
    $frontCount = Copy-Frontend -ToolkitRoot $toolkitRoot -TargetDir $targetDirPath -IsDryRun $DryRun.IsPresent -IsForce $Force.IsPresent
} else {
    Write-Host "`n[3/3] Frontend integration omitted." -ForegroundColor Gray
}

# Summary
Write-Host "`n======================================================================" -ForegroundColor Green
Write-Host "  [+] INTEGRATION COMPLETED SUCCESSFULLY!" -ForegroundColor Green
Write-Host "======================================================================" -ForegroundColor Green
Write-Host "  - Backend Main Classes Refactored: $mainCount"
Write-Host "  - Backend Test Suites Refactored:  $testCount"
if ($doFrontend) {
    Write-Host "  - Frontend Files Copied:           $frontCount"
}
Write-Host "  - Target Package:                  $finalPkg"
Write-Host "  - Target Location:                 $(Join-Path $mainJava ($finalPkg.Replace('.', '\')))"
Write-Host "`nNext Steps for your project:" -ForegroundColor White
Write-Host "  1. Ensure your pom.xml contains:"
Write-Host "     - spring-boot-starter-web"
Write-Host "     - spring-boot-starter-data-jpa"
Write-Host "     - spring-boot-starter-validation"
Write-Host "     - spring-boot-starter-security"
Write-Host "     - spring-boot-starter-websocket"
Write-Host "     - io.jsonwebtoken:jjwt-api:0.12.6, jjwt-impl, jjwt-jackson"
Write-Host "  2. Run backend tests to verify:"
Write-Host "     mvn test" -ForegroundColor Cyan
if ($doFrontend) {
    Write-Host "  3. Ensure frontend dependencies are installed in your React app:"
    Write-Host "     npm install @stomp/stompjs sockjs-client react-hook-form reactstrap bootstrap react-router-dom @fortawesome/fontawesome-free" -ForegroundColor Cyan
}
Write-Host ""
