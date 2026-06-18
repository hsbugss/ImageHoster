import AppKit
import Foundation

@MainActor
final class UploadViewModel: ObservableObject {
    @Published var status: UploadStatus = .idle
    @Published var history: [UploadedImage] = []
    @Published var isDropTargeted = false

    private let service = UploadService()

    func upload(urls: [URL], using config: AppConfiguration) async {
        let files = urls.filter { !$0.hasDirectoryPath }
        guard !files.isEmpty else { return }

        for file in files {
            status = .uploading(file.lastPathComponent)
            do {
                let image = try await service.upload(file: file, config: config)
                history.insert(image, at: 0)
                copyToPasteboard(image, markdown: config.copyMarkdown)
                status = .success(image.url)
            } catch {
                status = .failure(error.localizedDescription)
                break
            }
        }
    }

    func copyToPasteboard(_ image: UploadedImage, markdown: Bool) {
        copyToPasteboard(markdown ? image.markdownURL : image.url)
    }

    func copyToPasteboard(_ value: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(value, forType: .string)
    }

}
