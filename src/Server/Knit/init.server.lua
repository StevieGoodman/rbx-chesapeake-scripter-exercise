local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

Knit.AddServices(script)
local success, result = Knit.Start():await()
assert(success, `Failed to start Knit on the server: {result}`)
print("Knit has successfully started on the server!")