import FrameEngine
import FrameMacOS
import FrameUI
import Common
import Foundation
import TOMLKit

extension [TomlParseError] {
    package var descriptions: [String] { map(\.description) }
}
