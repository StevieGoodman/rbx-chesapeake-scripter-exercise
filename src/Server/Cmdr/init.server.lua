local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cmdr = require(ReplicatedStorage.Packages.Cmdr)
local Knit = require(ReplicatedStorage.Packages.Knit)

local success, result = Knit:OnStart():await()
assert(success, `Failed to start Cmdr on the server: {result}`)

Cmdr:RegisterCommandsIn(script.Commands)
Cmdr:RegisterHooksIn(script.Hooks)
-- Cmdr:RegisterTypesIn(script.Types)
print("Cmdr has successfully started on the server!")