local L = MasterBlaster.Locals;

MasterBlaster:RegisterModule("elemental");

MasterBlaster.elemental = {
	Initialize = function(self)
		-- spells available to the elemental spec
		MasterBlaster:LoadSpells({
			["Ascendance"] = GetSpellInfo(114050),
			["Ascendance Buff"] = GetSpellInfo(114050),
			["Chain Lightning"] = GetSpellInfo(421),
			["Earthquake"] = GetSpellInfo(61882),
			["Earth Shock"] = GetSpellInfo(8042),
			["Echoes of the Great Sundering"] = GetSpellInfo(208723),
			["Echo of the Elements"] = GetSpellInfo(108283),
			["Elemental Blast"] = GetSpellInfo(117014),
			["Elemental Mastery"] = GetSpellInfo(16166),
			["Ember Totem Buff"] = GetSpellInfo(210658),
			["Fire Elemental"] = GetSpellInfo(198067),
			["Flame Shock"] = GetSpellInfo(188389),
			["Frost Shock"] = GetSpellInfo(196840),
			["Ghost Wolf"] = GetSpellInfo(2645),
			["Icefury"] = GetSpellInfo(210714),
			["Lava Burst"] = GetSpellInfo(51505),
			["Lightning Bolt"] = GetSpellInfo(403),
			["Liquid Magma Totem"] = GetSpellInfo(192222),
			["Power of the Maelstrom"] = GetSpellInfo(191861),
			["Power of the Maelstrom Buff"] = GetSpellInfo(191877),
			["Purge"]	= GetSpellInfo(370),
			["Resonance Totem Buff"] = GetSpellInfo(202192),
			["Stormkeeper"] = GetSpellInfo(205495),
			["Storm Elemental"] = GetSpellInfo(192249),
			["Storm Totem Buff"] = GetSpellInfo(210652),
			["Tailwind Totem Buff"] = GetSpellInfo(210659),
			["Totem Mastery"] = GetSpellInfo(210643),
			["Thunderstorm"] = GetSpellInfo(51490),
			["Wind Shear"] = GetSpellInfo(57994)
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

		-- set minimum amount of flameshock remaining for a lava burst
		local lavaBurstCastTime = 2 - (2 * MasterBlaster.spellHaste * .01)

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

			-- no spell in cast, check global cd via Ghost Wolf
			if (MasterBlaster.SpellList["Ghost Wolf"]) then
				local globalCooldown = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Ghost Wolf"])
				if (globalCooldown) then
					timeshift = timeshift + MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Ghost Wolf"])
				else
					timeshift = timeshift + MasterBlaster.lastBaseGCD
				end
			else
				timeshift = timeshift + MasterBlaster.lastBaseGCD
			end
		end

		-- get target's flame shock debuff information
		local flameShockDebuff, _, _, _, _, flameShockDuration,flameShockExpiration, unitCaster = MasterBlaster:hasDeBuff("target", MasterBlaster.SpellList["Flame Shock"], "player");
		if (not flameShockExpiration) then
			flameShockExpiration = 0
			flameShockDuration = 0
		end

		-- get unit power variables
		local currentMaelstrom = UnitPower("player", 11)

		-- get lava burst charges and adjust charges based on how far in the future the adivser goes
		local lavaBurstCharges, _, cooldownStart, cooldownLength = GetSpellCharges(MasterBlaster.SpellList["Lava Burst"]);
		lavaBurstCharges = lavaBurstCharges - MasterBlaster:Count(MasterBlaster.SpellList["Lava Burst"], spellInCast,nextSpell1,nextSpell2);
		if (((cooldownStart + cooldownLength)- currentTime) - timeshift <= 0) then
			lavaBurstCharges = lavaBurstCharges + 1
		end

		-- check if ascendance is active
		local ascendance, _, _, _, _, _, ascendanceExpires = MasterBlaster:hasBuff("player",MasterBlaster.SpellList["Ascendance Buff"]);
		if (ascendance == nil) then
			ascendanceExpires = 0
		end

		-- if tier 1 talent is totem mastery keep those totems up
		if MasterBlaster.talents[1] == 3 then
			-- check to see that have have all the buffs (are in range of the totems)
			local hasStormTotem = MasterBlaster:hasBuff("player",MasterBlaster.SpellList["Storm Totem Buff"]);
			local hasEmberTotem = MasterBlaster:hasBuff("player",MasterBlaster.SpellList["Ember Totem Buff"]);
			local hasTailwindTotem = MasterBlaster:hasBuff("player",MasterBlaster.SpellList["Tailwind Totem Buff"]);
			local hasResonanceTotem = MasterBlaster:hasBuff("player",MasterBlaster.SpellList["Resonance Totem Buff"]);
			local haveTotem,totemName,totemStart,totemDuration = GetTotemInfo(1)
			-- if you drop while the first is still active, it goes to toteminfo(2) - check there before advising to drop again
			-- also interfered with by other totems, so we need to check them all
			if (not haveTotem)  or (totemName ~= MasterBlaster.SpellList["Totem Mastery"]) then
				haveTotem,totemName,totemStart,totemDuration = GetTotemInfo(2)
			end
			if (not haveTotem)  or (totemName ~= MasterBlaster.SpellList["Totem Mastery"]) then
				haveTotem,totemName,totemStart,totemDuration = GetTotemInfo(3)
			end
			if (not haveTotem)  or (totemName ~= MasterBlaster.SpellList["Totem Mastery"]) then
				haveTotem,totemName,totemStart,totemDuration = GetTotemInfo(4)
			end
			if (not hasStormTotem or not hasEmberTotem or not hasTailwindTotem or not hasResonanceTotem) then
				haveTotem = false
			end
			if (MasterBlaster:ZeroCount(MasterBlaster.SpellList["Totem Mastery"],spellInCast,nextSpell1,nextSpell2)) then
				if (not haveTotem) or (totemName ~= MasterBlaster.SpellList["Totem Mastery"]) or (totemStart + totemDuration - currentTime - timeshift <= 0.5) then
					return MasterBlaster.SpellList["Totem Mastery"]
				end
			end
		end

		-- flame shock if not on the target
		if (flameShockDebuff == nil) then
			if (MasterBlaster:ZeroCount(MasterBlaster.SpellList["Flame Shock"],spellInCast,nextSpell1,nextSpell2)) then
				return MasterBlaster.SpellList["Flame Shock"]
			end
		end

		-- elemental blast if talented
		if (MasterBlaster:ZeroCount(MasterBlaster.SpellList["Elemental Blast"],spellInCast,nextSpell1,nextSpell2)) then
			d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Elemental Blast"])
			if ((d - timeshift) <= 0.5) then
				return MasterBlaster.SpellList["Elemental Blast"]
			end
		end

		-- earth shock if maelstrom capped
		if (currentMaelstrom >= 100) and (MasterBlaster:ZeroCount(MasterBlaster.SpellList["Earth Shock"],spellInCast,nextSpell1,nextSpell2)) then
			d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Earth Shock"])
			if ((d - timeshift) <= 0.5) then
				return MasterBlaster.SpellList["Earth Shock"]
			end
		end
		
		-- icefury if talented and maelstrom <= 70
		if MasterBlaster.talents[7] == 3 then
			if (currentMaelstrom < 70) and (MasterBlaster:ZeroCount(MasterBlaster.SpellList["Icefury"],spellInCast,nextSpell1,nextSpell2)) then
				d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Icefury"])
				if ((d - timeshift) <= 0.5) then
					return MasterBlaster.SpellList["Icefury"]
				end
			end

			-- if icefury is already in queue and we have no frost shocks, queue one up to avoid capping
			if (
				MasterBlaster:Count(MasterBlaster.SpellList["Icefury"],spellInCast,nextSpell1,nextSpell2) == 1) and 
				(MasterBlaster:ZeroCount(MasterBlaster.SpellList["Frost Shock"],spellInCast,nextSpell1,nextSpell2)
			) then
				if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Frost Shock"]) then
					return MasterBlaster.SpellList["Frost Shock"], icon, charges
				end
			end
		end

		-- lava burst
		if ((lavaBurstCharges > 0) or ((ascendanceExpires - currentTime - timeshift) > 0)) and
			MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Lava Burst"])
		then
			if (
				((flameShockExpiration ~= 0) and ((flameShockExpiration - currentTime - timeshift) > lavaBurstCastTime)) or 
				(MasterBlaster:Count(MasterBlaster.SpellList["Flame Shock"],spellInCast,nextSpell1,nextSpell2) > 0)
			) then
				d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Lava Burst"])
				if ((d - timeshift) <= 0.5) or ((ascendanceExpires - currentTime - timeshift) > 0) then
					return MasterBlaster.SpellList["Lava Burst"]
				end
			end
		end

		-- flame shock if maelstrom > 20 and the flame shock debuff has < 9 seconds left
		if (currentMaelstrom >= 20) and ((flameShockExpiration - currentTime - timeshift) < 9) then
			if MasterBlaster:ZeroCount(MasterBlaster.SpellList["Flame Shock"],spellInCast,nextSpell1,nextSpell2) then
				return MasterBlaster.SpellList["Flame Shock"]
			end
		end
		
		-- earth shock if maelstrom > 90
		if (currentMaelstrom >= 90) and (MasterBlaster:ZeroCount(MasterBlaster.SpellList["Earth Shock"],spellInCast,nextSpell1,nextSpell2)) then
			return MasterBlaster.SpellList["Earth Shock"]
		end

		-- if you have an icefury buff, frost shock if you have > 20 maelstrom
		if MasterBlaster.talents[7] == 3 then
			local hasIcefuryBuff, _, _, charges = MasterBlaster:hasBuff("player",MasterBlaster.SpellList["Icefury"])
			if (hasIcefuryBuff ~= nil) then
				local totalFrostShocksInQueue = MasterBlaster:Count(MasterBlaster.SpellList["Frost Shock"],spellInCast,nextSpell1,nextSpell2)
				if currentMaelstrom > (totalFrostShocksInQueue * 20) then
					if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Frost Shock"]) then
						return MasterBlaster.SpellList["Frost Shock"]
					end
				end
			end
		end

		-- stormkeeper if available
		if (MasterBlaster:ZeroCount(MasterBlaster.SpellList["Stormkeeper"],spellInCast,nextSpell1,nextSpell2)) then
			d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Stormkeeper"])
			if ((d - timeshift) <= 0.5) then
				return MasterBlaster.SpellList["Stormkeeper"]
			end
		end

		-- lightning bolt as filler
		if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Lightning Bolt"])then
			return MasterBlaster.SpellList["Lightning Bolt"]
		end

		return ""
	end;

	MiscSpell = function(self)
		-- no particular category
		local d

		-- check for echoes of the great sundering proc
		local echoesOfTheGreatSundering = MasterBlaster:hasBuff("player",MasterBlaster.SpellList["Echoes of the Great Sundering"]);
		if (echoesOfTheGreatSundering ~= nil) then
			return MasterBlaster.SpellList["Earthquake"]
		end

		-- icefury buff on frost shock
		if MasterBlaster.talents[7] == 3 then
			name, _, icon, charges = MasterBlaster:hasBuff("player",MasterBlaster.SpellList["Icefury"])
			if (name ~= nil) then
				if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Frost Shock"]) then
					return MasterBlaster.SpellList["Frost Shock"], icon, charges
				end
			end
		end

		-- show power of the maelstrom with proc count
		name, _, icon, charges = MasterBlaster:hasBuff("player",MasterBlaster.SpellList["Power of the Maelstrom Buff"])
		if (name ~= nil) then
			if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Lightning Bolt"]) then
				return MasterBlaster.SpellList["Lightning Bolt"], icon, charges
			end
		end

		return ""
	end;

	IntSpell = function(self)
		-- interruptions, purge
		local d

		if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Wind Shear"]) then
			d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Wind Shear"])
			if ((IsSpellInRange(MasterBlaster.SpellList["Wind Shear"], "target") == 1) and (d) and (d < 0.5)) then
				--- windshear to interupt channel spell
				_, _, _, _, _, _, _, notInterruptible = UnitChannelInfo("target")
				if (notInterruptible == false) then
					return MasterBlaster.SpellList["Wind Shear"]
				end

				--- windshear to interupt cast spell
				_, _, _, _, _, _, _, _, notInterruptible = UnitCastingInfo("target")
				if (notInterruptible == false)  then
					return MasterBlaster.SpellList["Wind Shear"]
				end
			end
		end

		-- check if purgeable buff is on target
		if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Purge"]) then
			if IsSpellInRange(MasterBlaster.SpellList["Purge"], "target") == 1 then
				if (MasterBlaster:hasBuff("target", ".", 1)) then
					d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Purge"])
					if (d) and (d < 0.5) then
						return MasterBlaster.SpellList["Purge"]
					end
				end
			end
		end

		return ""
	end;

	MajorSpell = function(self)
		-- major dps cooldowns
		local d, name

		-- fire elemental
		if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Fire Elemental"]) then
			d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Fire Elemental"])
			if d <= MasterBlaster.lastBaseGCD then
				return MasterBlaster.SpellList["Fire Elemental"]
			end
		end
		
		-- storm elemental
		if MasterBlaster.talents[6] == 2 then
			if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Storm Elemental"]) then
				d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Storm Elemental"])
				if d <= MasterBlaster.lastBaseGCD then
					return MasterBlaster.SpellList["Storm Elemental"]
				end
			end
		end

		-- ascendance
		if MasterBlaster.talents[7] == 1 then
			if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Ascendance"]) then
				name = MasterBlaster:hasBuff("player",MasterBlaster.SpellList["Ascendance Buff"])
				if (name == nil) then
					d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Ascendance"])
					if d <= MasterBlaster.lastBaseGCD then
						return MasterBlaster.SpellList["Ascendance"]
					end
				end
			end
		end

		-- elemental mastery
		if MasterBlaster.talents[4] == 3 then
			if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Elemental Mastery"]) then
				d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Elemental Mastery"])
				if d <= MasterBlaster.lastBaseGCD then
					return MasterBlaster.SpellList["Elemental Mastery"]
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
			-- always use liquid magma totem if available
			if MasterBlaster.talents[6] == 1 then
				if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Liquid Magma Totem"]) then
					d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Liquid Magma Totem"])
					if d <= 0.5 then
						return MasterBlaster.SpellList["Liquid Magma Totem"]
					end
				end
			end

			-- only recommend stormkeeper if ascendance isn't active
			local ascendanceActive = MasterBlaster:hasBuff("player",MasterBlaster.SpellList["Ascendance Buff"]);
			if (ascendanceActive == nil) then
				-- stormkeeper for those sweet instant + 200% chain lightnings
				d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Stormkeeper"])
				if d <= 0.5 then
					return MasterBlaster.SpellList["Stormkeeper"]
				end
			end

			-- earthquake if you have the maelstrom and 3 or more targets
			if (MasterBlaster.person["foeCount"] >= 3) and MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Earthquake"]) then
				return MasterBlaster.SpellList["Earthquake"]
			end

			---- chain lightning as filler 
			if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Chain Lightning"]) then
				return MasterBlaster.SpellList["Chain Lightning"]
			end
		end

		return ""
	end;
};
