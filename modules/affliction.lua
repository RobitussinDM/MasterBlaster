local L = MasterBlaster.Locals;

MasterBlaster:RegisterModule("affliction");

MasterBlaster.affliction = {
	Initialize = function(self)
		-- spells available to the affliction spec
		MasterBlaster:LoadSpells({
            ["Agony"] = GetSpellInfo(980),
			["Corruption"] = GetSpellInfo(172),
			["Devour Magic"] = GetSpellInfo(19505),
			["Drain Soul"] = GetSpellInfo(198590),
			["Seed of Corruption"] = GetSpellInfo(27243),
			["Soul Harvest"] = GetSpellInfo(196098),
			["Spell Lock"] = GetSpellInfo(19647),
            ["Summon Felhunter"] = GetSpellInfo(691),
            ["Summon Doomguard"] = GetSpellInfo(18540),
            ["Summon Infernal"] = GetSpellInfo(1122),
            ["Unending Breath"] = GetSpellInfo(5697),
			["Unstable Affliction"] = GetSpellInfo(30108)
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

			-- no spell in cast, check global cd via Unending Breath
			if (MasterBlaster.SpellList["Unending Breath"]) then
				local globalCooldown = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Unending Breath"])
				if (globalCooldown) then
					timeshift = timeshift + MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Unending Breath"])
				else
					timeshift = timeshift + MasterBlaster.lastBaseGCD
				end
			else
				timeshift = timeshift + MasterBlaster.lastBaseGCD
			end
		end

		-- get target's agony debuff information
		local agonyDebuff, _, _, _, _, agonyDuration, agonyExpiration, unitCaster = MasterBlaster:hasDeBuff("target", MasterBlaster.SpellList["Agony"], "player");
		if (not agonyExpiration) then
			agonyExpiration = 0
			agonyDuration = 0
		end

        -- get target's corruption debuff information
		local corruptionDebuff, _, _, _, _, corruptionDuration, corruptionExpiration, unitCaster = MasterBlaster:hasDeBuff("target", MasterBlaster.SpellList["Corruption"], "player");
		if (not corruptionExpiration) then
			corruptionExpiration = 0
			corruptionDuration = 0
		end

		-- get unit power variables
		local currentSoulShards = UnitPower("player", 7)
		local currentMana = UnitPower("player", 0)

		-- summon a pet if we don't have one out
		if (not MasterBlaster:hasPet()) then
			if (MasterBlaster:ZeroCount(MasterBlaster.SpellList["Summon Felhunter"],spellInCast,nextSpell1,nextSpell2)) then
				d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Summon Felhunter"])
				if ((d - timeshift) <= 0.5) then
					return MasterBlaster.SpellList["Summon Felhunter"]
				end
			end
		end

        -- agony if not on the target
		if (agonyDebuff == nil) then
			if (MasterBlaster:ZeroCount(MasterBlaster.SpellList["Agony"],spellInCast,nextSpell1,nextSpell2)) then
				return MasterBlaster.SpellList["Agony"]
			end
		end

		-- corruption if not on the target
		if (corruptionDebuff == nil) then
			if (MasterBlaster:ZeroCount(MasterBlaster.SpellList["Corruption"],spellInCast,nextSpell1,nextSpell2)) then
				return MasterBlaster.SpellList["Corruption"]
			end
		end

	   -- unstable affliction if we have 4+ soul shards
	   if (currentSoulShards >= 4) then
		if (MasterBlaster:ZeroCount(MasterBlaster.SpellList["Unstable Affliction"],spellInCast,nextSpell1,nextSpell2)) then
			return MasterBlaster.SpellList["Unstable Affliction"]
		end
	   end

		-- drain soul as filler
		if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Drain Soul"])then
			return MasterBlaster.SpellList["Drain Soul"]
		end

		return ""
	end;

	MiscSpell = function(self)
		-- no particular category
		local d

		return ""
	end;

	IntSpell = function(self)
		-- interruptions
		local d

		if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Spell Lock"]) then
			d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Spell Lock"])
			if ((IsSpellInRange(MasterBlaster.SpellList["Spell Lock"], "target") == 1) and (d) and (d < 0.5)) then
				--- spell lock to interupt channel spell
				_, _, _, _, _, _, _, notInterruptible = UnitChannelInfo("target")
				if (notInterruptible == false) then
					return MasterBlaster.SpellList["Spell Lock"]
				end

				--- spell lock to interupt cast spell
				_, _, _, _, _, _, _, _, notInterruptible = UnitCastingInfo("target")
				if (notInterruptible == false)  then
					return MasterBlaster.SpellList["Spell Lock"]
				end
			end
		end

		return ""
	end;

	MajorSpell = function(self)
		-- major dps cooldowns
		local d, name

		-- soul harvest
		if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Soul Harvest"]) then
			d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Soul Harvest"])
			if d <= MasterBlaster.lastBaseGCD then
				return MasterBlaster.SpellList["Soul Harvest"]
			end
		end

		return ""
	end;

	AoeSpell = function(self)
		-- aoe on target
		local d

		if (MasterBlaster.person["foeCount"] > 1) then
			-- use seed of corruption if available
			if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Seed of Corruption"]) then
				d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Seed of Corruption"])
				if d <= 0.5 then
					return MasterBlaster.SpellList["Seed of Corruption"]
				end
			end
		end

		return ""
	end;
};
