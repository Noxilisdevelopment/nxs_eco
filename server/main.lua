local ESX = exports.es_extended:getSharedObject()
local lastFetch = 0
local cachedData = nil

-- ====================================================================
-- SÉCURITÉ & PERMISSIONS
-- ====================================================================

local function IsPlayerAuthorized(xPlayer)
    if not xPlayer then return false end
    
    -- Vérification par licence SuperAdmin
    local identifier = xPlayer.getIdentifier()
    for _, license in ipairs(Config.SuperAdmins or {}) do
        if identifier == license then
            return true
        end
    end

    -- Vérification par groupe ESX
    local group = xPlayer.getGroup()
    if Config.AllowedGroups and Config.AllowedGroups[group] == true then
        return true
    end

    return false
end

-- ====================================================================
-- LOGS DISCORD
-- ====================================================================

local function SendDiscordLog(title, description, color, fields)
    if not Config.Webhook.Enabled or not Config.Webhook.Url or Config.Webhook.Url == '' then
        return
    end

    local embed = {
        {
            ['title'] = title,
            ['description'] = description,
            ['color'] = color or Config.Webhook.Color,
            ['fields'] = fields or {},
            ['footer'] = {
                ['text'] = os.date('!%Y-%m-%d %H:%M:%S UTC') .. ' • ' .. (Config.Webhook.Name or 'NXS Économie')
            }
        }
    }

    PerformHttpRequest(Config.Webhook.Url, function(err, text, headers) end, 'POST', json.encode({
        username = Config.Webhook.Name or 'NXS Economy',
        avatar_url = Config.Webhook.Avatar or nil,
        embeds = embed
    }), { ['Content-Type'] = 'application/json' })
end

-- ====================================================================
-- RÉCUPÉRATION COMPLÈTE DE L'ÉCONOMIE
-- ====================================================================

local function FetchServerEconomy()
    -- 1. Index des joueurs actuellement en ligne
    local onlineMap = {}
    local onlineCount = 0
    local extendedPlayers = ESX.GetExtendedPlayers()
    for _, xPlayer in ipairs(extendedPlayers) do
        local idf = xPlayer.getIdentifier()
        onlineMap[idf] = xPlayer
        onlineCount = onlineCount + 1
    end

    -- 2. Récupération de tous les comptes joueurs dans la base de données
    local rows = MySQL.query.await([[
        SELECT identifier, firstname, lastname, accounts, job, job_grade, `group`
        FROM users
    ]])

    local playersList = {}
    local totCash = 0
    local totBank = 0
    local totBlackMoney = 0
    local totEconomy = 0

    if rows and #rows > 0 then
        for _, row in ipairs(rows) do
            local xPlayer = onlineMap[row.identifier]
            local isOnline = (xPlayer ~= nil)
            local serverId = isOnline and xPlayer.source or nil
            
            local fname = row.firstname or ''
            local lname = row.lastname or ''
            local fullName = (fname ~= '' or lname ~= '') and (fname .. ' ' .. lname) or row.identifier
            if isOnline and xPlayer.getName then
                local pName = xPlayer.getName()
                if pName and pName ~= '' then fullName = pName end
            end

            local cash = 0
            local bank = 0
            local blackMoney = 0
            local jobLabel = row.job or 'unemployed'
            local jobGradeLabel = tostring(row.job_grade or 0)
            local group = row.group or 'user'

            if isOnline then
                local cashAcc = xPlayer.getAccount('money')
                local bankAcc = xPlayer.getAccount('bank')
                local blackAcc = xPlayer.getAccount('black_money')

                cash = (cashAcc and cashAcc.money) or 0
                bank = (bankAcc and bankAcc.money) or 0
                blackMoney = (Config.IncludeBlackMoney and blackAcc and blackAcc.money) or 0
                
                local jobObj = xPlayer.getJob()
                if jobObj then
                    jobLabel = jobObj.label or jobLabel
                    jobGradeLabel = jobObj.grade_label or jobGradeLabel
                end
                group = xPlayer.getGroup() or group
            else
                local acc = {}
                if row.accounts and row.accounts ~= '' then
                    local ok, decoded = pcall(json.decode, row.accounts)
                    if ok and type(decoded) == 'table' then
                        acc = decoded
                    end
                end
                cash = tonumber(acc.money) or 0
                bank = tonumber(acc.bank) or 0
                blackMoney = (Config.IncludeBlackMoney and tonumber(acc.black_money)) or 0
            end

            local playerTotal = cash + bank + blackMoney

            totCash = totCash + cash
            totBank = totBank + bank
            totBlackMoney = totBlackMoney + blackMoney
            totEconomy = totEconomy + playerTotal

            table.insert(playersList, {
                identifier  = row.identifier,
                name        = fullName,
                online      = isOnline,
                serverId    = serverId,
                cash        = cash,
                bank        = bank,
                blackMoney  = blackMoney,
                total       = playerTotal,
                job         = jobLabel,
                jobGrade    = jobGradeLabel,
                group       = group
            })
        end
    end

    -- Tri des joueurs du plus riche au moins riche
    table.sort(playersList, function(a, b)
        return a.total > b.total
    end)

    -- 3. Récupération des comptes de sociétés (entreprises)
    local societies = {}
    local totSocieties = 0
    if Config.IncludeSocietyAccounts then
        local ok, socRows = pcall(function()
            return MySQL.query.await([[
                SELECT ad.account_name, ad.money, COALESCE(a.label, ad.account_name) AS label
                FROM addon_account_data ad
                LEFT JOIN addon_account a ON ad.account_name = a.name
                WHERE ad.account_name LIKE 'society_%'
                ORDER BY ad.money DESC
            ]])
        end)

        if ok and socRows then
            for _, soc in ipairs(socRows) do
                local sMoney = tonumber(soc.money) or 0
                totSocieties = totSocieties + sMoney
                table.insert(societies, {
                    name  = soc.account_name,
                    label = soc.label or soc.account_name,
                    money = sMoney
                })
            end
        end
    end

    local totalPlayers = #playersList
    local avgMoney = totalPlayers > 0 and math.floor(totEconomy / totalPlayers) or 0
    local richest = playersList[1] or { name = 'Aucun', total = 0 }
    local grandTotal = totEconomy + totSocieties

    local payload = {
        stats = {
            totalEconomy   = totEconomy,
            totalCash      = totCash,
            totalBank      = totBank,
            totalBlackMoney= totBlackMoney,
            totalSocieties = totSocieties,
            grandTotal     = grandTotal,
            totalPlayers   = totalPlayers,
            onlinePlayers  = onlineCount,
            averageMoney   = avgMoney,
            richestPlayer  = {
                name   = richest.name,
                total  = richest.total,
                online = richest.online
            }
        },
        players = playersList,
        societies = societies,
        timestamp = os.time()
    }

    cachedData = payload
    lastFetch = os.time()
    return payload
end

-- ====================================================================
-- CALLBACKS (ox_lib & ESX)
-- ====================================================================

-- ox_lib Callback
if lib and lib.callback then
    lib.callback.register('nxs_economy:getEconomyData', function(source, force)
        local xPlayer = ESX.GetPlayerFromId(source)
        if not IsPlayerAuthorized(xPlayer) then
            return nil
        end

        local now = os.time()
        if not force and cachedData and (now - lastFetch < (Config.RefreshCooldown or 3)) then
            return cachedData
        end

        return FetchServerEconomy()
    end)
end

-- ESX Server Callback
ESX.RegisterServerCallback('nxs_economy:getEconomyData', function(source, cb, force)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not IsPlayerAuthorized(xPlayer) then
        cb(nil)
        return
    end

    local now = os.time()
    if not force and cachedData and (now - lastFetch < (Config.RefreshCooldown or 3)) then
        cb(cachedData)
        return
    end

    local data = FetchServerEconomy()
    cb(data)
end)

-- Callback vérification de permission
ESX.RegisterServerCallback('nxs_economy:checkPermission', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    cb(IsPlayerAuthorized(xPlayer))
end)

if lib and lib.callback then
    lib.callback.register('nxs_economy:checkPermission', function(source)
        local xPlayer = ESX.GetPlayerFromId(source)
        return IsPlayerAuthorized(xPlayer)
    end)
end

-- ====================================================================
-- ACTIONS ADMINISTRATIVES SUR LES JOUEURS
-- ====================================================================

RegisterNetEvent('nxs_economy:executePlayerAction', function(targetIdentifier, actionType, accountType, amount, reason)
    local src = source
    local adminPlayer = ESX.GetPlayerFromId(src)
    if not IsPlayerAuthorized(adminPlayer) then
        TriggerClientEvent('esx:showNotification', src, _T('no_permission'))
        return
    end

    amount = tonumber(amount)
    if not amount or amount < 0 then
        TriggerClientEvent('esx:showNotification', src, _T('invalid_amount'))
        return
    end

    amount = math.floor(amount)
    accountType = accountType or 'money'
    reason = (reason and reason ~= '') and reason or 'Modification Staff Économie'

    local adminName = adminPlayer.getName() or GetPlayerName(src)
    local xTarget = ESX.GetPlayerFromIdentifier(targetIdentifier)
    local targetName = targetIdentifier

    if xTarget then
        -- Joueur EN LIGNE
        targetName = xTarget.getName() or targetIdentifier
        local currentAcc = xTarget.getAccount(accountType)
        local curBal = currentAcc and currentAcc.money or 0

        if actionType == 'give' then
            xTarget.addAccountMoney(accountType, amount, reason)
            TriggerClientEvent('esx:showNotification', src, _T('money_given', amount, Config.Currency.Symbol, accountType, targetName))
            TriggerClientEvent('esx:showNotification', xTarget.source, _T('received_money_admin', accountType, amount, Config.Currency.Symbol))
        elseif actionType == 'remove' then
            local toRemove = math.min(amount, curBal)
            xTarget.removeAccountMoney(accountType, toRemove, reason)
            TriggerClientEvent('esx:showNotification', src, _T('money_removed', toRemove, Config.Currency.Symbol, accountType, targetName))
            TriggerClientEvent('esx:showNotification', xTarget.source, _T('removed_money_admin', accountType, toRemove, Config.Currency.Symbol))
        elseif actionType == 'set' then
            xTarget.setAccountMoney(accountType, amount, reason)
            TriggerClientEvent('esx:showNotification', src, _T('money_set', accountType, targetName, amount, Config.Currency.Symbol))
        elseif actionType == 'wipe' then
            xTarget.setAccountMoney('money', 0, reason)
            xTarget.setAccountMoney('bank', 0, reason)
            if Config.IncludeBlackMoney then xTarget.setAccountMoney('black_money', 0, reason) end
            TriggerClientEvent('esx:showNotification', src, _T('money_wiped', targetName))
        end
    else
        -- Joueur HORS LIGNE (Direct MySQL)
        if not Config.AllowOfflineModifications then
            TriggerClientEvent('esx:showNotification', src, "~r~Les modifications hors-ligne sont désactivées.~s~")
            return
        end

        local row = MySQL.single.await('SELECT firstname, lastname, accounts FROM users WHERE identifier = ?', { targetIdentifier })
        if not row then
            TriggerClientEvent('esx:showNotification', src, _T('player_not_found'))
            return
        end

        local fname = row.firstname or ''
        local lname = row.lastname or ''
        targetName = (fname ~= '' or lname ~= '') and (fname .. ' ' .. lname) or targetIdentifier

        local acc = {}
        if row.accounts and row.accounts ~= '' then
            local ok, decoded = pcall(json.decode, row.accounts)
            if ok and type(decoded) == 'table' then acc = decoded end
        end

        local oldBal = tonumber(acc[accountType]) or 0

        if actionType == 'give' then
            acc[accountType] = oldBal + amount
            TriggerClientEvent('esx:showNotification', src, _T('money_given', amount, Config.Currency.Symbol, accountType, targetName .. ' (Hors-ligne)'))
        elseif actionType == 'remove' then
            acc[accountType] = math.max(0, oldBal - amount)
            TriggerClientEvent('esx:showNotification', src, _T('money_removed', amount, Config.Currency.Symbol, accountType, targetName .. ' (Hors-ligne)'))
        elseif actionType == 'set' then
            acc[accountType] = amount
            TriggerClientEvent('esx:showNotification', src, _T('money_set', accountType, targetName .. ' (Hors-ligne)', amount, Config.Currency.Symbol))
        elseif actionType == 'wipe' then
            acc['money'] = 0
            acc['bank'] = 0
            if Config.IncludeBlackMoney then acc['black_money'] = 0 end
            TriggerClientEvent('esx:showNotification', src, _T('money_wiped', targetName .. ' (Hors-ligne)'))
        end

        MySQL.update.await('UPDATE users SET accounts = ? WHERE identifier = ?', { json.encode(acc), targetIdentifier })
    end

    -- Invalidation du cache pour actualisation instantanée
    lastFetch = 0

    -- Logs Discord
    SendDiscordLog("Action Économique - Joueur", string.format("L'administrateur **%s** a effectué une action sur **%s**.", adminName, targetName), 3066993, {
        { name = "Action", value = actionType, inline = true },
        { name = "Compte", value = accountType, inline = true },
        { name = "Montant", value = string.format("%s %s", amount, Config.Currency.Symbol), inline = true },
        { name = "Cible", value = string.format("%s (`%s`)", targetName, targetIdentifier), inline = false },
        { name = "Motif", value = reason, inline = false },
    })

    -- Déclenchement de la mise à jour côté client
    TriggerClientEvent('nxs_economy:actionCompleted', src)
end)

-- ====================================================================
-- ACTIONS ADMINISTRATIVES SUR LES SOCIÉTÉS
-- ====================================================================

RegisterNetEvent('nxs_economy:executeSocietyAction', function(accountName, actionType, amount, reason)
    local src = source
    local adminPlayer = ESX.GetPlayerFromId(src)
    if not IsPlayerAuthorized(adminPlayer) or not Config.Permissions.ManageSociety then
        TriggerClientEvent('esx:showNotification', src, _T('no_permission'))
        return
    end

    amount = tonumber(amount)
    if not amount or amount < 0 then
        TriggerClientEvent('esx:showNotification', src, _T('invalid_amount'))
        return
    end

    amount = math.floor(amount)
    local adminName = adminPlayer.getName() or GetPlayerName(src)

    local row = MySQL.single.await('SELECT money FROM addon_account_data WHERE account_name = ?', { accountName })
    if not row then
        TriggerClientEvent('esx:showNotification', src, "~r~Société introuvable dans addon_account_data.~s~")
        return
    end

    local current = tonumber(row.money) or 0
    local newMoney = current

    if actionType == 'give' then
        newMoney = current + amount
        TriggerClientEvent('esx:showNotification', src, _T('society_money_given', amount, Config.Currency.Symbol, accountName))
    elseif actionType == 'remove' then
        newMoney = math.max(0, current - amount)
        TriggerClientEvent('esx:showNotification', src, _T('society_money_removed', amount, Config.Currency.Symbol, accountName))
    elseif actionType == 'set' then
        newMoney = amount
        TriggerClientEvent('esx:showNotification', src, _T('society_money_set', accountName, amount, Config.Currency.Symbol))
    end

    MySQL.update.await('UPDATE addon_account_data SET money = ? WHERE account_name = ?', { newMoney, accountName })

    -- Invalidation du cache
    lastFetch = 0

    -- Logs Discord
    SendDiscordLog("Action Économique - Société", string.format("L'administrateur **%s** a modifié la caisse de l'entreprise **%s**.", adminName, accountName), 15105570, {
        { name = "Entreprise", value = accountName, inline = true },
        { name = "Action", value = actionType, inline = true },
        { name = "Montant", value = string.format("%s %s", amount, Config.Currency.Symbol), inline = true },
        { name = "Nouveau solde", value = string.format("%s %s", newMoney, Config.Currency.Symbol), inline = true },
        { name = "Motif", value = reason or 'Non spécifié', inline = false }
    })

    TriggerClientEvent('nxs_economy:actionCompleted', src)
end)

-- ====================================================================
-- COMMANDES SERVEUR / CONSOLE
-- ====================================================================

-- Commande console : eco_stats
RegisterCommand('eco_stats', function(source, args, rawCommand)
    if source ~= 0 then
        local xPlayer = ESX.GetPlayerFromId(source)
        if not IsPlayerAuthorized(xPlayer) then
            TriggerClientEvent('esx:showNotification', source, _T('no_permission'))
            return
        end
    end

    local data = FetchServerEconomy()
    local s = data.stats

    print("^2==============================================================^7")
    print("^2               RAPPORT ÉCONOMIQUE DU SERVEUR NXS              ^7")
    print("^2==============================================================^7")
    print(string.format("^3Total Joueurs Enregistrés :^7 %d", s.totalPlayers))
    print(string.format("^3Joueurs En Ligne          :^7 %d", s.onlinePlayers))
    print("--------------------------------------------------------------")
    print(string.format("^2Total Liquid (Cash)       :^7 %s %s", ESX.Math.GroupDigits(s.totalCash), Config.Currency.Symbol))
    print(string.format("^2Total Banque              :^7 %s %s", ESX.Math.GroupDigits(s.totalBank), Config.Currency.Symbol))
    if Config.IncludeBlackMoney then
        print(string.format("^1Total Argent Sale         :^7 %s %s", ESX.Math.GroupDigits(s.totalBlackMoney), Config.Currency.Symbol))
    end
    print(string.format("^6Total Masse Joueurs       :^7 %s %s", ESX.Math.GroupDigits(s.totalEconomy), Config.Currency.Symbol))
    print("--------------------------------------------------------------")
    print(string.format("^5Total Caisses Sociétés    :^7 %s %s", ESX.Math.GroupDigits(s.totalSocieties), Config.Currency.Symbol))
    print(string.format("^2MASSE MONÉTAIRE TOTALE    :^7 %s %s", ESX.Math.GroupDigits(s.grandTotal), Config.Currency.Symbol))
    print("--------------------------------------------------------------")
    print(string.format("^3Moyenne par Joueur        :^7 %s %s", ESX.Math.GroupDigits(s.averageMoney), Config.Currency.Symbol))
    print(string.format("^3Citoyen le plus riche     :^7 %s (%s %s)", s.richestPlayer.name, ESX.Math.GroupDigits(s.richestPlayer.total), Config.Currency.Symbol))
    print("^2==============================================================^7")
end, false)

-- Commande console : eco_top
RegisterCommand('eco_top', function(source, args, rawCommand)
    if source ~= 0 then
        local xPlayer = ESX.GetPlayerFromId(source)
        if not IsPlayerAuthorized(xPlayer) then
            TriggerClientEvent('esx:showNotification', source, _T('no_permission'))
            return
        end
    end

    local limit = tonumber(args[1]) or 10
    local data = FetchServerEconomy()

    print("^3==============================================================^7")
    print(string.format("^3             TOP %d DES PLUS GRANDES FORTUNES                  ^7", limit))
    print("^3==============================================================^7")
    for i = 1, math.min(limit, #data.players) do
        local p = data.players[i]
        local status = p.online and "^2[EN LIGNE]^7" or "^8[HORS LIGNE]^7"
        print(string.format("#%02d %s %-25s | Total: %12s %s (Liq: %s | Bq: %s)",
            i, status, p.name,
            ESX.Math.GroupDigits(p.total), Config.Currency.Symbol,
            ESX.Math.GroupDigits(p.cash),
            ESX.Math.GroupDigits(p.bank)
        ))
    end
    print("^3==============================================================^7")
end, false)
