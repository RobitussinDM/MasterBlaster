local L = MasterBlaster.Locals;

MasterBlaster:RegisterModule("blood");

MasterBlaster.blood = {
	Initialize = function(self)
		-- spells available to the blood death knight spec
		MasterBlaster:LoadSpells({
            ["Anti-Magic Shell"] = GetSpellInfo(48707),
            ["Asphxiate"] = GetSpellInfo(221562),
            ["Blooddrinker"] = GetSpellInfo(206931),
            ["Blood Boil"] = GetSpellInfo(50842),
            ["Blood Plague"] = GetSpellInfo(195740),
            ["Bone Shield Buff"] = GetSpellInfo(195181),
            ["Consumption"] = GetSpellInfo(205223),
            ["Crimson Scourge Buff"] = GetSpellInfo(81136),
            ["Dancing Rune Weapon"] = GetSpellInfo(49028),
            ["Dark Command"] = GetSpellInfo(56222),
            ["Death and Decay"] = GetSpellInfo(43265),
            ["Death Strike"] = GetSpellInfo(49998),
            ["Death's Caress"] = GetSpellInfo(195292),
            ["Heart Strike"] = GetSpellInfo(206930),
            ["Marrowrend"] = GetSpellInfo(195182),
            ["Mind Freeze"] = GetSpellInfo(47528),
            ["Souldrinker Buff"] = GetSpellInfo(238114)
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

			-- no spell in cast, check global cd via Heart Strike
			if (MasterBlaster.SpellList["Heart Strike"]) then
				local globalCooldown = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Heart Strike"])
				if (globalCooldown) then
					timeshift = timeshift + MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Heart Strike"])
				else
					timeshift = timeshift + MasterBlaster.lastBaseGCD
				end
			else
				timeshift = timeshift + MasterBlaster.lastBaseGCD
			end
		end

        -- get target's blood plague debuff information
		local bloodPlagueDebuff, _, _, _, _, bloodPlagueDuration, bloodPlagueExpiration, unitCaster = MasterBlaster:hasDeBuff("target", MasterBlaster.SpellList["Blood Plague"], "player");
		if (not bloodPlagueExpiration) then
			bloodPlagueExpiration = 0
			bloodPlagueDuration = 0
		end

		-- get player's bone shield buff information
		local boneShieldBuff, _, _, boneShieldCharges, _, _, boneShieldExpires = MasterBlaster:hasBuff("player",MasterBlaster.SpellList["Bone Shield Buff"]);
		if (boneShieldBuff == nil) then
            boneShieldCharges = 0
			boneShieldExpires = 0
		end

		-- check if in melee range
		local meleeRange = (IsSpellInRange(MasterBlaster.SpellList["Marrowrend"], "target") == 1)

		-- get unit power variables
		local currentRunes = UnitPower("player", 5)
		local currentRunicPower = UnitPower("player", 6)

        -- use marrowrend if bone shield is about to expire
        if (boneShieldBuff == nil) or ((boneShieldExpires - currentTime - timeshift) <= 3) then
            if (currentRunes >= 2) and (MasterBlaster:ZeroCount(MasterBlaster.SpellList["Marrowrend"],spellInCast,nextSpell1,nextSpell2)) then
                d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Marrowrend"])
                if ((d - timeshift) <= 0.5) then
                    return MasterBlaster.SpellList["Marrowrend"], meleeRange
                end
            end
        end

        -- death strike if souldrinker is about to expire
        -- TODO: this section when i get the souldrinker trait

        -- blood boil if blood plague isn't on the target, or blood plague is about to fall off (< 5 seconds left)
        if (bloodPlagueDebuff == nil) or ((bloodPlagueExpiration - currentTime - timeshift) < 5) or (haveRime) then
            if (MasterBlaster:ZeroCount(MasterBlaster.SpellList["Blood Boil"],spellInCast,nextSpell1,nextSpell2)) then
				d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Blood Boil"])
				if ((d - timeshift) <= 0.5) then
					return MasterBlaster.SpellList["Blood Boil"], meleeRange
				end
			end
        end

        -- death strike if we have > 80 runic power and don't have a death strike in queue
		if (currentRunicPower >= 80) and (MasterBlaster:ZeroCount(MasterBlaster.SpellList["Death Strike"],spellInCast,nextSpell1,nextSpell2)) then
			d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Death Strike"])
			if ((d - timeshift) <= 0.5) then
				return MasterBlaster.SpellList["Death Strike"], meleeRange
			end
		end

        -- marrowrend if bone shield has 6 or fewer stack
        if (boneShieldCharges <= 6) then
            if (currentRunes >= 2) and (MasterBlaster:ZeroCount(MasterBlaster.SpellList["Marrowrend"],spellInCast,nextSpell1,nextSpell2)) then
                d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Marrowrend"])
                if ((d - timeshift) <= 0.5) then
                    return MasterBlaster.SpellList["Marrowrend"], meleeRange
                end
            end
        end

        -- death and decay if we have 3 or more runes, or if there are 3 or more enemies
        if (MasterBlaster.person["foeCount"] >= 3) or (currentRunes >= 3) then
			if (MasterBlaster:ZeroCount(MasterBlaster.SpellList["Death and Decay"],spellInCast,nextSpell1,nextSpell2)) then
                d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Death and Decay"])
                if ((d - timeshift) <= 0.5) then
                    return MasterBlaster.SpellList["Death and Decay"], meleeRange
                end
            end
		end

        -- heart strike if we have 3 or more runes
        if (currentRunes >= 3) then
			if (MasterBlaster:ZeroCount(MasterBlaster.SpellList["Heart Strike"],spellInCast,nextSpell1,nextSpell2)) then
                d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Heart Strike"])
                if ((d - timeshift) <= 0.5) then
                    return MasterBlaster.SpellList["Heart Strike"], meleeRange
                end
            end
		end

        -- consumption if available
        if (MasterBlaster:ZeroCount(MasterBlaster.SpellList["Consumption"],spellInCast,nextSpell1,nextSpell2)) then
            d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Consumption"])
            if ((d - timeshift) <= 0.5) then
                return MasterBlaster.SpellList["Consumption"], meleeRange
            end
        end

        -- blood boil if available
		if (MasterBlaster:ZeroCount(MasterBlaster.SpellList["Blood Boil"],spellInCast,nextSpell1,nextSpell2)) then
            d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Blood Boil"])
            if ((d - timeshift) <= 0.5) then
                return MasterBlaster.SpellList["Blood Boil"], meleeRange
            end
        end

		-- if we made it this far and found nothing to cast, rip
		return "", meleeRange
	end;

	MiscSpell = function(self)
		-- no particular category
		local d

        -- free death and decay from crimson scourge
		name = MasterBlaster:hasBuff("player",MasterBlaster.SpellList["Crimson Scourge Buff"])
		if (name ~= nil) then
			if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Death and Decay"]) then
				return MasterBlaster.SpellList["Death and Decay"]
			end
		end

		return ""
	end;

	IntSpell = function(self)
		-- interruptions, purge
		local d

		if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Mind Freeze"]) then
			d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Mind Freeze"])
			if ((IsSpellInRange(MasterBlaster.SpellList["Mind Freeze"], "target") == 1) and (d) and (d < 0.5)) then
				--- mind freeze to interupt channel spell
				_, _, _, _, _, _, _, notInterruptible = UnitChannelInfo("target")
				if (notInterruptible == false) then
					return MasterBlaster.SpellList["Mind Freeze"]
				end

				--- mind freeze to interupt cast spell
				_, _, _, _, _, _, _, _, notInterruptible = UnitCastingInfo("target")
				if (notInterruptible == false)  then
					return MasterBlaster.SpellList["Mind Freeze"]
				end
			end
		end

        -- asphxiate as backup
        if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Asphxiate"]) then
			d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Asphxiate"])
			if ((IsSpellInRange(MasterBlaster.SpellList["Asphxiate"], "target") == 1) and (d) and (d < 0.5)) then
				--- asphxiate to interupt channel spell
				_, _, _, _, _, _, _, notInterruptible = UnitChannelInfo("target")
				if (notInterruptible == false) then
					return MasterBlaster.SpellList["Asphxiate"]
				end

				--- asphxiate to interupt cast spell
				_, _, _, _, _, _, _, _, notInterruptible = UnitCastingInfo("target")
				if (notInterruptible == false)  then
					return MasterBlaster.SpellList["Asphxiate"]
				end
			end
		end

		return ""
	end;

	MajorSpell = function(self)
		-- major dps cooldowns
		local d, name

		-- dancing rune weapon if you have it
		if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Dancing Rune Weapon"]) then
			d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Dancing Rune Weapon"])
			if d <= MasterBlaster.lastBaseGCD then
				return MasterBlaster.SpellList["Dancing Rune Weapon"]
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

			-- consumption if available
			if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Consumption"]) then
				d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Consumption"])
				if d <= MasterBlaster.lastBaseGCD then
					return MasterBlaster.SpellList["Consumption"]
				end
			end
		end

		return ""
	end;
};
