-- ╔═══════════════════════════════════════════════════════════════════════╗
-- ║  Hyprland configuration — Lua (hyprlang → lua migration, 0.55+)         ║
-- ║                                                                         ║
-- ║  Converted from the modular *.conf files (kept alongside as backup).    ║
-- ║  Hyprland loads hyprland.lua in preference to hyprland.conf, so this    ║
-- ║  file is authoritative once present. Delete it to fall back to .conf.   ║
-- ║                                                                         ║
-- ║  NOTE: monitors are declarative (see MONITORS below) — Hyprland          ║
-- ║  auto-applies each rule on hotplug, so no daemon (kanshi/socket2         ║
-- ║  listener). The laptop panel is toggled by the LID SWITCH binds.         ║
-- ║  hyprlock.conf stays hyprlang — separate program, unaffected.           ║
-- ╚═══════════════════════════════════════════════════════════════════════╝

----------------------------------------------------------------------
-- VARIABLES / PROGRAMS
----------------------------------------------------------------------

local home    = os.getenv("HOME")
local srcPath = home .. "/.local/share/bin"   -- scripts path ($srcPath)

local term    = "kitty"
local fileMgr = "nautilus"
local browser = "google-chrome-stable"
local mainMod = "SUPER"

----------------------------------------------------------------------
-- MONITORS  (declarative — Hyprland auto-applies each rule on hotplug)
----------------------------------------------------------------------
-- No daemon (was kanshi, then a socket2 listener — both removed). Hyprland
-- re-applies these rules every time a matching output connects, so docking the
-- two home Dells "just works". The laptop panel (eDP-1) is toggled on/off by
-- the LID SWITCH binds further down (clamshell docking), because a closing lid
-- does NOT disconnect eDP at the DRM level and so never triggers a hotplug.
--
-- Dell U2518D units report no EDID preferred mode -> pin 2560x1440@59.95 or they
-- fall back to 1280x720. transform=1 == 90° (left panel is portrait).
-- Order matters: Hyprland applies the LAST matching rule, so the catch-all
-- (output="") must come FIRST and the specific rules AFTER it.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })  -- fallback for any other output
hl.monitor({ output = "eDP-1", mode = "preferred", position = "auto", scale = 1.333 })
hl.monitor({ output = "desc:Dell Inc. DELL U2518D 3C4YP898AHPL", mode = "2560x1440@59.95", position = "0x0",    transform = 1, scale = 1 })
hl.monitor({ output = "desc:Dell Inc. DELL U2518D 3C4YP8A4AGBL", mode = "2560x1440@59.95", position = "1440x560",              scale = 1 })

----------------------------------------------------------------------
-- ENVIRONMENT VARIABLES
----------------------------------------------------------------------

hl.env("PATH", (os.getenv("PATH") or "") .. ":" .. srcPath)
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")
hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("GDK_SCALE", "1.333")

----------------------------------------------------------------------
-- AUTOSTART  (exec-once)
----------------------------------------------------------------------

hl.on("hyprland.start", function()
    -- systemd / D-Bus session bootstrap -- this is what makes screen sharing work.
    -- Chained in ONE shell so ordering is guaranteed: the environment must be
    -- imported BEFORE graphical-session.target activates, or
    -- xdg-desktop-portal-hyprland fails its ConditionEnvironment=WAYLAND_DISPLAY.
    --
    -- nixos-fake-graphical-session.target is NixOS's sanctioned hook for a session
    -- that isn't systemd-aware (Hyprland exec'd bare, no display manager / uwsm).
    -- It BindsTo graphical-session.target, so starting it activates that target.
    -- Needed since xdg-desktop-portal 1.22, which added
    -- "Requisite=graphical-session.target" to its unit: with the target inactive,
    -- D-Bus activation of the portal fails instantly and Chrome (Google Meet)
    -- shows no screens to share.
    --
    -- resetxdgportal.sh used to run here and was removed: its killall/relaunch
    -- probed /run/current-system/sw/libexec (absent) then fell back to /usr/lib
    -- (also absent on NixOS), so it only ever KILLED the portals. systemd quietly
    -- re-activated them on demand until 1.22 made that fail.
    hl.exec_cmd("sh -c 'dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP; dbus-update-activation-environment --systemd --all; systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP; systemctl --user start nixos-fake-graphical-session.target'")
    hl.exec_cmd(srcPath .. "/polkitkdeauth.sh")                                          -- auth dialogue for GUI apps
    hl.exec_cmd("waybar")
    hl.exec_cmd("vicinae server")
    hl.exec_cmd("obsidian")
    hl.exec_cmd("slack")
    hl.exec_cmd("blueman-applet")
    hl.exec_cmd("udiskie --no-automount --smart-tray")
    hl.exec_cmd("nm-applet --indicator")
    hl.exec_cmd("dunst")
    hl.exec_cmd("wl-paste --type text --watch cliphist store")                           -- clipboard: text
    hl.exec_cmd("wl-paste --type image --watch cliphist store")                          -- clipboard: image
    hl.exec_cmd(srcPath .. "/wallpaper.sh")                                              -- wallpaper daemon
    hl.exec_cmd(srcPath .. "/batterynotify.sh")                                          -- battery notifications
    hl.exec_cmd("wayscriber --daemon")                                                   -- screen annotation daemon (Super+D toggles it)
    hl.exec_cmd("handy")                                                                 -- speech-to-text; runs in bg, F5 toggles recording
end)

----------------------------------------------------------------------
-- LOOK & FEEL  (gsettings run on every (re)load — was `exec =`)
----------------------------------------------------------------------

hl.exec_cmd("gsettings set org.gnome.desktop.interface icon-theme 'Tela-circle-dracula'")
hl.exec_cmd("gsettings set org.gnome.desktop.interface gtk-theme 'Catppuccin-Mocha'")
hl.exec_cmd("gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'")

----------------------------------------------------------------------
-- CONFIG  (general / input / decoration / misc / layouts …)
----------------------------------------------------------------------

local accent   = { colors = { "rgba(ca9ee6ff)", "rgba(f2d5cfff)" }, angle = 45 }
local inactive = { colors = { "rgba(b4befecc)", "rgba(6c7086cc)" }, angle = 45 }

hl.config({
    general = {
        gaps_in   = 3,
        gaps_out  = 8,
        border_size = 2,
        layout    = "dwindle",
        resize_on_border = true,
        col = {
            active_border   = accent,
            inactive_border = inactive,
        },
    },

    group = {
        col = {
            border_active          = accent,
            border_inactive        = inactive,
            border_locked_active   = accent,
            border_locked_inactive = inactive,
        },
    },

    decoration = {
        rounding    = 10,
        dim_special = 0.3,                    -- from themes/common.conf
        blur = {
            enabled           = true,
            size              = 6,
            passes            = 3,
            new_optimizations = true,
            ignore_opacity    = true,
            xray              = false,
            special           = true,         -- from themes/common.conf
        },
    },

    input = {
        kb_layout    = "us,ch",
        kb_options   = "caps:super,altwin:ctrl_alt_win,grp:shifts_toggle",
        follow_mouse = 1,
        sensitivity  = 0.3,
        force_no_accel = false,
        repeat_delay = 250,
        touchpad = { natural_scroll = true },
    },

    dwindle = { preserve_split = true },

    misc = {
        vrr = 0,
        disable_hyprland_logo    = true,
        disable_splash_rendering = true,
        force_default_wallpaper  = 0,
        middle_click_paste       = true,
    },

    xwayland = { force_zero_scaling = true },

    -- Animations were disabled in the old animations.conf (a second
    -- `animations { enabled = 0 }` block overrode the first). The original
    -- bezier/animation defs live in git history (animations.conf, removed) if
    -- you want to re-enable and port them.
    animations = { enabled = false },
})

-- Per-device tweak (was: device { name = epic mouse V1; sensitivity = -0.5 })
hl.device({ name = "epic mouse V1", sensitivity = -0.5 })

-- Vicinae pastes (emoji, snippets) through a virtual keyboard. Clear the global
-- kb_options remap (caps:super, ctrl<->alt swap) on it so vicinae's synthetic
-- Ctrl+V arrives clean instead of being mangled into a stray combo that broke
-- emoji paste and misfired into the rofi/cliphist keybinds.
hl.device({ name = "vicinae-snippet-virtual-keyboard", kb_options = "" })

-- Touchpad gesture (was: gestures { gesture = 3, horizontal, workspace })
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

----------------------------------------------------------------------
-- KEYBINDINGS
----------------------------------------------------------------------

-- Reload
hl.bind(mainMod .. " + SHIFT + R", hl.dsp.exec_cmd("hyprctl reload"))

-- Window / session actions
hl.bind(mainMod .. " + Q",            hl.dsp.window.close())
hl.bind(mainMod .. " + Delete",       hl.dsp.exit())
hl.bind(mainMod .. " + CTRL + Space", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + G",            hl.dsp.group.toggle())
hl.bind(mainMod .. " + F",            hl.dsp.window.fullscreen({ mode = "fullscreen" }))
hl.bind(mainMod .. " + Escape",       hl.dsp.exec_cmd("hyprlock"))
hl.bind(mainMod .. " + Backspace",    hl.dsp.exec_cmd(srcPath .. "/logoutlaunch.sh"))
hl.bind("CTRL + ALT + W",             hl.dsp.exec_cmd("killall waybar || waybar"))

-- Application shortcuts
hl.bind(mainMod .. " + Return",         hl.dsp.exec_cmd(term))
hl.bind(mainMod .. " + SHIFT + Return", hl.dsp.exec_cmd(srcPath .. "/browser-launcher.sh"))
hl.bind(mainMod .. " + E",              hl.dsp.exec_cmd(fileMgr))
hl.bind("CTRL + SHIFT + Escape",        hl.dsp.exec_cmd(srcPath .. "/sysmonlaunch.sh",
                                            { float = true, size = { 800, 500 }, center = true }))

-- Launchers / menus
hl.bind(mainMod .. " + Space",     hl.dsp.exec_cmd("vicinae toggle"))
hl.bind(mainMod .. " + Tab",       hl.dsp.exec_cmd("pkill -x rofi || " .. srcPath .. "/rofi-launcher.sh w"))
hl.bind(mainMod .. " + SHIFT + E", hl.dsp.exec_cmd("pkill -x rofi || " .. srcPath .. "/rofi-launcher.sh f"))

-- Audio control (locked = works on lockscreen; repeating = autorepeat while held)
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd(srcPath .. "/volumecontrol.sh -o m"), { locked = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd(srcPath .. "/volumecontrol.sh -i m"), { locked = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd(srcPath .. "/volumecontrol.sh -o d"), { locked = true, repeating = true })
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd(srcPath .. "/volumecontrol.sh -o i"), { locked = true, repeating = true })

-- Media control
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })

-- Brightness control
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd(srcPath .. "/brightnesscontrol.sh i"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(srcPath .. "/brightnesscontrol.sh d"), { locked = true, repeating = true })

-- Screenshot / screencapture  (ported from Omarchy 4)
-- Everything lives on Print, the way Omarchy lays it out. The old three-mode
-- split (Super+X region / Super+ALT+P monitor / Print all) is gone: capture-
-- region.sh's "smart" mode does all of it from one key — drag for a freeform
-- region, single-click to snap to the window or monitor under the cursor.
-- Shots auto-save to ~/obsidian/Files AND land on the clipboard, with a
-- clickable notification that opens swappy. Super+X is now universal cut.
hl.bind("Print",                    hl.dsp.exec_cmd(srcPath .. "/capture-screenshot.sh"))
hl.bind("ALT + Print",              hl.dsp.exec_cmd(srcPath .. "/capture-screenrecording.sh --stop-recording || " .. srcPath .. "/capture-screenrecording.sh"))
hl.bind(mainMod .. " + Print",      hl.dsp.exec_cmd("pkill hyprpicker || hyprpicker -a"))
hl.bind(mainMod .. " + CTRL + Print", hl.dsp.exec_cmd(srcPath .. "/capture-text.sh"))
hl.bind(mainMod .. " + SHIFT + Print", hl.dsp.exec_cmd(srcPath .. "/capture-qr.sh"))

-- Keyboard control for the slurp region picker (see capture-region.sh).
-- The binds live exactly as long as a selection layer is on screen (slurp opens
-- one per monitor), so they cannot leak or get stuck. Unbinding by key would
-- take a same-key binding out of the rest of this config with it, so each
-- handle is kept and removed individually.
local selectionLayers = 0
local selectionBinds  = {}

hl.on("layer.opened", function(layer)
    if layer.namespace ~= "selection" then return end
    selectionLayers = selectionLayers + 1
    if selectionLayers ~= 1 then return end

    selectionBinds = {
        hl.bind("RETURN",        hl.dsp.exec_cmd(srcPath .. "/capture-region.sh --take-window"),          { description = "Capture highlighted window" }),
        hl.bind("CTRL + RETURN", hl.dsp.exec_cmd(srcPath .. "/capture-region.sh --take-fullscreen"),      { description = "Capture entire screen" }),
        hl.bind("TAB",           hl.dsp.exec_cmd(srcPath .. "/capture-region.sh --select-window next"),   { description = "Select next window to capture" }),
        hl.bind("CTRL + TAB",    hl.dsp.exec_cmd(srcPath .. "/capture-region.sh --select-window prev"),   { description = "Select previous window to capture" }),
    }
    for _, direction in ipairs({ "left", "right", "up", "down" }) do
        table.insert(
            selectionBinds,
            hl.bind(direction:upper(), hl.dsp.exec_cmd(srcPath .. "/capture-region.sh --select-window " .. direction), { description = "Select window to capture" })
        )
    end
end)

hl.on("layer.closed", function(layer)
    if layer.namespace ~= "selection" or selectionLayers <= 0 then return end
    selectionLayers = selectionLayers - 1
    if selectionLayers ~= 0 then return end

    for _, keybind in ipairs(selectionBinds) do
        keybind:unbind()
    end
    selectionBinds = {}
end)

-- Monitor control
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd(home .. "/.config/hypr/bin/monitor-laptop-only.sh"))

-- Laptop lid (clamshell docking). switch:on = lid CLOSED, switch:off = lid OPEN
-- (verified against Hyprland source). These touch ONLY eDP-1 — the Dells are
-- handled by the declarative monitor rules on hotplug. `locked` is required so
-- the binds fire while the session is locked. logind must not suspend on lid
-- close while docked (services.logind.settings.Login.HandleLidSwitchDocked =
-- "ignore" in configuration.nix; also the systemd default).
--
-- lid-close.sh disables eDP-1 ONLY when an external monitor is present (docked).
-- Undocked, it does nothing so logind suspends cleanly — disabling the sole
-- monitor left Hyprland headless and it often couldn't re-light eDP-1 on
-- lid-open (needed a power cycle). lid-open.sh re-enables eDP-1 with verify+retry.
hl.bind("switch:on:Lid Switch",  hl.dsp.exec_cmd(home .. "/.config/hypr/bin/lid-close.sh"), { locked = true })
hl.bind("switch:off:Lid Switch", hl.dsp.exec_cmd(home .. "/.config/hypr/bin/lid-open.sh"),  { locked = true })

-- Speech-to-text dictation — right cmd key.
-- NOTE: the altwin:ctrl_alt_win remap (see input.kb_options) rotates modifiers,
-- so the physical right cmd emits Control_R at evdev keycode 100 (Hyprland
-- code:108), NOT Super_R. Bind by keycode to stay immune to the keysym remap;
-- consuming it also suppresses the stray Control_R.
hl.bind("code:108", hl.dsp.exec_cmd(srcPath .. "/dictation.sh"))

-- Handy — offline push-to-talk speech-to-text (github.com/cjpais/Handy).
-- A separate STT engine from VoiceFlow above; Handy autostarts (exec-once) and
-- this toggles recording into the focused field. Wayland has no global-hotkey
-- API, so the compositor owns the key.
hl.bind("F5", hl.dsp.exec_cmd("handy --toggle-transcription"))

-- Screen annotation (wayscriber overlay toggle)
hl.bind(mainMod .. " + D", hl.dsp.exec_cmd("wayscriber --daemon-toggle"))

----------------------------------------------------------------------
-- UNIVERSAL COPY / PASTE  (ported from Omarchy 4 bindings/clipboard.lua)
----------------------------------------------------------------------
-- Super+C/V/X copy/paste/cut in EVERY app, so the terminal stops being the odd
-- one out. Terminals get Ctrl+Insert / Shift+Insert instead, because Ctrl+C
-- there is SIGINT.
--
-- Sent with explicit mods to the FOCUSED SURFACE by omitting the window target,
-- so the chord also reaches layer-shell surfaces (rofi, vicinae). A virtual
-- keyboard (wtype) won't do: the physically-held SUPER merges into the injected
-- chord at the seat. The down/up split works around Hyprland send_shortcut
-- sometimes leaving synthetic key state stuck/repeating.
-- https://github.com/hyprwm/Hyprland/discussions/14099
local function sendShortcutOnce(mods, key)
    return function()
        hl.dispatch(hl.dsp.send_key_state({ mods = mods, key = key, state = "down" }))
        hl.timer(function()
            hl.dispatch(hl.dsp.send_key_state({ mods = mods, key = key, state = "up" }))
        end, { timeout = 50, type = "oneshot" })
    end
end

-- Omarchy keys this off its window tags; this config has none, so match on the
-- class instead. "cliamp" is listed because it is a kitty window flying under
-- its own class (see the Super+A submap, Z).
local terminalClasses = { "kitty", "ghostty", "foot", "alacritty", "wezterm", "xterm", "cliamp" }

local function activeWindowIsTerminal()
    local ok, window = pcall(hl.get_active_window)
    if not ok or not window then return false end

    local okClass, class = pcall(function() return window.class end)
    if not okClass or type(class) ~= "string" then return false end

    class = class:lower()
    for _, name in ipairs(terminalClasses) do
        if class:find(name, 1, true) then return true end
    end
    return false
end

local function universalClipboard(defaultMods, defaultKey, terminalMods, terminalKey)
    return function()
        if activeWindowIsTerminal() then
            sendShortcutOnce(terminalMods, terminalKey)()
        else
            sendShortcutOnce(defaultMods, defaultKey)()
        end
    end
end

-- Terminal chord is CTRL+SHIFT+C/V, NOT Omarchy's Ctrl+Insert / Shift+Insert.
-- Omarchy ships foot; kitty's defaults are different and both of upstream's
-- chords are wrong here:
--   * ctrl+insert  is bound to NOTHING in kitty, so kitty forwards it to the
--     running program as the xterm sequence CSI 2;5~ — which is where the
--     stray "5~" in the shell came from.
--   * shift+insert is paste_from_selection, i.e. the PRIMARY selection
--     (whatever was last mouse-highlighted), not the clipboard.
-- kitty_mod defaults to ctrl+shift, so ctrl+shift+c/v are its real
-- copy_to_clipboard / paste_from_clipboard binds — and the same pair is
-- correct for ghostty, foot, alacritty and wezterm.
hl.bind(mainMod .. " + C", universalClipboard("CTRL", "C", "CTRL SHIFT", "C"), { description = "Universal copy" })
hl.bind(mainMod .. " + V", universalClipboard("CTRL", "V", "CTRL SHIFT", "V"), { description = "Universal paste" })
hl.bind(mainMod .. " + X", sendShortcutOnce("CTRL", "X"),                      { description = "Universal cut" })

-- Custom scripts
-- cliphist moved off Super+V (now universal paste) to Super+Ctrl+V — the slot
-- Omarchy gives its own clipboard manager. The wl-paste --watch daemons in
-- AUTOSTART above still feed it, so history is unchanged.
hl.bind(mainMod .. " + CTRL + V",   hl.dsp.exec_cmd(srcPath .. "/cliphist-menu.sh c"))

-- (cliamp, the music TUI, lives in the Super+A submap on Z — see SUBMAPS.)

-- Move / change window focus
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))
hl.bind(mainMod .. " + H",     hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + L",     hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + K",     hl.dsp.focus({ direction = "up" }))
-- (Super+J is the dwindle split toggle, see SUBMAPS section below; use
--  Super+Down for focus-down.)
hl.bind("ALT + Tab",           hl.dsp.focus({ direction = "down" }))

-- Switch workspaces (custom toggle script) + move-window-silent, keys 1..0
for i = 1, 10 do
    local key = i % 10   -- 10 -> key 0
    hl.bind(mainMod .. " + " .. key,          hl.dsp.exec_cmd(srcPath .. "/toggle_workspace.sh " .. i))
    hl.bind(mainMod .. " + CTRL + " .. key,   hl.dsp.window.move({ workspace = i, follow = false }))
end

-- Move current workspace to another monitor
hl.bind(mainMod .. " + SHIFT + H",     hl.dsp.workspace.move({ monitor = "l" }))
hl.bind(mainMod .. " + SHIFT + L",     hl.dsp.workspace.move({ monitor = "r" }))
hl.bind(mainMod .. " + SHIFT + J",     hl.dsp.workspace.move({ monitor = "d" }))
hl.bind(mainMod .. " + SHIFT + K",     hl.dsp.workspace.move({ monitor = "u" }))
hl.bind(mainMod .. " + SHIFT + left",  hl.dsp.workspace.move({ monitor = "l" }))
hl.bind(mainMod .. " + SHIFT + right", hl.dsp.workspace.move({ monitor = "r" }))
hl.bind(mainMod .. " + SHIFT + down",  hl.dsp.workspace.move({ monitor = "d" }))
hl.bind(mainMod .. " + SHIFT + up",    hl.dsp.workspace.move({ monitor = "u" }))

-- Move focused window around the current workspace
hl.bind(mainMod .. " + CTRL + left",  hl.dsp.window.move({ direction = "l" }))
hl.bind(mainMod .. " + CTRL + right", hl.dsp.window.move({ direction = "r" }))
hl.bind(mainMod .. " + CTRL + up",    hl.dsp.window.move({ direction = "u" }))
hl.bind(mainMod .. " + CTRL + down",  hl.dsp.window.move({ direction = "d" }))
hl.bind(mainMod .. " + CTRL + H",     hl.dsp.window.move({ direction = "l" }))
hl.bind(mainMod .. " + CTRL + L",     hl.dsp.window.move({ direction = "r" }))
hl.bind(mainMod .. " + CTRL + K",     hl.dsp.window.move({ direction = "u" }))
hl.bind(mainMod .. " + CTRL + J",     hl.dsp.window.move({ direction = "d" }))

-- Move / resize window with the mouse (and Z/X keyboard equivalents)
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })
hl.bind(mainMod .. " + Z",         hl.dsp.window.drag(),   { mouse = true })

-- Special workspaces (scratchpads)
hl.bind(mainMod .. " + CTRL + F1", hl.dsp.window.move({ workspace = "special:slack",    follow = false }))
hl.bind(mainMod .. " + CTRL + F2", hl.dsp.window.move({ workspace = "special:obsidian", follow = false }))
hl.bind(mainMod .. " + CTRL + F3", hl.dsp.window.move({ workspace = "special",          follow = false }))
hl.bind("F1", hl.dsp.workspace.toggle_special("slack"))
hl.bind("F2", hl.dsp.workspace.toggle_special("obsidian"))
hl.bind("F3", hl.dsp.workspace.toggle_special())
hl.bind(mainMod .. " + CTRL + U", hl.dsp.window.move({ workspace = "special", follow = false }))
hl.bind(mainMod .. " + U",        hl.dsp.workspace.toggle_special())

-- Toggle focused window split (dwindle): rearrange the split the window sits
-- in, horizontal <-> vertical. Super+J is the primary key; Super+N kept as the
-- historical alias.
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"))
hl.bind(mainMod .. " + N", hl.dsp.layout("togglesplit"))

----------------------------------------------------------------------
-- SUBMAPS
----------------------------------------------------------------------

-- App / selector submap (Super+A) --------------------------------------------
-- One leader for "start a thing". Web apps run as Chrome --app windows via
-- webapp.sh, native apps via launch-or-focus.sh; both focus an existing window
-- instead of spawning a duplicate.
-- The Chrome profile is PINNED per entry (resolved by email out of Chrome's
-- Local State), deliberately unlike browser-launcher.sh which derives the
-- profile from the active workspace -- a work calendar must open the Roche
-- account from wherever it is pressed.
-- The vicinae system toggles that used to sit on W/A/B/M moved to SHIFT+key,
-- because W/M are now WhatsApp/Maps.
local privateAcct = "ikeark@gmail.com"                 -- Profile 3
local workAcct    = "andreas.schmid.as3@roche.com"     -- Profile 15 (Roche)

local function submapExec(command)
    return hl.dsp.exec_cmd([[hyprctl dispatch 'hl.dsp.submap("reset")' && ]] .. command)
end

local function webapp(account, url)
    return submapExec(string.format("%s/webapp.sh '%s' '%s'", srcPath, account, url))
end

local function app(match, command)
    return submapExec(string.format("%s/launch-or-focus.sh '%s' %s", srcPath, match, command))
end

local function vicinae(deeplink)
    return submapExec(string.format('vicinae deeplink "%s"', deeplink))
end

hl.bind(mainMod .. " + A", hl.dsp.submap("rofiselect"))
hl.define_submap("rofiselect", function()
    -- Web apps, private profile
    hl.bind("Y", webapp(privateAcct, "https://youtube.com/"))
    hl.bind("W", webapp(privateAcct, "https://web.whatsapp.com/"))
    hl.bind("T", webapp(privateAcct, "https://web.telegram.org/a/"))
    hl.bind("P", webapp(privateAcct, "https://photos.google.com/"))
    hl.bind("M", webapp(privateAcct, "https://maps.google.com/"))

    -- Web apps, work profile (Roche)
    hl.bind("C", webapp(workAcct, "https://calendar.google.com/"))
    hl.bind("G", webapp(workAcct, "https://mail.google.com/"))
    hl.bind("D", webapp(workAcct, "https://drive.google.com/"))

    -- Native apps
    hl.bind("S",     app("signal", "signal-desktop"))
    hl.bind("slash", app("1[Pp]assword", "1password"))

    -- TUI apps. cliamp is the Winamp 2.x-styled terminal music player Omarchy
    -- ships (cliamp.stream), with built-in lo-fi radio; "?" lists its keys. It
    -- runs as a kitty window under its OWN class so launch-or-focus.sh can find
    -- it again — that class is also in `terminalClasses` above, so universal
    -- copy/paste treats it as the terminal it is.
    hl.bind("Z",     app("cliamp", "kitty --class cliamp -e cliamp"))

    -- vicinae system toggles (moved to SHIFT, W/A/B/M are apps now)
    hl.bind("SHIFT + W", vicinae("vicinae://launch/@dagimg-dot/store.vicinae.wifi-commander/scan-wifi"))
    hl.bind("SHIFT + A", vicinae("vicinae://launch/@rastsislaux/store.vicinae.pulseaudio/pulseaudio"))
    hl.bind("SHIFT + B", vicinae("vicinae://launch/@Gelei/store.vicinae.bluetooth/scan"))
    hl.bind("SHIFT + M", vicinae("vicinae://launch/@kraeki/google-calendar/list-events"))

    hl.bind("escape", hl.dsp.submap("reset"))
end)

-- Resize submap (Super+R)
hl.bind(mainMod .. " + R", hl.dsp.submap("resize"))
hl.define_submap("resize", function()
    hl.bind("H",     hl.dsp.window.resize({ x = -30, y = 0,   relative = true }), { repeating = true })
    hl.bind("L",     hl.dsp.window.resize({ x = 30,  y = 0,   relative = true }), { repeating = true })
    hl.bind("K",     hl.dsp.window.resize({ x = 0,   y = -30, relative = true }), { repeating = true })
    hl.bind("J",     hl.dsp.window.resize({ x = 0,   y = 30,  relative = true }), { repeating = true })
    hl.bind("left",  hl.dsp.window.resize({ x = -30, y = 0,   relative = true }), { repeating = true })
    hl.bind("right", hl.dsp.window.resize({ x = 30,  y = 0,   relative = true }), { repeating = true })
    hl.bind("up",    hl.dsp.window.resize({ x = 0,   y = -30, relative = true }), { repeating = true })
    hl.bind("down",  hl.dsp.window.resize({ x = 0,   y = 30,  relative = true }), { repeating = true })
    hl.bind("escape", hl.dsp.submap("reset"))
end)

----------------------------------------------------------------------
-- WORKSPACE RULES
----------------------------------------------------------------------

hl.workspace_rule({ workspace = "special:slack",    no_rounding = true, border_size = 0 })
hl.workspace_rule({ workspace = "special:obsidian", no_rounding = true, border_size = 0 })

----------------------------------------------------------------------
-- WINDOW RULES
----------------------------------------------------------------------

-- Scratchpad placement
hl.window_rule({ name = "windowrule-1", match = { class = "^([Ss]lack)$" },    workspace = "special:slack" })
hl.window_rule({ name = "windowrule-2", match = { class = "^(obsidian)$" }, workspace = "special:obsidian" })

-- Google Meet always on workspace 2
hl.window_rule({ name = "meets-on-workspace2", match = { class = "^(google-chrome)$", title = "^(Meet - .*)$" }, workspace = "2" })

-- Opacity (and float) rules
hl.window_rule({ name = "windowrule-3",  match = { class = "^(kitty)$" },          opacity = "0.80 0.80" })
hl.window_rule({ name = "windowrule-4",  match = { class = "^(org.kde.dolphin)$" }, opacity = "0.80 0.80" })
hl.window_rule({ name = "windowrule-5",  match = { class = "^(org.kde.ark)$" },     opacity = "0.80 0.80", float = true })
hl.window_rule({ name = "windowrule-6",  match = { class = "^(nwg-look)$" },        opacity = "0.80 0.80", float = true })
hl.window_rule({ name = "windowrule-7",  match = { class = "^(qt5ct)$" },           opacity = "0.80 0.80", float = true })
hl.window_rule({ name = "windowrule-8",  match = { class = "^(qt6ct)$" },           opacity = "0.80 0.80", float = true })
hl.window_rule({ name = "windowrule-9",  match = { class = "^(kvantummanager)$" },  opacity = "0.80 0.80", float = true })
hl.window_rule({ name = "windowrule-10", match = { class = "^(pavucontrol)$" },     opacity = "0.80 0.70", float = true })
hl.window_rule({ name = "windowrule-11", match = { class = "^(blueman-manager)$" }, opacity = "0.80 0.70", float = true })
hl.window_rule({ name = "windowrule-12", match = { class = "^(nm-applet)$" },       opacity = "0.80 0.70", float = true })
hl.window_rule({ name = "windowrule-13", match = { class = "^(nm-connection-editor)$" }, opacity = "0.80 0.70", float = true })
hl.window_rule({ name = "windowrule-14", match = { class = "^(org.kde.polkit-kde-authentication-agent-1)$" }, opacity = "0.80 0.70", float = true })
hl.window_rule({ name = "windowrule-15", match = { class = "^(polkit-gnome-authentication-agent-1)$" },       opacity = "0.80 0.70" })
hl.window_rule({ name = "windowrule-16", match = { class = "^(org.freedesktop.impl.portal.desktop.gtk)$" },      opacity = "0.80 0.70" })
hl.window_rule({ name = "windowrule-17", match = { class = "^(org.freedesktop.impl.portal.desktop.hyprland)$" }, opacity = "0.80 0.70" })
hl.window_rule({ name = "windowrule-18", match = { class = "^([Ss]team)$" },        opacity = "0.70 0.70" })
hl.window_rule({ name = "windowrule-19", match = { class = "^(steamwebhelper)$" },  opacity = "0.70 0.70" })
hl.window_rule({ name = "windowrule-20", match = { class = "^(Spotify)$" },         opacity = "0.70 0.70" })
hl.window_rule({ name = "windowrule-21", match = { initial_title = "^(Spotify Free)$" }, opacity = "0.70 0.70" })
hl.window_rule({ name = "windowrule-22", match = { class = "^(com.github.rafostar.Clapper)$" },  opacity = "0.90 0.90", float = true })
hl.window_rule({ name = "windowrule-23", match = { class = "^(com.github.tchx84.Flatseal)$" },   opacity = "0.80 0.80" })
hl.window_rule({ name = "windowrule-24", match = { class = "^(hu.kramo.Cartridges)$" },          opacity = "0.80 0.80" })
hl.window_rule({ name = "windowrule-25", match = { class = "^(com.obsproject.Studio)$" },        opacity = "0.80 0.80" })
hl.window_rule({ name = "windowrule-26", match = { class = "^(gnome-boxes)$" },                  opacity = "0.80 0.80" })
hl.window_rule({ name = "windowrule-27", match = { class = "^(discord)$" },                      opacity = "0.80 0.80" })
hl.window_rule({ name = "windowrule-28", match = { class = "^(WebCord)$" },                      opacity = "0.80 0.80" })
hl.window_rule({ name = "windowrule-29", match = { class = "^(ArmCord)$" },                      opacity = "0.80 0.80" })
hl.window_rule({ name = "windowrule-30", match = { class = "^(app.drey.Warp)$" },                opacity = "0.80 0.80", float = true })
hl.window_rule({ name = "windowrule-31", match = { class = "^(net.davidotek.pupgui2)$" },        opacity = "0.80 0.80", float = true })
hl.window_rule({ name = "windowrule-32", match = { class = "^(yad)$" },                          opacity = "0.80 0.80", float = true })
hl.window_rule({ name = "windowrule-33", match = { class = "^(Signal)$" },                       opacity = "0.80 0.80", float = true })
hl.window_rule({ name = "windowrule-34", match = { class = "^(io.github.alainm23.planify)$" },   opacity = "0.80 0.80", float = true })
hl.window_rule({ name = "windowrule-35", match = { class = "^(io.gitlab.theevilskeleton.Upscaler)$" }, opacity = "0.80 0.80", float = true })
hl.window_rule({ name = "windowrule-36", match = { class = "^(com.github.unrud.VideoDownloader)$" },    opacity = "0.80 0.80" })
hl.window_rule({ name = "windowrule-37", match = { class = "^(io.gitlab.adhami3310.Impression)$" },     opacity = "0.80 0.80", float = true })

-- Float-only rules
hl.window_rule({ name = "windowrule-38", match = { class = "^(Rofi)$" }, float = true })
hl.window_rule({ name = "windowrule-39", match = { class = "^(org.kde.dolphin)$", title = "^(Copying — Dolphin)$" }, float = true })
hl.window_rule({ name = "windowrule-40", match = { class = "^(firefox)$", title = "^(Picture-in-Picture)$" },        float = true })
hl.window_rule({ name = "windowrule-41", match = { class = "^(firefox)$", title = "^(Library)$" },                   float = true })
hl.window_rule({ name = "windowrule-42", match = { class = "^(vlc)$" }, float = true })
hl.window_rule({ name = "windowrule-43", match = { class = "^(eog)$" }, float = true })
hl.window_rule({ name = "windowrule-44", match = { class = "^(com.github.unrud.VideoDownloader)$" }, float = true })

----------------------------------------------------------------------
-- LAYER RULES
----------------------------------------------------------------------

hl.layer_rule({ name = "layerrule-waybar", match = { namespace = "waybar" }, blur = true })   -- from themes/common.conf
hl.layer_rule({ name = "layerrule-1", match = { namespace = "rofi" },                      blur = true, ignore_alpha = 0 })
hl.layer_rule({ name = "layerrule-2", match = { namespace = "notifications" },             blur = true, ignore_alpha = 0 })
hl.layer_rule({ name = "layerrule-3", match = { namespace = "swaync-notification-window" }, blur = true, ignore_alpha = 0 })
hl.layer_rule({ name = "layerrule-4", match = { namespace = "swaync-control-center" },     blur = true, ignore_alpha = 0 })
hl.layer_rule({ name = "layerrule-5", match = { namespace = "logout_dialog" },             blur = true })

----------------------------------------------------------------------
-- USER PREFERENCES  (userprefs.conf was empty — add personal overrides here)
----------------------------------------------------------------------
