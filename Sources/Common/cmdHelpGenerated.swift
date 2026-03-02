// Command help text is intentionally checked in as source.
// It is maintained manually while docs generation is disabled.

let add_column_help_generated = """
    USAGE: add-column [-h|--help]
    """
let balance_sizes_help_generated = """
    USAGE: balance-sizes [-h|--help] [--workspace <workspace>]
    """
let check_config_help_generated = """
    USAGE: check-config [-h|--help]
    """
let focus_monitor_help_generated = """
    USAGE: focus-monitor [-h|--help] [--wrap-around] (left|down|up|right)
       OR: focus-monitor [-h|--help] [--wrap-around] (next|prev)
       OR: focus-monitor [-h|--help] <monitor-pattern>...
    """
let focus_help_generated = """
    USAGE: focus [-h|--help] [--wrap-around]
                 [--boundaries <boundary>] [--boundaries-action <action>]
                 (left|down|up|right)
       OR: focus [-h|--help] --window-id <window-id>
    """
let fullscreen_help_generated = """
    USAGE: fullscreen [-h|--help]     [--window-id <window-id>] [--no-outer-gaps]
       OR: fullscreen [-h|--help] on  [--window-id <window-id>] [--no-outer-gaps] [--fail-if-noop]
       OR: fullscreen [-h|--help] off [--window-id <window-id>] [--fail-if-noop]
    """
let layout_help_generated = """
    USAGE: layout [-h|--help] [--window-id <window-id>] (tiling|floating)...
    """
let list_apps_help_generated = """
    USAGE: list-apps [-h|--help] [--macos-native-hidden [no]] [--count] [--json]
    """
let list_monitors_help_generated = """
    USAGE: list-monitors [-h|--help] [--focused [no]] [--mouse [no]] [--count] [--json]
    """
let list_windows_help_generated = """
    USAGE: list-windows [-h|--help] (--workspace <workspace>...|--monitor <monitor>...)
                        [--monitor <monitor>...] [--workspace <workspace>...]
                        [--pid <pid>] [--app-bundle-id <app-bundle-id>]
                        [--count] [--json]
       OR: list-windows [-h|--help] --focused [--count] [--json]
    """
let list_workspaces_help_generated = """
    USAGE: list-workspaces [-h|--help] --monitor <monitor>... [--visible [no]] [--empty [no]] [--count] [--json]
    """
let move_mouse_help_generated = """
    USAGE: move-mouse [-h|--help] [--fail-if-noop] <mouse-position>
    """
let move_node_to_workspace_help_generated = """
    USAGE: move-node-to-workspace [-h|--help] [--focus-follows-window] [--wrap-around]
                                  [--stdin|--no-stdin]
                                  (next|prev)
       OR: move-node-to-workspace [-h|--help] [--focus-follows-window] [--fail-if-noop]
                                  [--window-id <window-id>] <workspace-name>
    """
let move_help_generated = """
    USAGE: move [-h|--help] [--window-id <window-id>] (left|down|up|right)
    """
let reload_config_help_generated = """
    USAGE: reload-config [-h|--help] [--no-gui] [--dry-run]
    """
let remove_column_help_generated = """
    USAGE: remove-column [-h|--help]
    """
let resize_help_generated = """
    USAGE: resize [-h|--help] [--window-id <window-id>] (smart|smart-opposite|width|height) [+|-]<number>
    """
let workspace_help_generated = """
    USAGE: workspace [-h|--help] [--fail-if-noop] <workspace-name>
       OR: workspace [-h|--help] [--wrap-around] [--stdin|--no-stdin] (next|prev)
    """
