local ESX = exports['es_extended']:getSharedObject()

local function T(key, ...)
    local lang = Locales[Config.Locale] or Locales['en']
    local value = lang[key] or Locales['en'][key] or key
    if select('#', ...) > 0 then return value:format(...) end
    return value
end

local function findVehicle(model)
    for _, vehicles in pairs(Config.Vehicles) do
        for _, vehicle in ipairs(vehicles) do
            if vehicle.model == model then return vehicle end
        end
    end
    return nil
end

local function getBalance(xPlayer, payment)
    if payment == 'card' then
        local account = xPlayer.getAccount('bank')
        return account and tonumber(account.money) or 0
    end
    return tonumber(xPlayer.getMoney()) or 0
end

local function removePayment(xPlayer, payment, amount)
    if payment == 'card' then xPlayer.removeAccountMoney('bank', amount, T('rent_a_car')) else xPlayer.removeMoney(amount, T('rent_a_car')) end
end

RegisterNetEvent('rentacar:server:prepareRent', function(requestId, model, payment)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return TriggerClientEvent('rentacar:client:prepareResult', source, requestId, { ok = false, message = T('player_not_found') }) end
    local vehicle = findVehicle(model)
    payment = payment == 'card' and 'card' or 'cash'
    if not vehicle then return TriggerClientEvent('rentacar:client:prepareResult', source, requestId, { ok = false, message = T('vehicle_unavailable') }) end
    local price = tonumber(vehicle.price)
    if not price then return TriggerClientEvent('rentacar:client:prepareResult', source, requestId, { ok = false, message = T('price_not_configured') }) end
    local balance = getBalance(xPlayer, payment)
    if balance < price then
        local method = payment == 'card' and T('on_card') or T('in_cash')
        return TriggerClientEvent('rentacar:client:prepareResult', source, requestId, { ok = false, message = T('not_enough_money_method', method, price) })
    end
    TriggerClientEvent('rentacar:client:prepareResult', source, requestId, { ok = true, model = vehicle.model, label = vehicle.label, price = price, payment = payment })
end)

RegisterNetEvent('rentacar:server:payRent', function(requestId, model, payment, price)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return TriggerClientEvent('rentacar:client:payResult', source, requestId, { ok = false, message = T('player_not_found') }) end
    local vehicle = findVehicle(model)
    payment = payment == 'card' and 'card' or 'cash'
    price = tonumber(price)
    if not vehicle then return TriggerClientEvent('rentacar:client:payResult', source, requestId, { ok = false, message = T('rental_no_longer_valid') }) end
    local serverPrice = tonumber(vehicle.price)
    if not serverPrice or price ~= serverPrice then return TriggerClientEvent('rentacar:client:payResult', source, requestId, { ok = false, message = T('price_changed') }) end
    local balance = getBalance(xPlayer, payment)
    if balance < serverPrice then return TriggerClientEvent('rentacar:client:payResult', source, requestId, { ok = false, message = T('not_enough_money_rental') }) end
    removePayment(xPlayer, payment, serverPrice)
    TriggerClientEvent('rentacar:client:payResult', source, requestId, { ok = true, price = serverPrice, payment = payment })
end)

RegisterNetEvent('rentacar:server:giveRentPaper', function(data)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer or type(data) ~= 'table' then return end
    local vehicle = findVehicle(data.model)
    local plate = tostring(data.plate or ''):sub(1, 12)
    if not vehicle or plate == '' then return end
    if GetResourceState('ox_inventory') ~= 'started' then print(T('ox_inventory_not_started')) return end
    local playerName = xPlayer.getName() or GetPlayerName(source) or T('unknown')
    local rentTime = os.date('%d.%m.%Y. %H:%M')
    local metadata = {
        description = (T('paper_vehicle') .. ': %s\n' .. T('paper_plate') .. ': %s\n' .. T('paper_rented_by') .. ': %s\n' .. T('paper_rented_at') .. ': %s'):format(vehicle.label, plate, playerName, rentTime),
        vehicle = vehicle.label, model = vehicle.model, plate = plate, renter = playerName, rentedAt = rentTime
    }
    local success, response = pcall(function() return exports.ox_inventory:AddItem(source, 'rent_documents', 1, metadata) end)
    if not success then print(T('item_add_error', response)) elseif response ~= true then print(T('item_not_added', tostring(response))) end
end)
