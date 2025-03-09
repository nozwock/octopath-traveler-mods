local UEHelpers = require("UEHelpers")
local Settings = require("settings")

local function Log(msg)
	print("[SpeedWarp] " .. msg .. "\n")
end

-- todo: Add an option to not bleed in the game speed changes made in combat outside of combat

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
	assert(GameplayStatics:IsValid())

	local KSGameStatics = StaticFindObject("/Script/Octopath_Traveler.Default__KSGameStatics")
	assert(KSGameStatics:IsValid())

	local BattleManager = StaticFindObject("/Game/Battle/BP/BattleManagerBP.Default__BattleManagerBP_C")
	assert(BattleManager:IsValid())

	---@return boolean
	local function IsBattleOn()
		return KSGameStatics:GetBattleMode(UEHelpers.GetWorld())
	end

	---@return integer
	local function GetBattleFlow()
		local Ret = {}
		BattleManager:GetCurrentFlow(Ret)
		return Ret.CurrentFlow
	end

	local ModState = {
		InBattle = IsBattleOn(),
		IsSpeedChangedDuringBattle = false,
		GameSpeedIdxBeforeBattle = 1,
		ActiveGameSpeedIdx = 1,
		CombatGameSpeedIdx = LinearSearch(Settings.GameSpeedList, Settings.AutoCombatSpeedup.CombatGameSpeed),
		CombatGameSpeedOn = false,
		ActiveTimeDilation = 1,
		CallingSetTimeDilation = false,
		LastBattleFlow = nil,
	}

	---@param speed number
	local function SetGameSpeed(speed)
		ModState.ActiveTimeDilation = speed
		ModState.CallingSetTimeDilation = true
		GameplayStatics:SetGlobalTimeDilation(UEHelpers.GetWorld(), speed)
		ModState.CallingSetTimeDilation = false
	end

	RegisterHook("/Script/Engine.GameplayStatics:SetGlobalTimeDilation", function() end, function()
		if not ModState.CallingSetTimeDilation then
			SetGameSpeed(ModState.ActiveTimeDilation)
		end
	end)

	local function CycleActiveGameSpeed()
		ModState.ActiveGameSpeedIdx = ModState.ActiveGameSpeedIdx % #Settings.GameSpeedList + 1
		-- Log("CycledActiveGameSpeedTo:" .. Settings.GameSpeedList[ModState.ActiveGameSpeedIdx])
	end

	Log(
		string.format(
			"AutoCombatSpeedup.Enable:%s, OnlyInTurnResolution:%s",
			tostring(Settings.AutoCombatSpeedup.Enable),
			tostring(Settings.AutoCombatSpeedup.OnlyInTurnResolution)
		)
	)

	local function ShouldResetCombatSpeed(BattleFlow)
		return BattleFlow == 0 or BattleFlow == 5 or (BattleFlow >= 13 and BattleFlow <= 15)
	end
	local function ShouldIncreaseCombatSpeed(BattleFlow)
		return BattleFlow == 8 or BattleFlow == 12
	end

	if Settings.AutoCombatSpeedup.Enable then
		-- For hot-reloading
		if ModState.InBattle then
			-- This is mostly for convenience incase let's you have 2 game speed set, 1x, and 2x
			-- With ActiveGameSpeed currently being 1x and the CombatGameSpeed being 2x, so now in combat,
			-- if you cycle through, you'll get from 2x to 1x, instead of 2x to 2x.
			ModState.GameSpeedIdxBeforeBattle = ModState.ActiveGameSpeedIdx
			if ModState.CombatGameSpeedIdx then
				ModState.ActiveGameSpeedIdx = ModState.CombatGameSpeedIdx
			end

			if Settings.AutoCombatSpeedup.OnlyInTurnResolution then
				ModState.LastBattleFlow = GetBattleFlow()
				if not ShouldResetCombatSpeed(ModState.LastBattleFlow) then
					-- Set combat game speed regardless of whether the value is in GameSpeedList
					SetGameSpeed(Settings.AutoCombatSpeedup.CombatGameSpeed)
					ModState.CombatGameSpeedOn = true
				else
					SetGameSpeed(Settings.GameSpeedList[ModState.ActiveGameSpeedIdx])
				end
			else
				SetGameSpeed(Settings.AutoCombatSpeedup.CombatGameSpeed)
				ModState.CombatGameSpeedOn = true
			end
		else
			SetGameSpeed(Settings.GameSpeedList[ModState.ActiveGameSpeedIdx])
		end

		--[[
            Battle Flow enum observations:
            5: Waiting on user to decide their turn
            13, 14: Victory
            15: Defeat
            16: Flee
            17: Closing batlle
            18: Battle closed
            12: Triggers a lot in b/w the back and forth of player and enemies, but
                also the first one to trigger when exiting from battle in some way
        --]]

		if Settings.AutoCombatSpeedup.OnlyInTurnResolution then
			RegisterHook(
				"/Game/Battle/BP/BattleManagerBP.BattleManagerBP_C:ChangeBattleFlow",
				function(self, NextFlow, CurrentFlow, IsChange)
					local CombatGameSpeed = Settings.AutoCombatSpeedup.CombatGameSpeed
					if ModState.IsSpeedChangedDuringBattle then
						CombatGameSpeed = Settings.GameSpeedList[ModState.ActiveGameSpeedIdx]
					end

					local iCurrentFlow = CurrentFlow:get()
					ModState.LastBattleFlow = iCurrentFlow
					if ModState.CombatGameSpeedOn and ShouldResetCombatSpeed(iCurrentFlow) then
						SetGameSpeed(1)
						ModState.CombatGameSpeedOn = false
					elseif not ModState.CombatGameSpeedOn and ShouldIncreaseCombatSpeed(iCurrentFlow) then
						SetGameSpeed(CombatGameSpeed)
						ModState.CombatGameSpeedOn = true
					end
				end
			)
		end

		-- Called at BattleFlow 2?
		RegisterHook("/Game/Battle/BP/BattleManagerBP.BattleManagerBP_C:Start", function()
			-- Performing check since this gets called many times when the battle is starting
			if not ModState.InBattle then
				ModState.GameSpeedIdxBeforeBattle = ModState.ActiveGameSpeedIdx
				if ModState.CombatGameSpeedIdx then
					ModState.ActiveGameSpeedIdx = ModState.CombatGameSpeedIdx
				end
				SetGameSpeed(Settings.AutoCombatSpeedup.CombatGameSpeed)
				ModState.CombatGameSpeedOn = true
				ModState.InBattle = true
			end
		end)
		-- Called at BattleFlow 17?
		RegisterHook("/Game/Battle/BP/BattleManagerBP.BattleManagerBP_C:EndProcess", function()
			if ModState.InBattle then
				-- Restore game speed after battle
				if not ModState.IsSpeedChangedDuringBattle or Settings.AutoCombatSpeedup.ForceRestoreGameSpeed then
					ModState.ActiveGameSpeedIdx = ModState.GameSpeedIdxBeforeBattle
					SetGameSpeed(Settings.GameSpeedList[ModState.ActiveGameSpeedIdx])
				else
					ModState.IsSpeedChangedDuringBattle = false
				end
				ModState.InBattle = false
				ModState.CombatGameSpeedOn = false
			end
		end)
	end

	local GameSpeedCycleKeybind = Settings.Keybinds.GameSpeedCycle
	RegisterKeyBind(GameSpeedCycleKeybind.Key, GameSpeedCycleKeybind.ModifierKeys, function()
		local bIsBattleOn = IsBattleOn()
		if Settings.AutoCombatSpeedup.Enable and bIsBattleOn then
			ModState.IsSpeedChangedDuringBattle = true
		end

		local IsHandledInTurnResolution = (
			Settings.AutoCombatSpeedup.Enable
			and bIsBattleOn
			and Settings.AutoCombatSpeedup.OnlyInTurnResolution
			and ShouldResetCombatSpeed(ModState.LastBattleFlow)
		)

		CycleActiveGameSpeed()
		if not IsHandledInTurnResolution then
			SetGameSpeed(Settings.GameSpeedList[ModState.ActiveGameSpeedIdx])
		end
	end)

	Log("Mod initialization complete")
end)
