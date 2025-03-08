local UEHelpers = require("UEHelpers")

local function Log(msg)
	print("[ToggleDash] " .. msg)
end

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
				Log("Failed to unregister Init hook")
			end

			InitCallback()
		end)

		InitHookIds = { PreId, PostId }
	end
end

local function GetKSGameStatics()
	return StaticFindObject("/Script/Majesty.Default__KSGameStatics")
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
		Press = "/Game/Character/BP/KSPlayerControllerBP.KSPlayerControllerBP_C:InpActEvt_Dash_K2Node_InputActionEvent_75",
		Release = "/Game/Character/BP/KSPlayerControllerBP.KSPlayerControllerBP_C:InpActEvt_Dash_K2Node_InputActionEvent_76",
	}

	local UserToggledDash = false
	SetPlayerDash(false) -- for hot-reloading

	RegisterHook(DashActionFnName.Press, function()
		UserToggledDash = not UserToggledDash
		-- Not calling SetPlayerDash, since the game will call it anyways
	end)
	RegisterHook(DashActionFnName.Release, function()
		if UserToggledDash then
			SetPlayerDash(true) -- Re-enabling dash if the user has it toggled
		end
	end)

	Log("Mod initialization complete")
end)
