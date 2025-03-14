local Settings = { Keybinds = {}, CombatSpeed = {} }

-- EDITABLE SECTION START

-- The game speed list that you can cycle through in-game, via either
-- the "Travel Banter" key (if enabled) or the custom keybind GameSpeedCycle,
-- that's listed below in this settings file.
--
-- 1x is in the list implicitly.
Settings.GameSpeedList = { 2 }

-- Game speed-ups in combat mode apply only after the player has chosen a battle action.
Settings.CombatSpeed.OnlyInTurnResolution = true

-- Automatically increases game speed upon entering combat
-- and restores the previous speed when the battle ends.
Settings.CombatSpeed.AutoSpeedup = {
	Enable = true,

	-- Game speed to start the combat with.
	CombatGameSpeed = 2,
}

-- Restores the game speed to its pre-combat value once the combat is over,
-- even if the user adjusted the speed mid-combat using GameSpeedCycle.
--
-- If disabled, even with CombatSpeed.AutoSpeedup, the game speed will not be reset after battle
-- if the user changed it using the GameSpeedCycle hotkey.
Settings.CombatSpeed.ForceRestoreGameSpeed = true

-- Cycle through all the speeds in the GameSpeedList.
Settings.Keybinds.GameSpeedCycle = {
	Key = "F8",

	-- E.g.
	-- ModifierKeys = { "SHIFT", "ALT" },
	ModifierKeys = {},

	-- Allows using the "Travel Banter" key to cycle through the game speed list as well,
	-- but only while in combat mode since the key is used by the game outside of it.
	UseTravelBanterKeyInCombat = true,
}

-- EDITABLE SECTION END

--[[
    Valid modifier keys:
    SHIFT
    CONTROL
    ALT

    Valid keys:
    LEFT_MOUSE_BUTTON
    RIGHT_MOUSE_BUTTON
    CANCEL
    MIDDLE_MOUSE_BUTTON
    XBUTTON_ONE
    XBUTTON_TWO
    BACKSPACE
    TAB
    CLEAR
    RETURN
    PAUSE
    CAPS_LOCK
    IME_KANA
    IME_HANGUEL
    IME_HANGUL
    IME_ON
    IME_JUNJA
    IME_FINAL
    IME_HANJA
    IME_KANJI
    IME_OFF
    ESCAPE
    IME_CONVERT
    IME_NONCONVERT
    IME_ACCEPT
    IME_MODECHANGE
    SPACE
    PAGE_UP
    PAGE_DOWN
    END
    HOME
    LEFT_ARROW
    UP_ARROW
    RIGHT_ARROW
    DOWN_ARROW
    SELECT
    PRINT
    EXECUTE
    PRINT_SCREEN
    INS

    Valid modifier keys:
    SHIFT
    CONTROL
    ALT
    DEL
    HELP
    ZERO
    ONE
    TWO
    THREE
    FOUR
    FIVE
    SIX
    SEVEN
    EIGHT
    NINE
    A
    B
    C
    D
    E
    F
    G
    H
    I
    J
    K
    L
    M
    N
    O
    P
    Q
    R
    S
    T
    U
    V
    W
    X
    Y
    Z
    LEFT_WIN
    RIGHT_WIN
    APPS
    SLEEP
    NUM_ZERO
    NUM_ONE
    NUM_TWO
    NUM_THREE
    NUM_FOUR
    NUM_FIVE
    NUM_SIX
    NUM_SEVEN
    NUM_EIGHT
    NUM_NINE
    MULTIPLY
    ADD
    SEPARATOR
    SUBTRACT
    DECIMAL
    DIVIDE
    F1
    F2
    F3
    F4
    F5
    F6
    F7
    F8
    F9
    F10
    F11
    F12
    F13
    F14
    F15
    F16
    F17
    F18
    F19
    F20
    F21
    F22
    F23
    F24
    NUM_LOCK
    SCROLL_LOCK
    BROWSER_BACK
    BROWSER_FORWARD
    BROWSER_REFRESH
    BROWSER_STOP
    BROWSER_SEARCH
    BROWSER_FAVORITES
    BROWSER_HOME
    VOLUME_MUTE
    VOLUME_DOWN
    VOLUME_UP
    MEDIA_NEXT_TRACK
    MEDIA_PREV_TRACK
    MEDIA_STOP
    MEDIA_PLAY_PAUSE
    LAUNCH_MAIL
    LAUNCH_MEDIA_SELECT
    LAUNCH_APP1
    LAUNCH_APP2
    OEM_ONE
    OEM_PLUS
    OEM_COMMA
    OEM_MINUS
    OEM_PERIOD
    OEM_TWO
    OEM_THREE
    OEM_FOUR
    OEM_FIVE
    OEM_SIX
    OEM_SEVEN
    OEM_EIGHT
    OEM_102
    IME_PROCESS
    PACKET
    ATTN
    CRSEL
    EXSEL
    EREOF
    PLAY
    ZOOM
    PA1
    OEM_CLEAR
--]]

return Settings
