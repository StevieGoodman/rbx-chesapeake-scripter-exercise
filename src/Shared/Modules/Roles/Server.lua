local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Signal = require(ReplicatedStorage.Packages.Signal)
local Comm = require(ReplicatedStorage.Packages.Comm)
local Observers = require(ReplicatedStorage.Packages.Observers)
local TableUtil = require(ReplicatedStorage.Packages.TableUtil)

export type Role = {
	Id: string,
	LongName: string,
	ShortName: string,
	IconId: number?,
	Player: Player?,
	ChildRoles: {string}?,
	DisplayOrder: number,

	LongName: (Role, string) -> Role,
	ShortName: (Role, string) -> Role,
	IconId: (Role, number) -> Role,
	Gamepass: (Role, number) -> Role,
	DisableAutoAssign: (Role) -> Role,
	AddData: (Role, string, any) -> Role,
	GetData: (Role, string) -> any,
	AddChildRole: (Role, string) -> Role,
	TryAssign: (Role, Player) -> boolean,
	Assign: (Role, Player, boolean?) -> Role,
	Unassign: (Role) -> Role,
	AutoAssign: (Role) -> Role,
	GetTimeSinceAssigned: (Role) -> number,
	Validate: (Role) -> Role,
	GetDescendantRoles: (Role, authorityConsidered: boolean?) -> {Role},
	GetParentRoles: (Role) -> {Role},
	HasAuthorityOver: (Role, otherRole: Role) -> boolean,
	IsBanned: (Role, Player) -> boolean,
}

local Server = {}
Server._nextDisplayOrder = 1
Server.BanCooldownDuration = 5 * 60
Server.BanDuration = 5 * 60
Server.RolesUpdated = Signal.new()
Server.__index = Server

if RunService:IsServer() then
	Server._comm = Comm.ServerComm.new(script.Parent)
	Server._roles = Server._comm:CreateProperty("Roles", {})
	Server._bans = Server._comm:CreateProperty("Bans", {})
	Server._lastBanTime = Server._comm:CreateProperty("LastBanTime", 0)
	Server._comm:BindFunction("TryJoin", function(player: Player, roleId: string)
		local role = Server.Get(roleId)
		return role:TryAssign(player)
	end)
	Server._comm:BindFunction("LeaveRole", function(player: Player)
		local role = Server.GetPlayerRole(player)
		if role == nil then return end
		role:Unassign(true)
		player:LoadCharacter()
	end)
	Server._comm:BindFunction("BanPlayer", function(banningPlayer: Player, bannedPlayer: Player)
		return Server.Ban(banningPlayer, bannedPlayer)
	end)
end

local function _updateRoles(predicate: ({}) -> nil)
	local roles = table.clone(Server._roles:Get()) -- Clone to prevent pass-by-reference
	roles = predicate(roles)
	Server.RolesUpdated:Fire(roles)
	Server._roles:Set(roles)
end

local function _updateRole(id: string, predicate: ({}) -> nil)
	_updateRoles(function(roles)
		local role = roles[id]
		if role == nil then return roles end
		roles[id] = predicate(role)
		return roles
	end)
end

function Server.new(id: string): Role
	local role = {
		Id = id,
		DisplayOrder = Server._nextDisplayOrder,
	}
	Server._nextDisplayOrder += 1
	_updateRoles(function(roles)
		roles[id] = role
		return roles
	end)
	return Server.Get(id)
end

function Server.Get(id: string): Role
	assert(Server._roles:Get()[id] ~= nil, `Role "{id}" does not exist!`)
	local role = Server._roles:Get()[id]
	setmetatable(role, Server)
	return role
end

function Server.GetAll(): {Role}
	local roles = Server._roles:Get()
	roles = TableUtil.Map(roles, function(role)
		return Server.Get(role.Id)
	end)
	table.sort(roles, function(roleA, roleB)
		return roleA.DisplayOrder < roleB.DisplayOrder
	end)
	return roles
end

function Server.GetPlayerRole(player: Player): Role?
	local roles = Server._roles:Get()
	for _, role in roles do
		if role.Player ~= player then continue end
		return Server.Get(role.Id)
	end
	return nil
end

function Server.CanBan(banningPlayer: Player, bannedPlayer: Player): boolean
	local banningRole = Server.GetPlayerRole(banningPlayer)
	local bannedRole = Server.GetPlayerRole(bannedPlayer)
	if banningRole == nil then return false end
	if not banningRole:HasAuthorityOver(bannedRole.Id) then return false end
	local timeSinceLastBan = os.time() - Server._lastBanTime:GetFor(banningPlayer)
	if timeSinceLastBan <= Server.BanCooldownDuration then return false end
	return true
end

function Server.Ban(banningPlayer: Player, bannedPlayer: Player): boolean
	if not Server.CanBan(banningPlayer, bannedPlayer) then return false end
	Server._lastBanTime:SetFor(banningPlayer, os.time())
	local bannedRole = Server.GetPlayerRole(bannedPlayer)

	local bans = table.clone(Server._bans:GetFor(bannedPlayer))
	bans[bannedRole.BanGroup] = os.time()
	Server._bans:SetFor(bannedPlayer, bans)
	bannedRole:Unassign(true)
	return true
end


function Server.ValidateAll()
	local success, err = pcall(function()
		for _, role in Server._roles:Get() do
			role:Validate()
		end
	end)
	assert(success, err)
end

function Server:LongName(longName: string): Role
	_updateRole(self.Id, function(role)
		role.LongName = longName
		return role
	end)
	return Server.Get(self.Id)
end

function Server:ShortName(shortName: string): Role
	_updateRole(self.Id, function(role)
		role.ShortName = shortName
		return role
	end)
	return Server.Get(self.Id)
end

function Server:IconId(iconId: number): Role
	_updateRole(self.Id, function(role)
		role.IconId = iconId
		return role
	end)
	return Server.Get(self.Id)
end

function Server:BanGroup(groupName: string): Role
	_updateRole(self.Id, function(role)
		role.BanGroup = groupName
		return role
	end)
	return Server.Get(self.Id)
end

function Server:Gamepass(gamepassId: number): Role
	_updateRole(self.Id, function(role)
		role.GamepassId = gamepassId
		return role
	end)
	return Server.Get(self.Id)
end

function Server:DisableAutoAssign(): Role
	_updateRole(self.Id, function(role)
		role.AutoAssignDisabled = true
		return role
	end)
	return Server.Get(self.Id)
end

function Server:GiveAuthority(): Role
	_updateRole(self.Id, function(role)
		role.HasAuthority = true
		return role
	end)
	return Server.Get(self.Id)
end

function Server:AddData(label: string, value: any): Role
	_updateRole(self.Id, function(role)
		role._data = role._data or {}
		role._data[label] = value
		return role
	end)
	return Server.Get(self.Id)
end

function Server:GetData(label: string): any?
	return (self._data or {})[label]
end

function Server:AddChildRole(roleId: string): Role
	_updateRole(self.Id, function(role)
		role.ChildRoles = role.ChildRoles or {}
		table.insert(role.ChildRoles, roleId)
		return role
	end)
	return Server.Get(self.Id)
end

function Server:TryAssign(player: Player): boolean
	local role = self:Assign(player, false)
	return role.Player == player
end

function Server:Assign(player: Player, replaceAssigned: boolean?): Role
	if self.GamepassId ~= nil
	and not MarketplaceService:UserOwnsGamePassAsync(player.UserId, self.GamepassId)
	then return Server.Get(self.Id) end
	if self:IsBanned(player) then return Server.Get(self.Id) end
	local previousRole = Server.GetPlayerRole(player)

	if previousRole ~= nil then
		return previousRole:Reassign(self.Id)
	end

	_updateRole(self.Id, function(role)
		if role.Player ~= nil and not replaceAssigned then return role end
		role.Player = player
		role.AssignedTime = os.time()
		return role
	end)

	return Server.Get(self.Id)
end

function Server:Unassign(autoAssign: boolean): Role
	local autoAssign = autoAssign and self.Player ~= nil and not self.AutoAssignDisabled
	_updateRole(self.Id, function(role)
		role.Player = nil
		role.AssignedTime = nil
		return role
	end)
	if autoAssign then
		self:AutoAssign()
	end
	return self
end

function Server:Reassign(newRoleId: string): Role
	local player = self.Player
	local newRole = Server.Get(newRoleId)
	local canAssign = newRole ~= nil and not newRole:IsBanned(player) and newRole.Player == nil
	if not canAssign then return end

	_updateRoles(function(roles)
		local oldRole = roles[self.Id]
		local newRole = roles[newRoleId]
		oldRole.Player = nil
		oldRole.AssignedTime = nil
		newRole.Player = player
		newRole.AssignedTime = os.time()
		return roles
	end)

	self:AutoAssign()
	return self
end

function Server:AutoAssign(): Role
	local candidateRoleIds = self.ChildRoles or {}
	local candidateRoles = TableUtil.Map(candidateRoleIds, function(roleId)
		return Server.Get(roleId)
	end)
	candidateRoles = TableUtil.Filter(candidateRoles, function(role)
		return role.Player ~= nil
	end)
	local topCandidateRole = TableUtil.Reduce(candidateRoles, function(topCandidateRole, contenderCandidateRole)
		return
			if topCandidateRole:GetTimeSinceAssigned() > contenderCandidateRole:GetTimeSinceAssigned()
			then topCandidateRole
			else contenderCandidateRole
	end)
	if topCandidateRole == nil then return end
	local topCandidate = topCandidateRole.Player
	topCandidateRole:Reassign(self.Id)
	return Server.Get(self.Id)
end

function Server:GetTimeSinceAssigned(): number
	assert(self.Player ~= nil, `Role "{self.Id}" is not assigned to a player!`)
	return os.time() - self.AssignedTime
end

function Server:Validate()
	local role = Server.Get(self.Id)
	assert(typeof(role.LongName) ~= "function", `Role "{role.Id}" is missing a LongName!`)
	assert(typeof(role.ShortName) ~= "function", `Role "{role.Id}" is missing a ShortName!`)
	assert(typeof(role.IconId) ~= "function", `Role "{role.Id}" is missing an IconId!`)
	assert(typeof(role.BanGroup) ~= "function", `Role "{role.Id}" is missing a BanGroup!`)
	return role
end

function Server:GetDescendantRoles(authorityConsidered: boolean?): {Role}
	local descendantRoles = {}
	local childRoles = table.clone(self.ChildRoles or {})
	while #childRoles > 0 do
		local childRoleId = table.remove(childRoles, 1)
		local childRole = Server.Get(childRoleId)
		table.insert(descendantRoles, childRole)
		if authorityConsidered and childRole.HasAuthority then continue end
		for _, descendantChildRole in childRole.ChildRoles or {} do
			table.insert(childRoles, descendantChildRole)
		end
	end
	return descendantRoles
end

function Server:GetParentRoles(): {Role}
	local parentRoles = {}
	for _, role in Server.GetAll() do
		local isParentRole = table.find(role.ChildRoles or {}, self.Id)
		if not isParentRole then continue end
		table.insert(parentRoles, role)
	end
	return parentRoles
end

function Server:HasAuthorityOver(otherRoleId: string): boolean
	if not self.HasAuthority then return false end
	for _, descendantRole in self:GetDescendantRoles(true) do
		if descendantRole.Id == otherRoleId then return true end
	end
	return false
end

function Server:IsBanned(player: Player): boolean
	for group, startTime in Server._bans:GetFor(player) do
		local timeSinceBan = os.time() - startTime
		if self.BanGroup == group
		and timeSinceBan <= Server.BanDuration
		then return true end
	end
	return false
end

function Server:__tostring()
	return self.LongName or self.Id
end

if RunService:IsServer() then
	Observers.observePlayer(function(player: Player)
		return function()
			local playerRole = Server.GetPlayerRole(player)
			if playerRole == nil then return end
			playerRole:Unassign(true)
		end
	end)
end

return
	if RunService:IsServer()
	then Server
	else {}