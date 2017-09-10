local L = MasterBlaster.Locals;

MasterBlaster:RegisterModule("windwalker");

MasterBlaster.windwalker = {
	Initialize = function(self)
		-- spells available to the frost death knight spec
		MasterBlaster:LoadSpells({
            ["Blackout Kick"] = GetSpellInfo(100784),
            ["Blackout Kick Buff"] = GetSpellInfo(116768),
            ["Chi Burst"] = GetSpellInfo(123986),
            ["Chi Wave"] = GetSpellInfo(115098),
            ["Crackling Jade Lightning"] = GetSpellInfo(117952),
            ["Disable"] = GetSpellInfo(116095),
            ["Eye of the Tiger Buff"] = GetSpellInfo(196608),
            ["Fists of Fury"] = GetSpellInfo(113656),
            ["Flying Serpent Kick"] = GetSpellInfo(101545),
            ["Invoke Xuen, the White Tiger"] = GetSpellInfo(123904),
            ["Leg Sweep"] = GetSpellInfo(119381),
            ["Rising Sun Kick"] = GetSpellInfo(107428),
            ["Rushing Jade Wind"] = GetSpellInfo(116847),
            ["Serenity"] = GetSpellInfo(152173),
            ["Spear Hand Strike"] = GetSpellInfo(116705),
            ["Spinning Crane Kick"] = GetSpellInfo(101546),
            ["Storm, Earth, and Fire"] = GetSpellInfo(137639),
            ["Strike of the Windlord"] = GetSpellInfo(205320),
            ["Tiger Palm"] = GetSpellInfo(100780),
            ["Touch of Death"] = GetSpellInfo(115080),
            ["Whirling Dragon Punch"] = GetSpellInfo(152175)
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

			-- no spell in cast, check global cd via Disable (no cooldown, low energy cost)
			if (MasterBlaster.SpellList["Disable"]) then
				local globalCooldown = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Disable"])
				if (globalCooldown) then
					timeshift = timeshift + MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Disable"])
				else
					timeshift = timeshift + MasterBlaster.lastBaseGCD
				end
			else
				timeshift = timeshift + MasterBlaster.lastBaseGCD
			end
		end

		-- get player's eye of the tiger buff information
		local eyeOfTheTigerBuff, _, _, _, _, _, eyeOfTheTigerExpires = MasterBlaster:hasBuff("player",MasterBlaster.SpellList["Eye of the Tiger Buff"]);
		if (eyeOfTheTigerBuff == nil) then
			eyeOfTheTigerExpires = 0
		end

		-- check if in melee range
		local meleeRange = (IsSpellInRange(MasterBlaster.SpellList["Tiger Palm"], "target") == 1)

		-- get unit power variables
		local currentChi = UnitPower("player", 12)
		local currentEnergy = UnitPower("player", 3)
		local maximumEnergy = UnitPowerMax("player", 3)

        -- fists of fury if available
        if (currentChi >= 3) and (MasterBlaster:ZeroCount(MasterBlaster.SpellList["Fists of Fury"],spellInCast,nextSpell1,nextSpell2)) then
			d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Fists of Fury"])
			if ((d - timeshift) <= 0.5) then
				return MasterBlaster.SpellList["Fists of Fury"], meleeRange
			end
		end

        -- whirling dragon punch
        if MasterBlaster.talents[7] == 2 then
            if MasterBlaster:ZeroCount(MasterBlaster.SpellList["Whirling Dragon Punch"],spellInCast,nextSpell1,nextSpell2) then
                d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Whirling Dragon Punch"])
                if ((d - timeshift) <= 0.5) then
                    return MasterBlaster.SpellList["Whirling Dragon Punch"], meleeRange
                end
            end
        end

        -- tiger palm if we have less than 4 chi AND we're about to reach maximum energy
        if (currentChi < 4) and (currentEnergy >= 80) then
            if MasterBlaster:ZeroCount(MasterBlaster.SpellList["Tiger Palm"],spellInCast,nextSpell1,nextSpell2) then
                d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Tiger Palm"])
                if ((d - timeshift) <= 0.5) then
                    return MasterBlaster.SpellList["Tiger Palm"], meleeRange
                end
            end
        end

        -- rising sun kick if we have the chi
        if (currentChi >= 2) and (MasterBlaster:ZeroCount(MasterBlaster.SpellList["Rising Sun Kick"],spellInCast,nextSpell1,nextSpell2)) then
			d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Rising Sun Kick"])
			if ((d - timeshift) <= 0.5) then
				return MasterBlaster.SpellList["Rising Sun Kick"], meleeRange
			end
		end

        -- blackout kick
        if (currentChi >= 2) and (MasterBlaster:ZeroCount(MasterBlaster.SpellList["Blackout Kick"],spellInCast,nextSpell1,nextSpell2)) then
			d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Blackout Kick"])
			if ((d - timeshift) <= 0.5) then
				return MasterBlaster.SpellList["Blackout Kick"], meleeRange
			end
		end

		-- tiger palm if we have > 50 energy from cap
		local totalTigerPalmsInQueue = MasterBlaster:Count(MasterBlaster.SpellList["Tiger Palm"],spellInCast,nextSpell1,nextSpell2)
		if (currentEnergy >= (maximumEnergy - 50)) and (currentEnergy > (totalTigerPalmsInQueue * 50)) then
			d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Tiger Palm"])
			if ((d - timeshift) <= 0.5) then
				return MasterBlaster.SpellList["Tiger Palm"], meleeRange
			end
		end

		-- if we made it this far and found nothing to cast, rip
		return "", meleeRange
	end;

	MiscSpell = function(self)
		-- no particular category
		local d

		-- free blackout kick from tiger palm
		name = MasterBlaster:hasBuff("player",MasterBlaster.SpellList["Blackout Kick Buff"])
		if (name ~= nil) then
			if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Blackout Kick"]) then
				return MasterBlaster.SpellList["Blackout Kick"]
			end
		end

		return ""
	end;

	IntSpell = function(self)
		-- interruptions
		local d

		if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Spear Hand Strike"]) then
			d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Spear Hand Strike"])
			if ((IsSpellInRange(MasterBlaster.SpellList["Spear Hand Strike"], "target") == 1) and (d) and (d < 0.5)) then
				--- spear hand strike to interupt channel spell
				_, _, _, _, _, _, _, notInterruptible = UnitChannelInfo("target")
				if (notInterruptible == false) then
					return MasterBlaster.SpellList["Spear Hand Strike"]
				end

				--- spear hand strike to interupt cast spell
				_, _, _, _, _, _, _, _, notInterruptible = UnitCastingInfo("target")
				if (notInterruptible == false)  then
					return MasterBlaster.SpellList["Spear Hand Strike"]
				end
			end
		end

		return ""
	end;

	MajorSpell = function(self)
		-- major dps cooldowns
		local d, name

        -- strike of the windlord
        if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Strike of the Windlord"]) then
			d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Strike of the Windlord"])
			if d <= MasterBlaster.lastBaseGCD then
				return MasterBlaster.SpellList["Strike of the Windlord"]
			end
		end

		-- storm earth and fire
		if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Storm, Earth, and Fire"]) then
			d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Storm, Earth, and Fire"])
			if d <= MasterBlaster.lastBaseGCD then
				return MasterBlaster.SpellList["Storm, Earth, and Fire"]
			end
		end

        -- touch of death
        if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Touch of Death"]) then
			d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Touch of Death"])
			if d <= MasterBlaster.lastBaseGCD then
				return MasterBlaster.SpellList["Touch of Death"]
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
			-- whirling dragon punch if talented
			if MasterBlaster.talents[7] == 2 then
					if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Whirling Dragon Punch"]) then
					d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Whirling Dragon Punch"])
					if d <= MasterBlaster.lastBaseGCD then
						return MasterBlaster.SpellList["Whirling Dragon Punch"]
					end
				end
			end

			-- spinning crane kick if available
			if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Spinning Crane Kick"]) then
				d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Spinning Crane Kick"])
				if d <= MasterBlaster.lastBaseGCD then
					return MasterBlaster.SpellList["Spinning Crane Kick"]
				end
			end
		end

		return ""
	end;
};
