import AppKit
import Common
import SwiftUI

@MainActor
public func getMessageWindow(messageModel: MessageModel) -> some Scene {
    // Using SwiftUI.Window because another class in Frame is already called Window
    SwiftUI.Window(messageModel.message?.title ?? appDisplayName, id: messageWindowId) {
        MessageView(model: messageModel)
            .onAppear {
                // Set activation policy; otherwise, Frame windows won't be able to receive focus and accept keyboard input
                NSApp.setActivationPolicy(.accessory)
                NSApplication.shared.windows.forEach {
                    if $0.identifier?.rawValue == messageWindowId {
                        $0.level = .floating
                        $0.styleMask.remove(.miniaturizable) // Disable minimize button, because we don't unminimize the window on config error
                    }
                }
            }
    }
    .windowResizability(.contentMinSize)
}

public let messageWindowId = "\(appDisplayName).messageView"

public struct MessageView: View {
    @StateObject private var model: MessageModel
    @Environment(\.dismiss) private var dismiss: DismissAction
    @FocusState var focus: Bool

    public init(model: MessageModel) {
        self._model = .init(wrappedValue: model)
    }

    public var body: some View {
        VStack(alignment: .leading) {
            HStack(alignment: .top, spacing: 12) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(model.message?.description ?? "")")
                    if let steps = model.message?.steps, !steps.isEmpty {
                        Text("Steps to follow:")
                            .font(.headline)
                        ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                            Text("\(index + 1). \(step)")
                        }
                    }
                }
                .font(.callout)
                .frame(maxWidth: .infinity, alignment: .leading)
                .focusable()
            }
            .padding()
            Text("Config errors:")
                .font(.headline)
                .padding(.horizontal)
            ScrollView {
                VStack(alignment: .leading) {
                    HStack {
                        let cancelOnEnterBinding: Binding<String> = Binding(
                            get: { model.message?.body ?? "" },
                            set: { newText in
                                if let prev = model.message?.body.count(where: \.isNewline), newText.count(where: \.isNewline) > prev {
                                    model.message = nil
                                }
                            },
                        )
                        TextEditor(text: cancelOnEnterBinding)
                            .font(.system(size: 12).monospaced())
                            .focused($focus)
                        Spacer()
                    }
                    Spacer()
                }
                .padding()
            }
            .background(Color(.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .padding(.horizontal)
            HStack {
                Spacer()
                Button("Close") { model.message = nil }
                    .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .textSelection(.enabled)
        .frame(minWidth: 520, idealWidth: 620, maxWidth: 760, minHeight: 200)
        .onChange(of: model.message) { message in
            if message == nil {
                self.dismiss()
            }
        }
        .onDisappear {
            // If user closes the screen with the macOS native close (x) button and then the error is still the same, this window will not appear again
            model.message = nil
        }
        .onAppear {
            focus = true
        }
    }
}

public final class MessageModel: ObservableObject {
    @MainActor public static let shared = MessageModel()
    @Published public var message: Message? = nil

    private init() {}
}

public struct Message: Hashable, Equatable {
    public let title: String
    public let description: String
    public let body: String
    public let steps: [String]

    package init(title: String = appDisplayName, description: String, body: String, steps: [String] = []) {
        self.title = title
        self.description = description
        self.body = body
        self.steps = steps
    }
}
