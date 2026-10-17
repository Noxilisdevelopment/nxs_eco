local ESX = exports.es_extended:getSharedObject()
local isUIOpen = false

-- ====================================================================
-- OUVERTURE ET FERMETURE DE L'INTERFACE
-- ====================================================================

local function CloseEconomyMenu()
    if not isUIOpen then return end
    isUIOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({
        action = 'close'
    })
end

local function OpenEconomyMenu()
    if isUIOpen then return end

    -- Vérification des permissions auprès du serveur
    ESX.TriggerServerCallback('nxs_economy:checkPermission', function(hasPermission)
        if not hasPermission then
            ESX.ShowNotification(_T('no_permission'))
            return
        end

        -- Récupération des données économiques
        ESX.TriggerServerCallback('nxs_economy:getEconomyData', function(data)
            if not data then
                ESX.ShowNotification(_T('no_permission'))
                return
            end

            isUIOpen = true
            SetNuiFocus(true, true)
            SendNUIMessage({
                action   = 'open',
                data     = data,
                currency = Config.Currency or { Symbol = '$', Position = 'after', Separator = ' ' }
            })
        end, false)
    end)
end

-- ====================================================================
-- NUI CALLBACKS
-- ====================================================================

RegisterNUICallback('closeUI', function(data, cb)
    CloseEconomyMenu()
    cb('ok')
end)

RegisterNUICallback('refreshData', function(data, cb)
    ESX.TriggerServerCallback('nxs_economy:getEconomyData', function(freshData)
        if freshData then
            cb({ success = true, data = freshData })
        else
            cb({ success = false, message = _T('no_permission') })
        end
    end, true)
end)

RegisterNUICallback('executePlayerAction', function(data, cb)
    if not data or not data.identifier or not data.action then
        cb({ success = false, message = "Paramètres invalides" })
        return
    end

    TriggerServerEvent(
        'nxs_economy:executePlayerAction',
        data.identifier,
        data.action,
        data.account or 'money',
        data.amount or 0,
        data.reason or 'Action Panel Économie'
    )
    cb({ success = true })
end)

RegisterNUICallback('executeSocietyAction', function(data, cb)
    if not data or not data.accountName or not data.action then
        cb({ success = false, message = "Paramètres invalides" })
        return
    end

    TriggerServerEvent(
        'nxs_economy:executeSocietyAction',
        data.accountName,
        data.action,
        data.amount or 0,
        data.reason or 'Action Panel Économie'
    )
    cb({ success = true })
end)

-- Notification de fin d'action serveur pour actualiser la NUI
RegisterNetEvent('nxs_economy:actionCompleted', function()
    if isUIOpen then
        ESX.TriggerServerCallback('nxs_economy:getEconomyData', function(freshData)
            if freshData then
                SendNUIMessage({
                    action = 'updateData',
                    data   = freshData
                })
            end
        end, true)
    end
end)

-- ====================================================================
-- COMMANDES & KEYMAPPING
-- ====================================================================

RegisterCommand(Config.Command or 'eco', function()
    if isUIOpen then
        CloseEconomyMenu()
    else
        OpenEconomyMenu()
    end
end, false)

for _, alias in ipairs(Config.CommandAliases or {}) do
    RegisterCommand(alias, function()
        if isUIOpen then
            CloseEconomyMenu()
        else
            OpenEconomyMenu()
        end
    end, false)
end

if Config.KeyMapping and Config.KeyMapping ~= '' then
    RegisterKeyMapping(Config.Command or 'eco', 'Ouvrir la gestion économique', 'keyboard', Config.KeyMapping)
end
