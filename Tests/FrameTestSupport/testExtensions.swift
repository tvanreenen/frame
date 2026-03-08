import FrameEngine
import FrameMacOS
import FrameUI
import Common
import Foundation
import TOMLKit

package extension [TomlParseError] {
    var descriptions: [String] { map(\.description) }
}
