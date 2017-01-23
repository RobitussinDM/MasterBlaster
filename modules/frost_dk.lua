local L = MasterBlaster.Locals;

MasterBlaster:RegisterModule("frost_dk");

MasterBlaster.frost_dk = {
	Initialize = function(self)
		-- spells available to the frost death knight spec
		MasterBlaster:LoadSpells({
            ["Blinding Sleet"] = GetSpellInfo(207167),
            ["Breath of Sindragosa"] = GetSpellInfo(152279),
			["Dark Succor Buff"] = GetSpellInfo(101568),
            ["Death Strike"] = GetSpellInfo(49998),
            ["Empower Rune Weapon"] = GetSpellInfo(47568),
            ["Frost Fever"] = GetSpellInfo(55095),
            ["Frost Strike"] = GetSpellInfo(49143),
            ["Frostscythe"] = GetSpellInfo(207230),
            ["Glacial Advance"] = GetSpellInfo(194913),
            ["Horn of Winter"] = GetSpellInfo(57330),
            ["Howling Blast"] = GetSpellInfo(49184),
            ["Hungering Rune Weapon"] = GetSpellInfo(207127),
            ["Icy Talons Buff"] = GetSpellInfo(194878),
            ["Killing Machine Buff"] = GetSpellInfo(51128),
            ["Mind Freeze"] = GetSpellInfo(47528),
            ["Obliterate"] = GetSpellInfo(49020),
            ["Obliteration"] = GetSpellInfo(207256),
            ["Pillar of Frost"] = GetSpellInfo(51271),
            ["Razorice"] = GetSpellInfo(51714),
            ["Remorseless Winter"] = GetSpellInfo(196770),
            ["Rime Buff"] = GetSpellInfo(59052),
            ["Sindragosa's Fury"] = GetSpellInfo(190778)
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

			-- no spell in cast, check global cd via Ghost Wolf
			if (MasterBlaster.SpellList["Howling Blast"]) then
				local globalCooldown = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Howling Blast"])
				if (globalCooldown) then
					timeshift = timeshift + MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Howling Blast"])
				else
					timeshift = timeshift + MasterBlaster.lastBaseGCD
				end
			else
				timeshift = timeshift + MasterBlaster.lastBaseGCD
			end
		end

        -- get target's frost fever debuff information
		local frostFeverDebuff, _, _, _, _, frostFeverDuration, frostFeverExpiration, unitCaster = MasterBlaster:hasDeBuff("target", MasterBlaster.SpellList["Frost Fever"], "player");
		if (not frostFeverExpiration) then
			frostFeverExpiration = 0
			frostFeverDuration = 0
		end

		-- check if in melee range
		local meleeRange = (IsSpellInRange(MasterBlaster.SpellList["Obliterate"], "target") == 1)
		local currentRunes = UnitPower("player", 5)
		local currentRunicPower = UnitPower("player", 6)

		-- pillar of frost if you have it
		if MasterBlaster:ZeroCount(MasterBlaster.SpellList["Pillar of Frost"],spellInCast,nextSpell1,nextSpell2) then
            d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Pillar of Frost"])
            if ((d - timeshift) <= 0.5) then
                return MasterBlaster.SpellList["Pillar of Frost"], meleeRange
            end
        end

		-- if we don't have icy talon's buff, frost strike
		if (not MasterBlaster:hasBuff("player", MasterBlaster.SpellList["Icy Talons Buff"])) then
			if (currentRunicPower >= 25) and (MasterBlaster:ZeroCount(MasterBlaster.SpellList["Frost Strike"],spellInCast,nextSpell1,nextSpell2)) then
				d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Frost Strike"])
				if ((d - timeshift) <= 0.5) then
					return MasterBlaster.SpellList["Frost Strike"], meleeRange
				end
			end
		end

        -- howling blast if frost fever isn't on the target, or if the debuff is about to fall off (< 5 seconds left)
		-- or if we have a rime proc
		local haveRime = MasterBlaster:hasBuff("player",MasterBlaster.SpellList["Rime Buff"])
        if (frostFeverDebuff == nil) or ((frostFeverExpiration - currentTime - timeshift) < 5) or (haveRime) then
            if (MasterBlaster:ZeroCount(MasterBlaster.SpellList["Howling Blast"],spellInCast,nextSpell1,nextSpell2)) then
				d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Howling Blast"])
				if ((d - timeshift) <= 0.5) then
					return MasterBlaster.SpellList["Howling Blast"], meleeRange
				end
			end
        end

		-- frost strike if we have > 80 runic power and don't have a frost strike in queue
		if (currentRunicPower >= 80) and (MasterBlaster:ZeroCount(MasterBlaster.SpellList["Frost Strike"],spellInCast,nextSpell1,nextSpell2)) then
			d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Frost Strike"])
			if ((d - timeshift) <= 0.5) then
				return MasterBlaster.SpellList["Frost Strike"], meleeRange
			end
		end

		-- obliterate if we have the runes
		local totalObliteratesInQueue = MasterBlaster:Count(MasterBlaster.SpellList["Obliterate"],spellInCast,nextSpell1,nextSpell2)
		if currentRunicPower > (totalObliteratesInQueue * 2) then
			d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Obliterate"])
			if ((d - timeshift) <= 0.5) then
				return MasterBlaster.SpellList["Obliterate"], meleeRange
			end
		end
		
		-- remorseless winter if we have a rune
		if (currentRunes >= 1) and (MasterBlaster:ZeroCount(MasterBlaster.SpellList["Remorseless Winter"],spellInCast,nextSpell1,nextSpell2)) then
			d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Remorseless Winter"])
			if ((d - timeshift) <= 0.5) then
				return MasterBlaster.SpellList["Remorseless Winter"], meleeRange
			end
		end

		-- frost strike if we have > 25 runic power
		local totalFrostStrikesInQueue = MasterBlaster:Count(MasterBlaster.SpellList["Frost Strike"],spellInCast,nextSpell1,nextSpell2)
		if (currentRunicPower >= 25) and (currentRunicPower > (totalFrostStrikesInQueue * 25)) then
			d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Frost Strike"])
			if ((d - timeshift) <= 0.5) then
				return MasterBlaster.SpellList["Frost Strike"], meleeRange
			end
		end

		-- if we made it this far and found nothing to cast, rip
		return "", meleeRange
	end;

	MiscSpell = function(self)
		-- no particular category
		local d

		-- free death strike from dark Succor
		name = MasterBlaster:hasBuff("player",MasterBlaster.SpellList["Dark Succor Buff"])
		if (name ~= nil) then
			if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Death Strike"]) then
				return MasterBlaster.SpellList["Death Strike"]
			end
		end

		-- show obliterate if killing machine procs
		name = MasterBlaster:hasBuff("player",MasterBlaster.SpellList["Killing Machine Buff"])
		if (name ~= nil) then
			if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Obliterate"]) then
				if (UnitPower("player", 5) >= 2) then
                    return MasterBlaster.SpellList["Obliterate"]
                end
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
				--- windshear to interupt channel spell
				_, _, _, _, _, _, _, notInterruptible = UnitChannelInfo("target")
				if (notInterruptible == false) then
					return MasterBlaster.SpellList["Mind Freeze"]
				end

				--- windshear to interupt cast spell
				_, _, _, _, _, _, _, _, notInterruptible = UnitCastingInfo("target")
				if (notInterruptible == false)  then
					return MasterBlaster.SpellList["Mind Freeze"]
				end
			end
		end

		return ""
	end;

	MajorSpell = function(self)
		-- major dps cooldowns
		local d, name

		-- sindragosa's fury if there's 5 stacks of razorice
		if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Sindragosa's Fury"]) then
            d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Sindragosa's Fury"])
            if d <= MasterBlaster.lastBaseGCD then
                local razoriceDebuff, _, _, razoriceStacks = MasterBlaster:hasDeBuff("target", MasterBlaster.SpellList["Razorice"], "player");
                if (razoriceDebuff ~= nil) then
                    if (razoriceStacks == 5) then
                        return MasterBlaster.SpellList["Sindragosa's Fury"]
                    end
                end
            end
		end

        -- obliteration if talented
        if MasterBlaster.talents[7] == 1 then
			if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Obliteration"]) then
                d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Obliteration"])
                if d <= MasterBlaster.lastBaseGCD then
                    -- make sure we have enough runic power for a frost strike, or that killing machine is active
                    name = MasterBlaster:hasBuff("player",MasterBlaster.SpellList["Killing Machine Buff"])
                    if (name ~= nil) or (UnitPower("player", 6) >= 25) then
                        return MasterBlaster.SpellList["Obliteration"]
                    end
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
			---- crash lightning if you have the maelstrom
			if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Howling Blast"]) then
				d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Howling Blast"])
				if d <= MasterBlaster.lastBaseGCD then
					return MasterBlaster.SpellList["Howling Blast"]
				end
			end
		end

		return ""
	end;
};
