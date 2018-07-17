local L = MasterBlaster.Locals;

MasterBlaster:RegisterModule("guardian");

MasterBlaster.guardian = {
	Initialize = function(self)
		-- spells available to the guardian druid spec
		MasterBlaster:LoadSpells({
            ["Barkskin"] = GetSpellInfo(22812),
            ["Bear Form"] = GetSpellInfo(5487),
            ["Frenzied Regeneration"] = GetSpellInfo(22842),
            ["Gore Buff"] = GetSpellInfo(93622),
            ["Ironfur"] = GetSpellInfo(192081),
            ["Mangle"] = GetSpellInfo(33917),
            ["Maul"] = GetSpellInfo(6807),
            ["Mighty Bash"] = GetSpellInfo(5211),
            ["Moonfire"] = GetSpellInfo(8921),
            ["Rage of the Sleeper"] = GetSpellInfo(200851),
            ["Skull Bash"] = GetSpellInfo(106839),
            ["Survival Instincts"] = GetSpellInfo(61336),
            ["Swipe"] = GetSpellInfo(213771),
            ["Thrash"] = GetSpellInfo(77758)
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

			-- no spell in cast, check global cd via moonfire
			if (MasterBlaster.SpellList["Moonfire"]) then
				local globalCooldown = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Moonfire"])
				if (globalCooldown) then
					timeshift = timeshift + MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Moonfire"])
				else
					timeshift = timeshift + MasterBlaster.lastBaseGCD
				end
			else
				timeshift = timeshift + MasterBlaster.lastBaseGCD
			end
		end

        -- get target's moonfire debuff information
		local moonfireDebuff, _, _, _, _, moonfireDuration, moonfireExpiration, unitCaster = MasterBlaster:hasDeBuff("target", MasterBlaster.SpellList["Moonfire"], "player");
		if (not moonfireExpiration) then
			moonfireExpiration = 0
			moonfireDuration = 0
		end

		-- check if in melee range
		local meleeRange = (IsSpellInRange(MasterBlaster.SpellList["Mangle"], "target") == 1)

		-- get unit power variables
		local currentRage = UnitPower("player", 1)

		-- make sure we are in bear Form
		if (not MasterBlaster:hasBuff("player", MasterBlaster.SpellList["Bear Form"])) then
			if MasterBlaster:ZeroCount(MasterBlaster.SpellList["Bear Form"],spellInCast,nextSpell1,nextSpell2) then
				return MasterBlaster.SpellList["Bear Form"], meleeRange
			end
		end

        -- thrash if available
        if (MasterBlaster:ZeroCount(MasterBlaster.SpellList["Thrash"],spellInCast,nextSpell1,nextSpell2)) then
            d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Thrash"])
            if ((d - timeshift) <= 0.5) then
                return MasterBlaster.SpellList["Thrash"], meleeRange
            end
        end

        -- mangle if available
		if (MasterBlaster:ZeroCount(MasterBlaster.SpellList["Mangle"],spellInCast,nextSpell1,nextSpell2)) then
            d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Mangle"])
            if ((d - timeshift) <= 0.5) then
                return MasterBlaster.SpellList["Mangle"], meleeRange
            end
        end

        -- dump excess rage into maul
        if (currentRage > 75) then
            if MasterBlaster:ZeroCount(MasterBlaster.SpellList["Maul"],spellInCast,nextSpell1,nextSpell2) then
                d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Maul"])
                if ((d - timeshift) <= 0.5) then
                    return MasterBlaster.SpellList["Maul"], meleeRange
                end
			end
        end

		-- moonfire as filler
		if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Moonfire"]) then
			return MasterBlaster.SpellList["Moonfire"], meleeRange
		end
	end;

	MiscSpell = function(self)
		-- no particular category
		local d

        -- mangle reset from the gore buff
		name = MasterBlaster:hasBuff("player",MasterBlaster.SpellList["Gore Buff"])
		if (name ~= nil) then
			if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Mangle"]) then
				return MasterBlaster.SpellList["Mangle"]
			end
		end

		return ""
	end;

	IntSpell = function(self)
		-- interruptions, purge
		local d

		if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Skull Bash"]) then
			d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Skull Bash"])
			if ((IsSpellInRange(MasterBlaster.SpellList["Skull Bash"], "target") == 1) and (d) and (d < 0.5)) then
				--- skull bash to interupt channel spell
				_, _, _, _, _, _, _, notInterruptible = UnitChannelInfo("target")
				if (notInterruptible == false) then
					return MasterBlaster.SpellList["Skull Bash"]
				end

				--- skull bash to interupt cast spell
				_, _, _, _, _, _, _, _, notInterruptible = UnitCastingInfo("target")
				if (notInterruptible == false)  then
					return MasterBlaster.SpellList["Skull Bash"]
				end
			end
		end

        -- mighty bash as backup if talented
        if MasterBlaster.talents[4] == 1 then
            if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Mighty Bash"]) then
                d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Mighty Bash"])
                if ((IsSpellInRange(MasterBlaster.SpellList["Mighty Bash"], "target") == 1) and (d) and (d < 0.5)) then
                    --- mighty bash to interupt channel spell
                    _, _, _, _, _, _, _, notInterruptible = UnitChannelInfo("target")
                    if (notInterruptible == false) then
                        return MasterBlaster.SpellList["Mighty Bash"]
                    end
    
                    --- mighty bash to interupt cast spell
                    _, _, _, _, _, _, _, _, notInterruptible = UnitCastingInfo("target")
                    if (notInterruptible == false)  then
                        return MasterBlaster.SpellList["Mighty Bash"]
                    end
                end
            end
        end

		return ""
	end;

	MajorSpell = function(self)
		-- major dps cooldowns
		local d, name

		-- rage of the sleeper if you have it
		if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Rage of the Sleeper"]) then
			d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Rage of the Sleeper"])
			if d <= MasterBlaster.lastBaseGCD then
				return MasterBlaster.SpellList["Rage of the Sleeper"]
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

		if (MasterBlaster.person["foeCount"] > 1) then

			-- swipe if available
			if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Swipe"]) then
				d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Swipe"])
				if d <= MasterBlaster.lastBaseGCD then
					return MasterBlaster.SpellList["Swipe"]
				end
			end
		end

		return ""
	end;
};
