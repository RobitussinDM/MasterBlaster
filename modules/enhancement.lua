local L = MasterBlaster.Locals;

MasterBlaster:RegisterModule("enhancement");

MasterBlaster.enhancement = {
	Initialize = function(self)
		-- spells available to the enhancement spec
		MasterBlaster:LoadSpells({
            ["Ascendance"] = GetSpellInfo(114051),
            ["Boulderfist"] = GetSpellInfo(201897),
			["Boulderfist Buff"] = GetSpellInfo(218825),
            ["Crash Lightning"] = GetSpellInfo(187874),
            ["Doom Winds"] = GetSpellInfo(204945),
            ["Earthen Spike"] = GetSpellInfo(188089),
            ["Feral Spirit"] = GetSpellInfo(51533),
            ["Flametongue"] = GetSpellInfo(193796),
            ["Frostbrand"] = GetSpellInfo(196834),
            ["Fury of Air"] = GetSpellInfo(197211),
			["Fury of Air Buff"] = GetSpellInfo(197385),
            ["Ghost Wolf"] = GetSpellInfo(2645),
			["Hot Hand Buff"] = GetSpellInfo(215785),
			["Landslide Buff"] = GetSpellInfo(202004),
            ["Lava Lash"] = GetSpellInfo(60103),
            ["Lightning Bolt"] = GetSpellInfo(187837),
            ["Lightning Shield"] = GetSpellInfo(192106),
            ["Purge"] = GetSpellInfo(370),
            ["Rockbiter"] = GetSpellInfo(193786),
			["Stormbringer Buff"] = GetSpellInfo(201846),
            ["Stormstrike"] = GetSpellInfo(17364),
            ["Sundering"] = GetSpellInfo(197214),
            ["Wind Shear"] = GetSpellInfo(57994),
            ["Windsong"] = GetSpellInfo(201898),
		});
	end;

	-- determine the next spell to display
	NextSpell = function(self,timeshift,nextSpell1,nextSpell2)
		local currentTime = GetTime()
		local d

		-- if target is dead, return
		if (UnitHealth("target")<=0) then
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
			if ( (spellInCastEndTime - spellInCastStartTime) / 1000 ) < MasterBlaster.lastBaseGCD then
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

		-- check if in melee range
		local meleeRange = (IsSpellInRange(MasterBlaster.SpellList["Stormstrike"], "target") == 1)

		-- boulderfist to start if talented
		if MasterBlaster.talents[1] == 3 then
			local boulderfistCharges, _, cooldownStart, cooldownLength = GetSpellCharges(MasterBlaster.SpellList["Boulderfist"]);
			boulderfistCharges = boulderfistCharges - MasterBlaster:Count(MasterBlaster.SpellList["Boulderfist"], spellInCast,nextSpell1,nextSpell2);
			if (((cooldownStart + cooldownLength)- currentTime) - timeshift <= 0) then
				boulderfistCharges = boulderfistCharges + 1
			end

			-- keep boulderfist up
			if (not MasterBlaster:hasBuff("player", MasterBlaster.SpellList["Boulderfist Buff"])) then
				if MasterBlaster:ZeroCount(MasterBlaster.SpellList["Boulderfist"],spellInCast,nextSpell1,nextSpell2) then
					d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Boulderfist"])
					if ((d - timeshift) <= 0.5) then
						return MasterBlaster.SpellList["Boulderfist"], meleeRange
					end
				end
			end
		else
			-- if not using boulderfist, make sure rockbiter is up when using landslide
			if MasterBlaster.talents[7] == 2 then
				if (not MasterBlaster:hasBuff("player", MasterBlaster.SpellList["Landslide Buff"])) then
					if MasterBlaster:ZeroCount(MasterBlaster.SpellList["Rockbiter"],spellInCast,nextSpell1,nextSpell2) then
						return MasterBlaster.SpellList["Rockbiter"], meleeRange
					end
				end
			end
		end

		-- keep frostbrand up (if hailstorm talented)
		if MasterBlaster.talents[4] == 3 then
			if (not MasterBlaster:hasBuff("player", MasterBlaster.SpellList["Frostbrand"])) then
				if MasterBlaster:ZeroCount(MasterBlaster.SpellList["Frostbrand"],spellInCast,nextSpell1,nextSpell2) then
					d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Frostbrand"])
					if ((d - timeshift) <= 0.5) then
						return MasterBlaster.SpellList["Frostbrand"], meleeRange
					end
				end
			end
		end

		-- if fury of air is talented and not present, use it
		if (not MasterBlaster:hasBuff("player", MasterBlaster.SpellList["Fury of Air Buff"])) then
			if MasterBlaster:ZeroCount(MasterBlaster.SpellList["Fury of Air"],spellInCast,nextSpell1,nextSpell2) then
				d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Fury of Air"])
				if ((d - timeshift) <= 0.5) then
					return MasterBlaster.SpellList["Fury of Air"], meleeRange
				end
			end
		end

		-- doom winds
		if MasterBlaster:ZeroCount(MasterBlaster.SpellList["Doom Winds"],spellInCast,nextSpell1,nextSpell2) and MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Doom Winds"]) then
			d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Doom Winds"])
			if ((d - timeshift) <= 0.5) then
				return MasterBlaster.SpellList["Doom Winds"], meleeRange
			end
		end

		-- earthen spike if talented
		if MasterBlaster.talents[7] == 3 then
			if (UnitPower("player",11) >= 30) and (MasterBlaster:ZeroCount(MasterBlaster.SpellList["Earthen Spike"],spellInCast,nextSpell1,nextSpell2)) then
				d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Earthen Spike"])
				if ((d - timeshift) <= 0.5) then
					return MasterBlaster.SpellList["Earthen Spike"], meleeRange
				end
			end
		end

		-- lightning bolt if overcharge is talented and above 50 maelstrom
		if MasterBlaster.talents[5] == 2 then
			if (UnitPower("player",11) >= 50) and (MasterBlaster:ZeroCount(MasterBlaster.SpellList["Lightning Bolt"],spellInCast,nextSpell1,nextSpell2)) then
				d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Lightning Bolt"])
				if ((d - timeshift) <= 0.5) then
					return MasterBlaster.SpellList["Lightning Bolt"], meleeRange
				end
			end
		end

		-- use windsong if talented
		if MasterBlaster:ZeroCount(MasterBlaster.SpellList["Windsong"],spellInCast,nextSpell1,nextSpell2) and MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Windsong"]) then
			d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Windsong"])
			if ((d - timeshift) <= 0.5) then
				return MasterBlaster.SpellList["Windsong"], meleeRange
			end
		end

		-- keep flametongue up
		if (not MasterBlaster:hasBuff("player", MasterBlaster.SpellList["Flametongue"])) then
			if MasterBlaster:ZeroCount(MasterBlaster.SpellList["Flametongue"],spellInCast,nextSpell1,nextSpell2) then
				d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Flametongue"])
				if ((d - timeshift) <= 0.5) then
					return MasterBlaster.SpellList["Flametongue"], meleeRange
				end
			end
		end

		-- frostbrand if hailstorm is talented and the buff is < 4.5 seconds remaining
		if MasterBlaster.talents[4] == 3 then
			local _, _, _, _, _, _, frostbrandExpires = MasterBlaster:hasBuff("player",MasterBlaster.SpellList["Frostbrand"]);
			if frostbrandExpires ~= nil then
				if ((frostbrandExpires - currentTime - timeshift) < 4.5) then
					if MasterBlaster:ZeroCount(MasterBlaster.SpellList["Frostbrand"],spellInCast,nextSpell1,nextSpell2) then
						d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Frostbrand"])
						if ((d - timeshift) <= 0.5) then
							return MasterBlaster.SpellList["Frostbrand"], meleeRange
						end
					end
				end
			end
		end

		-- flametongue the buff is < 4.5 seconds remaining
		local _, _, _, _, _, _, flametongueExpires = MasterBlaster:hasBuff("player",MasterBlaster.SpellList["Flametongue"]);
		if flametongueExpires ~= nil then
			if ((flametongueExpires - currentTime - timeshift) < 4.5) then
				if MasterBlaster:ZeroCount(MasterBlaster.SpellList["Flametongue"],spellInCast,nextSpell1,nextSpell2) then
					d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Flametongue"])
					if ((d - timeshift) <= 0.5) then
						return MasterBlaster.SpellList["Flametongue"], meleeRange
					end
				end
			end
		end

		-- stormstrike if available
		if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Stormstrike"]) then
			d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Stormstrike"])
			if ((d - timeshift) <= 0.5) then
				return MasterBlaster.SpellList["Stormstrike"], meleeRange
			end
		end

		-- boulderfist if talented and at 2 charges within adviser future
		-- calculation is done above
		if MasterBlaster.talents[1] == 3 then
			if boulderfistCharges == 2 then
				if MasterBlaster:ZeroCount(MasterBlaster.SpellList["Boulderfist"],spellInCast,nextSpell1,nextSpell2) then
					d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Boulderfist"])
					if ((d - timeshift) <= 0.5) then
						return MasterBlaster.SpellList["Boulderfist"], meleeRange
					end
				end
			end
		end


		-- crash lightning if crashing storm talented and above 80 maelstrom
		if MasterBlaster.talents[6] == 1 then
			if (UnitPower("player",11) >= 80) and (MasterBlaster:ZeroCount(MasterBlaster.SpellList["Crash Lightning"],spellInCast,nextSpell1,nextSpell2)) then
				d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Crash Lightning"])
				if ((d - timeshift) <= 0.5) then
					return MasterBlaster.SpellList["Crash Lightning"], meleeRange
				end
			end
		end

		-- sundering if talented and above 70 maelstrom
		if MasterBlaster.talents[6] == 3 then
			if (UnitPower("player",11) >= 70) and (MasterBlaster:ZeroCount(MasterBlaster.SpellList["Sundering"],spellInCast,nextSpell1,nextSpell2)) then
				d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Sundering"])
				if ((d - timeshift) <= 0.5) then
					return MasterBlaster.SpellList["Sundering"], meleeRange
				end
			end
		end

		-- lava lash if above 80 maelstrom
		if (UnitPower("player",11) >= 80) and (MasterBlaster:ZeroCount(MasterBlaster.SpellList["Lava Lash"],spellInCast,nextSpell1,nextSpell2)) then
			d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Lava Lash"])
			if ((d - timeshift) <= 0.5) then
				return MasterBlaster.SpellList["Lava Lash"], meleeRange
			end
		end

		-- boulderfist / flametongue if nothing else availabe if boulderfist talented
		if MasterBlaster.talents[1] == 3 then
			-- boulderfist first
			if MasterBlaster:ZeroCount(MasterBlaster.SpellList["Boulderfist"],spellInCast,nextSpell1,nextSpell2) then
				d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Boulderfist"])
				if ((d - timeshift) <= 0.5) then
					return MasterBlaster.SpellList["Boulderfist"], meleeRange
				end
			end

			-- otherwise flametongue as filler
			if MasterBlaster:ZeroCount(MasterBlaster.SpellList["Flametongue"],spellInCast,nextSpell1,nextSpell2) then
				d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Flametongue"])
				if ((d - timeshift) <= 0.5) then
					return MasterBlaster.SpellList["Flametongue"], meleeRange
				end
			end
		else
			-- otherwise rockbiter as filler
			return MasterBlaster.SpellList["Rockbiter"], meleeRange
		end

		-- if we made it this far and found nothing to cast, rip
		return ""
	end;

	MiscSpell = function(self)
		-- no particular category
		local d

		-- show lavalash if hot hand talent procs
		name = MasterBlaster:hasBuff("player",MasterBlaster.SpellList["Hot Hand Buff"])
		if (name ~= nil) then
			if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Lava Lash"]) then
				return MasterBlaster.SpellList["Lava Lash"]
			end
		end

		-- show stormbringer buff with proc count
		name, _, _, charges = MasterBlaster:hasBuff("player",MasterBlaster.SpellList["Stormbringer Buff"])
		if (name ~= nil) then
			if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Stormstrike"]) then
				return MasterBlaster.SpellList["Stormstrike"], nil, charges
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

		-- ascendance
		if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Ascendance"]) then
			name = MasterBlaster:hasBuff("player",MasterBlaster.SpellList["Ascendance Buff"])
			if (name == nil) then
				d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Ascendance"])
				if d <= MasterBlaster.lastBaseGCD then
					return MasterBlaster.SpellList["Ascendance"]
				end
			end
		end

		-- feral spirit
		if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Feral Spirit"]) then
			d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Feral Spirit"])
			if d <= MasterBlaster.lastBaseGCD then
				return MasterBlaster.SpellList["Feral Spirit"]
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
			if MasterBlaster:SpellAvailable(MasterBlaster.SpellList["Crash Lightning"]) then
				d = MasterBlaster:GetSpellCooldownRemaining(MasterBlaster.SpellList["Crash Lightning"])
				if d <= MasterBlaster.lastBaseGCD then
					return MasterBlaster.SpellList["Crash Lightning"]
				end
			end
		end

		return ""
	end;
};
