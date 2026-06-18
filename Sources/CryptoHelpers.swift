import CryptoKit
import Foundation

enum CryptoHelpers {
    static func sha1Hex(_ string: String) -> String {
        let digest = Insecure.SHA1.hash(data: Data(string.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    static func sha256Hex(_ string: String) -> String {
        let digest = SHA256.hash(data: Data(string.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    static func hmacSHA1Hex(key: String, message: String) -> String {
        let key = SymmetricKey(data: Data(key.utf8))
        let code = HMAC<Insecure.SHA1>.authenticationCode(for: Data(message.utf8), using: key)
        return Data(code).hexString
    }

    static func hmacSHA1Data(key: String, message: String) -> Data {
        let key = SymmetricKey(data: Data(key.utf8))
        let code = HMAC<Insecure.SHA1>.authenticationCode(for: Data(message.utf8), using: key)
        return Data(code)
    }

    static func hmacSHA256Data(key: Data, message: String) -> Data {
        let key = SymmetricKey(data: key)
        let code = HMAC<SHA256>.authenticationCode(for: Data(message.utf8), using: key)
        return Data(code)
    }

    static func hmacSHA256Data(key: String, message: String) -> Data {
        hmacSHA256Data(key: Data(key.utf8), message: message)
    }

    static func urlSafeBase64(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
    }
}

extension Data {
    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}

extension String {
    func pathPercentEncoded(allowSlash: Bool = true) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        if allowSlash {
            allowed.insert("/")
        }
        return addingPercentEncoding(withAllowedCharacters: allowed) ?? self
    }

    func queryPercentEncoded() -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return addingPercentEncoding(withAllowedCharacters: allowed) ?? self
    }
}
