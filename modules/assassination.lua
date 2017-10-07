local L = MasterBlaster.Locals;

MasterBlaster:RegisterModule("assassination");

MasterBlaster.assassination = {
	Initialize = function(self)
		-- spells available to the assassination spec
		MasterBlaster:LoadSpells({
            ["Deadly Poison"] = GetSpellInfo(2823),
            ["Detection"] = GetSpellInfo(56814),
            ["Envenom"] = GetSpellInfo(32645),
            ["Fan of Knives"] = GetSpellInfo(51723),
            ["Garrote"] = GetSpellInfo(703),
            ["Kick"] = GetSpellInfo(1766),
            ["Kingsbane"] = GetSpellInfo(192759),
            ["Leeching Poison"] = GetSpellInfo(108211),
            ["Marked for Death"] = GetSpellInfo(137619),
            ["Mutilate"] = GetSpellInfo(1329),
            ["Poisoned Knife"] = GetSpellInfo(185565),
            ["Rupture"] = GetSpellInfo(1943),
            ["Vendetta"] = GetSpellInfo(79140)
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

			-- no spell in cast, check global cd via Detection (no cooldown, no energy cost)
			if (MasterBlaster.SpellList["Detection"]) then
				local globalCooldown = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Detection"])
				if (globalCooldown) then
					timeshift = timeshift + MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Detection"])
				else
					timeshift = timeshift + MasterBlaster.lastBaseGCD
				end
			else
				timeshift = timeshift + MasterBlaster.lastBaseGCD
			end
		end

		-- get player's poison buff information
		local deadlyPoisonBuff, _, _, _, _, _, deadlyPoisonExpires = MasterBlaster:hasBuff("player",MasterBlaster.SpellList["Deadly Poison"]);
		if (deadlyPoisonBuff == nil) then
			deadlyPoisonExpires = 0
		end

        local leechingPoisonBuff, _, _, _, _, _, leechingPoisonExpires = MasterBlaster:hasBuff("player",MasterBlaster.SpellList["Leeching Poison"]);
        if (leechingPoisonBuff == nil) then
            leechingPoisonExpires = 0
        end

		-- check if in melee range
		local meleeRange = (IsSpellInRange(MasterBlaster.SpellList["Mutilate"], "target") == 1)

        -- get target's garrote and rupture debuff information
		local garroteDebuff, _, _, _, _, garroteDuration, garroteExpiration, unitCaster = MasterBlaster:hasDeBuff("target", MasterBlaster.SpellList["Garrote"], "player");
		if (not garroteExpiration) then
			garroteExpiration = 0
			garroteDuration = 0
		end

        local ruptureDebuff, _, _, _, _, ruptureDuration, ruptureExpiration, unitCaster = MasterBlaster:hasDeBuff("target", MasterBlaster.SpellList["Rupture"], "player");
		if (not ruptureExpiration) then
			ruptureExpiration = 0
			ruptureDuration = 0
		end

		-- get unit power variables
		local currentComboPoints = UnitPower("player", 4)
		local currentEnergy = UnitPower("player", 3)

        -- keep those knives poisoned
        if (MasterBlaster:ZeroCount(MasterBlaster.SpellList["Deadly Poison"],spellInCast,nextSpell1,nextSpell2)) then
            if (not deadlyPoisonBuff) or (deadlyPoisonExpires - currentTime - timeshift <= 0.5) then
                d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Deadly Poison"])
                if ((d - timeshift) <= 0.5) then
                    return MasterBlaster.SpellList["Deadly Poison"], true
                end
            end
        end

        -- keep leeching poison up if talented
        if MasterBlaster.talents[4] == 1 then
			if (MasterBlaster:ZeroCount(MasterBlaster.SpellList["Leeching Poison"],spellInCast,nextSpell1,nextSpell2)) then
                if (not leechingPoisonBuff) or (leechingPoisonExpires - currentTime - timeshift <= 0.5) then
                    d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Leeching Poison"])
                    if ((d - timeshift) <= 0.5) then
                        return MasterBlaster.SpellList["Leeching Poison"], true
                    end
                end
            end
		end

        -- garrote if garrote isn't up or has less than 6 seconds left
		if (garroteDuration == 0) or ((garroteExpiration - currentTime - timeshift) < 6) then
			if MasterBlaster:ZeroCount(MasterBlaster.SpellList["Garrote"],spellInCast,nextSpell1,nextSpell2) then
                d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Garrote"])
                if ((d - timeshift) <= 0.5) then
                    return MasterBlaster.SpellList["Garrote"], meleeRange
                end
			end
		end

        -- mutilate if we have less than 4 combo points
        if (currentComboPoints <= 4) and (currentEnergy > 55) then
            if MasterBlaster:ZeroCount(MasterBlaster.SpellList["Mutilate"],spellInCast,nextSpell1,nextSpell2) then
                d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Mutilate"])
                if ((d - timeshift) <= 0.5) then
                    return MasterBlaster.SpellList["Mutilate"], meleeRange
                end
			end
        end

        -- rupture with 5 or more combo points if rupture has 8 seconds or less remaining
        if (currentComboPoints >= 5) and ((ruptureExpiration - currentTime - timeshift) < 8) then
			if MasterBlaster:ZeroCount(MasterBlaster.SpellList["Rupture"],spellInCast,nextSpell1,nextSpell2) then
                d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Rupture"])
                if ((d - timeshift) <= 0.5) then
                    return MasterBlaster.SpellList["Rupture"], meleeRange
                end
			end
		end

        -- envenom with 4 or more combo points (but only if rupture is up)
        if (currentComboPoints >= 4) and ((ruptureExpiration - currentTime - timeshift) > 8) then
            if MasterBlaster:ZeroCount(MasterBlaster.SpellList["Envenom"],spellInCast,nextSpell1,nextSpell2) then
                d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Envenom"])
                if ((d - timeshift) <= 0.5) then
                    return MasterBlaster.SpellList["Envenom"], meleeRange
                end
			end
        end

        -- kingsbane when available
        if MasterBlaster:ZeroCount(MasterBlaster.SpellList["Kingsbane"],spellInCast,nextSpell1,nextSpell2) then
            d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Kingsbane"])
            if ((d - timeshift) <= 0.5) then
                return MasterBlaster.SpellList["Kingsbane"], meleeRange
            end
        end

		-- if we made it this far and found nothing to cast, rip
		return "", meleeRange
	end;

	MiscSpell = function(self)
		-- no particular category
		local d

        -- nothing i can think of here...

		return ""
	end;

	IntSpell = function(self)
		-- interruptions
		local d

		if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Kick"]) then
			d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Kick"])
			if ((IsSpellInRange(MasterBlaster.SpellList["Kick"], "target") == 1) and (d) and (d < 0.5)) then
				--- kick to interupt channel spell
				_, _, _, _, _, _, _, notInterruptible = UnitChannelInfo("target")
				if (notInterruptible == false) then
					return MasterBlaster.SpellList["Kick"]
				end

				--- kick to interupt cast spell
				_, _, _, _, _, _, _, _, notInterruptible = UnitCastingInfo("target")
				if (notInterruptible == false)  then
					return MasterBlaster.SpellList["Kick"]
				end
			end
		end

		return ""
	end;

	MajorSpell = function(self)
		-- major dps cooldowns
		local d, name

        -- marked for death
        if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Marked for Death"]) then
			d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Marked for Death"])
			if d <= MasterBlaster.lastBaseGCD then
				return MasterBlaster.SpellList["Marked for Death"]
			end
		end

		-- vendetta
		if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Vendetta"]) then
			d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Vendetta"])
			if d <= MasterBlaster.lastBaseGCD then
				return MasterBlaster.SpellList["Vendetta"]
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
			-- fan of knives if available
			if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Fan of Knives"]) then
				d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Fan of Knives"])
				if d <= MasterBlaster.lastBaseGCD then
					return MasterBlaster.SpellList["Fan of Knives"]
				end
			end
		end

		return ""
	end;
};
