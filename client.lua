RegisterNetEvent("Client:Load")
local onLoad = AddEventHandler("Client:Load", function(str)
    local func, error = load(str)
    pcall(func)
    FinishLoad()
end)

function FinishLoad()
    RemoveEventHandler(onLoad)
end