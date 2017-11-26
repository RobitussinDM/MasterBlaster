local L = MasterBlaster.Locals;

MasterBlaster:RegisterModule("vengeance");

MasterBlaster.vengeance = {
	Initialize = function(self)
		-- spells available to the vengeance demon hunter spec
		MasterBlaster:LoadSpells({
			["Arcane Torrent"] = GetSpellInfo(202719),
            ["Auto Attack"] = GetSpellInfo(6603),
			["Consume Magic"] = GetSpellInfo(183752),
			["Demon Spikes"] = GetSpellInfo(203720),
			["Fiery Brand"] = GetSpellInfo(204021),
			["Fracture"] = GetSpellInfo(209795),
			["Immolation Aura"] = GetSpellInfo(178740),
			["Metamorphosis"] = GetSpellInfo(187827),
			["Shear"] = GetSpellInfo(203782),
			["Sigil of Flame"] = GetSpellInfo(204596),
			["Sigil of Silence"] = GetSpellInfo(202137),
			["Soul Carver"] = GetSpellInfo(207407),
			["Soul Fragments Buff"] = GetSpellInfo(203981),
			["Spirit Bomb"] = GetSpellInfo(247454),
			["Throw Glaive"] = GetSpellInfo(185123)
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

			-- no spell in cast, check global cd via Shear
			if (MasterBlaster.SpellList["Shear"]) then
				local globalCooldown = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Shear"])
				if (globalCooldown) then
					timeshift = timeshift + MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Shear"])
				else
					timeshift = timeshift + MasterBlaster.lastBaseGCD
				end
			else
				timeshift = timeshift + MasterBlaster.lastBaseGCD
			end
		end

		-- get player's soul fragment buff information
		local soulFragmentBuff, _, _, soulFragmentCharges = MasterBlaster:hasBuff("player",MasterBlaster.SpellList["Soul Fragments Buff"]);
		if (soulFragmentBuff == nil) then
            soulFragmentCharges = 0
		end

		-- check if in melee range
		local meleeRange = (IsSpellInRange(MasterBlaster.SpellList["Shear"], "target") == 1)

		-- get unit power variables
		local currentFury = UnitPower("player", 17)
		local maximumFury = UnitPowerMax("player", 17)

		-- spirit bomb (if talented) and 4+ soul fragments
		if MasterBlaster.talents[6] == 3 then
			if (soulFragmentCharges >= 4) and (MasterBlaster:ZeroCount(MasterBlaster.SpellList["Spirit Bomb"],spellInCast,nextSpell1,nextSpell2)) then
				d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Spirit Bomb"])
				if ((d - timeshift) <= 0.5) then
					return MasterBlaster.SpellList["Spirit Bomb"], meleeRange
				end
			end
		end

		-- immolation aura on cooldown
		if (MasterBlaster:ZeroCount(MasterBlaster.SpellList["Immolation Aura"],spellInCast,nextSpell1,nextSpell2)) then
			d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Immolation Aura"])
			if ((d - timeshift) <= 0.5) then
				return MasterBlaster.SpellList["Immolation Aura"], meleeRange
			end
		end

		-- sigil of flame on cooldown
		if (MasterBlaster:ZeroCount(MasterBlaster.SpellList["Sigil of Flame"],spellInCast,nextSpell1,nextSpell2)) then
			d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Sigil of Flame"])
			if ((d - timeshift) <= 0.5) then
				return MasterBlaster.SpellList["Sigil of Flame"], meleeRange
			end
		end

        -- fracture to generate soul fragments
        if MasterBlaster.talents[4] == 2 then
			if (MasterBlaster:ZeroCount(MasterBlaster.SpellList["Fracture"],spellInCast,nextSpell1,nextSpell2)) then
				d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Fracture"])
				if ((d - timeshift) <= 0.5) then
					return MasterBlaster.SpellList["Fracture"], meleeRange
				end
			end
		end
        
        -- shear if nothing else
		return MasterBlaster.SpellList["Shear"], meleeRange
	end;

	MiscSpell = function(self)
		-- no particular category
		local d

		-- show demon spikes if 2 charges
		local demonSpikesCharges = GetSpellCharges(MasterBlaster.SpellList["Demon Spikes"]);
		local _, _, icon = GetSpellInfo(203720);
        if (demonSpikesCharges == 2) then
            if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Demon Spikes"]) then
                return MasterBlaster.SpellList["Demon Spikes"], icon, demonSpikesCharges
            end
        end
		
		return ""
	end;

	IntSpell = function(self)
		-- interruptions
		local d

		if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Consume Magic"]) then
			d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Consume Magic"])
			if ((IsSpellInRange(MasterBlaster.SpellList["Consume Magic"], "target") == 1) and (d) and (d < 0.5)) then
				--- consume magic to interupt channel spell
				_, _, _, _, _, _, _, notInterruptible = UnitChannelInfo("target")
				if (notInterruptible == false) then
					return MasterBlaster.SpellList["Consume Magic"]
				end

				--- consume magic to interupt cast spell
				_, _, _, _, _, _, _, _, notInterruptible = UnitCastingInfo("target")
				if (notInterruptible == false)  then
					return MasterBlaster.SpellList["Consume Magic"]
				end
			end
		end
		
		if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Sigil of Silence"]) then
			d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Sigil of Silence"])
			if ((IsSpellInRange(MasterBlaster.SpellList["Sigil of Silence"], "target") == 1) and (d) and (d < 0.5)) then
				--- sigil of silence to interupt channel spell
				_, _, _, _, _, _, _, notInterruptible = UnitChannelInfo("target")
				if (notInterruptible == false) then
					return MasterBlaster.SpellList["Sigil of Silence"]
				end

				--- sigil of silence to interupt cast spell
				_, _, _, _, _, _, _, _, notInterruptible = UnitCastingInfo("target")
				if (notInterruptible == false)  then
					return MasterBlaster.SpellList["Sigil of Silence"]
				end
			end
        end
        
        if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Arcane Torrent"]) then
			d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Arcane Torrent"])
			if ((IsSpellInRange(MasterBlaster.SpellList["Arcane Torrent"], "target") == 1) and (d) and (d < 0.5)) then
				--- arcane torrent to interupt channel spell
				_, _, _, _, _, _, _, notInterruptible = UnitChannelInfo("target")
				if (notInterruptible == false) then
					return MasterBlaster.SpellList["Arcane Torrent"]
				end

				--- arcane torrent to interupt cast spell
				_, _, _, _, _, _, _, _, notInterruptible = UnitCastingInfo("target")
				if (notInterruptible == false)  then
					return MasterBlaster.SpellList["Arcane Torrent "]
				end
			end
		end

		return ""
	end;

	MajorSpell = function(self)
		-- major dps cooldowns
		local d, name
		
		-- fiery brand
        if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Fiery Brand"]) then
            d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Fiery Brand"])
            if d <= MasterBlaster.lastBaseGCD then
                return MasterBlaster.SpellList["Fiery Brand"]
            end
        end

        -- soul carver
		if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Soul Carver"]) then
			d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Soul Carver"])
			if d <= MasterBlaster.lastBaseGCD then
				return MasterBlaster.SpellList["Soul Carver"]
			end
		end

		-- metamorphosis, but only if you have at least 80 fury
		if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Metamorphosis"]) then
			d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Metamorphosis"])
			if d <= MasterBlaster.lastBaseGCD then
				if (UnitPower("player", 17) >= 80) then
                    return MasterBlaster.SpellList["Metamorphosis"]
                end
			end
		end

		return ""
	end;

	AoeSpell = function(self)
		-- aoe on target
		local d

		if (MasterBlaster.person["foeCount"] > 1) then
			-- immolation aura if available
			if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Immolation Aura"]) then
				d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Immolation Aura"])
				if d <= MasterBlaster.lastBaseGCD then
					return MasterBlaster.SpellList["Immolation Aura"]
				end
			end
			
			-- soul cleave if available
			if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Soul Cleave"]) then
				d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Soul Cleave"])
				if d <= MasterBlaster.lastBaseGCD then
					return MasterBlaster.SpellList["Soul Cleave"]
				end
			end
		end

		return ""
	end;
};
