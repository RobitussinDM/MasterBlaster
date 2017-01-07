-- shows the advised spell for optimal DPS output.

MasterBlaster = {Locals = {}}
local L = MasterBlaster.Locals

-- variables to save game state
MasterBlaster.versionNumber = '0.1';
MasterBlaster.enabled = true;
MasterBlaster.playerName = UnitName("player");
MasterBlaster.playerGUID = UnitGUID("player");
MasterBlaster.targetGUID = nil;
MasterBlaster.spellHaste = GetCombatRatingBonus(20);
MasterBlaster.timeSinceLastUpdate = 0;
MasterBlaster.inCombat = false;
MasterBlaster.lastBaseGCD = 1.5;
MasterBlaster.person = {
	["foeCount"]	= 0,
	["friendCount"]	= 0,
	["friend"]  = {},
	["foe"]		= {}
};
MasterBlaster.talents = {};
MasterBlaster.lastPersonTablePurged = 0.0;
MasterBlaster.configPanel = nil;
MasterBlaster.prevDB = {};
MasterBlaster.DebugChat = DEFAULT_CHAT_FRAME;
MasterBlaster.inParty = 0;
MasterBlaster.spec = ""  -- name of the specialization 
MasterBlaster.specUnsure = true
MasterBlaster.lastSpell = ""
MasterBlaster.lastCastTime = 0
-- spells available to multiple modules
MasterBlaster.SpellList = {
	-- racials
	["Berserking"] = GetSpellInfo(26297),	-- Troll racial
	["Blood Fury"] = GetSpellInfo(33697),	-- Orc racial
}
-- list of currently shown textures in the spell adviser
MasterBlaster.textureList = {
	["next"] = nil,
	["next1"] = nil,
	["next2"] = nil,
	["major"] = nil,
	["int"] = nil,
	["misc"] = nil,
	["aoe"] = nil
}
-- list of currently shown text values in the spell adviser
MasterBlaster.textList = {
	["misc_charges"] = nil,
	["power"] = nil
}
-- array to check combat log for in combat
MasterBlaster.HostileFilter = {
  ["_DAMAGE"] = true, 
  ["_LEECH"] = true,
  ["_DRAIN"] = true,
  ["_STOLEN"] = true,
  ["_INSTAKILL"] = true,
  ["_INTERRUPT"] = true,
  ["_MISSED"] = true,
  ["_START"] = true
}
-- list of modules available by spec
MasterBlaster.modules = {}

-- frame to watch for events ... checks MasterBlaster.events[] for the function.  Passes all args.
MasterBlaster.eventFrame = CreateFrame("Frame")
MasterBlaster.eventFrame:SetScript("OnEvent", function(this, event, ...)
  MasterBlaster.events[event](...)
end)

MasterBlaster.eventFrame:RegisterEvent("ADDON_LOADED");
MasterBlaster.eventFrame:RegisterEvent("PLAYER_LOGIN");
MasterBlaster.eventFrame:RegisterEvent("PLAYER_ALIVE");
MasterBlaster.eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD");

-- define our event handlers here
MasterBlaster.events = {}

-- output to the debut window
function MasterBlaster:Debug(statictxt,msg)
	if (MasterBlasterDB.DebugMode) and (MasterBlaster.DebugChat) then
		if (msg) then
			MasterBlaster.DebugChat:AddMessage( date("MasterBlaster - %I:%M:%S:  ") .. " " .. statictxt  .. " : " .. msg)
		else
			MasterBlaster.DebugChat:AddMessage( date("MasterBlaster - %I:%M:%S:  ") .. statictxt  .. " : " .. "<nil>")
		end
	end
end

-- figure out which chat window is for debugging
function MasterBlaster:GetDebugFrame()
	for i=1,NUM_CHAT_WINDOWS do
		local windowName = GetChatWindowInfo(i);
		if windowName == "Debug" then
			return getglobal("ChatFrame" .. i)
		end
	end
	return DEFAULT_CHAT_FRAME
end

-- hook into events raised in game
function MasterBlaster.events.PLAYER_TALENT_UPDATE()
	MasterBlaster:detectSpecialization()
	MasterBlaster:ApplySettings()
end

function MasterBlaster.events.PARTY_MEMBERS_CHANGED()
	MasterBlaster.inParty = MasterBlaster:PlayerInParty()
end

function MasterBlaster.events.PLAYER_ALIVE()
	MasterBlaster:detectSpecialization()
	MasterBlaster:ApplySettings()
end

function MasterBlaster.events.PLAYER_ENTERING_WORLD()
	MasterBlaster:detectSpecialization()
	if MasterBlaster.isEnabled() then
		if (MasterBlasterDB.DebugMode) then
			MasterBlaster.DebugChat = MasterBlaster:GetDebugFrame()
			DEFAULT_CHAT_FRAME:AddMessage ("MasterBlaster ".. MasterBlaster.spec .. " module registered - Debug Mode",1,0,1)
		end
	end
end

function MasterBlaster.events.PLAYER_LOGIN()
	MasterBlaster.playerName = UnitName("player");
	MasterBlaster.spellHaste = GetCombatRatingBonus(20)
end

function MasterBlaster.events.ADDON_LOADED(addon)
	if addon ~= "MasterBlaster" then return end

	-- load defaults, if first start
	MasterBlaster:InitSettings()

	-- add slash command
	SlashCmdList["MasterBlaster"] = function(msg)
		if (msg=='debug') then
			if (MasterBlasterDB.DebugMode) then
				MasterBlaster:Debug("Debug ended", "")
			end
			MasterBlasterDB.DebugMode = not ( MasterBlasterDB.DebugMode )
			local debugStatus = "disabled"
			if (MasterBlasterDB.DebugMode) then
				MasterBlaster.DebugChat = MasterBlaster:GetDebugFrame()
				debugStatus = "enabled. Using frame: " .. MasterBlaster.DebugChat:GetID()
				MasterBlaster:Debug("Debug started", "")
			end
			DEFAULT_CHAT_FRAME:AddMessage("MasterBlaster Debug " .. debugStatus,.7,.2,.2)
		else
			InterfaceOptionsFrame_OpenToCategory(getglobal("MasterBlasterConfigPanel"))
			InterfaceOptionsFrame_OpenToCategory(getglobal("MasterBlasterConfigPanel"))
		end
	end
	SLASH_MasterBlaster1 = "/MasterBlaster"
	SLASH_MasterBlaster2 = "/MB"
	
	-- check class specializations and load any files with that name from modules folder
	MasterBlaster:detectSpecialization()
	
	-- Create GUI
	MasterBlaster:CreateGUI()
	MasterBlaster.displayFrame:SetScale(MasterBlasterDB.scale)

	-- Create config page
	MasterBlaster:CreateConfig()

	-- Register for Function Events
	MasterBlaster.eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	MasterBlaster.eventFrame:RegisterEvent("COMBAT_RATING_UPDATE") -- Monitor the all-mighty haste
	MasterBlaster.eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
	MasterBlaster.eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED") -- Left combat, clean up all enemy GUIDs
	MasterBlaster.eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED") -- Entering combat
	MasterBlaster.eventFrame:RegisterEvent("PLAYER_TALENT_UPDATE")
	MasterBlaster.eventFrame:RegisterEvent("PARTY_MEMBERS_CHANGED")
	
	-- get debug frame
	MasterBlaster.DebugChat = MasterBlaster:GetDebugFrame()
end

-- parse the combat log - the main driver of changes
function MasterBlaster.events.COMBAT_LOG_EVENT_UNFILTERED(timestamp, event, hideCaster, srcGUID, srcName, srcFlags, srcRaidFlags, dstGUID, dstName, dstFlags, dstRaidFlags, spellId, spellName, spellSchool, damage, ...)
	if MasterBlaster.isEnabled() then
		if srcName == MasterBlaster.playerName then
			MasterBlaster:DecideSpells()
			MasterBlaster.ShowUnitPower()
			if (event=="SPELL_CAST_SUCCESS") then
				MasterBlaster.lastSpell = spellName
			end
		else
			-- if unit died, remove if from friend and foe tables
			if (event=="UNIT_DIED") or (event=="UNIT_DESTROYED") then
				MasterBlaster:RemoveFromTables(dstGUID);
			end

			-- count enemies if player in combat
			if (UnitAffectingCombat("player")) then
				-- enemy count for aoe adviser
				MasterBlaster:CountPerson(timestamp, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags)
			end
		end
	end
end

function MasterBlaster.events.COMBAT_RATING_UPDATE(unit)
	if unit == "player" then
    	MasterBlaster.spellHaste = GetCombatRatingBonus(20) -- update spell haste
	end
end

function MasterBlaster.events.PLAYER_TARGET_CHANGED(...) 
	MasterBlaster.targetGUID = UnitGUID("target")
	MasterBlaster.inParty = MasterBlaster:PlayerInParty()

	if MasterBlaster:isEnabled() then
		MasterBlaster:ApplySettings()
	end

	MasterBlaster:DecideSpells()
	MasterBlaster.ShowUnitPower()
end

function MasterBlaster.events.PLAYER_REGEN_DISABLED(...)
	-- Entered combat
	MasterBlaster.inCombat = true
	MasterBlaster:Debug('Entering Combat:', "" )
end

function MasterBlaster.events.PLAYER_REGEN_ENABLED(...)
	-- left combat
	MasterBlaster.inCombat = false
	MasterBlaster:Debug('Exited Combat:', "" )
	MasterBlaster.person["friend"] = {}
	MasterBlaster.person["friendCount"] = 0
	MasterBlaster.person["foe"] = {}
	MasterBlaster.person["foeCount"] = 0
	MasterBlaster.cooldownFrame:SetReverse(false)
	MasterBlaster:PurgePersonTable()
end

-- register the module for the chosen spec
function MasterBlaster:RegisterModule(spec)
	-- save the registration of the module for each specialization file in modules folder
	MasterBlaster.modules[spec] = true;
end;

-- call a function in the selected module
function MasterBlaster:CallModule( funcName, ... )
	if (MasterBlaster.modules[MasterBlaster.spec]) and (MasterBlaster[MasterBlaster.spec]) and (MasterBlaster[MasterBlaster.spec][funcName]) then
		return MasterBlaster[MasterBlaster.spec][funcName](self,...);
	end;
	return false;
end;

-- used from inside modules, sets the list of available spells
function MasterBlaster:LoadSpells(spellList)
	local k,v;
	
	for k,v in pairs(spellList) do
		MasterBlaster.SpellList[k] = v;
	end;
end;

-- initialize stored settings
function MasterBlaster:InitSettings()
	--initalize saved variables if no value set for them 
	if not MasterBlasterDB then
		MasterBlasterDB = {} -- fresh start
	end
	if not MasterBlasterDB.x then MasterBlasterDB.x = -200 end
	if not MasterBlasterDB.y then MasterBlasterDB.y = -200 end
	if not MasterBlasterDB.relativePoint then MasterBlasterDB.relativePoint = "CENTER" end
	if not MasterBlasterDB.scale then MasterBlasterDB.scale = 1 end
	if MasterBlasterDB.locked == nil then MasterBlasterDB.locked = false end
	if MasterBlasterDB.enabled == nil then MasterBlasterDB.enabled = true end
	if MasterBlasterDB.alpha == nil then MasterBlasterDB.alpha = 0.8 end
	if MasterBlasterDB.DebugMode == nil then MasterBlasterDB.DebugMode = false end
end

-- determine if the player has a specific set bonus
function MasterBlaster:HasSetBonus(spellID,minCount)
	local slotId, _, itemId, i, setCount
	setCount = 0;
	
	if (MasterBlaster.ArmorSets[spellID]) then
		local CheckInventoryID = {
			(GetInventorySlotInfo("HeadSlot")),
			(GetInventorySlotInfo("ShoulderSlot")),
			(GetInventorySlotInfo("ChestSlot")),
			(GetInventorySlotInfo("HandsSlot")),
			(GetInventorySlotInfo("LegsSlot")),
		}
		for i=1,5,1 do
			itemId = GetInventoryItemID("player", CheckInventoryID[i]);
			if (MasterBlaster.ArmorSets[spellID][itemId]) then
				setCount = setCount + 1;
			end
		end
	end
	
	return (setCount >= minCount);
end

-- determine if a player has a specific trinket
function MasterBlaster:HasTrinket(itemID)
	return (GetInventoryItemID("player",GetInventorySlotInfo("Trinket0Slot")) == itemID) or (GetInventoryItemID("player",GetInventorySlotInfo("Trinket1Slot")) == itemID) ;
end

-- detect the currently selected spec
function MasterBlaster:detectSpecialization()
	-- get the class and specialization information for current player
	local spec = ""

	local _,playerClass = UnitClass("player")
	local activeSpec = GetSpecialization()

	-- currently only available for elemental shaman
	if playerClass == "SHAMAN" then
		if (activeSpec == 1) then
			spec = "elemental"
			MasterBlaster.enabled = true;
		elseif (activeSpec == 2) then
			spec = "enhancement"
			MasterBlaster.enabled = true; -- not ready yet
		elseif (activeSpec == 3) then
			spec = "restoration";
			MasterBlaster.enabled = false;
			return;
		end
	else
		spec = "";
		MasterBlaster.enabled = false;
		return;
	end
	
	-- check there is a registered module for the specialization and configuration information is saved in the MasterBlasterDB variables
	if (spec ~= "") and (spec ~= MasterBlaster.spec) then
		if (MasterBlaster.modules) and (MasterBlaster.modules[spec]) and (MasterBlaster[spec].Initialize) then
			MasterBlaster[spec]:Initialize(); -- call initialize section from the file being loaded
		end;
		MasterBlaster.spec = spec;
	end;
	
	-- Get talent tree
	for tier=1,7 do
		MasterBlaster.talents[tier] = 0
		for column=1,3 do
			local _,_,_,selected = GetTalentInfo(tier,column,1)
			if selected then
				MasterBlaster.talents[tier] = column
			end
		end
	end
	
	-- set a flag so calling functions know this check has been passed previously
	if (activeSpec == nil) or (spec == "") then
		MasterBlaster.specUnsure = true
	else
		MasterBlaster.specUnsure = false
	end
end

-- check to see if a player is in a party
function MasterBlaster:PlayerInParty()
	if (IsInRaid()) then
		return 2
	elseif (GetNumGroupMembers()>0) then
		return 1
	else
		return 0
	end
end

-- when a unit dies, remove them from local storage
function MasterBlaster:RemoveFromTables(guid)
	if (MasterBlaster.person["friend"][guid]) and (MasterBlaster.person["friend"][guid] ~= 0) then
		MasterBlaster.person["friend"][guid] = 0
		MasterBlaster.person["friendCount"] = MasterBlaster.person["friendCount"] - 1
	end
	if (MasterBlaster.person["foe"][guid]) and (MasterBlaster.person["foe"][guid] ~= 0) then
		MasterBlaster.person["foe"][guid] = 0
		MasterBlaster.person["foeCount"] = MasterBlaster.person["foeCount"] - 1
	end
end

-- remove all local storage, ie when out of combat
function MasterBlaster:PurgePersonTable()
	for i,v in pairs(MasterBlaster.person["foe"]) do
		if ( ( GetTime() - MasterBlaster.person["foe"][i] ) > 3) then
			-- no activity from that unit in last 2 seconds, remove it
			if ( MasterBlaster.person["foe"][i] ~= 0) then
				MasterBlaster.person["foe"][i] = 0	-- mark as inactive
				MasterBlaster.person["foeCount"] = MasterBlaster.person["foeCount"] - 1
			end
		end
	end
	for i,v in pairs(MasterBlaster.person["friend"]) do
		if ( ( GetTime() - MasterBlaster.person["friend"][i] ) > 3) then
			-- no activity from that unit in last 2 seconds, remove it
			if ( MasterBlaster.person["friend"][i] ~= 0 ) then
				MasterBlaster.person["friend"][i] = 0	-- mark as inactive
				MasterBlaster.person["friendCount"] = MasterBlaster.person["friendCount"] - 1
			end
		end
	end
	MasterBlaster.lastPersonTablePurged = GetTime()
end

-- count the number of enemies so we can suggest aoe spells if necessary
function MasterBlaster:CountPerson(time, event, sguid, sname, sflags, dguid, dname, dflags)
	local suffix = event:match(".+(_.-)$")
	if MasterBlaster.HostileFilter[suffix] then
		if (bit.band(dflags, COMBATLOG_OBJECT_REACTION_HOSTILE) == COMBATLOG_OBJECT_REACTION_HOSTILE) and (bit.band(dflags, COMBATLOG_OBJECT_AFFILIATION_OUTSIDER) == COMBATLOG_OBJECT_AFFILIATION_OUTSIDER) then
			if (not MasterBlaster.person["foe"][dguid]) then
				MasterBlaster.person["foeCount"] = MasterBlaster.person["foeCount"] + 1
			end
			MasterBlaster.person["foe"][dguid] = GetTime()
    	elseif (bit.band(sflags, COMBATLOG_OBJECT_REACTION_HOSTILE) == COMBATLOG_OBJECT_REACTION_HOSTILE) and (bit.band(sflags, COMBATLOG_OBJECT_AFFILIATION_OUTSIDER) == COMBATLOG_OBJECT_AFFILIATION_OUTSIDER) then
			if ((not MasterBlaster.person["foe"][sguid]) or (MasterBlaster.person["foe"][sguid]==0)) then
				MasterBlaster.person["foeCount"] = MasterBlaster.person["foeCount"] + 1
			end
			MasterBlaster.person["foe"][sguid] = GetTime()
		end
		if (bit.band(dflags, COMBATLOG_OBJECT_REACTION_FRIENDLY) == COMBATLOG_OBJECT_REACTION_FRIENDLY) then
			if ((not MasterBlaster.person["friend"][dguid]) or (MasterBlaster.person["friend"][dguid]==0)) then
				MasterBlaster.person["friendCount"] = MasterBlaster.person["friendCount"] + 1
			end
			MasterBlaster.person["friend"][dguid] = GetTime()
    	elseif (bit.band(sflags, COMBATLOG_OBJECT_REACTION_FRIENDLY) == COMBATLOG_OBJECT_REACTION_FRIENDLY) then
			if ((not MasterBlaster.person["friend"][sguid]) or (MasterBlaster.person["friend"][sguid]==0)) then
				MasterBlaster.person["friendCount"] = MasterBlaster.person["friendCount"] + 1
			end
			MasterBlaster.person["friend"][sguid] = GetTime()
		end
	end
	if (MasterBlaster.lastPersonTablePurged < (GetTime() - 3)) and (MasterBlaster.person["foeCount"]>0) then
		MasterBlaster:PurgePersonTable()
	end
end

-- self explanatory
function MasterBlaster:isEnabled()
	if (MasterBlaster.specUnsure) then
		MasterBlaster:detectSpecialization()
	end
	return (
		MasterBlaster.enabled and
		MasterBlasterDB.enabled
	)
end

-- check the cooldown on an item - not currently in use
function MasterBlaster:GetItemCooldownRemaining(itemID)
    local s, d, _ = GetItemCooldown(itemID)
    if (d) and (d>0) then
        d = s - GetTime() + d
    end

    return d
end

-- check the cooldown on a spell
function MasterBlaster:GetSpellCooldownRemaining(spell)
	local s, d, _ = GetSpellCooldown(spell)
	if (d) and (d>0) then
		d = s - GetTime() + d
	end

	return d
end

-- counter function
function MasterBlaster:Count(needle,...)
	local c = 0;

	for i = 1, select("#", ...) do
		if (select(i, ...) == needle) then
			c = c + 1;
		end
	end

	return c;
end

-- utility function to check if spell available, and has 0 count in list
-- that way we don't show a spell with a cooldown twice
function MasterBlaster:ZeroCount(needle,...)
	return (MasterBlaster:SpellAvailable(needle)) and (MasterBlaster:Count(needle,...)==0)
end

-- check to see if an enemy has a debuff
function MasterBlaster:hasDeBuff(unit, spellName, casterUnit)
	local i = 1;
	while true do
		local name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable = UnitDebuff(unit, i);
		if not name then
			break;
		end
		if (name) and (spellName) then
			if string.match(name, spellName) and ((unitCaster == casterUnit) or (casterUnit == nil)) then
				return name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable;
			end
		end
		i = i + 1;
	end
end

-- check to see if an enemy has a buff
function MasterBlaster:hasBuff(unit, spellName, stealableOnly, getByID)
	local i = 1;
	while true do
		local name, rank, icon, count, buffType, duration, expirationTime, source, isStealable, _, spellId = UnitBuff(unit, i);
		if not name then
			break;
		end
		if (not getByID) and (name) and (spellName) then
			if string.match(name, spellName) then
				if (not stealableOnly) or (isStealable) then
					return name, rank, icon, count, buffType, duration, expirationTime, unitCaster, isStealable;
				end
			end
		else
			if (getByID == spellId) then
				return name, rank, icon, count, buffType, duration, expirationTime, unitCaster, isStealable;
			end
		end
		i = i + 1;
	end
end

-- see if there's a totem in the totem timers
function MasterBlaster:hasTotem(unit, spellName)
	local i = 1;
	while true do
		local name, rank, icon, count, buffType, duration, expirationTime, source, isStealable = UnitBuff(unit, i);
		if not name then
			break;
		end
		if (string.match(name, spellName) or (string.match(icon, spellName))) and (expirationTime==0) then
	   		return name, rank, icon, count, buffType, duration, expirationTime, unitCaster, isStealable;
		end
		i = i + 1;
	end
end

-- determine if a spell is available
function MasterBlaster:SpellAvailable(spell)
	if (not spell) then
		return false
	end
	if (IsUsableSpell(spell)) then
		return true
	else
		return false
	end
end

-- spell adviser funtions, called in the loaded module
function MasterBlaster:NextSpell(...)
	return MasterBlaster:CallModule("NextSpell", ...);
end

function MasterBlaster:MajorSpell(...)
	return MasterBlaster:CallModule("MajorSpell", ...);
end

function MasterBlaster:IntSpell(...)
	return MasterBlaster:CallModule("IntSpell", ...);
end

function MasterBlaster:MiscSpell(...)
	return MasterBlaster:CallModule("MiscSpell", ...);
end

function MasterBlaster:AoeSpell(...)
	return MasterBlaster:CallModule("AoeSpell", ...)
end

-- empty the adviser
function MasterBlaster:EmptyFrames()
	MasterBlaster:SetTexture(MasterBlaster.textureList["next"],"")
	MasterBlaster:SetTexture(MasterBlaster.textureList["next1"],"")
	MasterBlaster:SetTexture(MasterBlaster.textureList["next2"],"")
	
	MasterBlaster:SetTexture(MasterBlaster.textureList["misc"],"")
	MasterBlaster:SetTexture(MasterBlaster.textureList["int"],"")
	MasterBlaster:SetTexture(MasterBlaster.textureList["major"],"")
	MasterBlaster:SetTexture(MasterBlaster.textureList["aoe"],"")

	MasterBlaster.textList["misc_charges"]:SetText("")
	MasterBlaster.textList["power"]:SetText("")
end

-- determine the spells to show in the adviser
function MasterBlaster:DecideSpells()
	if (not MasterBlaster.enabled) then
		return;
	end
	
	MasterBlaster.timeSinceLastUpdate = 0;
	local currentTime = GetTime()

	local guid = UnitGUID("target")
	if  (UnitName("target") == nil) or (not UnitCanAttack("player","target")) or (UnitHealth("target") == 0) then
		guid = nil
	end

	if (UnitInVehicle("player") and HasVehicleActionBar()) or ((guid == nil) or (UnitHealth("target") == 0)) then
		-- player is in a "vehicle" so don't suggest spell
		MasterBlaster:EmptyFrames()
		return
	end

	local spell = ""
	spell = MasterBlaster:NextSpell()
	if (spell) then
		local d = MasterBlaster:GetSpellCooldownRemaining(spell)
		if (d) and (d > 0) then
			local cooldownStart = currentTime - MasterBlaster.lastBaseGCD + d  -- should be less then the base gcd if we are suggesting it
			if (cooldownStart) and (MasterBlaster.lastBaseGCD) then
				MasterBlaster.cooldownFrame:SetCooldown(cooldownStart, MasterBlaster.lastBaseGCD)
			end
		end
		MasterBlaster:SetTexture(MasterBlaster.textureList["next"],GetSpellTexture(spell))

		local _,_,_,castingTime1=GetSpellInfo(spell)
		if (not castingTime1) then
			castingTime1 = 0
		else
			castingTime1 = (castingTime1 / 1000)
		end
		if (not castingTime1) or (castingTime1 < MasterBlaster.lastBaseGCD) then
			castingTime1 = MasterBlaster.lastBaseGCD
		end

		local next1 = MasterBlaster:NextSpell(castingTime1,spell)
		MasterBlaster:SetTexture(MasterBlaster.textureList["next1"],GetSpellTexture(next1))

		local _,_,_,castingTime2=GetSpellInfo(next1)
		if (not castingTime2) then
			castingTime2 = 0
		else
			castingTime2 = (castingTime2 / 1000)
		end
		if (not castingTime2) or (castingTime2 < MasterBlaster.lastBaseGCD) then
			castingTime2 = MasterBlaster.lastBaseGCD
		end

		local next2 = MasterBlaster:NextSpell(castingTime1+castingTime2,spell,next1)
		MasterBlaster:SetTexture(MasterBlaster.textureList["next2"],GetSpellTexture(next2))
	end

	local icon,charges
	spell,icon,charges = MasterBlaster:MiscSpell()
	if (icon) then
		MasterBlaster:SetTexture(MasterBlaster.textureList["misc"],icon)
	else
		if (spell) then
			MasterBlaster:SetTexture(MasterBlaster.textureList["misc"],GetSpellTexture(spell))
		end
	end
	if (charges) then
		MasterBlaster.textList["misc_charges"]:SetText(format('%.0f', charges))
	else
		MasterBlaster.textList["misc_charges"]:SetText("")
	end

	spell = MasterBlaster:IntSpell()
	MasterBlaster:SetTexture(MasterBlaster.textureList["int"],GetSpellTexture(spell))

	spell = MasterBlaster:MajorSpell()
	MasterBlaster:SetTexture(MasterBlaster.textureList["major"],GetSpellTexture(spell))

	spell = MasterBlaster:AoeSpell()
	MasterBlaster:SetTexture(MasterBlaster.textureList["aoe"],GetSpellTexture(spell))
end

-- show the current power(maelstrom, fury, etc) as a % of maximum
function MasterBlaster:ShowUnitPower(...)
	local guid = UnitGUID("target")
	if  (UnitName("target") == nil) or (not UnitCanAttack("player","target")) or (UnitHealth("target") == 0) then
		guid = nil
	end

	if (UnitInVehicle("player") and HasVehicleActionBar()) or UnitOnTaxi("player") or ((guid == nil) or (UnitHealth("target") == 0)) then
		-- player is in a "vehicle" or has no target
		MasterBlaster.textList["power"]:SetText("")
		return
	end

	local powerTypeIndex = UnitPowerType("player")
	if not powerTypeIndex then return end

	-- get the unit power per element (for example per burning ember)
	local currentPower = UnitPower("player", powerTypeIndex)
	local maxPower = UnitPowerMax("player", powerTypeIndex)

	-- show as a percentage
	if ((maxPower == nil) and (currentPower == nil)) then
		MasterBlaster.textList["power"]:SetText("")
	else
		local powerPercent = (currentPower/maxPower) * 100
		local displayText = ""
		if (powerPercent < 80) then
			displayText = format("%.f",powerPercent) .. " %"
		else
			displayText = "|cffff0000" .. format("%.f",powerPercent) .. " %|r"
		end
		MasterBlaster.textList["power"]:SetText(displayText)
	end
end

-- update function to refresh our frames
function MasterBlaster:OnUpdate(elapsed)
	if (MasterBlaster:isEnabled()) then
		MasterBlaster.timeSinceLastUpdate = MasterBlaster.timeSinceLastUpdate + elapsed 
		
		if (MasterBlaster.timeSinceLastUpdate > (1.5 - (1.5 * MasterBlaster.spellHaste * .01)) * 0.3) then
			MasterBlaster:DecideSpells()
			MasterBlaster.ShowUnitPower()
		end
	end
end
