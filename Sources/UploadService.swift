import AppKit
import Foundation

enum UploadError: LocalizedError {
    case missingConfiguration
    case badEndpoint
    case httpFailure(Int, String)

    var errorDescription: String? {
        switch self {
        case .missingConfiguration:
            "请先补全 AccessKey、SecretKey、容器名称、地区等配置"
        case .badEndpoint:
            "Endpoint 或公开访问域名格式不正确"
        case .httpFailure(let code, let body):
            "上传失败：HTTP \(code)\(body.isEmpty ? "" : " - \(body)")"
        }
    }
}

struct UploadService {
    func upload(file url: URL, config: AppConfiguration) async throws -> UploadedImage {
        guard config.isReady else { throw UploadError.missingConfiguration }

        let data = try Data(contentsOf: url)
        let objectKey = makeObjectKey(for: url, prefix: config.uploadPrefix)
        let publicURL: String

        switch config.provider {
        case .aliyun:
            try await uploadAliyun(data: data, mimeType: url.inferredMimeType, key: objectKey, config: config)
            publicURL = makePublicURL(config: config, key: objectKey, defaultHost: "\(config.bucket).\(cleanHost(config.endpoint))")
        case .tencent:
            let host = tencentHost(config)
            try await uploadTencent(data: data, mimeType: url.inferredMimeType, key: objectKey, host: host, config: config)
            publicURL = makePublicURL(config: config, key: objectKey, defaultHost: host)
        case .qiniu:
            try await uploadQiniu(data: data, fileName: url.lastPathComponent, mimeType: url.inferredMimeType, key: objectKey, config: config)
            publicURL = makePublicURL(config: config, key: objectKey, defaultHost: config.publicDomain)
        }

        return UploadedImage(
            localName: url.lastPathComponent,
            objectKey: objectKey,
            url: publicURL,
            provider: config.provider,
            uploadedAt: Date()
        )
    }

    private func uploadAliyun(data: Data, mimeType: String, key: String, config: AppConfiguration) async throws {
        let endpoint = cleanHost(config.endpoint)
        let host = "\(config.bucket).\(endpoint)"
        guard let url = URL(string: "\(scheme(config))://\(host)/\(key.pathPercentEncoded())") else {
            throw UploadError.badEndpoint
        }

        let now = Date()
        let timestamp = iso8601Basic.string(from: now)
        let signDate = yyyymmdd.string(from: now)
        let canonicalURI = "/\(config.bucket)/\(key)".pathPercentEncoded()
        let canonicalHeaders = [
            "content-type:\(mimeType)",
            "x-oss-content-sha256:UNSIGNED-PAYLOAD",
            "x-oss-date:\(timestamp)"
        ].joined(separator: "\n") + "\n"
        let canonicalRequest = [
            "PUT",
            canonicalURI,
            "",
            canonicalHeaders,
            "",
            "UNSIGNED-PAYLOAD"
        ].joined(separator: "\n")
        let scope = "\(signDate)/\(config.region.trimmed)/oss/aliyun_v4_request"
        let stringToSign = [
            "OSS4-HMAC-SHA256",
            timestamp,
            scope,
            CryptoHelpers.sha256Hex(canonicalRequest)
        ].joined(separator: "\n")

        let dateKey = CryptoHelpers.hmacSHA256Data(key: "aliyun_v4\(config.secretKey.trimmed)", message: signDate)
        let dateRegionKey = CryptoHelpers.hmacSHA256Data(key: dateKey, message: config.region.trimmed)
        let dateRegionServiceKey = CryptoHelpers.hmacSHA256Data(key: dateRegionKey, message: "oss")
        let signingKey = CryptoHelpers.hmacSHA256Data(key: dateRegionServiceKey, message: "aliyun_v4_request")
        let signature = CryptoHelpers.hmacSHA256Data(key: signingKey, message: stringToSign).hexString
        let authorization = "OSS4-HMAC-SHA256 Credential=\(config.accessKey.trimmed)/\(scope),AdditionalHeaders=,Signature=\(signature)"

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.httpBody = data
        request.setValue(mimeType, forHTTPHeaderField: "Content-Type")
        request.setValue(timestamp, forHTTPHeaderField: "x-oss-date")
        request.setValue("UNSIGNED-PAYLOAD", forHTTPHeaderField: "x-oss-content-sha256")
        request.setValue(authorization, forHTTPHeaderField: "Authorization")
        try await send(request)
    }

    private func uploadTencent(data: Data, mimeType: String, key: String, host: String, config: AppConfiguration) async throws {
        guard let url = URL(string: "\(scheme(config))://\(host)/\(key.pathPercentEncoded())") else {
            throw UploadError.badEndpoint
        }

        let now = Int(Date().timeIntervalSince1970)
        let keyTime = "\(now);\(now + 3600)"
        let headers = [
            "content-type": mimeType,
            "host": host
        ]
        let headerKeys = headers.keys.sorted()
        let headerList = headerKeys.joined(separator: ";")
        let httpHeaders = headerKeys
            .map { "\($0.queryPercentEncoded())=\((headers[$0] ?? "").queryPercentEncoded())" }
            .joined(separator: "&")
        let httpString = [
            "put",
            "/\(key)".pathPercentEncoded(),
            "",
            httpHeaders
        ].joined(separator: "\n") + "\n"

        let signKey = CryptoHelpers.hmacSHA1Hex(key: config.secretKey.trimmed, message: keyTime)
        let stringToSign = [
            "sha1",
            keyTime,
            CryptoHelpers.sha1Hex(httpString)
        ].joined(separator: "\n") + "\n"
        let signature = CryptoHelpers.hmacSHA1Hex(key: signKey, message: stringToSign)
        let authorization = [
            "q-sign-algorithm=sha1",
            "q-ak=\(config.accessKey.trimmed)",
            "q-sign-time=\(keyTime)",
            "q-key-time=\(keyTime)",
            "q-header-list=\(headerList)",
            "q-url-param-list=",
            "q-signature=\(signature)"
        ].joined(separator: "&")

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.httpBody = data
        request.setValue(mimeType, forHTTPHeaderField: "Content-Type")
        request.setValue(authorization, forHTTPHeaderField: "Authorization")
        try await send(request)
    }

    private func uploadQiniu(data: Data, fileName: String, mimeType: String, key: String, config: AppConfiguration) async throws {
        guard let uploadURL = URL(string: cleanURL(config.endpoint.isEmpty ? "https://upload.qiniup.com" : config.endpoint)) else {
            throw UploadError.badEndpoint
        }

        let token = try qiniuUploadToken(key: key, config: config)
        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()
        body.appendMultipartField(name: "key", value: key, boundary: boundary)
        body.appendMultipartField(name: "token", value: token, boundary: boundary)
        body.appendMultipartFile(name: "file", fileName: fileName, mimeType: mimeType, data: data, boundary: boundary)
        body.appendString("--\(boundary)--\r\n")

        var request = URLRequest(url: uploadURL)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        try await send(request)
    }

    private func qiniuUploadToken(key: String, config: AppConfiguration) throws -> String {
        let deadline = Int(Date().timeIntervalSince1970) + 3600
        let policy: [String: Any] = [
            "scope": "\(config.bucket.trimmed):\(key)",
            "deadline": deadline
        ]
        let policyData = try JSONSerialization.data(withJSONObject: policy, options: [])
        let encodedPolicy = CryptoHelpers.urlSafeBase64(policyData)
        let sign = CryptoHelpers.hmacSHA1Data(key: config.secretKey.trimmed, message: encodedPolicy)
        let encodedSign = CryptoHelpers.urlSafeBase64(sign)
        return "\(config.accessKey.trimmed):\(encodedSign):\(encodedPolicy)"
    }

    private func send(_ request: URLRequest) async throws {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { return }
        guard (200...299).contains(http.statusCode) else {
            let body = String(data: data.prefix(800), encoding: .utf8) ?? ""
            throw UploadError.httpFailure(http.statusCode, body)
        }
    }

    private func makeObjectKey(for url: URL, prefix: String) -> String {
        let ext = url.pathExtension.isEmpty ? "png" : url.pathExtension.lowercased()
        let base = url.deletingPathExtension().lastPathComponent
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
            .lowercased()
        let stamp = objectDateFormatter.string(from: Date())
        let name = base.isEmpty ? "image" : base
        let fileName = "\(stamp)-\(UUID().uuidString.prefix(8))-\(name).\(ext)"
        let cleanPrefix = prefix.trimmed.trimmingSlashes()
        return cleanPrefix.isEmpty ? fileName : "\(cleanPrefix)/\(fileName)"
    }

    private func makePublicURL(config: AppConfiguration, key: String, defaultHost: String) -> String {
        let host = (config.publicDomain.trimmed.isEmpty ? defaultHost : config.publicDomain.trimmed)
        let base = host.prefixedWithScheme(useHTTPS: config.useHTTPS).trimmingSlashes()
        return "\(base)/\(key.pathPercentEncoded())"
    }

    private func tencentHost(_ config: AppConfiguration) -> String {
        let endpoint = cleanHost(config.endpoint)
        if endpoint.contains(config.bucket) {
            return endpoint
        }
        if endpoint.contains("myqcloud.com") && endpoint.hasPrefix("cos.") {
            return "\(config.bucket.trimmed).\(endpoint)"
        }
        return "\(config.bucket.trimmed).cos.\(config.region.trimmed).myqcloud.com"
    }

    private func scheme(_ config: AppConfiguration) -> String {
        config.useHTTPS ? "https" : "http"
    }

    private func cleanHost(_ value: String) -> String {
        var host = value.trimmed
        host = host.replacingOccurrences(of: "https://", with: "")
        host = host.replacingOccurrences(of: "http://", with: "")
        return host.trimmingSlashes()
    }

    private func cleanURL(_ value: String) -> String {
        value.trimmed.prefixedWithScheme(useHTTPS: true).trimmingSlashes()
    }
}

private let iso8601Basic: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
    return formatter
}()

private let yyyymmdd: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "yyyyMMdd"
    return formatter
}()

private let objectDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyyMMdd-HHmmss"
    return formatter
}()

private extension Data {
    mutating func appendString(_ string: String) {
        append(Data(string.utf8))
    }

    mutating func appendMultipartField(name: String, value: String, boundary: String) {
        appendString("--\(boundary)\r\n")
        appendString("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
        appendString("\(value)\r\n")
    }

    mutating func appendMultipartFile(name: String, fileName: String, mimeType: String, data: Data, boundary: String) {
        appendString("--\(boundary)\r\n")
        appendString("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(fileName)\"\r\n")
        appendString("Content-Type: \(mimeType)\r\n\r\n")
        append(data)
        appendString("\r\n")
    }
}
