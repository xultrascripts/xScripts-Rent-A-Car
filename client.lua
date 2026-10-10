local ESX = exports['es_extended']:getSharedObject()

local rentalPeds = {}
local rentalBlips = {}
local rentedVehicles = {}
local menuOpen = false
local selectedLocation = 1
local pendingRequests = {}
local rentBusy = false

local function T(key, ...)
    local lang = Locales[Config.Locale] or Locales['en']
    local value = lang[key] or Locales['en'][key] or key
    if select('#', ...) > 0 then return value:format(...) end
    return value
end

local function notify(msg, typ)
    lib.notify({ title = T('rent_a_car'), description = msg, type = typ or 'inform' })
end

local function closeMenu()
    menuOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

local function openMenu(locationIndex)
    if menuOpen then return end
    selectedLocation = locationIndex or 1
    menuOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', vehicles = Config.Vehicles, locale = Config.Locale, translations = Locales[Config.Locale] or Locales['en'] })
end

local function loadVehicleModel(model)
    local hash = joaat(model)
    if not IsModelInCdimage(hash) or not IsModelAVehicle(hash) then return nil end
    RequestModel(hash)
    local timeout = GetGameTimer() + 15000
    while not HasModelLoaded(hash) do
        Wait(50)
        if GetGameTimer() > timeout then return nil end
    end
    return hash
end

local function deleteRental(vehicle)
    if not vehicle then return end
    if DoesEntityExist(vehicle) then
        NetworkRequestControlOfEntity(vehicle)
        local timeout = GetGameTimer() + 2000
        while not NetworkHasControlOfEntity(vehicle) and GetGameTimer() < timeout do
            Wait(50)
            NetworkRequestControlOfEntity(vehicle)
        end
        SetEntityAsMissionEntity(vehicle, true, true)
        DeleteVehicle(vehicle)
        if DoesEntityExist(vehicle) then DeleteEntity(vehicle) end
    end
    for i = #rentedVehicles, 1, -1 do
        if rentedVehicles[i].vehicle == vehicle then table.remove(rentedVehicles, i) break end
    end
end

local function spawnRental(model, label)
    local location = Config.Locations[selectedLocation]
    if not location then notify(T('rental_location_not_found'), 'error') return false end
    local spawns = location.VehicleSpawns
    if not spawns and location.VehicleSpawn then spawns = { location.VehicleSpawn } end
    if not spawns or #spawns == 0 then notify(T('vehicle_spawn_not_set'), 'error') return false end
    local spawn = nil
    for _, possibleSpawn in ipairs(spawns) do
        if not IsAnyVehicleNearPoint(possibleSpawn.x, possibleSpawn.y, possibleSpawn.z, Config.SpawnClearRadius) then spawn = possibleSpawn break end
    end
    if not spawn then notify(T('all_spawns_occupied'), 'error') return false end
    local hash = loadVehicleModel(model)
    if not hash then notify(T('model_not_found', model), 'error') return false end
    local vehicle = CreateVehicle(hash, spawn.x, spawn.y, spawn.z, spawn.w, true, true)
    if not DoesEntityExist(vehicle) then
        SetModelAsNoLongerNeeded(hash)
        notify(T('create_vehicle_failed'), 'error')
        return false
    end
    SetEntityAsMissionEntity(vehicle, true, true)
    SetVehicleOnGroundProperly(vehicle)
    SetVehicleEngineOn(vehicle, true, true, false)
    SetVehicleHasBeenOwnedByPlayer(vehicle, true)
    local chars = 'ABCDEFGHJKLMNPRSTUVWXYZ'
    local function randChar()
        local index = math.random(1, #chars)
        return chars:sub(index, index)
    end
    local plate = ('RS%02d%s%s'):format(math.random(10, 99), randChar(), randChar())
    SetVehicleNumberPlateText(vehicle, plate)
    SetVehicleDirtLevel(vehicle, 0.0)
    SetVehRadioStation(vehicle, 'OFF')
    SetModelAsNoLongerNeeded(hash)
    table.insert(rentedVehicles, { vehicle = vehicle, plate = plate, model = model, label = label })
    TriggerEvent('vehiclekeys:client:SetOwner', plate)
    TriggerEvent('qb-vehiclekeys:client:AddKeys', plate)
    if Config.WarpIntoVehicle then TaskWarpPedIntoVehicle(PlayerPedId(), vehicle, -1) end
    notify(T('rented_until_restart', label), 'success')
    return true
end

local function requestId()
    return ('%s_%s'):format(GetGameTimer(), math.random(1000, 9999))
end

local function waitForServerResult(sendEvent, ...)
    local id = requestId()
    local p = promise.new()
    pendingRequests[id] = p
    TriggerServerEvent(sendEvent, id, ...)
    local result = Citizen.Await(p)
    pendingRequests[id] = nil
    return result
end

RegisterNetEvent('rentacar:client:prepareResult', function(id, result)
    local p = pendingRequests[id]
    if p then p:resolve(result) end
end)

RegisterNetEvent('rentacar:client:payResult', function(id, result)
    local p = pendingRequests[id]
    if p then p:resolve(result) end
end)

RegisterNUICallback('rentVehicle', function(data, cb)
    if rentBusy then return cb({ ok = false }) end
    if type(data) ~= 'table' or type(data.model) ~= 'string' then return cb({ ok = false }) end
    local payment = data.payment == 'card' and 'card' or 'cash'
    rentBusy = true
    local result = waitForServerResult('rentacar:server:prepareRent', data.model, payment)
    if not result or not result.ok then
        rentBusy = false
        notify((result and result.message) or T('rental_failed'), 'error')
        return cb({ ok = false })
    end
    local spawned = spawnRental(result.model, result.label)
    if not spawned then rentBusy = false return cb({ ok = false }) end
    local paymentResult = waitForServerResult('rentacar:server:payRent', result.model, payment, result.price)
    if not paymentResult or not paymentResult.ok then
        local lastRental = rentedVehicles[#rentedVehicles]
        if lastRental and lastRental.vehicle then deleteRental(lastRental.vehicle) end
        rentBusy = false
        notify((paymentResult and paymentResult.message) or T('payment_failed_vehicle_removed'), 'error')
        return cb({ ok = false })
    end
    local lastRental = rentedVehicles[#rentedVehicles]
    if not lastRental or not lastRental.vehicle or not DoesEntityExist(lastRental.vehicle) then
        rentBusy = false
        notify(T('rental_vehicle_not_found'), 'error')
        return cb({ ok = false })
    end
    local plate = GetVehicleNumberPlateText(lastRental.vehicle)
    TriggerServerEvent('rentacar:server:giveRentPaper', { model = result.model, plate = plate })
    local method = paymentResult.payment == 'card' and T('paid_card') or T('paid_cash')
    notify(T('paid', result.label, method, paymentResult.price), 'success')
    notify(T('rent_papers_added'), 'success')
    rentBusy = false
    closeMenu()
    cb({ ok = true })
end)

RegisterNUICallback('close', function(_, cb)
    closeMenu()
    cb({ ok = true })
end)

local function normalizePlate(plate)
    return tostring(plate or ''):upper():gsub('%s+', '')
end

local function getRentPaperPlate(item)
    if not item then return nil end
    local metadata = item.metadata or item.info
    if type(metadata) ~= 'table' then return nil end
    local plate = metadata.plate or metadata.plateText or metadata.plateNumber
    if plate and tostring(plate) ~= '' then return normalizePlate(plate) end
    local description = tostring(metadata.description or '')
    local found = description:match('[Tt]ablice:%s*([^\n]+)')
    if found then return normalizePlate(found) end
    return nil
end

local function hasRentPaperForPlate(plate)
    if GetResourceState('ox_inventory') ~= 'started' then return false end
    local items = exports.ox_inventory:Search('slots', 'rent_documents')
    if type(items) ~= 'table' then return false end
    local wanted = normalizePlate(plate)
    for _, item in pairs(items) do if getRentPaperPlate(item) == wanted then return true end end
    return false
end

local function getVehicleForRentPaper(maxDistance)
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle ~= 0 and DoesEntityExist(vehicle) then return vehicle end
    local coords = GetEntityCoords(ped)
    local closest = 0
    local closestDist = maxDistance or 5.0
    for _, veh in ipairs(GetGamePool('CVehicle')) do
        if DoesEntityExist(veh) then
            local dist = #(coords - GetEntityCoords(veh))
            if dist <= closestDist then closest = veh closestDist = dist end
        end
    end
    return closest
end

local function playLockAnimation()
    local ped = PlayerPedId()
    local dict = 'anim@mp_player_intmenu@key_fob@'
    RequestAnimDict(dict)
    local timeout = GetGameTimer() + 3000
    while not HasAnimDictLoaded(dict) do
        Wait(10)
        if GetGameTimer() > timeout then return end
    end
    TaskPlayAnim(ped, dict, 'fob_click', 8.0, -8.0, 800, 48, 0.0, false, false, false)
    RemoveAnimDict(dict)
end

local function playLockSound(vehicle)
    if vehicle and DoesEntityExist(vehicle) then PlaySoundFromEntity(-1, 'Remote_Control_Fob', vehicle, 'PI_Menu_Sounds', false, 0) end
end

local function flashVehicleLights(vehicle)
    if not vehicle or not DoesEntityExist(vehicle) then return end
    SetVehicleLights(vehicle, 2); Wait(120); SetVehicleLights(vehicle, 0); Wait(100); SetVehicleLights(vehicle, 2); Wait(120); SetVehicleLights(vehicle, 0)
end

local function toggleRentVehicleLock()
    local vehicle = getVehicleForRentPaper(6.0)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then notify(T('no_rental_vehicle_nearby'), 'error') return end
    local plate = GetVehicleNumberPlateText(vehicle)
    if not hasRentPaperForPlate(plate) then notify(T('no_rental_papers'), 'error') return end
    local lockStatus = GetVehicleDoorLockStatus(vehicle)
    local locked = lockStatus == 2 or lockStatus == 4 or lockStatus == 7 or lockStatus == 8 or lockStatus == 10
    local newStatus = locked and 1 or 2
    playLockAnimation(); Wait(250)
    SetVehicleDoorsLocked(vehicle, newStatus)
    SetVehicleDoorsLockedForAllPlayers(vehicle, newStatus == 2)
    SetVehicleNeedsToBeHotwired(vehicle, false)
    SetVehicleCanBeUsedByFleeingPeds(vehicle, false)
    local plateNormalized = normalizePlate(plate)
    TriggerEvent('vehiclekeys:client:SetOwner', plateNormalized)
    TriggerEvent('qb-vehiclekeys:client:AddKeys', plateNormalized)
    playLockSound(vehicle)
    CreateThread(function() flashVehicleLights(vehicle) end)
    if newStatus == 2 then notify(T('vehicle_locked', plateNormalized), 'success') else notify(T('vehicle_unlocked', plateNormalized), 'success') end
end

RegisterCommand('rentpaperlock', function() toggleRentVehicleLock() end, false)
RegisterKeyMapping('rentpaperlock', T('rental_papers_lock'), 'keyboard', 'L')

exports('useRentPapers', function(data)
    local paperPlate = getRentPaperPlate(data)
    if not paperPlate then notify(T('invalid_rental_papers'), 'error') return end
    local vehicle = getVehicleForRentPaper(5.0)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then notify(T('no_vehicle_nearby'), 'error') return end
    local vehiclePlate = normalizePlate(GetVehicleNumberPlateText(vehicle))
    if vehiclePlate ~= paperPlate then notify(T('papers_not_valid', vehiclePlate), 'error') return end
    toggleRentVehicleLock()
end)

CreateThread(function()
    for index, location in ipairs(Config.Locations) do
        if location.Ped then
            local hash = joaat(location.Ped.model)
            RequestModel(hash)
            while not HasModelLoaded(hash) do Wait(50) end
            local c = location.Ped.coords
            local ped = CreatePed(4, hash, c.x, c.y, c.z - 1.0, c.w, false, true)
            FreezeEntityPosition(ped, true)
            SetEntityInvincible(ped, true)
            SetBlockingOfNonTemporaryEvents(ped, true)
            if location.Ped.scenario and location.Ped.scenario ~= '' then TaskStartScenarioInPlace(ped, location.Ped.scenario, 0, true) end
            exports.ox_target:addLocalEntity(ped, {{ name = 'rentacar_open_' .. index, icon = 'fa-solid fa-car', label = T('rent_a_car'), distance = 2.5, onSelect = function() openMenu(index) end }})
            rentalPeds[index] = ped
            SetModelAsNoLongerNeeded(hash)
        end
        if location.Blip and location.Blip.enabled then
            local c = location.Blip.coords
            local blip = AddBlipForCoord(c.x, c.y, c.z)
            SetBlipSprite(blip, location.Blip.sprite); SetBlipDisplay(blip, 4); SetBlipScale(blip, location.Blip.scale); SetBlipColour(blip, location.Blip.color); SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING'); AddTextComponentString(location.Blip.name); EndTextCommandSetBlipName(blip)
            rentalBlips[index] = blip
        end
    end
end)

CreateThread(function()
    while true do
        Wait(0)
        if menuOpen and IsControlJustPressed(0, 322) then closeMenu() end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    SetNuiFocus(false, false)
    for _, ped in pairs(rentalPeds) do if ped and DoesEntityExist(ped) then DeletePed(ped) end end
    for _, blip in pairs(rentalBlips) do if blip then RemoveBlip(blip) end end
    for _, rental in pairs(rentedVehicles) do if rental.vehicle and DoesEntityExist(rental.vehicle) then DeleteVehicle(rental.vehicle) end end
    rentedVehicles = {}
end)
