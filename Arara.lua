--[[
	SBO:R Auto Farm
	Clean rebuild - Custom Path only, multi-floor, priority-driven
]]

local Players            = game:GetService("Players")
local Replicated         = game:GetService("ReplicatedStorage")
local StarterGui         = game:GetService("StarterGui")
local RunService         = game:GetService("RunService")
local UserInputService   = game:GetService("UserInputService")
local MarketplaceService = game:GetService("MarketplaceService")
local HttpService        = game:GetService("HttpService")
local VirtualUser        = game:GetService("VirtualUser")
local TeleportService    = game:GetService("TeleportService")

local Player    = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui", 30)
if not PlayerGui then
	error("[SBOR Auto Farm] PlayerGui not found")
end

----------------------------------------------------------------------
-- CONFIG
----------------------------------------------------------------------
local CONFIG = {
	VERSION = "2.3.2R",
	CONFIG_DIR = "SBOR_Configs",

	-- Combat / movement
	MOB_DETECTION_DISTANCE = 450,
	PLAYER_ATTACK_DISTANCE = 8,
	GOBLIN_REACH_DISTANCE = 8,
	ENEMY_ATTACK_SAFE_DISTANCE = 2,
	ENEMY_BLADE_PADDING = 2,
	GROUP_DANGER_DISTANCE = 22,
	THREAT_DETECTION_DISTANCE = 12,
	THREAT_ANGLE = 65,
	THREAT_ESCAPE_DISTANCE = 20,

	ATTACK_INTERVAL = 0.2,
	SKILL_INTERVAL = 3,
	CONSUME_INTERVAL = 10,
	INTERACTION_INTERVAL = 0.5,
	BLOCK_COOLDOWN = 3,

	MINIMUM_WALKSPEED = 28,
	MAXIMUM_WALKSPEED = 38,

	MOB_VALIDATION_INTERVAL = 0.15,
	SAFECOMBAT_INTERVAL = 0.25,
	BLADE_PART_CACHE_INTERVAL = 0.2,
	COMBAT_GROUP_CACHE_INTERVAL = 0.15,
	TARGET_REPOSITION_INTERVAL = 0.3,
	TARGET_UNREACHABLE_TIMEOUT = 10,
	SAFE_COMBAT_DIRECTIONS = 12,
	SAFE_COMBAT_MAX_PATH_TESTS = 4,
	TARGET_REPOSITION_DIRECTIONS = 16,

	RETREAT_DISTANCE = 60,
	RETREAT_DIRECTIONS = 16,
	RETREAT_RECALCULATE_INTERVAL = 0.5,

	PATH_REACH_DISTANCE = 6,
	INTERACT_COOLDOWN = 0.55,
	STUCK_CHECK_INTERVAL = 0.5,
	JUMP_HEIGHT = 2,

	RETURN_TO_FARM_DISTANCE = 80,
	RETURN_TO_FARM_INTERVAL = 8,

	PATROL_RADIUS_MIN = 28,
	PATROL_RADIUS_MAX = 60,
	PATROL_RECALCULATE_INTERVAL = 12,
	PATROL_ESCAPE_DISTANCE = 10,
	PATROL_ESCAPE_DIRECTIONS = 4,
	PATROL_DIRECTIONS = 12,

	WATER_SAMPLE_DISTANCE = 4,
	DEADZONE_SAMPLE_DISTANCE = 2,
	MAX_SERVER_AGE = 7 * 60 * 60,

	-- Defaults (overridden by UI / save)
	TARGET_ENTITY_PRIORITY = {},
	-- Paths keyed by entity name:
	-- Paths["Goblin"] = { Waypoints = {...}, FarmCenter, FarmRadius, DeadzoneCenter, DeadzoneRadius }
	Paths = {},
	ActivePathEntity = nil, -- currently selected farm target for path
	CurrentWaypoint = 1,
	UseCustomFarmZone = false,
	FarmCenter = nil,
	FarmRadius = 200,
	DeadzoneCenter = nil,
	DeadzoneRadius = 35,

	-- Friendly floor names (add more as you discover PlaceIds)
	-- Key = PlaceId, Value = display name
	FLOOR_MAP = {
		[11987539001] = "Floor 16",
		[10299594856] = "Event Floor",
		-- ตัวอย่าง: [123456789] = "Floor 12",
	},

	-- Theme
	UI_BG       = Color3.fromRGB(16, 17, 22),
	UI_PANEL    = Color3.fromRGB(22, 24, 32),
	UI_SURFACE  = Color3.fromRGB(30, 33, 42),
	UI_HOVER    = Color3.fromRGB(40, 44, 56),
	UI_BORDER   = Color3.fromRGB(55, 60, 75),
	UI_TEXT     = Color3.fromRGB(240, 242, 248),
	UI_MUTED    = Color3.fromRGB(140, 146, 160),
	UI_ACCENT   = Color3.fromRGB(99, 120, 255),
	UI_SUCCESS  = Color3.fromRGB(72, 180, 90),
	UI_DANGER   = Color3.fromRGB(230, 70, 70),
	UI_WARN     = Color3.fromRGB(230, 170, 50),
}

----------------------------------------------------------------------
-- STATE
----------------------------------------------------------------------
local Feature = {
	AutoFarm        = false,
	AutoBlock       = false,
	SafeCombat      = false,
	AutoPatrol      = false,
	AutoSkill       = false,
	IgnoreFarmZone  = false,
	ResetOnBoostOut = false,
	AntiAfk         = false,
}

local Character, Humanoid, RootPart
local ClosestTarget = nil
local ValidMobs = {}
local DEATH_COUNT = 0
local Enabled = false
local Equipped = false
local RETREATING = false
local InputBindableFunction = nil

local LAST_ATTACK_TIME, LAST_SKILL_TIME, LAST_CONSUME_TIME = 0, 0, 0
local LAST_INTERACTION_TIME, LAST_MOB_VALIDATION, LAST_TEXT = 0, 0, 0
local LAST_STUCK_TIME, LAST_STUCK_POS = 0, nil
local LAST_SAFECOMBAT_TIME, CACHED_SAFE_POS = 0, nil
local LAST_PATH_INTERACT = 0
local LAST_FORCE_RETURN = 0
local ForcingReturn = false

local TargetUnreachableSince = nil
local TargetApproachPosition = nil
local TargetApproachMob = nil
local LastTargetRepositionTime = 0

local BladePartCache, CombatGroupCache, CombatBladeCache = {}, {}, {}
local BlockCache = {}
local FaceAttachment, FaceOrientation
local PatrolPosition, LastPatrolTime = nil, 0
local FarmReturnPosition, LastFarmReturnTime = nil, 0
local ProfileName = "Default"
local PlaceNameCache = "Loading..."
local FloorLabel = nil -- optional user override saved in config

local function GetFloorDisplayName()
	if type(FloorLabel) == "string" and FloorLabel ~= "" then
		return FloorLabel
	end
	local mapped = CONFIG.FLOOR_MAP[game.PlaceId]
	if mapped then
		return mapped
	end
	if PlaceNameCache and PlaceNameCache ~= "Loading..." then
		return PlaceNameCache
	end
	return "Place " .. tostring(game.PlaceId)
end

local function GetHeaderSubtitle()
	return GetFloorDisplayName() .. "  |  " .. tostring(game.PlaceId)
end

----------------------------------------------------------------------
-- CHARACTER
----------------------------------------------------------------------
local function updateCharacter()
	Character = Player.Character
	if not Character then
		Humanoid, RootPart = nil, nil
		return
	end
	Humanoid = Character:FindFirstChildOfClass("Humanoid")
	RootPart = Character:FindFirstChild("HumanoidRootPart")

	if RootPart and not FaceAttachment then
		FaceAttachment = Instance.new("Attachment")
		FaceAttachment.Name = "FaceAttach"
		FaceAttachment.Parent = RootPart
	end
	if RootPart and not FaceOrientation then
		FaceOrientation = Instance.new("AlignOrientation")
		FaceOrientation.Name = "FaceAlign"
		FaceOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
		FaceOrientation.Attachment0 = FaceAttachment
		FaceOrientation.RigidityEnabled = false
		FaceOrientation.Responsiveness = 25
		FaceOrientation.MaxTorque = math.huge
		FaceOrientation.Enabled = false
		FaceOrientation.Parent = RootPart
	end
	task.defer(function()
		if not Humanoid then return end
		Humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
		Humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
		Humanoid:SetStateEnabled(Enum.HumanoidStateType.Physics, false)
		Humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
	end)
end
updateCharacter()

local function ResetCombatLock()
	ClosestTarget = nil
	TargetUnreachableSince = nil
	TargetApproachPosition = nil
	TargetApproachMob = nil
	CACHED_SAFE_POS = nil
	table.clear(ValidMobs)
	table.clear(CombatGroupCache)
	table.clear(CombatBladeCache)
end

----------------------------------------------------------------------
-- UTILS
----------------------------------------------------------------------
local function horizDist(a, b)
	local o = a - b
	return Vector3.new(o.X, 0, o.Z).Magnitude
end

local function DoJump()
	if not Humanoid then return end
	if Humanoid.FloorMaterial ~= Enum.Material.Air
		and Humanoid:GetState() ~= Enum.HumanoidStateType.Jumping then
		Humanoid.Jump = true
		Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	end
end

local function vec3From(t)
	if typeof(t) == "Vector3" then return t end
	if type(t) == "table" and t.X then
		return Vector3.new(tonumber(t.X) or 0, tonumber(t.Y) or 0, tonumber(t.Z) or 0)
	end
	return nil
end

local function vec3ToTable(v)
	if typeof(v) == "Vector3" then
		return { X = v.X, Y = v.Y, Z = v.Z }
	end
	if type(v) == "table" then return v end
	return nil
end

-- Ensure a path profile exists for an entity name
local function EnsurePath(entityName)
	if type(entityName) ~= "string" or entityName == "" then return nil end
	if not CONFIG.Paths[entityName] then
		CONFIG.Paths[entityName] = {
			Waypoints = {},
			FarmCenter = nil,
			FarmRadius = 200,
			DeadzoneCenter = nil,
			DeadzoneRadius = 35,
		}
	end
	return CONFIG.Paths[entityName]
end

-- Entity whose path we are EDITING in UI
local function GetEditPathEntity()
	if CONFIG.ActivePathEntity and IsEntityInPriority(CONFIG.ActivePathEntity) then
		return CONFIG.ActivePathEntity
	end
	return CONFIG.TARGET_ENTITY_PRIORITY[1]
end

-- Entity we FARM toward = top priority (path from respawn → its farm)
local function GetActiveFarmEntity()
	return CONFIG.TARGET_ENTITY_PRIORITY[1]
end

local function GetActivePath()
	local name = GetActiveFarmEntity()
	if not name then return nil, nil end
	local path = EnsurePath(name)
	-- Same area: if this entity has no waypoints, inherit from priority #1 or any sibling with a path
	if path and #(path.Waypoints or {}) == 0 then
		for _, other in ipairs(CONFIG.TARGET_ENTITY_PRIORITY) do
			if other ~= name then
				local op = CONFIG.Paths[other]
				if op and op.Waypoints and #op.Waypoints > 0 then
					return op, name -- still farm "name", but walk "other"'s route
				end
			end
		end
	end
	return path, name
end

local function GetEditPath()
	local name = GetEditPathEntity()
	if not name then return nil, nil end
	return EnsurePath(name), name
end

local function GetActiveWaypoints()
	local path = select(1, GetActivePath())
	if not path then return {} end
	return path.Waypoints or {}
end

local function GetEditWaypoints()
	local path = select(1, GetEditPath())
	if not path then return {} end
	return path.Waypoints or {}
end

local function SyncFarmFromPath()
	local path, name = GetActivePath()
	if not path then return end
	CONFIG.ActivePathEntity = name
	if path.FarmCenter then
		CONFIG.FarmCenter = vec3From(path.FarmCenter)
		CONFIG.UseCustomFarmZone = true
	end
	if path.FarmRadius then CONFIG.FarmRadius = path.FarmRadius end
	if path.DeadzoneCenter then CONFIG.DeadzoneCenter = vec3From(path.DeadzoneCenter) end
	if path.DeadzoneRadius then CONFIG.DeadzoneRadius = path.DeadzoneRadius end
end

local function SaveFarmIntoPath()
	local path = select(1, GetEditPath()) or select(1, GetActivePath())
	if not path then return end
	path.FarmCenter = vec3ToTable(CONFIG.FarmCenter)
	path.FarmRadius = CONFIG.FarmRadius
	path.DeadzoneCenter = vec3ToTable(CONFIG.DeadzoneCenter)
	path.DeadzoneRadius = CONFIG.DeadzoneRadius
end

----------------------------------------------------------------------
-- FARM ZONE
----------------------------------------------------------------------
local function GetFarmCenter()
	local path = select(1, GetActivePath())
	if path and path.FarmCenter then
		return vec3From(path.FarmCenter)
	end
	-- inherit farm center from any priority path that has one
	for _, other in ipairs(CONFIG.TARGET_ENTITY_PRIORITY) do
		local op = CONFIG.Paths[other]
		if op and op.FarmCenter then
			return vec3From(op.FarmCenter)
		end
	end
	return vec3From(CONFIG.FarmCenter)
end

local function GetFarmRadius()
	local path = select(1, GetActivePath())
	if path and path.FarmRadius then
		return path.FarmRadius
	end
	for _, other in ipairs(CONFIG.TARGET_ENTITY_PRIORITY) do
		local op = CONFIG.Paths[other]
		if op and op.FarmRadius then
			return op.FarmRadius
		end
	end
	return CONFIG.FarmRadius or 200
end

local function IsInsideFarmArea(pos)
	if Feature.IgnoreFarmZone then return true end
	local center = GetFarmCenter()
	if not center or not pos then
		-- no farm set: allow everywhere
		return true
	end
	if horizDist(pos, center) > GetFarmRadius() then return false end
	local path = select(1, GetActivePath())
	local dz = path and vec3From(path.DeadzoneCenter) or vec3From(CONFIG.DeadzoneCenter)
	local dzr = (path and path.DeadzoneRadius) or CONFIG.DeadzoneRadius or 0
	if dz and dzr > 0 then
		if horizDist(pos, dz) <= dzr then return false end
	end
	return true
end

local function IsInsideDeadzone(pos)
	local path = select(1, GetActivePath())
	local dz = path and vec3From(path.DeadzoneCenter) or vec3From(CONFIG.DeadzoneCenter)
	local r = (path and path.DeadzoneRadius) or CONFIG.DeadzoneRadius or 0
	if not dz or not pos or r <= 0 then return false end
	return horizDist(pos, dz) <= r
end

----------------------------------------------------------------------
-- WATER / PATH CHECKS
----------------------------------------------------------------------
local function IsWaterAt(pos, ignore)
	if not pos then return false end
	local filter = { Character }
	if ignore then table.insert(filter, ignore) end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = filter
	local r = workspace:Raycast(pos + Vector3.new(0, 10, 0), Vector3.new(0, -30, 0), params)
	return r and r.Material == Enum.Material.Water
end

local function IsPathThroughWater(target)
	if not RootPart or not target then return true end
	local origin = RootPart.Position
	local offset = target - origin
	local dist = offset.Magnitude
	if dist <= 0 then return IsWaterAt(target) end
	local dir = offset.Unit
	for d = 0, dist, CONFIG.WATER_SAMPLE_DISTANCE do
		if IsWaterAt(origin + dir * d) then return true end
	end
	return IsWaterAt(target)
end

local function IsPathThroughDeadzone(target)
	if Feature.IgnoreFarmZone then return false end
	local path = select(1, GetActivePath())
	local dz = path and vec3From(path.DeadzoneCenter) or vec3From(CONFIG.DeadzoneCenter)
	local dzr = (path and path.DeadzoneRadius) or CONFIG.DeadzoneRadius or 0
	if not RootPart or not target or not dz or dzr <= 0 then return false end
	local origin = RootPart.Position
	local offset = target - origin
	local dist = offset.Magnitude
	if dist <= 0 then return horizDist(origin, dz) <= dzr end
	local dir = offset.Unit
	for d = 0, dist, CONFIG.DEADZONE_SAMPLE_DISTANCE do
		if horizDist(origin + dir * d, dz) <= dzr then return true end
	end
	return false
end

----------------------------------------------------------------------
-- PRIORITY / MOBS
----------------------------------------------------------------------
local function IsEntityInPriority(name)
	for _, n in ipairs(CONFIG.TARGET_ENTITY_PRIORITY) do
		if n == name then return true end
	end
	return false
end

local function GetMobPriority(mob)
	local cfg = mob:FindFirstChild("Config")
	local ent = cfg and cfg:FindFirstChild("Entity")
	if not ent then return nil end
	return table.find(CONFIG.TARGET_ENTITY_PRIORITY, ent.Value)
end

local function GetMobDistance(mob)
	local root = mob:FindFirstChild("HumanoidRootPart")
	if not root or not RootPart then return math.huge end
	return horizDist(root.Position, RootPart.Position)
end

local function CanSeeMob(mob)
	if not RootPart or not mob then return false end
	local root = mob:FindFirstChild("HumanoidRootPart")
	if not root then return false end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { Character }
	local result = workspace:Raycast(RootPart.Position, root.Position - RootPart.Position, params)
	if not result then return true end
	return result.Instance:IsDescendantOf(mob)
end

local function IsValidMob(mob)
	if not mob or not mob:IsA("Model") or not mob:IsDescendantOf(workspace) then return false end
	if not RootPart then return false end
	local folder = workspace:FindFirstChild("Mobs")
	if not folder or not mob:IsDescendantOf(folder) then return false end
	local cfg = mob:FindFirstChild("Config")
	local ent = cfg and cfg:FindFirstChild("Entity")
	if not ent or not ent:IsA("StringValue") then return false end
	if not IsEntityInPriority(ent.Value) then return false end
	local hum = mob:FindFirstChildOfClass("Humanoid")
	local root = mob:FindFirstChild("HumanoidRootPart")
	if not hum or not root or hum.Health <= 0 then return false end
	if GetMobDistance(mob) > CONFIG.MOB_DETECTION_DISTANCE then return false end
	if not IsInsideFarmArea(root.Position) then return false end
	if IsWaterAt(root.Position, mob) then return false end
	if not CanSeeMob(mob) then return false end
	if IsPathThroughWater(root.Position) then return false end
	if IsPathThroughDeadzone(root.Position) then return false end
	return true
end

local function IsTargetLockValid(mob)
	if not mob or not mob:IsA("Model") or not mob:IsDescendantOf(workspace) then return false end
	if not RootPart then return false end
	local folder = workspace:FindFirstChild("Mobs")
	if not folder or not mob:IsDescendantOf(folder) then return false end
	local cfg = mob:FindFirstChild("Config")
	local ent = cfg and cfg:FindFirstChild("Entity")
	if not ent or not IsEntityInPriority(ent.Value) then return false end
	local hum = mob:FindFirstChildOfClass("Humanoid")
	local root = mob:FindFirstChild("HumanoidRootPart")
	if not hum or not root or hum.Health <= 0 then return false end
	if GetMobDistance(mob) > CONFIG.MOB_DETECTION_DISTANCE then return false end
	if not IsInsideFarmArea(root.Position) then return false end
	if IsWaterAt(root.Position, mob) then return false end
	return true
end

local function UpdateValidMobs()
	local folder = workspace:FindFirstChild("Mobs")
	if not folder or not RootPart then
		table.clear(ValidMobs)
		if ClosestTarget and not IsTargetLockValid(ClosestTarget) then ClosestTarget = nil end
		return
	end
	local current = {}
	for _, mob in folder:GetChildren() do
		current[mob] = true
		if IsValidMob(mob) then
			ValidMobs[mob] = true
		else
			ValidMobs[mob] = nil
		end
	end
	for mob in ValidMobs do
		if not current[mob] then ValidMobs[mob] = nil end
	end
	if ClosestTarget and not IsTargetLockValid(ClosestTarget) then
		ClosestTarget = nil
	end
end

local function GetClosestPriorityMob()
	if not RootPart then return nil end
	local best, bestP, bestD = nil, math.huge, math.huge
	for mob in ValidMobs do
		local p = GetMobPriority(mob)
		if not p then
			ValidMobs[mob] = nil
		else
			local d = GetMobDistance(mob)
			if p < bestP or (p == bestP and d < bestD) then
				bestP, bestD, best = p, d, mob
			end
		end
	end
	return best
end

local function GetDetectedEntities()
	local folder = workspace:FindFirstChild("Mobs")
	if not folder then return {} end
	local set = {}
	for _, mob in folder:GetChildren() do
		if mob:IsA("Model") then
			local cfg = mob:FindFirstChild("Config")
			local ent = cfg and cfg:FindFirstChild("Entity")
			if ent and type(ent.Value) == "string" and ent.Value ~= "" then
				set[ent.Value] = true
			end
		end
	end
	local list = {}
	for name in set do table.insert(list, name) end
	table.sort(list)
	return list
end

----------------------------------------------------------------------
-- COMBAT BLADE (simplified from original)
----------------------------------------------------------------------
local function GetBladeParts(mob)
	if not mob then return {} end
	local now = os.clock()
	local c = BladePartCache[mob]
	if c and now - c.Time < CONFIG.BLADE_PART_CACHE_INTERVAL then return c.Parts end
	local parts = {}
	for _, d in mob:GetDescendants() do
		if d:IsA("BasePart") and d.Name == "BladePart" then
			table.insert(parts, d)
		end
	end
	BladePartCache[mob] = { Time = now, Parts = parts }
	return parts
end

local function GetClosestPointOnBlade(blade, pos)
	if not blade or not blade:IsA("BasePart") then return nil, math.huge end
	local localPos = blade.CFrame:PointToObjectSpace(pos)
	local half = blade.Size * 0.5
	local closestLocal = Vector3.new(
		math.clamp(localPos.X, -half.X, half.X),
		math.clamp(localPos.Y, -half.Y, half.Y),
		math.clamp(localPos.Z, -half.Z, half.Z)
	)
	local world = blade.CFrame:PointToWorldSpace(closestLocal)
	return world, (pos - world).Magnitude
end

local function GetBladeDangerDistance()
	return CONFIG.ENEMY_ATTACK_SAFE_DISTANCE + CONFIG.ENEMY_BLADE_PADDING
end

local function GetNearbyCombatMobs(target)
	if not target then return {} end
	local root = target:FindFirstChild("HumanoidRootPart")
	if not root then return {} end
	local now = os.clock()
	local c = CombatGroupCache[target]
	if c and now - c.Time < CONFIG.COMBAT_GROUP_CACHE_INTERVAL then return c.Mobs end
	local nearby = { [target] = true }
	for mob in ValidMobs do
		if mob ~= target then
			local hum = mob:FindFirstChildOfClass("Humanoid")
			local mroot = mob:FindFirstChild("HumanoidRootPart")
			if hum and mroot and hum.Health > 0
				and horizDist(root.Position, mroot.Position) <= CONFIG.GROUP_DANGER_DISTANCE then
				nearby[mob] = true
			end
		end
	end
	local result = {}
	for m in nearby do table.insert(result, m) end
	CombatGroupCache[target] = { Time = now, Mobs = result }
	return result
end

local function GetCombatBladeParts(target)
	if not target then return {} end
	local now = os.clock()
	local c = CombatBladeCache[target]
	if c and now - c.Time < CONFIG.COMBAT_GROUP_CACHE_INTERVAL then return c.Parts end
	local parts = {}
	for _, mob in GetNearbyCombatMobs(target) do
		for _, b in GetBladeParts(mob) do
			if b:IsDescendantOf(workspace) then table.insert(parts, b) end
		end
	end
	CombatBladeCache[target] = { Time = now, Parts = parts }
	return parts
end

local function IsPositionSafeFromBlades(pos, target)
	if not pos or not target then return true end
	local danger = GetBladeDangerDistance()
	for _, blade in GetCombatBladeParts(target) do
		local _, d = GetClosestPointOnBlade(blade, pos)
		if d <= danger then return false end
	end
	return true
end

local function GetBladeDangerData(target)
	if not RootPart or not target then return Vector3.zero, math.huge end
	local push = Vector3.zero
	local closest = math.huge
	local danger = GetBladeDangerDistance()
	for _, blade in GetCombatBladeParts(target) do
		local pt, dist = GetClosestPointOnBlade(blade, RootPart.Position)
		if pt then
			local eff = dist - danger
			if eff < closest then closest = eff end
			if dist <= danger then
				local off = RootPart.Position - pt
				local h = Vector3.new(off.X, 0, off.Z)
				if h.Magnitude > 0.01 then
					push = push + (h.Unit * math.max(danger - dist, 0.1))
				end
			end
		end
	end
	if push.Magnitude > 0.01 then push = push.Unit end
	return push, closest
end

local function IsSafePathClear(targetPos, goblin)
	if not RootPart or not targetPos then return false end
	local dir = targetPos - RootPart.Position
	if dir.Magnitude <= 0.01 then return true end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { Character, goblin }
	if workspace:Raycast(RootPart.Position, dir, params) then return false end
	local size = Vector3.new(
		math.max(RootPart.Size.X, 2.5),
		math.max(RootPart.Size.Y, 4),
		math.max(RootPart.Size.Z, 2.5)
	)
	return workspace:Blockcast(CFrame.new(RootPart.Position), size, dir, params) == nil
end

local function CanSeeFrom(pos, mob)
	local root = mob and mob:FindFirstChild("HumanoidRootPart")
	if not pos or not root then return false end
	local dir = root.Position - pos
	if dir.Magnitude <= 0 then return true end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { Character, mob }
	return workspace:Raycast(pos, dir, params) == nil
end

local function GetSafeCombatPosition(target)
	if not RootPart or not target then return nil end
	local troot = target:FindFirstChild("HumanoidRootPart")
	if not troot then return nil end
	local off = RootPart.Position - troot.Position
	local curDir = Vector3.new(off.X, 0, off.Z)
	if curDir.Magnitude <= 0.01 then curDir = Vector3.zAxis else curDir = curDir.Unit end

	local combatDist = CONFIG.PLAYER_ATTACK_DISTANCE
	local lastAtk = target:FindFirstChild("LastAttacker")
	if lastAtk and lastAtk.Value ~= Player then combatDist /= 2 end
	for _, blade in GetCombatBladeParts(target) do
		local bo = blade.Position - troot.Position
		combatDist = math.max(combatDist, Vector3.new(bo.X, 0, bo.Z).Magnitude + GetBladeDangerDistance())
	end

	local candidates = {}
	for i = 0, CONFIG.SAFE_COMBAT_DIRECTIONS - 1 do
		local ang = (math.pi * 2 / CONFIG.SAFE_COMBAT_DIRECTIONS) * i
		local dir = Vector3.new(math.cos(ang), 0, math.sin(ang))
		local cand = troot.Position + dir * combatDist
		if IsInsideFarmArea(cand) and not IsWaterAt(cand, target)
			and not IsPathThroughDeadzone(cand) and IsPositionSafeFromBlades(cand, target) then
			local dot = math.clamp(curDir:Dot(dir), -1, 1)
			local score = (cand - RootPart.Position).Magnitude + (1 - dot) * combatDist * 0.35
			table.insert(candidates, { Position = cand, Score = score })
		end
	end
	table.sort(candidates, function(a, b) return a.Score < b.Score end)
	local maxT = math.min(CONFIG.SAFE_COMBAT_MAX_PATH_TESTS, #candidates)
	for i = 1, maxT do
		local cand = candidates[i].Position
		if IsSafePathClear(cand, target)
			and not IsPathThroughWater(cand)
			and CanSeeFrom(cand, target) then
			return cand
		end
	end
	return nil
end

local function FaceMob(mob)
	if not RootPart or not mob then return end
	local root = mob:FindFirstChild("HumanoidRootPart")
	if not root or not FaceOrientation then return end
	local dir = Vector3.new(root.Position.X - RootPart.Position.X, 0, root.Position.Z - RootPart.Position.Z)
	if dir.Magnitude <= 0.01 then return end
	FaceOrientation.CFrame = CFrame.lookAt(RootPart.Position, RootPart.Position + dir)
	FaceOrientation.Enabled = true
end

local function GetNearbyThreatMob(targetMob)
	if not RootPart or not targetMob then return nil end
	local look = Vector3.new(RootPart.CFrame.LookVector.X, 0, RootPart.CFrame.LookVector.Z)
	if look.Magnitude <= 0.01 then return nil end
	look = look.Unit
	local best, bestD = nil, math.huge
	for mob in ValidMobs do
		if mob ~= targetMob then
			local hum = mob:FindFirstChildOfClass("Humanoid")
			local root = mob:FindFirstChild("HumanoidRootPart")
			if hum and root and hum.Health > 0 then
				local off = root.Position - RootPart.Position
				local h = Vector3.new(off.X, 0, off.Z)
				local d = h.Magnitude
				if d > 0.01 and d <= CONFIG.THREAT_DETECTION_DISTANCE then
					local dir = h.Unit
					local ang = math.deg(math.acos(math.clamp(look:Dot(dir), -1, 1)))
					if ang >= CONFIG.THREAT_ANGLE and d < bestD then
						best, bestD = mob, d
					end
				end
			end
		end
	end
	return best, bestD
end

local function GetThreatEscapePos(targetMob, threatMob)
	if not RootPart or not threatMob then return nil end
	local troot = threatMob:FindFirstChild("HumanoidRootPart")
	local aroot = targetMob and targetMob:FindFirstChild("HumanoidRootPart")
	if not troot or not aroot then return nil end
	local away = Vector3.new(RootPart.Position.X - troot.Position.X, 0, RootPart.Position.Z - troot.Position.Z)
	if away.Magnitude <= 0.01 then return nil end
	away = away.Unit
	local dirs = {
		away,
		CFrame.fromAxisAngle(Vector3.yAxis, math.rad(45)):VectorToWorldSpace(away),
		CFrame.fromAxisAngle(Vector3.yAxis, math.rad(-45)):VectorToWorldSpace(away),
		CFrame.fromAxisAngle(Vector3.yAxis, math.rad(90)):VectorToWorldSpace(away),
		CFrame.fromAxisAngle(Vector3.yAxis, math.rad(-90)):VectorToWorldSpace(away),
	}
	for _, dir in ipairs(dirs) do
		dir = Vector3.new(dir.X, 0, dir.Z)
		if dir.Magnitude > 0.01 then
			dir = dir.Unit
			local cand = RootPart.Position + dir * CONFIG.THREAT_ESCAPE_DISTANCE
			if IsInsideFarmArea(cand) and not IsWaterAt(cand, targetMob)
				and not IsPathThroughWater(cand) and not IsPathThroughDeadzone(cand)
				and IsSafePathClear(cand, targetMob) then
				return cand
			end
		end
	end
	return nil
end

local function MoveToMob(mob)
	if not mob or not RootPart or not Humanoid then return end
	if not IsTargetLockValid(mob) then
		if ClosestTarget == mob then ClosestTarget = nil end
		ResetCombatLock()
		return
	end
	local hum = mob:FindFirstChildOfClass("Humanoid")
	local root = mob:FindFirstChild("HumanoidRootPart")
	if not hum or not root or hum.Health <= 0 then
		ValidMobs[mob] = nil
		if ClosestTarget == mob then ClosestTarget = nil end
		return
	end

	-- Side/rear threat: step away but keep lock on primary target
	local threat, threatD = GetNearbyThreatMob(mob)
	if threat and threatD and threatD <= CONFIG.ENEMY_ATTACK_SAFE_DISTANCE + CONFIG.THREAT_ESCAPE_DISTANCE then
		local esc = GetThreatEscapePos(mob, threat)
		if esc then
			Humanoid.AutoRotate = false
			Humanoid:MoveTo(esc)
			FaceMob(mob)
			return
		end
	end

	if not Feature.SafeCombat then
		Humanoid.AutoRotate = false
		Humanoid:MoveTo(root.Position)
		FaceMob(mob)
		return
	end

	local now = os.clock()
	local push, closestEff = GetBladeDangerData(mob)
	if closestEff <= 0 and push.Magnitude > 0 then
		local retreat = RootPart.Position + push * (math.abs(closestEff) + CONFIG.ENEMY_ATTACK_SAFE_DISTANCE + 2)
		if IsInsideFarmArea(retreat) and not IsWaterAt(retreat, mob)
			and not IsPathThroughDeadzone(retreat) and not IsPathThroughWater(retreat) then
			Humanoid.AutoRotate = false
			Humanoid:MoveTo(retreat)
			FaceMob(mob)
			return
		end
	end

	local safePos = CACHED_SAFE_POS
	if now - LAST_SAFECOMBAT_TIME >= CONFIG.SAFECOMBAT_INTERVAL then
		LAST_SAFECOMBAT_TIME = now
		safePos = GetSafeCombatPosition(mob)
		CACHED_SAFE_POS = safePos
	end

	if safePos then
		local d = horizDist(RootPart.Position, safePos)
		if d <= 2 then
			Humanoid.AutoRotate = false
			Humanoid:Move(Vector3.zero)
			FaceMob(mob)
			TargetUnreachableSince = nil
			return
		end
		if IsSafePathClear(safePos, mob) and not IsPathThroughWater(safePos)
			and not IsPathThroughDeadzone(safePos) then
			Humanoid.AutoRotate = false
			Humanoid:MoveTo(safePos)
			FaceMob(mob)
			TargetUnreachableSince = nil
			return
		end
	end

	-- Reposition around target when direct safe path blocked
	if not TargetUnreachableSince then TargetUnreachableSince = now end
	if not TargetApproachPosition or now - LastTargetRepositionTime >= CONFIG.TARGET_REPOSITION_INTERVAL then
		LastTargetRepositionTime = now
		local safeR = CONFIG.PLAYER_ATTACK_DISTANCE
		for _, blade in GetCombatBladeParts(mob) do
			local bo = blade.Position - root.Position
			safeR = math.max(safeR, Vector3.new(bo.X, 0, bo.Z).Magnitude + GetBladeDangerDistance())
		end
		safeR = math.max(safeR, CONFIG.GOBLIN_REACH_DISTANCE)
		local best, bestScore = nil, math.huge
		for i = 0, CONFIG.TARGET_REPOSITION_DIRECTIONS - 1 do
			local ang = (math.pi * 2 / CONFIG.TARGET_REPOSITION_DIRECTIONS) * i
			local dir = Vector3.new(math.cos(ang), 0, math.sin(ang))
			local cand = root.Position + dir * safeR
			if IsInsideFarmArea(cand) and not IsWaterAt(cand, mob)
				and not IsPathThroughDeadzone(cand) and IsPositionSafeFromBlades(cand, mob)
				and CanSeeFrom(cand, mob) and IsSafePathClear(cand, mob) then
				local score = horizDist(RootPart.Position, cand)
				if score < bestScore then bestScore, best = score, cand end
			end
		end
		TargetApproachPosition = best
	end

	if TargetApproachPosition then
		if horizDist(RootPart.Position, TargetApproachPosition) <= 3 then
			TargetApproachPosition = nil
		else
			Humanoid.AutoRotate = false
			Humanoid:MoveTo(TargetApproachPosition)
			FaceMob(mob)
			return
		end
	end

	-- Last resort: stand at attack distance on current side
	local off = RootPart.Position - root.Position
	local h = Vector3.new(off.X, 0, off.Z)
	if h.Magnitude > 0.01 then
		local stand = root.Position + h.Unit * CONFIG.PLAYER_ATTACK_DISTANCE
		Humanoid.AutoRotate = false
		Humanoid:MoveTo(stand)
		FaceMob(mob)
	else
		Humanoid:Move(Vector3.zero)
		FaceMob(mob)
	end

	if TargetUnreachableSince and now - TargetUnreachableSince >= CONFIG.TARGET_UNREACHABLE_TIMEOUT then
		if ClosestTarget == mob then ClosestTarget = nil end
		ResetCombatLock()
	end
end

----------------------------------------------------------------------
-- PATH / RETURN TO FARM
----------------------------------------------------------------------
local function ShouldForceReturn()
	if Feature.IgnoreFarmZone then
		ForcingReturn = false
		return false
	end
	local center = GetFarmCenter()
	if not center or not RootPart then
		ForcingReturn = false
		return false
	end
	local limit = CONFIG.RETURN_TO_FARM_DISTANCE or 80
	limit = math.max(limit, GetFarmRadius() * 0.85)
	return horizDist(RootPart.Position, center) > limit
end

local function ForceReturnToFarm()
	local center = GetFarmCenter()
	if not center or not Humanoid or not RootPart then return false end
	ForcingReturn = true
	if FaceOrientation then FaceOrientation.Enabled = false end
	Humanoid.AutoRotate = true
	Humanoid:MoveTo(center)
	if horizDist(RootPart.Position, center) <= 12 then
		ForcingReturn = false
	end
	return true
end

local function GetWaypointPos(i)
	local wps = GetActiveWaypoints()
	local wp = wps[i]
	if not wp then return nil end
	return Vector3.new(wp.X or 0, wp.Y or 0, wp.Z or 0), wp.Action or "None"
end

----------------------------------------------------------------------
-- PATROL (inside farm only)
----------------------------------------------------------------------
local function GetPatrolGround(pos)
	if not pos or not RootPart or not IsInsideFarmArea(pos) then return nil end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { Character }
	local r = workspace:Raycast(
		Vector3.new(pos.X, RootPart.Position.Y + 60, pos.Z),
		Vector3.new(0, -250, 0),
		params
	)
	if not r or r.Material == Enum.Material.Water or r.Normal.Y < 0.5 then return nil end
	local g = Vector3.new(pos.X, r.Position.Y + RootPart.Size.Y * 0.5, pos.Z)
	if IsWaterAt(g) or IsInsideDeadzone(g) then return nil end
	return g
end

local function MoveToPatrol()
	if not Feature.AutoPatrol or not RootPart or not Humanoid then return false end
	local center = GetFarmCenter()
	if not center then return false end
	local now = os.clock()
	if not PatrolPosition or now - LastPatrolTime >= CONFIG.PATROL_RECALCULATE_INTERVAL then
		LastPatrolTime = now
		PatrolPosition = nil
		local best, bestScore = nil, math.huge
		for i = 0, 15 do
			local ang = (math.pi * 2 / 16) * i
			local dir = Vector3.new(math.cos(ang), 0, math.sin(ang))
			for _, rad in ipairs({ CONFIG.PATROL_RADIUS_MIN, (CONFIG.PATROL_RADIUS_MIN + CONFIG.PATROL_RADIUS_MAX) * 0.5, CONFIG.PATROL_RADIUS_MAX }) do
				local cand = GetPatrolGround(center + dir * rad)
				if cand then
					local score = (cand - RootPart.Position).Magnitude
					if score < bestScore then bestScore, best = score, cand end
				end
			end
		end
		PatrolPosition = best
	end
	if not PatrolPosition then return false end
	if horizDist(RootPart.Position, PatrolPosition) <= 4 then
		PatrolPosition = nil
		return false
	end
	if FaceOrientation then FaceOrientation.Enabled = false end
	Humanoid.AutoRotate = true
	Humanoid:MoveTo(PatrolPosition)
	return true
end

----------------------------------------------------------------------
-- BLOCK + ANTI AFK + TELEPORT
----------------------------------------------------------------------
local function isBlocked(userId)
	local ok, ids = pcall(function() return StarterGui:GetCore("GetBlockedUserIds") end)
	if not ok or not ids then return false end
	for _, id in ids do
		if id == userId then return true end
	end
	return false
end

-- Auto Block: only opens Roblox prompt (user confirms manually — auto-click unreliable on MuMu)
local function promptBlockPlayer(plr)
	local uid = plr.UserId
	if BlockCache[uid] or isBlocked(uid) then return end
	BlockCache[uid] = true
	local ok, err = pcall(function()
		StarterGui:SetCore("PromptBlockPlayer", plr)
	end)
	if not ok then
		warn("[Block]", err)
		BlockCache[uid] = nil
		return
	end
	-- Manual confirm only (auto-click Block button removed — unstable on MuMu)
	task.delay(CONFIG.BLOCK_COOLDOWN, function() BlockCache[uid] = nil end)
end

local function TeleportToPlace(id)
	pcall(function()
		TeleportService:Teleport(id or game.PlaceId, Player)
	end)
end

-- Anti AFK
Player.Idled:Connect(function()
	if not Feature.AntiAfk then return end
	pcall(function()
		VirtualUser:CaptureController()
		VirtualUser:ClickButton2(Vector2.new())
	end)
end)
task.spawn(function()
	while true do
		task.wait(60 + math.random(0, 30))
		if Feature.AntiAfk then
			pcall(function()
				VirtualUser:CaptureController()
				VirtualUser:ClickButton2(Vector2.new())
			end)
		end
	end
end)

----------------------------------------------------------------------
-- SAVE / LOAD
----------------------------------------------------------------------
local function ensureDir()
	if isfolder and not isfolder(CONFIG.CONFIG_DIR) then pcall(makefolder, CONFIG.CONFIG_DIR) end
end

local function profilePath(name)
	name = tostring(name or ProfileName):gsub("[^%w%-%_]", "_")
	if name == "" then name = "Default" end
	return CONFIG.CONFIG_DIR .. "/" .. name .. ".json"
end

local function BuildConfig()
	local pathsOut = {}
	for entName, pdata in pairs(CONFIG.Paths) do
		local wps = {}
		for _, wp in ipairs(pdata.Waypoints or {}) do
			table.insert(wps, {
				X = wp.X, Y = wp.Y, Z = wp.Z,
				Action = wp.Action == "Interact" and "Interact" or "None",
				Label = wp.Label or "",
			})
		end
		pathsOut[entName] = {
			Waypoints = wps,
			FarmCenter = vec3ToTable(pdata.FarmCenter),
			FarmRadius = pdata.FarmRadius or 200,
			DeadzoneCenter = vec3ToTable(pdata.DeadzoneCenter),
			DeadzoneRadius = pdata.DeadzoneRadius or 35,
		}
	end
	local pri = {}
	for _, n in ipairs(CONFIG.TARGET_ENTITY_PRIORITY) do table.insert(pri, n) end
	return {
		Version = CONFIG.VERSION,
		PlaceId = game.PlaceId,
		ProfileName = ProfileName,
		Features = {
			AutoFarm = Feature.AutoFarm,
			AutoBlock = Feature.AutoBlock,
			SafeCombat = Feature.SafeCombat,
			AutoPatrol = Feature.AutoPatrol,
			AutoSkill = Feature.AutoSkill,
			IgnoreFarmZone = Feature.IgnoreFarmZone,
			ResetOnBoostOut = Feature.ResetOnBoostOut,
			AntiAfk = Feature.AntiAfk,
		},
		TargetEntityPriority = pri,
		Paths = pathsOut,
		ActivePathEntity = CONFIG.ActivePathEntity,
		CurrentWaypoint = CONFIG.CurrentWaypoint,
		MobDetectionDistance = CONFIG.MOB_DETECTION_DISTANCE,
		FloorLabel = FloorLabel,
	}
end

local function ApplyConfig(data)
	if type(data) ~= "table" then return false end
	if type(data.Features) == "table" then
		for k, v in pairs(data.Features) do
			if Feature[k] ~= nil then Feature[k] = v end
		end
		Enabled = Feature.AutoFarm
	end
	if type(data.TargetEntityPriority) == "table" then
		CONFIG.TARGET_ENTITY_PRIORITY = {}
		for _, n in ipairs(data.TargetEntityPriority) do
			if type(n) == "string" and n ~= "" then
				table.insert(CONFIG.TARGET_ENTITY_PRIORITY, n)
			end
		end
		ResetCombatLock()
	end
	if type(data.Paths) == "table" then
		CONFIG.Paths = {}
		for entName, pdata in pairs(data.Paths) do
			if type(entName) == "string" and type(pdata) == "table" then
				local wps = {}
				for _, wp in ipairs(pdata.Waypoints or {}) do
					table.insert(wps, {
						X = tonumber(wp.X) or 0, Y = tonumber(wp.Y) or 0, Z = tonumber(wp.Z) or 0,
						Action = wp.Action == "Interact" and "Interact" or "None",
						Label = tostring(wp.Label or ""),
					})
				end
				CONFIG.Paths[entName] = {
					Waypoints = wps,
					FarmCenter = vec3From(pdata.FarmCenter),
					FarmRadius = tonumber(pdata.FarmRadius) or 200,
					DeadzoneCenter = vec3From(pdata.DeadzoneCenter),
					DeadzoneRadius = tonumber(pdata.DeadzoneRadius) or 35,
				}
			end
		end
	elseif type(data.CustomWaypoints) == "table" then
		-- migrate old flat format into first priority entity
		local key = (type(data.TargetEntityPriority) == "table" and data.TargetEntityPriority[1]) or "Default"
		local wps = {}
		for _, wp in ipairs(data.CustomWaypoints) do
			table.insert(wps, {
				X = tonumber(wp.X) or 0, Y = tonumber(wp.Y) or 0, Z = tonumber(wp.Z) or 0,
				Action = wp.Action == "Interact" and "Interact" or "None",
				Label = tostring(wp.Label or ""),
			})
		end
		CONFIG.Paths[key] = {
			Waypoints = wps,
			FarmCenter = vec3From(data.FarmCenter),
			FarmRadius = tonumber(data.FarmRadius) or 200,
			DeadzoneCenter = vec3From(data.DeadzoneCenter),
			DeadzoneRadius = tonumber(data.DeadzoneRadius) or 35,
		}
	end
	if type(data.ActivePathEntity) == "string" then
		CONFIG.ActivePathEntity = data.ActivePathEntity
	end
	CONFIG.CurrentWaypoint = tonumber(data.CurrentWaypoint) or 1
	if data.MobDetectionDistance then CONFIG.MOB_DETECTION_DISTANCE = tonumber(data.MobDetectionDistance) or 450 end
	if type(data.ProfileName) == "string" then ProfileName = data.ProfileName end
	if type(data.FloorLabel) == "string" then FloorLabel = data.FloorLabel end
	SyncFarmFromPath()
	return true
end

local function SaveConfig(name)
	name = name or ProfileName
	ProfileName = name
	if not writefile then return false, "writefile missing" end
	ensureDir()
	local ok, enc = pcall(function() return HttpService:JSONEncode(BuildConfig()) end)
	if not ok then return false, enc end
	local ok2, err = pcall(writefile, profilePath(name), enc)
	return ok2, err
end

local _autoSaveToken = 0
local function AutoSaveConfig()
	_autoSaveToken = _autoSaveToken + 1
	local token = _autoSaveToken
	task.delay(0.6, function()
		if token ~= _autoSaveToken then return end
		local name = "Place_" .. tostring(game.PlaceId)
		local ok, err = SaveConfig(name)
		if CfgStatus then
			CfgStatus.Text = ok and "Auto-saved" or tostring(err):sub(1, 14)
		end
	end)
end

local function LoadConfig(name)
	name = name or ProfileName
	if not readfile then return false, "readfile missing" end
	ensureDir()
	local file = profilePath(name)
	if isfile and not isfile(file) then return false, "not found" end
	local ok, raw = pcall(readfile, file)
	if not ok then return false, raw end
	local ok2, data = pcall(function() return HttpService:JSONDecode(raw) end)
	if not ok2 then return false, data end
	ProfileName = name
	ApplyConfig(data)
	return true
end

local function TryAutoLoad()
	if not listfiles or not readfile then return end
	ensureDir()
	local ok, files = pcall(listfiles, CONFIG.CONFIG_DIR)
	if not ok or type(files) ~= "table" then return end
	for _, f in ipairs(files) do
		local n = string.match(f, "([^/\\]+)%.json$")
		if n then
			local ok2, raw = pcall(readfile, profilePath(n))
			if ok2 then
				local ok3, data = pcall(function() return HttpService:JSONDecode(raw) end)
				if ok3 and data and data.PlaceId == game.PlaceId then
					LoadConfig(n)
					return
				end
			end
		end
	end
end

----------------------------------------------------------------------
-- STAMINA / BOOST
----------------------------------------------------------------------
local StaminaConnection
local function RegenStamina()
	task.spawn(function()
		local stats = Player:WaitForChild("PlayerStats", 30)
		local gui = PlayerGui:WaitForChild("GameGui", 30)
		if not stats or not gui then return end
		local stam = gui:FindFirstChild("Stamina")
		local maxS = stats:FindFirstChild("MaxStamina")
		if not stam or not maxS then return end
		if StaminaConnection then StaminaConnection:Disconnect() end
		StaminaConnection = stam:GetPropertyChangedSignal("Value"):Connect(function()
			if stam.Value < maxS.Value then stam.Value = maxS.Value end
		end)
	end)
end
RegenStamina()

task.spawn(function()
	local stats = Player:WaitForChild("PlayerStats", 30)
	if not stats then return end
	local expB = stats:FindFirstChild("Boost")
	local dropB = stats:FindFirstChild("BoostDrops")
	if expB then
		expB:GetPropertyChangedSignal("Value"):Connect(function()
			if Feature.ResetOnBoostOut and expB.Value == 0 and Humanoid then
				Humanoid.Health = 0
			end
		end)
	end
	if dropB then
		dropB:GetPropertyChangedSignal("Value"):Connect(function()
			if Feature.ResetOnBoostOut and dropB.Value == 0 and Humanoid then
				Humanoid.Health = 0
			end
		end)
	end
end)

Player.CharacterAdded:Connect(function()
	task.wait()
	DEATH_COUNT = DEATH_COUNT + 1
	CONFIG.CurrentWaypoint = 1
	ResetCombatLock()
	-- path restarts from respawn after death
	Equipped = false
	RETREATING = false
	InputBindableFunction = nil
	FaceAttachment, FaceOrientation = nil, nil
	if StaminaConnection then StaminaConnection:Disconnect(); StaminaConnection = nil end
	task.delay(0.5, function() Equipped = false end)
	updateCharacter()
	RegenStamina()
end)

----------------------------------------------------------------------
-- UI
----------------------------------------------------------------------
pcall(function()
	PlaceNameCache = MarketplaceService:GetProductInfoAsync(game.PlaceId).Name
end)
-- SubTitle updated after UI creates it (see below)

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "SBOR_AutoFarm"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.DisplayOrder = 50
ScreenGui.Parent = PlayerGui

-- Floating toggle
local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Name = "MenuToggle"
ToggleBtn.Size = UDim2.fromOffset(44, 44)
ToggleBtn.Position = UDim2.new(1, -58, 0, 12)
ToggleBtn.BackgroundColor3 = CONFIG.UI_PANEL
ToggleBtn.BorderSizePixel = 0
ToggleBtn.Text = "="
ToggleBtn.TextColor3 = CONFIG.UI_TEXT
ToggleBtn.TextSize = 20
ToggleBtn.Font = Enum.Font.GothamBold
ToggleBtn.Parent = ScreenGui
Instance.new("UICorner", ToggleBtn).CornerRadius = UDim.new(0, 10)
Instance.new("UIStroke", ToggleBtn).Color = CONFIG.UI_BORDER

-- Main panel
local Panel = Instance.new("Frame")
Panel.Name = "Panel"
Panel.AnchorPoint = Vector2.new(1, 0.5)
Panel.Size = UDim2.fromScale(0.28, 0.78)
Panel.Position = UDim2.fromScale(0.97, 0.52)
Panel.BackgroundColor3 = CONFIG.UI_BG
Panel.BorderSizePixel = 0
Panel.ClipsDescendants = true
Panel.Parent = ScreenGui
Instance.new("UICorner", Panel).CornerRadius = UDim.new(0, 14)
local panelStroke = Instance.new("UIStroke", Panel)
panelStroke.Color = CONFIG.UI_BORDER
panelStroke.Thickness = 1.2

-- Header
local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 64)
Header.BackgroundColor3 = CONFIG.UI_PANEL
Header.BorderSizePixel = 0
Header.Parent = Panel
Instance.new("UICorner", Header).CornerRadius = UDim.new(0, 14)
local headerMask = Instance.new("Frame")
headerMask.Size = UDim2.new(1, 0, 0, 20)
headerMask.Position = UDim2.new(0, 0, 1, -20)
headerMask.BackgroundColor3 = CONFIG.UI_PANEL
headerMask.BorderSizePixel = 0
headerMask.Parent = Header

local accentBar = Instance.new("Frame")
accentBar.Size = UDim2.new(0, 4, 0, 32)
accentBar.Position = UDim2.new(0, 14, 0.5, -16)
accentBar.BackgroundColor3 = CONFIG.UI_ACCENT
accentBar.BorderSizePixel = 0
accentBar.Parent = Header
Instance.new("UICorner", accentBar).CornerRadius = UDim.new(1, 0)

local Title = Instance.new("TextLabel")
Title.BackgroundTransparency = 1
Title.Size = UDim2.new(1, -80, 0, 24)
Title.Position = UDim2.new(0, 28, 0, 10)
Title.Text = "Auto Farm"
Title.TextColor3 = CONFIG.UI_TEXT
Title.Font = Enum.Font.GothamBold
Title.TextSize = 18
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Header

local SubTitle = Instance.new("TextLabel")
SubTitle.BackgroundTransparency = 1
SubTitle.Size = UDim2.new(1, -80, 0, 18)
SubTitle.Position = UDim2.new(0, 28, 0, 34)
SubTitle.Text = GetHeaderSubtitle()
SubTitle.TextColor3 = CONFIG.UI_MUTED
SubTitle.Font = Enum.Font.Gotham
SubTitle.TextSize = 12
SubTitle.TextXAlignment = Enum.TextXAlignment.Left
SubTitle.TextTruncate = Enum.TextTruncate.AtEnd
SubTitle.Parent = Header

local StatusDot = Instance.new("Frame")
StatusDot.Size = UDim2.fromOffset(10, 10)
StatusDot.Position = UDim2.new(1, -28, 0.5, -5)
StatusDot.BackgroundColor3 = Feature.AutoFarm and CONFIG.UI_SUCCESS or CONFIG.UI_DANGER
StatusDot.BorderSizePixel = 0
StatusDot.Parent = Header
Instance.new("UICorner", StatusDot).CornerRadius = UDim.new(1, 0)

-- Content scroll
local Content = Instance.new("ScrollingFrame")
Content.Size = UDim2.new(1, -20, 1, -80)
Content.Position = UDim2.new(0, 10, 0, 70)
Content.BackgroundTransparency = 1
Content.BorderSizePixel = 0
Content.ScrollBarThickness = 3
Content.ScrollBarImageColor3 = CONFIG.UI_BORDER
Content.CanvasSize = UDim2.new(0, 0, 0, 0)
Content.AutomaticCanvasSize = Enum.AutomaticSize.Y
Content.Parent = Panel
local contentLayout = Instance.new("UIListLayout", Content)
contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
contentLayout.Padding = UDim.new(0, 8)
local contentPad = Instance.new("UIPadding", Content)
contentPad.PaddingBottom = UDim.new(0, 12)

local layoutOrder = 0
local function nextOrder()
	layoutOrder = layoutOrder + 1
	return layoutOrder
end

local function sectionLabel(text)
	local l = Instance.new("TextLabel")
	l.LayoutOrder = nextOrder()
	l.Size = UDim2.new(1, 0, 0, 22)
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextColor3 = CONFIG.UI_MUTED
	l.Font = Enum.Font.GothamBold
	l.TextSize = 11
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Parent = Content
	return l
end

local function makeToggle(label, key, defaultOn)
	local row = Instance.new("Frame")
	row.LayoutOrder = nextOrder()
	row.Size = UDim2.new(1, 0, 0, 40)
	row.BackgroundColor3 = CONFIG.UI_SURFACE
	row.BorderSizePixel = 0
	row.Parent = Content
	Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)

	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Size = UDim2.new(1, -70, 1, 0)
	name.Position = UDim2.new(0, 12, 0, 0)
	name.Text = label
	name.TextColor3 = CONFIG.UI_TEXT
	name.Font = Enum.Font.GothamMedium
	name.TextSize = 13
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.Parent = row

	local btn = Instance.new("TextButton")
	btn.Size = UDim2.fromOffset(52, 26)
	btn.Position = UDim2.new(1, -62, 0.5, -13)
	btn.BorderSizePixel = 0
	btn.Text = ""
	btn.AutoButtonColor = false
	btn.Parent = row
	Instance.new("UICorner", btn).CornerRadius = UDim.new(1, 0)

	local knob = Instance.new("Frame")
	knob.Size = UDim2.fromOffset(20, 20)
	knob.Position = UDim2.new(0, 3, 0.5, -10)
	knob.BackgroundColor3 = Color3.new(1, 1, 1)
	knob.BorderSizePixel = 0
	knob.Parent = btn
	Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

	local function refresh()
		local on = Feature[key]
		btn.BackgroundColor3 = on and CONFIG.UI_SUCCESS or CONFIG.UI_HOVER
		knob.Position = on and UDim2.new(1, -23, 0.5, -10) or UDim2.new(0, 3, 0.5, -10)
	end
	refresh()
	btn.Activated:Connect(function()
		Feature[key] = not Feature[key]
		if key == "AutoFarm" then Enabled = Feature.AutoFarm end
		if key == "SafeCombat" then ResetCombatLock() end
		refresh()
		StatusDot.BackgroundColor3 = Feature.AutoFarm and CONFIG.UI_SUCCESS or CONFIG.UI_DANGER
		if AutoSaveConfig then AutoSaveConfig() end
	end)
	return refresh
end

-- Live stats
sectionLabel("STATUS")
local StatsFrame = Instance.new("Frame")
StatsFrame.LayoutOrder = nextOrder()
StatsFrame.Size = UDim2.new(1, 0, 0, 72)
StatsFrame.BackgroundColor3 = CONFIG.UI_SURFACE
StatsFrame.BorderSizePixel = 0
StatsFrame.Parent = Content
Instance.new("UICorner", StatsFrame).CornerRadius = UDim.new(0, 8)

local function statCell(parent, xScale, title)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.new(0.5, -8, 0, 14)
	t.Position = UDim2.new(xScale, 8, 0, 8)
	t.Text = title
	t.TextColor3 = CONFIG.UI_MUTED
	t.Font = Enum.Font.Gotham
	t.TextSize = 10
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.Parent = parent
	local v = Instance.new("TextLabel")
	v.BackgroundTransparency = 1
	v.Size = UDim2.new(0.5, -8, 0, 18)
	v.Position = UDim2.new(xScale, 8, 0, 22)
	v.Text = "--"
	v.TextColor3 = CONFIG.UI_TEXT
	v.Font = Enum.Font.GothamBold
	v.TextSize = 13
	v.TextXAlignment = Enum.TextXAlignment.Left
	v.TextTruncate = Enum.TextTruncate.AtEnd
	v.Parent = parent
	return v
end

local StatPos = statCell(StatsFrame, 0, "POSITION")
local StatWP = statCell(StatsFrame, 0.5, "WAYPOINT")
local StatDeath = Instance.new("TextLabel")
StatDeath.BackgroundTransparency = 1
StatDeath.Size = UDim2.new(0.5, -8, 0, 18)
StatDeath.Position = UDim2.new(0, 8, 0, 48)
StatDeath.Text = "Deaths: 0"
StatDeath.TextColor3 = CONFIG.UI_MUTED
StatDeath.Font = Enum.Font.Gotham
StatDeath.TextSize = 11
StatDeath.TextXAlignment = Enum.TextXAlignment.Left
StatDeath.Parent = StatsFrame
local StatTarget = Instance.new("TextLabel")
StatTarget.BackgroundTransparency = 1
StatTarget.Size = UDim2.new(0.5, -8, 0, 18)
StatTarget.Position = UDim2.new(0.5, 8, 0, 48)
StatTarget.Text = "Target: --"
StatTarget.TextColor3 = CONFIG.UI_MUTED
StatTarget.Font = Enum.Font.Gotham
StatTarget.TextSize = 11
StatTarget.TextXAlignment = Enum.TextXAlignment.Left
StatTarget.TextTruncate = Enum.TextTruncate.AtEnd
StatTarget.Parent = StatsFrame

-- Features
sectionLabel("FEATURES")
makeToggle("Auto Farm", "AutoFarm", true)
makeToggle("Auto Block", "AutoBlock", true)
makeToggle("Safe Combat", "SafeCombat", true)
makeToggle("Auto Patrol", "AutoPatrol", true)
makeToggle("Auto Skill", "AutoSkill", true)
makeToggle("Ignore Farm Zone", "IgnoreFarmZone", false)
makeToggle("Reset on Boost Out", "ResetOnBoostOut", true)
makeToggle("Anti AFK", "AntiAfk", true)

-- Priority
sectionLabel("ENEMY PRIORITY")
local PriorityBox = Instance.new("Frame")
PriorityBox.LayoutOrder = nextOrder()
PriorityBox.Size = UDim2.new(1, 0, 0, 0)
PriorityBox.AutomaticSize = Enum.AutomaticSize.Y
PriorityBox.BackgroundTransparency = 1
PriorityBox.Parent = Content
local PriorityLayout = Instance.new("UIListLayout", PriorityBox)
PriorityLayout.SortOrder = Enum.SortOrder.LayoutOrder
PriorityLayout.Padding = UDim.new(0, 4)

local function rebuildPriorityUI()
	for _, ch in PriorityBox:GetChildren() do
		if ch:IsA("GuiObject") and ch ~= PriorityLayout then ch:Destroy() end
	end
	for i, name in ipairs(CONFIG.TARGET_ENTITY_PRIORITY) do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, 34)
		row.BackgroundColor3 = CONFIG.UI_SURFACE
		row.BorderSizePixel = 0
		row.LayoutOrder = i
		row.Parent = PriorityBox
		Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)

		local num = Instance.new("TextLabel")
		num.BackgroundTransparency = 1
		num.Size = UDim2.new(0, 24, 1, 0)
		num.Position = UDim2.new(0, 6, 0, 0)
		num.Text = tostring(i)
		num.TextColor3 = CONFIG.UI_ACCENT
		num.Font = Enum.Font.GothamBold
		num.TextSize = 13
		num.Parent = row

		local nl = Instance.new("TextLabel")
		nl.BackgroundTransparency = 1
		nl.Size = UDim2.new(1, -120, 1, 0)
		nl.Position = UDim2.new(0, 30, 0, 0)
		nl.Text = name
		nl.TextColor3 = CONFIG.UI_TEXT
		nl.Font = Enum.Font.GothamMedium
		nl.TextSize = 12
		nl.TextXAlignment = Enum.TextXAlignment.Left
		nl.TextTruncate = Enum.TextTruncate.AtEnd
		nl.Parent = row

		local function smallBtn(txt, x)
			local b = Instance.new("TextButton")
			b.Size = UDim2.fromOffset(26, 24)
			b.Position = UDim2.new(1, x, 0.5, -12)
			b.BackgroundColor3 = CONFIG.UI_HOVER
			b.BorderSizePixel = 0
			b.Text = txt
			b.TextColor3 = CONFIG.UI_TEXT
			b.TextSize = 12
			b.Font = Enum.Font.GothamBold
			b.Parent = row
			Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)
			return b
		end
		local up = smallBtn("^", -90)
		local down = smallBtn("v", -60)
		local rm = smallBtn("x", -30)
		up.Activated:Connect(function()
			if i <= 1 then return end
			CONFIG.TARGET_ENTITY_PRIORITY[i], CONFIG.TARGET_ENTITY_PRIORITY[i - 1] =
				CONFIG.TARGET_ENTITY_PRIORITY[i - 1], CONFIG.TARGET_ENTITY_PRIORITY[i]
			ResetCombatLock()
			rebuildPriorityUI()
		end)
		down.Activated:Connect(function()
			if i >= #CONFIG.TARGET_ENTITY_PRIORITY then return end
			CONFIG.TARGET_ENTITY_PRIORITY[i], CONFIG.TARGET_ENTITY_PRIORITY[i + 1] =
				CONFIG.TARGET_ENTITY_PRIORITY[i + 1], CONFIG.TARGET_ENTITY_PRIORITY[i]
			ResetCombatLock()
			rebuildPriorityUI()
		end)
		rm.Activated:Connect(function()
			table.remove(CONFIG.TARGET_ENTITY_PRIORITY, i)
			ResetCombatLock()
			rebuildPriorityUI()
			if refreshPathUI then refreshPathUI() end
		end)
	end
	if refreshPathUI then task.defer(refreshPathUI) end
end

local AddEnemyBtn = Instance.new("TextButton")
AddEnemyBtn.LayoutOrder = nextOrder()
AddEnemyBtn.Size = UDim2.new(1, 0, 0, 34)
AddEnemyBtn.BackgroundColor3 = CONFIG.UI_SURFACE
AddEnemyBtn.BorderSizePixel = 0
AddEnemyBtn.Text = "+  Add enemy from world"
AddEnemyBtn.TextColor3 = CONFIG.UI_ACCENT
AddEnemyBtn.Font = Enum.Font.GothamBold
AddEnemyBtn.TextSize = 12
AddEnemyBtn.Parent = Content
Instance.new("UICorner", AddEnemyBtn).CornerRadius = UDim.new(0, 8)

local EnemyPicker = Instance.new("Frame")
EnemyPicker.LayoutOrder = nextOrder()
EnemyPicker.Size = UDim2.new(1, 0, 0, 0)
EnemyPicker.AutomaticSize = Enum.AutomaticSize.Y
EnemyPicker.BackgroundColor3 = CONFIG.UI_PANEL
EnemyPicker.BorderSizePixel = 0
EnemyPicker.Visible = false
EnemyPicker.Parent = Content
Instance.new("UICorner", EnemyPicker).CornerRadius = UDim.new(0, 8)
local pickerLayout = Instance.new("UIListLayout", EnemyPicker)
pickerLayout.Padding = UDim.new(0, 2)

local function refreshEnemyPicker()
	for _, ch in EnemyPicker:GetChildren() do
		if ch:IsA("GuiObject") and ch ~= pickerLayout then ch:Destroy() end
	end
	for _, name in ipairs(GetDetectedEntities()) do
		local b = Instance.new("TextButton")
		b.Size = UDim2.new(1, -8, 0, 28)
		b.BackgroundColor3 = CONFIG.UI_SURFACE
		b.BorderSizePixel = 0
		b.Text = "  " .. name .. (IsEntityInPriority(name) and "  ✓" or "")
		b.TextColor3 = IsEntityInPriority(name) and CONFIG.UI_MUTED or CONFIG.UI_TEXT
		b.Font = Enum.Font.GothamMedium
		b.TextSize = 12
		b.TextXAlignment = Enum.TextXAlignment.Left
		b.Parent = EnemyPicker
		Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)
		b.Activated:Connect(function()
			if IsEntityInPriority(name) then return end
			table.insert(CONFIG.TARGET_ENTITY_PRIORITY, name)
			ResetCombatLock()
			rebuildPriorityUI()
			refreshEnemyPicker()
		end)
	end
end

AddEnemyBtn.Activated:Connect(function()
	EnemyPicker.Visible = not EnemyPicker.Visible
	if EnemyPicker.Visible then refreshEnemyPicker() end
end)

rebuildPriorityUI()

-- Path editor
sectionLabel("PATH (bound to mob / boss)")

local PathEntityLabel = Instance.new("TextLabel")
PathEntityLabel.LayoutOrder = nextOrder()
PathEntityLabel.Size = UDim2.new(1, 0, 0, 28)
PathEntityLabel.BackgroundColor3 = CONFIG.UI_SURFACE
PathEntityLabel.BorderSizePixel = 0
PathEntityLabel.Text = "Path for: (select priority enemy)"
PathEntityLabel.TextColor3 = CONFIG.UI_ACCENT
PathEntityLabel.Font = Enum.Font.GothamBold
PathEntityLabel.TextSize = 12
PathEntityLabel.Parent = Content
Instance.new("UICorner", PathEntityLabel).CornerRadius = UDim.new(0, 8)

local PathHint2 = Instance.new("TextLabel")
PathHint2.LayoutOrder = nextOrder()
PathHint2.Size = UDim2.new(1, 0, 0, 32)
PathHint2.BackgroundTransparency = 1
PathHint2.Text = "Record from respawn → farm. Empty path inherits Priority #1 route (same area OK)."
PathHint2.TextColor3 = CONFIG.UI_MUTED
PathHint2.Font = Enum.Font.Gotham
PathHint2.TextSize = 10
PathHint2.TextWrapped = true
PathHint2.TextXAlignment = Enum.TextXAlignment.Left
PathHint2.Parent = Content

local PathEntityBar = Instance.new("Frame")
PathEntityBar.LayoutOrder = nextOrder()
PathEntityBar.Size = UDim2.new(1, 0, 0, 34)
PathEntityBar.BackgroundTransparency = 1
PathEntityBar.Parent = Content
local pebLayout = Instance.new("UIListLayout", PathEntityBar)
pebLayout.FillDirection = Enum.FillDirection.Horizontal
pebLayout.Padding = UDim.new(0, 6)

local function entityPathBtn(text)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(0.5, -3, 1, 0)
	b.BackgroundColor3 = CONFIG.UI_SURFACE
	b.BorderSizePixel = 0
	b.Text = text
	b.TextColor3 = CONFIG.UI_TEXT
	b.Font = Enum.Font.GothamBold
	b.TextSize = 11
	b.Parent = PathEntityBar
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
	return b
end

local PrevEntityBtn = entityPathBtn("< Prev target")
local NextEntityBtn = entityPathBtn("Next target >")

local PathToolbar = Instance.new("Frame")
PathToolbar.LayoutOrder = nextOrder()
PathToolbar.Size = UDim2.new(1, 0, 0, 34)
PathToolbar.BackgroundTransparency = 1
PathToolbar.Parent = Content
local ptLayout = Instance.new("UIListLayout", PathToolbar)
ptLayout.FillDirection = Enum.FillDirection.Horizontal
ptLayout.Padding = UDim.new(0, 6)

local function toolBtn(text, parent)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(0.33, -4, 1, 0)
	b.BackgroundColor3 = CONFIG.UI_SURFACE
	b.BorderSizePixel = 0
	b.Text = text
	b.TextColor3 = CONFIG.UI_TEXT
	b.Font = Enum.Font.GothamBold
	b.TextSize = 11
	b.Parent = parent
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
	return b
end

local RecordBtn = toolBtn("Record", PathToolbar)
local ClearPathBtn = toolBtn("Clear path", PathToolbar)
local PathCountLbl = Instance.new("TextLabel")
PathCountLbl.Size = UDim2.new(0.33, -4, 1, 0)
PathCountLbl.BackgroundColor3 = CONFIG.UI_SURFACE
PathCountLbl.BorderSizePixel = 0
PathCountLbl.Text = "0 pts"
PathCountLbl.TextColor3 = CONFIG.UI_MUTED
PathCountLbl.Font = Enum.Font.GothamMedium
PathCountLbl.TextSize = 11
PathCountLbl.Parent = PathToolbar
Instance.new("UICorner", PathCountLbl).CornerRadius = UDim.new(0, 6)

local PathList = Instance.new("Frame")
PathList.LayoutOrder = nextOrder()
PathList.Size = UDim2.new(1, 0, 0, 0)
PathList.AutomaticSize = Enum.AutomaticSize.Y
PathList.BackgroundTransparency = 1
PathList.Parent = Content
local pathListLayout = Instance.new("UIListLayout", PathList)
pathListLayout.Padding = UDim.new(0, 3)

local function refreshPathEntityLabel()
	local name = GetEditPathEntity()
	local farm = GetActiveFarmEntity()
	if name then
		local n = #GetEditWaypoints()
		local mark = (farm == name) and " [FARMING]" or ""
		PathEntityLabel.Text = "Editing path: " .. name .. "  (" .. n .. " pts)" .. mark
		CONFIG.ActivePathEntity = name
	else
		PathEntityLabel.Text = "Path for: (add enemy to priority first)"
	end
end

local function refreshPathUI()
	for _, ch in PathList:GetChildren() do
		if ch:IsA("GuiObject") and ch ~= pathListLayout then ch:Destroy() end
	end
	local wps = GetEditWaypoints()
	PathCountLbl.Text = #wps .. " pts"
	refreshPathEntityLabel()
	for i, wp in ipairs(wps) do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, 30)
		row.BackgroundColor3 = CONFIG.UI_SURFACE
		row.BorderSizePixel = 0
		row.Parent = PathList
		Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)
		local lbl = Instance.new("TextLabel")
		lbl.BackgroundTransparency = 1
		lbl.Size = UDim2.new(1, -100, 1, 0)
		lbl.Position = UDim2.new(0, 8, 0, 0)
		lbl.Text = string.format("#%d  %.0f, %.0f, %.0f", i, wp.X, wp.Y, wp.Z)
		lbl.TextColor3 = CONFIG.UI_TEXT
		lbl.Font = Enum.Font.Gotham
		lbl.TextSize = 11
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.Parent = row
		local act = Instance.new("TextButton")
		act.Size = UDim2.fromOffset(56, 22)
		act.Position = UDim2.new(1, -90, 0.5, -11)
		act.BackgroundColor3 = CONFIG.UI_HOVER
		act.BorderSizePixel = 0
		act.Text = wp.Action == "Interact" and "X" or "-"
		act.TextColor3 = wp.Action == "Interact" and CONFIG.UI_ACCENT or CONFIG.UI_MUTED
		act.Font = Enum.Font.GothamBold
		act.TextSize = 11
		act.Parent = row
		Instance.new("UICorner", act).CornerRadius = UDim.new(0, 4)
		act.Activated:Connect(function()
			wp.Action = wp.Action == "Interact" and "None" or "Interact"
			refreshPathUI()
		end)
		local del = Instance.new("TextButton")
		del.Size = UDim2.fromOffset(24, 22)
		del.Position = UDim2.new(1, -28, 0.5, -11)
		del.BackgroundColor3 = CONFIG.UI_HOVER
		del.BorderSizePixel = 0
		del.Text = "x"
		del.TextColor3 = CONFIG.UI_TEXT
		del.Font = Enum.Font.GothamBold
		del.TextSize = 12
		del.Parent = row
		Instance.new("UICorner", del).CornerRadius = UDim.new(0, 4)
		del.Activated:Connect(function()
			table.remove(wps, i)
			CONFIG.CurrentWaypoint = math.min(CONFIG.CurrentWaypoint, math.max(1, #wps))
			refreshPathUI()
		end)
	end
end

local function cycleActiveEntity(dir)
	local list = CONFIG.TARGET_ENTITY_PRIORITY
	if #list == 0 then return end
	local cur = CONFIG.ActivePathEntity or list[1]
	local idx = table.find(list, cur) or 1
	idx = idx + dir
	if idx < 1 then idx = #list end
	if idx > #list then idx = 1 end
	CONFIG.ActivePathEntity = list[idx]
	EnsurePath(list[idx])
	CONFIG.CurrentWaypoint = 1
	SyncFarmFromPath()
	ResetCombatLock()
	refreshPathUI()
	if updateFarmInfo then updateFarmInfo() end
end

PrevEntityBtn.Activated:Connect(function() cycleActiveEntity(-1) end)
NextEntityBtn.Activated:Connect(function() cycleActiveEntity(1) end)

RecordBtn.Activated:Connect(function()
	if not RootPart then return end
	local name = GetEditPathEntity()
	if not name then
		PathEntityLabel.Text = "Add an enemy to priority first"
		return
	end
	local path = EnsurePath(name)
	CONFIG.ActivePathEntity = name
	local p = RootPart.Position
	table.insert(path.Waypoints, { X = p.X, Y = p.Y, Z = p.Z, Action = "None", Label = "" })
	refreshPathUI()
end)

ClearPathBtn.Activated:Connect(function()
	local name = GetEditPathEntity()
	if not name then return end
	local path = EnsurePath(name)
	path.Waypoints = {}
	if GetActiveFarmEntity() == name then
		CONFIG.CurrentWaypoint = 1
	end
	refreshPathUI()
end)

refreshPathUI()

sectionLabel("FARM ZONE")
local FarmToolbar = Instance.new("Frame")
FarmToolbar.LayoutOrder = nextOrder()
FarmToolbar.Size = UDim2.new(1, 0, 0, 34)
FarmToolbar.BackgroundTransparency = 1
FarmToolbar.Parent = Content
local ftLayout = Instance.new("UIListLayout", FarmToolbar)
ftLayout.FillDirection = Enum.FillDirection.Horizontal
ftLayout.Padding = UDim.new(0, 6)
local SetCenterBtn = toolBtn("Set Center", FarmToolbar)
local SetDZBtn = toolBtn("Deadzone", FarmToolbar)
local ClearFarmBtn = toolBtn("Clear", FarmToolbar)

local FarmInfo = Instance.new("TextLabel")
FarmInfo.LayoutOrder = nextOrder()
FarmInfo.Size = UDim2.new(1, 0, 0, 36)
FarmInfo.BackgroundColor3 = CONFIG.UI_SURFACE
FarmInfo.BorderSizePixel = 0
FarmInfo.Text = "Center: off  |  R: 200  |  DZ: off"
FarmInfo.TextColor3 = CONFIG.UI_MUTED
FarmInfo.Font = Enum.Font.Gotham
FarmInfo.TextSize = 11
FarmInfo.Parent = Content
Instance.new("UICorner", FarmInfo).CornerRadius = UDim.new(0, 8)

local RadiusBar = Instance.new("Frame")
RadiusBar.LayoutOrder = nextOrder()
RadiusBar.Size = UDim2.new(1, 0, 0, 30)
RadiusBar.BackgroundTransparency = 1
RadiusBar.Parent = Content
local rbLayout = Instance.new("UIListLayout", RadiusBar)
rbLayout.FillDirection = Enum.FillDirection.Horizontal
rbLayout.Padding = UDim.new(0, 4)
local function rBtn(t)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(0.25, -3, 1, 0)
	b.BackgroundColor3 = CONFIG.UI_SURFACE
	b.BorderSizePixel = 0
	b.Text = t
	b.TextColor3 = CONFIG.UI_TEXT
	b.Font = Enum.Font.GothamBold
	b.TextSize = 11
	b.Parent = RadiusBar
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
	return b
end
local Rm, Rp, Dm, Dp = rBtn("R-25"), rBtn("R+25"), rBtn("DZ-5"), rBtn("DZ+5")

local function updateFarmInfo()
	SyncFarmFromPath()
	local ent = GetActiveFarmEntity() or "-"
	local c = GetFarmCenter()
	local path = select(1, GetActivePath())
	local d = path and vec3From(path.DeadzoneCenter) or vec3From(CONFIG.DeadzoneCenter)
	local r = GetFarmRadius()
	local dzr = (path and path.DeadzoneRadius) or CONFIG.DeadzoneRadius or 0
	local cs = c and string.format("%.0f,%.0f,%.0f", c.X, c.Y, c.Z) or "off"
	local ds = d and string.format("%.0f,%.0f", d.X, d.Z) or "off"
	FarmInfo.Text = string.format("[%s] Center: %s | R: %d | DZ: %s r=%d",
		ent, cs, r, ds, dzr)
end

SetCenterBtn.Activated:Connect(function()
	if not RootPart then return end
	local name = GetActiveFarmEntity()
	if name then
		local path = EnsurePath(name)
		path.FarmCenter = RootPart.Position
		path.FarmRadius = path.FarmRadius or CONFIG.FarmRadius or 200
		CONFIG.ActivePathEntity = name
	end
	CONFIG.FarmCenter = RootPart.Position
	CONFIG.UseCustomFarmZone = true
	SaveFarmIntoPath()
	updateFarmInfo()
end)
SetDZBtn.Activated:Connect(function()
	if not RootPart then return end
	CONFIG.DeadzoneCenter = RootPart.Position
	if (CONFIG.DeadzoneRadius or 0) <= 0 then CONFIG.DeadzoneRadius = 35 end
	SaveFarmIntoPath()
	updateFarmInfo()
end)
ClearFarmBtn.Activated:Connect(function()
	CONFIG.FarmCenter = nil
	CONFIG.DeadzoneCenter = nil
	CONFIG.UseCustomFarmZone = false
	CONFIG.FarmRadius = 200
	CONFIG.DeadzoneRadius = 35
	updateFarmInfo()
end)
Rm.Activated:Connect(function()
	CONFIG.FarmRadius = math.max(25, (CONFIG.FarmRadius or 200) - 25)
	SaveFarmIntoPath()
	updateFarmInfo()
end)
Rp.Activated:Connect(function()
	CONFIG.FarmRadius = math.min(600, (CONFIG.FarmRadius or 200) + 25)
	SaveFarmIntoPath()
	updateFarmInfo()
end)
Dm.Activated:Connect(function()
	CONFIG.DeadzoneRadius = math.max(0, (CONFIG.DeadzoneRadius or 35) - 5)
	SaveFarmIntoPath()
	updateFarmInfo()
end)
Dp.Activated:Connect(function()
	CONFIG.DeadzoneRadius = math.min(150, (CONFIG.DeadzoneRadius or 35) + 5)
	SaveFarmIntoPath()
	updateFarmInfo()
end)
updateFarmInfo()

-- Config save
sectionLabel("FLOOR / PLACE")
local FloorInfo = Instance.new("TextLabel")
FloorInfo.LayoutOrder = nextOrder()
FloorInfo.Size = UDim2.new(1, 0, 0, 36)
FloorInfo.BackgroundColor3 = CONFIG.UI_SURFACE
FloorInfo.BorderSizePixel = 0
FloorInfo.Text = GetHeaderSubtitle()
FloorInfo.TextColor3 = CONFIG.UI_TEXT
FloorInfo.Font = Enum.Font.GothamMedium
FloorInfo.TextSize = 12
FloorInfo.TextWrapped = true
FloorInfo.Parent = Content
Instance.new("UICorner", FloorInfo).CornerRadius = UDim.new(0, 8)

local FloorNameBox = Instance.new("TextBox")
FloorNameBox.LayoutOrder = nextOrder()
FloorNameBox.Size = UDim2.new(1, 0, 0, 34)
FloorNameBox.BackgroundColor3 = CONFIG.UI_SURFACE
FloorNameBox.BorderSizePixel = 0
FloorNameBox.PlaceholderText = "Custom floor name (e.g. Floor 16 Goblin)"
FloorNameBox.PlaceholderColor3 = CONFIG.UI_MUTED
FloorNameBox.Text = FloorLabel or ""
FloorNameBox.TextColor3 = CONFIG.UI_TEXT
FloorNameBox.Font = Enum.Font.Gotham
FloorNameBox.TextSize = 12
FloorNameBox.ClearTextOnFocus = false
FloorNameBox.Parent = Content
Instance.new("UICorner", FloorNameBox).CornerRadius = UDim.new(0, 8)
local fnPad = Instance.new("UIPadding", FloorNameBox)
fnPad.PaddingLeft = UDim.new(0, 10)

local SetFloorBtn = Instance.new("TextButton")
SetFloorBtn.LayoutOrder = nextOrder()
SetFloorBtn.Size = UDim2.new(1, 0, 0, 32)
SetFloorBtn.BackgroundColor3 = CONFIG.UI_ACCENT
SetFloorBtn.BorderSizePixel = 0
SetFloorBtn.Text = "Set floor name for this PlaceId"
SetFloorBtn.TextColor3 = Color3.new(1, 1, 1)
SetFloorBtn.Font = Enum.Font.GothamBold
SetFloorBtn.TextSize = 12
SetFloorBtn.Parent = Content
Instance.new("UICorner", SetFloorBtn).CornerRadius = UDim.new(0, 8)

local function refreshFloorUI()
	local t = GetHeaderSubtitle()
	FloorInfo.Text = t
	if SubTitle then SubTitle.Text = t end
	FloorNameBox.Text = FloorLabel or ""
end

SetFloorBtn.Activated:Connect(function()
	local t = FloorNameBox.Text:gsub("^%s+", ""):gsub("%s+$", "")
	if t == "" then
		FloorLabel = nil
	else
		FloorLabel = t
		-- also keep in FLOOR_MAP for this session
		CONFIG.FLOOR_MAP[game.PlaceId] = t
	end
	refreshFloorUI()
end)

sectionLabel("CONFIG")
local CfgBar = Instance.new("Frame")
CfgBar.LayoutOrder = nextOrder()
CfgBar.Size = UDim2.new(1, 0, 0, 34)
CfgBar.BackgroundTransparency = 1
CfgBar.Parent = Content
local cbLayout = Instance.new("UIListLayout", CfgBar)
cbLayout.FillDirection = Enum.FillDirection.Horizontal
cbLayout.Padding = UDim.new(0, 6)
local SaveBtn = toolBtn("Save", CfgBar)
local LoadBtn = toolBtn("Load", CfgBar)
local CfgStatus = Instance.new("TextLabel")
CfgStatus.Size = UDim2.new(0.33, -4, 1, 0)
CfgStatus.BackgroundColor3 = CONFIG.UI_SURFACE
CfgStatus.BorderSizePixel = 0
CfgStatus.Text = "Ready"
CfgStatus.TextColor3 = CONFIG.UI_MUTED
CfgStatus.Font = Enum.Font.Gotham
CfgStatus.TextSize = 11
CfgStatus.Parent = CfgBar
Instance.new("UICorner", CfgStatus).CornerRadius = UDim.new(0, 6)

SaveBtn.Activated:Connect(function()
	local name = "Place_" .. tostring(game.PlaceId)
	local ok, err = SaveConfig(name)
	CfgStatus.Text = ok and ("Saved") or tostring(err):sub(1, 12)
end)
LoadBtn.Activated:Connect(function()
	local name = "Place_" .. tostring(game.PlaceId)
	local ok, err = LoadConfig(name)
	if ok then
		rebuildPriorityUI()
		refreshPathUI()
		updateFarmInfo()
		if refreshFloorUI then refreshFloorUI() end
		Enabled = Feature.AutoFarm
		CfgStatus.Text = "Loaded"
	else
		CfgStatus.Text = tostring(err):sub(1, 12)
	end
end)

-- Drag panel
local dragging, dragStart, startPos = false, nil, nil
Header.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = input.Position
		startPos = Panel.Position
		input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then dragging = false end
		end)
	end
end)
UserInputService.InputChanged:Connect(function(input)
	if not dragging then return end
	if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
	local cam = workspace.CurrentCamera
	if not cam then return end
	local d = input.Position - dragStart
	Panel.Position = UDim2.fromScale(
		startPos.X.Scale + d.X / cam.ViewportSize.X,
		startPos.Y.Scale + d.Y / cam.ViewportSize.Y
	)
end)

local guiVisible = true
ToggleBtn.Activated:Connect(function()
	guiVisible = not guiVisible
	Panel.Visible = guiVisible
end)

task.defer(function()
	TryAutoLoad()
	if SubTitle then
		SubTitle.Text = GetHeaderSubtitle()
	end
end)

----------------------------------------------------------------------
-- MAIN LOOP
----------------------------------------------------------------------
RunService.RenderStepped:Connect(function()
	if RootPart then
		local p = RootPart.Position
		StatPos.Text = string.format("%.0f, %.0f, %.0f", p.X, p.Y, p.Z)
	end
	if Humanoid then
		local stats = Player:FindFirstChild("PlayerStats")
		if stats and stats:FindFirstChild("Level") and stats.Level.Value >= 300 then
			if Humanoid.WalkSpeed < CONFIG.MAXIMUM_WALKSPEED then
				Humanoid.WalkSpeed = CONFIG.MAXIMUM_WALKSPEED
			end
		elseif Humanoid.WalkSpeed < CONFIG.MINIMUM_WALKSPEED then
			Humanoid.WalkSpeed = CONFIG.MINIMUM_WALKSPEED
		end
	end
end)

RunService.Heartbeat:Connect(function()
	local now = os.clock()

	if not Humanoid or not RootPart then
		updateCharacter()
		ResetCombatLock()
		return
	end
	if Humanoid.Health <= 0 then
		ResetCombatLock()
		return
	end

	if now - LAST_TEXT >= 0.5 then
		LAST_TEXT = now
		local _wps = GetActiveWaypoints()
		local _ent = GetActiveFarmEntity() or "-"
		StatWP.Text = _ent .. " " .. CONFIG.CurrentWaypoint .. "/" .. #_wps
		StatDeath.Text = "Deaths: " .. DEATH_COUNT
		if ClosestTarget then
			local cfg = ClosestTarget:FindFirstChild("Config")
			local ent = cfg and cfg:FindFirstChild("Entity")
			StatTarget.Text = "Target: " .. (ent and ent.Value or "?")
		else
			StatTarget.Text = "Target: --"
		end
	end

	if now - LAST_MOB_VALIDATION >= CONFIG.MOB_VALIDATION_INTERVAL then
		LAST_MOB_VALIDATION = now
		UpdateValidMobs()
	end

	if not Enabled or not Feature.AutoFarm then
		if FaceOrientation then FaceOrientation.Enabled = false end
		Humanoid.AutoRotate = true
		Humanoid:Move(Vector3.zero)
		return
	end

	if not InputBindableFunction then
		InputBindableFunction = PlayerGui:FindFirstChild("InputBindableFunction", true)
		return
	end

	local stats = Player:FindFirstChild("PlayerStats")
	local sword = Character and Character:FindFirstChild("Sword")
	if not sword or not sword:FindFirstChild("MainWeld", true) or not stats then return end
	local mainWeld = sword:FindFirstChild("MainWeld", true)

	-- Force return to farm
	if now - LAST_FORCE_RETURN >= CONFIG.RETURN_TO_FARM_INTERVAL then
		LAST_FORCE_RETURN = now
		if ShouldForceReturn() then
			ForceReturnToFarm()
			return
		end
	elseif ForcingReturn then
		if ShouldForceReturn() then
			ForceReturnToFarm()
			return
		end
		ForcingReturn = false
	end

	-- Emergency retreat / heal
	local emergency = Humanoid.Health <= Humanoid.MaxHealth * 0.4
	local shouldHeal = Humanoid.Health <= Humanoid.MaxHealth * 0.65
	if emergency then
		RETREATING = true
	elseif RETREATING and Humanoid.Health >= Humanoid.MaxHealth * 0.7 then
		RETREATING = false
	end
	if RETREATING then
		if FaceOrientation then FaceOrientation.Enabled = false end
		Humanoid.AutoRotate = true
		local center = GetFarmCenter()
		if center then Humanoid:MoveTo(center) else Humanoid:Move(Vector3.zero) end
		if Equipped or (mainWeld.Part1 and mainWeld.Part1.Name ~= "UpperTorso") then
			Equipped = false
			InputBindableFunction:Invoke("EquipButton", Enum.UserInputState.Begin)
			return
		end
		local use = Replicated:FindFirstChild("UseConsumable", true)
		if use and not Equipped and (emergency or shouldHeal) then
			local last = stats:FindFirstChild("LastConsumed")
			if last and last.Value ~= "" and now - LAST_CONSUME_TIME >= CONFIG.CONSUME_INTERVAL then
				LAST_CONSUME_TIME = now
				use:InvokeServer(last.Value)
			end
		end
		return
	end

	-- Auto block (all floors)
	if Feature.AutoBlock then
		for _, plr in Players:GetPlayers() do
			if plr ~= Player and not isBlocked(plr.UserId) then
				promptBlockPlayer(plr)
				break
			end
		end
		for _, plr in Players:GetPlayers() do
			if plr ~= Player and isBlocked(plr.UserId) then
				TeleportToPlace()
				return
			end
		end
	end

	if workspace.DistributedGameTime >= CONFIG.MAX_SERVER_AGE then
		TeleportToPlace()
		return
	end

	-- Path following
	local wps = GetActiveWaypoints()
	local onPath = #wps > 0 and CONFIG.CurrentWaypoint <= #wps
	local atEnd = #wps == 0 or CONFIG.CurrentWaypoint > #wps

	if not ClosestTarget then
		ClosestTarget = GetClosestPriorityMob()
	elseif not IsTargetLockValid(ClosestTarget) then
		ClosestTarget = nil
	end

	if onPath and not ClosestTarget then
		local pos, action = GetWaypointPos(CONFIG.CurrentWaypoint)
		if pos then
			if horizDist(RootPart.Position, pos) <= CONFIG.PATH_REACH_DISTANCE then
				if action == "Interact" and now - LAST_PATH_INTERACT >= CONFIG.INTERACT_COOLDOWN then
					LAST_PATH_INTERACT = now
					InputBindableFunction:Invoke("InteractButton", Enum.UserInputState.Begin)
				end
				CONFIG.CurrentWaypoint = CONFIG.CurrentWaypoint + 1
			else
				if FaceOrientation then FaceOrientation.Enabled = false end
				Humanoid.AutoRotate = true
				Humanoid:MoveTo(pos)
				if now - LAST_STUCK_TIME >= CONFIG.STUCK_CHECK_INTERVAL then
					LAST_STUCK_TIME = now
					if LAST_STUCK_POS and (RootPart.Position - LAST_STUCK_POS).Magnitude < 1 then
						DoJump()
					else
						LAST_STUCK_POS = RootPart.Position
					end
				end
			end
		else
			atEnd = true
		end
	elseif ClosestTarget then
		MoveToMob(ClosestTarget)
	elseif Feature.AutoPatrol and (atEnd or GetFarmCenter()) then
		if not MoveToPatrol() then
			if FaceOrientation then FaceOrientation.Enabled = false end
			Humanoid.AutoRotate = true
			Humanoid:Move(Vector3.zero)
		end
	else
		if FaceOrientation then FaceOrientation.Enabled = false end
		Humanoid.AutoRotate = true
		Humanoid:Move(Vector3.zero)
	end

	if Humanoid:GetState() == Enum.HumanoidStateType.Swimming then
		DoJump()
		return
	end
	if Humanoid.Sit then
		Humanoid.Sit = false
		DoJump()
		return
	end

	-- Combat when we have a target (path done or mid-path with nearby mob)
	if ClosestTarget and IsTargetLockValid(ClosestTarget) then
		if not Equipped or (mainWeld.Part1 and mainWeld.Part1.Name == "UpperTorso") then
			Equipped = true
			InputBindableFunction:Invoke("EquipButton", Enum.UserInputState.Begin)
			return
		end
		local mroot = ClosestTarget:FindFirstChild("HumanoidRootPart")
		local mhum = ClosestTarget:FindFirstChildOfClass("Humanoid")
		if mroot and mhum and mhum.Health > 0 then
			local dist = GetMobDistance(ClosestTarget)
			if dist <= 30 and now - LAST_ATTACK_TIME >= CONFIG.ATTACK_INTERVAL then
				LAST_ATTACK_TIME = now
				InputBindableFunction:Invoke("AttackButton", Enum.UserInputState.Begin)
			end
			if Feature.AutoSkill and dist <= 15 and now - LAST_SKILL_TIME >= CONFIG.SKILL_INTERVAL then
				LAST_SKILL_TIME = now
				InputBindableFunction:Invoke("SkillButton", Enum.UserInputState.Begin)
			end
		else
			ValidMobs[ClosestTarget] = nil
			ClosestTarget = nil
		end
	elseif onPath and not ClosestTarget then
		if now - LAST_INTERACTION_TIME >= CONFIG.INTERACTION_INTERVAL then
			LAST_INTERACTION_TIME = now
			-- keep interacting while walking path for doors
		end
	end
end)

print("[SBOR Auto Farm] " .. CONFIG.VERSION .. " loaded | Place " .. tostring(game.PlaceId))
