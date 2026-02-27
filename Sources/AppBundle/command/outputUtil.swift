import Common
import Foundation

func outputJson<T: Encodable>(_ value: T, _ io: CmdIo) -> Bool {
    guard let json = JSONEncoder.aeroSpaceDefault.encodeToString(value) else {
        return io.err("Can't encode output to JSON")
    }
    return io.out(json)
}
