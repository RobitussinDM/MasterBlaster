local L = MasterBlaster.Locals;

MasterBlaster:RegisterModule("arcane");

MasterBlaster.arcane = {
	Initialize = function(self)
		-- spells available to the frost mage spec
		MasterBlaster:LoadSpells({
            ["Arcane Barrage"] = GetSpellInfo(44425),
            ["Arcane Blast"] = GetSpellInfo(30451),
            ["Arcane Charge Buff"] = GetSpellInfo(114664),
			["Arcane Explosion"] = GetSpellInfo(1449),
			["Arcane Missiles"] = GetSpellInfo(5143),
			["Arcane Missiles Buff"] = GetSpellInfo(79683),
            ["Arcane Power"] = GetSpellInfo(12042),
            ["Charged Up"] = GetSpellInfo(205032),
            ["Counterspell"] = GetSpellInfo(2139),
            ["Erosion"] = GetSpellInfo(205039),
            ["Evocation"] = GetSpellInfo(12051),
			["Frost Nova"] = GetSpellInfo(112),
			["Mark of Aluneth"] = GetSpellInfo(224968),
            ["Presence of Mind"] = GetSpellInfo(205025),
            ["Rune of Power"] = GetSpellInfo(116011),
            ["Spellsteal"] = GetSpellInfo(30449),
            ["Summon Water Elemental"] = GetSpellInfo(31687)
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

			-- no spell in cast, check global cd via arcane blast
			if (MasterBlaster.SpellList["Arcane Blast"]) then
				local globalCooldown = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Arcane Blast"])
				if (globalCooldown) then
					timeshift = timeshift + MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Arcane Blast"])
				else
					timeshift = timeshift + MasterBlaster.lastBaseGCD
				end
			else
				timeshift = timeshift + MasterBlaster.lastBaseGCD
			end
		end

		-- get arcane missiles charges
		local _, _, _, arcaneMissilesCharges = MasterBlaster:hasBuff("player",MasterBlaster.SpellList["Arcane Missiles Buff"])
		if arcaneMissilesCharges == nil then
			arcaneMissilesCharges = 0
		end

		-- get unit power variables
		local currentMana = UnitPower("player", 0)
		local maximumMana = UnitPowerMax("player", 0)
		local arcaneCharges = UnitPower("player", 16)
		
		-- mark of aluneth on cooldown
		if (MasterBlaster:ZeroCount(MasterBlaster.SpellList["Mark of Aluneth"],spellInCast,nextSpell1,nextSpell2)) then
			d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Mark of Aluneth"])
			if ((d - timeshift) <= 0.5) then
				return MasterBlaster.SpellList["Mark of Aluneth"]
			end
		end
        
        -- arcane missiles with 4 arcane charges
        if (arcaneCharges == 4) then
            if (MasterBlaster:ZeroCount(MasterBlaster.SpellList["Arcane Missiles"],spellInCast,nextSpell1,nextSpell2)) then
                d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Arcane Missiles"])
                if ((d - timeshift) <= 0.5) then
                    return MasterBlaster.SpellList["Arcane Missiles"]
                end
            end
		end
		
		-- arcane barrage to reduce mana costs if we are less than 50% mana
		if (currentMana < (maximumMana / 2)) then
			if (arcaneCharges > 0) then
				if (MasterBlaster:ZeroCount(MasterBlaster.SpellList["Arcane Barrage"],spellInCast,nextSpell1,nextSpell2)) then
					d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Arcane Barrage"])
					if ((d - timeshift) <= 0.5) then
						return MasterBlaster.SpellList["Arcane Barrage"]
					end
				end
			end
		end

        -- arcane blast as filler and to generate arcane charges
        if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Arcane Blast"])then
			return MasterBlaster.SpellList["Arcane Blast"]
		end

		return ""
	end;

	MiscSpell = function(self)
		-- no particular category

		-- show arcane missiles charges
		name, _, icon, charges = MasterBlaster:hasBuff("player",MasterBlaster.SpellList["Arcane Missiles Buff"])
		if (name ~= nil) then
			return MasterBlaster.SpellList["Arcane Missiles Buff"], icon, charges
		end

		return ""
	end;

	IntSpell = function(self)
		-- interruptions, spellsteal
		local d

		if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Counterspell"]) then
			d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Counterspell"])
			if ((IsSpellInRange(MasterBlaster.SpellList["Counterspell"], "target") == 1) and (d) and (d < 0.5)) then
				--- counterspell to interupt channel spell
				_, _, _, _, _, _, _, notInterruptible = UnitChannelInfo("target")
				if (notInterruptible == false) then
					return MasterBlaster.SpellList["Counterspell"]
				end

				--- counterspell to interupt cast spell
				_, _, _, _, _, _, _, _, notInterruptible = UnitCastingInfo("target")
				if (notInterruptible == false)  then
					return MasterBlaster.SpellList["Counterspell"]
				end
			end
		end

		-- check if stealable buff is on target
		if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Spellsteal"]) then
			if IsSpellInRange(MasterBlaster.SpellList["Spellsteal"], "target") == 1 then
				if (MasterBlaster:hasBuff("target", ".", 1)) then
					d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Spellsteal"])
					if (d) and (d < 0.5) then
						return MasterBlaster.SpellList["Spellsteal"]
					end
				end
			end
		end

		return ""
	end;

	MajorSpell = function(self)
		-- major dps cooldowns
        local d, name
        
        -- get arcane charges
		local arcaneCharges = UnitPower("player", 16)
        
        -- only use dps cooldowns if you have 4 arcane charges
        if (arcaneCharges == 4) then
            -- rune of power
            if MasterBlaster.talents[3] == 2 then
                if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Rune of Power"]) then
                    d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Rune of Power"])
                    if d <= MasterBlaster.lastBaseGCD then
                        return MasterBlaster.SpellList["Rune of Power"]
                    end
                end
			end
			
			-- arcane power
			if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Arcane Power"]) then
				d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Arcane Power"])
				if d <= MasterBlaster.lastBaseGCD then
					return MasterBlaster.SpellList["Arcane Power"]
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
			-- arcane explosion 
			if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Arcane Explosion"]) then
				return MasterBlaster.SpellList["Arcane Explosion"]
			end
		end

		return ""
	end;
};