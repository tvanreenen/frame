@testable import FrameEngine
@testable import FrameMacOS
@testable import FrameUI
import Common
import Foundation
import TOMLKit

extension [TomlParseError] {
    var descriptions: [String] { map(\.description) }
}
