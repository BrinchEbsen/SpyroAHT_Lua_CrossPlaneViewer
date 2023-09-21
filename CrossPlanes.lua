console.clear()
memory.usememorydomain("RAM")

--package.loaded.Trigger = nil
--package.loaded.Triggers = nil
--require "Packages\\Triggers"
require "Packages\\GlobalFunc"
require "Packages\\Hashcodes"
require "Packages\\LevelNames"

currInput = input.get()
lastInput = input.get()

local firstFrame = true
local lastloadedmaps

local arrSpinAng = 0
local arrSpinSpeed = 0.03

local gpCurrentMap = 0x4CB60C
local gNumMaps     = 0x4cb608
local gMapList     = 0x46EE54
local gpPlayerItem = 0x4CB360

--Window
forms.destroyall()
local windowToggles = forms.newform(180, 150, "Toggles")
forms.setlocation(windowToggles, client.xpos()+client.screenwidth(), client.ypos())

local formOffs = 5

local labelUpdate = forms.label(windowToggles, "Display:", 4, formOffs, 150, 14)
formOffs=formOffs+15

local checkRenderPlanes = forms.checkbox(windowToggles, "CrossPlanes", 4, formOffs)
forms.setproperty(checkRenderPlanes, "Checked", true)
formOffs=formOffs+20

local checkRenderArrows = forms.checkbox(windowToggles, "Arrows", 4, formOffs)
forms.setproperty(checkRenderArrows, "Checked", true)
formOffs=formOffs+20

local checkRenderCrosses = forms.checkbox(windowToggles, "Crosses", 4, formOffs)
forms.setproperty(checkRenderCrosses, "Checked", true)
formOffs=formOffs+20

local checkRenderText = forms.checkbox(windowToggles, "Markers", 4, formOffs)
forms.setproperty(checkRenderText, "Checked", true)
formOffs=formOffs+20

local checkMsg = forms.checkbox(windowToggles, "Messages", 4, formOffs)
forms.setproperty(checkMsg, "Checked", true)
formOffs=formOffs+20

local checkLoadedMaps = forms.checkbox(windowToggles, "Loaded Maps", 4, formOffs)
forms.setproperty(checkLoadedMaps, "Checked", true)

Player = {
	Position = EXVector.New{},
	Loaded = false
}
function Player:Update()
	local playerItem = memory.readptr(gpPlayerItem)
	
	if playerItem ~= 0 then
		self.Loaded = true
		self.Position.X = memory.readfloat(playerItem + 0xD0, true)
		self.Position.Y = memory.readfloat(playerItem + 0xD4, true)
		self.Position.Z = memory.readfloat(playerItem + 0xD8, true)
	else
		self.Loaded = false
		self.Position.X = nil
		self.Position.Y = nil
		self.Position.Z = nil
	end
end

function table.copy(t)
	local n = {}
	for k, v in pairs(t) do
		n[k] = v
	end
	return n
end
function checkTableIdentical(t1, t2)
	if (not t1) and (not t2) then return true  end
	--Here, at least one of the values are tables
	if (not t1) or  (not t2) then return false end
	--Here, both of the values are tables
	
	if table.getn(t1) ~= table.getn(t2) then return false end
	--Here, both of the tables have the same size
	
	for k, v in ipairs(t1) do
		if v ~= t2[k] then return false end
	end
	--Here, both of the tables contain the same values
	
	return true
end

local MapGlobals = {}
for i = 0, memory.read_u32_be(gNumMaps)-1 do
	MapGlobals[i] = {}
	MapGlobals[i].Address = memory.readptr(gMapList + (i * 0x4))
	
	MapGlobals[i].FileHash = memory.read_u32_be(MapGlobals[i].Address + 0xDC)
	if EXHashcodes[MapGlobals[i].FileHash] then
		MapGlobals[i].File = EXHashcodes[MapGlobals[i].FileHash]:gsub("HT_File_", "")
	else
		MapGlobals[i].File = "Map 0x"..bizstring.hex(MapGlobals[i].FileHash)
	end
	
	MapGlobals[i].MapHash = memory.read_u32_be(MapGlobals[i].Address + 0xE0)
	if bit.band(MapGlobals[i].MapHash, 0xFFFFFF00) == 0x05000000 then
		--Include only the hash lables useful to us
		if MapGlobals[i].MapHash >= 0x0500000B and MapGlobals[i].MapHash <= 0x05000012 then
		--if MapGlobals[i].MapHash ~= 0x05000000 then
			MapGlobals[i].Map = EXHashcodes[MapGlobals[i].MapHash]:gsub("HT_", "")
		end
	end
end
--Returns luatable with tables of the maps currently loaded, returns nil if no maps are loaded.
function GetLoadedMaps()
	local loadedmaps
	local i = 0
	
	--Map at address 0x46F4C0 seems to be a dummy map the script shouldn't read (file hash is 0xFFFFFFFF)
	for _, map in pairs(MapGlobals) do
		if map.Address ~= 0x46F4C0 and memory.read_u32_be(map.Address + 0x54) == 3 then
			if not loadedmaps then loadedmaps = {} end
			
			i=i+1
			table.insert(loadedmaps, i, map)
		end
	end
	
	return loadedmaps
end

CrossPlane = {}
CrossPlane.t = {
	TrigIndex,
	Position,
	Rotation,
	Matrix,
	Width,
	Height,
	Type,
	Map,
	SubMap,
	Verts,
	Normal,
	DistFromCam,
	Side,
	LastSide,
	PlayerRelative
}
function CrossPlane.t:GetVerts()
	self.Matrix = self.Rotation:GetMatrix()
	
	self.Verts = {
		[1] = EXVector.New{X =   self.Width/2,  Y =   self.Height/2,  Z = 0}:Transform(self.Matrix),
		[2] = EXVector.New{X =   self.Width/2,  Y = -(self.Height/2), Z = 0}:Transform(self.Matrix),
		[3] = EXVector.New{X = -(self.Width/2), Y = -(self.Height/2), Z = 0}:Transform(self.Matrix),
		[4] = EXVector.New{X = -(self.Width/2), Y =   self.Height/2,  Z = 0}:Transform(self.Matrix)
	}
	
	self.Normal = EXVector.New{X = 0, Y = 0, Z = 1}:Transform(self.Matrix)
end
function CrossPlane.t:ReportPlayerCross()
	local str = ""
	if self.Type == "LoadMap" or self.Type == "LoadMapLift" then
		str=str.."Load "
	else
		str=str.."Unload "
	end
	str=str.."trigger for "
	
	if LevelNames[self.Map] then
		str=str..LevelNames[self.Map]
	else
		str=str..self.Map
	end
	
	if self.SubMap then
		str=str.." ("..self.SubMap..")"
	end
	
	str=str.." has been passed through."
	
	gui.addmessage(str)
	--console.log(str)
end
function CrossPlane.t:CheckPlayerCross()
	if not Player.Loaded then return end
	local playerLocal   = Player.Position - self.Position
	self.PlayerRelative = playerLocal:InverseTransform(self.Matrix)
	
	self.LastSide = self.Side
	
	if self.PlayerRelative.Z < 0 then
		self.Side = -1
	else
		self.Side = 1
	end
	
	--Report if player has passed through trigger
	if forms.ischecked(checkMsg) then
		if self.Side ~= self.LastSide and self.LastSide ~= 0 then
			local pos = self.PlayerRelative
			
			if self.LastSide > self.Side then
				if pos.X > -self.Width/2  and pos.X < self.Width/2  and
				pos.Y > -self.Height/2 and pos.Y < self.Height/2 then
					self:ReportPlayerCross()
				end
			end
		end
	end
end
function CrossPlane.t:Read(trig, trigSubType)
	self.Position    = memory.read_EXVector(trig, true)
	self.Rotation    = memory.read_EXVector(trig+0x80, true, true)
	self.Width       = memory.readfloat(trig+0x2C, true)
	self.Height      = memory.readfloat(trig+0x30, true)
	self.Type        = EXHashcodes[trigSubType]:gsub("HT_TriggerSubType_", "")
	self.TrigIndex   = memory.read_u32_be(trig + 0x98)
	
	local maphash = memory.read_u32_be(trig+0x34)
	if EXHashcodes[maphash] then
		self.Map = EXHashcodes[maphash]:gsub("HT_File_", "")
	else
		self.Map = "ERR (0x"..bizstring.hex(maphash)..")"
	end
	
	local submaphash
	local h1 = memory.read_u32_be(trig+0x38)
	local h2 = memory.read_u32_be(trig+0x3C)
	if bit.band(h1, 0xFFFFFF00) == 0x05000000 then
		submaphash = h1
	elseif bit.band(h2, 0xFFFFFF00) == 0x05000000 then
		submaphash = h2
	end
	if submaphash then
		if submaphash == 0x05000000 then
			self.SubMap = nil
		elseif EXHashcodes[submaphash] then
			self.SubMap = EXHashcodes[submaphash]:gsub("HT_", "")
		else
			self.SubMap = nil
		end
	else
		self.SubMap = nil
	end
	
	self.PlayerRelative = EXVector.New{X = 0, Y = 0, Z = 0}
	self.Side = 0
	self.LastSide = 0
	
	self:GetVerts()
	self:CheckPlayerCross()
end
function CrossPlane.t:DrawPlane(l_col, p_col)
	if not l_col then l_col = 0xFFFFFFFF end
	if not p_col then p_col = 0x20FFFFFF end
	
	local onScreen = true
	
	local vertsSpc = {}
	local vertsPos = {}
	for i, vert in ipairs(self.Verts) do
		vertsSpc[i] = GetScreenSpace(vert + self.Position)
		
		--If any vertex is behind the camera, skip drawing.
		if vertsSpc[i].Z < 0 then return end
		
		vertsPos[i] = GetScreenPosition(vertsSpc[i])
		
		--if Screen:TestInFrame(vertsPos[i]) then
		--	onScreen = true
		--end
	end
	
	if onScreen then
		gui.drawPolygon(
			{
				{vertsPos[1].X, vertsPos[1].Y},
				{vertsPos[2].X, vertsPos[2].Y},
				{vertsPos[3].X, vertsPos[3].Y},
				{vertsPos[4].X, vertsPos[4].Y}
			},
			0, 0, l_col, p_col
		)
	end
end
function CrossPlane.t:DrawArrow(s, col)
	-- s = arrow scaling
	if not s then s = 1 end
	if not col then col = "White" end
	
	local arrWidth = 0.15
	local arrAngle = 0.01
	local arrVerts = {}
	
	local pos = self.Position
	local norm = self.Normal
	local spinX = math.cos(arrSpinAng)
	local spinY = math.sin(arrSpinAng)
	
	arrVerts.Tip   = pos:Copy()
	arrVerts.Tail  = pos + norm * s
	
	arrVerts.Side1 = pos + norm + 
		EXVector.New{
			X = spinX * (-arrWidth) * s,
			Y = spinY * (-arrWidth) * s,
			Z = arrAngle * s
		}:Transform(self.Matrix)
	
	arrVerts.Side2 = pos + norm + 
		EXVector.New{
			X = spinX * arrWidth * s,
			Y = spinY * arrWidth * s,
			Z = arrAngle * s
		}:Transform(self.Matrix)
	
	local onScreen = false
	
	local arrVertsSpc = {}
	local arrVertsPos = {}
	for k, v in pairs(arrVerts) do
		arrVertsSpc[k] = GetScreenSpace(v)
		
		--If any vertex is behind the camera, skip drawing.
		if arrVertsSpc[k].Z < 0 then return end
		
		arrVertsPos[k] = GetScreenPosition(arrVertsSpc[k])
		
		if Screen:TestInFrame(arrVertsPos[k]) then
			onScreen = true
		end
	end
	
	if onScreen then
		gui.drawLine(arrVertsPos.Tip.X, arrVertsPos.Tip.Y, arrVertsPos.Tail.X,  arrVertsPos.Tail.Y , col)
		gui.drawLine(arrVertsPos.Tip.X, arrVertsPos.Tip.Y, arrVertsPos.Side1.X, arrVertsPos.Side1.Y, col)
		gui.drawLine(arrVertsPos.Tip.X, arrVertsPos.Tip.Y, arrVertsPos.Side2.X, arrVertsPos.Side2.Y, col)
	end
end
function CrossPlane.t:DrawCross(s, col)
	-- s = cross scaling
	if not s then s = 1 end
	if not col then col = "White" end
	
	local crossVerts = {}
	
	local pos  = self.Position
	local norm = self.Normal
	
	local playerPos = Player.Position
	
	local playerLocal = playerPos - pos
	local playerRelative = playerLocal:InverseTransform(self.Matrix)
	playerRelative.Z = 0
	
	if (playerRelative.X < -(self.Width/2) or playerRelative.X > (self.Width/2)) or
		(playerRelative.Y < -(self.Height/2) or playerRelative.Y > (self.Height/2)) then
		return
	end
	
	local crossPos = playerRelative:Transform(self.Matrix) + pos
	
	--Render.Marker(crossPos)
	
	local spin1X = math.cos(arrSpinAng)
	local spin1Y = math.sin(arrSpinAng)
	local spin2X = math.cos(arrSpinAng + math.pi/2)
	local spin2Y = math.sin(arrSpinAng + math.pi/2)
	
	local crossVerts = {
		[1] = EXVector.New{X =  s * spin1X, Y =  s * spin1Y, Z = 0}:Transform(self.Matrix) + crossPos,
		[2] = EXVector.New{X = -s * spin1X, Y = -s * spin1Y, Z = 0}:Transform(self.Matrix) + crossPos,
		[3] = EXVector.New{X =  s * spin2X, Y =  s * spin2Y, Z = 0}:Transform(self.Matrix) + crossPos,
		[4] = EXVector.New{X = -s * spin2X, Y = -s * spin2Y, Z = 0}:Transform(self.Matrix) + crossPos
	}
	
	local crossVertsSpc = {}
	local crossVertsPos = {}
	local onScreen = false
	
	for k, v in pairs(crossVerts) do
		crossVertsSpc[k] = GetScreenSpace(v)
		
		--If any vertex is behind the camera, skip drawing.
		if crossVertsSpc[k].Z < 0 then return end
		
		crossVertsPos[k] = GetScreenPosition(crossVertsSpc[k])
		
		if Screen:TestInFrame(crossVertsPos[k]) then
			onScreen = true
		end
	end
	
	--Draw a circle
	--local topSide   = EXVector.New{X = 0, Y = s, Z = 0}:Transform(self.Matrix) + crossPos
	--local rightSide = EXVector.New{X = s, Y = 0, Z = 0}:Transform(self.Matrix) + crossPos
	--local circleC = GetScreenPosition(GetScreenSpace(crossPos))
	--local circleW = circleC.X - GetScreenPosition(GetScreenSpace(rightSide)).X
	--local circleH = circleC.Y - GetScreenPosition(GetScreenSpace(topSide)).Y
	
	if onScreen then
		gui.drawLine(crossVertsPos[1].X, crossVertsPos[1].Y, crossVertsPos[2].X, crossVertsPos[2].Y, col)
		gui.drawLine(crossVertsPos[3].X, crossVertsPos[3].Y, crossVertsPos[4].X, crossVertsPos[4].Y, col)
		--gui.drawEllipse(circleC.X-circleW, circleC.Y-circleH, circleW*2, circleH*2, col)
	end
end
function CrossPlane.t:Render()
	local linecol
	local typeName
	
	if self.Type == "LoadMap" then
		linecol  = 0xFF0000FF
		typeName = "Load"
	elseif self.Type == "CloseMap" then
		linecol  = 0xFFFF0000
		typeName = "Unload"
	elseif self.Type == "LoadMapLift" then
		linecol  = 0xFFA030FF
		typeName = "Load (Elevator)"
	elseif self.Type == "CloseMapLift" then
		linecol  = 0xFFFFA040
		typeName = "Unload (Elevator)"
	else
		linecol  = 0xFFFFFFFF
		typeName = "Undefined"
	end
	local planecol = Color.SetAlpha(linecol, 0x20)
	local textcol  = Color.Brighten(linecol, 0.7)
	
	if forms.ischecked(checkRenderPlanes) then
		self:DrawPlane(linecol, planecol)
	end
	
	if forms.ischecked(checkRenderArrows) then
		self:DrawArrow(3, textcol)
	end
	
	if forms.ischecked(checkRenderCrosses) then
		if Camera:GetDistance(self.Position) < 40 then
			self:DrawCross(0.5, textcol)
		end
	end
	
	if forms.ischecked(checkRenderText) then
		local labels = {}
		
		table.insert(labels, typeName)
		if LevelNames[self.Map] then
			table.insert(labels, LevelNames[self.Map])
		else
			table.insert(labels, self.Map)
		end
		if self.SubMap then
			table.insert(labels, self.SubMap)
		end
		
		Render.Marker(self.Position, linecol, nil, labels, textcol)
	end
end

CrossPlane.mt = {}
function CrossPlane.New(o)
	setmetatable(o, CrossPlane.mt)
	return o
end
CrossPlane.mt.__index = CrossPlane.t
CrossPlane.mt.__tostring = function(self)
	local str = "Trigger: "..tostring(self.TrigIndex).."\n"
	str = str.."Type: "..self.Type.."\n"
	str = str..string.format("Position:\n  X: %.3f\n  Y: %.3f\n  Z: %.3f\n",
	self.Position.X, self.Position.Y, self.Position.Z)
	str = str..string.format("Rotation:\n  P: %.3f\n  Y: %.3f\n  R: %.3f\n",
	self.Rotation.Pitch, self.Rotation.Yaw, self.Rotation.Roll)
	str = str..string.format("Size:\n  Width:  %.3f\n  Height: %.3f\n\n",
	self.Width, self.Height)
	
	str = str.."Verts:\n"
	for i, vert in ipairs(self.Verts) do
		str = str..string.format(tostring(i)..":\n  X: %.3f\n  Y: %.3f\n  Z: %.3f\n", vert.X, vert.Y, vert.Z)
	end
	return str
end

CrossPlanes = {List = {}}
function CrossPlanes:Update(loadedmaps)
	local i = 0
	
	for _, map in pairs(loadedmaps) do
		local triggerListSize = memory.read_u32_be(map.Address + 0x108)
		--print("Reading "..tostring(triggerListSize).." triggers from pointer in map "..map.File.." ("..bizstring.hex(map.Address)..")")
		local triggerList = memory.readptr(map.Address + 0x10C)
		
		for j = 0, triggerListSize-1 do
			--print("Reading trigger "..tostring(j+1))
			local trig = memory.readptr(triggerList + j*0x4)
			
			local trigType    = memory.read_u32_be(trig + 0xBC)
			local trigSubType = memory.read_u32_be(trig + 0xC0)
			
			--If trigger is a CrossPlane for loading/unloading maps, add it to the list
			if  trigType == 0x4100005A and --TriggerType    (CrossPlane)
			(trigSubType == 0x4200001A or  --TriggerSubType (Load)
			 trigSubType == 0x4200001B or  --TriggerSubType (Unload)
			 trigSubType == 0x42000083 or  --TriggerSubType (Elevator Unload)
			 trigSubType == 0x42000084)    --TriggerSubType (Elevator Load)
			then
				i=i+1
				
				self.List[i] = self.List[i] or CrossPlane.New{}
				self.List[i]:Read(trig, trigSubType)
			end
		end
	end
	
	--Sanitize List
	local amt = table.getn(self.List)
	if amt > i then
		for j = amt, i, -1 do
			self.List[j] = nil
		end
	end
end
function CrossPlanes:RenderAll()
	for _, plane in pairs(self.List) do
		plane.DistFromCam = Camera:GetDistance(plane.Position)
	end
	
	local renderList = {}
	
	for k, v in ipairs(self.List) do
		renderList[k] = v
	end
	
	table.sort(renderList, function(a, b) return a.DistFromCam > b.DistFromCam end)
	for _, plane in ipairs(renderList) do
		plane:Render()
	end
end
function CrossPlanes:PrintAll()
	for _, plane in ipairs(self.List) do
		console.log(tostring(plane))
	end
	return ""
end

function displayLoadedMaps(loadedmaps)
	gui.text(0, 20, "Currently Loaded Maps:", 0xFFC0C0FF)
	local textpos = 35
	
	for _, map in pairs(loadedmaps) do
		local str
		local col = 0xA0FFFFFF
		if memory.readptr(gpCurrentMap) == map.Address then
			col = 0xFFFFFFFF
		end
		
		if LevelNames[map.File] then
			str = LevelNames[map.File]
		else
			str = map.File
		end
		if map.Map then
			str=str.." ("..map.Map..")"
		end
		--str=str.."\n  0x"..bizstring.hex(map.Address)
		
		gui.text(0, textpos, str, col)
		
		textpos = textpos+15
	end
end

Camera:Initialize()

client.setwindowsize(1)
client.SetClientExtraPadding(0, 0, 0, 0)
gui.use_surface("client")

while true do
	currInput = input.get()
	
	gui.clearGraphics()
	Camera:Update()
	Screen:Update()
	
	Player:Update()
	
	--Spin arrows around with a global spin variable
	arrSpinAng = arrSpinAng + arrSpinSpeed
	if arrSpinAng > math.pi then
		arrSpinAng = -math.pi
	end
	
	local loadedmaps = GetLoadedMaps()
	
	local doUpdate = false
	if loadedmaps then
		if not checkTableIdentical(loadedmaps, lastloadedmaps) then
			--gui.addmessage("Change in loaded maps")
			doUpdate = true
		end
		lastloadedmaps = table.copy(loadedmaps)
		
		--Update every 60 frames just to be sure
		if emu.framecount() % 60 == 0 then doUpdate = true end
		
		if currInput["K"] and (lastInput["K"] ~= true) then
			doUpdate = true
		end
		
		if forms.ischecked(checkLoadedMaps) then
			displayLoadedMaps(loadedmaps)
		end
		
		for _, plane in pairs(CrossPlanes.List) do
			plane:CheckPlayerCross()
		end
	else
		for k, _ in pairs(CrossPlanes.List) do
			CrossPlanes.List[k] = nil
		end
		lastloadedmaps = nil
	end
	
	if doUpdate then
		CrossPlanes:Update(loadedmaps)
	end
	
	CrossPlanes:RenderAll()
	--SpyroPoint:renderPoint(Player.Position, 0xFFFF00FF, nil, {"Player"})
	
	lastInput = input.get()
	firstFrame = false
	
	emu.frameadvance()
end