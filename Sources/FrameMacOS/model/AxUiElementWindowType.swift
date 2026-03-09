package enum AxUiElementWindowType: String {
    case window
    case dialog
    case popup

    package static func new(isWindow: Bool, isDialog: () -> Bool) -> AxUiElementWindowType {
        switch true {
            case !isWindow: .popup
            case isDialog(): .dialog
            default: .window
        }
    }
}
