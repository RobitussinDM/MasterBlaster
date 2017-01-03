-------------------------------------------------------------------------------
-- GUI functions and structures for MasterBlaster
-------------------------------------------------------------------------------

local L = MasterBlaster.Locals

-- used to load spells into the advisor
function MasterBlaster:SetTexture(frame,icon)
	frame:SetTexture(icon)
end

-- used to create config controls
function MasterBlaster:CreateCheckButton(name, parent, table, field)
	local button = CreateFrame('CheckButton', parent:GetName() .. name, parent, 'OptionsCheckButtonTemplate')
	local frame = _G[button:GetName() .. 'Text']
	frame:SetText(name)
	frame:SetTextColor(1, 1, 1, 1)
	frame:SetFontObject(GameFontNormal)
	button:SetScript("OnShow", 
		function (self) 
			self:SetChecked(table[field]) 
			self.origValue = table[field] or self.origValue
		end 
	)
	button:SetScript("OnClick", 
		function (self, button, down) 
			table[field] = not table[field]
		end
	)

	function button:Restore() 
		table[field] = self.origValue 
	end 
	return button 
end

-- used to create config controls
function MasterBlaster:CreateSlider(text, parent, low, high, step)
	local name = parent:GetName() .. text
	local slider = CreateFrame('Slider', name, parent, 'OptionsSliderTemplate')
	slider:SetScript('OnMouseWheel', Slider_OnMouseWheel)
	slider:SetMinMaxValues(low, high)
	slider:SetValueStep(step)
	slider:EnableMouseWheel(true)
	_G[name .. 'Text']:SetText(text)
	_G[name .. 'Low']:SetText('')
	_G[name .. 'High']:SetText('')
	local text = slider:CreateFontString(nil, 'BACKGROUND')
	text:SetFontObject('GameFontHighlightSmall')
	text:SetPoint('LEFT', slider, 'RIGHT', 7, 0)
	slider.valText = text
	return slider
end

-- used to create config controls
function MasterBlaster:CreateButton(text, parent)
	local name = parent:GetName() .. text
	local button = CreateFrame('Button', name, parent, 'UIPanelButtonTemplate')
	_G[name .. 'Text']:SetText(text)
	local text = button:CreateFontString(nil, 'BACKGROUND')
	text:SetFontObject('GameFontHighlightSmall')
	text:SetPoint('LEFT', button, 'RIGHT', 7, 0)
	button.valText = text
	return button
end

-- store changes made in the config
function MasterBlaster:ApplySettings()
	MasterBlaster:InitSettings()
	if (not MasterBlasterDB.locked) then
		MasterBlaster:UnlockFrames()
	else
		if (MasterBlaster.displayFrame) then
			MasterBlaster.displayFrame:EnableMouse(false)
			MasterBlaster.displayFrame:SetMovable(false)
			MasterBlaster.displayFrame:SetBackdropColor(0, 0, 0, .0)
		end
	end
	if (not MasterBlaster:isEnabled()) then
		if (MasterBlaster.displayFrame) then
			MasterBlaster.displayFrame:Hide()
		end
	else
		if (MasterBlaster.displayFrame) then
			MasterBlaster.displayFrame:Show()
		end
	end
	if (MasterBlaster.displayFrame) then
		MasterBlaster.displayFrame:SetAlpha(MasterBlasterDB.alpha)
		MasterBlaster.displayFrame:SetScale(MasterBlasterDB.scale)
	end
	
	MasterBlaster.displayFrame_next:SetPoint("TOPLEFT", 45, -30)
	MasterBlaster.displayFrame_next1:SetPoint("TOPLEFT", 55, -10)
	MasterBlaster.displayFrame_next2:SetPoint("TOPLEFT", 65, 0)
	MasterBlaster.displayFrame_next:SetHeight(60)
	MasterBlaster.displayFrame_next:SetWidth(60)
	MasterBlaster.displayFrame_next1:SetHeight(40)
	MasterBlaster.displayFrame_next1:SetWidth(40)
	MasterBlaster.displayFrame_next2:SetHeight(20)
	MasterBlaster.displayFrame_next2:SetWidth(20)
	
	MasterBlaster.displayFrame_next1:Show();
	MasterBlaster.displayFrame_next2:Show();
end

-- persist config settings to the database
function MasterBlaster:StoreUIValues()
    for i,v in pairs(MasterBlasterDB) do
		MasterBlaster.prevDB[i]=v
    end
end

-- undo changes, re-apply what was previously in the database
function MasterBlaster:ReStoreUIValues()
    for i,v in pairs(MasterBlaster.prevDB) do
		MasterBlasterDB[i]=v
    end
end

-- create the interface for the user to configure MasterBlaster
function MasterBlaster:CreateConfig()
	if (MasterBlaster.configPanel ~= nil) then
		return;
	end
	
	MasterBlaster.configPanel = CreateFrame( "Frame", "MasterBlasterConfigPanel", UIParent );
	-- Register in the Interface Addon Options GUI
	-- Set the name for the Category for the Options Panel
	MasterBlaster.configPanel.name = "MasterBlaster";

	local EnableBtn = MasterBlaster:CreateCheckButton(L.CONFIG_ENABLED, MasterBlaster.configPanel, MasterBlasterDB, "enabled")
	EnableBtn:SetPoint('TOPLEFT', 10, -8)

	local LockBtn = MasterBlaster:CreateCheckButton(L.CONFIG_LOCK_FRAMES, MasterBlaster.configPanel, MasterBlasterDB, "locked")
	LockBtn:SetPoint('TOPLEFT', 10, -38)

	local Scale = MasterBlaster:CreateSlider(L.CONFIG_SPELL_ADV_SCALE, MasterBlaster.configPanel, .25, 3, .1)
	Scale:SetScript('OnShow', function(self)
		self.onShow = true
		MasterBlaster:StoreUIValues()
		self:SetValue(MasterBlasterDB.scale)
		self.onShow = nil
	end)
	Scale:SetScript('OnValueChanged', function(self, value)
		self.valText:SetText(format('%.1f', value))
		if not self.onShow then
			MasterBlasterDB.scale=value
			MasterBlaster.displayFrame:SetScale(value)
		end
	end)
	Scale:SetPoint("TOPLEFT",10,-78)
	Scale:Show()

	local Alpha = MasterBlaster:CreateSlider(L.CONFIG_SPELL_ADV_ALPHA, MasterBlaster.configPanel, .0, 1, .1)
	Alpha:SetScript('OnShow', function(self)
		self.onShow = true
		self:SetValue(MasterBlasterDB.alpha)
		self.onShow = nil
	end)
	Alpha:SetScript('OnValueChanged', function(self, value)
		self.valText:SetText(format('%.1f', value))
		if not self.onShow then
			MasterBlasterDB.alpha=value
			MasterBlaster.displayFrame:SetAlpha(value)
		end
	end)
	Alpha:SetPoint("TOPLEFT",200,-78)
	Alpha:Show()

	local ResetBtn = MasterBlaster:CreateButton(L.CONFIG_RESET_POSITIONS, MasterBlaster.configPanel)
	ResetBtn:SetWidth(160)
	ResetBtn:SetHeight(22)
	ResetBtn:SetScript('OnClick', function()
		MasterBlaster:ResetPosition()
	end)
	ResetBtn:SetPoint("TOPLEFT",10,-118)
	ResetBtn:Show()
	
	MasterBlaster.configPanel.okay = function()
		MasterBlaster:ApplySettings()
	end
	MasterBlaster.configPanel.cancel = function()
		-- cancel button pressed, revert changes
		MasterBlaster:ReStoreUIValues()
		MasterBlaster:ApplySettings()
	end
	MasterBlaster.configPanel.default = function()
		-- default button pressed, reset setting
		MasterBlasterDB.scale = 1
		MasterBlasterDB.locked = false
		MasterBlasterDB.enabled = true
		MasterBlasterDB.alpha = 0.8
		MasterBlasterDB.version = MasterBlaster.versionNumber;
		MasterBlaster:ResetPosition()
	end

	-- always show frame if config panel is open
	MasterBlaster.configPanel:SetScript('OnShow', function(self)
		MasterBlaster:Debug("Options", "onShow");
		self.onShow = true
		MasterBlaster:DecideSpells()
		MasterBlaster.ShowUnitPower()
		self.onShow = nil
	end)
	MasterBlaster.configPanel:SetScript('OnHide', function(self)
		self.onHide = true
		MasterBlaster:DecideSpells()
		MasterBlaster.ShowUnitPower()
		self.onHide = nil
	end)
	-- Add the panel to the Interface Options
	InterfaceOptions_AddCategory(MasterBlaster.configPanel)
	
	MasterBlaster.configPanel:Hide();

	return MasterBlaster.configPanel;
end

-- reset the advisor to a default position
function MasterBlaster:ResetPosition()
	MasterBlasterDB.x = 0
	MasterBlasterDB.y = -100
	MasterBlasterDB.relativePoint = "CENTER"
	MasterBlaster.displayFrame:ClearAllPoints()
	MasterBlaster.displayFrame:SetPoint(MasterBlasterDB.relativePoint,MasterBlasterDB.x,MasterBlasterDB.y)

end

-- enable moving of the spell advisor
function MasterBlaster:MakeDraggable(frame,x_name,y_name,rp_name)
	frame:SetBackdropColor(0, 0, 0, .3)
	frame:EnableMouse(true)
	frame:SetMovable(true)
	frame:SetClampedToScreen(true)
	frame:SetScript("OnMouseDown", function(self) self:StartMoving(); self:SetBackdropColor(0, 0, 0, .6); end)
	frame:SetScript("OnMouseUp", function(self)
		self:StopMovingOrSizing()
		if (MasterBlaster.locked) then
			self:SetBackdropColor(0, 0, 0, 0)
		else
			self:SetBackdropColor(0, 0, 0, .3)
		end
		local _,_,rp,x,y = self:GetPoint()
		MasterBlasterDB[x_name] = x
		MasterBlasterDB[y_name] = y
		MasterBlasterDB[rp_name] = rp
	end)
	frame:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing();
		if (MasterBlaster.locked) then
			self:SetBackdropColor(0, 0, 0, 0)
		else
			self:SetBackdropColor(0, 0, 0, .3)
		end
		local _,_,rp,x,y = self:GetPoint()
		MasterBlasterDB[x_name] = x
		MasterBlasterDB[y_name] = y
		MasterBlasterDB[rp_name] = rp
	end)
end

-- enable moving of the spell advisor
function MasterBlaster:UnlockFrames()
	MasterBlaster:MakeDraggable(MasterBlaster.displayFrame,"x","y","relativePoint")
end

-- create the spell advisor and all the sub-frames
function MasterBlaster:CreateGUI()
	local t
	local displayFrame = CreateFrame("Frame","MasterBlasterDisplayFrame",UIParent)
	displayFrame:SetFrameStrata("BACKGROUND")
	displayFrame:SetWidth(150)
	displayFrame:SetHeight(120)
	displayFrame:SetBackdrop({
          bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", tile = true, tileSize = 32,
	})
	displayFrame:SetBackdropColor(0, 0, 0, .0)
	displayFrame:SetPoint(MasterBlasterDB.relativePoint,MasterBlasterDB.x,MasterBlasterDB.y)
	
	local displayFrame_next = CreateFrame("Frame","$parent_next", MasterBlasterDisplayFrame)
	local displayFrame_next1 = CreateFrame("Frame","$parent_next1", MasterBlasterDisplayFrame)
	local displayFrame_next2 = CreateFrame("Frame","$parent_next2", MasterBlasterDisplayFrame)
	local displayFrame_misc = CreateFrame("Frame", "$parent_misc", MasterBlasterDisplayFrame)
	local displayFrame_misc_charges = CreateFrame("Frame","$parent_misc_charges", MasterBlasterDisplayFrame)
	local displayFrame_int = CreateFrame("Frame","$parent_int", MasterBlasterDisplayFrame)
	local displayFrame_major = CreateFrame("Frame","$parent_major", MasterBlasterDisplayFrame)
	local displayFrame_aoe = CreateFrame("Frame", "$parent_aoe", MasterBlasterDisplayFrame)
	local displayFrame_power = CreateFrame("Frame","$parent_power", MasterBlasterDisplayFrame)
	
	displayFrame_next:SetWidth(60)
	displayFrame_next1:SetWidth(40)
	displayFrame_next2:SetWidth(20)
	displayFrame_misc:SetWidth(40)
	displayFrame_misc_charges:SetWidth(40)
	displayFrame_int:SetWidth(40)
	displayFrame_major:SetWidth(40)
	displayFrame_aoe:SetWidth(40)
	displayFrame_power:SetWidth(60)

	displayFrame_next:SetFrameLevel(10)
	displayFrame_next1:SetFrameLevel(5)
	displayFrame_next2:SetFrameLevel(0)
	
	displayFrame_next:SetHeight(60)
	displayFrame_next1:SetHeight(40)
	displayFrame_next2:SetHeight(20)
	displayFrame_misc:SetHeight(40)
	displayFrame_misc_charges:SetHeight(40)
	displayFrame_int:SetHeight(40)
	displayFrame_major:SetHeight(40)
	displayFrame_aoe:SetHeight(40)
	displayFrame_power:SetHeight(30)
	
	displayFrame_next:SetPoint("TOPLEFT", 45, -30)
	displayFrame_next1:SetPoint("TOPLEFT", 55, -10)
	displayFrame_next2:SetPoint("TOPLEFT", 65, 0)
	
	displayFrame_misc:SetPoint("TOPLEFT", 0, 0)
	displayFrame_misc_charges:SetPoint("TOPLEFT", 0, 0)
	displayFrame_int:SetPoint("TOPLEFT", 110, 0)
	displayFrame_major:SetPoint("TOPLEFT", 0, -80)
	displayFrame_aoe:SetPoint("TOPLEFT", 110, -80)
	displayFrame_power:SetPoint("TOPLEFT", 45, -90)
	
	t = displayFrame_next:CreateTexture(nil,"BACKGROUND")
	MasterBlaster:SetTexture(t, "")
	t:SetAllPoints(displayFrame_next)
	t:SetAlpha(1)
	displayFrame_next.texture = t
	MasterBlaster.textureList["next"] = t

	t = displayFrame_next1:CreateTexture(nil,"BACKGROUND")
	MasterBlaster:SetTexture(t,"")
	t:SetAllPoints(displayFrame_next1)
	t:SetAlpha(0.7)
	displayFrame_next1.texture = t
	MasterBlaster.textureList["next1"] = t

	t = displayFrame_next2:CreateTexture(nil,"BACKGROUND")
	MasterBlaster:SetTexture(t,"")
	t:SetAllPoints(displayFrame_next2)
	t:SetAlpha(0.5)
	displayFrame_next2.texture = t
	MasterBlaster.textureList["next2"] = t

	t = displayFrame_misc:CreateTexture(nil,"BACKGROUND")
	MasterBlaster:SetTexture(t,"")
	t:SetAllPoints(displayFrame_misc)
	t:SetAlpha(1)
	displayFrame_misc.texture = t
	MasterBlaster.textureList["misc"] = t

	t = displayFrame_misc_charges:CreateFontString("$parent_misc_charges_text","OVERLAY","NumberFontNormalLarge");
	t:SetAllPoints(displayFrame_misc_charges)
	t:SetAlpha(1)
	t:SetText("")
	MasterBlaster.textList["misc_charges"] = t
	
	t = displayFrame_int:CreateTexture(nil,"BACKGROUND")
	MasterBlaster:SetTexture(t,"")
	t:SetAllPoints(displayFrame_int)
	t:SetAlpha(1)
	displayFrame_int.texture = t
	MasterBlaster.textureList["int"] = t

	t = displayFrame_major:CreateTexture(nil,"BACKGROUND")
	MasterBlaster:SetTexture(t,"")
	t:SetAllPoints(displayFrame_major)
	t:SetAlpha(1)
	displayFrame_major.texture = t
	MasterBlaster.textureList["major"] = t

	t = displayFrame_aoe:CreateTexture(nil,"BACKGROUND")
	MasterBlaster:SetTexture(t,"")
	t:SetAllPoints(displayFrame_aoe)
	t:SetAlpha(1)
	displayFrame_aoe.texture = t
	MasterBlaster.textureList["aoe"] = t

	t = displayFrame_power:CreateFontString("$parent_power_text","ARTWORK","NumberFontNormalLarge");
	t:SetAllPoints(displayFrame_power)
	t:SetAlpha(1)
	t:SetText("")
	MasterBlaster.textList["power"] = t

	displayFrame:SetScript("OnUpdate", function(this, elapsed)
		MasterBlaster:OnUpdate(elapsed)
	end)
  
	local cooldownFrame = CreateFrame("Cooldown","$parent_cooldown", displayFrame_next, "CooldownFrameTemplate")
	cooldownFrame:SetHeight(60)
	cooldownFrame:SetWidth(60)
	cooldownFrame:ClearAllPoints()
	cooldownFrame:SetPoint("CENTER", displayFrame_next, "CENTER", 0, 0)
	
	displayFrame:SetAlpha(MasterBlasterDB.alpha)
	
	MasterBlaster.displayFrame = displayFrame
	MasterBlaster.displayFrame_next = displayFrame_next
	MasterBlaster.displayFrame_next1 = displayFrame_next1
	MasterBlaster.displayFrame_next2 = displayFrame_next2
	MasterBlaster.displayFrame_misc = displayFrame_misc
	MasterBlaster.displayFrame_misc_charges =  displayFrame_misc_charges
	MasterBlaster.displayFrame_int =  displayFrame_int
	MasterBlaster.displayFrame_major =  displayFrame_major
	MasterBlaster.displayFrame_aoe = displayFrame_aoe
	MasterBlaster.cooldownFrame = cooldownFrame

	if (not MasterBlasterDB.locked) then
		MasterBlaster:UnlockFrames()
	end

	DEFAULT_CHAT_FRAME:AddMessage("MasterBlaster " .. MasterBlaster.versionNumber .. " loaded")
end
