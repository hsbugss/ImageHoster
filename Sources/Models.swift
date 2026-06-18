import Foundation
import UniformTypeIdentifiers

enum CloudProvider: String, CaseIterable, Identifiable, Codable {
    case aliyun
    case tencent
    case qiniu

    var id: String { rawValue }

    var title: String {
        switch self {
        case .aliyun: "阿里云 OSS"
        case .tencent: "腾讯云 COS"
        case .qiniu: "七牛云 Kodo"
        }
    }
}

struct CloudRegion: Identifiable, Hashable {
    let id: String
    let name: String

    var title: String {
        "\(name)  \(id)"
    }
}

extension CloudProvider {
    var regions: [CloudRegion] {
        switch self {
        case .aliyun:
            [
                CloudRegion(id: "cn-beijing", name: "华北 2（北京）"),
                CloudRegion(id: "cn-hangzhou", name: "华东 1（杭州）"),
                CloudRegion(id: "cn-shanghai", name: "华东 2（上海）"),
                CloudRegion(id: "cn-shenzhen", name: "华南 1（深圳）"),
                CloudRegion(id: "cn-guangzhou", name: "华南 3（广州）"),
                CloudRegion(id: "cn-chengdu", name: "西南 1（成都）"),
                CloudRegion(id: "cn-hongkong", name: "中国香港"),
                CloudRegion(id: "ap-southeast-1", name: "新加坡")
            ]
        case .tencent:
            [
                CloudRegion(id: "ap-beijing", name: "北京"),
                CloudRegion(id: "ap-guangzhou", name: "广州"),
                CloudRegion(id: "ap-shanghai", name: "上海"),
                CloudRegion(id: "ap-nanjing", name: "南京"),
                CloudRegion(id: "ap-chengdu", name: "成都"),
                CloudRegion(id: "ap-hongkong", name: "中国香港"),
                CloudRegion(id: "ap-singapore", name: "新加坡"),
                CloudRegion(id: "na-siliconvalley", name: "硅谷")
            ]
        case .qiniu:
            [
                CloudRegion(id: "z0", name: "华东"),
                CloudRegion(id: "z1", name: "华北"),
                CloudRegion(id: "z2", name: "华南"),
                CloudRegion(id: "na0", name: "北美"),
                CloudRegion(id: "as0", name: "东南亚"),
                CloudRegion(id: "cn-east-2", name: "华东浙江 2")
            ]
        }
    }
}

struct AppConfiguration: Codable, Equatable {
    var provider: CloudProvider = .aliyun
    var accessKey: String = ""
    var secretKey: String = ""
    var bucket: String = ""
    var region: String = "cn-hangzhou"
    var endpoint: String = "oss-cn-hangzhou.aliyuncs.com"
    var publicDomain: String = ""
    var uploadPrefix: String = "images"
    var useHTTPS: Bool = true
    var copyMarkdown: Bool = false

    var isReady: Bool {
        !accessKey.trimmed.isEmpty &&
        !secretKey.trimmed.isEmpty &&
        !bucket.trimmed.isEmpty &&
        !region.trimmed.isEmpty &&
        (provider != .qiniu || !publicDomain.trimmed.isEmpty)
    }
}

struct PersistedConfiguration: Codable, Equatable {
    var provider: CloudProvider
    var bucket: String
    var region: String
    var endpoint: String
    var publicDomain: String
    var uploadPrefix: String
    var useHTTPS: Bool
    var copyMarkdown: Bool

    init(from config: AppConfiguration) {
        provider = config.provider
        bucket = config.bucket
        region = config.region
        endpoint = config.endpoint
        publicDomain = config.publicDomain
        uploadPrefix = config.uploadPrefix
        useHTTPS = config.useHTTPS
        copyMarkdown = config.copyMarkdown
    }

    var configuration: AppConfiguration {
        AppConfiguration(
            provider: provider,
            bucket: bucket,
            region: region,
            endpoint: endpoint,
            publicDomain: publicDomain,
            uploadPrefix: uploadPrefix,
            useHTTPS: useHTTPS,
            copyMarkdown: copyMarkdown
        )
    }
}

struct UploadedImage: Identifiable, Equatable {
    let id = UUID()
    let localName: String
    let objectKey: String
    let url: String
    let provider: CloudProvider
    let uploadedAt: Date

    var markdownURL: String {
        "![\(localName)](\(url))"
    }
}

enum UploadStatus: Equatable {
    case idle
    case uploading(String)
    case success(String)
    case failure(String)
}

extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func trimmingSlashes() -> String {
        trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    func prefixedWithScheme(useHTTPS: Bool) -> String {
        if hasPrefix("http://") || hasPrefix("https://") {
            return self
        }
        return "\(useHTTPS ? "https" : "http")://\(self)"
    }
}

extension URL {
    var inferredMimeType: String {
        if let type = UTType(filenameExtension: pathExtension),
           let mimeType = type.preferredMIMEType {
            return mimeType
        }

        switch pathExtension.lowercased() {
        case "jpg", "jpeg": return "image/jpeg"
        case "png": return "image/png"
        case "gif": return "image/gif"
        case "webp": return "image/webp"
        case "heic": return "image/heic"
        default: return "application/octet-stream"
        }
    }
}
