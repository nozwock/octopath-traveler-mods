local Keybind = { Key = Key.SPACE, ModifierKeys = {} }

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

--- Runs callback once PlayerController is available
---@param InitCallback function
local function RegisterMod(InitCallback)
	if pcall(UEHelpers.GetPlayerController) then
		-- For hot-reloading
		InitCallback()
	else
		local InitHookIds
		local PreId, PostId = RegisterHook("/Script/Engine.PlayerController:ClientRestart", function()
			if InitHookIds then
				UnregisterHook("/Script/Engine.PlayerController:ClientRestart", table.unpack(InitHookIds))
			else
				print("[function StartMod] Failed to unregister Init hook")
			end

			InitCallback()
		end)

		InitHookIds = { PreId, PostId }
	end
end

local function Log(msg)
	print("[ToggleDash] " .. msg)
end

local function GetKSGameStatics()
	return StaticFindObject("/Script/Octopath_Traveler.Default__KSGameStatics")
end

RegisterMod(function()
	Log("Starting mod initialization")

	local KSGameStatics = GetKSGameStatics()
	assert(KSGameStatics:IsValid())

	---@return boolean
	local function GetPlayerDash()
		return KSGameStatics:GetPlayerDash(UEHelpers.GetWorld())
	end

	---@param v boolean
	local function SetPlayerDash(v)
		KSGameStatics:SetPlayerDash(UEHelpers.GetWorld(), v)
	end

	local DashActionFnName = {
		Press = "/Game/Character/BP/KSPlayerControllerBP.KSPlayerControllerBP_C:InpActEvt_Dash_K2Node_InputActionEvent_56",
		Release = "/Game/Character/BP/KSPlayerControllerBP.KSPlayerControllerBP_C:InpActEvt_Dash_K2Node_InputActionEvent_57",
	}

	local UserToggledDash = false

	RegisterKeyBind(Keybind["Key"], Keybind["ModifierKeys"], function()
		UserToggledDash = not UserToggledDash
		SetPlayerDash(UserToggledDash)
	end)

	-- note: ActionController_Impl_C:OnActionDash triggers for dash key press and releases, and resets by game
	-- Resets by game trigger both :OnActionDash and :ResetDash
	--
	-- So the below could be done with just one hook to :OnActionDash I believe

	-- Re-enable dash if it got turned off by the game while the user still has the dash toggled
	RegisterHook("/Game/Character/BP/KSPlayerControllerBP.KSPlayerControllerBP_C:ResetDash", function()
		if UserToggledDash then
			SetPlayerDash(true)
		end
	end)
	RegisterHook(DashActionFnName.Release, function()
		if UserToggledDash then
			SetPlayerDash(true)
		end
	end)

	Log("Mod initialization complete")
end)
