Config = {}

-- Langue par défaut
Config.Locale = 'fr'

-- Commandes d'ouverture du menu (Staff/Admin)
Config.Command = 'eco'
Config.CommandAliases = { 'economie', 'ecomenu' }

-- Raccourci clavier (vide par défaut pour éviter les conflits, modifiable dans Paramètres -> Clavier -> FiveM)
Config.KeyMapping = '' 

-- Groupes autorisés à ouvrir le menu et administrer l'économie
Config.AllowedGroups = {
    ['fondateur']   = true,
    ['owner']       = true,
    ['superadmin']  = true,
    ['admin']       = true,
    ['staff']       = true
}

-- Licences prioritaires autorisées (accès direct sans condition de groupe)
Config.SuperAdmins = {
    --'license:',
   -- 'license:',
}

-- Permissions détaillées pour les actions sensibles
Config.Permissions = {
    ViewStats     = true,  -- Voir la masse monétaire et stats globales
    ViewPlayers   = true,  -- Voir le tableau des joueurs
    GiveMoney     = true,  -- Créditer de l'argent
    RemoveMoney   = true,  -- Débiter de l'argent
    SetMoney      = true,  -- Fixer un solde exact
    WipeMoney     = true,  -- Remise à zéro d'un compte joueur
    ManageSociety = true,  -- Modifier les caisses de société
    ExportData    = true   -- Exporter en CSV
}

-- Devise & formatage
Config.Currency = {
    Symbol = '$',
    Position = 'after', -- 'before' ($100) ou 'after' (100 $)
    Separator = ' '     -- Séparateur de milliers (ex: 1 000 000)
}

-- Prise en compte de l'argent sale / black_money
Config.IncludeBlackMoney = true

-- Prise en compte des comptes de société (addon_account_data society_*)
Config.IncludeSocietyAccounts = true

-- Autoriser la modification des joueurs hors-ligne directement en base de données
Config.AllowOfflineModifications = true

-- Temps de rechargement minimal entre deux demandes globales (secondes, anti-spam)
Config.RefreshCooldown = 3

-- Logs Discord (Webhook)
Config.Webhook = {
    Enabled = false,
    Url = '', -- Insérez votre URL Webhook Discord ici
    Title = 'NXS - Surveillance Économique',
    Color = 3066993, -- Vert émeraude
    Name = 'NXS Economy Bot',
    Avatar = ''
}
