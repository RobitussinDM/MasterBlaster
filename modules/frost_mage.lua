local L = MasterBlaster.Locals;

MasterBlaster:RegisterModule("frost_mage");

MasterBlaster.frost_mage = {
	Initialize = function(self)
		-- spells available to the frost mage spec
		MasterBlaster:LoadSpells({
			["Blizzard"] = GetSpellInfo(190356),
            ["Brain Freeze Buff"] = GetSpellInfo(190446),
            ["Coldsnap"] = GetSpellInfo(235219),
            ["Comet Storm"] = GetSpellInfo(153595),
            ["Cone of Cold"] = GetSpellInfo(120),
            ["Counterspell"] = GetSpellInfo(2139),
            ["Ebonbolt"] = GetSpellInfo(214634),
            ["Fingers of Frost Buff"] = GetSpellInfo(44544),
            ["Flurry"] = GetSpellInfo(44614),
            ["Frost Bomb"] = GetSpellInfo(112948),
            ["Frost Nova"] = GetSpellInfo(112),
            ["Frostbolt"] = GetSpellInfo(116),
            ["Frozen Orb"] = GetSpellInfo(84714),
            ["Glacial Spike"] = GetSpellInfo(199786),
            ["Ice Lance"] = GetSpellInfo(30455),
            ["Ice Nova"] = GetSpellInfo(190356),
            ["Icy Veins"] = GetSpellInfo(12472),
            ["Mirror Image"] = GetSpellInfo(55342),
            ["Ray of Frost"] = GetSpellInfo(205021),
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

			-- no spell in cast, check global cd via frostbolt
			if (MasterBlaster.SpellList["Frostbolt"]) then
				local globalCooldown = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Frostbolt"])
				if (globalCooldown) then
					timeshift = timeshift + MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Frostbolt"])
				else
					timeshift = timeshift + MasterBlaster.lastBaseGCD
				end
			else
				timeshift = timeshift + MasterBlaster.lastBaseGCD
			end
		end

		-- get fingers of frost charges
		local _, _, _, fingersOfFrostCharges = MasterBlaster:hasBuff("player",MasterBlaster.SpellList["Fingers of Frost Buff"])
		if fingersOfFrostCharges == nil then
			fingersOfFrostCharges = 0
		end

		-- check if brain freeze is active
		local brainFreeze = MasterBlaster:hasBuff("player",MasterBlaster.SpellList["Brain Freeze Buff"]);

		-- summon a water elemental if we don't have one out
		if (not MasterBlaster:hasPet()) then
			if (MasterBlaster:ZeroCount(MasterBlaster.SpellList["Summon Water Elemental"],spellInCast,nextSpell1,nextSpell2)) then
				d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Summon Water Elemental"])
				if ((d - timeshift) <= 0.5) then
					return MasterBlaster.SpellList["Summon Water Elemental"]
				end
			end
		end

        -- frozen orb
		if (MasterBlaster:ZeroCount(MasterBlaster.SpellList["Frozen Orb"],spellInCast,nextSpell1,nextSpell2)) then
			d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Frozen Orb"])
			if ((d - timeshift) <= 0.5) then
				return MasterBlaster.SpellList["Frozen Orb"]
			end
		end

		-- ray of frost if talented
        if MasterBlaster.talents[1] == 1 then
            if (MasterBlaster:ZeroCount(MasterBlaster.SpellList["Ray of Frost"],spellInCast,nextSpell1,nextSpell2)) then
                d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Ray of Frost"])
                if ((d - timeshift) <= 0.5) then
                    return MasterBlaster.SpellList["Ray of Frost"]
                end
            end
        end

        -- ebonbolt (only if we don't have brain freeze)
        if (brainFreeze == nil) then
            if (MasterBlaster:ZeroCount(MasterBlaster.SpellList["Ebonbolt"],spellInCast,nextSpell1,nextSpell2)) then
                d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Ebonbolt"])
                if ((d - timeshift) <= 0.5) then
                    return MasterBlaster.SpellList["Ebonbolt"]
                end
            end
        end

		-- frost bomb if talented and at least one fingers of frost charge
        if (MasterBlaster.talents[6] == 1) and (fingersOfFrostCharges > 0) then
			-- get target's frost bomb debuff information
			frostBombDebuff, _, _, _, _, frostBombDuration,frostBombExpiration, unitCaster = MasterBlaster:hasDeBuff("target", MasterBlaster.SpellList["Frost Bomb"], "player");
			if (not frostBombExpiration) then
				frostBombDuration = 0
				frostBombExpiration = 0
			end

			-- frost bomb if the frost bomb debuff has < 2 seconds left
			if (frostBombExpiration - currentTime - timeshift) < 2 then
				if (MasterBlaster:ZeroCount(MasterBlaster.SpellList["Frost Bomb"],spellInCast,nextSpell1,nextSpell2)) then
					d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Frost Bomb"])
					if ((d - timeshift) <= 0.5) then
						return MasterBlaster.SpellList["Frost Bomb"]
					end
				end
			end
        end

        -- ice lance if we have 2 fingers of frost charges
        if (fingersOfFrostCharges == 2) then
            if (MasterBlaster:ZeroCount(MasterBlaster.SpellList["Ice Lance"],spellInCast,nextSpell1,nextSpell2)) then
                d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Ice Lance"])	
                if ((d - timeshift) <= 0.5) then
                    return MasterBlaster.SpellList["Ice Lance"]
                end
            end
        end

		-- flurry if we have a brain freeze proc
        if (brainFreeze) then
            if (MasterBlaster:ZeroCount(MasterBlaster.SpellList["Flurry"],spellInCast,nextSpell1,nextSpell2)) then
                d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Flurry"])
                if ((d - timeshift) <= 0.5) then
                    return MasterBlaster.SpellList["Flurry"]
                end
            end
        end
		
		-- if flurry is already in queue or cast and we have no ice lances, queue one up
        if (
            MasterBlaster:Count(MasterBlaster.SpellList["Flurry"],spellInCast,nextSpell1,nextSpell2) == 1) and 
            (MasterBlaster:ZeroCount(MasterBlaster.SpellList["Ice Lance"],spellInCast,nextSpell1,nextSpell2)
        ) then
            if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Ice Lance"]) then
                return MasterBlaster.SpellList["Ice Lance"], icon, charges
            end
        end

        -- glacial spike if talented
		if MasterBlaster.talents[7] == 2 then
            if (MasterBlaster:ZeroCount(MasterBlaster.SpellList["Glacial Spike"],spellInCast,nextSpell1,nextSpell2)) then
                d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Glacial Spike"])
                if ((d - timeshift) <= 0.5) then
                    return MasterBlaster.SpellList["Glacial Spike"]
                end
            end
        end

        -- comet storm if talented
		if MasterBlaster.talents[7] == 3 then
            if (MasterBlaster:ZeroCount(MasterBlaster.SpellList["Comet Storm"],spellInCast,nextSpell1,nextSpell2)) then
                d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Comet Storm"])
                if ((d - timeshift) <= 0.5) then
                    return MasterBlaster.SpellList["Comet Storm"]
                end
            end
        end

        -- ice nova if talented
		if MasterBlaster.talents[4] == 1 then
            if (MasterBlaster:ZeroCount(MasterBlaster.SpellList["Ice Nova"],spellInCast,nextSpell1,nextSpell2)) then
                d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Ice Nova"])
                if ((d - timeshift) <= 0.5) then
                    return MasterBlaster.SpellList["Ice Nova"]
                end
            end
        end

        -- water jet (if we have no fingers of frost)
		if (fingersOfFrostCharges == 0) then
			if (MasterBlaster:ZeroCount(MasterBlaster.SpellList["Water Jet"],spellInCast,nextSpell1,nextSpell2)) then
				d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Water Jet"])
				if ((d - timeshift) <= 0.5) then
					return MasterBlaster.SpellList["Water Jet"]
				end
			end
		end

		-- if water jet is already in queue or cast and we have no frostbolts, queue one up
        if (
            MasterBlaster:Count(MasterBlaster.SpellList["Water Jet"],spellInCast,nextSpell1,nextSpell2) == 1) and 
            (MasterBlaster:ZeroCount(MasterBlaster.SpellList["Frostbolt"],spellInCast,nextSpell1,nextSpell2)
        ) then
            if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Frostbolt"]) then
                return MasterBlaster.SpellList["Frostbolt"]
            end
        end

		-- ice lance
		if (fingersOfFrostCharges > 0) then
			if (MasterBlaster:ZeroCount(MasterBlaster.SpellList["Ice Lance"],spellInCast,nextSpell1,nextSpell2)) then
                d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Ice Lance"])
                if ((d - timeshift) <= 0.5) then
                    return MasterBlaster.SpellList["Ice Lance"]
                end
            end
		end

		-- frostbolt as filler
		if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Frostbolt"])then
			return MasterBlaster.SpellList["Frostbolt"]
		end

		return ""
	end;

	MiscSpell = function(self)
		-- no particular category

		-- show brain freeze
		name, _, icon, charges = MasterBlaster:hasBuff("player",MasterBlaster.SpellList["Brain Freeze Buff"])
		if (name ~= nil) then
			if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Flurry"]) then
				return MasterBlaster.SpellList["Flurry"], icon, charges
			end
		end

		-- show fingers of frost proc charges
		name, _, icon, charges = MasterBlaster:hasBuff("player",MasterBlaster.SpellList["Fingers of Frost Buff"])
		if (name ~= nil) then
			if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Ice Lance"]) then
				return MasterBlaster.SpellList["Ice Lance"], icon, charges
			end
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
		
		-- rune of power
		if MasterBlaster.talents[3] == 2 then
			if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Rune of Power"]) then
				d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Rune of Power"])
				if d <= MasterBlaster.lastBaseGCD then
					return MasterBlaster.SpellList["Rune of Power"]
				end
			end
		end

		-- mirror image
		if MasterBlaster.talents[3] == 1 then
			if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Mirror Image"]) then
				d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Mirror Image"])
				if d <= MasterBlaster.lastBaseGCD then
					return MasterBlaster.SpellList["Mirror Image"]
				end
			end
		end

        -- icy veins
		if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Icy Veins"]) then
			d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Icy Veins"])
			if d <= MasterBlaster.lastBaseGCD then
				return MasterBlaster.SpellList["Icy Veins"]
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
			-- comet storm
			if MasterBlaster.talents[7] == 3 then
				if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Comet Storm"]) then
					d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Comet Storm"])
					if d <= MasterBlaster.lastBaseGCD then
						return MasterBlaster.SpellList["Comet Storm"]
					end
				end
			end

			-- ice nova
			if MasterBlaster.talents[4] == 1 then
				if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Ice Nova"]) then
					d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Ice Nova"])
					if d <= MasterBlaster.lastBaseGCD then
						return MasterBlaster.SpellList["Ice Nova"]
					end
				end
			end

			---- blizzard as filler 
			if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Blizzard"]) then
				return MasterBlaster.SpellList["Blizzard"]
			end
		end

		return ""
	end;
};