import Common
import Foundation
import SwiftUI

public struct MenuBarMetadata {
    public let repositoryUrl: String
    public let version: String
    public let configPath: String

    public init(repositoryUrl: String, version: String, configPath: String) {
        self.repositoryUrl = repositoryUrl
        self.version = version
        self.configPath = configPath
    }
}

@MainActor
public func menuBar(
    viewModel: TrayMenuModel,
    metadata: MenuBarMetadata,
    onQuit: @escaping @MainActor () async throws -> ()
) -> some Scene {
    MenuBarExtra {
        menuMetadataBlock(metadata: metadata)
        Divider()
        Button("Quit \(appDisplayName)") {
            Task {
                try await onQuit()
            }
        }
    } label: {
        Text(viewModel.trayText.isEmpty ? "F" : viewModel.trayText)
    }
}

@MainActor @ViewBuilder
private func menuMetadataBlock(metadata: MenuBarMetadata) -> some View {
    VStack(alignment: .leading, spacing: 4) {
        Text("GitHub: \(metadata.repositoryUrl)")
        Text("Version: \(metadata.version)")
        Text("Config: \(metadata.configPath)")
            .lineLimit(1)
            .truncationMode(.middle)
    }
    .font(.caption)
}
