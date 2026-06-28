#!/bin/bash
# Shared helper: open a Ghostty tab running the given command
CMD="$1"
[ -z "$CMD" ] && exit 1
osascript <<APPLESCRIPT_EOF
tell application "Ghostty"
    if not (running) then
        activate
        delay 0.3
    end if
    set cfg to new surface configuration
    set initial working directory of cfg to POSIX path of (path to home folder)
    set command of cfg to "$CMD"
    set win to window 1
    set newTab to new tab in win with configuration cfg
end tell
APPLESCRIPT_EOF
