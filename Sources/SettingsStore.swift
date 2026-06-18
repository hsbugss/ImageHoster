import Foundation
import SwiftUI

@MainActor
final class SettingsStore: ObservableObject {
    @Published var configuration: AppConfiguration
    @Published var saveMessage: String = ""

    private let legacyDefaultsKey = "imageHoster.configuration.v1"
    private let legacySavedMarkerKey = "imageHoster.configuration.explicitlySaved.v1"
    private let selectedProviderKey = "imageHoster.selectedProvider.v2"
    private let keychain = KeychainStore(service: "local.imagehoster.app.keys.v2")

    init() {
        configuration = AppConfiguration()
        migrateLegacyConfigurationIfNeeded()

        let provider = selectedProvider()
        configuration = storedConfiguration(for: provider) ?? defaultConfiguration(for: provider)
        loadCredentials(for: provider)
    }

    var providerSelection: Binding<CloudProvider> {
        Binding(
            get: { self.configuration.provider },
            set: { self.selectProvider($0) }
        )
    }

    func selectProvider(_ provider: CloudProvider) {
        guard provider != configuration.provider else { return }

        UserDefaults.standard.set(provider.rawValue, forKey: selectedProviderKey)
        configuration = storedConfiguration(for: provider) ?? defaultConfiguration(for: provider)
        loadCredentials(for: provider)
        saveMessage = ""
    }

    func applyProviderDefaults() {
        switch configuration.provider {
        case .aliyun:
            if configuration.region.isEmpty { configuration.region = "cn-hangzhou" }
            configuration.endpoint = "oss-\(configuration.region).aliyuncs.com"
        case .tencent:
            if configuration.region.isEmpty { configuration.region = "ap-guangzhou" }
            configuration.endpoint = "cos.\(configuration.region).myqcloud.com"
        case .qiniu:
            if configuration.region.isEmpty { configuration.region = "z0" }
            if configuration.endpoint.isEmpty || configuration.endpoint.contains("aliyuncs") || configuration.endpoint.contains("myqcloud") {
                configuration.endpoint = "https://upload.qiniup.com"
            }
        }
    }

    func setRegion(_ region: String) {
        configuration.region = region
        applyProviderDefaults()
    }

    func saveConfiguration() {
        save()
        saveMessage = "配置已保存"
    }

    func clearCurrentProviderConfiguration() {
        let provider = configuration.provider
        configuration = AppConfiguration(provider: provider)

        switch provider {
        case .aliyun:
            configuration.region = "cn-hangzhou"
        case .tencent:
            configuration.region = "ap-beijing"
        case .qiniu:
            configuration.region = "z0"
        }
        applyProviderDefaults()

        keychain.delete("\(provider.rawValue).accessKey")
        keychain.delete("\(provider.rawValue).secretKey")
        UserDefaults.standard.removeObject(forKey: defaultsKey(for: provider))
        UserDefaults.standard.set(false, forKey: savedMarkerKey(for: provider))
        saveMessage = "配置已清空"
    }

    func refreshCredentialsForCurrentProvider() {
        loadCredentials(for: configuration.provider)
    }

    private func save() {
        let persisted = PersistedConfiguration(from: configuration)
        if let data = try? JSONEncoder().encode(persisted) {
            UserDefaults.standard.set(data, forKey: defaultsKey(for: configuration.provider))
        }
        UserDefaults.standard.set(true, forKey: savedMarkerKey(for: configuration.provider))
        UserDefaults.standard.set(configuration.provider.rawValue, forKey: selectedProviderKey)
        saveCredentials(for: configuration.provider, accessKey: configuration.accessKey, secretKey: configuration.secretKey)
    }

    private func selectedProvider() -> CloudProvider {
        if let rawValue = UserDefaults.standard.string(forKey: selectedProviderKey),
           let provider = CloudProvider(rawValue: rawValue) {
            return provider
        }

        if UserDefaults.standard.bool(forKey: legacySavedMarkerKey),
           let data = UserDefaults.standard.data(forKey: legacyDefaultsKey),
           let persisted = try? JSONDecoder().decode(PersistedConfiguration.self, from: data) {
            return persisted.provider
        }

        return .aliyun
    }

    private func storedConfiguration(for provider: CloudProvider) -> AppConfiguration? {
        guard UserDefaults.standard.bool(forKey: savedMarkerKey(for: provider)),
              let data = UserDefaults.standard.data(forKey: defaultsKey(for: provider)),
              let persisted = try? JSONDecoder().decode(PersistedConfiguration.self, from: data) else {
            return nil
        }

        var config = persisted.configuration
        config.provider = provider
        return config
    }

    private func defaultConfiguration(for provider: CloudProvider) -> AppConfiguration {
        var config = AppConfiguration(provider: provider)
        switch provider {
        case .aliyun:
            config.region = "cn-hangzhou"
            config.endpoint = "oss-cn-hangzhou.aliyuncs.com"
        case .tencent:
            config.region = "ap-beijing"
            config.endpoint = "cos.ap-beijing.myqcloud.com"
        case .qiniu:
            config.region = "z0"
            config.endpoint = "https://upload.qiniup.com"
        }
        return config
    }

    private func migrateLegacyConfigurationIfNeeded() {
        guard UserDefaults.standard.bool(forKey: legacySavedMarkerKey),
              let data = UserDefaults.standard.data(forKey: legacyDefaultsKey),
              let persisted = try? JSONDecoder().decode(PersistedConfiguration.self, from: data),
              !UserDefaults.standard.bool(forKey: savedMarkerKey(for: persisted.provider)) else {
            return
        }

        UserDefaults.standard.set(data, forKey: defaultsKey(for: persisted.provider))
        UserDefaults.standard.set(true, forKey: savedMarkerKey(for: persisted.provider))
        UserDefaults.standard.set(persisted.provider.rawValue, forKey: selectedProviderKey)
    }

    private func defaultsKey(for provider: CloudProvider) -> String {
        "imageHoster.configuration.\(provider.rawValue).v2"
    }

    private func savedMarkerKey(for provider: CloudProvider) -> String {
        "imageHoster.configuration.\(provider.rawValue).explicitlySaved.v2"
    }

    private func loadCredentials(for provider: CloudProvider) {
        configuration.accessKey = keychain.read("\(provider.rawValue).accessKey") ?? ""
        configuration.secretKey = keychain.read("\(provider.rawValue).secretKey") ?? ""
    }

    private func saveCredentials(for provider: CloudProvider, accessKey: String, secretKey: String) {
        keychain.write(accessKey, account: "\(provider.rawValue).accessKey")
        keychain.write(secretKey, account: "\(provider.rawValue).secretKey")
    }
}
