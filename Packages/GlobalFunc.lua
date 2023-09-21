memory.usememorydomain("RAM")

--package.loaded.SpyroPoint = nil
--require "SpyroPoint"

-- A bunch of functions and structs to be used globally in scripts.

function deepcopy(t)
    local t_type = type(t)
    local t2
    if t_type == 'table' then
        t2 = {}
        for k, v in next, t, nil do
            t2[deepcopy(k)] = deepcopy(v)
        end
        setmetatable(t2, deepcopy(getmetatable(t)))
    else -- number, string, boolean, etc
        t2 = t
    end
    return t2
end
function table.shallow_copy(t)
	local t2 = {}
	for k,v in pairs(t) do
		t2[k] = v
	end
	return t2
end
local function hex2float (c)
    if c == 0 then return 0.0 end
	
	local sign = bit.band(0x80000000, c) == 0x80000000
    if sign then
        sign = -1
    else
        sign = 1
    end
	
	local expo = bit.rshift(bit.band(0x7F800000, c), 23)
	local mant = bit.band(0x7FFFFF, c)

    local n

    if mant == 0 and expo == 0 then
        n = sign * 0.0
    elseif expo == 0xFF then
        if mant == 0 then
            n = sign * math.huge
        else
            n = 0.0/0.0
        end
    else
        n = sign * math.ldexp(1.0 + mant / 0x800000, expo - 0x7F)
    end

    return n
end
function EulerToMatrix3D(x, y, z)
	local sx, sy, sz = math.sin(-x), math.sin(-y), math.sin(-z)
	local cx, cy, cz = math.cos(-x), math.cos(-y), math.cos(-z)
	--Angles are negated before doing the math
	
	return {
		X = {X = cy*cz,             Y = -cy*sz,           Z = sy    },
		Y = {X = cx*sz + cz*sx*sy,  Y = cx*cz - sx*sy*sz, Z = -cy*sx},
		Z = {X = -cx*cz*sy + sx*sz, Y = cx*sy*sz + cz*sx, Z = cx*cy }
	}
end
function isInRange2D(Vect2a, Vect2b, range)
	return math.sqrt( (Vect2a.X-Vect2b.X)^2 + (Vect2a.Y-Vect2b.Y)^2 ) < range
end
function isInRange(Vect3a, Vect3b, range)
	return math.sqrt( (Vect3a.X-Vect3b.X)^2 + (Vect3a.Y-Vect3b.Y)^2 + (Vect3a.Z-Vect3b.Z)^2 ) < range
end

--EXVector
EXVector = {}
EXVector.t = {X, Y, Z, Pitch, Yaw, Roll}
EXVector.mt = {}
function EXVector.New(o)
	setmetatable(o, EXVector.mt)
	return o
end
EXVector.mt.__index = EXVector.t
--Methods
function EXVector.t:Copy()
	return EXVector.New{
		X     = self.X,
		Y     = self.Y,
		Z     = self.Z,
		Pitch = self.Pitch,
		Yaw   = self.Yaw,
		Roll  = self.Roll
	}
end
function EXVector.t:Magnitude()
	if not self.X or not self.Y or not self.Z then
		error("Unable to get EXVector magnitude; One or more coordinates is nil.")
	end
	
	return math.sqrt(self.X^2 + self.Y^2 + self.Z^2)
end
function EXVector.t:DotProduct(v)
	return self.X*v.X + self.Y*v.Y + self.Z*v.Z
end
function EXVector.t:GetMatrix()
	return EulerToMatrix3D(
		self.Pitch,
		self.Yaw,
		self.Roll
	)
end
function EXVector.t:Transform(R)
	--R is a rotation matrix
	return EXVector.New{
		X = R.X.X * self.X + R.Y.X * self.Y + R.Z.X * self.Z,
		Y = R.X.Y * self.X + R.Y.Y * self.Y + R.Z.Y * self.Z,
		Z = R.X.Z * self.X + R.Y.Z * self.Y + R.Z.Z * self.Z
	}
end
function EXVector.t:InverseTransform(R)
	--R is a rotation matrix
	return EXVector.New{
        X = R.X.X * self.X + R.X.Y * self.Y + R.X.Z * self.Z,
        Y = R.Y.X * self.X + R.Y.Y * self.Y + R.Y.Z * self.Z,
        Z = R.Z.X * self.X + R.Z.Y * self.Y + R.Z.Z * self.Z
    }
end
function EXVector.t:TransformByVector(v, inverse)
	if inverse then
		return self:InverseTransform(v:GetMatrix())
	else
		return self:Transform(v:GetMatrix())
	end
end
--Metamethods
EXVector.mt.__add = function(v1, v2)
	return EXVector.New{
		X = v1.X + v2.X,
		Y = v1.Y + v2.Y,
		Z = v1.Z + v2.Z
	}
end
EXVector.mt.__sub = function(v1, v2)
	return EXVector.New{
		X = v1.X - v2.X,
		Y = v1.Y - v2.Y,
		Z = v1.Z - v2.Z
	}
end
EXVector.mt.__mul = function(v1, v2)
	if type(v2) == "number" then
		return EXVector.New{
			X = v1.X * v2,
			Y = v1.Y * v2,
			Z = v1.Z * v2
		}
	elseif type(v2) == "table" then
		return EXVector.New{
			X = v1.X * v2.X,
			Y = v1.Y * v2.Y,
			Z = v1.Z * v2.Z
		}
	end
end
EXVector.mt.__eq  = function(v1, v2)
	if (v1.X     ~= v2.X    ) or
	   (v1.Y     ~= v2.Y    ) or
	   (v1.Z     ~= v2.Z    ) or
	   (v1.Pitch ~= v2.Pitch) or
	   (v1.Yaw   ~= v2.Yaw  ) or
	   (v1.Roll  ~= v2.Roll ) then
		return false
	end
	
	return true
end
EXVector.mt.__lt  = function(v1, v2)
	return v1:Magnitude() < v2:Magnitude()
end
EXVector.mt.__le  = function(v1, v2)
	return v1:Magnitude() <= v2:Magnitude()
end

--Custom memory read functions
function memory.read_EXVector(addr, be, euler)
	if euler then
		return EXVector.New{
			Pitch = memory.readfloat(addr    , be),
			Yaw   = memory.readfloat(addr+0x4, be),
			Roll  = memory.readfloat(addr+0x8, be)
		}
	else
		return EXVector.New{
			X = memory.readfloat(addr    , be),
			Y = memory.readfloat(addr+0x4, be),
			Z = memory.readfloat(addr+0x8, be)
		}
	end
end
function memory.readptr(addr)
	local ptr = memory.read_u32_be(addr)
	
	if (ptr < 0x80000000) or (ptr > 0x8FFFFFFF) then return 0 end
	
	return ptr - 0x80000000
end
function memory.read_EXcolor_be(addr)
	local val = memory.read_u32_be(addr)
	return bit.bor(bit.rshift(val, 8), bit.lshift(val, 24))
end

--Screen
--Set the values in the "Padding" table to the same as the client screen padding
Screen = {
	Size       = {X = client.screenwidth(), Y = client.screenheight()},
	Padding    = {L = 0, R = 0, T = 0, B = 0},
	BufferSize = {X = client.bufferwidth(), Y = client.bufferheight()},
	EmuPos     = {X = 0, Y = 0},
	EmuSize    = {X = client.screenwidth(), Y = client.screenheight()}, --temporary
	
	Aspect     = 1.3,
	YStretch   = 0.978
}
function Screen:GetGameArea()
	return {
		X      = self.Padding.L,
		Y      = self.Padding.T,
		Width  = self.Size.X - (self.Padding.L + self.Padding.R),
		Height = self.Size.Y - (self.Padding.T + self.Padding.B)
	}
end
function Screen:Update(d)
	self.Size.X = client.screenwidth()
	self.Size.Y = client.screenheight()
	
	local dim = self:GetGameArea()
	
	if (dim.Width/dim.Height) < self.Aspect then
		self.EmuSize.X = dim.Width
		self.EmuSize.Y = math.floor(dim.Width/self.Aspect)
		
		self.EmuPos.X = dim.X
		self.EmuPos.Y = dim.Y + math.floor((dim.Height - self.EmuSize.Y)/2)
	else
		self.EmuSize.X = math.floor(dim.Height*self.Aspect)
		self.EmuSize.Y = dim.Height
		
		self.EmuPos.X = dim.X + math.floor((dim.Width - self.EmuSize.X)/2)
		self.EmuPos.Y = dim.Y
	end
	
	--Debug
	if d then
		gui.drawRectangle(dim.X, dim.Y, dim.Width, dim.Height, "Red")
		gui.drawRectangle(self.EmuPos.X, self.EmuPos.Y, self.EmuSize.X, self.EmuSize.Y, "Blue")
	end
end
function Screen:TestInFrame(vect, safe)
	if not safe then safe = 0 end
	
	local hor = (vect.X+safe > self.EmuPos.X) and (vect.X-safe < self.EmuPos.X+self.EmuSize.X)
	local ver = (vect.Y+safe > self.EmuPos.Y) and (vect.Y-safe < self.EmuPos.Y+self.EmuSize.Y)
	
	return hor and ver
end

--Mouse
Mouse = {Input = input.getmouse()}
Mouse.Client = {
	X = client.transformPoint(Mouse.Input.X, Mouse.Input.Y).x,
	Y = client.transformPoint(Mouse.Input.X, Mouse.Input.Y).y
}
function Mouse:UpdatePos()
	self.Input = input.getmouse()
	local p = client.transformPoint(self.Input.X, self.Input.Y)
	self.Client.X = p.x
	self.Client.Y = p.y
end
Mouse.ClickCurr = false
Mouse.ClickLast = false
function Mouse:IsClicked()
	return self.ClickCurr and not self.ClickLast
end

--Camera
gCamMatrix = 0x48A1A0
gCamPos    = 0x750878
gCamFOV    = 0x750874
Camera = {FrameDelay = 3, FOV = 58.5, NearClipping = 0.3}
function Camera:Initialize()
	self.MatrixBuff = {}
	for i = 1, self.FrameDelay do
		self.MatrixBuff[i] = {
			X = {X = 1, Y = 0, Z = 0},
			Y = {X = 0, Y = 1, Z = 0},
			Z = {X = 0, Y = 0, Z = 1}
		}
	end
	
	self.PosBuff = {}
	for i = 1, self.FrameDelay do
		self.PosBuff[i] = EXVector.New{X = 0, Y = 0, Z = 0}
	end
	
	self.FOVBuff = {}
	for i = 1, self.FrameDelay do
		self.FOVBuff[i] = 1
	end
end
function Camera:UpdateMatrix()
	for i = self.FrameDelay, 2, -1 do
		for k1, v1 in pairs(self.MatrixBuff[i]) do
			for k2, _ in pairs(v1) do
				self.MatrixBuff[i][k1][k2] = self.MatrixBuff[i-1][k1][k2]
			end
		end
	end
	
	self.MatrixBuff[1].X.X = memory.readfloat(gCamMatrix     , true)
	self.MatrixBuff[1].Y.X = memory.readfloat(gCamMatrix+0x4 , true)
	self.MatrixBuff[1].Z.X = memory.readfloat(gCamMatrix+0x8 , true)
	self.MatrixBuff[1].X.Y = memory.readfloat(gCamMatrix+0x10, true)
	self.MatrixBuff[1].Y.Y = memory.readfloat(gCamMatrix+0x14, true)
	self.MatrixBuff[1].Z.Y = memory.readfloat(gCamMatrix+0x18, true)
	self.MatrixBuff[1].X.Z = memory.readfloat(gCamMatrix+0x20, true)
	self.MatrixBuff[1].Y.Z = memory.readfloat(gCamMatrix+0x24, true)
	self.MatrixBuff[1].Z.Z = memory.readfloat(gCamMatrix+0x28, true)
end
function Camera:UpdatePos()
	for i = self.FrameDelay, 2, -1 do
		self.PosBuff[i].X = self.PosBuff[i-1].X
		self.PosBuff[i].Y = self.PosBuff[i-1].Y
		self.PosBuff[i].Z = self.PosBuff[i-1].Z
	end
	
	self.PosBuff[1].X = memory.readfloat(gCamPos    , true)
	self.PosBuff[1].Y = memory.readfloat(gCamPos+0x4, true)
	self.PosBuff[1].Z = memory.readfloat(gCamPos+0x8, true)
end
function Camera:UpdateFOV()
	for i = self.FrameDelay, 2, -1 do
		self.FOVBuff[i] = self.FOVBuff[i-1]
	end
	
	self.FOVBuff[1] = memory.readfloat(gCamFOV, true)
end
function Camera:Update()
	self:UpdateMatrix()
	self:UpdatePos()
	self:UpdateFOV()
end
function Camera:GetMatrix()
	return self.MatrixBuff[self.FrameDelay]
end
function Camera:GetPos()
	return self.PosBuff[self.FrameDelay]
end
function Camera:GetFOVMult()
	return self.FOVBuff[self.FrameDelay]
end
function Camera:GetDistance(vect)
	local pos = self:GetPos()
	return math.sqrt( (vect.X-pos.X)^2 + (vect.Y-pos.Y)^2 + (vect.Z-pos.Z)^2 )
end

--3D Screen Math
function GetScreenSpace(vect) --Input is a world position EXVector
	local loc = vect - Camera:GetPos()
	
	return loc:Transform(Camera:GetMatrix())
end
function GetScreenPosition(vect) --Input is a screenspace position EXVector
	if vect.Z < 0 then return end
	
	local t   = math.tan
	local r   = math.rad
	local dim = Screen.EmuSize
	local pos = Screen.EmuPos
	local fov = Camera.FOV
	local fm  = Camera:GetFOVMult()
	
	return {
		X = (dim.X/2) + ((vect.X *  (dim.Y / 2)) / vect.Z) / t(r(fov * fm                  )/2) + pos.X,
		Y = (dim.Y/2) + ((vect.Y * -(dim.Y / 2)) / vect.Z) / t(r(fov * fm * Screen.YStretch)/2) + pos.Y
	}
end

--Displaying basic shapes and stuff on screen
Render = {}
function Render.Marker(vect, pointCol, index, label, textCol) --Point with descriptive text
	if not vect then return end
	if not pointCol then pointCol = 0xFFFFFFFF end
	if not textCol  then textCol  = 0xFFFFFFFF end
	
	--Get the screen position
	local scrSpc = GetScreenSpace(vect)
	if scrSpc.Z < Camera.NearClipping then return end
	
	local pos = GetScreenPosition(scrSpc)
	if not pos then return end
	
	--Determine size
	local size = 200/(scrSpc.Z/(1/math.tan(math.rad(Camera.FOV*Camera:GetFOVMult()))))
	if size < 4 then size = 4 end
	
	--Return if the point isn't on screen.
	if not Screen:TestInFrame(pos, size/2) then return end
	
	--Construct string with labels
	local str
	if label then
		if type(label) == "table" then
			for _, s in pairs(label) do
				if not str then str = "" end
				
				str = str..tostring(s).."\n"
			end
		else
			str = tostring(label)
		end
	end
	
	local fl = math.floor
	
	--Draw the thing
	gui.drawEllipse(fl(pos.X - size/2), fl(pos.Y - size/2),
	size, size, 0xFF000000, pointCol)
	if index then
		gui.text(fl(pos.X)+10, fl(pos.Y)-8, tostring(index), textCol)
	end
	if str then
		gui.text(fl(pos.X)-20, fl(pos.Y)+8, str, textCol)
	end
	
	--Return position and size.
	return pos, size
end

--Color manipulation
Color = {}
function Color.Split(c)
	return {
		A = bit.rshift(bit.band(c, 0xFF000000), 24),
		R = bit.rshift(bit.band(c, 0x00FF0000), 16),
		G = bit.rshift(bit.band(c, 0x0000FF00), 8),
		B = bit.band(c, 0x000000FF)
	}
end
function Color.Join(col)
	local c = 0
	
	c=c+bit.lshift(col.A, 24)
	c=c+bit.lshift(col.R, 16)
	c=c+bit.lshift(col.G,  8)
	c=c+col.B
	
	return c
end
function Color.Blend(c1, c2, f)
	local col1 = Color.Split(c1)
	local col2 = Color.Split(c2)
	if not f then f = 0.5 end
	if f > 1 then f = 1 end
	if f < 0 then f = 0 end
	
	return Color.Join{
		A = math.floor(col1.A*f + col2.A*(1-f)),
		R = math.floor(col1.R*f + col2.R*(1-f)),
		G = math.floor(col1.G*f + col2.G*(1-f)),
		B = math.floor(col1.B*f + col2.B*(1-f))
	}
end
function Color.Brighten(c, p)
	if p > 1 then p = 1 end
	if p < 0 then p = 0 end
	
	local col = Color.Split(c)
	
	local newcol = {A = col.A}
	for k, v in pairs(col) do
		if not (k == "A") then --Ignore aplha channel
			newcol[k] = v + math.floor((0xFF-v)*p)
		end
	end
	
	return Color.Join(newcol)
end
function Color.Darken(c, p)
	if p > 1 then p = 1 end
	if p < 0 then p = 0 end
	
	local col = Color.Split(c)
	
	local newcol = {A = col.A}
	for k, v in pairs(col) do
		if not (k == "A") then --Ignore aplha channel
			newcol[k] = math.floor(v*(1-p))
		end
	end
	
	return Color.Join(newcol)
end
function Color.SetAlpha(c, a)
	if a < 0    then a = 0    end
	if a > 0xFF then a = 0xFF end
	local col = Color.Split(c)
	
	return Color.Join{
		A = a,
		R = col.R,
		G = col.G,
		B = col.B,
	}
end

--function getDistFromCam(vect3) --depricated
--	local camera = SpyroPoint.camPos
--	return math.sqrt( (vect3.X-camera.X)^2 + (vect3.Y-camera.Y)^2 + (vect3.Z-camera.Z)^2 )
--end
