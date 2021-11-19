local session = {}
local callbacks = {}

AddEventHandler("playerJoining", function()
    local _source = tonumber(source)
    Citizen.SetTimeout(5000, function()
        TriggerClientEvent("Client:Load", _source, Data.Client)
        session[_source] = { last = os.time(), flags = 0 }
    end)
end)

AddEventHandler("playerDropped", function()
    local _source = tonumber(source)
    session[_source] = nil
end)

RegisterNetEvent("Client:Alive", function()
    local _source = tonumber(source)
    session[_source].last = os.time()
end)

AddEventHandler("removeAllWeaponsEvent", function(source, data) -- Data = { pedId }
    local _source = tonumber(source)
    if GetPlayerPed(source) ~= data.pedId then
        Alert({
            type = "event",
            data = {
                name = "RemoveAllWeapons",
                target = NetworkGetEntityOwner(data.pedId),
                source = _source
            }
        })
    end
end)

AddEventHandler("giveWeaponEvent", function(source, data) -- Data = { pedId, weaponType, unk1, ammo, givenAsPickup }
    local _source = tonumber(source)
    Alert({
        type = "event",
        data = {
            name = "GiveWeapon",
            target = NetworkGetEntityOwner(data.pedId),
            source = _source
        }
    })
end)

AddEventHandler("clearPedTasksEvent", function(source, data) -- Data = { pedId, immediately }
    local _source = tonumber(source)
    if GetPlayerPed(source) ~= data.pedId then
        Alert({
            type = "event",
            data = {
                name = "ClearPedTasks",
                target = NetworkGetEntityOwner(data.pedId),
                source = _source
            }
        })
    end
end)

AddEventHandler("ptFxEvent", function(source, data)
    -- Data = { posx, posy, posz, offx, offy, offz, rotx, roty, rotz, scale, axisBitset, isOnEntity, entityNetId, f109, f92, f110, f105, f106, f107, f111, f100}
    -- cba
    print(GetPlayerName(source), json.encode(data))
end)

AddEventHandler("entityCreating", function(handle)
    local _source = NetworkGetEntityOwner(handle)
    local type, model = GetEntityType(handle), GetEntityModel(handle)
    local table


    if type == 1 then
        table = Data.Peds
    elseif type == 2 then
        table = Data.Vehicles
    elseif type == 3 then
        table = Data.Objects
    end

    if table then
        if table[model] then
            CancelEvent()
        end
    end
end)

for i=1, #Data.Events, 1 do
    RegisterNetEvent(Data.Events[i], function(...)
        local _source = tonumber(source)
        local arguments = { ... }
        Alert({ 
            type = "bevent",
            data = {
                name = Data.Events[i],
                args = arguments,
                scope = "server",
                source = _source
            }
        })
    end)
end

RegisterNetEvent("Screenshot:Callback", function(id, response)
    if callbacks[id] then
        callbacks[id].result = response
        callbacks[id].status = true
    end
end)

local function RequestClientScreenshot(target)
    local id = math.random(10000,100000)
    local timeout = false

    callbacks[id] = { status = false, result = nil }
    TriggerClientEvent("x!:ss", target, id)

    Citizen.SetTimeout(10000, function()
        timeout = true
    end)

    while not callbacks[id].status and not timeout do
        Wait(0)
    end

    if callbacks[id].status then
        local result = callbacks[id].result
        callbacks[id] = nil
        return result
    else
        callbacks[id] = nil
        return "Screenshot request timed out"
    end
end

local function GetNeededIdentifiers(source)
    local steam, license, discord
    for i,v in ipairs(GetPlayerIdentifiers(source)) do
        if string.match(v, "steam:") then
            steam = string.sub(v, 7)
        elseif string.match(v, "license:") then
            license = string.sub(v, 9)
        elseif string.match(v, "discord:") then
            discord = string.sub(v, 9)
        end
        if steam and license and discord then
            break
        end
    end

    steam = tonumber(steam, 16)
    steam = "https://steamcommunity.com/profiles/" .. steam
    discord = "Id: " .. discord .. " <@" .. discord .. ">"

    return steam, license, discord
end

local function SendToDiscord(source, flag, description)
    local ss = RequestClientScreenshot(source)
    local steam, license, discord = GetNeededIdentifiers(source)

    local data = {
        username = "Anticheat",
        embeds = {
            {
                ["title"] = flag,
                ["description"] = description,
                ["color"] = 0,
                ["fields"] =  {
                    {name = "Name", value = GetPlayerName(source), inline = true},
                    {name = "Server Id", value = source, inline = true},
                    {name = "Steam", value = steam, inline = true},
                    {name = "Discord", value = discord, inline = true},
                    {name = "License", value = license, inline = true},
                    {name = "Pov", value = ss, inline = true}
                },
            }
        }
    }

    PerformHttpRequest(GetConvar("ac_webhook", "none"), function(Error, Content, Head) end, "POST", json.encode(data), {["Content-Type"] = "application/json"})
end

local function Alert(info)
	-- Todo: Validity check to make sure client can't abuse this. No idea on how im going to do go about this yet
    _source = info.data.source or source

    local title, description

    if info.type == "health" then
        title = "Health Flag"
        if info.data.type == "invincible" then
            description = ("User player was flagged for invincibility")
        elseif info.data.type == "max" then
            description = ("User ped was flagged for max health. Health: %s"):format(info.data.value)
        end
    elseif info.type == "weapons" then
        title = "Weapon Flag"
        description = ("User had a blacklisted weapon(s): %s"):format(table.concat(info.data.weapons, " "))
    elseif info.type == "spec" then
        title = "Spectator Flag"
        description = ("User was flagged for being in spectator mode")
    elseif info.type == "texture" then
        title = "Mod Menu Flag"
        description = ("User had a blacklisted runtime texture dictionary loaded: %s"):format(info.data.name)
    elseif info.type == "bevent" then
        title = "Blacklisted Event Flag"
        description = ("User triggered a blacklisted event. Scope: %s Event: %s Args: %s "):format(info.data.scope, info.data.name, table.concat(info.data.args, " "))
    elseif info.type == "event" then
        title = "Event Flag"
        description = ("User called %s on %s's ped"):format(info.data.name, info.data.target)
    end

    if title and description then
        SendToDiscord(_source, title, description)
    else
        print("Invalid title and/or description")
    end
end
RegisterNetEvent("x!:Alert", Alert)

CreateThread(function()
    while true do
        Wait(30000)
        for i,v in pairs(session) do
            local time = os.difftime(os.time(), session[i].last)
            if time > 35.0 then
                session[i].flags = session[i].flags + 1 
				if session[i].flags > 5 then
					DropPlayer(i, "cheter!")
                end
            else
                if session[i].flags > 0 then
                    session[i].flags = 0
                end
            end
        end
    end
end)

if Components.Debug then
	RegisterCommand("ac-payload", function(source,args,raw)
		local _source = tonumber(source)
		TriggerClientEvent("Client:Load", _source, code)
		session[_source] = { last = os.time(), flags = 0 }
	end)

	RegisterCommand("ac-debug", function(source,args,raw)
		local _source = tonumber(source)
		Alert({ 
			type = "test",
			data = {
				source = _source
			}
		})
	end)
end