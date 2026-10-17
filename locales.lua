Locales = {}

Locales['fr'] = {
    ['no_permission'] = "~r~Vous n'avez pas la permission d'accéder au menu d'économie.~s~",
    ['cooldown_active'] = "~y~Veuillez patienter quelques instants avant de rafraîchir.~s~",
    ['action_success'] = "~g~Opération effectuée avec succès !~s~",
    ['action_failed'] = "~r~Une erreur est survenue lors de l'opération.~s~",
    ['invalid_amount'] = "~r~Montant spécifié invalide.~s~",
    ['player_not_found'] = "~r~Joueur introuvable.~s~",
    ['money_given'] = "Vous avez crédité %s %s sur le compte %s de %s",
    ['money_removed'] = "Vous avez débité %s %s sur le compte %s de %s",
    ['money_set'] = "Vous avez fixé le compte %s de %s à %s %s",
    ['money_wiped'] = "Vous avez réinitialisé les comptes de %s",
    ['society_money_given'] = "Vous avez crédité %s %s sur la société %s",
    ['society_money_removed'] = "Vous avez débité %s %s sur la société %s",
    ['society_money_set'] = "Vous avez fixé la caisse de %s à %s %s",
    ['received_money_admin'] = "Votre compte %s a été crédité de %s %s par un administrateur.",
    ['removed_money_admin'] = "Votre compte %s a été débité de %s %s par un administrateur.",
}

function _T(str, ...)
    local lang = Config.Locale or 'fr'
    if Locales[lang] and Locales[lang][str] then
        return string.format(Locales[lang][str], ...)
    end
    return str
end
