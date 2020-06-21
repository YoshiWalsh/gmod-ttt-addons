local math = math

local GetTranslation
local GetPTranslation
hook.Add("InitPostEntity", "PerformJWRADIOInit", function()
	GetTranslation = LANG.GetTranslation
	GetPTranslation = LANG.GetParamTranslation
	LANG.AddToLanguage("English", "quick_traitor", "KOS {player}")
	LANG.AddToLanguage("English", "quick_inno", "{player} is proven!")
	LANG.AddToLanguage("English", "quick_proven", "I am proven, I may have a traitor weapon.")
	LANG.AddToLanguage("English", "quick_check", "Live check!")
end)

JWRADIO = {}
JWRADIO.Show = false

--- USER MODIFIABLE OPTIONS ---
JWRADIO.MaxNameLength = 12
JWRADIO.ArcSegments = 8
JWRADIO.FontSize = 25
JWRADIO.UnselectedAlpha = 102
JWRADIO.SelectedAlpha = 255
local inner = 0.06
local innerText = 0.16
local mid = 0.25
local outer = 0.45
JWRADIO.TimeDisplay = {}
JWRADIO.TimeDisplay.r1 = 0.04
JWRADIO.TimeDisplay.r2 = 0.06
JWRADIO.TimeDisplay.a1 = 240
JWRADIO.TimeDisplay.a2 = 300
JWRADIO.TimeDisplay.direction = -1 --1 for counter-clockwise, -1 for clockwise. Counter-clockwise seems to have a bug that draws triangles instead of trapeziums. If this functionality is important to you please contact me and I'll fix it.
JWRADIO.TimeDisplay.segments = 30
JWRADIO.TimeDisplay.color = Color(4,0,255,154)
JWRADIO.Arrow = {}
JWRADIO.Arrow.size = 15
JWRADIO.Arrow.color = Color(255,255,255,255)

JWRADIO.Commands = {
	{cmd="help",     text="quick_help", display="HELP", format=false, a1=300, a2=335, textangle=315, r1=inner, r2=mid, textdistance=innerText, c=Color(255,191,194), textcolor=Color(255,255,255)},
	{cmd="suspect",  text="quick_suspect", display="{player}\nACTS SUS", format=true, a1=335, a2=25, textangle=0, r1=inner, r2=mid, textdistance=innerText, c=Color(255,123,0), textcolor=Color(255,255,255)},
		{cmd="traitor",  text="quick_traitor", display="KOS\n{player}", format=true, a1=335, a2=25, textangle=0, r1=mid, r2=outer, c=Color(255,8,0), textcolor=Color(255,255,255)},
	
	{cmd="yes",      text="quick_yes", display="YES", format=false, a1=25, a2=70, textangle=315, r1=inner, r2=mid, textdistance=innerText, c=Color(148,255,0), textcolor=Color(255,255,255)},
	{cmd="check",    text="quick_check", display="LIVE\nCHECK", format=false, a1=70, a2=110, textangle=0, r1=inner, r2=mid, textdistance=innerText, c=Color(0,255,246), textcolor=Color(255,255,255)},
		{cmd="proven", 	text="quick_proven", display="I AM\nPROVEN", format=false, a1=70, a2=110, textangle=0, r1=mid, r2=outer, c=Color(4,0,255), textcolor=Color(0,255,17)},
	{cmd="no",       text="quick_no", display="NO", format=false, a1=110, a2=155, textangle=45, r1=inner, r2=mid, textdistance=innerText, c=Color(255,123,0), textcolor=Color(255,255,255)},
	
	{cmd="imwith",   text="quick_imwith", display="I'M WITH\n{player}", format=true, a1=155, a2=205, textangle=0, r1=inner, r2=mid, textdistance=innerText, c=Color(148,255,0), textcolor=Color(255,255,255)},
		{cmd="innocent", text="quick_inno", display="{player}\nIS PROVEN", format=true, a1=155, a2=205, textangle=0, r1=mid, r2=outer, c=Color(0,255,17), textcolor=Color(255,255,255)},
	{cmd="see",      text="quick_see", display="I SEE\n{player}", format=true, a1=205, a2=240, textangle=45, r1=inner, r2=mid, textdistance=innerText, c=Color(160,255,163), textcolor=Color(255,255,255)}
};

surface.CreateFont("radialRadioFont", {
	font = "Arial",
	size = JWRADIO.FontSize,
	weight = 700
})
-----------------------------------------------------------------------------------------------------
-------------------DON'T EDIT BEYOND THIS POINT UNLESS YOU KNOW WHAT YOU ARE DOING-------------------
-----------------------------------------------------------------------------------------------------


---- OPTIONS ----
function JWRADIO.enabledChanged(_, _, new)
	if new == 0 or new == "0" then
		JWRADIO.enabled = false
	else
		JWRADIO.enabled = true
	end
	print("JWRADIO.enabled: "..tostring(JWRADIO.enabled))
end
cvars.AddChangeCallback("jw_radio_enabled", JWRADIO.enabledChanged)
JWRADIO.enabledChanged(nil, nil, CreateConVar("jw_radio_enabled", "1", FCVAR_ARCHIVE)) -- Initial state

hook.Add("TTTSettingsTabs", "JWRADIOTTTSettings", function(dtabs)
  local dsettings = dtabs.Items[2].Panel
  do
    local dgui = vgui.Create("DForm", dsettings)
    dgui:SetName("Radial Radio")
    dgui:CheckBox("Enable enhanced (command flower style) radio menu", "jw_radio_enabled")
    return dsettings:AddItem(dgui)
  end
end)


---- GEOMETRY HELPER FUNCTIONS (because I don't think in trig) ----

function lengthdir_x(length, dir)
	return math.cos(dir*math.pi/180)*length
end

function lengthdir_y(length, dir)
	return math.sin(dir*math.pi/180)*length
end

function point_distance(x1,y1,x2,y2)
	return math.Dist(x1, y1, x2, y2)
end

function point_direction(x1,y1,x2,y2)
	return (math.atan2(y1-y2, x2-x1)*180/math.pi) --Y coordinates are swapped around to convert from screen space to geometric space. Technically this is stupid and inconsistent with lengthdir_y but it made my life easier.
end

local function isAngleBetweenAngles(angle, a1, a2)
	local angleDifference = math.abs(math.AngleDifference(a1, a2))
	local d1 = math.abs(math.AngleDifference(angle, a1))
	local d2 = math.abs(math.AngleDifference(angle, a2))
	return ((d1 <= angleDifference) and (d2 < angleDifference))
end


---- COMMAND HELPER FUNCTIONS ----

local function isSelected(mouseDistance, mouseDirection, r1, r2, a1, a2)
	if mouseDistance>r1 and mouseDistance<=r2 then
		if isAngleBetweenAngles(mouseDirection, a1, a2) then
			return true
		end
	end

	
	return false
end

local function isCommandSelected(command)
	local sw,sh = ScrW(), ScrH()
	local cx,cy = sw/2, sh/2 --Center
	local mx,my = gui.MousePos()
	local mouseDistance = point_distance(cx, cy, mx, my)
	local mouseDirection = point_direction(cx, cy, mx, my)
	if isSelected(mouseDistance, mouseDirection, command.r1*sh, command.r2*sh, command.a1, command.a2) then
		return true
	end
	
	maximumCommandAtAngle = nil
	maximumCommandDistance = 0
	for k,v in pairs(JWRADIO.Commands) do
		if isAngleBetweenAngles(mouseDirection, v.a1, v.a2) then
			if v.r2 > maximumCommandDistance then
				maximumCommandAtAngle = v
				maximumCommandDistance = v.r2
			end
		end
	end
	
	if maximumCommandAtAngle and mouseDistance >= maximumCommandDistance*sh and maximumCommandAtAngle==command then
		return true
	end
end


---- SURFACE DRAWING HELPER FUNCTIONS ----

local sSetTextPos = surface.SetTextPos
local sDrawText = surface.DrawText
local cPushModelMatrix = cam.PushModelMatrix
local cPopModelMatrix = cam.PopModelMatrix
local mSetAngles = FindMetaTable("VMatrix").SetAngles
local mSetTranslation = FindMetaTable("VMatrix").SetTranslation
local mSetScale = FindMetaTable("VMatrix").Scale

local mat = Matrix()
local matAng = Angle()
local matTrans = Vector()
local matScale = Vector()
local function drawSpecialText(txt, posX, posY, scaleX, scaleY, ang) -- Function by Wizard of Ass (http://facepunch.com/showthread.php?t=1206816&p=37362976&viewfull=1#post37362976)
	w, _ = surface.GetTextSize(txt)
	posX = posX + lengthdir_x(-w/2, ang)
	posY = posY - lengthdir_y(-w/2, ang)
	ang = 360-ang --Things were backwards
	matAng.y = ang
	mSetAngles(mat, matAng)
	matTrans.x = posX
	matTrans.y = posY
	mSetTranslation(mat, matTrans)
	matScale.x = scaleX
	matScale.y = scaleY
	--Scale(mat, matScale)
	sSetTextPos(0, 0)
	cPushModelMatrix(mat)
		sDrawText(txt)
	cPopModelMatrix()
end

local function drawMultilineSpecialText(txt, posX, posY, scaleX, scaleY, ang)
	local lines = string.Explode("\n", txt)
	--PrintTable(lines)
	local totalHeight = #lines * JWRADIO.FontSize - JWRADIO.FontSize
	local startingHeight = -totalHeight/2
	local heightStep = JWRADIO.FontSize
	local localDownDirection = (ang-90)%360
	for k,v in pairs(lines) do
		local height = startingHeight+heightStep*(k-1)
		local height = height-JWRADIO.FontSize/2 --Vertically center text
		local x = posX + lengthdir_x(height, localDownDirection)
		local y = posY - lengthdir_y(height, localDownDirection) --Because up is down. (Maths -> Programmatic coordinate system conversion)
		drawSpecialText(v, x, y, scaleX, scaleY, ang)
	end
end



local tex = surface.GetTextureID("VGUI/white.vmt")


--Dynamically generate some extra properties once only. Less computationally expensive than doing it every frame, much easier for me as a programmer than doing it manually. A compromise.
for k,v in pairs(JWRADIO.Commands) do
	---- GENERATE TRANSPARENT VERSIONS
	v.ct = Color(v.c.r, v.c.g, v.c.b, JWRADIO.UnselectedAlpha)
	v.c = Color(v.c.r, v.c.g, v.c.b, JWRADIO.SelectedAlpha)
	
	---- GENERATE POLYGONS
	local segments = math.ceil(JWRADIO.ArcSegments)
	local segmentSize = math.AngleDifference(v.a2,v.a1)/segments
	
	local polygons = {}
	
	for i=1,segments do
		local a1 = (i-1)*segmentSize + v.a1
		local a2 = i*segmentSize + v.a1
		table.insert(polygons, {
			{x = lengthdir_x(v.r1, a1), y = -lengthdir_y(v.r1, a1)},
			{x = lengthdir_x(v.r1, a2), y = -lengthdir_y(v.r1, a2)},
			{x = lengthdir_x(v.r2, a2), y = -lengthdir_y(v.r2, a2)},
			{x = lengthdir_x(v.r2, a1), y = -lengthdir_y(v.r2, a1)}
		})
	end
	
	v.polygons = polygons
	
	
	---- GENERATE TEXT GEOMETRY
	local textDirection = (math.AngleDifference(v.a2,v.a1)/2)+v.a1
	local textDistance = v.textdistance or ((v.r1+v.r2)/2)
	v.textx = lengthdir_x(textDistance, textDirection)
	v.texty = lengthdir_y(textDistance, textDirection)
end



local function lockMouse(_,x,y,ang)
	if RADIO.Show then		
		local sw,sh = ScrW(), ScrH()
		local cx,cy = sw/2, sh/2 --Center
		local mx,my = gui.MousePos()
		
		local mouseDistance = point_distance(cx, cy, mx, my)
		local mouseDirection = point_direction(cx, cy, mx, my)
		
		if mouseDistance > outer*sh then
			mouseDistance = outer*sh
			local tx = cx+lengthdir_x(mouseDistance, mouseDirection)
			local ty = cy-lengthdir_y(mouseDistance, mouseDirection)
			gui.SetMousePos(tx,ty)
		end
	end
end
hook.Add("PostThink", "radialRadioMouseLock", lockMouse)

local function DrawRadialRadioMenu()	
	if JWRADIO.Show and LocalPlayer and LocalPlayer().Alive and LocalPlayer():Alive() and LocalPlayer().IsSpec and not LocalPlayer():IsSpec() then		
		local sw,sh = ScrW(), ScrH()
		local cx,cy = sw/2, sh/2 --Center
		local mx,my = gui.MousePos()
		
		local mouseDistance = point_distance(cx, cy, mx, my)
		local mouseDirection = point_direction(cx, cy, mx, my)
		
		if mouseDistance > outer*sh then
			mouseDistance = outer*sh
			gui.SetMousePos(cx+lengthdir_x(mouseDistance, mouseDirection), cy-lengthdir_y(mouseDistance, mouseDirection))
		end
		
		local furthest = 0
		
		
		local target = RADIO:GetTarget()
		
		if target and type(target) ~= "string" then
			local targetPos = nil
			local bone = nil
			
			if target.LookupBone then
				bone = target:LookupBone("ValveBiped.Bip01_Head1")
			end
			if bone then
				targetPos = target:GetBonePosition(bone)
			else
				if target.GetPos then
					targetPos = target:GetPos()
				end
			end
			
			--[[local me = LocalPlayer()
			local myHead = me:LookupBone("ValveBiped.Bip01_Head1")
			local myPos
			if myHead then
				myPos = me:GetBonePosition(myHead)
			else
				myPos = me:GetPos()
			end
			
			local traceRes = util.TraceLine({start=myPos, endpos=targetPos, filter={me, target}, mask=MASK_ALL})]]
			--Failed attempt to prevent tracking players through walls.
			
			if targetPos then
				arrowPos = Vector(targetPos.x, targetPos.y, targetPos.z+15)
				
				local screenData = arrowPos:ToScreen()
				local sx = screenData.x
				local sy = screenData.y
				local a = JWRADIO.Arrow
				
				local p1 = {x=sx, y=sy}
				local p2 = {x=sx-a.size, y=sy-a.size}
				local p3 = {x=sx+a.size, y=sy-a.size}
				
				surface.SetTexture(tex)
				surface.SetDrawColor(a.color)
				surface.DrawPoly({p1,p2,p3})
			end
		end
		
		
		
		
		
		for _,command in pairs(JWRADIO.Commands) do
			for _,polygon in pairs(command.polygons) do
				vertices = table.Copy(polygon)
				for n,vertex in pairs(vertices) do
					vertex.x = vertex.x*sh+cx
					vertex.y = vertex.y*sh+cy
					if n~=1 then
						surface.SetDrawColor(Color(0,0,0))
						--surface.DrawLine(vertices[n-1].x, vertices[n-1].y, vertex.x, vertex.y)
					end
				end
				surface.SetTexture(tex)
				if isSelected(mouseDistance, mouseDirection, command.r1*sh, command.r2*sh, command.a1, command.a2) then
					surface.SetDrawColor(command.c)
				else
					surface.SetDrawColor(command.ct)
				end
				surface.DrawPoly(vertices)
			end
			
			local textToDraw = ""
			if command.format then
				local tgt, v = RADIO:GetTarget()
				--tgt = GetPTranslation(command.display, {player = RADIO.ToPrintable(tgt)})
				tgt = string.Interp(LANG.TryTranslation(command.display), {player = RADIO.ToPrintable(tgt)})
				--tgt = string.Interp(s.txt, {player = RADIO.ToPrintable(tgt)})
				--[[if v then
					tgt = util.Capitalize(tgt)
				end]]
				textToDraw = tgt
			else
				textToDraw = LANG.TryTranslation(command.display)
			end
			surface.SetTextColor(command.textcolor)
			surface.SetFont("radialRadioFont")
			drawMultilineSpecialText(textToDraw, cx+command.textx*sh, cy-command.texty*sh, 1, 1, command.textangle)
		end
		
		local storedTimeRemaining = RADIO.StoredTarget.t - CurTime() + 3
		local current, vague = RADIO.GetTargetType()
		if current then
			storedTimeRemaining = 3
		end
		
		if storedTimeRemaining > 0 then
			local totalDistance = (JWRADIO.TimeDisplay.a2-JWRADIO.TimeDisplay.a1)*JWRADIO.TimeDisplay.direction
			
			while totalDistance < 0 do
				totalDistance = totalDistance+360
			end

			totalDistance = totalDistance % 360
			
			
			local segmentSize = totalDistance/JWRADIO.TimeDisplay.segments
			local numSegs = math.Round(storedTimeRemaining/3 * JWRADIO.TimeDisplay.segments)

			for i=0,numSegs-1,1 do
				local a1 = JWRADIO.TimeDisplay.a1 + i*JWRADIO.TimeDisplay.direction*segmentSize
				local a2 = JWRADIO.TimeDisplay.a1 + (i+1)*JWRADIO.TimeDisplay.direction*segmentSize
				if i==numSegs-1 then
					a2 = JWRADIO.TimeDisplay.a1+(totalDistance*JWRADIO.TimeDisplay.direction*storedTimeRemaining/3) --Smoothing
				end
				local r1 = JWRADIO.TimeDisplay.r1*sh
				local r2 = JWRADIO.TimeDisplay.r2*sh
				
				local a1r1 = {x=lengthdir_x(r1, a1)+cx, y=cy-lengthdir_y(r1, a1)}
				local a2r1 = {x=lengthdir_x(r1, a2)+cx, y=cy-lengthdir_y(r1, a2)}
				local a1r2 = {x=lengthdir_x(r2, a1)+cx, y=cy-lengthdir_y(r2, a1)}
				local a2r2 = {x=lengthdir_x(r2, a2)+cx, y=cy-lengthdir_y(r2, a2)}
				
				--[[surface.SetDrawColor(Color(0,0,0))
				surface.DrawLine(a1r1.x, a1r1.y, a1r2.x, a1r2.y)
				surface.DrawLine(a1r2.x, a1r2.y, a2r2.x, a2r2.y)
				surface.DrawLine(a1r2.x, a1r2.y, a2r1.x, a2r1.y)
				surface.DrawLine(a2r1.x, a2r1.y, a1r1.x, a1r1.y)]]
				
				
				surface.SetTexture(tex)
				surface.SetDrawColor(JWRADIO.TimeDisplay.color)
				if JWRADIO.TimeDisplay.direction == -1 then
					surface.DrawPoly({a1r1, a1r2, a2r2, a2r1})
				end
				if JWRADIO.TimeDisplay.direction == 1 then
					surface.DrawPoly({a2r1, a2r2, a1r2, a2r1})
				end
			end
		end
	end
end
hook.Add("HUDPaint", "hudpaintradialradiomenu", DrawRadialRadioMenu)

function JWRADIO:SendCommand(slotidx)
   local c = self.Commands[slotidx]
   if c then
      RunConsoleCommand("jw_radio", c.cmd)
   end
end

function JWRADIO:RunSelectedCommand()
	local selectedCommand = nil
	for k,v in pairs(JWRADIO.Commands) do
		if isCommandSelected(v) then
			selectedCommand = k
		end
	end
	if selectedCommand then
		JWRADIO:SendCommand(selectedCommand)
	end
end

function JWRADIO:ResetMouse()
	local sw,sh = ScrW(), ScrH()
	local cx,cy = sw/2, sh/2 --Center
	gui.SetMousePos(cx, cy)
end

function JWRADIO:ShowRadioCommands(state)
	if not state and JWRADIO.enabled then
		self:RunSelectedCommand()
	end
	self.Show = state and JWRADIO.enabled
	gui.EnableScreenClicker(state and JWRADIO.enabled)
	self:ResetMouse()
end

local JWRADIOkeys = function(ply, bind, pressed)
	if not IsValid(ply) then return end
	
	if string.find(bind, "zoom") then
		-- open or close radio
		JWRADIO:ShowRadioCommands(pressed)
		if JWRADIO.enabled then
			return true
		end
	end
end
hook.Add("PlayerBindPress", "jwradialradiokeys", JWRADIOkeys)

local function RadioCommand(ply, cmd, arg)
   if not IsValid(ply) or #arg != 1 then
      print("ttt_radio failed, too many arguments?")
      return
   end

   if RADIO.LastRadio.t > (CurTime() - 0.5) then return end

   local msg_type = arg[1]
   local target, vague = RADIO:GetTarget()
   local msg_name = nil

   -- this will not be what is shown, but what is stored in case this message
   -- has to be used as last words (which will always be english for now)
   local text = nil

   for _, msg in pairs(JWRADIO.Commands) do
      if msg.cmd == msg_type then
         local eng = LANG.GetTranslationFromLanguage(msg.text, "english")
         text = msg.format and string.Interp(eng, {player = RADIO.ToPrintable(target)}) or eng

         msg_name = msg.text
         break
      end
   end

   if not text then
      print("ttt_radio failed, argument not valid radiocommand")
      return
   end

   if vague then
      text = util.Capitalize(text)
   end

   RADIO.LastRadio.t = CurTime()
   RADIO.LastRadio.msg = text

   -- target is either a lang string or an entity
   target = type(target) == "string" and target or tostring(target:EntIndex())

   RunConsoleCommand("_ttt_radio_send", msg_name, tostring(target))
end

local function RadioComplete(cmd, arg)
   local c = {}
   for k, cmd in pairs(JWRADIO.Commands) do
      table.insert(c, cmd.cmd)
   end
   return c
end
concommand.Add("jw_radio", RadioCommand, RadioComplete)