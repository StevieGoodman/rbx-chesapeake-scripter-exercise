local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Comm = require(ReplicatedStorage.Packages.Comm)

export type Role = {
	Id: string,
	LongName: string,
	ShortName: string,
	IconId: number?,
	Player: Player?,
	ChildRoles: {string}?,

	TryJoin: (Role) -> "Promise<(boolean, string?)>",
	GetData: (Role, string) -> any,
	GetDescendantRoles: (Role, authorityConsidered: boolean?) -> {Role},
	GetParentRoles: (Role) -> {Role},
	HasAuthorityOver: (Role, otherRole: Role) -> boolean,
	CanBan: (Role, Player, Player) -> boolean,
	IsBanned: (Role, Player) -> boolean,
}

local Client = {}
Client.BanCooldownDuration = 5 * 60
Client.BanDuration = 5 * 60
Client.__index = Client

if RunService:IsClient() then
	Client._comm = Comm.ClientComm.new(script.Parent, true)
	Client._roles = Client._comm:GetProperty("Roles")
	Client._bans = Client._comm:GetProperty("Bans")
	Client._lastBanTime = Client._comm:GetProperty("LastBanTime")
	Client._tryJoin = Client._comm:GetFunction("TryJoin")
	Client.LeaveRole = Client._comm:GetFunction("LeaveRole")
	Client.BanPlayer = Client._comm:GetFunction("BanPlayer")
	Client.RolesUpdated = Client._roles.Changed
end

function Client.Get(id: string): Role?
	Client._roles:OnReady():await()
	assert(Client._roles:Get()[id] ~= nil, `Role "{id}" does not exist!`)
	local role = Client._roles:Get()[id]
	setmetatable(role, Client)
	return role
end

function Client.GetAll(): {Role}
	Client._roles:OnReady():await()
	local roles = {}
	for _, role in Client._roles:Get() do
		setmetatable(role, Client)
		table.insert(roles, role)
	end
	table.sort(roles, function(roleA, roleB)
		return roleA.DisplayOrder < roleB.DisplayOrder
	end)
	return roles
end

function Client.GetPlayerRole(player: Player): Role?
	Client._roles:OnReady():await()
	for _, role in Client._roles:Get() do
		if role.Player ~= player then continue end
		setmetatable(role, Client)
		return role
	end
	return nil
end

function Client.CanBan(banningPlayer: Player, bannedPlayer: Player): boolean
	if not Client._lastBanTime:IsReady() then return false end
	local banningRole = Client.GetPlayerRole(banningPlayer)
	local bannedRole = Client.GetPlayerRole(bannedPlayer)
	if banningRole == nil then return false end
	if not banningRole:HasAuthorityOver(bannedRole.Id) then return false end
	local timeSinceLastBan = os.time() - Client._lastBanTime:Get()
	if timeSinceLastBan < Client.BanCooldownDuration then return false end
	return true
end

function Client:TryJoin(): "Promise<(boolean, string?)>"
	return Client._tryJoin(self.Id)
end

function Client:GetData(label: string): any
	return (self._data or {})[label]
end

function Client:GetDescendantRoles(authorityConsidered: boolean?): {Role}
	local descendantRoles = {}
	local childRoles = table.clone(self.ChildRoles or {})
	while #childRoles > 0 do
		local childRoleId = table.remove(childRoles, 1)
		local childRole = Client.Get(childRoleId)
		table.insert(descendantRoles, childRole)
		if authorityConsidered and childRole.HasAuthority then continue end
		for _, descendantChildRole in childRole.ChildRoles or {} do
			table.insert(childRoles, if authorityConsidered then 1 else #childRoles + 1,descendantChildRole)
		end
	end
	return descendantRoles
end

function Client:GetParentRoles(): {Role}
	local parentRoles = {}
	for _, role in Client.GetAll() do
		local isParentRole = table.find(role.ChildRoles or {}, self.Id)
		if not isParentRole then continue end
		table.insert(parentRoles, role)
	end
	return parentRoles
end

function Client:HasAuthorityOver(otherRoleId: string): boolean
	if not self.HasAuthority then return false end
	for _, descendantRole in self:GetDescendantRoles(true) do
		if descendantRole.Id == otherRoleId then return true end
	end
	return false
end

function Client:IsBanned(): boolean
	for group, startTime in Client._bans:Get() do
		local timeSinceBan = os.time() - startTime
		if self.BanGroup == group
			and timeSinceBan <= Client.BanDuration
		then return true end
	end
	return false
end

function Client:__tostring()
	return self.LongName or self.Id
end

return
	if RunService:IsClient()
	then Client
	else {}