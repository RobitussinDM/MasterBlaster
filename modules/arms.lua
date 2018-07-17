local L = MasterBlaster.Locals;

MasterBlaster:RegisterModule("arms");

MasterBlaster.arms = {
	Initialize = function(self)
		-- spells available to the fury spec
		MasterBlaster:LoadSpells({
            ["Auto Attack"] = GetSpellInfo(6603),
            ["Battle Cry"] = GetSpellInfo(1719),
            ["Bladestorm"] = GetSpellInfo(227847),
            ["Cleave"] = GetSpellInfo(845),
            ["Cleave Buff"] = GetSpellInfo(188923),
            ["Colossus Smash"] = GetSpellInfo(167105),
            ["Execute"] = GetSpellInfo(5308),
            ["Mortal Strike"] = GetSpellInfo(12294),
            ["Pummel"] = GetSpellInfo(6552),
            ["Shattered Defenses Buff"] = GetSpellInfo(248625),
            ["Slam"] = GetSpellInfo(1464),
            ["Victory Rush"] = GetSpellInfo(34428),
            ["Warbreaker"] = GetSpellInfo(209577),
            ["Whirlwind"] = GetSpellInfo(1680)
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
        
        -- get player's shattered defenses buff information
		local shatteredDefensesBuff, _, _, _, _, _, shatteredDefensesExpires = MasterBlaster:hasBuff("player",MasterBlaster.SpellList["Shattered Defenses Buff"]);
		if (shatteredDefensesBuff == nil) then
			shatteredDefensesExpires = 0
        end

		-- check if in melee range
		local meleeRange = (IsSpellInRange(MasterBlaster.SpellList["Slam"], "target") == 1)

		-- get unit power variables
        local currentRage = UnitPower("player", 1)
        
        -- get target's current and max health to check for execute range
        local targetCurrentHealth = UnitHealth("target");
        local targetMaxHealth = UnitHealthMax("target");
        local targetHealthPercent = (targetCurrentHealth / targetMaxHealth) * 100;

        -- colossus smash / warbreaker if no shattered defenses buff
        if (not shatteredDefensesBuff) then
            if MasterBlaster:ZeroCount(MasterBlaster.SpellList["Colossus Smash"],spellInCast,nextSpell1,nextSpell2) then
                d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Colossus Smash"])
                if ((d - timeshift) <= 0.5) then
                    return MasterBlaster.SpellList["Colossus Smash"], meleeRange
                end
            end
            
            if MasterBlaster:ZeroCount(MasterBlaster.SpellList["Warbreaker"],spellInCast,nextSpell1,nextSpell2) then
                d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Warbreaker"])
                if ((d - timeshift) <= 0.5) then
                    return MasterBlaster.SpellList["Warbreaker"], meleeRange
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

        -- mortal strike if available
        if MasterBlaster:ZeroCount(MasterBlaster.SpellList["Mortal Strike"],spellInCast,nextSpell1,nextSpell2) then
            d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Mortal Strike"])
            if ((d - timeshift) <= 0.5) then
                return MasterBlaster.SpellList["Mortal Strike"], meleeRange
            end
        end

		-- whirlwind if available
        if MasterBlaster:ZeroCount(MasterBlaster.SpellList["Whirlwind"],spellInCast,nextSpell1,nextSpell2) then
            d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Whirlwind"])
            if ((d - timeshift) <= 0.5) then
                return MasterBlaster.SpellList["Whirlwind"], meleeRange
            end
        end
        
        -- if we made it this far and found nothing to cast, rip
		return "", meleeRange
	end;

	MiscSpell = function(self)
		-- no particular category
		local d

        -- show shattered defenses info
        name, _, icon, _, _, _, expires = MasterBlaster:hasBuff("player",MasterBlaster.SpellList["Shattered Defenses Buff"])
		if (name ~= nil) then
			if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Shattered Defenses"]) then
				return MasterBlaster.SpellList["Shattered Defenses"], icon, expires
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

		-- blade storm
		if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Blade Storm"]) then
			d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Blade Storm"])
			if d <= MasterBlaster.lastBaseGCD then
				return MasterBlaster.SpellList["Blade Storm"]
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
