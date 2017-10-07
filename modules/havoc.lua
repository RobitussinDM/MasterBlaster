local L = MasterBlaster.Locals;

MasterBlaster:RegisterModule("havoc");

MasterBlaster.havoc = {
	Initialize = function(self)
		-- spells available to the havoc demon hunter spec
		MasterBlaster:LoadSpells({
            ["Annihilation"] = GetSpellInfo(201427),
            ["Auto Attack"] = GetSpellInfo(6603),
            ["Blade Dance"] = GetSpellInfo(188499),
            ["Chaos Blades"] = GetSpellInfo(211048),
            ["Chaos Strike"] = GetSpellInfo(162794),
			["Death Sweep"] = GetSpellInfo(210152),
			["Demon's Bite"] = GetSpellInfo(162243),
            ["Eye Beam"] = GetSpellInfo(198013),
            ["Fel Barrage"] = GetSpellInfo(211053),
            ["Fel Rush"] = GetSpellInfo(195072),
            ["Felblade"] = GetSpellInfo(213241),
            ["Fury of the Illidari"] = GetSpellInfo(201628),
            ["Metamorphosis"] = GetSpellInfo(191427),
			["Nemesis"] = GetSpellInfo(206491),
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

		-- check if in melee range
		local meleeRange = (IsSpellInRange(MasterBlaster.SpellList["Chaos Strike"], "target") == 1)

		-- get unit power variables
		local currentFury = UnitPower("player", 17)
		local maximumFury = UnitPowerMax("player", 17)

		-- fel barrage on cooldown if talented
		if MasterBlaster.talents[7] == 2 then
			if (MasterBlaster:ZeroCount(MasterBlaster.SpellList["Fel Barrage"],spellInCast,nextSpell1,nextSpell2)) then
				d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Fel Barrage"])
				if ((d - timeshift) <= 0.5) then
					return MasterBlaster.SpellList["Fel Barrage"], meleeRange
				end
			end
		end

		-- blade dance / death sweep on cooldown if talented into first blood
		if MasterBlaster.talents[3] == 2 then
			-- blade dance if at 35 fury or above
			if (currentFury >= 35) and (MasterBlaster:ZeroCount(MasterBlaster.SpellList["Blade Dance"],spellInCast,nextSpell1,nextSpell2)) then
				d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Blade Dance"])
				if ((d - timeshift) <= 0.5) then
					return MasterBlaster.SpellList["Blade Dance"], meleeRange
				end
			end
            
            -- death sweep is the metamorphosis upgrade of blade dance - cast if at 35 fury or above
            if (currentFury >= 35) and (MasterBlaster:ZeroCount(MasterBlaster.SpellList["Death Sweep"],spellInCast,nextSpell1,nextSpell2)) then
				d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Death Sweep"])
				if ((d - timeshift) <= 0.5) then
					return MasterBlaster.SpellList["Death Sweep"], meleeRange
				end
			end
		end

		-- felblade if talented and 30 or more fury below cap
		if MasterBlaster.talents[1] == 2 then
			if (maximumFury - 30 >= currentFury) and (MasterBlaster:ZeroCount(MasterBlaster.SpellList["Felblade"],spellInCast,nextSpell1,nextSpell2)) then
				d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Felblade"])
				if ((d - timeshift) <= 0.5) then
					return MasterBlaster.SpellList["Felblade"], meleeRange
				end
			end
		end

		-- chaos strike if over 40 fury
		if (currentFury >= 40) and (MasterBlaster:ZeroCount(MasterBlaster.SpellList["Chaos Strike"],spellInCast,nextSpell1,nextSpell2)) then
			d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Chaos Strike"])
			if ((d - timeshift) <= 0.5) then
				return MasterBlaster.SpellList["Chaos Strike"], meleeRange
			end
		end

		-- annihilation is the upgrade version of chaos strike from metamorphosis
		if (currentFury >= 40) and (MasterBlaster:ZeroCount(MasterBlaster.SpellList["Annihilation"],spellInCast,nextSpell1,nextSpell2)) then
			d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Annihilation"])
			if ((d - timeshift) <= 0.5) then
				return MasterBlaster.SpellList["Annihilation"], meleeRange
			end
		end

		-- demon's bite when available (if demon blades isn't taken)
        if MasterBlaster.talents[2] ~= 2 then
			if MasterBlaster:ZeroCount(MasterBlaster.SpellList["Demon's Bite"],spellInCast,nextSpell1,nextSpell2) then
				d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Demon's Bite"])
				if ((d - timeshift) <= 0.5) then
					return MasterBlaster.SpellList["Demon's Bite"], meleeRange
				end
			end
		end
		
		-- if demon blades is taken and have nothing else, toss some glaives
		if MasterBlaster.talents[2] == 2 then
			if MasterBlaster:ZeroCount(MasterBlaster.SpellList["Throw Glaive"],spellInCast,nextSpell1,nextSpell2) then
				d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Throw Glaive"])
				if ((d - timeshift) <= 0.5) then
					return MasterBlaster.SpellList["Throw Glaive"], meleeRange
				end
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

		if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Consume Magic"]) then
			d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Consume Magic"])
			if ((IsSpellInRange(MasterBlaster.SpellList["Consume Magic"], "target") == 1) and (d) and (d < 0.5)) then
				--- mind freeze to interupt channel spell
				_, _, _, _, _, _, _, notInterruptible = UnitChannelInfo("target")
				if (notInterruptible == false) then
					return MasterBlaster.SpellList["Consume Magic"]
				end

				--- mind freeze to interupt cast spell
				_, _, _, _, _, _, _, _, notInterruptible = UnitCastingInfo("target")
				if (notInterruptible == false)  then
					return MasterBlaster.SpellList["Consume Magic"]
				end
			end
        end
        
        if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Arcane Torrent"]) then
			d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Arcane Torrent"])
			if ((IsSpellInRange(MasterBlaster.SpellList["Arcane Torrent"], "target") == 1) and (d) and (d < 0.5)) then
				--- mind freeze to interupt channel spell
				_, _, _, _, _, _, _, notInterruptible = UnitChannelInfo("target")
				if (notInterruptible == false) then
					return MasterBlaster.SpellList["Arcane Torrent"]
				end

				--- mind freeze to interupt cast spell
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

        -- fury of the illidari
		if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Fury of the Illidari"]) then
			d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Fury of the Illidari"])
			if d <= MasterBlaster.lastBaseGCD then
				return MasterBlaster.SpellList["Fury of the Illidari"]
			end
		end
        
        -- nemesis if talented
        if MasterBlaster.talents[5] == 3 then
			if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Nemesis"]) then
                d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Nemesis"])
                if d <= MasterBlaster.lastBaseGCD then
                    return MasterBlaster.SpellList["Nemesis"]
                end
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

        -- chaos blades if talented
        if MasterBlaster.talents[7] == 1 then
			if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Chaos Blades"]) then
                d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Chaos Blades"])
                if d <= MasterBlaster.lastBaseGCD then
                    return MasterBlaster.SpellList["Chaos Blades"]
                end
            end
		end

		return ""
	end;

	AoeSpell = function(self)
		-- aoe on target
		local d

		if (MasterBlaster.person["foeCount"] > 1) then
			-- eye beam if available
			if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Eye Beam"]) then
				d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Eye Beam"])
				if d <= MasterBlaster.lastBaseGCD then
					return MasterBlaster.SpellList["Eye Beam"]
				end
            end
            
            -- blade dance if at 35 fury or above
            if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Blade Dance"]) then
				d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Blade Dance"])
                if d <= MasterBlaster.lastBaseGCD then
                    if (UnitPower("player", 17) >= 25) then
                        return MasterBlaster.SpellList["Blade Dance"]
                    end
				end
            end
            
            -- death sweep is the metamorphosis upgrade of blade dance - cast if at 35 fury or above
            if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Death Sweep"]) then
				d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Death Sweep"])
                if d <= MasterBlaster.lastBaseGCD then
                    if (UnitPower("player", 17) >= 25) then
                        return MasterBlaster.SpellList["Death Sweep"]
                    end
				end
            end
		end

		return ""
	end;
};
