param(
    [string]$Repo = "suixiao78/psychic-dollop",
    [string]$Alias = "upload",
    [string]$KeystorePath = "android/app/upload-keystore.jks",
    [string]$Dname = "CN=Grid Quiz, OU=Dev, O=Example, L=Beijing, ST=Beijing, C=CN"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path "pubspec.yaml")) {
    throw "请在 Flutter 项目根目录运行此脚本"
}

if (Test-Path $KeystorePath) {
    throw "签名文件已存在：$KeystorePath，请先备份或删除后再运行"
}

function New-RandomPassword {
    param([int]$Length = 24)
    $chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_"
    $result = -join (1..$Length | ForEach-Object {
        $chars[(Get-Random -Minimum 0 -Maximum $chars.Length)]
    })
    return $result
}

$storePassword = New-RandomPassword
$keyPassword = $storePassword

$keytool = Get-Command keytool -ErrorAction SilentlyContinue
if ($null -eq $keytool) {
    if ($env:JAVA_HOME) {
        $candidate = Join-Path $env:JAVA_HOME "bin\keytool.exe"
        if (Test-Path $candidate) {
            $keytool = Get-Item $candidate
        }
    }
}

if ($null -eq $keytool) {
    throw "未找到 keytool，请安装 JDK 17 并加入 PATH，或设置 JAVA_HOME"
}

$keystoreDir = Split-Path -Parent $KeystorePath
if ($keystoreDir -and -not (Test-Path $keystoreDir)) {
    New-Item -ItemType Directory -Force -Path $keystoreDir | Out-Null
}

Write-Host "正在生成签名文件：$KeystorePath"
& $keytool.FullName -genkeypair -v `
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
    throw "keytool 生成签名失败，退出码：$LASTEXITCODE"
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
    Write-Warning "未找到 GitHub CLI gh，请手动配置 Secrets。"
    Write-Host "Secrets:"
    Write-Host "ANDROID_KEYSTORE_BASE64=$base64"
    Write-Host "ANDROID_KEYSTORE_PASSWORD=$storePassword"
    Write-Host "ANDROID_KEY_PASSWORD=$keyPassword"
    Write-Host "ANDROID_KEY_ALIAS=$Alias"
} else {
    gh auth status 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "gh 尚未登录，请先执行：gh auth login"
    }

    Write-Host "正在写入 GitHub Secrets：$Repo"
    $base64 | gh secret set ANDROID_KEYSTORE_BASE64 --repo $Repo
    $storePassword | gh secret set ANDROID_KEYSTORE_PASSWORD --repo $Repo
    $keyPassword | gh secret set ANDROID_KEY_PASSWORD --repo $Repo
    $Alias | gh secret set ANDROID_KEY_ALIAS --repo $Repo
}

Write-Host ""
Write-Host "=========================================="
Write-Host "签名配置完成，请立即备份以下内容："
Write-Host "Keystore: $resolvedKeystore"
Write-Host "Alias: $Alias"
Write-Host "StorePassword: $storePassword"
Write-Host "KeyPassword: $keyPassword"
Write-Host "=========================================="
Write-Host ""
Write-Host "android/key.properties 已生成，keystore 与 key.properties 已加入 .gitignore。"
Write-Host "接下来推送新的 tag 即可触发正式签名 APK："
Write-Host "git tag v1.0.1"
Write-Host "git push origin v1.0.1"