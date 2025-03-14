local UEHelpers = require("UEHelpers")
local inspect = require("inspect")
local Settings = require("settings")

local function Log(...)
	local args = table.pack(...)
	for i = 1, #args do
		args[i] = tostring(args[i])
	end
	print("[SpeedWarp] " .. table.concat(args, ", ") .. "\n")
end

Log("Processing settings:\n" .. inspect(Settings))
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
		CombatGameSpeedIdx = LinearSearch(Settings.GameSpeedList, Settings.CombatSpeed.AutoSpeedup.CombatGameSpeed),
		CombatGameSpeedOn = false,
		ActiveTimeDilation = 1,
		CallingSetTimeDilation = false,
		LastBattleFlow = 0,
	}

	---@param speed number
	local function SetGameSpeed(speed)
		-- Log("SetGameSpeed:" .. speed)
		ModState.ActiveTimeDilation = speed
		ModState.CallingSetTimeDilation = true
		GameplayStatics:SetGlobalTimeDilation(UEHelpers.GetWorld(), speed)
		ModState.CallingSetTimeDilation = false
	end

	RegisterHook("/Script/Engine.GameplayStatics:SetGlobalTimeDilation", function() end, function()
		if not ModState.CallingSetTimeDilation then
			-- Log("Overriding game speed set from outside the mod")
			SetGameSpeed(ModState.ActiveTimeDilation)
		end
	end)

	local function CycleActiveGameSpeed()
		ModState.ActiveGameSpeedIdx = ModState.ActiveGameSpeedIdx % #Settings.GameSpeedList + 1
		-- Log("CycledActiveGameSpeedTo:" .. Settings.GameSpeedList[ModState.ActiveGameSpeedIdx])
	end

	local function ShouldResetCombatSpeed(BattleFlow)
		return BattleFlow == 0 or BattleFlow == 5 or (BattleFlow >= 13 and BattleFlow <= 15)
	end
	local function ShouldIncreaseCombatSpeed(BattleFlow)
		return BattleFlow == 8 or BattleFlow == 12
	end

	local function GetCombatGameSpeedForTurnResolution()
		-- Set combat game speed regardless of whether the value is in GameSpeedList
		local CombatGameSpeed = Settings.CombatSpeed.AutoSpeedup.CombatGameSpeed
		if ModState.IsSpeedChangedDuringBattle or not Settings.CombatSpeed.AutoSpeedup.Enable then
			CombatGameSpeed = Settings.GameSpeedList[ModState.ActiveGameSpeedIdx]
		end

		return CombatGameSpeed
	end

	-- For hot-reloading
	if ModState.InBattle then
		-- This is mostly for convenience incase let's you have 2 game speed set, 1x, and 2x
		-- With ActiveGameSpeed currently being 1x and the CombatGameSpeed being 2x, so now in combat,
		-- if you cycle through, you'll get from 2x to 1x, instead of 2x to 2x.
		ModState.GameSpeedIdxBeforeBattle = ModState.ActiveGameSpeedIdx
		if Settings.CombatSpeed.AutoSpeedup.Enable and ModState.CombatGameSpeedIdx then
			ModState.ActiveGameSpeedIdx = ModState.CombatGameSpeedIdx
		end

		if Settings.CombatSpeed.OnlyInTurnResolution then
			ModState.LastBattleFlow = GetBattleFlow()
			if not ShouldResetCombatSpeed(ModState.LastBattleFlow) then
				SetGameSpeed(GetCombatGameSpeedForTurnResolution())
				ModState.CombatGameSpeedOn = true
			else
				SetGameSpeed(Settings.GameSpeedList[ModState.GameSpeedIdxBeforeBattle])
			end
		elseif Settings.CombatSpeed.AutoSpeedup.Enable then
			SetGameSpeed(Settings.CombatSpeed.AutoSpeedup.CombatGameSpeed)
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

	if Settings.CombatSpeed.OnlyInTurnResolution then
		RegisterHook(
			"/Game/Battle/BP/BattleManagerBP.BattleManagerBP_C:ChangeBattleFlow",
			function(self, NextFlow, CurrentFlow, IsChange)
				local iCurrentFlow = CurrentFlow:get()
				-- Log(iCurrentFlow .. " -> " .. NextFlow:get())
				ModState.LastBattleFlow = iCurrentFlow
				if ModState.CombatGameSpeedOn and ShouldResetCombatSpeed(iCurrentFlow) then
					SetGameSpeed(1)
					ModState.CombatGameSpeedOn = false
				elseif not ModState.CombatGameSpeedOn and ShouldIncreaseCombatSpeed(iCurrentFlow) then
					SetGameSpeed(GetCombatGameSpeedForTurnResolution())
					ModState.CombatGameSpeedOn = true
				end
			end
		)
	end

	-- Called at BattleFlow 2
	RegisterHook("/Game/Battle/BP/BattleManagerBP.BattleManagerBP_C:Start", function()
		-- Performing check since this gets called many times when the battle is starting
		if not ModState.InBattle then
			ModState.GameSpeedIdxBeforeBattle = ModState.ActiveGameSpeedIdx
			if Settings.CombatSpeed.AutoSpeedup.Enable then
				if ModState.CombatGameSpeedIdx then
					ModState.ActiveGameSpeedIdx = ModState.CombatGameSpeedIdx
				end
				SetGameSpeed(Settings.CombatSpeed.AutoSpeedup.CombatGameSpeed)
			end
			ModState.IsSpeedChangedDuringBattle = false
			ModState.CombatGameSpeedOn = true
			ModState.InBattle = true
		end
	end)
	-- Called at BattleFlow 17
	RegisterHook("/Game/Battle/BP/BattleManagerBP.BattleManagerBP_C:EndProcess", function()
		if ModState.InBattle then
			-- Restore game speed after battle
			if
				(Settings.CombatSpeed.AutoSpeedup.Enable and not ModState.IsSpeedChangedDuringBattle)
				or Settings.CombatSpeed.ForceRestoreGameSpeed
			then
				ModState.ActiveGameSpeedIdx = ModState.GameSpeedIdxBeforeBattle
				SetGameSpeed(Settings.GameSpeedList[ModState.ActiveGameSpeedIdx])
			elseif Settings.CombatSpeed.OnlyInTurnResolution then
				SetGameSpeed(GetCombatGameSpeedForTurnResolution())
			end
			ModState.IsSpeedChangedDuringBattle = false
			ModState.CombatGameSpeedOn = false
			ModState.InBattle = false
		end
	end)

	-- todo: An option to use the "Path Action/Details" for cycling game speed, but ONLY in combat,
	-- as the key actually is used outside of combat by the game. So, this atleast allows limited
	-- ability for users with gamepad to cycle through the game speed list.

	local GameSpeedCycleKeybind = Settings.Keybinds.GameSpeedCycle
	RegisterKeyBind(GameSpeedCycleKeybind.Key, GameSpeedCycleKeybind.ModifierKeys, function()
		local bIsBattleOn = IsBattleOn()
		if bIsBattleOn then
			ModState.IsSpeedChangedDuringBattle = true
		end

		local IsHandledInTurnResolution = (
			bIsBattleOn
			and Settings.CombatSpeed.OnlyInTurnResolution
			and ShouldResetCombatSpeed(ModState.LastBattleFlow)
		)

		CycleActiveGameSpeed()
		if not IsHandledInTurnResolution then
			SetGameSpeed(Settings.GameSpeedList[ModState.ActiveGameSpeedIdx])
		end
	end)

	Log("Mod initialization complete")
end)
