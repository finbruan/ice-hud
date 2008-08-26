local AceOO = AceLibrary("AceOO-2.0")
local SML = AceLibrary("LibSharedMedia-3.0")

local TargetOfTarget = AceOO.Class(IceElement)

TargetOfTarget.prototype.stackedDebuffs = nil
TargetOfTarget.prototype.buffSize = nil
TargetOfTarget.prototype.height = nil
TargetOfTarget.prototype.unit = nil
TargetOfTarget.prototype.hadTarget = nil


-- Constructor --
function TargetOfTarget.prototype:init()
	TargetOfTarget.super.prototype.init(self, "TargetOfTarget")

	self.buffSize = 12
	self.height = 15
	self.stackedDebuffs = {}
	self.unit = "targettarget"
	self.hadTarget = false

	self.scalingEnabled = true
end


-- OVERRIDE
function TargetOfTarget.prototype:GetOptions()
	local opts = TargetOfTarget.super.prototype.GetOptions(self)
	
	opts["vpos"] = {
		type = "range",
		name = "Vertical Position",
		desc = "Vertical Position",
		get = function()
			return self.moduleSettings.vpos
		end,
		set = function(v)
			self.moduleSettings.vpos = v
			self:Redraw()
		end,
		min = -300,
		max = 300,
		step = 10,
		disabled = function()
			return not self.moduleSettings.enabled
		end,
		order = 31
	}

	opts["showDebuffs"] = {
		type = "toggle",
		name = "Show stacking debuffs",
		desc = "Show stacking debuffs in ToT info",
		get = function()
			return self.moduleSettings.showDebuffs
		end,
		set = function(value)
			self.moduleSettings.showDebuffs = value
			self:UpdateBuffs()
		end,
		disabled = function()
			return not self.moduleSettings.enabled
		end,
		order = 32
	}
	
	opts["fontSize"] = {
		type = 'range',
		name = 'Font Size',
		desc = 'Font Size',
		get = function()
			return self.moduleSettings.fontSize
		end,
		set = function(v)
			self.moduleSettings.fontSize = v
			self:Redraw()
		end,
		min = 8,
		max = 20,
		step = 1,
		disabled = function()
			return not self.moduleSettings.enabled
		end,
		order = 33
	}
	
	opts["mouse"] = {
		type = 'toggle',
		name = 'Mouseover',
		desc = 'Toggle mouseover on/off',
		get = function()
			return self.moduleSettings.mouse
		end,
		set = function(v)
			self.moduleSettings.mouse = v
			self:Redraw()
		end,
		disabled = function()
			return not self.moduleSettings.enabled
		end,
		order = 34
	}
	
	opts["texture"] = {
		type = 'text',
		name = 'Texture',
		desc = 'ToT frame texture',
		get = function()
			return self.moduleSettings.texture
		end,
		set = function(v)
			self.moduleSettings.texture = v
			self:Redraw()
		end,
		disabled = function()
			return not self.moduleSettings.enabled
		end,
		validate = SML:List(SML.MediaType.STATUSBAR),
		order = 35
	}

	opts["sizeToGap"] = {
		type = 'toggle',
		name = 'Size to gap',
		desc = "Automatically size this module to the addon's 'gap' setting",
		get = function()
			return self.moduleSettings.sizeToGap
		end,
		set = function(v)
			self.moduleSettings.sizeToGap = v
			self:Redraw()
		end,
		disabled = function()
			return not self.moduleSettings.enabled
		end
	}

	opts["totWidth"] = {
		type = 'range',
		name = 'Width',
		desc = "Sets the width of this module if 'size to gap' is not set",
		min = 100,
		max = 600,
		step = 1,
		get = function()
			return self.moduleSettings.totWidth
		end,
		set = function(v)
			self.moduleSettings.totWidth = v
			self:Redraw()
		end,
		disabled = function()
			return not self.moduleSettings.enabled
		end,
		hidden = function()
			return self.moduleSettings.sizeToGap
		end
	}
	
	return opts
end


-- OVERRIDE
function TargetOfTarget.prototype:GetDefaultSettings()
	local defaults =  TargetOfTarget.super.prototype.GetDefaultSettings(self)
	defaults["vpos"] = -130
	defaults["showDebuffs"] = true
	defaults["fontSize"] = 15
	defaults["mouse"] = true
	defaults["texture"] = "Blizzard"
	defaults["sizeToGap"] = true
	defaults["totWidth"] = 200
	return defaults
end


-- OVERRIDE
function TargetOfTarget.prototype:Redraw()
	TargetOfTarget.super.prototype.Redraw(self)

	if (self.moduleSettings.enabled) then
		self:CreateFrame()
	end
end


function TargetOfTarget.prototype:Enable(core)
	TargetOfTarget.super.prototype.Enable(self, core)
	
	self:RegisterEvent("PLAYER_TARGET_CHANGED", "Update")
	self:ScheduleRepeatingEvent(self.elementName, self.Update, 0.2, self)
	RegisterUnitWatch(self.frame)
	
	self:Update()
end


function TargetOfTarget.prototype:Disable(core)
	TargetOfTarget.super.prototype.Disable(self, core)
	
	self:CancelScheduledEvent(self.elementName)
	
	UnregisterUnitWatch(self.frame)
end


-- 'Protected' methods --------------------------------------------------------

-- OVERRIDE
function TargetOfTarget.prototype:CreateFrame()
	if not (self.frame) then
		self.frame = CreateFrame("Button", "IceHUD_"..self.elementName, self.parent, "SecureUnitButtonTemplate")
		self.frame:SetAttribute("unit", self.unit)
	end

	self.frame:SetFrameStrata("BACKGROUND")
	if self.moduleSettings.sizeToGap then
		self.frame:SetWidth(self.settings.gap)
	else
		self.frame:SetWidth(self.moduleSettings.totWidth)
	end
	self.frame:SetHeight(self.height)
	self.frame:SetPoint("TOP", self.parent, "TOP", 0, self.moduleSettings.vpos)
	self.frame:SetScale(self.moduleSettings.scale)
	
	
	self.frame.unit = self.unit -- for blizz default tooltip handling
	
	if (self.moduleSettings.mouse) then
		self.frame:EnableMouse(true)
		self.frame:RegisterForClicks("AnyUp")
		
		self.frame:SetScript("OnEnter", function(frame) self:OnEnter(frame) end)
		self.frame:SetScript("OnLeave", function(frame) self:OnLeave(frame) end)
	else
		self.frame:EnableMouse(false)
		self.frame:RegisterForClicks()
		self.frame:SetScript("OnEnter", nil)
		self.frame:SetScript("OnLeave", nil)
	end

	
	self.frame:SetAttribute("type1", "target")
	self.frame:SetAttribute("unit", self.unit)


	self:CreateBarFrame()
	self:CreateToTFrame()
	self:CreateToTHPFrame()
	self:CreateDebuffFrame()
	
	-- click casting support
	ClickCastFrames = ClickCastFrames or {}
	ClickCastFrames[self.frame] = true
end


function TargetOfTarget.prototype:CreateBarFrame()
	if (not self.frame.bar) then
		self.frame.bar = CreateFrame("StatusBar", nil, self.frame)
	end

	self.frame.bar:SetFrameStrata("BACKGROUND")
	if self.moduleSettings.sizeToGap then
		self.frame.bar:SetWidth(self.settings.gap)
	else
		self.frame.bar:SetWidth(self.moduleSettings.totWidth)
	end
	self.frame.bar:SetHeight(self.height)

	self.frame.bar:SetPoint("LEFT", self.frame, "LEFT", 0, 0)

	if (not self.frame.bar.texture) then
		self.frame.bar.texture = self.frame.bar:CreateTexture()
	end
	self.frame.bar.texture:SetTexture(SML:Fetch(SML.MediaType.STATUSBAR, self.moduleSettings.texture))
	self.frame.bar.texture:SetAllPoints(self.frame.bar)
	self.frame.bar:SetStatusBarTexture(self.frame.bar.texture)
	
	
	if (not self.frame.bar.highLight) then
		self.frame.bar.highLight = self.frame.bar:CreateTexture(nil, "OVERLAY")
	end
	self.frame.bar.highLight:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
	self.frame.bar.highLight:SetBlendMode("ADD")
	self.frame.bar.highLight:SetAllPoints(self.frame.bar)
	self.frame.bar.highLight:SetVertexColor(1, 1, 1, 0.3)
	self.frame.bar.highLight:Hide()


	self.frame.bar:Show()
end


function TargetOfTarget.prototype:CreateToTFrame()
	self.frame.totName = self:FontFactory(self.moduleSettings.fontSize, self.frame.bar, self.frame.totName)
	
	if self.moduleSettings.sizeToGap then
		self.frame.totName:SetWidth(self.settings.gap-40)
	else
		self.frame.totName:SetWidth(self.moduleSettings.totWidth-40)
	end
	self.frame.totName:SetHeight(self.height)
	self.frame.totName:SetJustifyH("LEFT")
	self.frame.totName:SetJustifyV("TOP")

	self.frame.totName:SetPoint("LEFT", self.frame, "LEFT", 0, -1)
	self.frame.totName:Show()
end


function TargetOfTarget.prototype:CreateToTHPFrame()
	self.frame.totHealth = self:FontFactory(self.moduleSettings.fontSize, self.frame.bar, self.frame.totHealth)

	self.frame.totHealth:SetWidth(40)
	self.frame.totHealth:SetHeight(self.height)
	self.frame.totHealth:SetJustifyH("RIGHT")
	self.frame.totHealth:SetJustifyV("TOP")

	self.frame.totHealth:SetPoint("RIGHT", self.frame, "RIGHT", 0, 0)
	self.frame.totHealth:Show()
end


function TargetOfTarget.prototype:CreateDebuffFrame()
	if (self.frame.debuffFrame) then
		return
	end
	self.frame.debuffFrame = CreateFrame("Frame", nil, self.frame)

	self.frame.debuffFrame:SetFrameStrata("BACKGROUND")
	self.frame.debuffFrame:SetWidth(10)
	self.frame.debuffFrame:SetHeight(self.height)

	self.frame.debuffFrame:SetPoint("TOPLEFT", self.frame, "BOTTOMLEFT", 0, -2)
	self.frame.debuffFrame:Show()

	self.frame.debuffFrame.buffs = self:CreateIconFrames(self.frame.debuffFrame)
end


function TargetOfTarget.prototype:CreateIconFrames(parent)
	local buffs = {}

	for i = 1, IceCore.BuffLimit do
		buffs[i] = CreateFrame("Frame", nil, parent)
		buffs[i]:SetFrameStrata("BACKGROUND")
		buffs[i]:SetWidth(self.buffSize)
		buffs[i]:SetHeight(self.buffSize)
		buffs[i]:SetPoint("LEFT", (i-1) * self.buffSize + (i-1), 0)
		buffs[i]:Show()
		
		buffs[i].texture = buffs[i]:CreateTexture()
		buffs[i].texture:SetTexture(nil)
		buffs[i].texture:SetAllPoints(buffs[i])
		
		buffs[i].stack = self:FontFactory(11, buffs[i], buffs[i].stack, "OUTLINE")
		buffs[i].stack:SetPoint("BOTTOMRIGHT" , buffs[i], "BOTTOMRIGHT", 2, -1)
		
		if (self.moduleSettings.mouse) then
			buffs[i]:EnableMouse(true)
			buffs[i]:SetScript("OnEnter", function() self:BuffOnEnter() end)
			buffs[i]:SetScript("OnLeave", function() GameTooltip:Hide() end)
		else
			buffs[i]:EnableMouse(false)
			buffs[i]:SetScript("OnEnter", nil)
			buffs[i]:SetScript("OnLeave", nil)
		end
		
		buffs[i].unit = self.unit
	end
	return buffs
end


function TargetOfTarget.prototype:UpdateBuffs()
	local debuffs = 0
	
	if (self.moduleSettings.showDebuffs) then
		for i = 1, IceCore.BuffLimit do
			local buffName, buffRank, buffTexture, buffApplications = UnitDebuff(self.unit, i)

			if (buffApplications and (buffApplications > 1)) then
				debuffs = debuffs + 1

				if not (self.stackedDebuffs[debuffs]) then
					self.stackedDebuffs[debuffs] = {}
				end
				
				self.stackedDebuffs[debuffs].texture = buffTexture
				self.stackedDebuffs[debuffs].count = buffApplications
				self.stackedDebuffs[debuffs].id = i
			end
		end
	end
	
	for i = 1, IceCore.BuffLimit do
		if (self.moduleSettings.showDebuffs and (i <= debuffs)) then
			self.frame.debuffFrame.buffs[i]:Show()
			self.frame.debuffFrame.buffs[i].texture:SetTexture(self.stackedDebuffs[i].texture)
			self.frame.debuffFrame.buffs[i].stack:SetText(self.stackedDebuffs[i].count)
			self.frame.debuffFrame.buffs[i].id = self.stackedDebuffs[debuffs].id
		else
			self.frame.debuffFrame.buffs[i]:Hide()
			self.frame.debuffFrame.buffs[i].texture:SetTexture(nil)
			self.frame.debuffFrame.buffs[i].stack:SetText(nil)
			self.frame.debuffFrame.buffs[i].id = nil
		end
	end
end


function TargetOfTarget.prototype:Update()
	if not (UnitExists(self.unit)) then
		if not (self.hadTarget) then
			return
		end
		self.hadTarget = false
		
		self.frame.totName:SetText()
		self.frame.totHealth:SetText()
		self:UpdateBuffs()
		return
	end
	
	self.hadTarget = true
	
	self:UpdateBuffs()

	local _, unitClass = UnitClass(self.unit)
	local name = UnitName(self.unit)
	local reaction = UnitReaction(self.unit, "player")

	local health = UnitHealth(self.unit)
	local maxHealth = UnitHealthMax(self.unit)
	local healthPercentage = math.floor( (health/maxHealth)*100 )
	
	local rColor = UnitReactionColor[reaction or 5]

	self.frame.totName:SetTextColor(rColor.r, rColor.g, rColor.b, 0.9)
	self.frame.totName:SetText(name)

	self.frame.totHealth:SetTextColor(rColor.r, rColor.g, rColor.b, 0.9)
	self.frame.totHealth:SetText(healthPercentage .. "%")

	self.frame.bar.texture:SetVertexColor(self:GetColor(unitClass, 0.7))
	self.frame.bar:SetMinMaxValues(0, maxHealth)
	self.frame.bar:SetValue(health)
end


function TargetOfTarget.prototype:OnEnter(frame)
	UnitFrame_OnEnter(frame)
	self.frame.bar.highLight:Show()
end


function TargetOfTarget.prototype:OnLeave(frame)
	UnitFrame_OnLeave(frame)
	self.frame.bar.highLight:Hide()
end


function TargetOfTarget.prototype:BuffOnEnter(type)
	if (not this:IsVisible()) then
		return
	end

	if (this.unit and this.id) then
		GameTooltip:SetOwner(this, "ANCHOR_BOTTOMRIGHT")
		GameTooltip:SetUnitDebuff(this.unit, this.id)
	end
end


-- load us up
IceHUD.TargetOfTarget = TargetOfTarget:new()
