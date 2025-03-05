Keybind = { ["Key"] = Key.SPACE, ["ModifierKeys"] = {} }

--[[
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

    Valid modifier keys:
    SHIFT
    CONTROL
    ALT
--]]

local UEHelpers = require("UEHelpers")

local KSGameStatics = FindFirstOf("KSGameStatics")
if not KSGameStatics:IsValid() then
	KSGameStatics = StaticConstructObject(
		StaticFindObject("/Script/Octopath_Traveler.KSGameStatics"),
		StaticFindObject("/Script/Engine.BlueprintFunctionLibrary")
	)
end

---@return boolean
local function GetPlayerDash()
	return KSGameStatics:GetPlayerDash(UEHelpers.GetWorld())
end

---@param v boolean
local function SetPlayerDash(v)
	KSGameStatics:SetPlayerDash(UEHelpers.GetWorld(), v)
end

local DashState = {
	UserToggled = false,
	IgnoreDashHookCount = 0,
}

RegisterKeyBind(Keybind["Key"], Keybind["ModifierKeys"], function()
	DashState.UserToggled = not GetPlayerDash()
	SetPlayerDash(DashState.UserToggled)
end)

RegisterHook("/Game/Character/BP/ActionController_Impl.ActionController_Impl_C:OnActionDash", function()
	if DashState.UserToggled then
		DashState.UserToggled = false
	end
end)

RegisterHook("/Script/Octopath_Traveler.KSGameStatics:SetPlayerDash", function()
	-- note: The control flow here is finnicky and fragile, do pay attention
	local NextDash = not GetPlayerDash()
	if DashState.IgnoreDashHookCount > 0 then
		DashState.IgnoreDashHookCount = DashState.IgnoreDashHookCount - 1
	else
		-- Re-enable dash if it got turned off by the game while the user still has the dash toggled
		if not NextDash and DashState.UserToggled then
			DashState.IgnoreDashHookCount = DashState.IgnoreDashHookCount + 1
			ExecuteWithDelay(100, function()
				SetPlayerDash(true)
			end)
		end
	end
end)
