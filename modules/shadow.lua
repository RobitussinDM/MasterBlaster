local L = MasterBlaster.Locals;

MasterBlaster:RegisterModule("shadow");

MasterBlaster.shadow = {
	Initialize = function(self)
		-- spells available to the shadow spec
		MasterBlaster:LoadSpells({
            ["Levitate"] = GetSpellInfo(1706),
			["Mind Blast"] = GetSpellInfo(8092),
			["Mind Bomb"] = GetSpellInfo(205369),
			["Mind Flay"] = GetSpellInfo(15407),
            ["Mindbender"] = GetSpellInfo(200174),
            ["Shadow Crash"] = GetSpellInfo(205385),
			["Shadow Word: Death"] = GetSpellInfo(199911),
			["Shadow Word: Pain"] = GetSpellInfo(589),
			["Shadowfiend"] = GetSpellInfo(34433),
			["Shadowform"] = GetSpellInfo(232698),
			["Silence"] = GetSpellInfo(15487),
            ["Surrender to Madness"] = GetSpellInfo(193223),
			["Vampiric Embrace"] = GetSpellInfo(15286),
			["Vampiric Touch"] = GetSpellInfo(34914),
            ["Void Bolt"] = GetSpellInfo(228266),
			["Void Eruption"] = GetSpellInfo(228260),
			["Void Torrent"] = GetSpellInfo(205065),
            ["Voidform Buff"] = GetSpellInfo(194249)
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

			-- no spell in cast, check global cd via Levitate
			if (MasterBlaster.SpellList["Levitate"]) then
				local globalCooldown = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Levitate"])
				if (globalCooldown) then
					timeshift = timeshift + MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Levitate"])
				else
					timeshift = timeshift + MasterBlaster.lastBaseGCD
				end
			else
				timeshift = timeshift + MasterBlaster.lastBaseGCD
			end
		end

		-- get target's shadow word: pain debuff information
		local swpDebuff, _, _, _, _, swpDuration,swpExpiration, unitCaster = MasterBlaster:hasDeBuff("target", MasterBlaster.SpellList["Shadow Word: Pain"], "player");
		if (not swpExpiration) then
			swpExpiration = 0
			swpDuration = 0
		end

        -- get target's vampiric touch debuff information
		local vampiricTouchDebuff, _, _, _, _, vampiricTouchDuration,vampiricTouchExpiration, unitCaster = MasterBlaster:hasDeBuff("target", MasterBlaster.SpellList["Vampiric Touch"], "player");
		if (not vampiricTouchExpiration) then
			vampiricTouchExpiration = 0
			vampiricTouchDuration = 0
		end

		-- get unit power variables
		local currentInsanity = UnitPower("player", 13)
		local maximumInsanity = UnitPowerMax("player", 13)

        -- get shadow word: death charges and adjust charges based on how far in the future the adivser goes
		local swdCharges, _, cooldownStart, cooldownLength = GetSpellCharges(MasterBlaster.SpellList["Shadow Word: Death"]);
		swdCharges = swdCharges - MasterBlaster:Count(MasterBlaster.SpellList["Shadow Word: Death"], spellInCast,nextSpell1,nextSpell2);
		if (((cooldownStart + cooldownLength)- currentTime) - timeshift <= 0) then
			swdCharges = swdCharges + 1
		end

		-- check if voidform is active
		local voidformActive = MasterBlaster:hasBuff("player",MasterBlaster.SpellList["Voidform Buff"]);

        -- make sure we're in shadowform
        if (not voidformActive) then
            if (not MasterBlaster:hasBuff("player", MasterBlaster.SpellList["Shadowform"])) then
                if MasterBlaster:ZeroCount(MasterBlaster.SpellList["Shadowform"],spellInCast,nextSpell1,nextSpell2) then
                    return MasterBlaster.SpellList["Shadowform"], meleeRange
                end
            end
        end

		-- shadow word: pain if not on the target and not talented into misery
		if MasterBlaster.talents[6] ~= 2 then
			if (swpDebuff == nil) then
				if (MasterBlaster:ZeroCount(MasterBlaster.SpellList["Shadow Word: Pain"],spellInCast,nextSpell1,nextSpell2)) then
					return MasterBlaster.SpellList["Shadow Word: Pain"]
				end
			end
		end

        -- vampiric touch if not on the target
		if (vampiricTouchDebuff == nil) then
			if (MasterBlaster:ZeroCount(MasterBlaster.SpellList["Vampiric Touch"],spellInCast,nextSpell1,nextSpell2)) then
				return MasterBlaster.SpellList["Vampiric Touch"]
			end
		end

        -- shadow word: death if available
		if (swdCharges > 0) and MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Shadow Word: Death"]) then
			d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Shadow Word: Death"])
            if ((d - timeshift) <= 0.5) then
                return MasterBlaster.SpellList["Shadow Word: Death"]
            end
		end

        -- if we are in voidform, use the voidform priority list
        if (voidformActive) then
             -- void bolt whenever possible
            if (MasterBlaster:ZeroCount(MasterBlaster.SpellList["Void Bolt"],spellInCast,nextSpell1,nextSpell2)) then
                d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Void Bolt"])
                if ((d - timeshift) <= 0.5) then
                    return MasterBlaster.SpellList["Void Bolt"]
                end
            end

            -- mind blast
            if (MasterBlaster:ZeroCount(MasterBlaster.SpellList["Mind Blast"],spellInCast,nextSpell1,nextSpell2)) then
                d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Mind Blast"])
                if ((d - timeshift) <= 0.5) then
                    return MasterBlaster.SpellList["Mind Blast"]
                end
            end

            -- void torrent
            if (MasterBlaster:ZeroCount(MasterBlaster.SpellList["Void Torrent"],spellInCast,nextSpell1,nextSpell2)) then
                d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Void Torrent"])
                if ((d - timeshift) <= 0.5) then
                    return MasterBlaster.SpellList["Void Torrent"]
                end
            end

        else
            -- if we're at maximum insanity, cast void eruption to enter void form
            if (currentInsanity == 100) then
                if (MasterBlaster:ZeroCount(MasterBlaster.SpellList["Void Eruption"],spellInCast,nextSpell1,nextSpell2)) then
                    d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Void Eruption"])
                    if ((d - timeshift) <= 0.5) then
                        return MasterBlaster.SpellList["Void Eruption"]
                    end
                end
            end

            -- mind blast
            if (MasterBlaster:ZeroCount(MasterBlaster.SpellList["Mind Blast"],spellInCast,nextSpell1,nextSpell2)) then
                d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Mind Blast"])
                if ((d - timeshift) <= 0.5) then
                    return MasterBlaster.SpellList["Mind Blast"]
                end
            end

        end

		-- mind flay as filler (voidform or not)
		if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Mind Flay"])then
			return MasterBlaster.SpellList["Mind Flay"]
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

		if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Silence"]) then
			d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Silence"])
			if ((IsSpellInRange(MasterBlaster.SpellList["Silence"], "target") == 1) and (d) and (d < 0.5)) then
				--- silence to interupt channel spell
				_, _, _, _, _, _, _, notInterruptible = UnitChannelInfo("target")
				if (notInterruptible == false) then
					return MasterBlaster.SpellList["Silence"]
				end

				--- silence to interupt cast spell
				_, _, _, _, _, _, _, _, notInterruptible = UnitCastingInfo("target")
				if (notInterruptible == false)  then
					return MasterBlaster.SpellList["Silence"]
				end
			end
		end

		return ""
	end;

	MajorSpell = function(self)
		-- major dps cooldowns
		local d, name

		-- mindbender
		if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Mindbender"]) then
			d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Mindbender"])
			if d <= MasterBlaster.lastBaseGCD then
				return MasterBlaster.SpellList["Mindbender"]
			end
		end
		
		-- shadowfiend
		if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Shadowfiend"]) then
            d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Shadowfiend"])
            if d <= MasterBlaster.lastBaseGCD then
                return MasterBlaster.SpellList["Shadowfiend"]
            end
        end

        -- surrender to madness
        if MasterBlaster.talents[7] == 3 then
            if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Surrender to Madness"]) then
                d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Surrender to Madness"])
                if d <= MasterBlaster.lastBaseGCD then
                    return MasterBlaster.SpellList["Surrender to Madness"]
                end
            end
        end

		return ""
	end;

	AoeSpell = function(self)
		-- aoe on target
		local d

		if (MasterBlaster.person["foeCount"] > 1) then
			-- use shadow crash if available
			if MasterBlaster.talents[7] == 2 then
				if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Shadow Crash"]) then
					d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Shadow Crash"])
					if d <= 0.5 then
						return MasterBlaster.SpellList["Shadow Crash"]
					end
				end
			end
		end

		return ""
	end;
};
