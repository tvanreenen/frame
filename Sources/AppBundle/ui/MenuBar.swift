import Common
import Foundation
import SwiftUI

@MainActor
public func menuBar(viewModel: TrayMenuModel) -> some Scene {
    MenuBarExtra {
        menuMetadataBlock()
        Divider()
        Button("Quit \(appDisplayName)") {
            Task {
                defer { terminateApp() }
                try await terminationHandler.beforeTermination()
            }
        }
    } label: {
        Text(viewModel.trayText.isEmpty ? "F" : viewModel.trayText)
    }
}

@MainActor @ViewBuilder
private func menuMetadataBlock() -> some View {
    VStack(alignment: .leading, spacing: 4) {
        Text("GitHub: \(repositoryUrl)")
        Text("Version: \(appVersionForDisplay)")
        Text("Config: \(runtimeContext.configUrl.path)")
            .lineLimit(1)
            .truncationMode(.middle)
    }
    .font(.caption)
}

func shortcutGroup(label: some View, content: some View) -> some View {
    GroupBox {
        VStack(alignment: .trailing, spacing: 6) {
            label
                .foregroundStyle(Color.secondary)
            content
        }
    }
}
