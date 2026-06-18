# ImageHoster

[中文](README.md) | English

ImageHoster is a macOS image hosting tool. After configuring object storage, you can upload images by drag and drop or file picker, then copy a plain URL or Markdown image link.

![ImageHoster main screen](docs/images/app-main-zh.png)

## Features

- Supports Alibaba Cloud OSS, Tencent Cloud COS, and Qiniu Kodo.
- Upload by drag and drop or by clicking the upload area.
- Shows both plain URL and Markdown image link after upload.
- Copy each link separately or copy both links at once.
- Keeps each provider configuration separate.
- Stores AccessKey / SecretKey in macOS Keychain.

## Requirements

- macOS 11.0 Big Sur or later.
- The current package script targets Apple Silicon / arm64.

## Configuration

Required fields:

- Provider
- AccessKey / SecretId
- SecretKey
- Container name, also known as bucket or space name
- Region
- Endpoint
- Public domain
- Upload prefix

Notes:

- Tencent Cloud COS bucket names usually include AppId, for example `my-bucket-1250000000`.
- Qiniu Kodo requires a public CDN domain.
- Unsaved fields are not persisted.

## Usage

1. Select a provider and fill in the configuration.
2. Click “保存配置”.
3. Click the upload area to choose images, or drag images into it.
4. Copy links from the upload history after upload succeeds.

## Run

```bash
swift run ImageHoster
```

## Build

```bash
swift build --scratch-path /tmp/imagehoster-build
```

## Package App

```bash
./Scripts/package-app.sh
```

Output:

```text
dist/ImageHoster.app
```

## Create Release Package

```bash
./Scripts/release.sh 1.0.0
```

Output:

```text
release/ImageHoster-v1.0.0-macos-arm64.zip
```

Verify:

```bash
unzip -l release/ImageHoster-v1.0.0-macos-arm64.zip
```

GitHub Release example:

```bash
gh release create v1.0.0 \
  release/ImageHoster-v1.0.0-macos-arm64.zip \
  --title "ImageHoster v1.0.0" \
  --notes-file RELEASE_NOTES.md
```

## Data and Privacy

- The release package contains only `ImageHoster.app`.
- It does not include Keychain data, UserDefaults settings, upload history, caches, `.DS_Store`, or build directories.
- Scripts do not delete locally saved configuration or credentials.
