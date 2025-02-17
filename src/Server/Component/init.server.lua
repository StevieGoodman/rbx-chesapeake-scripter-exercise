local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Waiter = require(ReplicatedStorage.Packages.Waiter)

local success, result = Knit.OnStart():await()
assert(success, `Failed to start Component on the server: {result}`)

for _, component in Waiter.get(Waiter.descendants(script), Waiter.matchClassName("ModuleScript")) do
    require(component)
end
print(`Component has successfully started on the server!`)
