param(
    [string]$Repo = "suixiao78/psychic-dollop",
    [string]$Alias = "upload",
    [string]$KeystorePath = "android/app/upload-keystore.jks",
    [string]$Dname = "CN=Grid Quiz, OU=Dev, O=Example, L=Beijing, ST=Beijing, C=CN"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path "pubspec.yaml")) {
    throw "Run this script from the Flutter project root."
}

if (Test-Path $KeystorePath) {
    throw "Keystore already exists: $KeystorePath. Back it up or delete it first."
}

function New-RandomPassword {
    param([int]$Length = 24)
    $chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_"
    $result = -join (1..$Length | ForEach-Object {
        $chars[(Get-Random -Minimum 0 -Maximum $chars.Length)]
    })
    return $result
}

function Test-KeytoolPath {
    param([string]$Path)
    if (-not $Path) { return $false }
    if (-not (Test-Path -LiteralPath $Path)) { return $false }

    $stdout = [IO.Path]::GetTempFileName()
    $stderr = [IO.Path]::GetTempFileName()
    try {
        $process = Start-Process -FilePath $Path -ArgumentList "-help" -Wait -PassThru -NoNewWindow `
            -RedirectStandardOutput $stdout -RedirectStandardError $stderr
        if ($process.ExitCode -eq 0) { return $true }

        $outText = Get-Content -LiteralPath $stdout -Raw -ErrorAction SilentlyContinue
        $errText = Get-Content -LiteralPath $stderr -Raw -ErrorAction SilentlyContinue
        return (($outText + $errText) -match "Key and Certificate Management Tool")
    } catch {
        return $false
    } finally {
        Remove-Item -LiteralPath $stdout, $stderr -Force -ErrorAction SilentlyContinue
    }
}

function Find-Keytool {
    $cmd = Get-Command keytool -ErrorAction SilentlyContinue
    if ($null -ne $cmd) {
        $cmdPath = $null
        if ($cmd.Path) { $cmdPath = $cmd.Path }
        if (-not $cmdPath -and $cmd.Source) { $cmdPath = $cmd.Source }
        if ($cmdPath -and (Test-KeytoolPath $cmdPath)) {
            return $cmdPath
        }
    }

    $candidates = New-Object System.Collections.Generic.List[string]
    if ($env:JAVA_HOME) {
        $candidates.Add((Join-Path $env:JAVA_HOME "bin\keytool.exe"))
    }
    $candidates.Add("C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe")
    $candidates.Add("C:\Program Files\Android\Android Studio\jre\bin\keytool.exe")
    if ($env:LOCALAPPDATA) {
        $candidates.Add("$env:LOCALAPPDATA\Android\Android Studio\jbr\bin\keytool.exe")
        $candidates.Add("$env:LOCALAPPDATA\Programs\Eclipse Adoptium\bin\keytool.exe")
    }

    foreach ($file in $candidates) {
        if (Test-KeytoolPath $file) { return $file }
    }

    $searchRoots = @(
        "$env:ProgramFiles\Eclipse Adoptium",
        "$env:ProgramFiles\Microsoft",
        "$env:ProgramFiles\Java",
        "$env:LOCALAPPDATA\Programs\Eclipse Adoptium"
    )

    foreach ($root in $searchRoots) {
        if (Test-Path $root) {
            $found = Get-ChildItem -Path $root -Filter "keytool.exe" -Recurse -ErrorAction SilentlyContinue |
                Select-Object -First 10
            foreach ($item in $found) {
                if (Test-KeytoolPath $item.FullName) { return $item.FullName }
            }
        }
    }

    return $null
}

$keytoolPath = Find-Keytool
if (-not $keytoolPath) {
    throw "No working keytool found. Install JDK 17 or Android Studio, then rerun this script."
}

$storePassword = New-RandomPassword
$keyPassword = $storePassword

$keystoreDir = Split-Path -Parent $KeystorePath
if ($keystoreDir -and -not (Test-Path $keystoreDir)) {
    New-Item -ItemType Directory -Force -Path $keystoreDir | Out-Null
}

Write-Host "Using keytool: $keytoolPath"
Write-Host "Generating keystore: $KeystorePath"
& $keytoolPath -genkeypair -v `
    -keystore $KeystorePath `
    -storetype JKS `
    -keyalg RSA `
    -keysize 2048 `
    -validity 10000 `
    -alias $Alias `
    -storepass $storePassword `
    -keypass $keyPassword `
    -dname $Dname

if ($LASTEXITCODE -ne 0) {
    throw "keytool failed with exit code $LASTEXITCODE"
}

$resolvedKeystore = (Resolve-Path $KeystorePath).Path
$base64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($resolvedKeystore))

$keyPropertiesPath = "android/key.properties"
$keyPropertiesContent = @"
storePassword=$storePassword
keyPassword=$keyPassword
keyAlias=$Alias
storeFile=$(Split-Path $KeystorePath -Leaf)
"@
[IO.File]::WriteAllText(
    (Join-Path (Get-Location) $keyPropertiesPath),
    $keyPropertiesContent,
    [Text.UTF8Encoding]::new($false)
)

$gh = Get-Command gh -ErrorAction SilentlyContinue
if ($null -eq $gh) {
    Write-Warning "GitHub CLI gh was not found. Set these GitHub Secrets manually."
    Write-Host "ANDROID_KEYSTORE_BASE64=$base64"
    Write-Host "ANDROID_KEYSTORE_PASSWORD=$storePassword"
    Write-Host "ANDROID_KEY_PASSWORD=$keyPassword"
    Write-Host "ANDROID_KEY_ALIAS=$Alias"
} else {
    gh auth status 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "gh is not logged in. Run: gh auth login"
    }

    Write-Host "Writing GitHub Secrets to: $Repo"
    $base64 | gh secret set ANDROID_KEYSTORE_BASE64 --repo $Repo
    $storePassword | gh secret set ANDROID_KEYSTORE_PASSWORD --repo $Repo
    $keyPassword | gh secret set ANDROID_KEY_PASSWORD --repo $Repo
    $Alias | gh secret set ANDROID_KEY_ALIAS --repo $Repo
}

Write-Host ""
Write-Host "=========================================="
Write-Host "Signing configured. Back up these values:"
Write-Host "Keystore: $resolvedKeystore"
Write-Host "Alias: $Alias"
Write-Host "StorePassword: $storePassword"
Write-Host "KeyPassword: $keyPassword"
Write-Host "=========================================="
Write-Host ""
Write-Host "android/key.properties was generated."
Write-Host "keystore and key.properties are already in .gitignore."
Write-Host "Next, push a new tag:"
Write-Host "git tag v1.0.1"
Write-Host "git push origin v1.0.1"