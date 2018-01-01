local L = MasterBlaster.Locals;

MasterBlaster:RegisterModule("fury");

MasterBlaster.fury = {
	Initialize = function(self)
		-- spells available to the fury spec
		MasterBlaster:LoadSpells({
            ["Auto Attack"] = GetSpellInfo(6603),
            ["Battle Cry"] = GetSpellInfo(1719),
            ["Bloodthirst"] = GetSpellInfo(23881),
            ["Enrage Buff"] = GetSpellInfo(184362),
            ["Execute"] = GetSpellInfo(5308),
            ["Furious Slash"] = GetSpellInfo(100130),
            ["Odyn's Fury"] = GetSpellInfo(205545),
            ["Pummel"] = GetSpellInfo(6552),
            ["Raging Blow"] = GetSpellInfo(85288),
            ["Rampage"] = GetSpellInfo(184367),
            ["Whirlwind"] = GetSpellInfo(190411),
            ["Wrecking Ball Buff"] = GetSpellInfo(215569)
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

		-- get player's enrage buff information
		local enrageBuff, _, _, _, _, _, enrageExpires = MasterBlaster:hasBuff("player",MasterBlaster.SpellList["Enrage"]);
		if (enrageBuff == nil) then
			enrageExpires = 0
        end

		-- check if in melee range
		local meleeRange = (IsSpellInRange(MasterBlaster.SpellList["Furious Slash"], "target") == 1)

		-- get unit power variables
        local currentRage = UnitPower("player", 1)
        
        -- get target's current and max health to check for execute range
        local targetCurrentHealth = UnitHealth("target");
        local targetMaxHealth = UnitHealthMax("target");
        local targetHealthPercent = (targetCurrentHealth / targetMaxHealth) * 100;

        -- rampage at 100 rage and if the target is above execute range
        if (currentRage == 100) and (targetHealthPercent > 20) then
            if MasterBlaster:ZeroCount(MasterBlaster.SpellList["Rampage"],spellInCast,nextSpell1,nextSpell2) then
                d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Rampage"])
                if ((d - timeshift) <= 0.5) then
                    return MasterBlaster.SpellList["Rampage"], meleeRange
                end
			end
        end

        -- bloodthirst if not currently enraged
        if (not enrageBuff) then
            if MasterBlaster:ZeroCount(MasterBlaster.SpellList["Bloodthirst"],spellInCast,nextSpell1,nextSpell2) then
                d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Bloodthirst"])
                if ((d - timeshift) <= 0.5) then
                    return MasterBlaster.SpellList["Bloodthirst"], meleeRange
                end
			end
        end

        -- execute if available
        if (targetHealthPercent < 20) and (currentRage > 25) then
            if MasterBlaster:ZeroCount(MasterBlaster.SpellList["Execute"],spellInCast,nextSpell1,nextSpell2) then
                d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Execute"])
                if ((d - timeshift) <= 0.5) then
                    return MasterBlaster.SpellList["Execute"], meleeRange
                end
			end
        end

        -- raging blow if available
        if (enrageBuff) then
            if MasterBlaster:ZeroCount(MasterBlaster.SpellList["Raging Blow"],spellInCast,nextSpell1,nextSpell2) then
                d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Raging Blow"])
                if ((d - timeshift) <= 0.5) then
                    return MasterBlaster.SpellList["Raging Blow"], meleeRange
                end
			end
        end

        -- bloodthirst even if enraged and available
        if MasterBlaster:ZeroCount(MasterBlaster.SpellList["Bloodthirst"],spellInCast,nextSpell1,nextSpell2) then
            d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Bloodthirst"])
            if ((d - timeshift) <= 0.5) then
                return MasterBlaster.SpellList["Bloodthirst"], meleeRange
            end
        end

		-- furious slash when available
        if MasterBlaster:ZeroCount(MasterBlaster.SpellList["Furious Slash"],spellInCast,nextSpell1,nextSpell2) then
            d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Furious Slash"])
            if ((d - timeshift) <= 0.5) then
                return MasterBlaster.SpellList["Furious Slash"], meleeRange
            end
        end

        -- if we made it this far and found nothing to cast, rip
		return "", meleeRange
	end;

	MiscSpell = function(self)
		-- no particular category
		local d

        -- whirlwind if wrecking ball is active
        name, _, icon = MasterBlaster:hasBuff("player",MasterBlaster.SpellList["Wrecking Ball Buff"])
		if (name ~= nil) then
			if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Whirlwind"]) then
				return MasterBlaster.SpellList["Whirlwind"], icon
			end
		end

		return ""
	end;

	IntSpell = function(self)
		-- interruptions
		local d

		if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Pummel"]) then
			d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Pummel"])
			if ((IsSpellInRange(MasterBlaster.SpellList["Pummel"], "target") == 1) and (d) and (d < 0.5)) then
				--- pummel to interupt channel spell
				_, _, _, _, _, _, _, notInterruptible = UnitChannelInfo("target")
				if (notInterruptible == false) then
					return MasterBlaster.SpellList["Pummel"]
				end

				--- pummel to interupt cast spell
				_, _, _, _, _, _, _, _, notInterruptible = UnitCastingInfo("target")
				if (notInterruptible == false)  then
					return MasterBlaster.SpellList["PummelKick"]
				end
			end
		end

		return ""
	end;

	MajorSpell = function(self)
		-- major dps cooldowns
		local d, name

        -- battle cry
        if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Battle Cry"]) then
			d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Battle Cry"])
			if d <= MasterBlaster.lastBaseGCD then
				return MasterBlaster.SpellList["Battle Cry"]
			end
		end

		-- odyn's fury
		if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Odyn's Fury"]) then
			d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Odyn's Fury"])
			if d <= MasterBlaster.lastBaseGCD then
				return MasterBlaster.SpellList["Odyn's Fury"]
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
			-- whirlwind if available
			if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Whirlwind"]) then
				d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Whirlwind"])
				if d <= MasterBlaster.lastBaseGCD then
					return MasterBlaster.SpellList["Whirlwind"]
				end
			end
		end

		return ""
	end;
};
