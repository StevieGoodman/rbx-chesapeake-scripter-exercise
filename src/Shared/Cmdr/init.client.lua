local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cmdr = require(ReplicatedStorage:WaitForChild("CmdrClient", 60))

Cmdr:SetActivationKeys({ Enum.KeyCode.F2 })

print("Cmdr has successfully started on the client!")