local PA = _G.ProjectAzilroka
local MXP = PA:NewModule('MasterXP', 'AceTimer-3.0', 'AceEvent-3.0')

MXP.Title = 'Master Experience'
MXP.Header = PA.ACL['|cFF16C3F2Master|r |cFFFFFFFFExperience|r']
MXP.Description = PA.ACL['Shows Experience Bars for Party / Battle.net Friends']
MXP.Authors = 'Azilroka     NihilisticPandemonium'
MXP.isEnabled = false
PA.MXP, _G.MasterExperience = MXP, MXP

local _G = _G
local min, format = min, format
local CreateFrame = CreateFrame
local GetXPExhaustion = GetXPExhaustion
local IsXPUserDisabled = IsXPUserDisabled
local GetQuestLogRewardXP = GetQuestLogRewardXP
local IsPlayerAtEffectiveMaxLevel = IsPlayerAtEffectiveMaxLevel
local UnitXP, UnitXPMax = UnitXP, UnitXPMax

local QuestLogXP, ZoneQuestXP, CompletedQuestXP = 0, 0, 0
local CurrentXP, XPToLevel, RestedXP, CurrentLevel

local PLAYER_NAME_WITH_REALM
MXP.BNFriendsWoW = {}
MXP.BNFriendsName = {}

MXP.MasterExperience = CreateFrame('Frame', 'MasterExperience', PA.PetBattleFrameHider)
MXP.MasterExperience:Size(250, 400)
MXP.MasterExperience:Point('BOTTOM', UIParent, 'BOTTOM', 0, 43)
MXP.MasterExperience.Bars = {}

if not (PA.Tukui or PA.ElvUI) then
	MXP.MasterExperience:SetMovable(true)
end

function MXP:CheckQuests(questID, zoneOnly)
	if not questID or questID == 0 then
		return
	end

	C_QuestLog.SetSelectedQuest(questID)

	if C_QuestLog.ShouldShowQuestRewards(questID) then
		local isCompleted = C_QuestLog.ReadyForTurnIn(questID)
		local experience = GetQuestLogRewardXP()
		if zoneOnly then
			ZoneQuestXP = ZoneQuestXP + experience
		else
			QuestLogXP = QuestLogXP + experience
		end
		if isCompleted then
			CompletedQuestXP = CompletedQuestXP + experience
		end
	end
end

function MXP:UpdateBar(barID, infoString)
	local bar = MXP.MasterExperience.Bars[barID] or MXP:CreateBar()
	bar:Show()

	-- Split the String
	bar.Info.name, bar.Info.class, bar.Info.level,
	bar.Info.atMaxLevel, bar.Info.xpDisabled,
	bar.Info.CurrentXP, bar.Info.XPToLevel, bar.Info.RestedXP,
	bar.Info.QuestLogXP, bar.Info.ZoneQuestXP, bar.Info.CompletedQuestXP = strsplit(":", infoString)

	-- Convert Strings to Number
	bar.Info.CurrentXP, bar.Info.XPToLevel, bar.Info.RestedXP, bar.Info.QuestLogXP, bar.Info.ZoneQuestXP, bar.Info.CompletedQuestXP = tonumber(bar.Info.CurrentXP), tonumber(bar.Info.XPToLevel), tonumber(bar.Info.RestedXP), tonumber(bar.Info.QuestLogXP), tonumber(bar.Info.ZoneQuestXP), tonumber(bar.Info.CompletedQuestXP)

	-- Convert String to Boolean
	bar.Info.atMaxLevel, bar.Info.xpDisabled = bar.Info.atMaxLevel == 'true', bar.Info.xpDisabled == 'true'

	if bar.Info.XPToLevel <= 0 then bar.Info.XPToLevel = 1 end

	local remainXP = bar.Info.XPToLevel - bar.Info.CurrentXP
	local remainPercent = remainXP / bar.Info.XPToLevel
	bar.Info.RemainTotal, bar.Info.RemainBars = remainPercent * 100, remainPercent * 20
	bar.Info.PercentXP, bar.Info.RemainXP = (bar.Info.CurrentXP / bar.Info.XPToLevel) * 100, remainXP

	-- Set the Colors
	local expColor, restedColor, questColor = MXP.db.Colors.Experience, MXP.db.Colors.Rested, MXP.db.Colors.Quest

	if MXP.db.ColorByClass then
		expColor = MXP:ConvertColorToClass(expColor, RAID_CLASS_COLORS[bar.Info.class])
		restedColor = MXP:ConvertColorToClass(expColor, RAID_CLASS_COLORS[bar.Info.class], .6)
	end

	bar:SetStatusBarColor(expColor.r, expColor.g, expColor.b, expColor.a)
	bar.Rested:SetStatusBarColor(restedColor.r, restedColor.g, restedColor.b, restedColor.a)
	bar.Quest:SetStatusBarColor(questColor.r, questColor.g, questColor.b, questColor.a)

	local displayString, textFormat = '', 'CURPERCREM'

	if bar.Info.atMaxLevel or bar.Info.xpDisabled then
		bar:SetMinMaxValues(0, 1)
		bar:SetValue(1)

		displayString = bar.Info.xpDisabled and PA.ACL["Disabled"] or PA.ACL["Max Level"]
	else
		bar:SetMinMaxValues(0, bar.Info.XPToLevel)
		bar:SetValue(bar.Info.CurrentXP)

		if textFormat == 'PERCENT' then
			displayString = format('%.2f%%', bar.Info.PercentXP)
		elseif textFormat == 'CURMAX' then
			displayString = format('%s - %s', bar.Info.CurrentXP, bar.Info.XPToLevel)
		elseif textFormat == 'CURPERC' then
			displayString = format('%s - %.2f%%', bar.Info.CurrentXP, bar.Info.PercentXP)
		elseif textFormat == 'CUR' then
			displayString = format('%s', bar.Info.CurrentXP)
		elseif textFormat == 'REM' then
			displayString = format('%s', bar.Info.RemainXP)
		elseif textFormat == 'CURREM' then
			displayString = format('%s - %s', bar.Info.CurrentXP, bar.Info.RemainXP)
		elseif textFormat == 'CURPERCREM' then
			displayString = format('%s - %.2f%% (%s)', bar.Info.CurrentXP, bar.Info.PercentXP, bar.Info.RemainXP)
		end

		local isRested = bar.Info.RestedXP and bar.Info.RestedXP > 0
		if isRested then
			bar.Rested:SetMinMaxValues(0, bar.Info.XPToLevel)
			bar.Rested:SetValue(min(bar.Info.CurrentXP + bar.Info.RestedXP, bar.Info.XPToLevel))

			bar.Info.PercentRested = (bar.Info.RestedXP / bar.Info.XPToLevel) * 100

			if textFormat == 'PERCENT' then
				displayString = format('%s R:%.2f%%', displayString, bar.Info.PercentRested)
			elseif textFormat == 'CURPERC' then
				displayString = format('%s R:%s [%.2f%%]', displayString, bar.Info.RestedXP, bar.Info.PercentRested)
			elseif textFormat ~= 'NONE' then
				displayString = format('%s R:%s', displayString, bar.Info.RestedXP)
			end
		end

		local hasQuestXP = bar.Info.QuestLogXP > 0
		if hasQuestXP then
			local QuestPercent = (bar.Info.QuestLogXP / bar.Info.XPToLevel) * 100

			bar.Quest:SetMinMaxValues(0, bar.Info.XPToLevel)
			bar.Quest:SetValue(min(bar.Info.CurrentXP + bar.Info.QuestLogXP, bar.Info.XPToLevel))

			if textFormat == 'PERCENT' then
				displayString = format('%s Q:%.2f%%', displayString, QuestPercent)
			elseif textFormat == 'CURPERC' then
				displayString = format('%s Q:%s [%.2f%%]', displayString, bar.Info.QuestLogXP, QuestPercent)
			elseif textFormat ~= 'NONE' then
				displayString = format('%s Q:%s', displayString, bar.Info.QuestLogXP)
			end
		end

		bar.Rested:SetShown(isRested)
		bar.Quest:SetShown(hasQuestXP)
	end

	bar.Text:SetText(displayString)
	bar.Name:SetText(MXP.BNFriendsName[bar.Info.name] or bar.Info.name)
end

function MXP:Bar_OnEnter()
	if MXP.db.MouseOver then
		UIFrameFadeIn(self, 0.4, self:GetAlpha(), 1)
	end

	_G.GameTooltip:ClearLines()
	_G.GameTooltip:SetOwner(self, 'ANCHOR_CURSOR', 0, -4)

	_G.GameTooltip:AddLine(format('%s %s', self.Info.name, PA.ACL["Experience"]))
	_G.GameTooltip:AddLine(' ')

	_G.GameTooltip:AddDoubleLine(PA.ACL["XP:"], format(' %d / %d (%.2f%%)', self.Info.CurrentXP, self.Info.XPToLevel, self.Info.PercentXP), 1, 1, 1)
	_G.GameTooltip:AddDoubleLine(PA.ACL["Remaining:"], format(' %s (%.2f%% - %d '..PA.ACL["Bars"]..')', self.Info.RemainXP, self.Info.RemainTotal, self.Info.RemainBars), 1, 1, 1)
	_G.GameTooltip:AddDoubleLine(PA.ACL["Quest Log XP:"], self.Info.QuestLogXP, 1, 1, 1)

	if self.Info.RestedXP and self.Info.RestedXP > 0 then
		_G.GameTooltip:AddDoubleLine(PA.ACL["Rested:"], format('+%d (%.2f%%)', self.Info.RestedXP, self.Info.PercentRested), 1, 1, 1)
	end

	_G.GameTooltip:Show()
end

function MXP:Bar_OnLeave()
	if MXP.db.MouseOver then
		UIFrameFadeIn(self, 0.4, self:GetAlpha(), 0)
	end

	GameTooltip_Hide(self)
end

function MXP:CreateBar()
	local barIndex = (#MXP.MasterExperience.Bars + 1)

	local Bar = CreateFrame('StatusBar', 'MasterXP_Bar'..barIndex, MXP.MasterExperience)
	PA:CreateBackdrop(Bar)
	Bar:SetStatusBarTexture(PA.Solid)
	Bar:Hide()
	Bar:Size(250, 20)
	Bar:SetScript('OnEnter', MXP.Bar_OnEnter)
	Bar:SetScript('OnLeave', MXP.Bar_OnLeave)
	Bar.Info = {}

	if barIndex == 1 then
		Bar:Point('BOTTOM', MXP.MasterExperience, 'BOTTOM', 0, 0)
	else
		Bar:Point('BOTTOM', MXP.MasterExperience.Bars[barIndex - 1], 'TOP', 0, 2)
	end

	Bar.Text = Bar:CreateFontString(nil, 'OVERLAY')
	Bar.Text:FontTemplate()
	Bar.Text:Point('CENTER')

	Bar.Name = Bar:CreateFontString(nil, 'OVERLAY')
	Bar.Name:FontTemplate()
	Bar.Name:SetJustifyV("MIDDLE")
	Bar.Name:Point('RIGHT', Bar, 'LEFT', -2, 0)

	Bar.Rested = CreateFrame('StatusBar', '$parent_Rested', Bar)
	Bar.Rested:SetFrameLevel(Bar:GetFrameLevel())
	Bar.Rested:Hide()
	Bar.Rested:SetStatusBarTexture(PA.Solid, 'ARTWORK', -2)
	Bar.Rested:SetAllPoints()

	Bar.Quest = CreateFrame('StatusBar', '$parent_Quest', Bar)
	Bar.Quest:SetFrameLevel(Bar:GetFrameLevel())
	Bar.Quest:Hide()
	Bar.Quest:SetStatusBarTexture(PA.Solid, 'ARTWORK', -1)
	Bar.Quest:SetAllPoints()

	MXP.MasterExperience.Bars[barIndex] = Bar

	return Bar
end

function MXP:UPDATE_EXHAUSTION()
	RestedXP = GetXPExhaustion()
end

function MXP:PLAYER_LEVEL_UP()
	CurrentLevel = UnitLevel('player')
end

function MXP:PLAYER_XP_UPDATE()
	CurrentXP, XPToLevel = UnitXP('player'), UnitXPMax('player')

	MXP:SendMessage()
end

function MXP:QUEST_LOG_UPDATE()
	QuestLogXP, ZoneQuestXP, CompletedQuestXP = 0, 0, 0

	for i = 1, C_QuestLog.GetNumQuestLogEntries() do
		MXP:CheckQuests(C_QuestLog.GetQuestIDForLogIndex(i), C_QuestLog.GetInfo(i).isOnMap)
	end

	MXP:SendMessage()
end

function MXP:ConvertColorToClass(colorTable, classColorTable, multiplier)
	local newColorTable = {}
	multiplier = multiplier or 1
	for key in pairs(classColorTable) do
		if colorTable[key] then
			newColorTable[key] = classColorTable[key] * multiplier
		end
	end

	return newColorTable
end

function MXP:ClearBars()
	for _, bar in ipairs(MXP.MasterExperience.Bars) do
		wipe(bar.Info)
		bar:Hide()
		bar:SetAlpha(1)
	end
end

function MXP:GetAssignedBar(name)
	local numBars = #MXP.MasterExperience.Bars
	if (not numBars or numBars == 0) then
		return 1
	else
		for i = 1, numBars do
			if MXP.MasterExperience.Bars[i] and (MXP.MasterExperience.Bars[i].Info.name == name or not MXP.MasterExperience.Bars[i].Info.name) then
				return i
			end
		end
		return numBars + 1
	end
end

function MXP:UpdateAllBars()
	MXP:ClearBars()
	MXP:SendMessage()

	if IsInGroup() then
		C_ChatInfo.SendAddonMessage('PA_MXP', 'REQUESTINFO', 'PARTY')
	end

	if MXP.db.BattleNet and BNConnected() then
		for friend in pairs(MXP.BNFriendsWoW) do
			BNSendGameData(friend, 'PA_MXP', 'REQUESTINFO')
		end
	end
end

function MXP:SendMessage()
	local message = format('%s:%s:%d:%s:%s:%d:%d:%d:%d:%d:%d:%d', PLAYER_NAME_WITH_REALM, PA.MyClass, CurrentLevel, tostring(IsPlayerAtEffectiveMaxLevel()), tostring(IsXPUserDisabled()), CurrentXP or 0, XPToLevel or 0, RestedXP or 0, QuestLogXP or 0, ZoneQuestXP or 0, CompletedQuestXP or 0)

	if IsInGroup() then
		C_ChatInfo.SendAddonMessage('PA_MXP', message, 'PARTY')
	end

	if MXP.db.BattleNet and BNConnected() then
		for friend in pairs(MXP.BNFriendsWoW) do
			BNSendGameData(friend, 'PA_MXP', message)
		end
	end
end

function MXP:HandleBNET()
	wipe(MXP.BNFriendsWoW)
	wipe(MXP.BNFriendsName)

	if BNConnected() then
		local _, numBNetOnline = BNGetNumFriends()
		for friendIndex = 1, numBNetOnline do
			local friendInfo = C_BattleNet.GetFriendAccountInfo(friendIndex)
			for gameIndex = 1, C_BattleNet.GetFriendNumGameAccounts(friendIndex) do
				local info = C_BattleNet.GetFriendGameAccountInfo(friendIndex, gameIndex)
				if info and info.clientProgram == 'WoW' then
					MXP.BNFriendsWoW[info.gameAccountID] = format('%s-%s', info.characterName, info.realmName)
					MXP.BNFriendsName[format('%s-%s', info.characterName, info.realmName)] = friendInfo.accountName
				end
			end
		end
	end
end

function MXP:RecieveMessage(event, prefix, message, _, sender)
	if prefix ~= 'PA_MXP' then return end

	if event == 'CHAT_MSG_ADDON' and sender ~= PLAYER_NAME_WITH_REALM then
		if message == 'REQUESTINFO' then
			MXP:SendMessage()
		else
			MXP:UpdateBar(MXP:GetAssignedBar(sender), message)
		end
	elseif event == 'BN_CHAT_MSG_ADDON' and MXP.db.BattleNet and MXP.BNFriendsWoW[sender] then
		if message == 'REQUESTINFO' then
			MXP:SendMessage()
		else
			MXP:UpdateBar(MXP:GetAssignedBar(MXP.BNFriendsWoW[sender]), message)
		end
	end
end

function MXP:GetOptions()
	PA.Options.args.MasterExperience = PA.ACH:Group(MXP.Title, MXP.Description, nil, nil, function(info) return MXP.db[info[#info]] end)
	PA.Options.args.MasterExperience.args.Header = PA.ACH:Header(MXP.Header, 0)
	PA.Options.args.MasterExperience.args.Enable = PA.ACH:Toggle(PA.ACL['Enable'], nil, 1, nil, nil, nil, nil, function(info, value) MXP.db[info[#info]] = value if not MXP.isEnabled then MXP:Initialize() else _G.StaticPopup_Show('PROJECTAZILROKA_RL') end end)

	PA.Options.args.MasterExperience.args.General = PA.ACH:Group(PA.ACL['General'], nil, 2, nil, nil, function(info, value) MXP.db[info[#info]] = value MXP:UpdateAllBars() end)
	PA.Options.args.MasterExperience.args.General.inline = true
	PA.Options.args.MasterExperience.args.General.args.BattleNet = PA.ACH:Toggle(PA.ACL['Check BattleNet Friends'], nil, 0)
	PA.Options.args.MasterExperience.args.General.args.MouseOver = PA.ACH:Toggle(PA.ACL['MouseOver'], nil, 1)
	PA.Options.args.MasterExperience.args.General.args.ColorByClass = PA.ACH:Toggle(PA.ACL['Color By Class'], nil, 2)

	PA.Options.args.MasterExperience.args.General.args.Colors = PA.ACH:Group(PA.ACL["Colors"], nil, 3, nil, function(info) local t = MXP.db.Colors[info[#info]] return t.r, t.g, t.b, t.a end, function(info, r, g, b, a) local t = MXP.db.Colors[info[#info]] t.r, t.g, t.b, t.a = r, g, b, a MXP:UpdateAllBars() end)
	PA.Options.args.MasterExperience.args.General.args.Colors.args.Experience = PA.ACH:Color('Experience', nil, 1, true)
	PA.Options.args.MasterExperience.args.General.args.Colors.args.Rested = PA.ACH:Color('Rested', nil, 2, true)
	PA.Options.args.MasterExperience.args.General.args.Colors.args.Quest = PA.ACH:Color('Quest', nil, 3, true)

	PA.Options.args.MasterExperience.args.AuthorHeader = PA.ACH:Header(PA.ACL['Authors:'], -2)
	PA.Options.args.MasterExperience.args.Authors = PA.ACH:Description(MXP.Authors, -1, 'large')
end

function MXP:BuildProfile()
	PA.Defaults.profile.MasterExperience = {
		Enable = true,
		ColorByClass = false,
		BattleNet = true,
		Colors = {
			Experience = { r = 0, g = .4, b = 1, a = .8 },
			Rested = { r = 1, g = 0, b = 1, a = .2},
			Quest = { r = 0, g = 1, b = 0, a = .5}
		},
	}
end

function MXP:UpdateSettings()
	MXP.db = PA.db.MasterExperience
end

function MXP:Initialize()
	MXP:UpdateSettings()

	if MXP.db.Enable ~= true then
		return
	end

	MXP.isEnabled = true

	PLAYER_NAME_WITH_REALM = format('%s-%s', UnitFullName("player"))
	_G.C_ChatInfo.RegisterAddonMessagePrefix('PA_MXP')

	if PA.Tukui then
		_G.Tukui[1].Movers:RegisterFrame(MXP.MasterExperience)
	elseif PA.ElvUI then
		_G.ElvUI[1]:CreateMover(MXP.MasterExperience, 'MasterExperienceMover', 'Master Experience Anchor', nil, nil, nil, 'ALL,GENERAL', nil, 'ProjectAzilroka,MasterExperience')
	else
		MXP.MasterExperience:SetScript('OnDragStart', MXP.MasterExperience.StartMoving)
		MXP.MasterExperience:SetScript('OnDragStop', MXP.MasterExperience.StopMovingOrSizing)
	end

	MXP:RegisterEvent('BN_CHAT_MSG_ADDON', 'RecieveMessage')
	MXP:RegisterEvent('CHAT_MSG_ADDON', 'RecieveMessage')
	MXP:RegisterEvent('DISABLE_XP_GAIN', 'SendMessage')
	MXP:RegisterEvent('ENABLE_XP_GAIN', 'SendMessage')
	MXP:RegisterEvent('QUEST_LOG_UPDATE')
	MXP:RegisterEvent('GROUP_ROSTER_UPDATE', 'UpdateAllBars')
	MXP:RegisterEvent('BN_FRIEND_INFO_CHANGED', 'UpdateAllBars')
	MXP:RegisterEvent('BN_FRIEND_ACCOUNT_ONLINE', 'HandleBNET')
	MXP:RegisterEvent('BN_FRIEND_ACCOUNT_OFFLINE', 'HandleBNET')
	MXP:RegisterEvent('PLAYER_XP_UPDATE')
	MXP:RegisterEvent('UPDATE_EXHAUSTION')
	MXP:RegisterEvent('PLAYER_LEVEL_UP')

	MXP:HandleBNET()
	MXP:UPDATE_EXHAUSTION()
	MXP:PLAYER_XP_UPDATE()
	MXP:QUEST_LOG_UPDATE()
	MXP:PLAYER_LEVEL_UP()

	MXP:UpdateAllBars()
end
