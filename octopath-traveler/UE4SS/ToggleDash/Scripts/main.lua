local UEHelpers = require("UEHelpers")

local function Log(...)
	local args = table.pack(...)
	for i = 1, #args do
		args[i] = tostring(args[i])
	end
	print("[ToggleDash] " .. table.concat(args, ", ") .. "\n")
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

---@param Class UObject
---@param FunctionPattern string
---@return UFunction[]?
local function FindFunctionsByPattern(Class, FunctionPattern)
	if not Class:IsValid() then
		return nil
	end

	local Results = {}
	Class:ForEachFunction(function(Function)
		local FunctionName = Function:GetFName():ToString()

		if string.find(FunctionName, FunctionPattern) then
			table.insert(Results, Function)
		end
	end)

	return Results
end

---@return boolean
local function IsRunningFirstGame()
	local KSGameStaticsClass = StaticFindObject("/Script/Octopath_Traveler.KSGameStatics")
	if KSGameStaticsClass:IsValid() then
		return true
	end

	KSGameStaticsClass = StaticFindObject("/Script/Majesty.Default__KSGameStatics")
	if KSGameStaticsClass:IsValid() then
		return false
	end

	error("Mod doesn't seem to be running on either Octopath 1 or 2")
end

RegisterMod(function()
	Log("Starting mod initialization")

	local IsRunningFirstGameBool = IsRunningFirstGame()
	Log("IsRunningFirstGame:" .. tostring(IsRunningFirstGameBool))

	local KSGameStatics
	if IsRunningFirstGameBool then
		KSGameStatics = StaticFindObject("/Script/Octopath_Traveler.Default__KSGameStatics")
	else
		KSGameStatics = StaticFindObject("/Script/Majesty.Default__KSGameStatics")
	end
	assert(KSGameStatics:IsValid())

	---@return boolean
	local function GetPlayerDash()
		return KSGameStatics:GetPlayerDash(UEHelpers.GetWorld())
	end

	---@param v boolean
	local function SetPlayerDash(v)
		KSGameStatics:SetPlayerDash(UEHelpers.GetWorld(), v)
	end

	local KSPlayerControllerBPClassPath = "/Game/Character/BP/KSPlayerControllerBP.KSPlayerControllerBP_C"
	local KSPlayerControllerBPClass = StaticFindObject(KSPlayerControllerBPClassPath)
	assert(KSPlayerControllerBPClass:IsValid())

	local DashActionFnName
	do
		-- An e.g. full path for press:
		-- /Game/Character/BP/KSPlayerControllerBP.KSPlayerControllerBP_C:InpActEvt_Dash_K2Node_InputActionEvent_75
		--
		-- I've only ever noticed the Press input having a lower number suffix, so I'm going to rely on that behaviour here
		-- to get the press and release function name programmatically

		local DashActionFns = FindFunctionsByPattern(KSPlayerControllerBPClass, "InpActEvt_Dash")
		assert(DashActionFns)
		assert(#DashActionFns >= 2)

		for i = 1, #DashActionFns do
			DashActionFns[i] = (DashActionFns[i]):GetFName():ToString()
		end
		table.sort(DashActionFns, function(a, b)
			return a < b
		end)

		DashActionFnName = { Press = DashActionFns[1], Release = DashActionFns[2] }
	end

	local UserToggledDash = false
	SetPlayerDash(false) -- for hot-reloading

	RegisterHook(string.format("%s:%s", KSPlayerControllerBPClassPath, DashActionFnName.Press), function()
		UserToggledDash = not UserToggledDash
		-- Not calling SetPlayerDash, since the game will call it anyways
	end)
	RegisterHook(string.format("%s:%s", KSPlayerControllerBPClassPath, DashActionFnName.Release), function()
		if UserToggledDash then
			SetPlayerDash(true) -- Re-enabling dash if the user has it toggled
		end
	end)

	if IsRunningFirstGameBool then
		-- note: ActionController_Impl_C:OnActionDash triggers for dash key press and releases, and resets by game
		-- Resets by game trigger both :OnActionDash and :ResetDash

		-- Re-enable dash if it got turned off by the game while the user still has the dash toggled
		RegisterHook("/Game/Character/BP/KSPlayerControllerBP.KSPlayerControllerBP_C:ResetDash", function()
			if UserToggledDash then
				SetPlayerDash(true)
			end
		end)
	end

	Log("Mod initialization complete")
end)
