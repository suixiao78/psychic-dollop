# Android Release 签名配置

## 1. 生成 keystore

```powershell
keytool -genkeypair -v `
  -keystore "D:\FlutterProjects\grid_quiz_app\android\app\upload-keystore.jks" `
  -storetype JKS `
  -keyalg RSA `
  -keysize 2048 `
  -validity 10000 `
  -alias upload `
  -dname "CN=Grid Quiz, OU=Dev, O=Example, L=Beijing, ST=Beijing, C=CN"
```

## 2. 生成 Base64

```powershell
$keystorePath = 'D:\FlutterProjects\grid_quiz_app\android\app\upload-keystore.jks'

[Convert]::ToBase64String(
    [IO.File]::ReadAllBytes($keystorePath)
) | Set-Clipboard
```

## 3. 配置 GitHub Secrets

进入仓库：

```text
Settings -> Secrets and variables -> Actions -> New repository secret
```

添加：

| Secret 名称 | 内容 |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | keystore 文件 Base64 |
| `ANDROID_KEYSTORE_PASSWORD` | keystore 密码 |
| `ANDROID_KEY_PASSWORD` | key 密码 |
| `ANDROID_KEY_ALIAS` | key 别名，例如 `upload` |

## 4. 触发云构建

推送代码：

```powershell
git push origin main
```

或创建 tag：

```powershell
git tag v1.0.1
git push origin v1.0.1
```

工作流会自动：

1. 解码 keystore
2. 构建 `app-release.apk`
3. 使用 `zipalign`
4. 使用 `apksigner` 自定义签名
5. 上传 Artifact
6. 如果是 tag，则创建 GitHub Release

## 5. 本地 build.gradle 配置

如果本地也需要 release 签名，在 `android/app/build.gradle` 或 `android/app/build.gradle.kts` 中配置：

```groovy
signingConfigs {
    release {
        keyAlias keystoreProperties['keyAlias']
        keyPassword keystoreProperties['keyPassword']
        storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
        storePassword keystoreProperties['storePassword']
    }
}

buildTypes {
    release {
        signingConfig signingConfigs.release
    }
}
```

具体 keystore 属性放在：

```text
android/key.properties
```

内容：

```properties
storePassword=你的Keystore密码
keyPassword=你的Key密码
keyAlias=upload
storeFile=upload-keystore.jks
```