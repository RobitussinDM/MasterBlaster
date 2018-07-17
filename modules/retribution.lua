local L = MasterBlaster.Locals;

MasterBlaster:RegisterModule("retribution");

MasterBlaster.retribution = {
	Initialize = function(self)
		-- spells available to the blood death knight spec
		MasterBlaster:LoadSpells({
            ["Auto Attack"] = GetSpellInfo(6603),
            ["Avenging Wrath"] = GetSpellInfo(31884),
            ["Blade of Justice"] = GetSpellInfo(184575),
            ["Crusade"] = GetSpellInfo(231895),
            ["Crusader Strike"] = GetSpellInfo(35395),
            ["Divine Storm"] = GetSpellInfo(53385),
            ["Judgement"] = GetSpellInfo(20271),
            ["Justicar's Vengeance"] = GetSpellInfo(215661),
            ["Rebuke"] = GetSpellInfo(96231),
            ["Templar's Verdict"] = GetSpellInfo(85256),
            ["Wake of Ashes"] = GetSpellInfo(205273)
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

			-- no spell in cast, check global cd via Auto Attack
			if (MasterBlaster.SpellList["Auto Attack"]) then
				local globalCooldown = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Auto Attack"])
				if (globalCooldown) then
					timeshift = timeshift + MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Auto Attack"])
				else
					timeshift = timeshift + MasterBlaster.lastBaseGCD
				end
			else
				timeshift = timeshift + MasterBlaster.lastBaseGCD
			end
        end

		-- check if in melee range
        local meleeRange = (IsSpellInRange(MasterBlaster.SpellList["Templar's Verdict"], "target") == 1)
        
        -- get unit power variables
        local currentHolyPower = UnitPower("player", 9)
        
        -- get crusader strike charges
        local crusaderStrikeCharges = GetSpellCharges(MasterBlaster.SpellList["Crusader Strike"]);

        -- judgement if available
        if (MasterBlaster:ZeroCount(MasterBlaster.SpellList["Judgement"],spellInCast,nextSpell1,nextSpell2)) then
            d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Judgement"])
            if ((d - timeshift) <= 0.5) then
                return MasterBlaster.SpellList["Judgement"], meleeRange
            end
        end

        -- templar's verdict if we have 5 holy power
        if (currentHolyPower == 5) then
            if (MasterBlaster:ZeroCount(MasterBlaster.SpellList["Templar's Verdict"],spellInCast,nextSpell1,nextSpell2)) then
                d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Templar's Verdict"])
                if ((d - timeshift) <= 0.5) then
                    return MasterBlaster.SpellList["Templar's Verdict"], meleeRange
                end
            end
        end

        -- wake of ashes if available
        if (MasterBlaster:ZeroCount(MasterBlaster.SpellList["Wake of Ashes"],spellInCast,nextSpell1,nextSpell2)) then
            d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Wake of Ashes"])
            if ((d - timeshift) <= 0.5) then
                return MasterBlaster.SpellList["Wake of Ashes"], meleeRange
            end
        end

        -- crusader strike if we have full charges on it
        if (crusaderStrikeCharges == 2) then
            if (MasterBlaster:ZeroCount(MasterBlaster.SpellList["Crusader Strike"],spellInCast,nextSpell1,nextSpell2)) then
                d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Crusader Strike"])
                if ((d - timeshift) <= 0.5) then
                    return MasterBlaster.SpellList["Crusader Strike"], meleeRange
                end
            end
        end

        -- templar's verdict if we have 4 holy power
        if (currentHolyPower >= 4) then
            if (MasterBlaster:ZeroCount(MasterBlaster.SpellList["Templar's Verdict"],spellInCast,nextSpell1,nextSpell2)) then
                d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Templar's Verdict"])
                if ((d - timeshift) <= 0.5) then
                    return MasterBlaster.SpellList["Templar's Verdict"], meleeRange
                end
            end
        end

        -- blade of justice if available
        if (MasterBlaster:ZeroCount(MasterBlaster.SpellList["Blade of Justice"],spellInCast,nextSpell1,nextSpell2)) then
            d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Blade of Justice"])
            if ((d - timeshift) <= 0.5) then
                return MasterBlaster.SpellList["Blade of Justice"], meleeRange
            end
        end

        -- crusader strike if we have any charges left
        if (crusaderStrikeCharges > 0) then
            if (MasterBlaster:ZeroCount(MasterBlaster.SpellList["Crusader Strike"],spellInCast,nextSpell1,nextSpell2)) then
                d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Crusader Strike"])
                if ((d - timeshift) <= 0.5) then
                    return MasterBlaster.SpellList["Crusader Strike"], meleeRange
                end
            end
        end

		-- if we made it this far and found nothing to cast, rip
		return "", meleeRange
	end;

	MiscSpell = function(self)
		-- no particular category
		local d
        
		return ""
	end;

	IntSpell = function(self)
		-- interruptions
		local d

		if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Rebuke"]) then
			d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Rebuke"])
			if ((IsSpellInRange(MasterBlaster.SpellList["Rebuke"], "target") == 1) and (d) and (d < 0.5)) then
				--- rebuke to interupt channel spell
				_, _, _, _, _, _, _, notInterruptible = UnitChannelInfo("target")
				if (notInterruptible == false) then
					return MasterBlaster.SpellList["Rebuke"]
				end

				--- rebuke to interupt cast spell
				_, _, _, _, _, _, _, _, notInterruptible = UnitCastingInfo("target")
				if (notInterruptible == false)  then
					return MasterBlaster.SpellList["Rebuke"]
				end
			end
		end

		return ""
	end;

	MajorSpell = function(self)
		-- major dps cooldowns
        local d, name
        
        -- crusade if talented
        if MasterBlaster.talents[7] == 2 then
            if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Crusade"]) then
                d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Crusade"])
                if d <= MasterBlaster.lastBaseGCD then
                    return MasterBlaster.SpellList["Crusade"]
                end
            end
        end

		-- avenging wrath
		if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Avenging Wrath"]) then
			d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Avenging Wrath"])
			if d <= MasterBlaster.lastBaseGCD then
				return MasterBlaster.SpellList["Avenging Wrath"]
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

			-- divine storm if available
			if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Divine Storm"]) then
				d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Divine Storm"])
				if d <= MasterBlaster.lastBaseGCD then
					return MasterBlaster.SpellList["Divine Storm"]
				end
			end
		end

		return ""
	end;
};
