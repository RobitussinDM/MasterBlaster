local L = MasterBlaster.Locals;

MasterBlaster:RegisterModule("outlaw");

MasterBlaster.outlaw = {
	Initialize = function(self)
		-- spells available to the outlaw spec
		MasterBlaster:LoadSpells({
			["Adrenaline Rush"] = GetSpellInfo(13750),
			["Between the Eyes"] = GetSpellInfo(199804),
            ["Blade Flurry"] = GetSpellInfo(13877),
            ["Broadsides Buff"] = GetSpellInfo(193356),
            ["Buried Treasure Buff"] = GetSpellInfo(199600),
            ["Curse of the Dreadblades"] = GetSpellInfo(202665),
            ["Grand Melee Buff"] = GetSpellInfo(193358),
            ["Skull and Crossbones Buff"] = GetSpellInfo(199603),
            ["Kick"] = GetSpellInfo(1766),
            ["Loaded Dice Buff"] = GetSpellInfo(238139),
            ["Marked for Death"] = GetSpellInfo(137619),
            ["Opportunity Buff"] = GetSpellInfo(195627),
            ["Pistol Shot"] = GetSpellInfo(185763),
            ["Roll the Bones"] = GetSpellInfo(193316),
            ["Run Through"] = GetSpellInfo(2098),
			["Rupture"] = GetSpellInfo(1943),
			["Ruthless Precision Buff"] = GetSpellInfo(193357),
            ["Saber Slash"] = GetSpellInfo(193315),
            ["True Bearing Buff"] = GetSpellInfo(193359),
            ["Vendetta"] = GetSpellInfo(79140)
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

			-- no spell in cast, check global cd via Detection (no cooldown, no energy cost)
			if (MasterBlaster.SpellList["Detection"]) then
				local globalCooldown = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Detection"])
				if (globalCooldown) then
					timeshift = timeshift + MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Detection"])
				else
					timeshift = timeshift + MasterBlaster.lastBaseGCD
				end
			else
				timeshift = timeshift + MasterBlaster.lastBaseGCD
			end
		end

        local rollTheBonesBuffCount = 0

        -- get player's roll the bones buff information
		local ruthlessPrecisionBuff, _, _, _, _, _, ruthlessPrecisionExpires = MasterBlaster:hasBuff("player",MasterBlaster.SpellList["Ruthless Precision Buff"]);
		if (ruthlessPrecisionBuff == nil) then
			ruthlessPrecisionExpires = 0
        else
            rollTheBonesBuffCount = rollTheBonesBuffCount + 1
		end

        local skullAndCrossbonesBuff, _, _, _, _, _, skullAndCrossbonesExpires = MasterBlaster:hasBuff("player",MasterBlaster.SpellList["Skull and Crossbones Buff"]);
		if (skullAndCrossbonesBuff == nil) then
			skullAndCrossbonesExpires = 0
        else
            rollTheBonesBuffCount = rollTheBonesBuffCount + 1
		end

        local buriedTreasureBuff, _, _, _, _, _, buriedTreasureExpires = MasterBlaster:hasBuff("player",MasterBlaster.SpellList["Buried Treasure Buff"]);
		if (buriedTreasureBuff == nil) then
			buriedTreasureExpires = 0
        else
            rollTheBonesBuffCount = rollTheBonesBuffCount + 1
		end

        local trueBearingBuff, _, _, _, _, _, trueBearingExpires = MasterBlaster:hasBuff("player",MasterBlaster.SpellList["True Bearing Buff"]);
		if (trueBearingBuff == nil) then
			trueBearingExpires = 0
        else
            rollTheBonesBuffCount = rollTheBonesBuffCount + 1
		end

        local grandMeleeBuff, _, _, _, _, _, grandMeleeExpires = MasterBlaster:hasBuff("player",MasterBlaster.SpellList["Grand Melee Buff"]);
		if (grandMeleeBuff == nil) then
			grandMeleeExpires = 0
        else
            rollTheBonesBuffCount = rollTheBonesBuffCount + 1
		end
        
        local broadsidesBuff, _, _, _, _, _, broadsidesExpires = MasterBlaster:hasBuff("player",MasterBlaster.SpellList["Broadsides Buff"]);
		if (broadsidesBuff == nil) then
			broadsidesExpires = 0
        else
            rollTheBonesBuffCount = rollTheBonesBuffCount + 1
		end

		local opportunityBuff = MasterBlaster:hasBuff("player",MasterBlaster.SpellList["Opportunity Buff"]);
		

		-- check if in melee range
		local meleeRange = (IsSpellInRange(MasterBlaster.SpellList["Saber Slash"], "target") == 1)

		-- get unit power variables
		local currentComboPoints = UnitPower("player", 4)
		local currentEnergy = UnitPower("player", 3)

		-- roll the bones if we have 5+ combo points and less than 2 buffs, unless one of them is ruthless precision or grand melee
		if (ruthlessPrecisionExpires == 0) and (grandMeleeExpires == 0) then
			if (currentComboPoints >= 5) and (rollTheBonesBuffCount < 2) then
				if MasterBlaster:ZeroCount(MasterBlaster.SpellList["Roll the Bones"],spellInCast,nextSpell1,nextSpell2) then
					d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Roll the Bones"])
					if ((d - timeshift) <= 0.5) then
						return MasterBlaster.SpellList["Roll the Bones"], meleeRange
					end
				end
			end
		end

        -- run through if we have 5 combo points, unless the buff is ruthless precision, then between the eyes
		if (currentComboPoints >= 5) then
			if (ruthlessPrecisionExpires > 0) then
				if MasterBlaster:ZeroCount(MasterBlaster.SpellList["Between the Eyes"],spellInCast,nextSpell1,nextSpell2) then
					d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Between the Eyes"])
					if ((d - timeshift) <= 0.5) then
						return MasterBlaster.SpellList["Between the Eyes"], meleeRange
					end
				end
			else
				if MasterBlaster:ZeroCount(MasterBlaster.SpellList["Run Through"],spellInCast,nextSpell1,nextSpell2) then
					d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Run Through"])
					if ((d - timeshift) <= 0.5) then
						return MasterBlaster.SpellList["Run Through"], meleeRange
					end
				end
			end
		end

        -- saber slash to generate combo points, or use pistol shot with opportunity buff
		if (currentComboPoints < 5) then
			if (opportunityBuff ~= nil) then
				if MasterBlaster:ZeroCount(MasterBlaster.SpellList["Pistol Shot"],spellInCast,nextSpell1,nextSpell2) then
					d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Pistol Shot"])
					if ((d - timeshift) <= 0.5) then
						return MasterBlaster.SpellList["Pistol Shot"], meleeRange
					end
				end
			end

            d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Saber Slash"])
            if ((d - timeshift) <= 0.5) then
                return MasterBlaster.SpellList["Saber Slash"], meleeRange
            end
        end

		-- if we made it this far and found nothing to cast, rip
		return "", meleeRange
	end;

	MiscSpell = function(self)
		-- no particular category
		local d

        -- show if blade flurry is active
        local bladeFlurryActive = MasterBlaster:hasBuff("player",MasterBlaster.SpellList["Blade Flurry"]);
		if (bladeFlurryActive ~= nil) then
			return MasterBlaster.SpellList["Blade Flurry"]
		end

		return ""
	end;

	IntSpell = function(self)
		-- interruptions
		local d

		if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Kick"]) then
			d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Kick"])
			if ((IsSpellInRange(MasterBlaster.SpellList["Kick"], "target") == 1) and (d) and (d < 0.5)) then
				--- kick to interupt channel spell
				_, _, _, _, _, _, _, notInterruptible = UnitChannelInfo("target")
				if (notInterruptible == false) then
					return MasterBlaster.SpellList["Kick"]
				end

				--- kick to interupt cast spell
				_, _, _, _, _, _, _, _, notInterruptible = UnitCastingInfo("target")
				if (notInterruptible == false)  then
					return MasterBlaster.SpellList["Kick"]
				end
			end
		end

		return ""
	end;

	MajorSpell = function(self)
		-- major dps cooldowns
		local d, name

        -- marked for death
        if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Marked for Death"]) then
			d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Marked for Death"])
			if d <= MasterBlaster.lastBaseGCD then
				return MasterBlaster.SpellList["Marked for Death"]
			end
		end

		-- adrenaline rush
		if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Adrenaline Rush"]) then
			d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Adrenaline Rush"])
			if d <= MasterBlaster.lastBaseGCD then
				return MasterBlaster.SpellList["Adrenaline Rush"]
			end
		end

        -- curse of the dreadblades
        if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Curse of the Dreadblades"]) then
			d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Curse of the Dreadblades"])
			if d <= MasterBlaster.lastBaseGCD then
				return MasterBlaster.SpellList["Curse of the Dreadblades"]
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
			-- fan of knives if available
			if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Fan of Knives"]) then
				d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Fan of Knives"])
				if d <= MasterBlaster.lastBaseGCD then
					return MasterBlaster.SpellList["Fan of Knives"]
				end
			end
		end

		return ""
	end;
};
