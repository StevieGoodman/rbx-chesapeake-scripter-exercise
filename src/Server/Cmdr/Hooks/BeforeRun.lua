function hook(_)
    warn("BeforeRun hook has not been implemented yet.")
end

function register(registry)
    registry:RegisterHook("BeforeRun", hook)
end

return register