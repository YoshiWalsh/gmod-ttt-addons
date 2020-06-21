AddCSLuaFile("autorun/client/cl_mapvote.lua")

MAPVOTE = {}
MAPVOTE.roundsSinceLastChange = 0

util.AddNetworkString("timeTillVotePS") -- Used to tell clients how many rounds are left until a vote
util.AddNetworkString("commenceVoting") -- Used to send clients voting data
util.AddNetworkString("playerVote") -- Used to receive votes from clients
util.AddNetworkString("votesSoFar") -- Used to update clients on the progress of voting
util.AddNetworkString("voteFinished") -- Used to indicate to clients that the vote is completed and the map will change shortly
util.AddNetworkString("requestConfig") -- Used by the client to request clientside configs
util.AddNetworkString("sendConfig") -- Used by the server to send clientside configs

function MAPVOTE.loadConfig() -- Config is for simple, user alterable options
	local configdata = {}
	local configfilecontents = file.Read("jw-ttt-map-voting/config.txt", "DATA")
	if configfilecontents then
		configdata = util.JSONToTable(configfilecontents)
		if not configdata then
			configdata = {}
			file.Write("jw-ttt-map-voting/config.old.txt", configfilecontents) -- We'll generate a new config but it's nice if we save a copy of the damaged one first
		end
	end
	
	-- Validate config and fill in blanks with defaults
	configdata.roundsPerMap = configdata.roundsPerMap ~= nil and configdata.roundsPerMap or 8
	configdata.votingTime = configdata.votingTime ~= nil and configdata.votingTime or 15
	configdata.catchupTime = configdata.catchupTime ~= nil and configdata.catchupTime or 1.5 -- Extra time for voters to compensate for lag (Recommended to be at least 1 second)
	configdata.reflectionTime = configdata.reflectionTime ~= nil and configdata.reflectionTime or 5 -- The time after a vote has finished that users have to reflect on all the poor choices they've made in the map vote.
	configdata.allowRTV = configdata.allowRTV ~= nil and configdata.allowRTV or true
	configdata.limitByPlayers = configdata.limitByPlayers ~= nil and configdata.limitByPlayers or true
	configdata.limitToNewestVersion = configdata.limitToNewestVersion ~= nil and configdata.limitToNewestVersion or true
	configdata.defaultBigVersion = configdata.defaultBigVersion ~= nil and configdata.defaultBigVersion or 4
	configdata.defaultSmallVersion = configdata.defaultSmallVersion ~= nil and configdata.defaultSmallVersion or 0
	configdata.newMapsDefaultEnabled = configdata.newMapsDefaultEnabled ~= nil and configdata.newMapsDefaultEnabled or false -- Whether new maps should automatically be added to the rotation
	configdata.prioritiseLeastRecentlyPlayedMaps = configdata.prioritiseLeastRecentlyPlayedMaps ~= nil and configdata.prioritiseLeastRecentlyPlayedMaps or true

	configdata.clientside = configdata.clientside or {}
	configdata.clientside.titleMargin = configdata.clientside.titleMargin or 15
	configdata.clientside.defaultThumbnail = configdata.clientside.defaultThumbnail or "http://example.org/images/logo.png"
	configdata.clientside.thumbnailLocation = configdata.clientside.thumbnailLocation or "http://example.org/images/mapthumbnails/"
	configdata.clientside.avatarSize = configdata.clientside.avatarSize or 64 --Must be one of the following: 16, 32, 64 (if useMegaAvatar is turned off then 128 can also be used) 32 recommnded for large servers (~50 slots), 64 should work for small servers (<24 slots)
	configdata.clientside.maxAvatarRows = configdata.clientside.maxAvatarRows or 5
	configdata.clientside.useMegaAvatar = configdata.clientside.useMegaAvatar or true --Whether players should see their own avatar at 4x the size.
	configdata.clientside.animateAvatarMovements = configdata.clientside.animateAvatarMovements or true
	configdata.clientside.avatarSpeed = configdata.clientside.avatarSpeed or 128 --Pixels per frame
	configdata.clientside.megaAvatarSpeed = configdata.clientside.megaAvatarSpeed or 96
	configdata.clientside.avatarR1 = configdata.clientside.avatarR1 or 32
	configdata.clientside.avatarR2 = configdata.clientside.avatarR2 or 256
	configdata.clientside.avatarR1Tightness = configdata.clientside.avatarR1Tightness or 1
	configdata.clientside.avatarR2Tightness = configdata.clientside.avatarR2Tightness or 0.3
	configdata.clientside.avatarR1SpeedScale = configdata.clientside.avatarR1SpeedScale or 0.2
	configdata.clientside.avatarR2SpeedScale = configdata.clientside.avatarR2SpeedScale or 1
	configdata.clientside.progressBarBackgroundColor = configdata.clientside.progressBarBackgroundColor or Color(31,67,118,255) --Please forgive me for not having a U in colour, I just wanted consistency
	configdata.clientside.progressBarForegroundColor = configdata.clientside.progressBarForegroundColor or Color(51,113,200,255)
	configdata.clientside.progressBarHeight = configdata.clientside.progressBarHeight or 32
	configdata.clientside.progressBarInterval = configdata.clientside.progressBarInterval or 0 --Measured in seconds, 0 for continuous
	
	
	MAPVOTE.config = configdata
end

function MAPVOTE.saveConfig()
	file.Write("jw-ttt-map-voting/config.txt", util.TableToJSON(MAPVOTE.config))
end

function MAPVOTE.calculateVersions(mapdata)
	-- Record whether each map is the latest version. Useful if the user has limitToNewestVersion on.
	local maxBigVersions = {}
	local maxSmallVersions = {}
	local maxVersions = {}
	for k,v in pairs(mapdata) do
		if v.enabled and v.exists then
			if maxVersions[v.name] then
				if v.releaseBig > maxBigVersions[v.name] then
					mapdata[maxVersions[v.name]].highestVersion = false
					maxVersions[v.name] = k
					maxBigVersions[v.name] = v.releaseBig
					maxSmallVersions[v.name] = v.releaseSmall
					v.highestVersion = true
				elseif v.releaseBig == maxBigVersions[v.name] then
					if v.releaseSmall > maxSmallVersions[v.name] then
						mapdata[maxVersions[v.name]].highestVersion = false
						maxVersions[v.name] = k
						maxBigVersions[v.name] = v.releaseBig
						maxSmallVersions[v.name] = v.releaseSmall
						v.highestVersion = true
					else
						v.highestVersion = false
					end
				else
					v.highestVersion = false
				end
			else
				maxVersions[v.name] = k
				maxBigVersions[v.name] = v.releaseBig
				maxSmallVersions[v.name] = v.releaseSmall
				v.highestVersion = true
			end
		end
	end
end

function MAPVOTE.loadMaps() -- Maps file is for storing non-volatile data about maps.
	-- Read existing map data into object or use blank object
	local mapfilecontents = file.Read("jw-ttt-map-voting/maps.txt", "DATA")
	local mapdata = {}
	if mapfilecontents then
		mapdata = util.JSONToTable(mapfilecontents)
		if not mapdata and mapfilecontents then
			mapdata = {}
			file.Write("jw-ttt-map-voting/maps.old.txt", mapfilecontents)
		end
	end

	for k,v in pairs(mapdata) do
		v.exists = false -- Set each map to be non existant by default. Later we iterate through every map in the maps directory and set exists to true for them.
		
		--Corrupted map repairs
		if v.enabled~=nil and v.enabled==false then
			if v.enabled==nil then
				v.enabled = false
				--print("Error: "..k.." missing enabled field")
			end
			if not v.name then
				v.enabled = false
				v.name = "Unknown Map"
				--print("Error: "..k.." missing name field")
			end
			if not v.thumbnail then
				v.enabled = false
				v.thumbnail = k..".jpg"
				--print("Error: "..k.." missing thumbnail field")
			end
			if v.bigRelease==nil then
				v.bigRelease = 0
				--print("Error: "..k.." missing bigRelease field")
			end
			if v.smallRelease==nil then
				v.smallRelease = 0
				--print("Error: "..k.." missing smallRelease field")
			end
			if v.minPlayers==nil then
				v.minPlayers = -1
				--print("Error: "..k.." missing minPlayers field")
			end
			if v.maxPlayers==nil then
				v.maxPlayers = -1
				--print("Error: "..k.." missing maxPlayers field")
			end
		end
	end
	
	local maps = file.Find( "maps/*.bsp", "GAME" )
	for _, map in ipairs( maps ) do
		map = map:sub( 1, -5 ) -- Take off .bsp
		if not mapdata[map] then -- Map doesn't have a config, generate a default one
			mapdata[map] = {}
			mapdata[map].thumbnail = map..".jpg"
			local mapgame = string.lower(string.sub(map, 1, string.find(map, "_", 0, true)-1))
			local remaining = string.lower(string.sub(map, string.find(map, "_", 0, true)+1))
			
			--Get the original game this map was designed for by prefix
			--See https://developer.valvesoftware.com/wiki/Map_prefixes
			local mapgamefriendly = nil
			if mapgame == "cs" or mapgame == "de" or mapgame == "as" or mapgame == "es" or mapgame == "ar" then
				mapgamefriendly = "CS"
			elseif mapgame == "arena" or mapgame == "cp" or mapgame == "ctf" or mapgame == "tc" or mapgame == "pl" or mapgame == "plr" or mapgame == "koth" or mapgame == "sd" or mapgame == "mvm" then
				mapgamefriendly = "TF"
			elseif mapgame == "gm" then
				mapgamefriendly = "GMOD"
			elseif mapgame == "ttt" then
				mapgamefriendly = "TTT"
			elseif mapgame == "d1" or mapgame == "d2" or mapgame == "d3" or mapgame == "ep1" or mapgame == "ep2" or mapgame == "ep3" then
				mapgamefriendly = "HL"
			elseif mapgame == "testchmb" or mapgame == "escape" then
				mapgamefriendly = "P1"
			elseif mapgame == "sp" or mapgame == "mp" then
				mapgamefriendly = "P2"
				-- Portal 2 maps are prefixed by two sections, so we'll remove up to another underscore
				remaining = string.sub(remaining, string.find(remaining, "_", 0, true)+1)
			elseif mapgame == "zm" then
				mapgamefriendly = "ZM"
			elseif mapgame == "rat" or mapgame == "rats" or mapgame == "toy" then
				mapgamefriendly = "CS"
			end
			
			-- Attempt to automatically determine the version of the map
			local name = ""
			local remaining = string.Split(remaining, "_")
			mapdata[map].releaseSmall = MAPVOTE.config.defaultSmallVersion
			mapdata[map].releaseBig = MAPVOTE.config.defaultBigVersion
			for k,v in ipairs(remaining) do
				if string.find(v, "^v?[abr]c?%d*$") or string.find(v, "^v?%d*[abr]?c?$") then
					local releaseCategory = string.match(v, "[abr]c?")
					mapdata[map].releaseBig = releaseCategory=="a" and 1 or releaseCategory=="b" and 2 or releaseCategory=="rc" and 3 or releaseCategory=="r" and 4 or mapdata[map].releaseBig
					mapdata[map].releaseSmall = tonumber(string.match(v, "%d")) or mapdata[map].releaseSmall
				elseif string.lower(v)=="fix" then
					mapdata[map].releaseSmall = mapdata[map].releaseSmall+1
				elseif string.lower(v)=="final" then
					mapdata[map].releaseBig = 5
				elseif string.lower(v)=="alpha" then
					mapdata[map].releaseBig = 1
				elseif string.lower(v)=="beta" then
					mapdata[map].releaseBig = 2
				elseif string.lower(v)=="release" then
					mapdata[map].releaseBig = 4
				elseif string.lower(v)=="mc" then
					mapgamefriendly = "MC"
				else
					if string.len(v) > 2 and string.lower(v) ~= "the" then -- Give capital letters to words longer than 2 letters. Obviously does nothing for words without spaces, but camel case should be preserved
						v=string.SetChar(v, 1, string.upper(string.GetChar(v, 1)))
					end
					
					if name~="" then
						name = name.." "
					end
					name = name..v
				end
			end
			
			-- Finalise friendly name
			if mapgamefriendly then
				mapgamefriendly = " ("..mapgamefriendly..")"
			else
				mapgamefriendly = ""
			end
			
			mapdata[map].name = name..mapgamefriendly
			mapdata[map].exists = true
			mapdata[map].minPlayers = -1
			mapdata[map].maxPlayers = -1
			mapdata[map].enabled = true
		else
			mapdata[map].exists = true
		end
	end
	
	MAPVOTE.calculateVersions(mapdata)
	
	MAPVOTE.maps = mapdata
end

function MAPVOTE.saveMaps()
	file.Write("jw-ttt-map-voting/maps.txt", util.TableToJSON(MAPVOTE.maps))
end


function MAPVOTE.loadLastPlayed() -- Last Played file is for storing commonly changing info about maps.
	local lastplayeddata = {}
	local lastplayedfilecontents = file.Read("jw-ttt-map-voting/lastplayed.txt", "DATA")
	if lastplayedfilecontents then
		lastplayeddata = util.JSONToTable(lastplayedfilecontents)
		if not lastplayeddata then
			lastplayeddata = {}
			file.Write("jw-ttt-map-voting/lastplayed.old.txt", lastplayedfilecontents) -- We'll generate a new config but it's nice if we save a copy of the damaged one first
		end
	end
	
	--PrintTable(lastplayeddata)
	lastplayeddata.currentRound = lastplayeddata.currentRound or 0
	local maps = lastplayeddata.maps or {}
	lastplayeddata.maps = {}
	for k,v in pairs(MAPVOTE.maps) do
		lastplayeddata.maps[k] = maps[k] or 0
	end
	
	MAPVOTE.lastplayed = lastplayeddata
end

function MAPVOTE.saveLastPlayed()
	file.Write("jw-ttt-map-voting/lastplayed.txt", util.TableToJSON(MAPVOTE.lastplayed))
end


function MAPVOTE.beginVoting()
	MAPVOTE.currentvote = {}
	MAPVOTE.currentvote.votingTime = MAPVOTE.config.votingTime
	MAPVOTE.currentvote.votes = {}
	MAPVOTE.currentvote.maps = {}
	local playersOnline = #player.GetAll()
	
	for k,v in pairs(MAPVOTE.maps) do
		--Check the map is eligible for a vote
		----PrintTable(v)
		if not v.enabled then
			----print("Map "..v.name.." is disabled")
		elseif not v.exists then
			----print("Map "..v.name.." does not exist")
		elseif MAPVOTE.config.limitToNewestVersion and not v.highestVersion then
			----print("Older version of map "..v.name.." disabled")
		elseif MAPVOTE.config.limitByPlayers and v.minPlayers ~= -1 and playersOnline<v.minPlayers then
			----print("Not enough players for map "..v.name)
		elseif MAPVOTE.config.limitByPlayers and v.maxPlayers ~= -1 and playersOnline>v.maxPlayers then
			----print("Too many players for map "..v.name)
		else
			----print("Adding map "..v.name)
			table.insert(MAPVOTE.currentvote.maps, {friendlyname=v.name, name=k, lastplayed=MAPVOTE.lastplayed.maps[k], thumbnail=v.thumbnail})
		end
	end
	
	if #MAPVOTE.currentvote.maps < 4 then --Just in case player limitations mean that there are not 4 available maps, we populate 4 maps anyway. 
		MAPVOTE.currentvote.maps = {}
		for k,v in pairs(MAPVOTE.maps) do
			if v.enabled and v.exists and (v.highestVersion or not MAPVOTE.config.limitToNewestVersion) then
				table.insert(MAPVOTE.currentvote.maps, {friendlyname=v.name, name=k, lastplayed=MAPVOTE.lastplayed.maps[k], thumbnail=v.thumbnail})
			end
		end
	end
	
	
	if MAPVOTE.config.prioritiseLeastRecentlyPlayedMaps then
		--Sort maps by last played
		table.sort(MAPVOTE.currentvote.maps, function(a, b) return (a.lastplayed or 0) < (b.lastplayed or 0) end)
	else
		local originalMaps = table.Copy(MAPVOTE.currentvote.maps) --Randomize maps
		MAPVOTE.currentvote.maps = {}
		while #originalMaps > 0 do
			table.insert(MAPVOTE.currentvote.maps, table.remove(originalMaps, math.random(1, #originalMaps)))
		end
	end
	
	while #MAPVOTE.currentvote.maps > 4 do -- Limit to 4 maps
		table.remove(MAPVOTE.currentvote.maps, 5)
	end
	
	
	net.Start("commenceVoting") --Send to clients
		net.WriteTable(MAPVOTE.currentvote)
	net.Broadcast()
	timer.Simple(MAPVOTE.currentvote.votingTime+MAPVOTE.config.catchupTime, MAPVOTE.endVoting)
end

function MAPVOTE.receiveVote(_, ply)
	if MAPVOTE.currentvote.winner then return end --If the vote has already ended, don't accept the vote
	local mapVotedFor = net.ReadString()
	local mapExists = false
	for k,v in pairs(MAPVOTE.currentvote.maps) do
		if v.name == mapVotedFor then
			mapExists = true
		end
	end
	if mapExists then --Only allow voting for existing maps. This prevents server command injection, but also ensures there is no cheating.
		MAPVOTE.currentvote.votes[ply] = mapVotedFor
	end
	MAPVOTE.sendVotingProgress() --Send the updated voting arrangements back to clients
end
net.Receive("playerVote", MAPVOTE.receiveVote)

function MAPVOTE.sendVotingProgress() --Send a list of all votes to the clients
	net.Start("votesSoFar")
		net.WriteTable(MAPVOTE.currentvote.votes)
	net.Broadcast()
end

function MAPVOTE.endVoting()
	local mapVotes = {} --Tally up votes by map
	for k,v in pairs(MAPVOTE.currentvote.votes) do
		mapVotes[v] = (mapVotes[v] or 0)+1
	end
	
	local currentWinner = "" --Determine winning vote, and give higher priority to earlier (least recently played) maps
	local currentVotes = -1
	for k,v in ipairs(MAPVOTE.currentvote.maps) do
		--print("Checking votes for map "..v.name..": "..(mapVotes[v.name] or 0))
		if (mapVotes[v.name] or 0) > currentVotes then
			currentWinner = v.name
			currentVotes = mapVotes[v.name] or 0
		end
	end
	
	MAPVOTE.currentvote.winner = currentWinner
	net.Start("voteFinished") --Send winner to clients
		net.WriteString(MAPVOTE.currentvote.winner)
	net.Broadcast()
	timer.Simple(MAPVOTE.config.reflectionTime, MAPVOTE.changeMap)
end

function MAPVOTE.changeMap()
	RunConsoleCommand("changelevel", MAPVOTE.currentvote.winner) --Actually change the map
end

function MAPVOTE.sendTimeUntilVote()
	net.Start("timeTillVotePS") --For modified scoreboards and other such things
		net.WriteUInt(MAPVOTE.config.roundsPerMap+1-MAPVOTE.roundsSinceLastChange, 32)
	net.Broadcast()
end
hook.Add("PlayerAuthed", "sendTimeUntilVoteToNewPlayers", MAPVOTE.sendTimeUntilVote)
timer.Create("updateTimeUntilVoteAtIntervalsForGoodMeasure", 5, 0, MAPVOTE.sendTimeUntilVote)

function MAPVOTE.checkIfVote()
	MAPVOTE.roundsSinceLastChange = MAPVOTE.roundsSinceLastChange + 1
	MAPVOTE.sendTimeUntilVote()
	if MAPVOTE.roundsSinceLastChange > MAPVOTE.config.roundsPerMap then
		MAPVOTE.beginVoting()
		--doVoting = true;
		--CustomMsg(nil, "Voting will commence shortly.", Color(255,230,0,255))
		return-- true
	elseif MAPVOTE.roundsSinceLastChange+1 > MAPVOTE.config.roundsPerMap then -- Copied over from previous voting system. I think I guess and checked these numbers which is why it's ugly.
		CustomMsg(nil, "Voting will commence after this round.", Color(255,230,0,255))
	else
		CustomMsg(nil, "Voting will commence in "..MAPVOTE.config.roundsPerMap+1-MAPVOTE.roundsSinceLastChange.." rounds.", Color(255,230,0,255))
	end
	return-- false
end
hook.Add("TTTPrepareRound", "CheckIfVote", MAPVOTE.checkIfVote)


function MAPVOTE.broadcastClientConfig()
	net.Start("sendConfig")
		net.WriteTable(MAPVOTE.config.clientside)
	net.Broadcast()
end
function MAPVOTE.sendPlayerConfig(_, ply)
	print("Sending client configs to "..ply:Nick())
	net.Start("sendConfig")
		net.WriteTable(MAPVOTE.config.clientside)
	net.Send(ply)
end
net.Receive("requestConfig", MAPVOTE.sendPlayerConfig)


function MAPVOTE.checkThumbnail(ply, thumbnail)
	local targetPly = ply
	local thumbnailName = thumbnail
	local function onFailure(_)
		targetPly:ChatPrint("Missing: "..thumbnailName)
	end
	local function onSuccess(_, _, _, code)
		if code >= 400 then
			targetPly:ChatPrint("Missing: "..thumbnailName)
		else
			targetPly:ChatPrint("Success: "..thumbnailName)
		end
	end
	http.Post(MAPVOTE.config.clientside.thumbnailLocation..thumbnail, {}, onSuccess, onFailure)
end

concommand.Add("findMissingThumbnails", function(ply)
	for k,v in pairs(MAPVOTE.maps) do
		MAPVOTE.checkThumbnail(ply, v.thumbnail)
	end
end)


previousShowRoundStartPopup = ShowRoundStartPopup
ShowRoundStartPopup = function()
	if MAPVOTE.roundsSinceLastChange <= MAPVOTE.config.roundsPerMap then
		previousRoundStartPopup()
	end
end




MAPVOTE.loadConfig()
MAPVOTE.saveConfig()



MAPVOTE.loadMaps()
MAPVOTE.saveMaps() -- Save maps again to keep maps.txt always in a tidy format



MAPVOTE.loadLastPlayed()

MAPVOTE.lastplayed.currentRound = MAPVOTE.lastplayed.currentRound+1
local currentMap = string.lower(game.GetMap())
for k,v in pairs(MAPVOTE.maps) do --Fixes a bug with game.GetMap() returning lowercase map names but the table being case sensitive
	if string.lower(k) == currentMap then
		MAPVOTE.lastplayed.maps[k] = MAPVOTE.lastplayed.currentRound
	end
end

MAPVOTE.saveLastPlayed()

hook.Add("InitPostEntity", "disableDefaultMapCycle", function()
	CheckForMapSwitch = function() end --Disable TTT automatically changing the map without our consent
end)