local L = MasterBlaster.Locals;

MasterBlaster:RegisterModule("beast_mastery");

MasterBlaster.beast_mastery = {
	Initialize = function(self)
		-- spells available to the frost mage spec
		MasterBlaster:LoadSpells({
			["A Murder of Crows"] = GetSpellInfo(131894),
			["Aspect of the Wild"] = GetSpellInfo(193530),
			["Bestial Wrath"] = GetSpellInfo(19574),
			["Call Pet"] = GetSpellInfo(883),
            ["Cobra Shot"] = GetSpellInfo(193455),
			["Counter Shot"] = GetSpellInfo(147362),
			["Dire Beast"] = GetSpellInfo(120769),
			["Dire Beast Buff"] = GetSpellInfo(120694),
			["Dire Frenzy"] = GetSpellInfo(217200),
			["Dire Frenzy Buff"] = GetSpellInfo(246152),
			["Eagle Eye"] = GetSpellInfo(6197),
            ["Kill Command"] = GetSpellInfo(34026),
            ["Multi-Shot"] = GetSpellInfo(2643),
            ["Titan's Thunder"] = GetSpellInfo(207097)
		});
	end;

	-- determine the next spell to display
	NextSpell = function(self,timeshift,nextSpell1,nextSpell2)
		local currentTime = GetTime()
		local d

		-- if target is dead, return
		if (UnitHealth("target") <= 0) then
			return ""
		end

		-- get current spell and target information
		local spellInCast, _, _, _, spellInCastStartTime, spellInCastEndTime = UnitCastingInfo("player")

		--  set the global cool down
		MasterBlaster.lastBaseGCD = 1.5 - (1.5 * MasterBlaster.spellHaste * .01)
		
		-- timeshift is used for spells further in the adviser's future
		-- it should be the cast time of the currently suggested spell + a gcd
		if (not timeshift) then
			timeshift = 0
		end

		-- adjust current spell to deal with gcd and delay
		if (spellInCast) then
			if ((spellInCastEndTime - spellInCastStartTime) / 1000 ) < MasterBlaster.lastBaseGCD then
				spellInCastEndTime = spellInCastStartTime + (MasterBlaster.lastBaseGCD * 1000)
			end
			MasterBlaster.lastCastTime = spellInCastEndTime;
			timeshift = timeshift + (spellInCastEndTime / 1000) - currentTime
		else
			-- to prevent tick in current spell, check if last one finished in short time
			if (MasterBlaster.lastCastTime) and ((MasterBlaster.lastCastTime / 1000) + MasterBlaster.lastBaseGCD >= currentTime) then
				spellInCast = MasterBlaster.lastSpell
			end

			-- no spell in cast, check global cd via eagle eye
			if (MasterBlaster.SpellList["Eagle Eye"]) then
				local globalCooldown = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Eagle Eye"])
				if (globalCooldown) then
					timeshift = timeshift + MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Eagle Eye"])
				else
					timeshift = timeshift + MasterBlaster.lastBaseGCD
				end
			else
				timeshift = timeshift + MasterBlaster.lastBaseGCD
			end
		end

		-- get player's dire beast / dire frenzy buff information
		local direBeastBuff, _, _, _, _, _, direBeastExpires = MasterBlaster:hasBuff("player",MasterBlaster.SpellList["Dire Beast Buff"]);
		if (direBeastBuff == nil) then
			direBeastExpires = 0
		end

		local direFrenzyBuff, _, _, _, _, _, direFrenzyExpires = MasterBlaster:hasBuff("player",MasterBlaster.SpellList["Dire Frenzy Buff"]);
		if (direFrenzyBuff == nil) then
			direFrenzyExpires = 0
		end

		-- get unit power variables
		local currentFocus = UnitPower("player", 2)
		local maximumFocus = UnitPowerMax("player", 2)

		-- summon a pet if we don't have one out
		if (not MasterBlaster:hasPet()) then
			if (MasterBlaster:ZeroCount(MasterBlaster.SpellList["Call Pet"],spellInCast,nextSpell1,nextSpell2)) then
				d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Call Pet"])
				if ((d - timeshift) <= 0.5) then
					return MasterBlaster.SpellList["Call Pet"]
				end
			end
		end

		-- bestial wrath
		if (MasterBlaster:ZeroCount(MasterBlaster.SpellList["Bestial Wrath"],spellInCast,nextSpell1,nextSpell2)) then
			d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Bestial Wrath"])
			if ((d - timeshift) <= 0.5) then
				return MasterBlaster.SpellList["Bestial Wrath"]
			end
		end

		-- kill command
		if (MasterBlaster:ZeroCount(MasterBlaster.SpellList["Kill Command"],spellInCast,nextSpell1,nextSpell2)) then
			d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Kill Command"])
			if ((d - timeshift) <= 0.5) then
				return MasterBlaster.SpellList["Kill Command"]
			end
		end

		-- dire frenzy / dire beast
        if MasterBlaster.talents[2] == 2 then
            if (direFrenzyBuff == nil) and (MasterBlaster:ZeroCount(MasterBlaster.SpellList["Dire Frenzy"],spellInCast,nextSpell1,nextSpell2)) then
                d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Dire Frenzy"])
                if ((d - timeshift) <= 0.5) then
                    return MasterBlaster.SpellList["Dire Frenzy"]
                end
			end
		else
			if (direBeastBuff == nil) and (MasterBlaster:ZeroCount(MasterBlaster.SpellList["Dire Beast"],spellInCast,nextSpell1,nextSpell2)) then
                d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Dire Beast"])
                if ((d - timeshift) <= 0.5) then
                    return MasterBlaster.SpellList["Dire Beast"]
                end
			end
		end
		
		-- cobra shot if we have > 90 focus
		local totalCobraShotsInQueue = MasterBlaster:Count(MasterBlaster.SpellList["Cobra Shot"],spellInCast,nextSpell1,nextSpell2)
		if (currentFocus >= 90) and (currentFocus > (totalCobraShotsInQueue * 40)) then
			d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Cobra Shot"])
			if ((d - timeshift) <= 0.5) then
				return MasterBlaster.SpellList["Cobra Shot"], meleeRange
			end
		end

		return ""
	end;

	MiscSpell = function(self)
		-- no particular category

		return ""
	end;

	IntSpell = function(self)
		-- interruptions
		local d

		if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Counter Shot"]) then
			d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Counter Shot"])
			if ((IsSpellInRange(MasterBlaster.SpellList["Counter Shot"], "target") == 1) and (d) and (d < 0.5)) then
				--- counter shot to interupt channel spell
				_, _, _, _, _, _, _, notInterruptible = UnitChannelInfo("target")
				if (notInterruptible == false) then
					return MasterBlaster.SpellList["Counter Shot"]
				end

				--- counter shot to interupt cast spell
				_, _, _, _, _, _, _, _, notInterruptible = UnitCastingInfo("target")
				if (notInterruptible == false)  then
					return MasterBlaster.SpellList["Counter Shot"]
				end
			end
		end

		return ""
	end;

	MajorSpell = function(self)
		-- major dps cooldowns
		local d, name
		
		-- a murder of crows
		if MasterBlaster.talents[6] == 1 then
			if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["A Murder of Crows"]) then
				d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["A Murder of Crows"])
				if d <= MasterBlaster.lastBaseGCD then
					return MasterBlaster.SpellList["A Murder of Crows"]
				end
			end
		end

        -- titan's thunder
		if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Titan's Thunder"]) then
			d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Titan's Thunder"])
			if d <= MasterBlaster.lastBaseGCD then
				return MasterBlaster.SpellList["Titan's Thunder"]
			end
		end

		-- aspect of the wild
		if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Aspect of the Wild"]) then
			d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Aspect of the Wild"])
			if d <= MasterBlaster.lastBaseGCD then
				return MasterBlaster.SpellList["Aspect of the Wild"]
			end
		end
	
		-- berserking
		if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Berserking"]) then
			d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Berserking"])
			if d <= MasterBlaster.lastBaseGCD then
				return MasterBlaster.SpellList["Berserking"]
			end
		end
	
		-- blood fury
		if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Blood Fury"]) then
			d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Blood Fury"])
			if d <= MasterBlaster.lastBaseGCD then
				return MasterBlaster.SpellList["Blood Fury"]
			end
		end

		return ""
	end;

	AoeSpell = function(self)
		-- aoe on target
		local d

		if (MasterBlaster.person["foeCount"] > 1) then

			-- multi-shot
			if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Multi-Shot"]) then
				d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Multi-Shot"])
				if d <= MasterBlaster.lastBaseGCD then
					return MasterBlaster.SpellList["Multi-Shot"]
				end
			end
		end

		return ""
	end;
};