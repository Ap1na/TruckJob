--[[
TruckJob - Created by Lama (fork by Ap1na)
Do not edit below if you don't know what you are doing
]] --

local ESX = nil -- ESX 
Citizen.CreateThread(function()
	while ESX == nil do
		ESX = exports["es_extended"]:getSharedObject()
		Citizen.Wait(0)
	end
end)
RegisterNetEvent('esx:playerLoaded') -- toto načte postavu prostě základ
AddEventHandler('esx:playerLoaded', function(xPlayer)
    src = xPlayer
    ESX.PlayerData = xPlayer
end)


RegisterNetEvent('esx:onPlayerLogout')
AddEventHandler('esx:onPlayerLogout', function()
	ESX.PlayerData = {}
end)

local amount = 0
local playerCoords = nil
local jobStarted = false
local truck, trailer = nil, nil
local opti

-- draw blip on the map
CreateThread(function()
    local blip = AddBlipForCoord(Config.BlipLocation.x, Config.BlipLocation.y, Config.BlipLocation.z)
    SetBlipSprite(blip, 457)
    SetBlipDisplay(blip, 4)
    SetBlipColour(blip, 21)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Truck Job")
    EndTextCommandSetBlipName(blip)
end)

CreateThread(function()
    while true do
        playerCoords = GetEntityCoords(PlayerPedId())
        Wait(500)
    end
end)

-- starting the job

CreateThread(function()
    local hideHelpText = false
    AddTextEntry("press_start_job", "Press ~INPUT_CONTEXT~ to start your shift")
    while true do
        opti = 2
        -- get distance between blip and player and check if player is near it
        if not jobStarted then
            if #(playerCoords - vector3(Config.BlipLocation.x, Config.BlipLocation.y, Config.BlipLocation.z)) <= 5 then
                if hideHelpText == false then
                    DisplayHelpTextThisFrame("press_start_job")
                end
                if IsControlPressed(1, 38) then
                    hideHelpText = true
                    HideHelpTextThisFrame()
                    local Elements = {
                        {label = "Start job", name = 'start'},
                        {label = "Cancel", name = "cancel"}
                    }
                    ESX.UI.Menu.Open("default", GetCurrentResourceName(), "Example_Menu", {
                        title = "Truck job Menu", -- The Name of Menu to show to users,
                        align    = 'top-left', -- top-left | top-right | bottom-left | bottom-right | center |
                        elements = Elements -- define elements as the pre-created table
                    }, function(data,menu) -- OnSelect Function
                        if data.current.name == "start" then
                            if ESX.PlayerData.job.name == 'trucker' then
                                if IsPedSittingInAnyVehicle(player) then
                                    ESX.ShowNotification("You cant start the job when you're in a vehicle.", true, false, red)
                                    hideHelpText = false
                                    menu.close()
                                else
                                    SpawnVehicle(Config.TruckModel, Config.DepotLocation)
                                    SetPedIntoVehicle(player, vehicle, -1)
                                    -- tell server we are starting the job
                                    TriggerServerEvent("lama_jobs:started")
                                    jobStarted = true
                                    hideHelpText = false
                                    StartJob()
                                    menu.close()
                                end
                            else
                                ESX.ShowNotification("You don't work here.", true, false, red)
                            end
                        elseif data.current.name == "cancel" then
                            hideHelpText = false
                            menu.close()
                        end
                    end)
                end
            else
                opti = 2000
            end
        else
            ESX.ShowNotification("Job is already started...", true, false, red)
        end
        Wait(opti)
    end
end)

-- drive to the trailer and pick it up
function StartJob()
    -- choose random location where the trailer is going to spawn
    local location = math.randomchoice(Config.TrailerLocations)
    -- choose random trailer model
    local model = math.randomchoice(Config.TrailerModels)
    -- add trailer blip to map
    local blip = AddBlipForCoord(location.x, location.y, location.z)
    SetBlipSprite(blip, 479)
    SetBlipColour(blip, 26)
    SetBlipRoute(blip, true)
    SetBlipRouteColour(blip, 26)
    -- clear area first
    ClearArea(location.x, location.y, location.z, 50, false, false, false, false, false);
    -- delete previous trailer before spawning a new one
    if trailer then 
        DeleteVehicle(trailer)
    end
    trailer = SpawnTrailer(model, location)
    ESX.ShowNotification("New task: pick up the trailer at the marked location.", true, false, green)
    jobStarted = true
    while true do
        opti = 2
        -- gets distance between player and trailer location and check if player is in the vicinity of it
        if #(playerCoords - vector3(location.x, location.y, location.z)) <= 20 then
            -- and check if they have picked up the trailer 
            if IsVehicleAttachedToTrailer(vehicle) then
                RemoveBlip(blip)
                DeliverTrailer()
                break
            end
        else
            opti = 2000
        end
        Wait(opti)
    end
end

-- drive to the location and deliver the trailer
function DeliverTrailer()
    AddTextEntry("press_detach_trailer", "Long press ~INPUT_VEH_HEADLIGHT~ to detach the trailer")
    local location = math.randomchoice(Config.Destinations)
    local blip = AddBlipForCoord(location.x, location.y, location.z)
    SetBlipSprite(blip, 478)
    SetBlipColour(blip, 26)
    SetBlipRoute(blip, true)
    SetBlipRouteColour(blip, 26)
    ESX.ShowNotification("New task: deliver the trailer at the marked location.", true, false, green)
    while true do
        opti = 2
        -- gets distance between player and task location and check f player is in the vicinity of it
        if #(playerCoords - vector3(location.x, location.y, location.z)) <= 20 then
            DisplayHelpTextThisFrame("press_detach_trailer")
            -- and check if they don't have a trailer attached anymore
            if not IsVehicleAttachedToTrailer(vehicle) then
                RemoveBlip(blip)
                NewChoice(location)
                break
            end
        else
            opti = 2000
        end
        Wait(opti)
    end
end

-- choose to deliver another trailer or return do depot
function NewChoice(location)
    amount = amount + Config.PayPerDelivery
    -- tell server we delivered something and where
    TriggerServerEvent("lama_jobs:delivered", location)
    ESX.ShowNotification("Press E to accept another job. Press X to end your shift.", true, false, blue)
    while true do
        Wait(0)
        if IsControlPressed(1, 38) then
            StartJob()
            break         
        elseif IsControlPressed(1, 73) then
            EndJob()
            break
        end
    end
end

-- drive back to the truck depot and get paid
function EndJob()
    local blip = AddBlipForCoord(Config.DepotLocation.x, Config.DepotLocation.y, Config.DepotLocation.z)
    AddTextEntry("press_end_job", "Press ~INPUT_CONTEXT~ to end your shift")
    SetBlipSprite(blip, 477)
    SetBlipColour(blip, 26)
    SetBlipRoute(blip, true)
    SetBlipRouteColour(blip, 26)
    ESX.ShowNotification("New task: return the truck to the depot to get paid.", true, false, green)
    jobStarted = false
    while true do
        opti = 2
        -- gets distance between player and depot location and check if player is in the vicinity of it
        if #(playerCoords - vector3(Config.DepotLocation.x, Config.DepotLocation.y, Config.DepotLocation.z)) <= 10 then
            DisplayHelpTextThisFrame("press_end_job")
            if IsControlPressed(1, 38) then
                RemoveBlip(blip)
                -- deletes truck and trailer
                local truck = GetVehiclePedIsIn(PlayerPedId(), false)
                if GetEntityModel(truck) == GetHashKey(Config.TruckModel) then
                    DeleteVehicle(GetVehiclePedIsIn(PlayerPedId(), false))
                end
                DeleteVehicle(trailer)
                ESX.ShowNotification("You've received $" .. amount .. " for completing the job.", true, false, green)
                break
            end
        else
            opti = 1000
        end
        Wait(opti)
    end
end

-- function to spawn vehicle at desired location
function SpawnVehicle(model, location)
    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(500)
    end
    vehicle = CreateVehicle(model, location.x, location.y, location.z, location.h, true, false)
    SetVehicleOnGroundProperly(vehicle)
    SetEntityAsMissionEntity(vehicle, true, true)
    SetModelAsNoLongerNeeded(model)
end

-- function to trailer vehicle at desired location
function SpawnTrailer(model, location)
    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(500)
    end
    trailer = CreateVehicle(model, location.x, location.y, location.z, location.h, true, false)
    SetVehicleOnGroundProperly(trailer)
    SetEntityAsMissionEntity(trailer, true, true)
    SetModelAsNoLongerNeeded(model)
end

-- function to get random items from a table
function math.randomchoice(table)
    local keys = {}
    for key, value in pairs(table) do
        keys[#keys + 1] = key
    end
    index = keys[math.random(1, #keys)]
    return table[index]
end

-- function to display the notification above minimap
function DisplayNotification(text)
    SetNotificationTextEntry("STRING")
    AddTextComponentString(text)
    DrawNotification(false, false)
end
