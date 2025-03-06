local UEHelpers = require("UEHelpers")
local Settings = require("settings")

local function Log(msg)
	print("[GameSpeedUp] " .. msg .. "\n")
end

Log("Processing settings")
table.insert(Settings.GameSpeedList, 1, 1) -- Implicit 1x
for _, keybind in pairs(Settings.Keybinds) do
	keybind.Key = Key[string.upper(keybind.Key)]
	assert(keybind.Key)

	for i = 1, #keybind.ModifierKeys do
		keybind.ModifierKeys[i] = ModifierKey[string.upper(keybind.ModifierKeys[i])]
		assert(keybind.ModifierKeys[i])
	end
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
				print("[function StartMod] Failed to unregister Init hook")
			end

			InitCallback()
		end)

		InitHookIds = { PreId, PostId }
	end
end

local function GetKSGameStatics()
	return StaticFindObject("/Script/Octopath_Traveler.Default__KSGameStatics")
end

---@param list [any]
---@param x any
---@return number?
local function LinearSearch(list, x)
	for i, v in ipairs(list) do
		if v == x then
			return i
		end
	end
	return nil
end

RegisterMod(function()
	Log("Starting mod initialization")

	local GameplayStatics = UEHelpers.GetGameplayStatics()

	---@param speed number
	local function SetGameSpeed(speed)
		Log(string.format("GameSpeed:%d", speed))
		GameplayStatics:SetGlobalTimeDilation(UEHelpers.GetWorld(), speed)
	end

	local KSGameStatics = GetKSGameStatics()
	assert(KSGameStatics:IsValid())

	---@return boolean
	local function IsBattleOn()
		return KSGameStatics:GetBattleMode(UEHelpers.GetWorld())
	end

	local ModState = {
		InBattle = IsBattleOn(),
		IsSpeedChangedDuringBattle = false,
		GameSpeedIdxBeforeBattle = 1,
		ActiveGameSpeedIdx = 1,
		CombatGameSpeedIdx = LinearSearch(Settings.GameSpeedList, Settings.AutoCombatSpeedup.CombatGameSpeed),
	}

	local function CycleActiveGameSpeed()
		ModState.ActiveGameSpeedIdx = ModState.ActiveGameSpeedIdx % #Settings.GameSpeedList + 1
	end

	Log(string.format("AutoCombatSpeedup.Enable:%s", tostring(Settings.AutoCombatSpeedup.Enable)))
	if Settings.AutoCombatSpeedup.Enable then
		if ModState.InBattle then
			-- This is mostly for convenience incase let's you have 2 game speed set, 1x, and 2x
			-- With ActiveGameSpeed currently being 1x and the CombatGameSpeed being 2x, so now in combat,
			-- if you cycle through, you'll get from 2x to 1x, instead of 2x to 2x.
			ModState.GameSpeedIdxBeforeBattle = ModState.ActiveGameSpeedIdx
			if ModState.CombatGameSpeedIdx then
				ModState.ActiveGameSpeedIdx = ModState.CombatGameSpeedIdx
			end

			-- Set combat game speed regardless of whether the value is in GameSpeedList
			SetGameSpeed(Settings.AutoCombatSpeedup.CombatGameSpeed)
		else
			SetGameSpeed(Settings.GameSpeedList[ModState.ActiveGameSpeedIdx])
		end

		RegisterHook("/Game/Battle/BP/BattleManagerBP.BattleManagerBP_C:Start", function()
			-- Performing check since this gets called many times when the battle is starting
			if not ModState.InBattle then
				ModState.GameSpeedIdxBeforeBattle = ModState.ActiveGameSpeedIdx
				if ModState.CombatGameSpeedIdx then
					ModState.ActiveGameSpeedIdx = ModState.CombatGameSpeedIdx
				end
				SetGameSpeed(Settings.AutoCombatSpeedup.CombatGameSpeed)
				ModState.InBattle = true
			end
		end)
		RegisterHook("/Game/Battle/BP/BattleManagerBP.BattleManagerBP_C:EndProcess", function()
			if ModState.InBattle then
				if not ModState.IsSpeedChangedDuringBattle then
					-- Restore previous speed only if the speed wasn't changed by the user
					ModState.ActiveGameSpeedIdx = ModState.GameSpeedIdxBeforeBattle
					SetGameSpeed(Settings.GameSpeedList[ModState.ActiveGameSpeedIdx])
				else
					ModState.IsSpeedChangedDuringBattle = false
				end
				ModState.InBattle = false
			end
		end)
	end

	local GameSpeedCycleKeybind = Settings.Keybinds.GameSpeedCycle
	RegisterKeyBind(GameSpeedCycleKeybind.Key, GameSpeedCycleKeybind.ModifierKeys, function()
		if Settings.AutoCombatSpeedup.Enable and IsBattleOn() then
			ModState.IsSpeedChangedDuringBattle = true
		end

		CycleActiveGameSpeed()
		SetGameSpeed(Settings.GameSpeedList[ModState.ActiveGameSpeedIdx])
	end)

	Log("Mod initialization complete")
end)
