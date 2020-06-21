MAPVOTE = {}

surface.CreateFont("MapVotingTitle", {
	font = "Roboto",
	size = 48,
	weight = 600,
	antialias = true
})

JWProgressBar = {}
JWProgressBar.m_value = nil
JWProgressBar.m_bgcolor = nil
JWProgressBar.m_color = nil
function JWProgressBar:Init()
	self.m_value = 0
	self.m_bgcolor = Color(0,0,0,0)
	self.m_color = Color(255,255,255)
end
function JWProgressBar:SetValue(i)
	self.m_value = i
end
function JWProgressBar:SetBackgroundColor(color)
	self.m_bgcolor = color
end
function JWProgressBar:SetForegroundColor(color)
	self.m_color = color
end
function JWProgressBar:Paint()
	local width = self:GetWide()
	local height = self:GetTall()
	
	surface.SetDrawColor(self.m_bgcolor)
	surface.DrawRect(0, 0, width, height)
	
	surface.SetDrawColor(self.m_color)
	surface.DrawRect(0, 0, width*self.m_value, height)
	
	return true
end
vgui.Register("JWBar", JWProgressBar, "DPanel")

function MAPVOTE.getHTML(img)
	return [[
<!DOCTYPE html>
<html>
	<head>
		<style>
			* {
				overflow: hidden;
				padding:0px;
				margin:0px;
				width:100%;
				height:100%;
				background:black;
				background-image:url("]] .. MAPVOTE.config.defaultThumbnail .. [[");
				background-repeat: no-repeat;
				background-position: center;
				background-size: auto 60%;
			}
			img {
				
			}
		</style>
	</head>
	<body>
		<img src="]] .. MAPVOTE.config.thumbnailLocation .. img .. [[">
	</body>
</html>
]]
end


function MAPVOTE.getButtonLocation(id)
	local sw = surface.ScreenWidth()
	local sh = surface.ScreenHeight()
	local cx = sw/2
	local cy = sh/2


	if id == 1 then
		return 0,0
	elseif id == 2 then
		return cx,0
	elseif id == 3 then
		return 0,cy
	elseif id == 4 then
		return cx,cy
	else
		return false
	end
end

function MAPVOTE.createButton(id, parent)
	local sw = surface.ScreenWidth()
	local sh = surface.ScreenHeight()
	local cx = sw/2
	local cy = sh/2

	local x, y = MAPVOTE.getButtonLocation(id)
	
	local panel = vgui.Create("DPanel", parent)
		panel:SetPos(x, y)
		panel:SetSize(cx, cy)
		panel:SetPaintBorderEnabled(false)
	
	local html = vgui.Create("HTML", panel)
		--html:SetPos(x, y)
		--html:SetSize(cx,cy)
		html:Dock(FILL)
		--map1:SetText(MAPVOTE.currentvote.maps[1].friendlyname)
		html:SetPaintBorderEnabled(false)
		html:SetHTML(MAPVOTE.getHTML(MAPVOTE.currentvote.maps[id].thumbnail))

	local text = vgui.Create("DLabel", panel)
		text:SetAutoStretchVertical(true)
		text:SetFont("MapVotingTitle")
		text:SetText(MAPVOTE.currentvote.maps[id].friendlyname)
		text:SetTextColor(Color(255,255,255))
		text:SetPaintBackgroundEnabled(false)
		text:SizeToContents()
		w,h = text:GetSize()
		local margin = MAPVOTE.config.titleMargin
		local verticalmargin = margin + MAPVOTE.config.progressBarHeight
		if id == 1 then
			text:SetPos(cx-w-margin, cy-h-verticalmargin)
		elseif id == 2 then
			text:SetPos(margin, cy-h-verticalmargin)
		elseif id == 3 then
			text:SetPos(cx-w-margin, verticalmargin)
		elseif id == 4 then
			text:SetPos(margin, verticalmargin)
		end

		local button = vgui.Create("DButton", parent)
		if id==1 or id==2 then
			button:SetPos(x, y)
		else
			button:SetPos(x, y+MAPVOTE.config.progressBarHeight)
		end
		
		button:SetSize(cx, cy-MAPVOTE.config.progressBarHeight)
		button:SetPaintedManually(true)
		button.mapindex = id
		button.DoClick = MAPVOTE.voteButtonClicked

	return {
				panel=panel,
				html=html,
				text=text,
				button=button
			}
end

function MAPVOTE.receiveTimeUntilVote()
	MAPVOTE.roundsUntilVote = net.ReadUInt(32)
end
net.Receive("timeTillVotePS", function() MAPVOTE.receiveTimeUntilVote() end)

function MAPVOTE.getCurrentVoteMapID(mapname) -- Returns the ID (1-4) of a mapname in the current vote, or nil if it is not in the vote
	for k,v in pairs(MAPVOTE.currentvote.maps) do
		if v.name == mapname then
			return k
		end
	end
	return nil
end

function MAPVOTE.getAvatarSpawnPosition(position)
	print("Position: "..position)
	local margin = MAPVOTE.config.avatarSize
	local sw = surface.ScreenWidth()
	local sh = surface.ScreenHeight()
	
	local horizontal = margin + sw + margin
	local vertical = margin + sh + margin
	
	local unwrappedlength = (horizontal+vertical) * 2 --Unwraps the rectangle that avatars can spawn along into a line
	
	local position = position*unwrappedlength
	x = 0-margin
	y = 0-margin
	if position < horizontal then
		print("Margin: "..margin)
		x = position - margin
		y = 0 - margin
	elseif position < horizontal+vertical then
		x = sw+margin
		y = position - horizontal - margin
	elseif position < horizontal*2+vertical then
		x = sw + margin - (position - horizontal - vertical)
		y = sh+margin
	else
		x = 0 - margin
		y = sh + margin - (position - horizontal*2 - vertical)
	end
	return x,y
end


function MAPVOTE.getAvatarPositionByIndex(i) --Please don't ask me to write this function again, it was pure hell. Took over 2 hours. I am not a mathematician.
	local maxRows = MAPVOTE.config.maxAvatarRows
	--print("i ("..type(i)..") = "..tostring(i))
	--print("maxRows ("..type(maxRows)..") = "..tostring(maxRows))
	if i <= maxRows * maxRows then
		local rows = math.ceil(math.sqrt(i))
		local position = i - math.pow(rows-1,2)
		local linesize = math.pow(rows,2)-math.pow(rows-1,2)
		if position < linesize then
			if position < linesize/2 then
				return rows, position
			else
				return position-math.floor(linesize/2), rows
			end
		else
			return rows, rows
		end
	else
		x = math.ceil(i/maxRows)
		y = ((i-1) % maxRows) + 1
		return x, y
	end
end

function MAPVOTE.setAvatarPosition(ply, x, y)
	--print("Moving "..ply:Nick())
	local avatar = MAPVOTE.currentvote.vgui.avatarimages[ply]
	if avatar then
		--print("Avatar exists, moving")
		--print("Target: "..x..", "..y)
		avatar.targetX, avatar.targetY = x, y
		if MAPVOTE.config.animateAvatarMovements then
			----print("Animating")
			if not MAPVOTE.config.avatarMomentum then
				----print("No momentum")
				--avatar.element:MoveTo(x, y, MAPVOTE.config.avatarMovementTime, 0, 0)
			end
		else
			--print("Not animating")
			avatar.element:SetPos(x, y)
		end
	elseif not MAPVOTE.currentvote.winner then --We don't want to mess around with VGUI too much after the vote has ended. Chances of this ever happening are low but better safe than sorry.
		--print("Avatar does not exist, spawning")
		--print("Target: "..x..", "..y)
		spawnX, spawnY = MAPVOTE.getAvatarSpawnPosition(math.Rand(0, 1))
		MAPVOTE.currentvote.vgui.avatarimages[ply] = {}
		local avatar = MAPVOTE.currentvote.vgui.avatarimages[ply]
		avatar.element = vgui.Create("AvatarImage", panel)
		local size
		if ply==LocalPlayer() and MAPVOTE.config.useMegaAvatar then
			size = MAPVOTE.config.avatarSize*2
		else
			size = MAPVOTE.config.avatarSize
		end
		avatar.element:SetSize(size, size)
		avatar.element:SetPos(spawnX-size/2, spawnY-size/2)
		avatar.element:SetPlayer(ply)
		
		
		avatar.velocityX, avatar.velocityY = 0, 0
		avatar.targetX, avatar.targetY = x, y
		if MAPVOTE.config.animateAvatarMovements then
			if not MAPVOTE.config.avatarMomentum then
				--avatar.element:MoveTo(x, y, MAPVOTE.config.avatarMovementTime, 0, 0)
			end
		else
			avatar.element:SetPos(x, y)
		end
	end
end

function MAPVOTE.setAvatarPositions()
	local sw = surface.ScreenWidth() --3 times faster than ScrH(), woo for optimisation!
	local sh = surface.ScreenHeight()
	
	--PrintTable(MAPVOTE.currentvote.vgui.steamavatars)
	for mapid, votes in pairs(MAPVOTE.currentvote.vgui.steamavatars) do
		for voteid, voter in pairs(votes) do
			local x, y
			if mapid == MAPVOTE.currentvote.myvote then --Make room for the player's own avatar
				if MAPVOTE.config.useMegaAvatar then
					x, y = MAPVOTE.getAvatarPositionByIndex(voteid+4)
				else
					x, y = MAPVOTE.getAvatarPositionByIndex(voteid+1)
				end
			else
				x, y = MAPVOTE.getAvatarPositionByIndex(voteid)
			end
			
			x = (x-1) * MAPVOTE.config.avatarSize
			y = (y-1) * MAPVOTE.config.avatarSize
			
			if mapid == 1 then
				MAPVOTE.setAvatarPosition(voter, x, y)
			elseif mapid == 2 then
				MAPVOTE.setAvatarPosition(voter, sw-x-MAPVOTE.config.avatarSize, y)
			elseif mapid == 3 then
				MAPVOTE.setAvatarPosition(voter, x, sh-y-MAPVOTE.config.avatarSize)
			elseif mapid == 4 then
				MAPVOTE.setAvatarPosition(voter, sw-x-MAPVOTE.config.avatarSize, sh-y-MAPVOTE.config.avatarSize)
			end
		end
	end
	
	voteid = MAPVOTE.currentvote.myvote
	if voteid then
		x, y = MAPVOTE.getAvatarPositionByIndex(voteid)
		
		x = (x-1) * MAPVOTE.config.avatarSize
		y = (y-1) * MAPVOTE.config.avatarSize
		
		if voteid == 1 then
			MAPVOTE.setAvatarPosition(LocalPlayer(), x, y)
		elseif voteid == 2 then
			MAPVOTE.setAvatarPosition(LocalPlayer(), sw-x-MAPVOTE.config.avatarSize, y)
		elseif voteid == 3 then
			MAPVOTE.setAvatarPosition(LocalPlayer(), x, sh-y-MAPVOTE.config.avatarSize)
		elseif voteid == 4 then
			MAPVOTE.setAvatarPosition(LocalPlayer(), sw-x-MAPVOTE.config.avatarSize, sh-y-MAPVOTE.config.avatarSize)
		end
	end
end

function MAPVOTE.receiveVotingProgress()
	if not MAPVOTE.currentvote then return end --Protection against race conditions, even though they are highly unlikely
	
	MAPVOTE.currentvote.votes = net.ReadTable()
	----PrintTable(MAPVOTE.currentvote.votes)
	for k,v in pairs(MAPVOTE.currentvote.votes) do
		local mapid = MAPVOTE.getCurrentVoteMapID(v)
		if k == LocalPlayer() then
			MAPVOTE.currentvote.myvote = mapid
		else
			if not table.HasValue(MAPVOTE.currentvote.vgui.steamavatars[mapid], k) then
				for k2,v2 in pairs(MAPVOTE.currentvote.vgui.steamavatars) do
					table.RemoveByValue(v2, k)
				end
				table.insert(MAPVOTE.currentvote.vgui.steamavatars[mapid], k)
			end
		end
	end
	MAPVOTE.setAvatarPositions()
end
net.Receive("votesSoFar", function() MAPVOTE.receiveVotingProgress() end)

local lastThinkTime = nil
function MAPVOTE.think()
	local deltaTime = SysTime()-lastThinkTime
	lastThinkTime = SysTime()
	
	if not MAPVOTE.currentvote.winner then
		if MAPVOTE.config.progressBarInterval <= 0 then
			MAPVOTE.currentvote.timeElapsed = MAPVOTE.currentvote.timeElapsed + deltaTime
			MAPVOTE.currentvote.vgui.progress:SetValue(MAPVOTE.currentvote.timeElapsed/MAPVOTE.currentvote.votingTime)
		end

		if MAPVOTE.config.animateAvatarMovements and IsValid(MAPVOTE.currentvote.vgui.mainpanel) then
			for k,v in pairs(MAPVOTE.currentvote.vgui.avatarimages) do
				local derma = v.element
				local x,y = derma:GetPos()
				if x~=v.targetX or y~=v.targetY or v.velocityX ~= 0 or v.velocityY ~= 0 then --We can skip all calculations if the avatar has already arrived
					local distance = math.Dist(x, y, v.targetX, v.targetY)
					local clampedRRatio = math.Clamp((distance-MAPVOTE.config.avatarR1)/(MAPVOTE.config.avatarR2-MAPVOTE.config.avatarR1),0,1)
					local avatarSpeed = MAPVOTE.config.avatarSpeed
					if k==LocalPlayer() then
						avatarSpeed = MAPVOTE.config.megaAvatarSpeed
					end
					local speed = Lerp(clampedRRatio, MAPVOTE.config.avatarR1SpeedScale, MAPVOTE.config.avatarR2SpeedScale)*avatarSpeed
					local tightness = Lerp(clampedRRatio, MAPVOTE.config.avatarR1Tightness, MAPVOTE.config.avatarR2Tightness)
					local flexibility = speed*tightness
					local nextX = x+v.velocityX
					local nextY = y+v.velocityY
					local midX = Lerp(tightness, nextX, x)
					local midY = Lerp(tightness, nextY, y)
					
					if math.Dist(midX, midY, v.targetX, v.targetY) < flexibility then
						--We did it, we finally made it home
						derma:SetPos(v.targetX, v.targetY)
						v.velocityX = 0
						v.velocityY = 0
					else
						local angle = math.atan2(y-v.targetY, v.targetX-x) --We swap the order of the subtractions to convert between screenspace and mathspace. Also, atan2 accepts y before x for some reason.
						v.velocityX = Lerp(tightness, v.velocityX, math.cos(angle)*speed)
						v.velocityY = Lerp(tightness, v.velocityY, -math.sin(angle)*speed)
						derma:SetPos(x+v.velocityX, y+v.velocityY)
					end
				end
			end
		end
	end
end

function MAPVOTE.incrementTime()
	MAPVOTE.currentvote.timeElapsed = MAPVOTE.currentvote.timeElapsed + MAPVOTE.config.progressBarInterval
	MAPVOTE.currentvote.vgui.progress:SetValue(MAPVOTE.currentvote.timeElapsed/MAPVOTE.currentvote.votingTime)
end

function MAPVOTE.beginVoting()
	if not MAPVOTE.config then return end --If the client hasn't loaded a config yet, leave em behind
	--print("Voting started")
	MAPVOTE.currentvote = net.ReadTable()
	--PrintTable(MAPVOTE.currentvote)
	MAPVOTE.currentvote.timeElapsed = 0
	MAPVOTE.createVotingScreen()
	lastThinkTime = SysTime()
	hook.Add("Think", "mapvoteThink", function() MAPVOTE.think() end)
	if MAPVOTE.config.progressBarInterval > 0 then
		timer.Create("mapvoteIncrementTime", MAPVOTE.config.progressBarInterval, MAPVOTE.currentvote.votingTime/MAPVOTE.config.progressBarInterval, function() MAPVOTE.incrementTime() end)
	end
end
net.Receive("commenceVoting", function() MAPVOTE.beginVoting() end)

function MAPVOTE.voteButtonClicked(button)
	if MAPVOTE.currentvote.timeElapsed > MAPVOTE.currentvote.votingTime then return end
	net.Start("playerVote")
		net.WriteString(MAPVOTE.currentvote.maps[button.mapindex].name)
	net.SendToServer()
	MAPVOTE.currentvote.myvote = MAPVOTE.getCurrentVoteMapID(MAPVOTE.currentvote.maps[button.mapindex].name)
	----print("Voted: "..MAPVOTE.currentvote.maps[button.mapindex].name)
end

function MAPVOTE.receiveWinner()
	local sw = surface.ScreenWidth()
	local sh = surface.ScreenHeight()
	
	MAPVOTE.currentvote.winner = net.ReadString()
	MAPVOTE.currentvote.winnerid = MAPVOTE.getCurrentVoteMapID(MAPVOTE.currentvote.winner)
	local id = MAPVOTE.currentvote.winnerid
	
	MAPVOTE.currentvote.winTime = SysTime()
	
	v = MAPVOTE.currentvote.vgui.mapbuttons[MAPVOTE.currentvote.winnerid]
	v.panel:MoveToFront()
	v.panel:SetSize(sw, sh)
	v.panel:SetPos(0,0)
	v.html:SetSize(sw, sh)
	v.html:MoveToFront()
	v.text:MoveToFront()
	
	local w, h = v.text:GetSize()
	local titleMargin = MAPVOTE.config.titleMargin
	
	if id==1 then
		v.text:SetPos(sw-w-titleMargin, sh-h-titleMargin)
	elseif id==2 then
		v.text:SetPos(titleMargin, sh-h-titleMargin)
	elseif id==3 then
		v.text:SetPos(sw-w-titleMargin, titleMargin)
	elseif id==4 then
		v.text:SetPos(titleMargin, titleMargin)
	end
	
	MAPVOTE.currentvote.vgui.progress:Remove()
	
	local preservedPlayers = {}
	for k,v in pairs(MAPVOTE.currentvote.vgui.steamavatars[MAPVOTE.currentvote.winnerid]) do
		table.insert(preservedPlayers, v)
	end
	if MAPVOTE.currentvote.myvote == MAPVOTE.currentvote.winnerid then
		table.insert(preservedPlayers, LocalPlayer())
	end
	for k,v in pairs(MAPVOTE.currentvote.vgui.avatarimages) do
		if table.KeyFromValue(preservedPlayers, k) then
			v.element:MoveToFront()
		else
			v.element:Remove()
		end
	end
	
	for k,v in pairs(MAPVOTE.currentvote.vgui.mapbuttons) do
		v.button:Remove()
	end
end
net.Receive("voteFinished", function() MAPVOTE.receiveWinner() end)

function MAPVOTE.createVotingScreen()
	local sw = surface.ScreenWidth()
	local sh = surface.ScreenHeight()
	local cx = sw/2
	local cy = sh/2
	
	MAPVOTE.currentvote.vgui = {}
	
	local panel = vgui.Create("DPanel")
	panel:SetPos(0,0)
	panel:SetSize(surface.ScreenWidth(), surface.ScreenHeight())
	--panel:SetVisible(true)
	panel:ParentToHUD()
	--panel:MoveToBack()
	panel:MoveToFront()
	--[[if g_VoicePanelList and g_VoicePanelList.MoveToFront then
		g_VoicePanelList:SetParent(panel)
		g_VoicePanelList:MoveToFront()
	end]]
	--panel:SetMouseInputEnabled(true)
	panel:SetKeyboardInputEnabled(false)
	--panel:SetPaintBackground(false)
	panel:MakePopup()
	panel:SetKeyboardInputEnabled(false)
	
	MAPVOTE.currentvote.vgui.mainpanel = panel

	MAPVOTE.currentvote.vgui.mapbuttons = {}

	MAPVOTE.currentvote.vgui.mapbuttons[1] = MAPVOTE.createButton(1,panel)
	MAPVOTE.currentvote.vgui.mapbuttons[2] = MAPVOTE.createButton(2,panel)
	MAPVOTE.currentvote.vgui.mapbuttons[3] = MAPVOTE.createButton(3,panel)
	MAPVOTE.currentvote.vgui.mapbuttons[4] = MAPVOTE.createButton(4,panel)
	
	MAPVOTE.currentvote.vgui.progress = vgui.Create("JWBar", panel)
	MAPVOTE.currentvote.vgui.progress:SetSize(sw, MAPVOTE.config.progressBarHeight)
	MAPVOTE.currentvote.vgui.progress:SetPos(0, cy-(MAPVOTE.config.progressBarHeight/2))
	MAPVOTE.currentvote.vgui.progress:SetBackgroundColor(MAPVOTE.config.progressBarBackgroundColor)
	MAPVOTE.currentvote.vgui.progress:SetForegroundColor(MAPVOTE.config.progressBarForegroundColor)
	
	MAPVOTE.currentvote.vgui.steamavatars = {{},{},{},{}}
	MAPVOTE.currentvote.vgui.avatarimages = {}
	local allPlayers = player.GetAll()
	local randomPlayers = {}
	while #allPlayers > 0 do
		table.insert(randomPlayers, table.remove(allPlayers, math.random(1, #allPlayers)))
	end
	for k,v in pairs(randomPlayers) do
		MAPVOTE.currentvote.vgui.avatarimages[v] = {}
		local current = MAPVOTE.currentvote.vgui.avatarimages[v]
		--x, y = cx, cy
		x, y = MAPVOTE.getAvatarSpawnPosition(k/#randomPlayers)
		print("Spawned avatar at "..x..", "..y)
		
		current.element = vgui.Create("AvatarImage", panel)
		local size
		if v==LocalPlayer() and MAPVOTE.config.useMegaAvatar then
			size = MAPVOTE.config.avatarSize*2
		else
			size = MAPVOTE.config.avatarSize
		end
		current.element:SetSize(size, size)
		current.element:SetPos(x-size/2, y-size/2)
		current.element:SetPlayer(v)
		
		
		current.velocityX, current.velocityY = 0, 0
		current.targetX, current.targetY = x-size/2, y-size/2
	end

	
	MAPVOTE.adjustDepth()
end

function MAPVOTE.adjustDepth()
	for k,v in pairs(MAPVOTE.currentvote.vgui.mapbuttons) do
		v.panel:MoveToFront()
		v.html:MoveToFront()
		v.text:MoveToFront()
	end
	
	MAPVOTE.currentvote.vgui.progress:MoveToFront()
	
	for k,v in pairs(MAPVOTE.currentvote.vgui.avatarimages) do
		v.element:MoveToFront()
	end
	
	for k,v in pairs(MAPVOTE.currentvote.vgui.mapbuttons) do
		v.button:MoveToFront()
	end
end

function MAPVOTE.hide()
	if not MAPVOTE.currentvote then return end
	if not MAPVOTE.currentvote.vgui then return end
	
	MAPVOTE.currentvote.vgui.progress:SetParent(nil)
	MAPVOTE.currentvote.vgui.progress:SetPos(0,0)
	MAPVOTE.currentvote.vgui.mainpanel:Remove()
	--MAPVOTE.think = function() end
	MAPVOTE.receiveWinner = function() end
end
concommand.Add("closemapvote", function() MAPVOTE.hide() end)

function MAPVOTE.receiveConfig()
	print("Received mapvote config settings")
	MAPVOTE.config = net.ReadTable()
end
net.Receive("sendConfig", function() MAPVOTE.receiveConfig() end)

function MAPVOTE.requestConfig()
	print("Requesting mapvote config settings")
	net.Start("requestConfig")
	net.SendToServer()
end
hook.Add("Initialize", "requestMapVoteConfigOnInit", function() timer.Simple(1, MAPVOTE.requestConfig) end)
concommand.Add("reqMVCFG", function() MAPVOTE.requestConfig() end)


hook.Add("TTTScoreboardColumns", "jw-ttt-map-voting time", function(scoreboard)
	if not scoreboard.mapchange then return end
	scoreboard.mapchange:SetText("Loading...")
	
	scoreboard.mapchange.Think = function (sf)
		if not MAPVOTE or MAPVOTE.roundsUntilVote==nil then
			voteString = "Loading..."
		else
			if MAPVOTE.roundsUntilVote<=1 then
				voteString = "Voting will commence after this round."
			else
				voteString = "Voting will commence in "..MAPVOTE.roundsUntilVote.." rounds."
			end
		end
		sf:SetText(voteString)
		sf:SizeToContents()
	end
end)


print("MAPVOTE SETUP COMPLETE")