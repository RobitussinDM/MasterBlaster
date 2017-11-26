local L = MasterBlaster.Locals;

MasterBlaster:RegisterModule("protection_pal");

MasterBlaster.protection_pal = {
	Initialize = function(self)
		-- spells available to the blood death knight spec
		MasterBlaster:LoadSpells({
            ["Auto Attack"] = GetSpellInfo(6603),
            ["Avenger's Shield"] = GetSpellInfo(31935),
            ["Avenging Wrath"] = GetSpellInfo(31884),
            ["Blessed Hammer"] = GetSpellInfo(204019),
            ["Consecration"] = GetSpellInfo(26573),
            ["Consecration Buff"] = GetSpellInfo(188370),
            ["Hammer of the Righteous"] = GetSpellInfo(53595),
            ["Judgement"] = GetSpellInfo(20271),
            ["Rebuke"] = GetSpellInfo(96231),
            ["Shield of the Righteous"] = GetSpellInfo(53600),
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
        
        -- get player's consecration buff information
		local consecrationBuff = MasterBlaster:hasBuff("player",MasterBlaster.SpellList["Consecration Buff"]);

		-- check if in melee range
		local meleeRange = (IsSpellInRange(MasterBlaster.SpellList["Shield of the Righteous"], "target") == 1)

        -- use consecration if we aren't standing in one
        if (consecrationBuff == nil) then
            if (MasterBlaster:ZeroCount(MasterBlaster.SpellList["Consecration"],spellInCast,nextSpell1,nextSpell2)) then
                d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Consecration"])
                if ((d - timeshift) <= 0.5) then
                    return MasterBlaster.SpellList["Consecration"], meleeRange
                end
            end
        end

        -- judgement if available
        if (MasterBlaster:ZeroCount(MasterBlaster.SpellList["Judgement"],spellInCast,nextSpell1,nextSpell2)) then
            d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Judgement"])
            if ((d - timeshift) <= 0.5) then
                return MasterBlaster.SpellList["Judgement"], meleeRange
            end
        end

        -- avenger's shield if available
		if (MasterBlaster:ZeroCount(MasterBlaster.SpellList["Avenger's Shield"],spellInCast,nextSpell1,nextSpell2)) then
            d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Avenger's Shield"])
            if ((d - timeshift) <= 0.5) then
                return MasterBlaster.SpellList["Avenger's Shield"], meleeRange
            end
        end

        -- blessed hammer if talented, hammer of the righteous if not
        if (MasterBlaster.talents[1] == 2) then
            if (MasterBlaster:ZeroCount(MasterBlaster.SpellList["Blessed Hammer"],spellInCast,nextSpell1,nextSpell2)) then
                d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Blessed Hammer"])
                if ((d - timeshift) <= 0.5) then
                    return MasterBlaster.SpellList["Blessed Hammer"], meleeRange
                end
            end
        else
            if (MasterBlaster:ZeroCount(MasterBlaster.SpellList["Hammer of the Righteous"],spellInCast,nextSpell1,nextSpell2)) then
                d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Hammer of the Righteous"])
                if ((d - timeshift) <= 0.5) then
                    return MasterBlaster.SpellList["Hammer of the Righteous"], meleeRange
                end
            end
        end

		-- if we made it this far and found nothing to cast, rip
		return "", meleeRange
	end;

	MiscSpell = function(self)
		-- no particular category
		local d

        -- show shield of the righteous charges
		local shieldOfTheRighteousCharges = GetSpellCharges(MasterBlaster.SpellList["Shield of the Righteous"]);
        local _, _, icon = GetSpellInfo(53600);
        if (shieldOfTheRighteousCharges > 0) then
            if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Shield of the Righteous"]) then
                return MasterBlaster.SpellList["Shield of the Righteous"], icon, shieldOfTheRighteousCharges
            end
        end
        
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

			-- avenger's shield if available
			if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Avenger's Shield"]) then
				d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Avenger's Shield"])
				if d <= MasterBlaster.lastBaseGCD then
					return MasterBlaster.SpellList["Avenger's Shield"]
				end
			end
		end

		return ""
	end;
};
