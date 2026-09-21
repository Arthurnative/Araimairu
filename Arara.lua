local Players            = game:GetService("Players")
local Replicated         = game:GetService("ReplicatedStorage")
local StarterGui         = game:GetService("StarterGui")
local RunService         = game:GetService("RunService")
local UserInputService   = game:GetService("UserInputService")
local MarketplaceService = game:GetService("MarketplaceService")
local HttpService        = game:GetService("HttpService")
local VirtualUser        = game:GetService("VirtualUser")

local Player    = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui", 10)

local CONFIG = {
	VERSION = "v1.60",

	CURRENT_WAYPOINT_TARGET = 1,
	MAX_SERVER_AGE = 7 * 60 * 60,

	TARGET_ENTITY_PRIORITY = {
		[1] = "Goblin",
		[2] = "Leader Goblin",
	},

	GOBLIN_REACH_DISTANCE = 8,
	PLAYER_ATTACK_DISTANCE = 8,
	ENEMY_ATTACK_SAFE_DISTANCE = 2,
	ENEMY_BLADE_PADDING = 2,
	GROUP_DANGER_DISTANCE = 22,
	THREAT_DETECTION_DISTANCE = 12,
	THREAT_ANGLE = 65,
	THREAT_ESCAPE_DISTANCE = 20,

	DEADZONE_ESCAPE_DISTANCE = 45,
	DEADZONE_ESCAPE_DIRECTIONS = 16,
	DEADZONE_ESCAPE_INTERVAL = 0.3,

	JUMP_HEIGHT = 2,
	STUCK_CHECK_INTERVAL = 0.5,
	BLOCK_COOLDOWN = 3,

	MOB_DETECTION_DISTANCE = 450, -- was 200; see farther mobs/bosses
	RETURN_TO_FARM_DISTANCE = 80, -- if this far from farm center, force return
	RETURN_TO_FARM_INTERVAL = 8, -- seconds between forced return checks
	MOB_VALIDATION_INTERVAL = 0.15,
	DISTANCE_Y_CALCULATE = false,
	TARGET_UNREACHABLE_TIMEOUT = 10,
	TARGET_REPOSITION_INTERVAL = 0.3,
	TARGET_REPOSITION_RADIUS = 12,
	TARGET_REPOSITION_DIRECTIONS = 16,
	SAFE_COMBAT_DIRECTIONS = 12,
	SAFE_COMBAT_MAX_PATH_TESTS = 4,

	RETREAT_DISTANCE = 60,
	RETREAT_DIRECTIONS = 16,
	RETREAT_RECALCULATE_INTERVAL = 0.5,
	RETREAT_NO_POSITION_TIMEOUT = 1.5,

	ATTACK_INTERVAL = 0.2,
	SKILL_INTERVAL = 3,
	CONSUME_INTERVAL = 10,
	MINIMUM_WALKSPEED = 28,
	MAXIMUM_WALKSPEED = 38,
	INTERACTION_INTERVAL = 0.5,
	TEXT_UPDATE_INTERVAL = 0.5,

	SAFECOMBAT_INTERVAL = 0.25,
	BLADE_PART_CACHE_INTERVAL = 0.2,
	COMBAT_GROUP_CACHE_INTERVAL = 0.15,
	DIRECT_PATH_CACHE_INTERVAL = 0.12,

	PATROL_RADIUS_MIN = 28,
	PATROL_RADIUS_MAX = 60,
	PATROL_DIRECTIONS = 12,
	PATROL_RECALCULATE_INTERVAL = math.random(10, 16),
	PATROL_ESCAPE_DISTANCE = 10,
	PATROL_ESCAPE_DIRECTIONS = 4,
	
	WATER_SAMPLE_DISTANCE = 4,
	DEADZONE_SAMPLE_DISTANCE = 2,

	-- Custom path / profiles
	UseCustomPath = false,
	CustomWaypoints = {}, -- { X, Y, Z, Action = "None"|"Interact", Label = "" }
	CurrentCustomWaypoint = 1,
	CUSTOM_REACH_DISTANCE = 6,
	INTERACT_HOLD_TIME = 0.55,
	ANTI_AFK_ENABLED = true,

	-- Custom Farm Zone (overrides PLACE_CONFIG when enabled)
	UseCustomFarmZone = false,
	CustomFarmCenter = nil, -- Vector3 or {X,Y,Z}
	CustomFarmRadius = 200,
	CustomDeadzoneCenter = nil,
	CustomDeadzoneRadius = 35,

	UI_PANEL = Color3.fromRGB(22, 23, 29),
	UI_SURFACE = Color3.fromRGB(29, 31, 38),
	UI_HOVER = Color3.fromRGB(38, 40, 48),
	UI_BORDER = Color3.fromRGB(55, 58, 68),
	UI_TEXT = Color3.fromRGB(238, 239, 244),
	UI_MUTED = Color3.fromRGB(145, 149, 162),
	UI_ACCENT = Color3.fromRGB(112, 126, 255),
}

local PLACE_CONFIG = {
	[10299594856] = { --// Event Floor
		DEFAULT_TARGET_PRIORITY = {
			[1] = "Karkinos the Visceral",
			[2] = "Water Style Disciple",
			[3] = "Drake the North Sea Commander",
		},
		WAYPOINTS = {
			Vector3.new(1773, 61, 336),
			Vector3.new(1778, 61, 536),
			Vector3.new(1810, 61, 703),
			Vector3.new(1652, 71, 809),
			Vector3.new(1652, 99, 735),
			Vector3.new(1600, 118, 737),
			Vector3.new(1605, 125, 770),
			Vector3.new(1533, 110, 778),
			Vector3.new(1466, 102, 726),
			Vector3.new(1427, 86, 664),
			Vector3.new(1410, 83, 712),
			Vector3.new(1455, 72, 720),
			Vector3.new(1533, 57, 588),
			Vector3.new(1474, 57, 553),
			Vector3.new(1442, 61, 517),
			Vector3.new(1438, 61, 504),
		},
		FARM_CENTER = Vector3.new(1442, 61, 517),
		FARM_RADIUS = 200,
		FARM_DEADZONE_CENTER = Vector3.zero,
		FARM_DEADZONE_RADIUS = 35,

		REACH_DISTANCE = 5,
	},
	[11987539001] = {
		DEFAULT_TARGET_PRIORITY = { --// F16
			[1] = "Goblin",
			[2] = "Leader Goblin",
		},
		WAYPOINTS = {
			Vector3.new(-2326, 163, -1412),
			Vector3.new(-2271, 148, -1298),
			Vector3.new(-2171, 168, -914),
			Vector3.new(-2044, 167, -429),
			Vector3.new(-1971, 157, 59),
			Vector3.new(-1831, 164, 168),
			Vector3.new(-1681, 184, 879),
			Vector3.new(-1520, 179, 1452),
			Vector3.new(-1409, 179, 1846),
			Vector3.new(-1365, 179, 1905),
			Vector3.new(-1364, 172, 1962),
			Vector3.new(-1363, 174, 2068),
			Vector3.new(-1437, 176, 2494),
			Vector3.new(-1654, 174, 2619),
			Vector3.new(-1792, 175, 2769),
		},
		FARM_CENTER = Vector3.new(-1715, 173, 2798),
		FARM_RADIUS = 200,
		FARM_DEADZONE_CENTER = Vector3.new(-1681, 173, 2821),
		FARM_DEADZONE_RADIUS = 35,

		REACH_DISTANCE = 5,
	}
}

function IsValidPlace(id: number)
	if PLACE_CONFIG[id] then
		return PLACE_CONFIG[id]
	end
	return false
end

local PlaceConfig = IsValidPlace(game.PlaceId)
if PlaceConfig then
	CONFIG.TARGET_ENTITY_PRIORITY = PlaceConfig.DEFAULT_TARGET_PRIORITY
end

-- Returns the active farm geometry (custom overrides PLACE_CONFIG when enabled)
function GetActiveFarmConfig()
	if CONFIG.UseCustomFarmZone and Feature.UseCustomFarmZone and Feature.UseCustomFarmZone.Enabled then
		local center = CONFIG.CustomFarmCenter
		if type(center) == "table" and center.X then
			center = Vector3.new(center.X, center.Y, center.Z)
		end
		local dcenter = CONFIG.CustomDeadzoneCenter
		if type(dcenter) == "table" and dcenter.X then
			dcenter = Vector3.new(dcenter.X, dcenter.Y, dcenter.Z)
		end
		if center then
			return {
				FARM_CENTER = center,
				FARM_RADIUS = CONFIG.CustomFarmRadius or 200,
				FARM_DEADZONE_CENTER = dcenter or Vector3.zero,
				FARM_DEADZONE_RADIUS = CONFIG.CustomDeadzoneRadius or 0,
				REACH_DISTANCE = (PlaceConfig and PlaceConfig.REACH_DISTANCE) or 5,
				WAYPOINTS = (PlaceConfig and PlaceConfig.WAYPOINTS) or {},
			}
		end
	end
	return PlaceConfig
end

function GetFarmCenter()
	local farm = GetActiveFarmConfig()
	return farm and farm.FARM_CENTER
end

function GetFarmRadius()
	local farm = GetActiveFarmConfig()
	return farm and farm.FARM_RADIUS or 200
end


local Character
local Humanoid
local RootPart

local Feature = {
	AutoFarm = {
		Enabled = true,
		Button = nil,
		Status = nil,
	},
	AutoBlock = {
		Enabled = true,
		Button = nil,
		Status = nil,
	},
	SafeCombat = {
		Enabled = true,
		Button = nil,
		Status = nil,
	},
	AutoFind = {
		Enabled = false,
		Button = nil,
		Status = nil,
	},
	IgnoreFarmZone = {
		Enabled = false,
		Button = nil,
		Status = nil,
	},
	AutoPatrol = {
		Enabled = true,
		Button = nil,
		Status = nil,
	},
	AutoSkill = {
		Enabled = true,
		Button = nil,
		Status = nil,
	},
	ResetOnBoostOut = {
		Enabled = true,
		Button = nil,
		Status = nil,
	},
	ResetStats = {
		Enabled = true,
		Button = nil,
		Status = nil,
	},
	UseCustomPath = {
		Enabled = false,
		Button = nil,
		Status = nil,
	},
	UseCustomFarmZone = {
		Enabled = false,
		Button = nil,
		Status = nil,
	},
}

--// Config profile system (DeltaX writefile/readfile)
local CONFIG_DIR = "SBOR_Configs"
local CURRENT_PROFILE_NAME = "Default"
local ProfileStatusLabel = nil
local LAST_CUSTOM_INTERACT_TIME = 0

-- ============================================================
-- CONFIG SAVE / LOAD (DeltaX compatible)
-- ============================================================

local function ensureConfigDir()
	if isfolder and not isfolder(CONFIG_DIR) then
		pcall(makefolder, CONFIG_DIR)
	end
end

local function profilePath(name)
	name = tostring(name or CURRENT_PROFILE_NAME):gsub("[^%w%-%_]", "_")
	if name == "" then name = "Default" end
	return CONFIG_DIR .. "/" .. name .. ".json"
end

function BuildConfigTable()
	local waypoints = {}
	for _, wp in ipairs(CONFIG.CustomWaypoints or {}) do
		table.insert(waypoints, {
			X = tonumber(wp.X) or 0,
			Y = tonumber(wp.Y) or 0,
			Z = tonumber(wp.Z) or 0,
			Action = (wp.Action == "Interact") and "Interact" or "None",
			Label = tostring(wp.Label or ""),
		})
	end
	local priority = {}
	for _, name in ipairs(CONFIG.TARGET_ENTITY_PRIORITY) do
		table.insert(priority, name)
	end
	return {
		Version = CONFIG.VERSION,
		PlaceId = game.PlaceId,
		ProfileName = CURRENT_PROFILE_NAME,
		Features = {
			AutoFarm = Feature.AutoFarm.Enabled,
			AutoBlock = Feature.AutoBlock.Enabled,
			SafeCombat = Feature.SafeCombat.Enabled,
			AutoFind = Feature.AutoFind.Enabled,
			IgnoreFarmZone = Feature.IgnoreFarmZone.Enabled,
			AutoPatrol = Feature.AutoPatrol.Enabled,
			AutoSkill = Feature.AutoSkill.Enabled,
			ResetOnBoostOut = Feature.ResetOnBoostOut.Enabled,
			UseCustomPath = Feature.UseCustomPath.Enabled,
			UseCustomFarmZone = Feature.UseCustomFarmZone.Enabled,
		},
		TargetEntityPriority = priority,
		UseCustomPath = CONFIG.UseCustomPath,
		CustomWaypoints = waypoints,
		CurrentCustomWaypoint = CONFIG.CurrentCustomWaypoint or 1,
		AntiAfk = CONFIG.ANTI_AFK_ENABLED,
		UseCustomFarmZone = CONFIG.UseCustomFarmZone,
		CustomFarmRadius = CONFIG.CustomFarmRadius,
		CustomDeadzoneRadius = CONFIG.CustomDeadzoneRadius,
		CustomFarmCenter = (function()
			local c = CONFIG.CustomFarmCenter
			if typeof(c) == "Vector3" then return { X = c.X, Y = c.Y, Z = c.Z } end
			if type(c) == "table" then return c end
			return nil
		end)(),
		CustomDeadzoneCenter = (function()
			local c = CONFIG.CustomDeadzoneCenter
			if typeof(c) == "Vector3" then return { X = c.X, Y = c.Y, Z = c.Z } end
			if type(c) == "table" then return c end
			return nil
		end)(),
	}
end

function ApplyConfigTable(data)
	if type(data) ~= "table" then return false, "Invalid config" end

	if type(data.Features) == "table" then
		local F = data.Features
		if F.AutoFarm ~= nil then Feature.AutoFarm.Enabled = F.AutoFarm; Enabled = F.AutoFarm end
		if F.AutoBlock ~= nil then Feature.AutoBlock.Enabled = F.AutoBlock; BlockEnabled = F.AutoBlock end
		if F.SafeCombat ~= nil then Feature.SafeCombat.Enabled = F.SafeCombat; SafeCombatPositionEnabled = F.SafeCombat end
		if F.AutoFind ~= nil then Feature.AutoFind.Enabled = F.AutoFind; WaypointEnabled = not F.AutoFind end
		if F.IgnoreFarmZone ~= nil then Feature.IgnoreFarmZone.Enabled = F.IgnoreFarmZone end
		if F.AutoPatrol ~= nil then Feature.AutoPatrol.Enabled = F.AutoPatrol end
		if F.AutoSkill ~= nil then Feature.AutoSkill.Enabled = F.AutoSkill end
		if F.ResetOnBoostOut ~= nil then Feature.ResetOnBoostOut.Enabled = F.ResetOnBoostOut end
		if F.UseCustomPath ~= nil then
			Feature.UseCustomPath.Enabled = F.UseCustomPath
			CONFIG.UseCustomPath = F.UseCustomPath
		end
		if F.UseCustomFarmZone ~= nil then
			Feature.UseCustomFarmZone.Enabled = F.UseCustomFarmZone
			CONFIG.UseCustomFarmZone = F.UseCustomFarmZone
		end
	end

	if type(data.TargetEntityPriority) == "table" and #data.TargetEntityPriority > 0 then
		CONFIG.TARGET_ENTITY_PRIORITY = {}
		for _, name in ipairs(data.TargetEntityPriority) do
			if type(name) == "string" and name ~= "" then
				table.insert(CONFIG.TARGET_ENTITY_PRIORITY, name)
			end
		end
		ClosestTarget = nil
		table.clear(ValidMobs)
		table.clear(CombatGroupCache)
	end

	if data.UseCustomPath ~= nil then
		CONFIG.UseCustomPath = data.UseCustomPath
		Feature.UseCustomPath.Enabled = data.UseCustomPath
	end

	if type(data.CustomWaypoints) == "table" then
		CONFIG.CustomWaypoints = {}
		for _, wp in ipairs(data.CustomWaypoints) do
			table.insert(CONFIG.CustomWaypoints, {
				X = tonumber(wp.X) or 0,
				Y = tonumber(wp.Y) or 0,
				Z = tonumber(wp.Z) or 0,
				Action = (wp.Action == "Interact") and "Interact" or "None",
				Label = tostring(wp.Label or ""),
			})
		end
		CONFIG.CurrentCustomWaypoint = math.clamp(
			tonumber(data.CurrentCustomWaypoint) or 1,
			1,
			math.max(1, #CONFIG.CustomWaypoints)
		)
	end

	if data.AntiAfk ~= nil then
		CONFIG.ANTI_AFK_ENABLED = data.AntiAfk
	end

	if data.UseCustomFarmZone ~= nil then
		CONFIG.UseCustomFarmZone = data.UseCustomFarmZone
		Feature.UseCustomFarmZone.Enabled = data.UseCustomFarmZone
	end
	if data.CustomFarmRadius ~= nil then
		CONFIG.CustomFarmRadius = tonumber(data.CustomFarmRadius) or 200
	end
	if data.CustomDeadzoneRadius ~= nil then
		CONFIG.CustomDeadzoneRadius = tonumber(data.CustomDeadzoneRadius) or 35
	end
	if type(data.CustomFarmCenter) == "table" and data.CustomFarmCenter.X then
		CONFIG.CustomFarmCenter = Vector3.new(
			tonumber(data.CustomFarmCenter.X) or 0,
			tonumber(data.CustomFarmCenter.Y) or 0,
			tonumber(data.CustomFarmCenter.Z) or 0
		)
	end
	if type(data.CustomDeadzoneCenter) == "table" and data.CustomDeadzoneCenter.X then
		CONFIG.CustomDeadzoneCenter = Vector3.new(
			tonumber(data.CustomDeadzoneCenter.X) or 0,
			tonumber(data.CustomDeadzoneCenter.Y) or 0,
			tonumber(data.CustomDeadzoneCenter.Z) or 0
		)
	end

	if type(data.ProfileName) == "string" and data.ProfileName ~= "" then
		CURRENT_PROFILE_NAME = data.ProfileName
	end

	return true
end

function SaveConfig(name)
	name = name or CURRENT_PROFILE_NAME
	CURRENT_PROFILE_NAME = name
	if not writefile then
		warn("[Config] writefile not available")
		return false, "writefile not available"
	end
	ensureConfigDir()
	local ok, encoded = pcall(function()
		return HttpService:JSONEncode(BuildConfigTable())
	end)
	if not ok then return false, encoded end
	local ok2, err = pcall(writefile, profilePath(name), encoded)
	if not ok2 then return false, err end
	if ProfileStatusLabel then ProfileStatusLabel.Text = "Saved: " .. name end
	return true
end

function LoadConfig(name)
	name = name or CURRENT_PROFILE_NAME
	if not readfile then
		warn("[Config] readfile not available")
		return false, "readfile not available"
	end
	ensureConfigDir()
	local file = profilePath(name)
	if isfile and not isfile(file) then
		return false, "File not found: " .. file
	end
	local ok, raw = pcall(readfile, file)
	if not ok then return false, raw end
	local ok2, data = pcall(function() return HttpService:JSONDecode(raw) end)
	if not ok2 then return false, data end
	CURRENT_PROFILE_NAME = name
	local ok3, err = ApplyConfigTable(data)
	if not ok3 then return false, err end
	if updateFeatureButtons then pcall(updateFeatureButtons) end
	if rebuildPriorityRows then pcall(rebuildPriorityRows) end
	if RefreshPathEditor then pcall(RefreshPathEditor) end
	if UpdateFarmInfoLabel then pcall(UpdateFarmInfoLabel) end
	if ProfileStatusLabel then ProfileStatusLabel.Text = "Loaded: " .. name end
	return true
end

function ListProfiles()
	local list = {}
	if not listfiles then return list end
	ensureConfigDir()
	local ok, files = pcall(listfiles, CONFIG_DIR)
	if not ok or type(files) ~= "table" then return list end
	for _, f in ipairs(files) do
		local name = string.match(f, "([^/\\]+)%.json$")
		if name then table.insert(list, name) end
	end
	table.sort(list)
	return list
end

function TryAutoLoadProfileForPlace()
	if not listfiles or not readfile then return false end
	for _, name in ipairs(ListProfiles()) do
		local ok, raw = pcall(readfile, profilePath(name))
		if ok and raw then
			local ok2, data = pcall(function() return HttpService:JSONDecode(raw) end)
			if ok2 and type(data) == "table" and data.PlaceId == game.PlaceId then
				LoadConfig(name)
				return true
			end
		end
	end
	return false
end

-- ============================================================
-- ANTI AFK (prevents 20-min idle kick)
-- ============================================================

Player.Idled:Connect(function()
	if not CONFIG.ANTI_AFK_ENABLED then return end
	pcall(function()
		VirtualUser:CaptureController()
		VirtualUser:ClickButton2(Vector2.new())
	end)
end)

task.spawn(function()
	while true do
		task.wait(60 + math.random(0, 30))
		if not CONFIG.ANTI_AFK_ENABLED then continue end
		pcall(function()
			VirtualUser:CaptureController()
			VirtualUser:ClickButton2(Vector2.new())
		end)
		-- tiny camera nudge helps some idle detectors
		pcall(function()
			local cam = workspace.CurrentCamera
			if cam then
				cam.CFrame = cam.CFrame * CFrame.Angles(0, math.rad(0.01), 0)
			end
		end)
	end
end)

-- ============================================================
-- AUTO CONFIRM BLOCK PROMPT
-- ============================================================

local function clickGuiButton(btn)
	if not btn then return false end
	pcall(function()
		if firesignal then
			if btn.MouseButton1Click then firesignal(btn.MouseButton1Click) end
			if btn.Activated then firesignal(btn.Activated) end
		end
	end)
	pcall(function()
		if getconnections then
			for _, conn in ipairs(getconnections(btn.MouseButton1Click) or {}) do
				pcall(conn.Fire or conn.fire or function() end)
			end
			for _, conn in ipairs(getconnections(btn.Activated) or {}) do
				pcall(conn.Fire or conn.fire or function() end)
			end
		end
	end)
	pcall(function() btn:Activate() end)
	return true
end

function AutoConfirmBlockPrompt()
	task.spawn(function()
		local CoreGui = game:GetService("CoreGui")
		local deadline = os.clock() + 4
		while os.clock() < deadline do
			local candidates = {}
			local function scan(parent, depth)
				if depth > 8 or not parent then return end
				for _, child in ipairs(parent:GetChildren()) do
					if child:IsA("TextButton") or child:IsA("ImageButton") then
						local text, name = "", ""
						pcall(function() text = string.lower(child.Text or "") end)
						pcall(function() name = string.lower(child.Name or "") end)
						if text:find("block") or text:find("confirm") or text:find("yes")
							or name:find("confirm") or name:find("block") or name:find("yes") then
							table.insert(candidates, child)
						end
					end
					scan(child, depth + 1)
				end
			end
			pcall(function()
				for _, top in ipairs(CoreGui:GetChildren()) do
					local n = top.Name or ""
					if n:find("Prompt") or n:find("Block") or n:find("Dialog") or n:find("Roblox") then
						scan(top, 0)
					end
				end
			end)
			for _, btn in ipairs(candidates) do
				local text = ""
				pcall(function() text = string.lower(btn.Text or "") end)
				if text:find("block") or text:find("confirm") or text == "yes" then
					if clickGuiButton(btn) then return end
				end
			end
			if #candidates > 0 then
				clickGuiButton(candidates[1])
				return
			end
			task.wait(0.15)
		end
	end)
end



local ClosestTarget = nil
local DEATH_COUNT    = 0
local LAST_MOB_VALIDATION_TIME     = 0
local TargetUnreachableSince   = nil
local TargetApproachPosition   = nil
local TargetApproachMob        = nil
local LastTargetRepositionTime = 0

local ValidMobs = {}

local RETREATING         = false
local LastRetreatPosition      = nil
local LastRetreatCalculateTime = 0
local RetreatNoPositionSince   = nil

local LAST_ATTACK_TIME = 0
local LAST_SKILL_TIME  = 0

--// Potion Consume

local LAST_CONSUME_TIME = 0
local LAST_INTERACTION_TIME = 0
local LAST_TEXT_UPDATE_TIME = 0
local LAST_STUCK_TIME = 0
local LAST_STUCK_POSITION = nil

local CAHCED_SAFECOMBAT_POSITION = nil
local LAST_SAFECOMBAT_TIME       = 0

local BladePartCache   = {}
local CombatGroupCache = {}
local CombatBladeCache = {}

local LastDirectPathCheckTime = 0
local LastDirectPathTarget = nil
local LastDirectPathPosition = nil
local LastDirectPathBlocked = false

local LastDeadzoneEscapeTime = 0
local DeadzoneEscapePosition = nil

local PatrolPosition              = nil
local LastPatrolCalculateTime     = 0
local FarmReturnPosition          = nil
local LastFarmReturnCalculateTime = 0
local LastForceReturnToFarmTime   = 0
local ForcingReturnToFarm         = false

--// InputBindableFunction
local InputBindableFunction = nil
local BlockValue            = nil

local WaypointEnabled = true
local Enabled        = true
local Equipped       = false
local TargetCurrency = "Golden Shell"
local LastInventory  = nil
local EventCurrency  = 0

local BlockCache                = {}
local BlockEnabled              = true
local SafeCombatPositionEnabled = true

local FaceAttachment
local FaceOrientation

--// Character
function updateCharacter()
	Character = Player.Character

	if not Character then
		Humanoid = nil
		RootPart = nil
		return
	end

	Humanoid = Character:FindFirstChildOfClass("Humanoid")
	RootPart = Character:FindFirstChild("HumanoidRootPart")

	if not FaceAttachment then
		FaceAttachment = Instance.new("Attachment")
		FaceAttachment.Name = "FaceGoblinAttachment"
		FaceAttachment.Parent = RootPart
	end

	if not FaceOrientation then
		FaceOrientation = Instance.new("AlignOrientation")
		FaceOrientation.Name = "FaceGoblin"
		FaceOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
		FaceOrientation.Attachment0 = FaceAttachment
		FaceOrientation.RigidityEnabled = false
		FaceOrientation.Responsiveness = 25
		FaceOrientation.MaxTorque = math.huge
		FaceOrientation.Enabled = false
		FaceOrientation.Parent = RootPart
	end

	task.defer(function()
		if not Humanoid then
			return
		end

		Humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
		Humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
		Humanoid:SetStateEnabled(Enum.HumanoidStateType.Physics, false)
		Humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
	end)
end

updateCharacter()

--// Target Reposition
function ResetTargetReposition()
	TargetUnreachableSince   = nil
	TargetApproachPosition   = nil
	TargetApproachMob        = nil
	LastTargetRepositionTime = 0
	CAHCED_SAFECOMBAT_POSITION = nil
	LAST_SAFECOMBAT_TIME = 0
	LastDirectPathTarget = nil
	LastDirectPathPosition = nil
	CombatBladeCache = {}
end

--// Toggle Screen GUI
local ToggleScreenGUI
local ToggleContainer
local ToggleUIListLayout

function CreateToggleContainer()
	if not ToggleScreenGUI then
		ToggleScreenGUI = Instance.new("ScreenGui")
		ToggleScreenGUI.Name = "ToggleScreenGUI"
		ToggleScreenGUI.ResetOnSpawn = false
		ToggleScreenGUI.IgnoreGuiInset = true
		ToggleScreenGUI.Parent = PlayerGui
	end

	if not ToggleContainer then
		ToggleContainer = Instance.new("Frame")
		ToggleContainer.Name = "ToggleContainer"
		ToggleContainer.Size = UDim2.new(1, -10, 0, 48)
		ToggleContainer.Position = UDim2.fromOffset(0, 10)
		ToggleContainer.BackgroundTransparency = 1
		ToggleContainer.Parent = ToggleScreenGUI
	end

	if not ToggleUIListLayout then
		ToggleUIListLayout = Instance.new("UIListLayout")
		ToggleUIListLayout.Padding = UDim.new(0, 10)
		ToggleUIListLayout.FillDirection = Enum.FillDirection.Horizontal
		ToggleUIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
		ToggleUIListLayout.VerticalAlignment = Enum.VerticalAlignment.Center
		ToggleUIListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
		ToggleUIListLayout.Parent = ToggleContainer
	end
end
CreateToggleContainer()

local StaminaConnection = nil
function RegenStamina()
	task.spawn(function()
		local PlayerStats = Player:FindFirstChild("PlayerStats")
		if not PlayerStats then
			repeat task.wait(0.5) until Player:FindFirstChild("PlayerStats")
			PlayerStats = Player:FindFirstChild("PlayerStats")
		end
		local GameGui = PlayerGui:FindFirstChild("GameGui")
		if not GameGui then
			repeat task.wait(0.5) until PlayerGui:FindFirstChild("GameGui")
			GameGui = PlayerGui:FindFirstChild("GameGui")
		end
		local Stamina = GameGui:FindFirstChild("Stamina")
		local MaxStamina = PlayerStats:FindFirstChild("MaxStamina")
		if not Stamina then
			return
		end

		StaminaConnection = Stamina:GetPropertyChangedSignal("Value"):Connect(function()
			if Stamina.Value < MaxStamina.Value then
				Stamina.Value = MaxStamina.Value
			end
		end)
	end)
end
RegenStamina()

Player.CharacterAdded:Connect(function()
	task.wait()

	DEATH_COUNT += 1
	CONFIG.CURRENT_WAYPOINT_TARGET = 1
	CONFIG.CurrentCustomWaypoint = 1
	ClosestTarget = nil
	InputBindableFunction = nil
	BlockValue = nil
	Equipped = false
	RETREATING = false
	LAST_ATTACK_TIME = 0
	LAST_SKILL_TIME = 0
	LAST_CONSUME_TIME = 0
	LAST_INTERACTION_TIME = 0
	LAST_STUCK_POSITION = nil
	FaceAttachment = nil
	FaceOrientation = nil

	if StaminaConnection then
		StaminaConnection:Disconnect()
		StaminaConnection = nil
	end

	table.clear(ValidMobs)
	table.clear(CombatGroupCache)
	table.clear(CombatBladeCache)
	table.clear(BladePartCache)

	task.delay(0.5, function()
		Equipped = false
	end)

	updateCharacter()
	ResetTargetReposition()
	CreateToggleContainer()
	RegenStamina()
end)

local function AutoRefillBooster()
	task.spawn(function()
		local PlayerStats = Player:FindFirstChild("PlayerStats")
		if not PlayerStats then
			repeat task.wait(1) until Player:FindFirstChild("PlayerStats")
			PlayerStats = Player:FindFirstChild("PlayerStats")
		end
		local ExpBoost = PlayerStats:FindFirstChild("Boost")
		local DropBoost = PlayerStats:FindFirstChild("BoostDrops")
		ExpBoost:GetPropertyChangedSignal("Value"):Connect(function()
			if ExpBoost.Value == 0 then
				Humanoid.Health = 0
			end
		end)
		DropBoost:GetPropertyChangedSignal("Value"):Connect(function()
			if DropBoost.Value == 0 then
				Humanoid.Health = 0
			end
		end)
	end)
end
AutoRefillBooster()

--// UI
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AutoFarmUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
ScreenGui.Parent = PlayerGui

if IsValidPlace(game.PlaceId) then
	ScreenGui.DisplayOrder = 1
end

--// Theme
local Panel = Instance.new("Frame")
Panel.Name = "Panel"
Panel.AnchorPoint = Vector2.new(1, 0.5)
Panel.Size = UDim2.fromScale(0.25, 0.70)
Panel.Position = UDim2.fromScale(0.95, 0.55)
Panel.BackgroundColor3 = CONFIG.UI_PANEL
Panel.BorderSizePixel = 0
Panel.ClipsDescendants = true
Panel.Parent = ScreenGui

local PanelCorner = Instance.new("UICorner")
PanelCorner.CornerRadius = UDim.new(0, 1)
PanelCorner.Parent = Panel

local PanelStroke = Instance.new("UIStroke")
PanelStroke.Color = CONFIG.UI_BORDER
PanelStroke.Thickness = 1
PanelStroke.Transparency = 0.1
PanelStroke.Parent = Panel

--// Header
local Header = Instance.new("Frame")
Header.Name = "Header"
Header.Size = UDim2.fromScale(1, 0.1346)
Header.BackgroundColor3 = CONFIG.UI_SURFACE
Header.BorderSizePixel = 0
Header.Parent = Panel

local HeaderCorner = Instance.new("UICorner")
HeaderCorner.CornerRadius = UDim.new(0.25, 0)
HeaderCorner.Parent = Header

local HeaderMask = Instance.new("Frame")
HeaderMask.Size = UDim2.fromScale(1, 0.25)
HeaderMask.Position = UDim2.fromScale(0, 0)
HeaderMask.BackgroundColor3 = CONFIG.UI_SURFACE
HeaderMask.BorderSizePixel = 0
HeaderMask.Parent = Header

local Accent = Instance.new("Frame")
Accent.Size = UDim2.fromScale(0.0103, 0.6667)
Accent.Position = UDim2.fromScale(0.0359, 0.1667)
Accent.BackgroundColor3 = CONFIG.UI_ACCENT
Accent.BorderSizePixel = 0
Accent.Parent = Header

local AccentCorner = Instance.new("UICorner")
AccentCorner.CornerRadius = UDim.new(1, 0)
AccentCorner.Parent = Accent

local Title = Instance.new("TextLabel")
Title.Name = "Title"
Title.Size = UDim2.fromScale(0.8205, 0.3889)
Title.Position = UDim2.fromScale(0.0769, 0.1528)
Title.BackgroundTransparency = 1
Title.Text = "AUTO FARMING (F16)"
Title.TextColor3 = CONFIG.UI_TEXT
Title.TextScaled = true
Title.Font = Enum.Font.GothamBold
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.TextTruncate = Enum.TextTruncate.AtEnd
Title.Parent = Header

local PlaceNameLabel = Instance.new("TextLabel")
PlaceNameLabel.Name = "PlaceName"
PlaceNameLabel.Size = UDim2.fromScale(0.8205, 0.25)
PlaceNameLabel.Position = UDim2.fromScale(0.0769, 0.5556)
PlaceNameLabel.BackgroundTransparency = 1
PlaceNameLabel.Text = MarketplaceService:GetProductInfoAsync(game.PlaceId).Name .. "  •  " .. CONFIG.VERSION
PlaceNameLabel.TextColor3 = CONFIG.UI_MUTED
PlaceNameLabel.TextScaled = true
PlaceNameLabel.Font = Enum.Font.GothamMedium
PlaceNameLabel.TextXAlignment = Enum.TextXAlignment.Left
PlaceNameLabel.TextTruncate = Enum.TextTruncate.AtEnd
PlaceNameLabel.Parent = Header

local DragHint = Instance.new("TextLabel")
DragHint.Size = UDim2.fromScale(0.0821, 0.3889)
DragHint.Position = UDim2.fromScale(0.8897, 0.3056)
DragHint.BackgroundTransparency = 1
DragHint.Text = "⋮⋮"
DragHint.TextColor3 = CONFIG.UI_MUTED
DragHint.TextScaled = true
DragHint.Font = Enum.Font.GothamBold
DragHint.Parent = Header

--// Content
local Content = Instance.new("ScrollingFrame")
Content.Name = "Content"
Content.Size = UDim2.fromScale(0.9385, 0.843)
Content.Position = UDim2.fromScale(0.0308, 0.1458)
Content.BackgroundTransparency = 1
Content.BorderSizePixel = 0
Content.ScrollBarThickness = 3
Content.ScrollBarImageColor3 = CONFIG.UI_BORDER
Content.CanvasSize = UDim2.fromScale(0, 0)
Content.AutomaticCanvasSize = Enum.AutomaticSize.Y
Content.ScrollingDirection = Enum.ScrollingDirection.Y
Content.Parent = Panel

local ContentPadding = Instance.new("UIPadding")
ContentPadding.PaddingLeft = UDim.new(0.005, 0)
ContentPadding.PaddingRight = UDim.new(0.005, 0)
ContentPadding.PaddingBottom = UDim.new(0, 0)
ContentPadding.Parent = Content

local ContentLayout = Instance.new("UIListLayout")
ContentLayout.SortOrder = Enum.SortOrder.LayoutOrder
ContentLayout.Padding = UDim.new(0, 5)
ContentLayout.Parent = Content

--// Features
local FeaturesCollapsed = false

local FeaturesHeader = Instance.new("TextButton")
FeaturesHeader.Name = "FeaturesHeader"
FeaturesHeader.LayoutOrder = 1
FeaturesHeader.Size = UDim2.fromScale(0.9949, 0.0374)
FeaturesHeader.BackgroundTransparency = 1
FeaturesHeader.Text = "FEATURES  ▼"
FeaturesHeader.TextColor3 = CONFIG.UI_TEXT
FeaturesHeader.TextScaled = true
FeaturesHeader.Font = Enum.Font.GothamBold
FeaturesHeader.TextXAlignment = Enum.TextXAlignment.Left
FeaturesHeader.AutoButtonColor = false
FeaturesHeader.Parent = Content

local Features = Instance.new("Frame")
Features.Name = "Features"
Features.LayoutOrder = 2
Features.Size = UDim2.fromScale(0.9949, 0.19)
Features.BackgroundTransparency = 1
Features.Parent = Content

local FeaturesGrid = Instance.new("UIGridLayout")
FeaturesGrid.CellSize = UDim2.fromScale(0.5, 0.5)
FeaturesGrid.CellPadding = UDim2.fromScale(0, 0.005)
FeaturesGrid.SortOrder = Enum.SortOrder.LayoutOrder
FeaturesGrid.Parent = Features

function UpdateFeaturesLayout()
	if FeaturesCollapsed then
		return
	end

	local CardCount = 0

	for _, Child in Features:GetChildren() do
		if Child:IsA("GuiObject") and Child ~= FeaturesGrid then
			CardCount += 1
		end
	end

	if CardCount <= 0 then
		Features.Size = UDim2.fromScale(0.9949, 0)
		return
	end

	local ColumnCount = 2
	local RowCount    = math.ceil(CardCount / ColumnCount)
	local BaseHeight  = 0.12
	local PaddingY    = 0.005
	local FeaturesHeight = (BaseHeight * RowCount) + (PaddingY * (RowCount - 1))

	Features.Size = UDim2.fromScale(0.9949, FeaturesHeight)

	local CellHeight = BaseHeight / FeaturesHeight
	FeaturesGrid.CellSize = UDim2.fromScale(0.5, CellHeight)
	FeaturesGrid.CellPadding = UDim2.fromScale(0, PaddingY / FeaturesHeight)
end

function SetFeaturesCollapsed(Collapsed)
	FeaturesCollapsed = Collapsed
	Features.Visible = not Collapsed
	FeaturesHeader.Text = Collapsed and "FEATURES  ▶" or "FEATURES  ▼"

	if not Collapsed then
		UpdateFeaturesLayout()
	end
end

function CreateFeatureCard(Name, Order)
	local Card = Instance.new("Frame")
	Card.Name = Name
	Card.LayoutOrder = Order
	Card.BackgroundColor3 = CONFIG.UI_SURFACE
	Card.BorderSizePixel = 0
	Card.Parent = Features

	local Corner = Instance.new("UICorner")
	Corner.CornerRadius = UDim.new(0.02, 0)
	Corner.Parent = Card

	local Button = Instance.new("TextButton")
	Button.Name = "Toggle"
	Button.Size = UDim2.fromScale(0.94, 0.52)
	Button.Position = UDim2.fromScale(0.03, 0.08)
	Button.BackgroundColor3 = CONFIG.UI_HOVER
	Button.BorderSizePixel = 0
	Button.TextColor3 = CONFIG.UI_TEXT
	Button.TextScaled = true
	Button.Font = Enum.Font.GothamBold
	Button.AutoButtonColor = false
	Button.Parent = Card

	local ButtonCorner = Instance.new("UICorner")
	ButtonCorner.CornerRadius = UDim.new(0.12, 0)
	ButtonCorner.Parent = Button

	local Status = Instance.new("TextLabel")
	Status.Name = "Status"
	Status.Size = UDim2.fromScale(0.94, 0.24)
	Status.Position = UDim2.fromScale(0.03, 0.68)
	Status.BackgroundTransparency = 1
	Status.TextColor3 = CONFIG.UI_MUTED
	Status.TextScaled = true
	Status.Font = Enum.Font.GothamMedium
	Status.TextXAlignment = Enum.TextXAlignment.Left
	Status.TextTruncate = Enum.TextTruncate.AtEnd
	Status.Parent = Card

	return Button, Status
end

Feature.AutoFarm.Button, Feature.AutoFarm.Status = CreateFeatureCard("AutoFarm", 1)
Feature.AutoBlock.Button, Feature.AutoBlock.Status = CreateFeatureCard("AutoBlock", 2)
Feature.SafeCombat.Button, Feature.SafeCombat.Status = CreateFeatureCard("SafeCombat", 3)
Feature.AutoSkill.Button, Feature.AutoSkill.Status = CreateFeatureCard("AutoSkill", 4)
Feature.AutoFind.Button, Feature.AutoFind.Status = CreateFeatureCard("AutoFind", 5)
Feature.IgnoreFarmZone.Button, Feature.IgnoreFarmZone.Status = CreateFeatureCard("IgnoreFarmZone", 6)
Feature.AutoPatrol.Button, Feature.AutoPatrol.Status = CreateFeatureCard("AutoPatrol", 7)
Feature.ResetOnBoostOut.Button, Feature.ResetOnBoostOut.Status = CreateFeatureCard("ResetOnBoostOut", 8)
Feature.ResetStats.Button, Feature.ResetStats.Status = CreateFeatureCard("ResetStats", 9)
Feature.UseCustomPath.Button, Feature.UseCustomPath.Status = CreateFeatureCard("UseCustomPath", 10)
Feature.UseCustomFarmZone.Button, Feature.UseCustomFarmZone.Status = CreateFeatureCard("UseCustomFarmZone", 11)

FeaturesHeader.Activated:Connect(function()
	SetFeaturesCollapsed(not FeaturesCollapsed)
end)

UpdateFeaturesLayout()

Features.ChildAdded:Connect(function(Child)
	if Child:IsA("GuiObject") and Child ~= FeaturesGrid then
		task.defer(UpdateFeaturesLayout)
	end
end)

Features.ChildRemoved:Connect(function(Child)
	if Child:IsA("GuiObject") and Child ~= FeaturesGrid then
		task.defer(UpdateFeaturesLayout)
	end
end)

--// Live Status
local StatsCollapsed = false

local StatsHeader = Instance.new("TextButton")
StatsHeader.Name = "StatsHeader"
StatsHeader.LayoutOrder = 3
StatsHeader.Size = UDim2.fromScale(0.9949, 0.0374)
StatsHeader.BackgroundTransparency = 1
StatsHeader.Text = "LIVE STATUS  ▼"
StatsHeader.TextColor3 = CONFIG.UI_TEXT
StatsHeader.TextScaled = true
StatsHeader.Font = Enum.Font.GothamBold
StatsHeader.TextXAlignment = Enum.TextXAlignment.Left
StatsHeader.AutoButtonColor = false
StatsHeader.Parent = Content

local Stats = Instance.new("Frame")
Stats.Name = "Stats"
Stats.LayoutOrder = 4
Stats.Size = UDim2.fromScale(0.9949, 0.2766)
Stats.BackgroundTransparency = 1
Stats.Parent = Content

local StatsGrid = Instance.new("UIGridLayout")
StatsGrid.CellSize = UDim2.fromScale(0.5, 0.3108)
StatsGrid.CellPadding = UDim2.fromScale(0, 0.005)
StatsGrid.SortOrder = Enum.SortOrder.LayoutOrder
StatsGrid.Parent = Stats

function UpdateStatsLayout()
	if StatsCollapsed then
		return
	end

	local CardCount = 0

	for _, Child in Stats:GetChildren() do
		if Child:IsA("GuiObject") and Child ~= StatsGrid then
			CardCount += 1
		end
	end

	if CardCount <= 0 then
		Stats.Size = UDim2.fromScale(0.9949, 0)
		return
	end

	local ColumnCount = 2
	local RowCount    = math.ceil(CardCount / ColumnCount)

	local BaseHeight = 0.095
	local PaddingY   = 0.005

	local StatsHeight = (BaseHeight * RowCount) + (PaddingY * (RowCount - 1))

	Stats.Size = UDim2.fromScale(0.9949, StatsHeight)

	local CellHeight = BaseHeight / StatsHeight

	StatsGrid.CellSize    = UDim2.fromScale(0.5, CellHeight)
	StatsGrid.CellPadding = UDim2.fromScale(0, PaddingY / StatsHeight)
end

function SetStatsCollapsed(Collapsed)
	StatsCollapsed = Collapsed

	if StatsCollapsed then
		StatsHeader.Text = "LIVE STATUS  ▶"
		Stats.Visible = false
	else
		StatsHeader.Text = "LIVE STATUS  ▼"
		Stats.Visible = true
		UpdateStatsLayout()
	end
end

StatsHeader.Activated:Connect(function()
	SetStatsCollapsed(not StatsCollapsed)
end)

function CreateStat(Name, DefaultText, Order)
	local Card = Instance.new("Frame")
	Card.Name = Name
	Card.LayoutOrder = Order
	Card.BackgroundColor3 = CONFIG.UI_SURFACE
	Card.BorderSizePixel = 0
	Card.Parent = Stats

	local Corner = Instance.new("UICorner")
	Corner.CornerRadius = UDim.new(0.02, 0)
	Corner.Parent = Card

	local Label = Instance.new("TextLabel")
	Label.Name = "Label"
	Label.Size = UDim2.fromScale(0.9158, 0.2826)
	Label.Position = UDim2.fromScale(0.0421, 0.1087)
	Label.BackgroundTransparency = 1
	Label.Text = Name
	Label.TextColor3 = CONFIG.UI_MUTED
	Label.TextScaled = true
	Label.Font = Enum.Font.GothamMedium
	Label.TextXAlignment = Enum.TextXAlignment.Left
	Label.Parent = Card

	local Value = Instance.new("TextLabel")
	Value.Name = "Value"
	Value.Size = UDim2.fromScale(0.9158, 0.4130)
	Value.Position = UDim2.fromScale(0.0421, 0.4348)
	Value.BackgroundTransparency = 1
	Value.Text = DefaultText
	Value.TextColor3 = CONFIG.UI_TEXT
	Value.TextScaled = true
	Value.Font = Enum.Font.GothamBold
	Value.TextXAlignment = Enum.TextXAlignment.Left
	Value.TextTruncate = Enum.TextTruncate.AtEnd
	Value.Parent = Card

	return Value
end

function neededExp(lvl)
	lvl = lvl - 1

	local total = 9

	for i = 1, lvl do
		total = total + (6 * (i + 2))
	end

	return total
end

local PlaceIDLabel       = CreateStat("PLACE ID", tostring(game.PlaceId), 1)
local WalkSpeedLabel     = CreateStat("WALKSPEED", "0", 2)
local WayPointLabel      = CreateStat("WAYPOINT", "0/" .. (IsValidPlace(game.PlaceId) and #IsValidPlace(game.PlaceId).WAYPOINTS or 0) , 3)
local EventCurrencyLabel = CreateStat("EVENT CURRENCY", "0", 4)
local ServerAgeLabel     = CreateStat("PLAY TIME", "00:00:00", 5)
local PositionLabel      = CreateStat("POSITION", "--", 6)
local DeathLabel         = CreateStat("DEATH", "0", 7)
local ExpLabel           = CreateStat("EXP", "0/0", 8)

UpdateStatsLayout()

Stats.ChildAdded:Connect(function(Child)
	if Child:IsA("GuiObject") and Child ~= StatsGrid then
		task.defer(UpdateStatsLayout)
	end
end)

Stats.ChildRemoved:Connect(function(Child)
	if Child:IsA("GuiObject") and Child ~= StatsGrid then
		task.defer(UpdateStatsLayout)
	end
end)

--// Enemy Priority
local PriorityHeader = Instance.new("TextLabel")
PriorityHeader.Name = "PriorityHeader"
PriorityHeader.LayoutOrder = 7
PriorityHeader.Size = UDim2.fromScale(0.9949, 0.0374)
PriorityHeader.BackgroundTransparency = 1
PriorityHeader.Text = "ENEMY PRIORITY"
PriorityHeader.TextColor3 = CONFIG.UI_TEXT
PriorityHeader.TextScaled = true
PriorityHeader.Font = Enum.Font.GothamBold
PriorityHeader.TextXAlignment = Enum.TextXAlignment.Left
PriorityHeader.Parent = Content

local PriorityHint = Instance.new("TextLabel")
PriorityHint.Name = "PriorityHint"
PriorityHint.LayoutOrder = 8
PriorityHint.Size = UDim2.fromScale(0.9949, 0.0318)
PriorityHint.BackgroundTransparency = 1
PriorityHint.Text = "▲ / ▼   Change targeting order"
PriorityHint.TextColor3 = CONFIG.UI_MUTED
PriorityHint.TextScaled = true
PriorityHint.Font = Enum.Font.GothamMedium
PriorityHint.TextXAlignment = Enum.TextXAlignment.Left
PriorityHint.Parent = Content

local PriorityRows = {}

local AddEnemyButton
local EnemyPicker
local EnemyPickerList
local EnemyPickerListLayout
local EnemyPickerPadding


function IsEntityInPriority(EntityName: string): boolean
	for _, PriorityName in ipairs(CONFIG.TARGET_ENTITY_PRIORITY) do
		if PriorityName == EntityName then
			return true
		end
	end

	return false
end

function CreatePriorityRow(Index)
	local Row = Instance.new("Frame")
	Row.Name = "Priority" .. Index
	Row.LayoutOrder = 8 + Index
	Row.Size = UDim2.fromScale(0.9949, 0.0822)
	Row.BackgroundColor3 = CONFIG.UI_SURFACE
	Row.BorderSizePixel = 0
	Row.Parent = Content

	local RowCorner = Instance.new("UICorner")
	RowCorner.CornerRadius = UDim.new(0.02, 0)
	RowCorner.Parent = Row

	local NumberLabel = Instance.new("TextLabel")
	NumberLabel.Name = "Number"
	NumberLabel.Size = UDim2.fromScale(0.0872, 1)
	NumberLabel.Position = UDim2.fromScale(0.0205, 0)
	NumberLabel.BackgroundTransparency = 1
	NumberLabel.TextColor3 = CONFIG.UI_ACCENT
	NumberLabel.TextScaled = true
	NumberLabel.Font = Enum.Font.GothamBold
	NumberLabel.TextXAlignment = Enum.TextXAlignment.Center
	NumberLabel.Parent = Row

	local NameLabel = Instance.new("TextLabel")
	NameLabel.Name = "Name"
	NameLabel.Size = UDim2.fromScale(0.5687, 1)
	NameLabel.Position = UDim2.fromScale(0.1231, 0)
	NameLabel.BackgroundTransparency = 1
	NameLabel.TextColor3 = CONFIG.UI_TEXT
	NameLabel.TextSize = 14
	NameLabel.Font = Enum.Font.GothamMedium
	NameLabel.TextXAlignment = Enum.TextXAlignment.Left
	NameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	NameLabel.Parent = Row

	local RemoveButton = Instance.new("TextButton")
	RemoveButton.Name = "Remove"
	RemoveButton.Size = UDim2.fromScale(0.0821, 0.6818)
	RemoveButton.Position = UDim2.fromScale(0.708, 0.1591)
	RemoveButton.BackgroundColor3 = CONFIG.UI_HOVER
	RemoveButton.BorderSizePixel = 0
	RemoveButton.Text = "×"
	RemoveButton.TextColor3 = CONFIG.UI_TEXT
	RemoveButton.TextScaled = true
	RemoveButton.Font = Enum.Font.GothamBold
	RemoveButton.AutoButtonColor = true
	RemoveButton.Parent = Row

	local RemoveCorner = Instance.new("UICorner")
	RemoveCorner.CornerRadius = UDim.new(0.159, 0)
	RemoveCorner.Parent = RemoveButton

	local UpButton = Instance.new("TextButton")
	UpButton.Name = "Up"
	UpButton.Size = UDim2.fromScale(0.0821, 0.6818)
	UpButton.Position = UDim2.fromScale(0.8051, 0.1591)
	UpButton.BackgroundColor3 = CONFIG.UI_HOVER
	UpButton.BorderSizePixel = 0
	UpButton.Text = "▲"
	UpButton.TextColor3 = CONFIG.UI_TEXT
	UpButton.TextScaled = true
	UpButton.Font = Enum.Font.GothamBold
	UpButton.AutoButtonColor = true
	UpButton.Parent = Row

	local UpCorner = Instance.new("UICorner")
	UpCorner.CornerRadius = UDim.new(0.159, 0)
	UpCorner.Parent = UpButton

	local DownButton = Instance.new("TextButton")
	DownButton.Name = "Down"
	DownButton.Size = UDim2.fromScale(0.0821, 0.6818)
	DownButton.Position = UDim2.fromScale(0.9026, 0.1591)
	DownButton.BackgroundColor3 = CONFIG.UI_HOVER
	DownButton.BorderSizePixel = 0
	DownButton.Text = "▼"
	DownButton.TextColor3 = CONFIG.UI_TEXT
	DownButton.TextScaled = true
	DownButton.Font = Enum.Font.GothamBold
	DownButton.AutoButtonColor = true
	DownButton.Parent = Row

	local DownCorner = Instance.new("UICorner")
	DownCorner.CornerRadius = UDim.new(0.159, 0)
	DownCorner.Parent = DownButton

	PriorityRows[Index] = {
		Row    = Row,
		Number = NumberLabel,
		Name   = NameLabel,
		Remove = RemoveButton,
		Up     = UpButton,
		Down   = DownButton,
	}

	RemoveButton.Activated:Connect(function()
		if not CONFIG.TARGET_ENTITY_PRIORITY[Index] then
			return
		end

		local WasPickerVisible = EnemyPicker.Visible

		table.remove(CONFIG.TARGET_ENTITY_PRIORITY, Index)

		ClosestTarget = nil
		table.clear(ValidMobs)
		table.clear(CombatGroupCache)

		for _, RowData in PriorityRows do
			RowData.Row:Destroy()
		end

		table.clear(PriorityRows)

		for NewIndex = 1, #CONFIG.TARGET_ENTITY_PRIORITY do
			CreatePriorityRow(NewIndex)
		end

		AddEnemyButton.LayoutOrder = 9 + #CONFIG.TARGET_ENTITY_PRIORITY
		EnemyPicker.LayoutOrder = 10 + #CONFIG.TARGET_ENTITY_PRIORITY

		updatePriorityUI()

		if WasPickerVisible then
			EnemyPicker.Visible = true
			RefreshEnemyPicker()
		end
	end)

	UpButton.Activated:Connect(function()
		if Index <= 1 then
			return
		end

		CONFIG.TARGET_ENTITY_PRIORITY[Index], CONFIG.TARGET_ENTITY_PRIORITY[Index - 1] =
			CONFIG.TARGET_ENTITY_PRIORITY[Index - 1], CONFIG.TARGET_ENTITY_PRIORITY[Index]

		ClosestTarget = nil
		table.clear(ValidMobs)
		table.clear(CombatGroupCache)

		updatePriorityUI()

		if EnemyPicker.Visible then
			RefreshEnemyPicker()
		end
	end)

	DownButton.Activated:Connect(function()
		if Index >= #CONFIG.TARGET_ENTITY_PRIORITY then
			return
		end

		CONFIG.TARGET_ENTITY_PRIORITY[Index], CONFIG.TARGET_ENTITY_PRIORITY[Index + 1] =
			CONFIG.TARGET_ENTITY_PRIORITY[Index + 1], CONFIG.TARGET_ENTITY_PRIORITY[Index]

		ClosestTarget = nil
		table.clear(ValidMobs)
		table.clear(CombatGroupCache)

		updatePriorityUI()

		if EnemyPicker.Visible then
			RefreshEnemyPicker()
		end
	end)
end

function updatePriorityUI()
	for Index, RowData in PriorityRows do
		RowData.Number.Text = tostring(Index)
		RowData.Name.Text = CONFIG.TARGET_ENTITY_PRIORITY[Index] or "--"

		local IsFirst = Index == 1
		local IsLast  = Index == #CONFIG.TARGET_ENTITY_PRIORITY

		RowData.Up.Active = not IsFirst
		RowData.Down.Active = not IsLast

		RowData.Up.TextTransparency = IsFirst and 0.65 or 0
		RowData.Down.TextTransparency = IsLast and 0.65 or 0
	end
end

for Index = 1, #CONFIG.TARGET_ENTITY_PRIORITY do
	CreatePriorityRow(Index)
end

updatePriorityUI()

--// Add Enemy
AddEnemyButton = Instance.new("TextButton")
AddEnemyButton.Name = "AddEnemy"
AddEnemyButton.LayoutOrder = 9 + #CONFIG.TARGET_ENTITY_PRIORITY
AddEnemyButton.Size = UDim2.fromScale(0.9949, 0.0785)
AddEnemyButton.BackgroundColor3 = CONFIG.UI_SURFACE
AddEnemyButton.BorderSizePixel = 0
AddEnemyButton.Text = "+  ADD ENEMY TO PRIORITY"
AddEnemyButton.TextColor3 = CONFIG.UI_TEXT
AddEnemyButton.TextScaled = true
AddEnemyButton.Font = Enum.Font.GothamBold
AddEnemyButton.AutoButtonColor = true
AddEnemyButton.Parent = Content

local AddEnemyCorner = Instance.new("UICorner")
AddEnemyCorner.CornerRadius = UDim.new(0.205, 0)
AddEnemyCorner.Parent = AddEnemyButton

local AddEnemyStroke = Instance.new("UIStroke")
AddEnemyStroke.Color = CONFIG.UI_BORDER
AddEnemyStroke.Thickness = 1
AddEnemyStroke.Transparency = 0.3
AddEnemyStroke.Parent = AddEnemyButton

--// Enemy Picker
EnemyPicker = Instance.new("Frame")
EnemyPicker.Name = "EnemyPicker"
EnemyPicker.LayoutOrder = 10 + #CONFIG.TARGET_ENTITY_PRIORITY
EnemyPicker.Size = UDim2.fromScale(0.9949, 0)
EnemyPicker.BackgroundColor3 = CONFIG.UI_SURFACE
EnemyPicker.BorderSizePixel = 0
EnemyPicker.Visible = false
EnemyPicker.ClipsDescendants = true
EnemyPicker.Parent = Content

local EnemyPickerCorner = Instance.new("UICorner")
EnemyPickerCorner.CornerRadius = UDim.new(0.02, 0)
EnemyPickerCorner.Parent = EnemyPicker

local EnemyPickerStroke = Instance.new("UIStroke")
EnemyPickerStroke.Color = CONFIG.UI_BORDER
EnemyPickerStroke.Thickness = 1
EnemyPickerStroke.Transparency = 0.2
EnemyPickerStroke.Parent = EnemyPicker

EnemyPickerList = Instance.new("Frame")
EnemyPickerList.Name = "List"
EnemyPickerList.Size = UDim2.fromScale(0.958, 1)
EnemyPickerList.Position = UDim2.fromScale(0.021, 0)
EnemyPickerList.BackgroundTransparency = 1
EnemyPickerList.BorderSizePixel = 0
EnemyPickerList.Parent = EnemyPicker

EnemyPickerListLayout = Instance.new("UIGridLayout")
EnemyPickerListLayout.CellSize = UDim2.fromScale(1, 1)
EnemyPickerListLayout.CellPadding = UDim2.fromScale(0, 0.005)
EnemyPickerListLayout.SortOrder = Enum.SortOrder.LayoutOrder
EnemyPickerListLayout.Parent = EnemyPickerList

EnemyPickerPadding = Instance.new("UIPadding")
EnemyPickerPadding.PaddingLeft = UDim.new(0, 5)
EnemyPickerPadding.PaddingRight = UDim.new(0, 5)
EnemyPickerPadding.Parent = EnemyPickerList

function GetItem(String, ItemName)
	for Item in string.gmatch(String, "([^,]+)") do
		local Name, Amount = string.match(Item, "([^|]+)|(.+)")

		if Name == ItemName then
			return Name, tonumber(Amount) or 0
		end
	end

	return ItemName, 0
end

function updateEventCurrency()
	local PlayerStats = Player:FindFirstChild("PlayerStats")

	if not PlayerStats then
		EventCurrency = 0
		EventCurrencyLabel.Text = "0"
		ExpLabel.Text = "0/0"
		LastInventory = nil
		return
	end

	local PlayerLvl = PlayerStats:FindFirstChild("Level")
	local PlayerExp = PlayerStats:FindFirstChild("EXP")

	if PlayerLvl and PlayerExp then
		ExpLabel.Text = PlayerExp.Value .. "/" .. neededExp(PlayerLvl.Value)
	else
		ExpLabel.Text = "0/0"
	end

	local Inventory = PlayerStats:FindFirstChild("Inventory")

	if not Inventory then
		EventCurrency = 0
		EventCurrencyLabel.Text = "0"
		return
	end

	local InventoryValue = Inventory.Value

	if InventoryValue == LastInventory then
		return
	end

	LastInventory = InventoryValue

	local _, Amount = GetItem(InventoryValue, TargetCurrency)

	EventCurrency = Amount
	EventCurrencyLabel.Text = tostring(EventCurrency)
end

function updatePlayTime()
	local ServerAge = math.floor(workspace.DistributedGameTime)

	local Hours   = math.floor(ServerAge / 3600)
	local Minutes = math.floor((ServerAge % 3600) / 60)
	local Seconds = ServerAge % 60

	ServerAgeLabel.Text = string.format("%02d:%02d:%02d", Hours, Minutes, Seconds)
end

function updatePosition()
	if RootPart then
		local Position = RootPart.Position

		PositionLabel.Text = string.format(
			"%.1f, %.1f, %.1f",
			Position.X,
			Position.Y,
			Position.Z
		)
	else
		PositionLabel.Text = "--"
	end
end

--// Detected Entity List
local DetectedEntities = {}

function GetDetectedEnemyEntities()
	local MobFolder = workspace:FindFirstChild("Mobs")

	if not MobFolder then
		return {}
	end

	local EntitySet = {}

	for _, Mob in MobFolder:GetChildren() do
		if not Mob:IsA("Model") then
			continue
		end

		local Config = Mob:FindFirstChild("Config")

		if not Config then
			continue
		end

		local Entity = Config:FindFirstChild("Entity")

		if not Entity then
			continue
		end

		if typeof(Entity.Value) ~= "string" then
			continue
		end

		if Entity.Value == "" then
			continue
		end

		EntitySet[Entity.Value] = true
	end

	local Result = {}

	for EntityName in EntitySet do
		table.insert(Result, EntityName)
	end

	table.sort(Result, function(A, B)
		local APriority = table.find(CONFIG.TARGET_ENTITY_PRIORITY, A)
		local BPriority = table.find(CONFIG.TARGET_ENTITY_PRIORITY, B)

		if APriority and BPriority then
			return APriority < BPriority
		end

		if APriority then
			return true
		end

		if BPriority then
			return false
		end

		return A < B
	end)

	return Result
end

--// Auto Scale Enemy Picker
function UpdateEnemyPickerLayout()
	local CardCount = 0

	for _, Child in EnemyPickerList:GetChildren() do
		if Child:IsA("GuiObject") and Child ~= EnemyPickerListLayout then
			CardCount += 1
		end
	end

	if CardCount <= 0 then
		EnemyPicker.Size = UDim2.fromScale(0.9949, 0)
		return
	end

	local ColumnCount = 1
	local RowCount    = math.ceil(CardCount / ColumnCount)
	local BaseHeight  = 0.0822
	local PaddingY    = 0.005

	local EnemyPickerHeight = (BaseHeight * RowCount) + (PaddingY * (RowCount - 1))

	EnemyPicker.Size = UDim2.fromScale(0.9949, EnemyPickerHeight)
	EnemyPickerList.Size = UDim2.fromScale(0.958, 1)

	local CellHeight = BaseHeight / EnemyPickerHeight

	EnemyPickerListLayout.CellSize = UDim2.fromScale(1, CellHeight)
	EnemyPickerListLayout.CellPadding = UDim2.fromScale(0, PaddingY / EnemyPickerHeight)
end

function CreateEnemyPickerRow(EntityName, Index)
	local Row = Instance.new("TextButton")
	Row.Name = "Enemy_" .. EntityName
	Row.LayoutOrder = Index
	Row.Size = UDim2.fromScale(1, 0.0822)
	Row.BackgroundColor3 = CONFIG.UI_PANEL
	Row.BorderSizePixel = 0
	Row.Text = ""
	Row.AutoButtonColor = false
	Row.Parent = EnemyPickerList

	local RowCorner = Instance.new("UICorner")
	RowCorner.CornerRadius = UDim.new(0.02, 0)
	RowCorner.Parent = Row

	local NameLabel = Instance.new("TextLabel")
	NameLabel.Name = "Name"
	NameLabel.Size = UDim2.fromScale(0.68, 1)
	NameLabel.Position = UDim2.fromScale(0.025, 0)
	NameLabel.BackgroundTransparency = 1
	NameLabel.Text = EntityName
	NameLabel.TextColor3 = CONFIG.UI_TEXT
	NameLabel.TextScaled = false
	NameLabel.TextSize = 14
	NameLabel.Font = Enum.Font.GothamMedium
	NameLabel.TextXAlignment = Enum.TextXAlignment.Left
	NameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	NameLabel.Parent = Row

	local IsPriority = IsEntityInPriority(EntityName)

	local ActionLabel = Instance.new("TextLabel")
	ActionLabel.Name = "Action"
	ActionLabel.Size = UDim2.fromScale(0.265, 1)
	ActionLabel.Position = UDim2.fromScale(0.71, 0)
	ActionLabel.BackgroundTransparency = 1
	ActionLabel.Text = IsPriority and "✓  IN PRIORITY" or "+  ADD"
	ActionLabel.TextColor3 = IsPriority and CONFIG.UI_MUTED or CONFIG.UI_ACCENT
	ActionLabel.TextScaled = true
	ActionLabel.Font = Enum.Font.GothamBold
	ActionLabel.TextXAlignment = Enum.TextXAlignment.Right
	ActionLabel.Parent = Row

	Row.MouseEnter:Connect(function()
		Row.BackgroundColor3 = CONFIG.UI_HOVER
	end)

	Row.MouseLeave:Connect(function()
		Row.BackgroundColor3 = CONFIG.UI_PANEL
	end)

	Row.Activated:Connect(function()
		if IsEntityInPriority(EntityName) then
			return
		end

		table.insert(CONFIG.TARGET_ENTITY_PRIORITY, EntityName)

		ClosestTarget = nil
		table.clear(ValidMobs)

		for _, RowData in PriorityRows do
			RowData.Row:Destroy()
		end

		table.clear(PriorityRows)

		for NewIndex = 1, #CONFIG.TARGET_ENTITY_PRIORITY do
			CreatePriorityRow(NewIndex)
		end

		AddEnemyButton.LayoutOrder = 9 + #CONFIG.TARGET_ENTITY_PRIORITY
		EnemyPicker.LayoutOrder = 10 + #CONFIG.TARGET_ENTITY_PRIORITY

		updatePriorityUI()
		RefreshEnemyPicker()
	end)

	UpdateEnemyPickerLayout()
end

function ClearEnemyPicker()
	for _, Child in EnemyPickerList:GetChildren() do
		if Child:IsA("GuiObject") and Child ~= EnemyPickerListLayout then
			Child:Destroy()
		end
	end
end

function RefreshEnemyPicker()
	if not EnemyPicker.Visible then
		return
	end

	ClearEnemyPicker()

	DetectedEntities = GetDetectedEnemyEntities()

	for Index, EntityName in ipairs(DetectedEntities) do
		CreateEnemyPickerRow(EntityName, Index)
	end

	task.defer(UpdateEnemyPickerLayout)
end

AddEnemyButton.Activated:Connect(function()
	EnemyPicker.Visible = not EnemyPicker.Visible

	if EnemyPicker.Visible then
		RefreshEnemyPicker()
	else
		EnemyPicker.Size = UDim2.fromScale(0.9949, 0)
	end
end)

-- ============================================================
-- PATH EDITOR + CONFIG PROFILES UI
-- ============================================================

function rebuildPriorityRows()
	for _, RowData in PriorityRows do
		if RowData.Row then RowData.Row:Destroy() end
	end
	table.clear(PriorityRows)
	for NewIndex = 1, #CONFIG.TARGET_ENTITY_PRIORITY do
		CreatePriorityRow(NewIndex)
	end
	AddEnemyButton.LayoutOrder = 9 + #CONFIG.TARGET_ENTITY_PRIORITY
	EnemyPicker.LayoutOrder = 10 + #CONFIG.TARGET_ENTITY_PRIORITY
	updatePriorityUI()
end

local PathHeader = Instance.new("TextLabel")
PathHeader.Name = "PathHeader"
PathHeader.LayoutOrder = 20
PathHeader.Size = UDim2.fromScale(0.9949, 0.0374)
PathHeader.BackgroundTransparency = 1
PathHeader.Text = "CUSTOM PATH EDITOR"
PathHeader.TextColor3 = CONFIG.UI_TEXT
PathHeader.TextScaled = true
PathHeader.Font = Enum.Font.GothamBold
PathHeader.TextXAlignment = Enum.TextXAlignment.Left
PathHeader.Parent = Content

local PathHint = Instance.new("TextLabel")
PathHint.Name = "PathHint"
PathHint.LayoutOrder = 21
PathHint.Size = UDim2.fromScale(0.9949, 0.0318)
PathHint.BackgroundTransparency = 1
PathHint.Text = "Record coords • set Interact on doors/warps"
PathHint.TextColor3 = CONFIG.UI_MUTED
PathHint.TextScaled = true
PathHint.Font = Enum.Font.GothamMedium
PathHint.TextXAlignment = Enum.TextXAlignment.Left
PathHint.Parent = Content

local PathToolbar = Instance.new("Frame")
PathToolbar.Name = "PathToolbar"
PathToolbar.LayoutOrder = 22
PathToolbar.Size = UDim2.fromScale(0.9949, 0.07)
PathToolbar.BackgroundTransparency = 1
PathToolbar.Parent = Content

local PathToolbarLayout = Instance.new("UIListLayout")
PathToolbarLayout.FillDirection = Enum.FillDirection.Horizontal
PathToolbarLayout.Padding = UDim.new(0.02, 0)
PathToolbarLayout.SortOrder = Enum.SortOrder.LayoutOrder
PathToolbarLayout.Parent = PathToolbar

local function makePathToolBtn(text, order)
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromScale(0.23, 1)
	b.LayoutOrder = order
	b.BackgroundColor3 = CONFIG.UI_SURFACE
	b.BorderSizePixel = 0
	b.Text = text
	b.TextColor3 = CONFIG.UI_TEXT
	b.TextScaled = true
	b.Font = Enum.Font.GothamBold
	b.AutoButtonColor = true
	b.Parent = PathToolbar
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0.15, 0)
	c.Parent = b
	return b
end

local RecordBtn = makePathToolBtn("📍 RECORD", 1)
local ClearPathBtn = makePathToolBtn("CLEAR", 2)
local SaveCfgBtn = makePathToolBtn("SAVE CFG", 3)
local LoadCfgBtn = makePathToolBtn("LOAD CFG", 4)

local PathListFrame = Instance.new("Frame")
PathListFrame.Name = "PathList"
PathListFrame.LayoutOrder = 23
PathListFrame.Size = UDim2.fromScale(0.9949, 0)
PathListFrame.BackgroundTransparency = 1
PathListFrame.Parent = Content

local PathListLayout = Instance.new("UIListLayout")
PathListLayout.SortOrder = Enum.SortOrder.LayoutOrder
PathListLayout.Padding = UDim.new(0, 4)
PathListLayout.Parent = PathListFrame

ProfileStatusLabel = Instance.new("TextLabel")
ProfileStatusLabel.Name = "ProfileStatus"
ProfileStatusLabel.LayoutOrder = 24
ProfileStatusLabel.Size = UDim2.fromScale(0.9949, 0.03)
ProfileStatusLabel.BackgroundTransparency = 1
ProfileStatusLabel.Text = "Profile: " .. CURRENT_PROFILE_NAME
ProfileStatusLabel.TextColor3 = CONFIG.UI_MUTED
ProfileStatusLabel.TextScaled = true
ProfileStatusLabel.Font = Enum.Font.GothamMedium
ProfileStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
ProfileStatusLabel.Parent = Content

-- ============================================================
-- CUSTOM FARM ZONE UI
-- ============================================================

local FarmHeader = Instance.new("TextLabel")
FarmHeader.Name = "FarmHeader"
FarmHeader.LayoutOrder = 25
FarmHeader.Size = UDim2.fromScale(0.9949, 0.0374)
FarmHeader.BackgroundTransparency = 1
FarmHeader.Text = "CUSTOM FARM ZONE"
FarmHeader.TextColor3 = CONFIG.UI_TEXT
FarmHeader.TextScaled = true
FarmHeader.Font = Enum.Font.GothamBold
FarmHeader.TextXAlignment = Enum.TextXAlignment.Left
FarmHeader.Parent = Content

local FarmHint = Instance.new("TextLabel")
FarmHint.Name = "FarmHint"
FarmHint.LayoutOrder = 26
FarmHint.Size = UDim2.fromScale(0.9949, 0.0318)
FarmHint.BackgroundTransparency = 1
FarmHint.Text = "Set center where you stand • adjust radius / deadzone"
FarmHint.TextColor3 = CONFIG.UI_MUTED
FarmHint.TextScaled = true
FarmHint.Font = Enum.Font.GothamMedium
FarmHint.TextXAlignment = Enum.TextXAlignment.Left
FarmHint.Parent = Content

local FarmToolbar = Instance.new("Frame")
FarmToolbar.Name = "FarmToolbar"
FarmToolbar.LayoutOrder = 27
FarmToolbar.Size = UDim2.fromScale(0.9949, 0.07)
FarmToolbar.BackgroundTransparency = 1
FarmToolbar.Parent = Content

local FarmToolbarLayout = Instance.new("UIListLayout")
FarmToolbarLayout.FillDirection = Enum.FillDirection.Horizontal
FarmToolbarLayout.Padding = UDim.new(0.02, 0)
FarmToolbarLayout.SortOrder = Enum.SortOrder.LayoutOrder
FarmToolbarLayout.Parent = FarmToolbar

local function makeFarmBtn(text, order)
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromScale(0.31, 1)
	b.LayoutOrder = order
	b.BackgroundColor3 = CONFIG.UI_SURFACE
	b.BorderSizePixel = 0
	b.Text = text
	b.TextColor3 = CONFIG.UI_TEXT
	b.TextScaled = true
	b.Font = Enum.Font.GothamBold
	b.AutoButtonColor = true
	b.Parent = FarmToolbar
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0.15, 0)
	c.Parent = b
	return b
end

local SetCenterBtn = makeFarmBtn("📍 SET CENTER", 1)
local SetDeadzoneBtn = makeFarmBtn("⛔ DEADZONE", 2)
local ClearFarmBtn = makeFarmBtn("CLEAR", 3)

local FarmInfoLabel = Instance.new("TextLabel")
FarmInfoLabel.Name = "FarmInfo"
FarmInfoLabel.LayoutOrder = 28
FarmInfoLabel.Size = UDim2.fromScale(0.9949, 0.055)
FarmInfoLabel.BackgroundColor3 = CONFIG.UI_SURFACE
FarmInfoLabel.BorderSizePixel = 0
FarmInfoLabel.Text = "Center: --  |  R: 200  |  Deadzone: --"
FarmInfoLabel.TextColor3 = CONFIG.UI_TEXT
FarmInfoLabel.TextScaled = true
FarmInfoLabel.Font = Enum.Font.GothamMedium
FarmInfoLabel.Parent = Content
local FarmInfoCorner = Instance.new("UICorner")
FarmInfoCorner.CornerRadius = UDim.new(0.08, 0)
FarmInfoCorner.Parent = FarmInfoLabel

local FarmRadiusBar = Instance.new("Frame")
FarmRadiusBar.Name = "FarmRadiusBar"
FarmRadiusBar.LayoutOrder = 29
FarmRadiusBar.Size = UDim2.fromScale(0.9949, 0.055)
FarmRadiusBar.BackgroundTransparency = 1
FarmRadiusBar.Parent = Content

local FarmRadiusLayout = Instance.new("UIListLayout")
FarmRadiusLayout.FillDirection = Enum.FillDirection.Horizontal
FarmRadiusLayout.Padding = UDim.new(0.02, 0)
FarmRadiusLayout.Parent = FarmRadiusBar

local function makeRadiusBtn(text, order)
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromScale(0.23, 1)
	b.LayoutOrder = order
	b.BackgroundColor3 = CONFIG.UI_SURFACE
	b.BorderSizePixel = 0
	b.Text = text
	b.TextColor3 = CONFIG.UI_TEXT
	b.TextScaled = true
	b.Font = Enum.Font.GothamBold
	b.Parent = FarmRadiusBar
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0.15, 0)
	c.Parent = b
	return b
end

local RadiusMinus = makeRadiusBtn("R -25", 1)
local RadiusPlus = makeRadiusBtn("R +25", 2)
local DzMinus = makeRadiusBtn("DZ -5", 3)
local DzPlus = makeRadiusBtn("DZ +5", 4)

function UpdateFarmInfoLabel()
	local c = CONFIG.CustomFarmCenter
	local d = CONFIG.CustomDeadzoneCenter
	local cs = c and string.format("%.0f,%.0f,%.0f", c.X, c.Y, c.Z) or "--"
	local ds = d and string.format("%.0f,%.0f,%.0f", d.X, d.Y, d.Z) or "--"
	FarmInfoLabel.Text = string.format(
		"Center: %s  |  R: %d  |  DZ: %s r=%d",
		cs,
		CONFIG.CustomFarmRadius or 200,
		ds,
		CONFIG.CustomDeadzoneRadius or 0
	)
end

SetCenterBtn.Activated:Connect(function()
	if not RootPart then return end
	CONFIG.CustomFarmCenter = RootPart.Position
	Feature.UseCustomFarmZone.Enabled = true
	CONFIG.UseCustomFarmZone = true
	UpdateFarmInfoLabel()
	updateFeatureButtons()
	if ProfileStatusLabel then ProfileStatusLabel.Text = "Farm center set" end
end)

SetDeadzoneBtn.Activated:Connect(function()
	if not RootPart then return end
	CONFIG.CustomDeadzoneCenter = RootPart.Position
	if not CONFIG.CustomDeadzoneRadius or CONFIG.CustomDeadzoneRadius <= 0 then
		CONFIG.CustomDeadzoneRadius = 35
	end
	UpdateFarmInfoLabel()
	if ProfileStatusLabel then ProfileStatusLabel.Text = "Deadzone center set" end
end)

ClearFarmBtn.Activated:Connect(function()
	CONFIG.CustomFarmCenter = nil
	CONFIG.CustomDeadzoneCenter = nil
	CONFIG.CustomFarmRadius = 200
	CONFIG.CustomDeadzoneRadius = 35
	Feature.UseCustomFarmZone.Enabled = false
	CONFIG.UseCustomFarmZone = false
	UpdateFarmInfoLabel()
	updateFeatureButtons()
	if ProfileStatusLabel then ProfileStatusLabel.Text = "Custom farm cleared" end
end)

RadiusMinus.Activated:Connect(function()
	CONFIG.CustomFarmRadius = math.max(25, (CONFIG.CustomFarmRadius or 200) - 25)
	UpdateFarmInfoLabel()
end)
RadiusPlus.Activated:Connect(function()
	CONFIG.CustomFarmRadius = math.min(500, (CONFIG.CustomFarmRadius or 200) + 25)
	UpdateFarmInfoLabel()
end)
DzMinus.Activated:Connect(function()
	CONFIG.CustomDeadzoneRadius = math.max(0, (CONFIG.CustomDeadzoneRadius or 35) - 5)
	UpdateFarmInfoLabel()
end)
DzPlus.Activated:Connect(function()
	CONFIG.CustomDeadzoneRadius = math.min(150, (CONFIG.CustomDeadzoneRadius or 35) + 5)
	UpdateFarmInfoLabel()
end)

UpdateFarmInfoLabel()

local PathRowRefs = {}

function RefreshPathEditor()
	for _, row in ipairs(PathRowRefs) do
		if row and row.Destroy then row:Destroy() end
	end
	table.clear(PathRowRefs)

	local count = #CONFIG.CustomWaypoints
	if count == 0 then
		PathListFrame.Size = UDim2.fromScale(0.9949, 0)
		return
	end

	for i, wp in ipairs(CONFIG.CustomWaypoints) do
		local row = Instance.new("Frame")
		row.Size = UDim2.fromScale(1, 0.065)
		row.BackgroundColor3 = CONFIG.UI_SURFACE
		row.BorderSizePixel = 0
		row.LayoutOrder = i
		row.Parent = PathListFrame
		local rc = Instance.new("UICorner")
		rc.CornerRadius = UDim.new(0.08, 0)
		rc.Parent = row

		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(0.55, 1)
		label.Position = UDim2.fromScale(0.02, 0)
		label.BackgroundTransparency = 1
		label.Text = string.format("#%d  %.0f, %.0f, %.0f", i, wp.X, wp.Y, wp.Z)
		label.TextColor3 = CONFIG.UI_TEXT
		label.TextScaled = true
		label.Font = Enum.Font.GothamMedium
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Parent = row

		local actBtn = Instance.new("TextButton")
		actBtn.Size = UDim2.fromScale(0.22, 0.7)
		actBtn.Position = UDim2.fromScale(0.58, 0.15)
		actBtn.BackgroundColor3 = CONFIG.UI_HOVER
		actBtn.BorderSizePixel = 0
		actBtn.Text = wp.Action == "Interact" and "INTERACT" or "NONE"
		actBtn.TextColor3 = wp.Action == "Interact" and CONFIG.UI_ACCENT or CONFIG.UI_TEXT
		actBtn.TextScaled = true
		actBtn.Font = Enum.Font.GothamBold
		actBtn.Parent = row
		local ac = Instance.new("UICorner")
		ac.CornerRadius = UDim.new(0.15, 0)
		ac.Parent = actBtn
		actBtn.Activated:Connect(function()
			wp.Action = (wp.Action == "Interact") and "None" or "Interact"
			actBtn.Text = wp.Action == "Interact" and "INTERACT" or "NONE"
			actBtn.TextColor3 = wp.Action == "Interact" and CONFIG.UI_ACCENT or CONFIG.UI_TEXT
		end)

		local delBtn = Instance.new("TextButton")
		delBtn.Size = UDim2.fromScale(0.14, 0.7)
		delBtn.Position = UDim2.fromScale(0.82, 0.15)
		delBtn.BackgroundColor3 = CONFIG.UI_HOVER
		delBtn.BorderSizePixel = 0
		delBtn.Text = "×"
		delBtn.TextColor3 = CONFIG.UI_TEXT
		delBtn.TextScaled = true
		delBtn.Font = Enum.Font.GothamBold
		delBtn.Parent = row
		local dc = Instance.new("UICorner")
		dc.CornerRadius = UDim.new(0.15, 0)
		dc.Parent = delBtn
		delBtn.Activated:Connect(function()
			table.remove(CONFIG.CustomWaypoints, i)
			if CONFIG.CurrentCustomWaypoint > #CONFIG.CustomWaypoints then
				CONFIG.CurrentCustomWaypoint = math.max(1, #CONFIG.CustomWaypoints)
			end
			RefreshPathEditor()
		end)

		table.insert(PathRowRefs, row)
	end

	PathListFrame.Size = UDim2.fromScale(0.9949, math.min(0.4, 0.065 * count + 0.01))
end

RecordBtn.Activated:Connect(function()
	if not RootPart then return end
	local p = RootPart.Position
	table.insert(CONFIG.CustomWaypoints, {
		X = p.X, Y = p.Y, Z = p.Z,
		Action = "None",
		Label = "",
	})
	RefreshPathEditor()
	if ProfileStatusLabel then
		ProfileStatusLabel.Text = "Recorded #" .. #CONFIG.CustomWaypoints
	end
end)

ClearPathBtn.Activated:Connect(function()
	CONFIG.CustomWaypoints = {}
	CONFIG.CurrentCustomWaypoint = 1
	RefreshPathEditor()
	if ProfileStatusLabel then ProfileStatusLabel.Text = "Path cleared" end
end)

SaveCfgBtn.Activated:Connect(function()
	local name = CURRENT_PROFILE_NAME
	-- simple: use PlaceId-based default name
	if name == "Default" then
		name = "Place_" .. tostring(game.PlaceId)
		CURRENT_PROFILE_NAME = name
	end
	local ok, err = SaveConfig(name)
	if not ok and ProfileStatusLabel then
		ProfileStatusLabel.Text = "Save failed: " .. tostring(err)
	end
end)

LoadCfgBtn.Activated:Connect(function()
	local name = "Place_" .. tostring(game.PlaceId)
	local ok, err = LoadConfig(name)
	if not ok then
		ok, err = LoadConfig(CURRENT_PROFILE_NAME)
	end
	if not ok and ProfileStatusLabel then
		ProfileStatusLabel.Text = "Load failed: " .. tostring(err)
	end
end)

-- Auto-load matching profile for this place on start
task.defer(function()
	task.wait(1)
	TryAutoLoadProfileForPlace()
end)

--// Mob Watcher
local MobConnections       = {}
local MobFolderConnections = {}
local RefreshQueued        = false

function QueueEnemyPickerRefresh()
	if not EnemyPicker.Visible then
		return
	end

	if RefreshQueued then
		return
	end

	RefreshQueued = true

	task.defer(function()
		RefreshQueued = false

		if EnemyPicker.Visible then
			RefreshEnemyPicker()
		end
	end)
end

function DisconnectMob(Mob)
	local Connections = MobConnections[Mob]

	if not Connections then
		return
	end

	for _, Connection in Connections do
		Connection:Disconnect()
	end

	MobConnections[Mob] = nil
	BladePartCache[Mob] = nil
	CombatGroupCache[Mob] = nil
	CombatBladeCache[Mob] = nil
end

function WatchMob(Mob)
	if not Mob:IsA("Model") then
		return
	end

	DisconnectMob(Mob)

	local Connections = {}
	MobConnections[Mob] = Connections

	local function WatchConfig(Config)
		if not Config then
			return
		end

		local Entity = Config:FindFirstChild("Entity")

		if Entity and Entity:IsA("StringValue") then
			table.insert(Connections, Entity:GetPropertyChangedSignal("Value"):Connect(function()
				QueueEnemyPickerRefresh()

				ValidMobs[Mob] = nil

				if ClosestTarget == Mob and not IsEntityInPriority(Entity.Value) then
					ClosestTarget = nil
				end
			end))
		end

		table.insert(Connections, Config.ChildAdded:Connect(function(Child)
			if Child.Name ~= "Entity" then
				return
			end

			if Child:IsA("StringValue") then
				table.insert(Connections, Child:GetPropertyChangedSignal("Value"):Connect(function()
					QueueEnemyPickerRefresh()
					ValidMobs[Mob] = nil

					if ClosestTarget == Mob and not IsEntityInPriority(Child.Value) then
						ClosestTarget = nil
					end
				end))
			end

			QueueEnemyPickerRefresh()
			ValidMobs[Mob] = nil
		end))

		table.insert(Connections, Config.ChildRemoved:Connect(function(Child)
			if Child.Name == "Entity" then
				ValidMobs[Mob] = nil

				if ClosestTarget == Mob then
					ClosestTarget = nil
				end

				QueueEnemyPickerRefresh()
			end
		end))
	end

	local Config = Mob:FindFirstChild("Config")

	if Config then
		WatchConfig(Config)
	end

	table.insert(Connections, Mob.ChildAdded:Connect(function(Child)
		if Child.Name == "Config" then
			WatchConfig(Child)
			QueueEnemyPickerRefresh()
			ValidMobs[Mob] = nil
		end
	end))

	table.insert(Connections, Mob.ChildRemoved:Connect(function(Child)
		if Child.Name == "Config" then
			ValidMobs[Mob] = nil

			if ClosestTarget == Mob then
				ClosestTarget = nil
			end

			QueueEnemyPickerRefresh()
		end
	end))

	QueueEnemyPickerRefresh()
end

function WatchMobFolder(MobFolder)
	for _, Connection in MobFolderConnections do
		Connection:Disconnect()
	end

	table.clear(MobFolderConnections)

	for Mob in MobConnections do
		DisconnectMob(Mob)
	end

	for _, Mob in MobFolder:GetChildren() do
		WatchMob(Mob)
	end

	table.insert(MobFolderConnections, MobFolder.ChildAdded:Connect(function(Mob)
		WatchMob(Mob)
		QueueEnemyPickerRefresh()
	end))

	table.insert(MobFolderConnections, MobFolder.ChildRemoved:Connect(function(Mob)
		DisconnectMob(Mob)
		ValidMobs[Mob] = nil

		if ClosestTarget == Mob then
			ClosestTarget = nil
		end

		QueueEnemyPickerRefresh()
	end))
end

local ExistingMobFolder = workspace:FindFirstChild("Mobs")

if ExistingMobFolder then
	WatchMobFolder(ExistingMobFolder)
end

workspace.ChildAdded:Connect(function(Child)
	if Child.Name == "Mobs" then
		WatchMobFolder(Child)
		QueueEnemyPickerRefresh()
	end
end)

workspace.ChildRemoved:Connect(function(Child)
	if Child.Name ~= "Mobs" then
		return
	end

	for _, Connection in MobFolderConnections do
		Connection:Disconnect()
	end

	table.clear(MobFolderConnections)

	for Mob in MobConnections do
		DisconnectMob(Mob)
	end

	table.clear(ValidMobs)

	ClosestTarget = nil

	QueueEnemyPickerRefresh()
end)

--// GUI Toggle
local GUIToggle = Instance.new("TextButton")
GUIToggle.Name = "GUIToggle"
GUIToggle.Size = UDim2.new(0, 44, 0, 44)
GUIToggle.BackgroundColor3 = Color3.fromRGB(18, 18, 21)
GUIToggle.BackgroundTransparency = 0.08
GUIToggle.BorderSizePixel = 0
GUIToggle.Text = "≡"
GUIToggle.LayoutOrder = 16
GUIToggle.TextTransparency = 0
GUIToggle.TextColor3 = CONFIG.UI_TEXT
GUIToggle.TextScaled = true
GUIToggle.Font = Enum.Font.Gotham
GUIToggle.AutoButtonColor = true
GUIToggle.Parent = ToggleContainer

local GUIToggleCorner = Instance.new("UICorner")
GUIToggleCorner.CornerRadius = UDim.new(0, 8)
GUIToggleCorner.Parent = GUIToggle

local GUIVisible = true

GUIToggle.Activated:Connect(function()
	GUIVisible = not GUIVisible
	Panel.Visible = GUIVisible
end)

--// Panel Dragging
local Dragging      = false
local DragStart     = nil
local StartPosition = nil

Header.InputBegan:Connect(function(Input)
	if Input.UserInputType == Enum.UserInputType.MouseButton1
		or Input.UserInputType == Enum.UserInputType.Touch
	then
		Dragging = true
		DragStart = Input.Position
		StartPosition = Panel.Position

		Input.Changed:Connect(function()
			if Input.UserInputState == Enum.UserInputState.End then
				Dragging = false
			end
		end)
	end
end)

UserInputService.InputChanged:Connect(function(Input)
	if not Dragging then
		return
	end

	if Input.UserInputType ~= Enum.UserInputType.MouseMovement
		and Input.UserInputType ~= Enum.UserInputType.Touch
	then
		return
	end

	local Delta = Input.Position - DragStart
	local Camera = workspace.CurrentCamera

	if not Camera then
		return
	end

	local Viewport = Camera.ViewportSize

	local DeltaScaleX = Delta.X / Viewport.X
	local DeltaScaleY = Delta.Y / Viewport.Y

	Panel.Position = UDim2.fromScale(
		StartPosition.X.Scale + DeltaScaleX,
		StartPosition.Y.Scale + DeltaScaleY
	)
end)

--// Feature Buttons
function updateFeatureButtons()
	if Feature.AutoFarm.Enabled then
		Feature.AutoFarm.Button.Text = "●  AUTO FARMING  •  ENABLED"
		Feature.AutoFarm.Button.BackgroundColor3 = Color3.fromRGB(60, 125, 50)
		Feature.AutoFarm.Status.Text = "Farming system is active"
	else
		Feature.AutoFarm.Button.Text = "●  AUTO FARMING  •  DISABLED"
		Feature.AutoFarm.Button.BackgroundColor3 = Color3.fromRGB(255, 65, 65)
		Feature.AutoFarm.Status.Text = "Farming system is paused"
	end

	if Feature.AutoBlock.Enabled then
		Feature.AutoBlock.Button.Text = "●  AUTO BLOCKING  •  ENABLED"
		Feature.AutoBlock.Button.BackgroundColor3 = Color3.fromRGB(60, 125, 50)
		Feature.AutoBlock.Status.Text = "Automatic player blocking is active"
	else
		Feature.AutoBlock.Button.Text = "●  AUTO BLOCKING  •  DISABLED"
		Feature.AutoBlock.Button.BackgroundColor3 = Color3.fromRGB(255, 65, 65)
		Feature.AutoBlock.Status.Text = "Automatic player blocking is paused"
	end

	if Feature.SafeCombat.Enabled then
		Feature.SafeCombat.Button.Text = "●  SAFE COMBAT  •  ENABLED"
		Feature.SafeCombat.Button.BackgroundColor3 = Color3.fromRGB(60, 125, 50)
		Feature.SafeCombat.Status.Text = "Safe positioning is active"
	else
		Feature.SafeCombat.Button.Text = "●  SAFE COMBAT  •  DISABLED"
		Feature.SafeCombat.Button.BackgroundColor3 = Color3.fromRGB(255, 65, 65)
		Feature.SafeCombat.Status.Text = "Direct target movement is active"
	end

	if Feature.AutoFind.Enabled then
		Feature.AutoFind.Button.Text = "●  AUTO FIND  •  ENABLED"
		Feature.AutoFind.Button.BackgroundColor3 = Color3.fromRGB(60, 125, 50)
		Feature.AutoFind.Status.Text = "Ignoring waypoint route • finding mobs"
	else
		Feature.AutoFind.Button.Text = "●  AUTO FIND  •  DISABLED"
		Feature.AutoFind.Button.BackgroundColor3 = Color3.fromRGB(255, 65, 65)
		Feature.AutoFind.Status.Text = "Following waypoint route"
	end

	if Feature.IgnoreFarmZone.Enabled then
		Feature.IgnoreFarmZone.Button.Text = "●  IGNORE FARM ZONE  •  ENABLED"
		Feature.IgnoreFarmZone.Button.BackgroundColor3 = Color3.fromRGB(60, 125, 50)
		Feature.IgnoreFarmZone.Status.Text = "Farm zone checks are bypassed"
	else
		Feature.IgnoreFarmZone.Button.Text = "●  IGNORE FARM ZONE  •  DISABLED"
		Feature.IgnoreFarmZone.Button.BackgroundColor3 = Color3.fromRGB(255, 65, 65)
		Feature.IgnoreFarmZone.Status.Text = "Farm zone checks are active"
	end

	if Feature.AutoPatrol.Enabled then
		Feature.AutoPatrol.Button.Text = "●  AUTO PATROL  •  ENABLED"
		Feature.AutoPatrol.Button.BackgroundColor3 = Color3.fromRGB(60, 125, 50)
		Feature.AutoPatrol.Status.Text = "Patrolling safe open areas when no mob is found"
	else
		Feature.AutoPatrol.Button.Text = "●  AUTO PATROL  •  DISABLED"
		Feature.AutoPatrol.Button.BackgroundColor3 = Color3.fromRGB(255, 65, 65)
		Feature.AutoPatrol.Status.Text = "Stops when no target is available"
	end

	if Feature.AutoSkill.Enabled then
		Feature.AutoSkill.Button.Text = "●  AUTO SKILL  •  ENABLED"
		Feature.AutoSkill.Button.BackgroundColor3 = Color3.fromRGB(60, 125, 50)
		Feature.AutoSkill.Status.Text = "Automatic use skill is active"
	else
		Feature.AutoSkill.Button.Text = "●  AUTO SKILL  •  DISABLED"
		Feature.AutoSkill.Button.BackgroundColor3 = Color3.fromRGB(255, 65, 65)
		Feature.AutoSkill.Status.Text = "Automatic use skill is inactive"
	end

	if Feature.ResetOnBoostOut.Enabled then
		Feature.ResetOnBoostOut.Button.Text = "●  REFILL BOOSTER  •  ENABLED"
		Feature.ResetOnBoostOut.Button.BackgroundColor3 = Color3.fromRGB(60, 125, 50)
		Feature.ResetOnBoostOut.Status.Text = "Automatic reset when booster ends is active"
	else
		Feature.ResetOnBoostOut.Button.Text = "●  REFILL BOOSTER  •  DISABLED"
		Feature.ResetOnBoostOut.Button.BackgroundColor3 = Color3.fromRGB(255, 65, 65)
		Feature.ResetOnBoostOut.Status.Text = "Automatic reset when booster ends is inactive"
	end

	Feature.ResetStats.Button.Text = "●  RESET STATS  •  [???]"
	Feature.ResetStats.Button.BackgroundColor3 = Color3.fromRGB(255, 180, 0)
	Feature.ResetStats.Status.Text = "Reset player stats"

	if Feature.UseCustomPath.Enabled then
		Feature.UseCustomPath.Button.Text = "●  CUSTOM PATH  •  ENABLED"
		Feature.UseCustomPath.Button.BackgroundColor3 = Color3.fromRGB(60, 125, 50)
		Feature.UseCustomPath.Status.Text = "Following custom recorded waypoints"
	else
		Feature.UseCustomPath.Button.Text = "●  CUSTOM PATH  •  DISABLED"
		Feature.UseCustomPath.Button.BackgroundColor3 = Color3.fromRGB(255, 65, 65)
		Feature.UseCustomPath.Status.Text = "Using default PLACE_CONFIG route"
	end

	if Feature.UseCustomFarmZone.Enabled then
		Feature.UseCustomFarmZone.Button.Text = "●  CUSTOM FARM  •  ENABLED"
		Feature.UseCustomFarmZone.Button.BackgroundColor3 = Color3.fromRGB(60, 125, 50)
		Feature.UseCustomFarmZone.Status.Text = "Using your farm center / radius / deadzone"
	else
		Feature.UseCustomFarmZone.Button.Text = "●  CUSTOM FARM  •  DISABLED"
		Feature.UseCustomFarmZone.Button.BackgroundColor3 = Color3.fromRGB(255, 65, 65)
		Feature.UseCustomFarmZone.Status.Text = "Using PLACE_CONFIG farm zone"
	end
end

Feature.AutoBlock.Button.Activated:Connect(function()
	Feature.AutoBlock.Enabled = not Feature.AutoBlock.Enabled
	BlockEnabled = Feature.AutoBlock.Enabled
	updateFeatureButtons()
end)

Feature.SafeCombat.Button.Activated:Connect(function()
	Feature.SafeCombat.Enabled = not Feature.SafeCombat.Enabled
	SafeCombatPositionEnabled = Feature.SafeCombat.Enabled
	ResetTargetReposition()
	updateFeatureButtons()
end)

Feature.AutoFind.Button.Activated:Connect(function()
	Feature.AutoFind.Enabled = not Feature.AutoFind.Enabled
	WaypointEnabled = not Feature.AutoFind.Enabled
	ClosestTarget = nil
	table.clear(ValidMobs)
	table.clear(CombatGroupCache)
	ResetTargetReposition()
	UpdateValidMobs()
	ClosestTarget = GetClosestGoblin()
	updateFeatureButtons()
end)

Feature.IgnoreFarmZone.Button.Activated:Connect(function()
	Feature.IgnoreFarmZone.Enabled = not Feature.IgnoreFarmZone.Enabled
	ClosestTarget = nil
	table.clear(ValidMobs)
	table.clear(CombatGroupCache)
	ResetTargetReposition()
	DeadzoneEscapePosition = nil
	PatrolPosition = nil
	LastPatrolCalculateTime = 0
	FarmReturnPosition = nil
	LastFarmReturnCalculateTime = 0

	UpdateValidMobs()
	ClosestTarget = GetClosestGoblin()
	updateFeatureButtons()
end)

Feature.AutoPatrol.Button.Activated:Connect(function()
	Feature.AutoPatrol.Enabled = not Feature.AutoPatrol.Enabled
	PatrolPosition = nil
	LastPatrolCalculateTime = 0
	updateFeatureButtons()
end)

Feature.AutoSkill.Button.Activated:Connect(function()
	Feature.AutoSkill.Enabled = not Feature.AutoSkill.Enabled
	BlockEnabled = Feature.AutoSkill.Enabled
	updateFeatureButtons()
end)

Feature.ResetOnBoostOut.Button.Activated:Connect(function()
	Feature.ResetOnBoostOut.Enabled = not Feature.ResetOnBoostOut.Enabled
	updateFeatureButtons()
end)

Feature.UseCustomPath.Button.Activated:Connect(function()
	Feature.UseCustomPath.Enabled = not Feature.UseCustomPath.Enabled
	CONFIG.UseCustomPath = Feature.UseCustomPath.Enabled
	CONFIG.CurrentCustomWaypoint = 1
	updateFeatureButtons()
end)

Feature.UseCustomFarmZone.Button.Activated:Connect(function()
	Feature.UseCustomFarmZone.Enabled = not Feature.UseCustomFarmZone.Enabled
	CONFIG.UseCustomFarmZone = Feature.UseCustomFarmZone.Enabled
	if Feature.UseCustomFarmZone.Enabled and not CONFIG.CustomFarmCenter and RootPart then
		CONFIG.CustomFarmCenter = RootPart.Position
	end
	ClosestTarget = nil
	table.clear(ValidMobs)
	updateFeatureButtons()
end)

Feature.ResetStats.Button.Activated:Connect(function()
	Feature.ResetStats.Enabled = not Feature.ResetStats.Enabled
	updateFeatureButtons()

	task.spawn(function()
		local PlayerStats = Player:WaitForChild("PlayerStats")
		local StatsEvent = Replicated:FindFirstChild("StatsEvent", true)
		if not StatsEvent then
			return print(`StatsEvent is not valid.`)
		end
		local Stats = {
			"Vitality",
			"Agility",
			"Luck",
			"Strength",
			"Defense",
		}
		for _, stat in ipairs(Stats) do
			if PlayerStats[stat].Value >= 500 then
				StatsEvent:FireServer(stat, -1)
				task.delay(0.35, function()
					StatsEvent:FireServer(stat, 0)
				end)
			else
				StatsEvent:FireServer(stat, 0)
			end
		end
	end)
end)

--// Farm Button
function updateButton()
	Feature.AutoFarm.Enabled = Enabled
	updateFeatureButtons()
end

Toggle = Feature.AutoFarm.Button
Status = Feature.AutoFarm.Status

Toggle.Activated:Connect(function()
	Enabled = not Enabled
	Feature.AutoFarm.Enabled = Enabled
	updateFeatureButtons()
end)

updateFeatureButtons()
updatePosition()

--// Teleport
function TeleportToPlace(placeId: number?)
	local TeleportService = game:GetService("TeleportService")

	TeleportService:Teleport(placeId or game.PlaceId, Player)
end

--// Block
function isBlocked(userId)
	local success, blockedUserIds = pcall(function()
		return StarterGui:GetCore("GetBlockedUserIds")
	end)

	if not success or not blockedUserIds then
		return false
	end

	for _, blockedUserId in blockedUserIds do
		if blockedUserId == userId then
			return true
		end
	end

	return false
end

function promptBlockPlayer(plr)
	local userId = plr.UserId

	if BlockCache[userId] then
		return
	end

	if isBlocked(userId) then
		return
	end

	BlockCache[userId] = true

	local success, err = pcall(function()
		StarterGui:SetCore("PromptBlockPlayer", plr)
	end)

	if not success then
		warn("PromptBlockPlayer failed:", err)
		BlockCache[userId] = nil
		return
	end

	AutoConfirmBlockPrompt()

	task.delay(CONFIG.BLOCK_COOLDOWN, function()
		BlockCache[userId] = nil
	end)
end

--// Farm Area Check
function IsInsideFarmArea(Position)
	if Feature.IgnoreFarmZone.Enabled then
		return true
	end

	local farm = GetActiveFarmConfig()
	if not farm then
		-- No place config and no custom zone: allow everywhere
		return true
	end

	if not Position then
		return false
	end

	local Offset = Position - farm.FARM_CENTER
	local Distance = Vector3.new(Offset.X, 0, Offset.Z).Magnitude

	if Distance > farm.FARM_RADIUS then
		return false
	end

	if farm.FARM_DEADZONE_RADIUS and farm.FARM_DEADZONE_RADIUS > 0 and farm.FARM_DEADZONE_CENTER then
		local DeadzoneOffset = Position - farm.FARM_DEADZONE_CENTER
		local DeadzoneDistance = Vector3.new(DeadzoneOffset.X, 0, DeadzoneOffset.Z).Magnitude
		if DeadzoneDistance <= farm.FARM_DEADZONE_RADIUS then
			return false
		end
	end

	return true
end

--// Water Check


function IsWaterAtPosition(Position, IgnoreModel)
	if not Position then
		return false
	end

	local FilterInstances = {
		Character,
	}

	if IgnoreModel then
		table.insert(FilterInstances, IgnoreModel)
	end

	local RaycastParams = RaycastParams.new()
	RaycastParams.FilterType = Enum.RaycastFilterType.Exclude
	RaycastParams.FilterDescendantsInstances = FilterInstances

	local Origin    = Position + Vector3.new(0, 10, 0)
	local Direction = Vector3.new(0, -30, 0)

	local Result = workspace:Raycast(Origin, Direction, RaycastParams)

	return Result and Result.Material == Enum.Material.Water
end

function IsPathThroughWater(TargetPosition)
	if not RootPart then
		return true
	end

	local Origin   = RootPart.Position
	local Offset   = TargetPosition - Origin
	local Distance = Offset.Magnitude

	if Distance <= 0 then
		return IsWaterAtPosition(TargetPosition)
	end

	local Direction = Offset.Unit

	for DistanceTravelled = 0, Distance, CONFIG.WATER_SAMPLE_DISTANCE do
		local Position = Origin + Direction * DistanceTravelled

		if IsWaterAtPosition(Position) then
			return true
		end
	end

	return IsWaterAtPosition(TargetPosition)
end

--// Deadzone Path Check


function IsPathThroughDeadzone(TargetPosition)
	if Feature.IgnoreFarmZone.Enabled then
		return false
	end

	local farm = GetActiveFarmConfig()
	if not RootPart or not TargetPosition or not farm then
		return false
	end

	if not farm.FARM_DEADZONE_CENTER or not farm.FARM_DEADZONE_RADIUS or farm.FARM_DEADZONE_RADIUS <= 0 then
		return false
	end

	local Origin   = RootPart.Position
	local Offset   = TargetPosition - Origin
	local Distance = Offset.Magnitude

	if Distance <= 0 then
		local DeadzoneOffset = Origin - farm.FARM_DEADZONE_CENTER
		local DeadzoneDistance = Vector3.new(DeadzoneOffset.X, 0, DeadzoneOffset.Z).Magnitude
		return DeadzoneDistance <= farm.FARM_DEADZONE_RADIUS
	end

	local Direction = Offset.Unit

	for DistanceTravelled = 0, Distance, CONFIG.DEADZONE_SAMPLE_DISTANCE do
		local Position = Origin + Direction * DistanceTravelled
		local DeadzoneOffset = Position - farm.FARM_DEADZONE_CENTER
		local DeadzoneDistance = Vector3.new(DeadzoneOffset.X, 0, DeadzoneOffset.Z).Magnitude

		if DeadzoneDistance <= farm.FARM_DEADZONE_RADIUS then
			return true
		end
	end

	return false
end

--// Line Of Sight
function CanSeeGoblin(Goblin)
	if not RootPart or not Goblin then
		return false
	end

	local MobRoot = Goblin:FindFirstChild("HumanoidRootPart")

	if not MobRoot then
		return false
	end

	local Origin    = RootPart.Position
	local Direction = MobRoot.Position - Origin

	local RaycastParams = RaycastParams.new()
	RaycastParams.FilterType = Enum.RaycastFilterType.Exclude
	RaycastParams.FilterDescendantsInstances = {
		Character,
	}

	local Result = workspace:Raycast(Origin, Direction, RaycastParams)

	if not Result then
		return true
	end

	return Result.Instance:IsDescendantOf(Goblin)
end

--// Target Lock Validation
function IsTargetLockValid(Mob)
	if not Mob or not Mob:IsA("Model") then
		return false
	end

	if not Mob:IsDescendantOf(workspace) then
		return false
	end

	if not RootPart then
		return false
	end

	local MobFolder = workspace:FindFirstChild("Mobs")

	if not MobFolder or not Mob:IsDescendantOf(MobFolder) then
		return false
	end

	local Config = Mob:FindFirstChild("Config")

	if not Config then
		return false
	end

	local Entity = Config:FindFirstChild("Entity")

	if not Entity or not Entity:IsA("StringValue") then
		return false
	end

	if not IsEntityInPriority(Entity.Value) then
		return false
	end

	local MobHumanoid = Mob:FindFirstChildOfClass("Humanoid")
	local MobRoot     = Mob:FindFirstChild("HumanoidRootPart")

	if not MobHumanoid or not MobRoot then
		return false
	end

	if MobHumanoid.Health <= 0 then
		return false
	end

	local Offset   = MobRoot.Position - RootPart.Position
	local Distance = Vector3.new(Offset.X, 0, Offset.Z).Magnitude

	if CONFIG.DISTANCE_Y_CALCULATE then
		Distance = Offset.Magnitude
	end

	if Distance > CONFIG.MOB_DETECTION_DISTANCE then
		return false
	end

	if not IsInsideFarmArea(MobRoot.Position) then
		return false
	end

	if IsWaterAtPosition(MobRoot.Position, Mob) then
		return false
	end

	return true
end

--// Validate Mob
function IsValidMob(Mob)
	if not Mob or not Mob:IsA("Model") then
		return false
	end

	if not Mob:IsDescendantOf(workspace) then
		return false
	end

	if not RootPart then
		return false
	end

	local MobFolder = workspace:FindFirstChild("Mobs")

	if not MobFolder or not Mob:IsDescendantOf(MobFolder) then
		return false
	end

	local Config = Mob:FindFirstChild("Config")

	if not Config then
		return false
	end

	local Entity = Config:FindFirstChild("Entity")

	if not Entity or not Entity:IsA("StringValue") then
		return false
	end

	if not IsEntityInPriority(Entity.Value) then
		return false
	end

	local MobHumanoid = Mob:FindFirstChildOfClass("Humanoid")
	local MobRoot     = Mob:FindFirstChild("HumanoidRootPart")

	if not MobHumanoid or not MobRoot then
		return false
	end

	if MobHumanoid.Health <= 0 then
		return false
	end

	local Offset   = MobRoot.Position - RootPart.Position
	local Distance = Vector3.new(Offset.X, 0, Offset.Z).Magnitude

	if CONFIG.DISTANCE_Y_CALCULATE then
		Distance = Offset.Magnitude
	end

	if Distance > CONFIG.MOB_DETECTION_DISTANCE then
		return false
	end

	if not IsInsideFarmArea(MobRoot.Position) then
		return false
	end

	if IsWaterAtPosition(MobRoot.Position, Mob) then
		return false
	end

	if not CanSeeGoblin(Mob) then
		return false
	end

	if IsPathThroughWater(MobRoot.Position) then
		return false
	end

	if IsPathThroughDeadzone(MobRoot.Position) then
		return false
	end

	return true
end

--// Update Realtime Valid Mob List
function UpdateValidMobs()
	local MobFolder = workspace:FindFirstChild("Mobs")

	if not MobFolder or not RootPart then
		table.clear(ValidMobs)

		if ClosestTarget and not IsTargetLockValid(ClosestTarget) then
			ClosestTarget = nil
		end

		return
	end

	local CurrentMobs = {}

	for _, Mob in MobFolder:GetChildren() do
		CurrentMobs[Mob] = true

		if IsValidMob(Mob) then
			ValidMobs[Mob] = true
		else
			ValidMobs[Mob] = nil
		end
	end

	for Mob in ValidMobs do
		if not CurrentMobs[Mob] then
			ValidMobs[Mob] = nil
		end
	end

	if ClosestTarget and not IsTargetLockValid(ClosestTarget) then
		ClosestTarget = nil
	end
end

--// Closest Visible Goblin
function GetMobPriority(Mob)
	local Config = Mob:FindFirstChild("Config")

	if not Config then
		return nil
	end

	local Entity = Config:FindFirstChild("Entity")

	if not Entity then
		return nil
	end

	return table.find(CONFIG.TARGET_ENTITY_PRIORITY, Entity.Value)
end

function GetMobDistance(Mob)
	local MobRoot = Mob:FindFirstChild("HumanoidRootPart")

	if not MobRoot or not RootPart then
		return math.huge
	end

	local Offset = MobRoot.Position - RootPart.Position

	if CONFIG.DISTANCE_Y_CALCULATE then
		return Offset.Magnitude
	end

	return Vector3.new(Offset.X, 0, Offset.Z).Magnitude
end

function GetClosestGoblin()
	if not RootPart then
		return nil
	end

	local BestTarget   = nil
	local BestPriority = math.huge
	local BestDistance = math.huge

	for Mob in ValidMobs do
		local Priority = GetMobPriority(Mob)

		if not Priority then
			ValidMobs[Mob] = nil
			continue
		end

		local Distance = GetMobDistance(Mob)

		if Priority < BestPriority
			or (Priority == BestPriority and Distance < BestDistance)
		then
			BestPriority = Priority
			BestDistance = Distance
			BestTarget = Mob
		end
	end

	return BestTarget
end

--// Detect a secondary mob approaching from the side or behind.
--// The primary target is never replaced by this system.
function GetNearbyThreatMob(TargetMob)
	if not RootPart or not TargetMob then
		return nil
	end

	local BestThreat = nil
	local BestDistance = math.huge
	local LookVector = Vector3.new(RootPart.CFrame.LookVector.X, 0, RootPart.CFrame.LookVector.Z)

	if LookVector.Magnitude <= 0.01 then
		return nil
	end

	LookVector = LookVector.Unit

	for Mob in ValidMobs do
		if Mob == TargetMob then
			continue
		end

		local MobHumanoid = Mob:FindFirstChildOfClass("Humanoid")
		local MobRoot = Mob:FindFirstChild("HumanoidRootPart")

		if not MobHumanoid or not MobRoot or MobHumanoid.Health <= 0 then
			continue
		end

		local Offset = MobRoot.Position - RootPart.Position
		local HorizontalOffset = Vector3.new(Offset.X, 0, Offset.Z)
		local Distance = HorizontalOffset.Magnitude

		if Distance <= 0.01 or Distance > CONFIG.THREAT_DETECTION_DISTANCE then
			continue
		end

		local Direction = HorizontalOffset.Unit
		local Dot = math.clamp(LookVector:Dot(Direction), -1, 1)
		local Angle = math.deg(math.acos(Dot))

		--// 0 = directly in front, 90 = side, 180 = behind.
		if Angle >= CONFIG.THREAT_ANGLE and Distance < BestDistance then
			BestThreat = Mob
			BestDistance = Distance
		end
	end

	return BestThreat, BestDistance
end

function GetThreatEscapePosition(TargetMob, ThreatMob)
	if not RootPart or not ThreatMob then
		return nil
	end

	local ThreatRoot = ThreatMob:FindFirstChild("HumanoidRootPart")
	local TargetRoot = TargetMob and TargetMob:FindFirstChild("HumanoidRootPart")

	if not ThreatRoot or not TargetRoot then
		return nil
	end

	local Origin = RootPart.Position
	local Away = Origin - ThreatRoot.Position
	local AwayDirection = Vector3.new(Away.X, 0, Away.Z)

	if AwayDirection.Magnitude <= 0.01 then
		return nil
	end

	AwayDirection = AwayDirection.Unit

	--// Try several directions instead of blindly retreating straight back.
	--// This prevents Safe Distance from pushing the player into a wall,
	--// corner, or narrow gap when the direct retreat path is blocked.
	local Directions = {
		AwayDirection,
		CFrame.fromAxisAngle(Vector3.yAxis, math.rad(45)):VectorToWorldSpace(AwayDirection),
		CFrame.fromAxisAngle(Vector3.yAxis, math.rad(-45)):VectorToWorldSpace(AwayDirection),
		CFrame.fromAxisAngle(Vector3.yAxis, math.rad(90)):VectorToWorldSpace(AwayDirection),
		CFrame.fromAxisAngle(Vector3.yAxis, math.rad(-90)):VectorToWorldSpace(AwayDirection),
		CFrame.fromAxisAngle(Vector3.yAxis, math.rad(135)):VectorToWorldSpace(AwayDirection),
		CFrame.fromAxisAngle(Vector3.yAxis, math.rad(-135)):VectorToWorldSpace(AwayDirection),
	}

	local CurrentTargetDistance = GetHorizontalDistance(Origin, TargetRoot.Position)
	local BestPosition = nil
	local BestScore = math.huge

	for Index, Direction in ipairs(Directions) do
		Direction = Vector3.new(Direction.X, 0, Direction.Z)

		if Direction.Magnitude <= 0.01 then
			continue
		end

		Direction = Direction.Unit

		--// Prefer shorter movement when multiple escape directions are safe.
		local Candidate = Origin + Direction * CONFIG.THREAT_ESCAPE_DISTANCE

		if not IsInsideFarmArea(Candidate)
			or IsWaterAtPosition(Candidate, TargetMob)
			or IsPathThroughWater(Candidate)
			or IsPathThroughDeadzone(Candidate)
			or IsPathThroughBladeGroupDanger(Candidate, TargetMob)
			or not IsEscapePathClear(Candidate)
		then
			continue
		end

		--// Keep enough space from the threat while avoiding a huge
		--// increase in distance from the primary target.
		local ThreatDistance = GetHorizontalDistance(Candidate, ThreatRoot.Position)
		local TargetDistance = GetHorizontalDistance(Candidate, TargetRoot.Position)

		--// Penalize positions that move much farther from the primary target.
		local TargetDistancePenalty = math.max(0, TargetDistance - CurrentTargetDistance) * 0.35

		--// Prefer directions closer to directly away from the threat.
		local DirectionPenalty = (1 - math.clamp(AwayDirection:Dot(Direction), -1, 1)) * 2

		local Score = TargetDistancePenalty + DirectionPenalty + Index * 0.01

		if ThreatDistance > CONFIG.THREAT_DETECTION_DISTANCE
			and Score < BestScore
		then
			BestScore = Score
			BestPosition = Candidate
		elseif ThreatDistance > CONFIG.ENEMY_ATTACK_SAFE_DISTANCE
			and Score < BestScore
		then
			BestScore = Score
			BestPosition = Candidate
		end
	end

	return BestPosition
end

--// ============================================================
--// COMBAT BLADE SYSTEM
--// ============================================================

function GetHorizontalDistance(PositionA, PositionB)
	local Offset = PositionA - PositionB

	return Vector3.new(
		Offset.X,
		0,
		Offset.Z
	).Magnitude
end

--// Get every BladePart inside one Mob.
function GetBladeParts(Mob)
	if not Mob then
		return {}
	end

	local now = os.clock()
	local Cached = BladePartCache[Mob]

	if Cached
		and now - Cached.Time < CONFIG.BLADE_PART_CACHE_INTERVAL
	then
		return Cached.Parts
	end

	local BladeParts = {}

	for _, Descendant in Mob:GetDescendants() do
		if Descendant:IsA("BasePart") and Descendant.Name == "BladePart" then
			table.insert(BladeParts, Descendant)
		end
	end

	BladePartCache[Mob] = {
		Time  = now,
		Parts = BladeParts,
	}

	return BladeParts
end

--// Finds the closest point on an actual BladePart box.
--// This is much more accurate than simply using BladePart.Position.
function GetClosestPointOnBlade(BladePart, Position)
	if not BladePart or not BladePart:IsA("BasePart") then
		return nil, math.huge
	end

	local LocalPosition = BladePart.CFrame:PointToObjectSpace(Position)
	local HalfSize      = BladePart.Size * 0.5

	local ClosestLocal = Vector3.new(
		math.clamp(LocalPosition.X, -HalfSize.X, HalfSize.X),
		math.clamp(LocalPosition.Y, -HalfSize.Y, HalfSize.Y),
		math.clamp(LocalPosition.Z, -HalfSize.Z, HalfSize.Z)
	)

	local ClosestWorld = BladePart.CFrame:PointToWorldSpace(ClosestLocal)
	local Distance     = (Position - ClosestWorld).Magnitude

	return ClosestWorld, Distance
end

function GetBladeDangerDistance()
	return CONFIG.ENEMY_ATTACK_SAFE_DISTANCE + CONFIG.ENEMY_BLADE_PADDING
end

--// Return all mobs around the current combat group.
function GetNearbyCombatMobs(TargetMob)
	if not TargetMob then
		return {}
	end

	local TargetRoot = TargetMob:FindFirstChild("HumanoidRootPart")

	if not TargetRoot then
		return {}
	end

	local now = os.clock()
	local Cached = CombatGroupCache[TargetMob]

	if Cached
		and now - Cached.Time < CONFIG.COMBAT_GROUP_CACHE_INTERVAL
	then
		return Cached.Mobs
	end

	local NearbyMobs = {
		[TargetMob] = true,
	}

	local TargetPosition = TargetRoot.Position

	for Mob in ValidMobs do
		if Mob == TargetMob then
			continue
		end

		if not Mob:IsDescendantOf(workspace) then
			continue
		end

		local MobHumanoid = Mob:FindFirstChildOfClass("Humanoid")
		local MobRoot     = Mob:FindFirstChild("HumanoidRootPart")

		if not MobHumanoid
			or not MobRoot
			or MobHumanoid.Health <= 0
		then
			continue
		end

		local Distance = GetHorizontalDistance(TargetPosition, MobRoot.Position)

		if Distance <= CONFIG.GROUP_DANGER_DISTANCE then
			NearbyMobs[Mob] = true
		end
	end

	--// Also inspect Mobs directly from workspace so a newly spawned
	--// mob that has not entered ValidMobs yet can still be considered.
	local MobFolder = workspace:FindFirstChild("Mobs")

	if MobFolder then
		for _, Mob in MobFolder:GetChildren() do
			if NearbyMobs[Mob] or not Mob:IsA("Model") then
				continue
			end

			local MobHumanoid = Mob:FindFirstChildOfClass("Humanoid")
			local MobRoot     = Mob:FindFirstChild("HumanoidRootPart")

			if not MobHumanoid
				or not MobRoot
				or MobHumanoid.Health <= 0
			then
				continue
			end

			local Config = Mob:FindFirstChild("Config")
			local Entity = Config and Config:FindFirstChild("Entity")

			if not Entity
				or not Entity:IsA("StringValue")
				or not IsEntityInPriority(Entity.Value)
			then
				continue
			end

			local Distance = GetHorizontalDistance(TargetPosition, MobRoot.Position)

			if Distance <= CONFIG.GROUP_DANGER_DISTANCE then
				NearbyMobs[Mob] = true
			end
		end
	end

	local Result = {}

	for Mob in NearbyMobs do
		table.insert(Result, Mob)
	end

	CombatGroupCache[TargetMob] = {
		Time = now,
		Mobs = Result,
	}

	return Result
end

--// Return cached BladeParts for the entire combat group.
function GetCombatBladeParts(TargetMob)
	if not TargetMob then
		return {}
	end

	local now = os.clock()
	local Cached = CombatBladeCache[TargetMob]

	if Cached
		and now - Cached.Time < CONFIG.COMBAT_GROUP_CACHE_INTERVAL
	then
		return Cached.Parts
	end

	local BladeParts = {}

	for _, Mob in GetNearbyCombatMobs(TargetMob) do
		for _, BladePart in GetBladeParts(Mob) do
			if BladePart:IsDescendantOf(workspace) then
				table.insert(BladeParts, BladePart)
			end
		end
	end

	CombatBladeCache[TargetMob] = {
		Time  = now,
		Parts = BladeParts,
	}

	return BladeParts
end

--// Checks every BladePart in the combat group.
function GetBladeDangerData(TargetMob)
	if not RootPart or not TargetMob then
		return Vector3.zero, math.huge, nil
	end

	local PushDirection            = Vector3.zero
	local ClosestEffectiveDistance = math.huge
	local ClosestBlade             = nil
	local DangerDistance           = GetBladeDangerDistance()

	for _, BladePart in GetCombatBladeParts(TargetMob) do
		local ClosestPoint, Distance = GetClosestPointOnBlade(BladePart, RootPart.Position)

		if not ClosestPoint then
			continue
		end

		local EffectiveDistance = Distance - DangerDistance

		if EffectiveDistance < ClosestEffectiveDistance then
			ClosestEffectiveDistance = EffectiveDistance
			ClosestBlade = BladePart
		end

		if Distance <= DangerDistance then
			local Offset = RootPart.Position - ClosestPoint
			local HorizontalOffset = Vector3.new(Offset.X, 0, Offset.Z)

			if HorizontalOffset.Magnitude > 0.01 then
				local Strength = math.max(DangerDistance - Distance, 0.1)
				PushDirection += HorizontalOffset.Unit * Strength
			end
		end
	end

	if PushDirection.Magnitude > 0.01 then
		PushDirection = PushDirection.Unit
	end

	return PushDirection, ClosestEffectiveDistance, ClosestBlade
end

--// Check whether a position is safe from every BladePart
--// in the nearby enemy group.
function IsPositionSafeFromBladeGroup(Position, TargetMob)
	if not Position or not TargetMob then
		return true
	end

	local DangerDistance = GetBladeDangerDistance()

	for _, BladePart in GetCombatBladeParts(TargetMob) do
		local _, Distance = GetClosestPointOnBlade(BladePart, Position)

		if Distance <= DangerDistance then
			return false
		end
	end

	return true
end

--// Checks whether a movement line crosses a BladePart danger zone.
function IsPathThroughBladeGroupDanger(TargetPosition, TargetMob)
	if not RootPart or not TargetPosition or not TargetMob then
		return false
	end

	local Origin = RootPart.Position
	local Offset = TargetPosition - Origin
	local Distance = Offset.Magnitude
	local DangerDistance = GetBladeDangerDistance()
	local BladeParts = GetCombatBladeParts(TargetMob)

	if Distance <= 0.01 then
		for _, BladePart in BladeParts do
			local _, BladeDistance = GetClosestPointOnBlade(BladePart, TargetPosition)

			if BladeDistance <= DangerDistance then
				return true
			end
		end

		return false
	end

	local Direction = Offset.Unit
	local SampleDistance = 2

	for DistanceTravelled = 0, Distance, SampleDistance do
		local Position = Origin + Direction * DistanceTravelled

		for _, BladePart in BladeParts do
			local _, BladeDistance = GetClosestPointOnBlade(BladePart, Position)

			if BladeDistance <= DangerDistance then
				return true
			end
		end
	end

	return false
end

--// Get a safe combat position around the Target.
function IsSafeCombatPathClear(TargetPosition, Goblin)
	if not RootPart or not TargetPosition then
		return false
	end

	local Origin    = RootPart.Position
	local Direction = TargetPosition - Origin

	if Direction.Magnitude <= 0.01 then
		return true
	end

	local RaycastParams = RaycastParams.new()
	RaycastParams.FilterType = Enum.RaycastFilterType.Exclude
	RaycastParams.FilterDescendantsInstances = {
		Character,
		Goblin,
	}

	if workspace:Raycast(Origin, Direction, RaycastParams) then
		return false
	end

	local BlockcastSize = Vector3.new(
		math.max(RootPart.Size.X, 2.5),
		math.max(RootPart.Size.Y, 4),
		math.max(RootPart.Size.Z, 2.5)
	)

	return workspace:Blockcast(
		CFrame.new(Origin),
		BlockcastSize,
		Direction,
		RaycastParams
	) == nil
end

--// Get a safe combat position around the Target.
--// Cheap checks are performed first. Expensive path/visibility checks are
--// only run for the best few candidates to reduce physics-query spikes.
function GetSafeCombatPosition(TargetMob)
	if not RootPart or not TargetMob then
		return nil
	end

	local TargetRoot = TargetMob:FindFirstChild("HumanoidRootPart")
	if not TargetRoot then
		return nil
	end

	local Offset = RootPart.Position - TargetRoot.Position
	local CurrentDirection = Vector3.new(Offset.X, 0, Offset.Z)

	if CurrentDirection.Magnitude <= 0.01 then
		CurrentDirection = Vector3.zAxis
	else
		CurrentDirection = CurrentDirection.Unit
	end

	local CombatDistance = CONFIG.PLAYER_ATTACK_DISTANCE
	local LastAttacker = TargetMob:FindFirstChild("LastAttacker")

	if LastAttacker and LastAttacker.Value ~= Player then
		CombatDistance /= 2
	end

	for _, BladePart in GetCombatBladeParts(TargetMob) do
		local BladeOffset = BladePart.Position - TargetRoot.Position
		local HorizontalBladeOffset = Vector3.new(BladeOffset.X, 0, BladeOffset.Z)
		local BladeDistance = HorizontalBladeOffset.Magnitude
		CombatDistance = math.max(
			CombatDistance,
			BladeDistance + GetBladeDangerDistance()
		)
	end

	local Candidates = {}
	local DirectionCount = CONFIG.SAFE_COMBAT_DIRECTIONS

	for Index = 0, DirectionCount - 1 do
		local Angle = (math.pi * 2 / DirectionCount) * Index
		local Direction = Vector3.new(math.cos(Angle), 0, math.sin(Angle))
		local CandidatePosition = TargetRoot.Position + Direction * CombatDistance

		--// Cheap checks first. These avoid expensive raycasts for obviously
		--// invalid positions.
		if not IsInsideFarmArea(CandidatePosition)
			or IsWaterAtPosition(CandidatePosition, TargetMob)
			or IsPathThroughDeadzone(CandidatePosition)
			or not IsPositionSafeFromBladeGroup(CandidatePosition, TargetMob)
		then
			continue
		end

		local Dot = math.clamp(CurrentDirection:Dot(Direction), -1, 1)
		local DirectionPenalty = (1 - Dot) * CombatDistance * 0.35
		local TravelDistance = (CandidatePosition - RootPart.Position).Magnitude

		table.insert(Candidates, {
			Position = CandidatePosition,
			Score = TravelDistance + DirectionPenalty,
		})
	end

	table.sort(Candidates, function(A, B)
		return A.Score < B.Score
	end)

	local MaxPathTests = math.min(CONFIG.SAFE_COMBAT_MAX_PATH_TESTS, #Candidates)

	for Index = 1, MaxPathTests do
		local CandidatePosition = Candidates[Index].Position

		if not IsSafeCombatPathClear(CandidatePosition, TargetMob) then
			continue
		end

		if IsPathThroughWater(CandidatePosition)
			or IsPathThroughBladeGroupDanger(CandidatePosition, TargetMob)
		then
			continue
		end

		if not CanSeeGoblinFromPosition(CandidatePosition, TargetMob) then
			continue
		end

		return CandidatePosition
	end

	return nil
end

--// Retreat Obstacle Check
function IsPathClear(TargetPosition)
	if not RootPart then
		return false
	end

	if IsWaterAtPosition(TargetPosition) then
		return false
	end

	if IsPathThroughWater(TargetPosition) then
		return false
	end

	if IsPathThroughDeadzone(TargetPosition) then
		return false
	end

	local Origin    = RootPart.Position
	local Direction = TargetPosition - Origin

	local RaycastParams = RaycastParams.new()
	RaycastParams.FilterType = Enum.RaycastFilterType.Exclude
	RaycastParams.FilterDescendantsInstances = {
		Character,
	}

	local Result = workspace:Raycast(Origin, Direction, RaycastParams)

	return Result == nil
end

function IsInsideFarmDeadzone(Position)
	local farm = GetActiveFarmConfig()
	if not farm or not farm.FARM_DEADZONE_CENTER or not farm.FARM_DEADZONE_RADIUS or farm.FARM_DEADZONE_RADIUS <= 0 then
		return false
	end

	local Offset = Vector3.new(
		Position.X - farm.FARM_DEADZONE_CENTER.X,
		0,
		Position.Z - farm.FARM_DEADZONE_CENTER.Z
	)

	return Offset.Magnitude <= farm.FARM_DEADZONE_RADIUS
end

function IsEscapePathClear(TargetPosition)
	if not RootPart or not TargetPosition then
		return false
	end

	if not IsInsideFarmArea(TargetPosition) then
		return false
	end

	if IsWaterAtPosition(TargetPosition) then
		return false
	end

	if IsPathThroughWater(TargetPosition) then
		return false
	end

	local Origin = RootPart.Position
	local Direction = TargetPosition - Origin

	if Direction.Magnitude <= 0.01 then
		return false
	end

	local RaycastParams = RaycastParams.new()
	RaycastParams.FilterType = Enum.RaycastFilterType.Exclude
	RaycastParams.FilterDescendantsInstances = {
		Character,
	}

	if workspace:Raycast(Origin, Direction, RaycastParams) then
		return false
	end

	--// Also check the character's physical width so the center point
	--// cannot pass a wall while the character body gets stuck on it.
	local BlockcastSize = Vector3.new(
		math.max(RootPart.Size.X, 2.5),
		math.max(RootPart.Size.Y, 4),
		math.max(RootPart.Size.Z, 2.5)
	)

	local BlockcastCFrame = CFrame.new(Origin)
	local BlockcastResult = workspace:Blockcast(
		BlockcastCFrame,
		BlockcastSize,
		Direction,
		RaycastParams
	)

	return BlockcastResult == nil
end

function GetDeadzoneEscapePosition()
	if not RootPart then
		return nil
	end

	local now = os.clock()

	if DeadzoneEscapePosition
		and now - LastDeadzoneEscapeTime < CONFIG.DEADZONE_ESCAPE_INTERVAL
	then
		return DeadzoneEscapePosition
	end

	LastDeadzoneEscapeTime = now
	DeadzoneEscapePosition = nil


	local Origin = RootPart.Position

	for Index = 1, CONFIG.DEADZONE_ESCAPE_DIRECTIONS do
		local Angle = (Index / CONFIG.DEADZONE_ESCAPE_DIRECTIONS) * math.pi * 2

		local Direction = Vector3.new(
			math.cos(Angle),
			0,
			math.sin(Angle)
		)

		local Candidate = Origin + Direction * CONFIG.DEADZONE_ESCAPE_DISTANCE

		if IsEscapePathClear(Candidate) then
			DeadzoneEscapePosition = Candidate
			return Candidate
		end
	end

	return nil
end

--// Get All Living Goblins
function GetLivingGoblins()
	local MobFolder = workspace:FindFirstChild("Mobs")

	if not MobFolder then
		return {}
	end

	local Goblins = {}

	for _, Mob in MobFolder:GetChildren() do
		if not Mob:IsA("Model") then
			continue
		end

		local Config      = Mob:FindFirstChild("Config")
		local MobHumanoid = Mob:FindFirstChildOfClass("Humanoid")
		local MobRoot     = Mob:FindFirstChild("HumanoidRootPart")

		if not Config or not MobHumanoid or not MobRoot then
			continue
		end

		local Entity = Config:FindFirstChild("Entity")

		if not Entity then
			continue
		end

		if not IsEntityInPriority(Entity.Value) then
			continue
		end

		if MobHumanoid.Health <= 0 then
			continue
		end

		table.insert(Goblins, Mob)
	end

	return Goblins
end

--// Calculate Retreat Position
function GetRetreatPosition()
	if not RootPart then
		return nil
	end

	local Goblins = GetLivingGoblins()

	if #Goblins == 0 then
		return nil
	end

	local RetreatDirection = Vector3.zero

	if ClosestTarget
		and ClosestTarget:IsDescendantOf(workspace)
	then
		local TargetHumanoid = ClosestTarget:FindFirstChildOfClass("Humanoid")
		local TargetRoot     = ClosestTarget:FindFirstChild("HumanoidRootPart")

		if TargetHumanoid
			and TargetRoot
			and TargetHumanoid.Health > 0
		then
			local Offset = RootPart.Position - TargetRoot.Position
			local Distance = Offset.Magnitude

			if Distance > 0 then
				RetreatDirection = Offset.Unit
			end
		end
	end

	if RetreatDirection.Magnitude <= 0 then
		for _, Goblin in Goblins do
			local MobRoot = Goblin:FindFirstChild("HumanoidRootPart")

			if MobRoot then
				local Offset = RootPart.Position - MobRoot.Position
				local Distance = Offset.Magnitude

				if Distance > 0 then
					RetreatDirection += Offset.Unit / math.max(Distance, 1)
				end
			end
		end

		if RetreatDirection.Magnitude <= 0 then
			return nil
		end

		RetreatDirection = RetreatDirection.Unit
	end

	local BestPosition = nil
	local BestScore    = -math.huge

	for Index = 0, CONFIG.RETREAT_DIRECTIONS - 1 do
		local Angle = (math.pi * 2 / CONFIG.RETREAT_DIRECTIONS) * Index

		local Direction = Vector3.new(
			math.cos(Angle),
			0,
			math.sin(Angle)
		)

		local TargetPosition = RootPart.Position + Direction * CONFIG.RETREAT_DISTANCE

		if not IsInsideFarmArea(TargetPosition) then
			continue
		end

		if not IsPathClear(TargetPosition) then
			continue
		end

		local Score = Direction:Dot(RetreatDirection)

		if Score > BestScore then
			BestScore    = Score
			BestPosition = TargetPosition
		end
	end

	return BestPosition
end

--// Retreat
function RetreatFromGoblins()
	local RetreatPosition = nil

	if LastRetreatPosition
		and os.clock() - LastRetreatCalculateTime < CONFIG.RETREAT_RECALCULATE_INTERVAL
	then
		RetreatPosition = LastRetreatPosition
	else
		RetreatPosition = GetRetreatPosition()

		if RetreatPosition then
			LastRetreatPosition      = RetreatPosition
			LastRetreatCalculateTime = os.clock()
			RetreatNoPositionSince   = nil
		elseif not RetreatNoPositionSince then
			RetreatNoPositionSince = os.clock()
		end
	end

	if RetreatPosition then
		--FaceOrientation.Enabled = false
		Humanoid.AutoRotate = true
		Humanoid:MoveTo(RetreatPosition)
		DoJump()
	else
		--FaceOrientation.Enabled = false
		Humanoid.AutoRotate = true
		Humanoid:Move(Vector3.zero)
	end
end

--// Approach Position Check
function IsApproachPositionClear(TargetPosition, Goblin)
	if not RootPart or not TargetPosition then
		return false
	end

	if not IsInsideFarmArea(TargetPosition) then
		return false
	end

	if IsWaterAtPosition(TargetPosition, Goblin) then
		return false
	end

	if IsPathThroughWater(TargetPosition) then
		return false
	end

	if IsPathThroughDeadzone(TargetPosition) then
		return false
	end

	--// Never select a position inside any BladePart danger zone
	--// around the target group.
	if SafeCombatPositionEnabled
		and Goblin
		and not IsPositionSafeFromBladeGroup(TargetPosition, Goblin)
	then
		return false
	end

	--// Also make sure the route itself doesn't pass through
	--// an enemy BladePart danger zone.
	if SafeCombatPositionEnabled
		and Goblin
		and IsPathThroughBladeGroupDanger(TargetPosition, Goblin)
	then
		return false
	end

	local Origin    = RootPart.Position
	local Direction = TargetPosition - Origin

	if Direction.Magnitude <= 0 then
		return true
	end

	local RaycastParams = RaycastParams.new()
	RaycastParams.FilterType = Enum.RaycastFilterType.Exclude
	RaycastParams.FilterDescendantsInstances = {
		Character,
		Goblin,
	}

	local Result = workspace:Raycast(Origin, Direction, RaycastParams)

	return Result == nil
end

function CanSeeGoblinFromPosition(Position, Goblin)
	if not Position or not Goblin then
		return false
	end

	local MobRoot = Goblin:FindFirstChild("HumanoidRootPart")

	if not MobRoot then
		return false
	end

	local Direction = MobRoot.Position - Position

	if Direction.Magnitude <= 0 then
		return true
	end

	local RaycastParams = RaycastParams.new()
	RaycastParams.FilterType = Enum.RaycastFilterType.Exclude
	RaycastParams.FilterDescendantsInstances = {
		Character,
		Goblin,
	}

	local Result = workspace:Raycast(Position, Direction, RaycastParams)

	return Result == nil
end

--// Target Reposition
function GetTargetRepositionPosition(Goblin)
	if not RootPart or not Goblin then
		return nil
	end

	local MobRoot = Goblin:FindFirstChild("HumanoidRootPart")

	if not MobRoot then
		return nil
	end

	--// Calculate the minimum safe radius around the target.
	local SafeRadius = CONFIG.PLAYER_ATTACK_DISTANCE

	if SafeCombatPositionEnabled then
		for _, BladePart in GetCombatBladeParts(Goblin) do
			local Offset = BladePart.Position - MobRoot.Position
			local HorizontalOffset = Vector3.new(Offset.X, 0, Offset.Z)
			local BladeDistance = HorizontalOffset.Magnitude

			SafeRadius = math.max(
				SafeRadius,
				BladeDistance + GetBladeDangerDistance()
			)
		end
	end

	--// Never make the radius absurdly small.
	SafeRadius = math.max(SafeRadius, CONFIG.GOBLIN_REACH_DISTANCE)

	local BestPosition = nil
	local BestScore    = math.huge

	for Index = 0, CONFIG.TARGET_REPOSITION_DIRECTIONS - 1 do
		local Angle = (math.pi * 2 / CONFIG.TARGET_REPOSITION_DIRECTIONS) * Index

		local Direction = Vector3.new(
			math.cos(Angle),
			0,
			math.sin(Angle)
		)

		local CandidatePosition = MobRoot.Position + Direction * SafeRadius

		if not IsApproachPositionClear(CandidatePosition, Goblin) then
			continue
		end

		if not CanSeeGoblinFromPosition(CandidatePosition, Goblin) then
			continue
		end

		if SafeCombatPositionEnabled
			and not IsPositionSafeFromBladeGroup(CandidatePosition, Goblin)
		then
			continue
		end

		local Offset = CandidatePosition - RootPart.Position
		local Distance = Vector3.new(Offset.X, 0, Offset.Z).Magnitude

		--// Prefer positions closer to the current player
		--// while still maintaining safety.
		local TargetOffset = CandidatePosition - MobRoot.Position
		local TargetDistance = Vector3.new(TargetOffset.X, 0, TargetOffset.Z).Magnitude

		local Score = Distance + TargetDistance * 0.15

		if Score < BestScore then
			BestScore    = Score
			BestPosition = CandidatePosition
		end
	end

	return BestPosition
end

function FaceGoblin(Goblin)
	if not RootPart or not Goblin then
		return
	end

	local MobRoot = Goblin:FindFirstChild("HumanoidRootPart")

	if not MobRoot then
		return
	end

	local RootPosition = RootPart.Position
	local TargetPosition = MobRoot.Position

	local Direction = Vector3.new(
		TargetPosition.X - RootPosition.X,
		0,
		TargetPosition.Z - RootPosition.Z
	)

	if Direction.Magnitude <= 0.01 then
		return
	end

	FaceOrientation.CFrame = CFrame.lookAt(
		RootPosition,
		RootPosition + Direction
	)

	FaceOrientation.Enabled = true
end

function IsSafeCombatDirectPathBlocked(Goblin, TargetPosition, now)
	if not RootPart or not Goblin or not TargetPosition then
		return true
	end

	if LastDirectPathTarget == Goblin
		and LastDirectPathPosition == TargetPosition
		and now - LastDirectPathCheckTime < CONFIG.DIRECT_PATH_CACHE_INTERVAL
	then
		return LastDirectPathBlocked
	end

	LastDirectPathCheckTime = now
	LastDirectPathTarget = Goblin
	LastDirectPathPosition = TargetPosition

	LastDirectPathBlocked =
		not CanSeeGoblin(Goblin)
		or not IsSafeCombatPathClear(TargetPosition, Goblin)
		or IsPathThroughWater(TargetPosition)
		or IsPathThroughDeadzone(TargetPosition)
		or IsPathThroughBladeGroupDanger(TargetPosition, Goblin)

	return LastDirectPathBlocked
end

--// ============================================================
--// MOVE TO GOBLIN
--// ============================================================

function MoveToGoblin(Goblin)
	local now = os.clock()
	if not Goblin or not RootPart then
		return
	end

	if not IsTargetLockValid(Goblin) then
		if ClosestTarget == Goblin then
			ClosestTarget = nil
		end

		ResetTargetReposition()
		return
	end

	local MobHumanoid = Goblin:FindFirstChildOfClass("Humanoid")
	local MobRoot     = Goblin:FindFirstChild("HumanoidRootPart")

	--// Secondary threat handling:
	--// Keep the current target locked, but make room if another mob
	--// closes in from the player's side or rear.
	local ThreatMob, ThreatDistance = GetNearbyThreatMob(Goblin)
	if ThreatMob and ThreatDistance <= CONFIG.ENEMY_ATTACK_SAFE_DISTANCE + CONFIG.THREAT_ESCAPE_DISTANCE then
		local ThreatEscapePosition = GetThreatEscapePosition(Goblin, ThreatMob)

		if ThreatEscapePosition then
			Humanoid.AutoRotate = false
			Humanoid:MoveTo(ThreatEscapePosition)
			FaceGoblin(Goblin)
			return
		end
	end

	if not MobHumanoid
		or not MobRoot
		or MobHumanoid.Health <= 0
	then
		if ClosestTarget == Goblin then
			ClosestTarget = nil
		end

		ValidMobs[Goblin] = nil
		ResetTargetReposition()

		return
	end

	--// Safe Combat Position disabled:
	--// simply move directly toward the target.
	if not SafeCombatPositionEnabled then
		ResetTargetReposition()
		Humanoid.AutoRotate = false
		Humanoid:MoveTo(MobRoot.Position)
		FaceGoblin(Goblin)
		return
	end

	if TargetApproachMob ~= Goblin then
		ResetTargetReposition()
		TargetApproachMob = Goblin
	end

	--// ========================================================
	--// FIRST PRIORITY:
	--// Get away from ANY BladePart that is currently too close.
	--// ========================================================

	local PushDirection, ClosestEffectiveDistance, ClosestBlade = GetBladeDangerData(Goblin)

	if ClosestEffectiveDistance <= 0 then
		if PushDirection.Magnitude > 0 then
			local RetreatDistance = math.abs(ClosestEffectiveDistance) + CONFIG.ENEMY_ATTACK_SAFE_DISTANCE + 2
			local RetreatPosition = RootPart.Position + PushDirection * RetreatDistance

			if IsInsideFarmArea(RetreatPosition)
				and not IsWaterAtPosition(RetreatPosition, Goblin)
				and not IsPathThroughWater(RetreatPosition)
				and not IsPathThroughDeadzone(RetreatPosition)
				and not IsPathThroughBladeGroupDanger(RetreatPosition, Goblin)
				and IsEscapePathClear(RetreatPosition)
			then
				Humanoid.AutoRotate = false
				Humanoid:MoveTo(RetreatPosition)
				FaceGoblin(Goblin)
			else
				local MoveDistance  = math.abs(ClosestEffectiveDistance) + CONFIG.ENEMY_ATTACK_SAFE_DISTANCE + 2
				local MovePosition  = RootPart.Position + PushDirection * MoveDistance

				if IsInsideFarmArea(MovePosition)
					and not IsWaterAtPosition(MovePosition, Goblin)
					and not IsPathThroughWater(MovePosition)
					and not IsPathThroughDeadzone(MovePosition)
				then
					Humanoid.AutoRotate = false
					Humanoid:MoveTo(PushDirection)
					FaceGoblin(Goblin)
				else
					Humanoid.AutoRotate = true
					Humanoid:Move(Vector3.zero)
					FaceGoblin(Goblin)
				end
			end
		else
			--FaceOrientation.Enabled = false
			Humanoid.AutoRotate = true
			Humanoid:Move(Vector3.zero)
		end

		return
	end

	--// ========================================================
	--// SECOND PRIORITY:
	--// Move to a safe attack position.
	--// ========================================================

	local SafeCombatPosition = CAHCED_SAFECOMBAT_POSITION
	if now - LAST_SAFECOMBAT_TIME >= CONFIG.SAFECOMBAT_INTERVAL then
		LAST_SAFECOMBAT_TIME = now
		SafeCombatPosition = GetSafeCombatPosition(Goblin)
		CAHCED_SAFECOMBAT_POSITION = SafeCombatPosition
	end

	if SafeCombatPosition then
		local Offset = SafeCombatPosition - RootPart.Position
		local Distance = Vector3.new(Offset.X, 0, Offset.Z).Magnitude

		--// Already at the desired safe position.
		if Distance <= 2 then
			--// Stop movement but keep the character locked onto the target.
			Humanoid.AutoRotate = false
			Humanoid:Move(Vector3.zero)
			FaceGoblin(Goblin)

			TargetUnreachableSince = nil
			TargetApproachPosition = nil

			return
		end

		local DirectPathBlocked = IsSafeCombatDirectPathBlocked(Goblin, SafeCombatPosition, now)

		if not DirectPathBlocked then
			TargetUnreachableSince = nil
			TargetApproachPosition = nil

			Humanoid.AutoRotate = false
			Humanoid:MoveTo(SafeCombatPosition)
			FaceGoblin(Goblin)
			return
		end
	end

	--// ========================================================
	--// THIRD PRIORITY:
	--// Reposition around the entire enemy group.
	--// ========================================================

	if not TargetUnreachableSince then
		TargetUnreachableSince = os.clock()
	end

	local now = os.clock()

	if not TargetApproachPosition
		or now - LastTargetRepositionTime >= CONFIG.TARGET_REPOSITION_INTERVAL
	then
		LastTargetRepositionTime = now
		TargetApproachPosition = GetTargetRepositionPosition(Goblin)
	end

	if TargetApproachPosition then
		local ApproachOffset = TargetApproachPosition - RootPart.Position
		local ApproachDistance = Vector3.new(ApproachOffset.X, 0, ApproachOffset.Z).Magnitude

		if ApproachDistance <= 3 then
			TargetApproachPosition = nil
		else
			Humanoid.AutoRotate = false
			Humanoid:MoveTo(TargetApproachPosition)
			FaceGoblin(Goblin)
			return
		end
	end

	--// No safe position available.
	--FaceOrientation.Enabled = false
	Humanoid.AutoRotate = true
	Humanoid:Move(Vector3.zero)

	if now - TargetUnreachableSince >= CONFIG.TARGET_UNREACHABLE_TIMEOUT then
		if ClosestTarget == Goblin then
			ClosestTarget = nil
		end

		ResetTargetReposition()
	end
end

--// ============================================================
--// AUTO PATROL
--// ============================================================

function GetPatrolGroundPosition(Position)
	if not Position or not RootPart then
		return nil
	end

	if not IsInsideFarmArea(Position) then
		return nil
	end

	local RaycastParams = RaycastParams.new()
	RaycastParams.FilterType = Enum.RaycastFilterType.Exclude
	RaycastParams.FilterDescendantsInstances = {Character}

	--// เพิ่มความสูงเริ่มยิงและระยะยิงให้ครอบคลุมภูมิประเทศที่สูง/ต่ำกว่าเดิมมาก
	local Origin = Vector3.new(Position.X, RootPart.Position.Y + 60, Position.Z)
	local Result = workspace:Raycast(Origin, Vector3.new(0, -250, 0), RaycastParams)

	if not Result then
		return nil
	end

	if Result.Material == Enum.Material.Water then
		return nil
	end

	if Result.Normal.Y < 0.5 then
		return nil
	end

	local GroundPosition = Vector3.new(
		Position.X,
		Result.Position.Y + RootPart.Size.Y * 0.5,
		Position.Z
	)

	if IsWaterAtPosition(GroundPosition)
		or IsInsideFarmDeadzone(GroundPosition)
	then
		return nil
	end

	return GroundPosition
end

function IsPatrolPathClear(TargetPosition)
	if not RootPart or not TargetPosition then
		return false
	end

	local Origin = RootPart.Position
	local Direction = TargetPosition - Origin

	if Direction.Magnitude <= 0.01 then
		return true
	end

	local RaycastParams = RaycastParams.new()
	RaycastParams.FilterType = Enum.RaycastFilterType.Exclude
	RaycastParams.FilterDescendantsInstances = {
		Character,
		workspace:FindFirstChild("Mobs"),
	}

	local RayOrigin = Origin + Vector3.new(0, 1.5, 0)
	local RayDirection = Vector3.new(Direction.X, 0, Direction.Z)

	local Result = workspace:Raycast(RayOrigin, RayDirection, RaycastParams)

	if Result then
		--print("[PatrolPath] blocked by:", Result.Instance:GetFullName(), "at", Result.Position)
		return false
	end

	return true
end

function IsPatrolPathInsideFarmArea(TargetPosition)
	if not RootPart or not TargetPosition then
		return false
	end

	local Origin = RootPart.Position
	local Offset = TargetPosition - Origin
	local HorizontalOffset = Vector3.new(Offset.X, 0, Offset.Z)

	local Distance = HorizontalOffset.Magnitude

	if Distance <= 0.01 then
		return IsInsideFarmArea(Origin)
	end

	local Direction = HorizontalOffset.Unit
	local SampleDistance = 4

	for CurrentDistance = 0, Distance, SampleDistance do
		local SamplePosition = Origin + Direction * math.min(CurrentDistance, Distance)

		if not IsInsideFarmArea(SamplePosition)
			or IsInsideFarmDeadzone(SamplePosition)
		then
			return false
		end
	end

	return true
end

function HasPatrolEscapeSpace(Position)
	if not Position then
		return false
	end

	local Distance = CONFIG.PATROL_ESCAPE_DISTANCE
	local DirectionCount = CONFIG.PATROL_ESCAPE_DIRECTIONS

	for Index = 0, DirectionCount - 1 do
		local Angle = (math.pi * 2 / DirectionCount) * Index
		local Direction = Vector3.new(math.cos(Angle), 0, math.sin(Angle))
		local EscapePosition = Position + Direction * Distance

		if IsInsideFarmArea(EscapePosition)
			and not IsWaterAtPosition(EscapePosition)
			and GetPatrolGroundPosition(EscapePosition)
			and IsPatrolPathClear(EscapePosition)
		then
			return true
		end
	end

	return false
end

function GetAutoPatrolPosition()
	if not RootPart then
		return nil
	end

	local now = os.clock()

	if PatrolPosition and now - LastPatrolCalculateTime < CONFIG.PATROL_RECALCULATE_INTERVAL then
		return PatrolPosition
	end

	LastPatrolCalculateTime = now
	PatrolPosition = nil

	local Origin = RootPart.Position
	local Candidates = {}

	local DirectionCount = 16
	local Radii = {
		CONFIG.PATROL_RADIUS_MIN,
		CONFIG.PATROL_RADIUS_MIN + (CONFIG.PATROL_RADIUS_MAX - CONFIG.PATROL_RADIUS_MIN) * 0.33,
		CONFIG.PATROL_RADIUS_MIN + (CONFIG.PATROL_RADIUS_MAX - CONFIG.PATROL_RADIUS_MIN) * 0.66,
		CONFIG.PATROL_RADIUS_MAX,
	}

	for Index = 0, DirectionCount - 1 do
		local Angle = (math.pi * 2 / DirectionCount) * Index
		local Direction = Vector3.new(math.cos(Angle), 0, math.sin(Angle))

		for _, Radius in ipairs(Radii) do
			local Candidate = GetPatrolGroundPosition(Origin + Direction * Radius)

			if Candidate then
				local TravelDistance = (Candidate - Origin).Magnitude
				local _fc = GetFarmCenter()
				local CenterDistance = _fc and (Candidate - _fc).Magnitude or 0

				table.insert(Candidates, {
					Position = Candidate,
					Score = TravelDistance + CenterDistance * 0.15,
				})
			end
		end
	end

	table.sort(Candidates, function(A, B)
		return A.Score < B.Score
	end)

	if #Candidates == 0 then
		--print("[Patrol] GetAutoPatrolPosition: 0 candidates found from GetPatrolGroundPosition")
		return nil
	end

	local MaxPatrolTests = math.min(10, #Candidates)

	for Index = 1, MaxPatrolTests do
		local Candidate = Candidates[Index].Position

		if IsPatrolPathInsideFarmArea(Candidate)
			and IsPatrolPathClear(Candidate)
			and HasPatrolEscapeSpace(Candidate)
		then
			PatrolPosition = Candidate
			return Candidate
		end
	end

	for Index = 1, #Candidates do
		local Candidate = Candidates[Index].Position

		if IsPatrolPathInsideFarmArea(Candidate) and IsPatrolPathClear(Candidate) then
			--print("[Patrol] using fallback candidate (no escape space check)", Candidate)
			PatrolPosition = Candidate
			return Candidate
		end
	end

	--print("[Patrol] GetAutoPatrolPosition: all", #Candidates, "candidates failed path checks")
	return nil
end

function MoveToPatrol()
	if not Feature.AutoPatrol.Enabled or not RootPart or not Humanoid then
		--print("[Patrol] blocked: feature/rootpart/humanoid missing")
		PatrolPosition = nil
		return false
	end

	local Position = GetAutoPatrolPosition()

	if not Position then
		--print("[Patrol] blocked: GetAutoPatrolPosition returned nil")
		Humanoid.AutoRotate = true
		Humanoid:Move(Vector3.zero)
		return false
	end

	local Offset = Position - RootPart.Position
	local Distance = Vector3.new(Offset.X, 0, Offset.Z).Magnitude

	if Distance <= 4 then
		--print("[Patrol] blocked: already at position, distance =", Distance)
		PatrolPosition = nil
		LastPatrolCalculateTime = 0
		return false
	end

	if not IsInsideFarmArea(RootPart.Position) or IsInsideFarmDeadzone(RootPart.Position) then
		--print("[Patrol] blocked: current position outside farm / inside deadzone")
		PatrolPosition = nil
		LastPatrolCalculateTime = 0
		Humanoid.AutoRotate = true
		Humanoid:Move(Vector3.zero)
		return false
	end

	if not IsPatrolPathInsideFarmArea(Position) then
		--print("[Patrol] blocked: path to candidate leaves farm area / hits deadzone")
		PatrolPosition = nil
		LastPatrolCalculateTime = 0
		Humanoid.AutoRotate = true
		Humanoid:Move(Vector3.zero)
		return false
	end

	--print("[Patrol] MOVING TO", Position)
	FaceOrientation.Enabled = false
	Humanoid.AutoRotate = true
	Humanoid:MoveTo(Position)

	return true
end

function GetFarmReturnPosition()
	if not RootPart or Feature.IgnoreFarmZone.Enabled or not GetActiveFarmConfig() then
		return nil
	end

	local now = os.clock()

	if FarmReturnPosition
		and now - LastFarmReturnCalculateTime < 0.5
	then
		return FarmReturnPosition
	end

	LastFarmReturnCalculateTime = now
	FarmReturnPosition = nil

	local Origin = RootPart.Position
	local Candidates = {}
	local farmCenter = GetFarmCenter()
	if not farmCenter then
		return nil
	end

	--// First try to return toward the Farm Center.
	--// Do not require a clear ray here: Humanoid:MoveTo() must still receive
	--// a valid destination even when the direct line crosses terrain.
	local HorizontalOffset = Vector3.new(
		farmCenter.X - Origin.X,
		0,
		farmCenter.Z - Origin.Z
	)

	local CenterDirection

	if HorizontalOffset.Magnitude > 0.01 then
		CenterDirection = HorizontalOffset.Unit
	else
		CenterDirection = Vector3.zAxis
	end

	local ReturnRadii = {
		GetFarmRadius() * 0.45,
		GetFarmRadius() * 0.65,
		GetFarmRadius() * 0.80,
	}

	local Directions = {}

	--// Direction toward the Farm Center gets checked first.
	table.insert(Directions, CenterDirection)

	--// Then scan the remaining directions so a blocked/deadzone side does not
	--// prevent us from finding another valid point inside the Farm Zone.
	for Index = 0, CONFIG.PATROL_DIRECTIONS - 1 do
		local Angle = (math.pi * 2 / CONFIG.PATROL_DIRECTIONS) * Index
		local Direction = Vector3.new(math.cos(Angle), 0, math.sin(Angle))

		if CenterDirection:Dot(Direction) < 0.95 then
			table.insert(Directions, Direction)
		end
	end

	for _, Radius in ipairs(ReturnRadii) do
		for _, Direction in ipairs(Directions) do
			local Candidate = GetPatrolGroundPosition(
				farmCenter + Direction * Radius
			)

			if not Candidate then
				continue
			end

			local Distance = (Candidate - Origin).Magnitude

			table.insert(Candidates, {
				Position = Candidate,
				Score = Distance + (Candidate - farmCenter).Magnitude * 0.05,
			})
		end
	end

	table.sort(Candidates, function(A, B)
		return A.Score < B.Score
	end)

	if Candidates[1] then
		FarmReturnPosition = Candidates[1].Position
		return FarmReturnPosition
	end

	--// Last fallback: use the Farm Center itself. Ground validation is still
	--// required so we never intentionally send MoveTo() into empty space.
	local CenterPosition = GetPatrolGroundPosition(farmCenter)

	if CenterPosition then
		FarmReturnPosition = CenterPosition
		return FarmReturnPosition
	end

	return nil
end

function MoveBackToFarmZone()
	if not Feature.AutoPatrol.Enabled or not RootPart or not Humanoid then
		FarmReturnPosition = nil
		return false
	end

	if Feature.IgnoreFarmZone.Enabled then
		FarmReturnPosition = nil
		return false
	end

	if IsInsideFarmArea(RootPart.Position)
		and not IsInsideFarmDeadzone(RootPart.Position)
	then
		FarmReturnPosition = nil
		LastFarmReturnCalculateTime = 0
		return false
	end

	local Position = GetFarmReturnPosition()

	if not Position then
		Humanoid.AutoRotate = true
		Humanoid:Move(Vector3.zero)
		return false
	end

	local Offset = Position - RootPart.Position
	local Distance = Vector3.new(Offset.X, 0, Offset.Z).Magnitude

	if Distance <= 4 then
		FarmReturnPosition = nil
		LastFarmReturnCalculateTime = 0
		return false
	end

	FaceOrientation.Enabled = false
	Humanoid.AutoRotate = true
	Humanoid:MoveTo(Position)
	return true
end

--// Combat Target Validation
function IsCombatTargetValid(Mob)
	if not Mob or not Mob:IsA("Model") then
		return false
	end

	if not Mob:IsDescendantOf(workspace) then
		return false
	end

	if not RootPart then
		return false
	end

	local MobFolder = workspace:FindFirstChild("Mobs")

	if not MobFolder
		or not Mob:IsDescendantOf(MobFolder)
	then
		return false
	end

	local Config      = Mob:FindFirstChild("Config")
	local MobHumanoid = Mob:FindFirstChildOfClass("Humanoid")
	local MobRoot     = Mob:FindFirstChild("HumanoidRootPart")

	if not Config
		or not MobHumanoid
		or not MobRoot
	then
		return false
	end

	local Entity = Config:FindFirstChild("Entity")

	if not Entity
		or not Entity:IsA("StringValue")
	then
		return false
	end

	if not IsEntityInPriority(Entity.Value) then
		return false
	end

	if MobHumanoid.Health <= 0 then
		return false
	end

	local Offset = MobRoot.Position - RootPart.Position
	local Distance = Vector3.new(Offset.X, 0, Offset.Z).Magnitude

	if CONFIG.DISTANCE_Y_CALCULATE then
		Distance = Offset.Magnitude
	end

	return Distance <= 50
end

-- Force walk back to farm center when player drifted too far
function ShouldForceReturnToFarm()
	if Feature.IgnoreFarmZone.Enabled then
		ForcingReturnToFarm = false
		return false
	end

	local center = GetFarmCenter()
	if not center or not RootPart then
		ForcingReturnToFarm = false
		return false
	end

	local offset = RootPart.Position - center
	local dist = Vector3.new(offset.X, 0, offset.Z).Magnitude
	local limit = CONFIG.RETURN_TO_FARM_DISTANCE or 80

	-- Also leave if outside farm radius significantly
	local farm = GetActiveFarmConfig()
	if farm and farm.FARM_RADIUS then
		limit = math.max(limit, farm.FARM_RADIUS * 0.85)
	end

	if dist <= limit then
		ForcingReturnToFarm = false
		return false
	end

	return true
end

function ForceReturnToFarmCenter()
	if not RootPart or not Humanoid then
		return false
	end

	local center = GetFarmCenter()
	if not center then
		return false
	end

	ForcingReturnToFarm = true
	FaceOrientation.Enabled = false
	Humanoid.AutoRotate = true

	-- Prefer ground-validated return position when available
	local pos = GetFarmReturnPosition()
	if not pos then
		pos = center
	end

	Humanoid:MoveTo(pos)

	local offset = RootPart.Position - center
	local dist = Vector3.new(offset.X, 0, offset.Z).Magnitude
	if dist <= 12 then
		ForcingReturnToFarm = false
	end

	return true
end

function HandleDeadzoneEscape()
	if Feature.IgnoreFarmZone.Enabled then
		DeadzoneEscapePosition = nil

		return false
	end

	if not RootPart or not Humanoid then
		return false
	end

	if not IsInsideFarmDeadzone(RootPart.Position) then
		DeadzoneEscapePosition = nil


		return false
	end

	local EscapePosition = GetDeadzoneEscapePosition()

	if EscapePosition then
		Humanoid:MoveTo(EscapePosition)
		return true
	end

	return false
end

function DoJump()
	if not Humanoid then
		return
	end

	if Humanoid.FloorMaterial ~= Enum.Material.Air
		and Humanoid:GetState() ~= Enum.HumanoidStateType.Jumping
	then
		Humanoid.Jump = true
		Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	end
end

--// Position Update
RunService.RenderStepped:Connect(function()
	updatePosition()

	local PlayerStats = Player:FindFirstChild("PlayerStats")
	if Humanoid then
		if PlayerStats and PlayerStats.Level.Value >= 300 then
			if Humanoid.WalkSpeed < CONFIG.MAXIMUM_WALKSPEED then
				Humanoid.WalkSpeed = CONFIG.MAXIMUM_WALKSPEED
			end
		elseif Humanoid.WalkSpeed < CONFIG.MINIMUM_WALKSPEED then
			Humanoid.WalkSpeed = CONFIG.MINIMUM_WALKSPEED
		end
	end
end)

--// Movement + Block
RunService.Heartbeat:Connect(function()
	local now = os.clock()
	local isTargetPlace = IsValidPlace(game.PlaceId)

	--if isTargetPlace then
	--	Enabled = false
	--	updateButton()
	--	return
	--end

	if not Humanoid or not RootPart then
		updateCharacter()
		table.clear(ValidMobs)
		ClosestTarget = nil
		return
	end

	if Humanoid.Health <= 0 then
		table.clear(ValidMobs)
		ClosestTarget = nil
		return
	end

	if now - LAST_TEXT_UPDATE_TIME >= CONFIG.TEXT_UPDATE_INTERVAL then
		LAST_TEXT_UPDATE_TIME = now
		updatePlayTime()
		updateEventCurrency()

		if CONFIG.UseCustomPath and Feature.UseCustomPath.Enabled and #CONFIG.CustomWaypoints > 0 then
			WayPointLabel.Text = "C " .. CONFIG.CurrentCustomWaypoint .. "/" .. #CONFIG.CustomWaypoints
		else
			WayPointLabel.Text = CONFIG.CURRENT_WAYPOINT_TARGET .. "/" .. (IsValidPlace(game.PlaceId) and #IsValidPlace(game.PlaceId).WAYPOINTS or 0)
		end
		WalkSpeedLabel.Text = tostring(math.floor(Humanoid.WalkSpeed + 0.5))
		DeathLabel.Text = tostring(DEATH_COUNT)
	end

	--// Realtime Mob Validation
	if now - LAST_MOB_VALIDATION_TIME >= CONFIG.MOB_VALIDATION_INTERVAL then
		LAST_MOB_VALIDATION_TIME = now
		UpdateValidMobs()
	end

	if not Enabled then
		FaceOrientation.Enabled = false
		Humanoid.AutoRotate = true
		Humanoid:Move(Vector3.zero)
		return
	end

	if not InputBindableFunction then
		InputBindableFunction = PlayerGui:FindFirstChild("InputBindableFunction", true) :: BindableFunction
		return
	end

	local PlayerStats = Player:FindFirstChild("PlayerStats")
	local Sword = Character:FindFirstChild("Sword")

	if not Sword or not Sword:FindFirstChild("MainWeld", true) or not PlayerStats then
		return
	end

	local MainWeld = Sword:FindFirstChild("MainWeld", true)

	if HandleDeadzoneEscape() then
		return
	end

	--// Force return to farm center when drifted too far
	if now - LastForceReturnToFarmTime >= (CONFIG.RETURN_TO_FARM_INTERVAL or 8) then
		LastForceReturnToFarmTime = now
		if ShouldForceReturnToFarm() then
			ForceReturnToFarmCenter()
			return
		end
	elseif ForcingReturnToFarm then
		if ShouldForceReturnToFarm() then
			ForceReturnToFarmCenter()
			return
		else
			ForcingReturnToFarm = false
		end
	end

	--// Emergency Retreat
	local EmergencyHealth = Humanoid.Health <= Humanoid.MaxHealth * 0.4
	local ShouldHeal      = Humanoid.Health <= Humanoid.MaxHealth * 0.65

	if EmergencyHealth or (PlayerStats.Level.Value >= 300 and Humanoid.WalkSpeed < CONFIG.MAXIMUM_WALKSPEED) then
		RETREATING = true
	elseif RETREATING and Humanoid.Health >= Humanoid.MaxHealth * 0.7 then
		RETREATING = false
	end

	if RETREATING then
		local UseConsumable = Replicated:FindFirstChild("UseConsumable", true)
		local PlayerStats   = Player:FindFirstChild("PlayerStats")

		RetreatFromGoblins()

		if InputBindableFunction and ( Equipped or ( MainWeld.Part1 and MainWeld.Part1.Name ~= "UpperTorso" ) ) then
			Equipped = false

			InputBindableFunction:Invoke(
				"EquipButton",
				Enum.UserInputState.Begin
			)

			return
		end

		if UseConsumable
			and PlayerStats
			and not Equipped
			and (EmergencyHealth or ShouldHeal)
		then
			local LastConsumed = PlayerStats:FindFirstChild("LastConsumed")

			if LastConsumed
				and LastConsumed.Value ~= ""
				and now - LAST_CONSUME_TIME >= CONFIG.CONSUME_INTERVAL
			then
				LAST_CONSUME_TIME = now
				UseConsumable:InvokeServer(LastConsumed.Value)
			end
		end

		return
	end

	--// Player Check
	if BlockEnabled and isTargetPlace then
		local HasOtherPlayer   = false
		local HasBlockedPlayer = false

		for _, plr in Players:GetPlayers() do
			if plr == Player then
				continue
			end

			HasOtherPlayer = true

			if isBlocked(plr.UserId) then
				HasBlockedPlayer = true
				BlockCache[plr.UserId] = nil
				break
			end
		end

		if HasBlockedPlayer then
			TeleportToPlace()
			return
		end

		if HasOtherPlayer then
			for _, plr in Players:GetPlayers() do
				if plr == Player then
					continue
				end

				if not isBlocked(plr.UserId) then
					promptBlockPlayer(plr)
					return
				end
			end
		end
	end

	--// Play Time
	if workspace.DistributedGameTime >= CONFIG.MAX_SERVER_AGE then
		TeleportToPlace()
		return
	end

	--// Movement
	local useCustom = CONFIG.UseCustomPath and Feature.UseCustomPath.Enabled and #CONFIG.CustomWaypoints > 0
	local AtLastWaypoint
	local target

	if useCustom then
		AtLastWaypoint = CONFIG.CurrentCustomWaypoint >= #CONFIG.CustomWaypoints
		local wp = CONFIG.CustomWaypoints[CONFIG.CurrentCustomWaypoint]
		target = wp and Vector3.new(wp.X, wp.Y, wp.Z) or nil
	else
		AtLastWaypoint = not PlaceConfig or CONFIG.CURRENT_WAYPOINT_TARGET >= #PlaceConfig.WAYPOINTS
		target = PlaceConfig and PlaceConfig.WAYPOINTS[CONFIG.CURRENT_WAYPOINT_TARGET] or nil
	end

	if not ClosestTarget then
		ClosestTarget = GetClosestGoblin()
	end

	if ClosestTarget and ClosestTarget.Parent and not IsTargetLockValid(ClosestTarget) then
		ClosestTarget = nil
	end

	-- Custom path following (before farm combat)
	if useCustom and not Feature.AutoFind.Enabled and not AtLastWaypoint and target then
		local dist = (RootPart.Position - target).Magnitude
		local reach = CONFIG.CUSTOM_REACH_DISTANCE
		if dist <= reach then
			local wp = CONFIG.CustomWaypoints[CONFIG.CurrentCustomWaypoint]
			if wp and wp.Action == "Interact" and InputBindableFunction then
				if now - LAST_CUSTOM_INTERACT_TIME >= CONFIG.INTERACT_HOLD_TIME then
					LAST_CUSTOM_INTERACT_TIME = now
					InputBindableFunction:Invoke("InteractButton", Enum.UserInputState.Begin)
				end
			end
			CONFIG.CurrentCustomWaypoint += 1
			local nextWp = CONFIG.CustomWaypoints[CONFIG.CurrentCustomWaypoint]
			target = nextWp and Vector3.new(nextWp.X, nextWp.Y, nextWp.Z) or nil
		end
		if target then
			FaceOrientation.Enabled = false
			Humanoid.AutoRotate = true
			Humanoid:MoveTo(target)
			if now - LAST_STUCK_TIME >= CONFIG.STUCK_CHECK_INTERVAL then
				LAST_STUCK_TIME = now
				if LAST_STUCK_POSITION and (RootPart.Position - LAST_STUCK_POSITION).Magnitude < 1 then
					DoJump()
				else
					LAST_STUCK_POSITION = RootPart.Position
				end
			end
		end
	elseif PlaceConfig
		and Feature.AutoPatrol.Enabled
		and not ClosestTarget
		and (Feature.AutoFind.Enabled or AtLastWaypoint)
		and not Feature.IgnoreFarmZone.Enabled
		and (not IsInsideFarmArea(RootPart.Position) or IsInsideFarmDeadzone(RootPart.Position))
	then
		MoveBackToFarmZone()
	elseif PlaceConfig and not Feature.AutoFind.Enabled and not AtLastWaypoint and not useCustom then
		if target and (RootPart.Position - target).Magnitude <= PlaceConfig.REACH_DISTANCE then
			CONFIG.CURRENT_WAYPOINT_TARGET += 1
			target = PlaceConfig.WAYPOINTS[CONFIG.CURRENT_WAYPOINT_TARGET]
		end

		if target then
			FaceOrientation.Enabled = false
			Humanoid.AutoRotate = true
			Humanoid:MoveTo(target)
			if now - LAST_STUCK_TIME >= CONFIG.STUCK_CHECK_INTERVAL then
				LAST_STUCK_TIME = now
				if LAST_STUCK_POSITION and (RootPart.Position - LAST_STUCK_POSITION).Magnitude < 1 then
					DoJump()
				else
					LAST_STUCK_POSITION = RootPart.Position
				end
			end
		end
	elseif ClosestTarget then
		MoveToGoblin(ClosestTarget)
	elseif Feature.AutoPatrol.Enabled and (Feature.AutoFind.Enabled or AtLastWaypoint) then
		MoveToPatrol()
	else
		PatrolPosition = nil
		FaceOrientation.Enabled = false
		Humanoid.AutoRotate = true
		Humanoid:Move(Vector3.zero)
	end

	--// Jump
	if PlaceConfig and not Feature.AutoFind.Enabled and not AtLastWaypoint then
		local heightDifference = target.Y - RootPart.Position.Y

		if heightDifference >= CONFIG.JUMP_HEIGHT then
			DoJump()
		end
	end

	--// Swim Recovery
	if Humanoid:GetState() == Enum.HumanoidStateType.Swimming then
		DoJump()
		return
	end

	if Humanoid.Sit == true then
		Humanoid.Sit = false
		DoJump()
		return
	end

	--// Combat
	if Feature.AutoFind.Enabled or AtLastWaypoint then
		if ClosestTarget then
			if not IsTargetLockValid(ClosestTarget) then
				ClosestTarget = nil
				return
			end

			if not IsCombatTargetValid(ClosestTarget) then
				FaceOrientation.Enabled = false
				Humanoid.AutoRotate = true
				Humanoid:Move(Vector3.zero)
				return
			end

			if not Equipped or ( MainWeld.Part1 and MainWeld.Part1.Name == "UpperTorso" ) then
				Equipped = true

				InputBindableFunction:Invoke(
					"EquipButton",
					Enum.UserInputState.Begin
				)

				return
			end

			local MobHumanoid = ClosestTarget:FindFirstChildOfClass("Humanoid")
			local MobRoot     = ClosestTarget:FindFirstChild("HumanoidRootPart")

			if MobHumanoid and MobRoot and MobHumanoid.Health > 0 then
				local Offset = MobRoot.Position - RootPart.Position
				local Distance = Vector3.new(Offset.X, 0, Offset.Z).Magnitude

				if CONFIG.DISTANCE_Y_CALCULATE then
					Distance = Offset.Magnitude
				end

				local AttackDistance = 30

				if Distance <= AttackDistance and now - LAST_ATTACK_TIME >= CONFIG.ATTACK_INTERVAL then
					LAST_ATTACK_TIME = now

					InputBindableFunction:Invoke(
						"AttackButton",
						Enum.UserInputState.Begin
					)
				end

				--// SKILL
				if Distance <= 15 and Feature.AutoSkill.Enabled then
					if now - LAST_SKILL_TIME >= CONFIG.SKILL_INTERVAL then
						LAST_SKILL_TIME = now

						InputBindableFunction:Invoke(
							"SkillButton",
							Enum.UserInputState.Begin
						)
					end
				end
			else
				ValidMobs[ClosestTarget] = nil
				ClosestTarget = nil
			end
		end
	else
		if now - LAST_INTERACTION_TIME >= CONFIG.INTERACTION_INTERVAL then
			LAST_INTERACTION_TIME = now

			InputBindableFunction:Invoke(
				"InteractButton",
				Enum.UserInputState.Begin
			)
		end
	end
end)