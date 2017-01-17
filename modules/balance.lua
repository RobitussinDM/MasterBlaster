local L = MasterBlaster.Locals;

MasterBlaster:RegisterModule("balance");

MasterBlaster.balance = {
	Initialize = function(self)
		-- spells available to the balance spec
		MasterBlaster:LoadSpells({
			["Blessing of the Ancients"] = GetSpellInfo(202360),
            ["Celestial Alignment"] = GetSpellInfo(194223),
            ["Force of Nature"] = GetSpellInfo(205636),
			["Full Moon"] = GetSpellInfo(202771),
            ["Fury of Elune"] = GetSpellInfo(202770),
			["Half Moon"] = GetSpellInfo(202768),
            ["Incarnation: Chosen of Elune"] = GetSpellInfo(102560),
			["Lunar Empowerment Buff"] = GetSpellInfo(164547),
            ["Lunar Strike"] = GetSpellInfo(194153),
            ["Moonfire"] = GetSpellInfo(8921),
			["Moonfire Debuff"] = GetSpellInfo(164812),
            ["Moonkin Form"] = GetSpellInfo(24858),
            ["New Moon"] = GetSpellInfo(202767),
			["Owlkin Frenzy"] = GetSpellInfo(157228),
			["Oneth's Intuition"] = GetSpellInfo(209406),
			["Oneth's Overconfidence"] = GetSpellInfo(209407),
			["Power of Elune"] = GetSpellInfo(208284),
			["Regrowth"] = GetSpellInfo(8936),
            ["Solar Beam"] = GetSpellInfo(78675),
			["Solar Empowerment Buff"] = GetSpellInfo(164545),
            ["Solar Wrath"] = GetSpellInfo(190984),
            ["Starfall"] = GetSpellInfo(191034),
            ["Starsurge"] = GetSpellInfo(78674),
            ["Stellar Flare"] = GetSpellInfo(202347),
            ["Sunfire"] = GetSpellInfo(93402),
			["Sunfire Debuff"] = GetSpellInfo(164815),
            ["Travel Form"] = GetSpellInfo(783),
            ["Warrior of Elune"] = GetSpellInfo(202425)
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

			-- no spell in cast, check global cd via Travel Form
			if (MasterBlaster.SpellList["Travel Form"]) then
				local globalCooldown = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Travel Form"])
				if (globalCooldown) then
					timeshift = timeshift + MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Travel Form"])
				else
					timeshift = timeshift + MasterBlaster.lastBaseGCD
				end
			else
				timeshift = timeshift + MasterBlaster.lastBaseGCD
			end
		end

		-- get target's moonfire and sunfire debuff information
		local moonfireDebuff, _, _, _, _, moonfireDuration,moonfireExpiration, unitCaster = MasterBlaster:hasDeBuff("target", MasterBlaster.SpellList["Moonfire Debuff"], "player");
		if (not moonfireExpiration) then
			moonfireExpiration = 0
			moonfireDuration = 0
		end

		local sunfireDebuff, _, _, _, _, sunfireDuration,sunfireExpiration, unitCaster = MasterBlaster:hasDeBuff("target", MasterBlaster.SpellList["Sunfire Debuff"], "player");
		if (not sunfireExpiration) then
			sunfireExpiration = 0
			sunfireDuration = 0
		end

		-- get new moon charges and adjust charges based on how far in the future the adivser goes
		local newMoonCharges, _, cooldownStart, cooldownLength = GetSpellCharges(MasterBlaster.SpellList["New Moon"]);
		newMoonCharges = newMoonCharges - MasterBlaster:Count(MasterBlaster.SpellList["New Moon"], spellInCast,nextSpell1,nextSpell2);
		if (((cooldownStart + cooldownLength)- currentTime) - timeshift <= 0) then
			newMoonCharges = newMoonCharges + 1
		end

		-- make sure we are in moonkin Form
		if (not MasterBlaster:hasBuff("player", MasterBlaster.SpellList["Moonkin Form"])) then
			if MasterBlaster:ZeroCount(MasterBlaster.SpellList["Moonkin Form"],spellInCast,nextSpell1,nextSpell2) then
				return MasterBlaster.SpellList["Moonkin Form"], meleeRange
			end
		end

		-- new moon if we have all 3 charges
		if newMoonCharges == 3 then
			if (MasterBlaster:ZeroCount(MasterBlaster.SpellList["New Moon"],spellInCast,nextSpell1,nextSpell2)) then
				d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["New Moon"])
				if ((d - timeshift) <= 0) then
					return MasterBlaster.SpellList["New Moon"]
				end
			end
		end

		-- moon fire and sunfire if not on the target
		if (moonfireDebuff == nil) then
			if (MasterBlaster:ZeroCount(MasterBlaster.SpellList["Moonfire"],spellInCast,nextSpell1,nextSpell2)) then
				return MasterBlaster.SpellList["Moonfire"]
			end
		end
		if (sunfireDebuff == nil) then
			if (MasterBlaster:ZeroCount(MasterBlaster.SpellList["Sunfire"],spellInCast,nextSpell1,nextSpell2)) then
				return MasterBlaster.SpellList["Sunfire"]
			end
		end

		-- use our new moon charges, but be careful to not cap astral power,
		-- and don't suggest more new moons in queue than we have charges for
		local totalNewMoonsInQueue = MasterBlaster:Count(MasterBlaster.SpellList["New Moon"],spellInCast,nextSpell1,nextSpell2)
		if (newMoonCharges > 0) and (totalNewMoonsInQueue < newMoonCharges) and (UnitPower("player",8) < 70) and MasterBlaster:SpellAvailable(MasterBlaster.SpellList["New Moon"]) then
			d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["New Moon"])
			if (d - timeshift) <= 0.5 then
				return MasterBlaster.SpellList["New Moon"]
			end
		end

		-- use up those lunar and solar empowerment charges
		local lunarEmpowermentBuff, _, _, lunarEmpowermentCharges = MasterBlaster:hasBuff("player",MasterBlaster.SpellList["Lunar Empowerment Buff"])
		local solarEmpowermentBuff, _, _, solarEmpowermentCharges = MasterBlaster:hasBuff("player",MasterBlaster.SpellList["Solar Empowerment Buff"])
		-- if we don't have a buff, charges is nil - set it to zero so we can use it for comparisons
		if (lunarEmpowermentBuff == nil) then
			lunarEmpowermentCharges = 0
		end
		if (solarEmpowermentBuff == nil) then
			solarEmpowermentCharges = 0
		end
		-- we have at least one of the buffs, figure out which one to cast - lunar strike has priority
		if (lunarEmpowermentBuff ~= nil) or (solarEmpowermentBuff ~= nil) then
			if (lunarEmpowermentCharges >= solarEmpowermentCharges) then
				if (MasterBlaster:Count(MasterBlaster.SpellList["Lunar Strike"],spellInCast,nextSpell1,nextSpell2) < lunarEmpowermentCharges) then
					if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Lunar Strike"]) then
						return MasterBlaster.SpellList["Lunar Strike"]
					end
				end
			elseif (solarEmpowermentCharges > lunarEmpowermentCharges) then
				if (MasterBlaster:Count(MasterBlaster.SpellList["Solar Wrath"],spellInCast,nextSpell1,nextSpell2) < solarEmpowermentCharges) then
					if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Solar Wrath"]) then
						return MasterBlaster.SpellList["Solar Wrath"]
					end
				end
			end
		end

		-- consume astral power with starsurge(s), but be careful not to go over lunar or solar empowerment charges
		local currentAstralPower= UnitPower("player", 8)
		local totalStarsurgesInQueue = MasterBlaster:Count(MasterBlaster.SpellList["Starsurge"],spellInCast,nextSpell1,nextSpell2)
		if (currentAstralPower > (totalStarsurgesInQueue * 40)) and (lunarEmpowermentCharges < 3) and (solarEmpowermentCharges < 3) then
			if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Starsurge"]) then
				return MasterBlaster.SpellList["Starsurge"]
			end
		end

		-- moonfire if the moonfire debuff has < 2 seconds left
		if (moonfireExpiration - currentTime - timeshift) < 2 then
			if MasterBlaster:ZeroCount(MasterBlaster.SpellList["Moonfire"],spellInCast,nextSpell1,nextSpell2) then
				return MasterBlaster.SpellList["Moonfire"]
			end
		end

		-- sunfire if the sunfire debuff has < 2 seconds left
		if (sunfireExpiration - currentTime - timeshift) < 2 then
			if MasterBlaster:ZeroCount(MasterBlaster.SpellList["Sunfire"],spellInCast,nextSpell1,nextSpell2) then
				return MasterBlaster.SpellList["Sunfire"]
			end
		end

        -- solar wrath as filler
		if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Solar Wrath"])then
			return MasterBlaster.SpellList["Solar Wrath"]
		end

		return ""
	end;

	MiscSpell = function(self)
		-- no particular category
		local d

		-- oneth's intuition (free starsurge from starfall)
		if MasterBlaster:hasBuff("player",MasterBlaster.SpellList["Oneth's Intuition"]) then
			if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Starsurge"]) then
				return MasterBlaster.SpellList["Starsurge"]
			end
		end

		-- oneth's overconfidence (free starfall from starsurge)
		if MasterBlaster:hasBuff("player",MasterBlaster.SpellList["Oneth's Overconfidence"]) then
			if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Starfall"]) then
				return MasterBlaster.SpellList["Starfall"]
			end
		end

		-- lunar strike if you get owlkin Frenzy
		if MasterBlaster:hasBuff("player",MasterBlaster.SpellList["Owlkin Frenzy"]) then
			if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Lunar Strike"]) then
				return MasterBlaster.SpellList["Lunar Strike"]
			end
		end

		-- power of elune legendary - regrowth is instant and free at 20 stacks
		local name, _, icon, charges = MasterBlaster:hasBuff("player",MasterBlaster.SpellList["Power of Elune"])
		if (name ~= nil) and (charges == 20) then
			if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Regrowth"]) then
				return MasterBlaster.SpellList["Regrowth"], _, charges
			end
		end

		return ""
	end;

	IntSpell = function(self)
		-- interruptions
		local d

		if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Solar Beam"]) then
			d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Solar Beam"])
			if ((IsSpellInRange(MasterBlaster.SpellList["Solar Beam"], "target") == 1) and (d) and (d < 0.5)) then
				--- windshear to interupt channel spell
				_, _, _, _, _, _, _, notInterruptible = UnitChannelInfo("target")
				if (notInterruptible == false) then
					return MasterBlaster.SpellList["Solar Beam"]
				end

				--- windshear to interupt cast spell
				_, _, _, _, _, _, _, _, notInterruptible = UnitCastingInfo("target")
				if (notInterruptible == false)  then
					return MasterBlaster.SpellList["Solar Beam"]
				end
			end
		end

		return ""
	end;

	MajorSpell = function(self)
		-- major dps cooldowns
		local d

        -- incarnation: chosen of elune
		if MasterBlaster.talents[5] == 2 then
			if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Incarnation: Chosen of Elune"]) then
				d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Incarnation: Chosen of Elune"])
				if d <= MasterBlaster.lastBaseGCD then
					return MasterBlaster.SpellList["Incarnation: Chosen of Elune"]
				end
			end
        else  -- celestial alignment 
            if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Celestial Alignment"]) then
                d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Celestial Alignment"])
                if d <= MasterBlaster.lastBaseGCD then
                    return MasterBlaster.SpellList["Celestial Alignment"]
                end
            end
		end

		-- fury of elune if talented and have the astral power (get over 90 to make it more effective)
		if MasterBlaster.talents[7] == 1 then
			if UnitPower("player", 8) >= 90 then
				if MasterBlaster:ZeroCount(MasterBlaster.SpellList["Fury of Elune"],spellInCast,nextSpell1,nextSpell2) then
					return MasterBlaster.SpellList["Fury of Elune"]
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

		-- starfall if we have the astral power and there are more than 3 targets
		if (MasterBlaster.person["foeCount"] >= 3) and (UnitPower("player",8) > 60) then
			if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Starfall"]) then
				return MasterBlaster.SpellList["Starfall"]
			end
		end

		return ""
	end;
};
