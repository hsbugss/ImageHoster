import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var uploader: UploadViewModel

    var body: some View {
        HStack(spacing: 0) {
            SettingsPanel()
                .frame(width: 438)
            Divider()
            UploadPanel()
        }
        .frame(minWidth: 980, minHeight: 680)
    }
}

private struct SettingsPanel: View {
    @EnvironmentObject private var settings: SettingsStore

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    SettingsGroup("存储") {
                        Picker("服务商", selection: settings.providerSelection) {
                            ForEach(CloudProvider.allCases) { provider in
                                Text(provider.title).tag(provider)
                            }
                        }
                        .pickerStyle(.segmented)
                        .controlSize(.large)

                        SettingsTextField(
                            title: settings.configuration.provider == .tencent ? "SecretId / AccessKey" : "AccessKey",
                            placeholder: settings.configuration.provider == .tencent ? "输入腾讯云 SecretId" : "输入 AccessKey",
                            text: $settings.configuration.accessKey
                        )

                        SettingsSecureField(
                            title: "SecretKey",
                            placeholder: "输入 SecretKey",
                            text: $settings.configuration.secretKey
                        )
                    }

                    SettingsGroup("容器") {
                        SettingsTextField(title: "容器名称", placeholder: bucketPlaceholder, text: $settings.configuration.bucket)

                        VStack(alignment: .leading, spacing: 7) {
                            Text("地区")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.secondary)
                            Picker("地区", selection: regionSelection) {
                                ForEach(settings.configuration.provider.regions) { region in
                                    Text(region.title).tag(region.id)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .controlSize(.large)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        SettingsTextField(title: "Endpoint", placeholder: endpointPlaceholder, text: $settings.configuration.endpoint)
                        SettingsTextField(title: "公开域名", placeholder: publicDomainPlaceholder, text: $settings.configuration.publicDomain)
                        SettingsTextField(title: "上传目录", placeholder: "例如 images 或 blog/2026", text: $settings.configuration.uploadPrefix)
                    }

                    SettingsGroup("输出") {
                        Toggle("使用 HTTPS", isOn: $settings.configuration.useHTTPS)
                        Toggle("上传后复制 Markdown 图片语法", isOn: $settings.configuration.copyMarkdown)
                    }
                }
                .padding(18)
            }

            Divider()

            HStack(spacing: 10) {
                Button {
                    settings.saveConfiguration()
                } label: {
                    Label("保存配置", systemImage: "checkmark.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(DefaultButtonStyle())
                .controlSize(.large)

                Button {
                    settings.clearCurrentProviderConfiguration()
                } label: {
                    Label("清空配置", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .help("清空当前服务商的配置和密钥")

                if !settings.saveMessage.isEmpty {
                    Label(settings.saveMessage, systemImage: "checkmark")
                        .font(.caption)
                    .foregroundColor(settings.saveMessage.contains("清空") ? .orange : .green)
                    .lineLimit(1)
                }
            }
            .padding(14)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var regionSelection: Binding<String> {
        Binding(
            get: { settings.configuration.region },
            set: { settings.setRegion($0) }
        )
    }

    private var bucketPlaceholder: String {
        switch settings.configuration.provider {
        case .aliyun: "容器名称，例如 my-bucket"
        case .tencent: "容器名称，例如 my-bucket-1250000000"
        case .qiniu: "空间名称，例如 my-bucket"
        }
    }

    private var regionPlaceholder: String {
        switch settings.configuration.provider {
        case .aliyun: "Region，例如 cn-hangzhou"
        case .tencent: "Region，例如 ap-guangzhou"
        case .qiniu: "区域标识，可填 z0 / cn-east-2 等作备注"
        }
    }

    private var endpointPlaceholder: String {
        switch settings.configuration.provider {
        case .aliyun: "Endpoint，例如 oss-cn-hangzhou.aliyuncs.com"
        case .tencent: "Endpoint，可留 cos.ap-guangzhou.myqcloud.com"
        case .qiniu: "上传地址，例如 https://upload.qiniup.com"
        }
    }

    private var publicDomainPlaceholder: String {
        switch settings.configuration.provider {
        case .aliyun: "公开域名，可留空使用 bucket.endpoint"
        case .tencent: "公开域名，可留空使用 COS 默认域名"
        case .qiniu: "公开 CDN 域名，七牛必填"
        }
    }
}

private struct SettingsGroup<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.headline)
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct SettingsTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
            TextField(placeholder, text: $text)
                .textFieldStyle(.roundedBorder)
                .controlSize(.large)
        }
    }
}

private struct SettingsSecureField: View {
    let title: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
            SecureField(placeholder, text: $text)
                .textFieldStyle(.roundedBorder)
                .controlSize(.large)
        }
    }
}

private struct UploadPanel: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var uploader: UploadViewModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button {
                    Task { await pickFiles() }
                } label: {
                    Label("选择图片", systemImage: "photo.on.rectangle")
                }

                Spacer()

                statusView
            }
            .padding(16)

            DropZone {
                Task { await pickFiles() }
            }
                .padding(.horizontal, 16)

            HistoryList()
                .padding(16)
        }
    }

    @ViewBuilder
    private var statusView: some View {
        switch uploader.status {
        case .idle:
            ResultBadge(title: "待上传", detail: "等待图片", systemImage: "checkmark.circle", tint: .secondary)
        case .uploading(let name):
            ResultBadge(title: "上传中", detail: name, systemImage: "arrow.up.circle", tint: .accentColor, showsProgress: true)
        case .success(let url):
            ResultBadge(title: "上传成功", detail: "链接已复制", systemImage: "checkmark.circle.fill", tint: .green)
                .help(url)
        case .failure(let message):
            ResultBadge(title: "上传失败", detail: message, systemImage: "exclamationmark.triangle.fill", tint: .red)
                .help(message)
        }
    }

    private func pickFiles() async {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.image]
        if panel.runModal() == .OK {
            await uploader.upload(urls: panel.urls, using: settings.configuration)
        }
    }
}

private struct ResultBadge: View {
    let title: String
    let detail: String
    let systemImage: String
    let tint: Color
    var showsProgress = false

    var body: some View {
        HStack(spacing: 8) {
            if showsProgress {
                ProgressView()
                    .scaleEffect(0.65)
            } else {
                Image(systemName: systemImage)
                    .foregroundColor(tint)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                Text(detail)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(maxWidth: 240, alignment: .leading)
        .background(tint.opacity(tint == .secondary ? 0.08 : 0.12))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct DropZone: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var uploader: UploadViewModel
    let onPickFiles: () -> Void

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .foregroundColor(uploader.isDropTargeted ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            uploader.isDropTargeted ? Color.accentColor : Color.secondary.opacity(0.28),
                            style: StrokeStyle(lineWidth: 1.5, dash: [7, 6])
                        )
                )

            VStack(spacing: 12) {
                Image(systemName: "arrow.down.doc")
                    .font(.system(size: 42, weight: .regular))
                    .foregroundColor(.secondary)
                Text("点击或拖拽图片到这里上传")
                    .font(.title3.weight(.semibold))
                Text("支持 PNG、JPEG、GIF、WebP、HEIC 等系统可识别图片")
                    .foregroundColor(.secondary)
            }
            .padding(28)
        }
        .frame(minHeight: 230)
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .onTapGesture {
            onPickFiles()
        }
        .help("点击选择图片，或将图片拖拽到这里上传")
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: $uploader.isDropTargeted) { providers in
            loadDroppedFiles(from: providers)
            return true
        }
    }

    private func loadDroppedFiles(from providers: [NSItemProvider]) {
        let group = DispatchGroup()
        let collector = ThreadSafeURLCollector()

        for provider in providers {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                defer { group.leave() }
                let url: URL?
                if let data = item as? Data,
                   let string = String(data: data, encoding: .utf8) {
                    url = URL(string: string)
                } else {
                    url = item as? URL
                }

                if let url {
                    collector.append(url)
                }
            }
        }

        group.notify(queue: .main) {
            Task { await uploader.upload(urls: collector.snapshot, using: settings.configuration) }
        }
    }
}

private final class ThreadSafeURLCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var urls: [URL] = []

    var snapshot: [URL] {
        lock.lock()
        defer { lock.unlock() }
        return urls
    }

    func append(_ url: URL) {
        lock.lock()
        urls.append(url)
        lock.unlock()
    }
}

private struct HistoryList: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var uploader: UploadViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("上传记录")
                    .font(.headline)
                Spacer()
                if !uploader.history.isEmpty {
                    Button {
                        uploader.history.removeAll()
                    } label: {
                        Label("清空", systemImage: "trash")
                    }
                    .labelStyle(.iconOnly)
                    .help("清空上传记录")
                }
            }

            if uploader.history.isEmpty {
                EmptyHistoryView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(uploader.history) { image in
                    HistoryRow(image: image)
                        .environmentObject(uploader)
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}

private struct EmptyHistoryView: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray")
                .font(.system(size: 34, weight: .regular))
                .foregroundColor(.secondary)
            Text("还没有上传记录")
                .font(.headline)
            Text("上传图片后会在这里显示普通链接和 Markdown 链接")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(24)
    }
}

private struct HistoryRow: View {
    @EnvironmentObject private var uploader: UploadViewModel
    let image: UploadedImage

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(image.localName)
                .font(.body.weight(.medium))
                .lineLimit(1)

            LinkLine(title: "链接", value: image.url) {
                uploader.copyToPasteboard(image.url)
            }

            LinkLine(title: "Markdown", value: image.markdownURL) {
                uploader.copyToPasteboard(image.markdownURL)
            }

            Button {
                uploader.copyToPasteboard("\(image.url)\n\(image.markdownURL)")
            } label: {
                Label("复制全部", systemImage: "square.on.square")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("同时复制普通链接和 Markdown 图片链接")
        }
        .padding(.vertical, 9)
    }
}

private struct LinkLine: View {
    let title: String
    let value: String
    let copy: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundColor(.secondary)
                .frame(width: 70, alignment: .leading)
            Text(value)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            Button(action: copy) {
                Label("复制\(title)", systemImage: "doc.on.doc")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("复制\(title)")
        }
    }
}
