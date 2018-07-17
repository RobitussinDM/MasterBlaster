local L = MasterBlaster.Locals;

MasterBlaster:RegisterModule("feral");

MasterBlaster.feral = {
	Initialize = function(self)
		-- spells available to the feral druid spec
		MasterBlaster:LoadSpells({
            ["Ashamane's Frenzy"] = GetSpellInfo(22812),
            ["Berserk"] = GetSpellInfo(106951),
            ["Brutal Slash"] = GetSpellInfo(202028),
			["Cat Form"] = GetSpellInfo(768),
			["Clearcasting Buff"] = GetSpellInfo(135700),
            ["Ferocious Bite"] = GetSpellInfo(22568),
            ["Maim"] = GetSpellInfo(22570),
			["Mighty Bash"] = GetSpellInfo(5211),
			["Predatory Swiftness Buff"] = GetSpellInfo(69369),
            ["Rake"] = GetSpellInfo(1822),
            ["Rip"] = GetSpellInfo(1079),
            ["Shred"] = GetSpellInfo(5221),
			["Skull Bash"] = GetSpellInfo(106839),
			["Swipe"] = GetSpellInfo(106785),
            ["Thrash"] = GetSpellInfo(106830),
            ["Tiger's Fury"] = GetSpellInfo(5217)
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

			-- no spell in cast, check global cd via cat form
			if (MasterBlaster.SpellList["Cat Form"]) then
				local globalCooldown = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Cat Form"])
				if (globalCooldown) then
					timeshift = timeshift + MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Cat Form"])
				else
					timeshift = timeshift + MasterBlaster.lastBaseGCD
				end
			else
				timeshift = timeshift + MasterBlaster.lastBaseGCD
			end
		end

		-- get target's rake debuff information
		local rakeDebuff, _, _, _, _, rakeDuration, rakeExpiration, unitCaster = MasterBlaster:hasDeBuff("target", MasterBlaster.SpellList["Rake"], "player");
		if (not rakeExpiration) then
			rakeExpiration = 0
			rkeDuration = 0
		end

        -- get target's rip debuff information
		local ripDebuff, _, _, _, _, ripDuration, ripExpiration, unitCaster = MasterBlaster:hasDeBuff("target", MasterBlaster.SpellList["Rip"], "player");
		if (not ripExpiration) then
			ripExpiration = 0
			ripDuration = 0
		end

		-- check if in melee range
		local meleeRange = (IsSpellInRange(MasterBlaster.SpellList["Shred"], "target") == 1)

		local currentComboPoints = UnitPower("player", 4)
		local currentEnergy = UnitPower("player", 3)
        
        -- make sure we are in cat form
		if (not MasterBlaster:hasBuff("player", MasterBlaster.SpellList["Cat Form"])) then
			if MasterBlaster:ZeroCount(MasterBlaster.SpellList["Cat Form"],spellInCast,nextSpell1,nextSpell2) then
				return MasterBlaster.SpellList["Cat Form"], meleeRange
			end
		end

        -- rake if rake isn't up or has less than 4 seconds left
		if ((rakeDuration == 0) or ((rakeExpiration - currentTime - timeshift) < 6)) and (currentEnergy > 35) then
			if MasterBlaster:ZeroCount(MasterBlaster.SpellList["Rake"],spellInCast,nextSpell1,nextSpell2) then
                d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Rake"])
                if ((d - timeshift) <= 0.5) then
                    return MasterBlaster.SpellList["Rake"], meleeRange
                end
			end
		end

		-- rip with 5 combo points if rip isn't present
        if ((currentComboPoints >= 5) and ((ripExpiration - currentTime - timeshift) < 0)) and (currentEnergy > 30) then
			if MasterBlaster:ZeroCount(MasterBlaster.SpellList["Rip"],spellInCast,nextSpell1,nextSpell2) then
                d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Rip"])
                if ((d - timeshift) <= 0.5) then
                    return MasterBlaster.SpellList["Rip"], meleeRange
                end
			end
		end

		-- ferocious bite with 5 combo points (but only if rip is up)
        if ((currentComboPoints >= 5) and ((ripExpiration - currentTime - timeshift) > 0)) and (currentEnergy > 25) then
            if MasterBlaster:ZeroCount(MasterBlaster.SpellList["Ferocious Bite"],spellInCast,nextSpell1,nextSpell2) then
                d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Ferocious Bite"])
                if ((d - timeshift) <= 0.5) then
                    return MasterBlaster.SpellList["Ferocious Bite"], meleeRange
                end
			end
		end
		
		-- shred if we have less than 5 combo points
        if (currentComboPoints <= 5) and (currentEnergy > 40) then
            if MasterBlaster:ZeroCount(MasterBlaster.SpellList["Shred"],spellInCast,nextSpell1,nextSpell2) then
                d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Shred"])
                if ((d - timeshift) <= 0.5) then
                    return MasterBlaster.SpellList["Shred"], meleeRange
                end
			end
        end

	end;

	MiscSpell = function(self)
		-- no particular category
		local d

		-- clearcasting, free thrash
		if MasterBlaster:hasBuff("player",MasterBlaster.SpellList["Clearcasting Buff"]) then
			if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Thrash"]) then
				return MasterBlaster.SpellList["Thrash"]
			end
		end

        -- free regrowth
		if MasterBlaster:hasBuff("player",MasterBlaster.SpellList["Predatory Swiftness Buff"]) then
			if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Regrowth"]) then
				return MasterBlaster.SpellList["Regrowth"]
			end
		end

		return ""
	end;

	IntSpell = function(self)
		-- interruptions, purge
		local d

		if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Skull Bash"]) then
			d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Skull Bash"])
			if ((IsSpellInRange(MasterBlaster.SpellList["Skull Bash"], "target") == 1) and (d) and (d < 0.5)) then
				--- skull bash to interupt channel spell
				_, _, _, _, _, _, _, notInterruptible = UnitChannelInfo("target")
				if (notInterruptible == false) then
					return MasterBlaster.SpellList["Skull Bash"]
				end

				--- skull bash to interupt cast spell
				_, _, _, _, _, _, _, _, notInterruptible = UnitCastingInfo("target")
				if (notInterruptible == false)  then
					return MasterBlaster.SpellList["Skull Bash"]
				end
			end
		end

        -- mighty bash as backup if talented
        if MasterBlaster.talents[4] == 1 then
            if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Mighty Bash"]) then
                d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Mighty Bash"])
                if ((IsSpellInRange(MasterBlaster.SpellList["Mighty Bash"], "target") == 1) and (d) and (d < 0.5)) then
                    --- mighty bash to interupt channel spell
                    _, _, _, _, _, _, _, notInterruptible = UnitChannelInfo("target")
                    if (notInterruptible == false) then
                        return MasterBlaster.SpellList["Mighty Bash"]
                    end
    
                    --- mighty bash to interupt cast spell
                    _, _, _, _, _, _, _, _, notInterruptible = UnitCastingInfo("target")
                    if (notInterruptible == false)  then
                        return MasterBlaster.SpellList["Mighty Bash"]
                    end
                end
            end
        end

		return ""
	end;

	MajorSpell = function(self)
		-- major dps cooldowns
		local d, name

		-- berserk if you have it
		if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Berserk"]) then
			d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Berserk"])
			if d <= MasterBlaster.lastBaseGCD then
				return MasterBlaster.SpellList["Berserk"]
			end
		end

		-- tiger's fury if under 30 energy
		local currentEnergy = UnitPower("player", 3)
		if (currentEnergy < 30) then
            if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Tiger's Fury"]) then
				d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Tiger's Fury"])
				if d <= MasterBlaster.lastBaseGCD then
					return MasterBlaster.SpellList["Tiger's Fury"]
				end
			end
		end
		
		-- ashamane's frenzy only if tiger's fury is active
		local tigersFuryBuff = MasterBlaster:hasBuff("player",MasterBlaster.SpellList["Tiger's Fury"]);
		if (deadlyPoisonBuff ~= nil) then
			if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Ashamane's Frenzy"]) then
				d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Ashamane's Frenzy"])
				if d <= MasterBlaster.lastBaseGCD then
					return MasterBlaster.SpellList["Ashamane's Frenzy"]
				end
			end
		end
	
		-- berserking
		if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Berserking"]) then
			d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Berserking"])
			if d <= MasterBlaster.lastBaseGCD then
				return MasterBlaster.SpellList["Berserking"]
			end
		end

		return ""
	end;

	AoeSpell = function(self)
		-- aoe on target
		local d

		if (MasterBlaster.person["foeCount"] > 1) then

			if MasterBlaster.talents[6] == 2 then
				-- brutal slash if talented
				if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Brutal Slash"]) then
					d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Brutal Slash"])
					if d <= MasterBlaster.lastBaseGCD then
						return MasterBlaster.SpellList["Brutal Slash"]
					end
				end
			else
				-- swipe if available
				if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Swipe"]) then
					d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Swipe"])
					if d <= MasterBlaster.lastBaseGCD then
						return MasterBlaster.SpellList["Swipe"]
					end
				end
			end

			-- thrash second best
			if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Thrash"]) then
				d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Thrash"])
				if d <= MasterBlaster.lastBaseGCD then
					return MasterBlaster.SpellList["Thrash"]
				end
			end
		end

		return ""
	end;
};
