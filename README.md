# 国家电网刷题助手

离线刷题 Android App MVP。技术栈：Flutter 3.x、Dart 空安全、Material 3、sqflite、path、provider、shared_preferences。

## 下载 APK

最新 Release：

- https://github.com/suixiao78/psychic-dollop/releases

## 功能

- 首页按专科、本科、硕士显示科目和章节
- 顺序练习、随机练习、模拟考试
- 支持单选、多选、判断
- 选完即时判题，显示正确答案和解析
- 自动收集错题，支持错题重做
- 支持收藏题目
- 统计做题数、正确率、今日进度
- 设置每日刷题目标
- 全程离线，不需要登录和联网

## 题库

题库文件：

```text
assets/questions.json
```

首次启动时导入 SQLite。当前仓库内置示例题目，后续可以把资料整理成同一 JSON 格式后替换。

## 云构建

本仓库使用 GitHub Actions 构建 Android APK：

```text
.github/workflows/android-release.yml
```

触发方式：

- 推送到 `main` 或 `master`：构建并上传 APK Artifact
- 推送 `v*` tag：构建、上传 Artifact，并创建 GitHub Release
- 也可以在 Actions 页面手动 `workflow_dispatch`

构建流程：

1. 安装 Java 17
2. 安装 Flutter 3.24.0
3. 临时生成 Android 工程
4. 自动把 Kotlin 插件升级到 1.9.22
5. `flutter pub get`
6. `flutter analyze`
7. `flutter build apk --release`
8. 如果配置了签名 Secrets，用自定义 keystore 重新签名
9. 上传 `app-release.apk`

## 签名说明

当前如果没有配置签名 Secrets，GitHub Actions 会跳过自定义签名，上传 Flutter 默认签名的 APK。

配置正式 release 签名后，工作流会自动用你的 keystore 签名：

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_PASSWORD`
- `ANDROID_KEY_ALIAS`

完整步骤见：

```text
docs/SIGNING.md
```

## 本地构建

```powershell
flutter pub get
flutter analyze
flutter build apk --release
```

输出：

```text
build\app\outputs\flutter-apk\app-release.apk
```

## 项目结构

```text
lib/
 main.dart
 app.dart
 app_routes.dart
 db/
 models/
 providers/
 services/
 pages/
 widgets/
```
