local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cmdr = require(ReplicatedStorage.Packages.Cmdr)

return function(_)
    local commands = Cmdr.Registry:GetCommands()
    local response = ""
    for _, info in commands do
        response ..= `{info.Name}: {info.Description}\n`
    end
    return string.gsub(response, "\n", -2)
end