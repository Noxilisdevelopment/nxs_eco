# 💰 NXS Économie - Gestion & Surveillance Économique

Script complet et moderne de surveillance et gestion de l'économie pour serveurs **FiveM (ESX Legacy / ox_inventory / oxmysql)**.

---

## 🌟 Fonctionnalités Principales

### 📊 1. Vue Globale de l'Économie (Dashboard KPIs)
- **Masse Monétaire Totale** : Calcul en temps réel de tout l'argent circulant sur le serveur (Citoyens + Entreprises).
- **Total Argent Liquide (Cash)** : Somme totale de l'argent liquide détenu par tous les citoyens (en ligne et hors ligne).
- **Total Argent Banque** : Somme totale de l'argent sur les comptes bancaires des joueurs.
- **Total Argent Sale (Black Money)** : Détection et totalisation de l'argent sale.
- **Caisses Entreprises** : Somme globale des comptes de sociétés (`addon_account_data`).
- **Moyenne de fortune par joueur** : Ratio de répartition de la richesse.
- **Citoyen le plus riche** : Affichage instantané du record de fortune avec nom et montant.

### 👥 2. Tableau & Gestion des Joueurs (En Ligne & Hors Ligne)
- Liste complète de tous les citoyens enregistrés en base de données.
- Statut en direct (🟢 **En ligne** avec ID serveur / ⚪ **Hors ligne**).
- Détail précis pour chaque joueur : **Argent Liquide**, **Argent Banque**, **Argent Sale**, **Total Fortune**, **Métier** et **Grade**.
- **Recherche instantanée** par Nom, Prénom, ID serveur ou Licence.
- **Filtres rapides** : Tous, En ligne uniquement, Hors ligne uniquement.
- **Tri dynamique** : Du plus riche au moins riche, par argent liquide, par banque, alphabétique.
- **Pagination fluide** pour supporter des milliers de joueurs sans baisse de FPS.

### ⚙️ 3. Actions Administratives Sécurisées
- **Créditer (+)** : Ajouter du liquide, de la banque ou de l'argent sale avec motif.
- **Débiter (-)** : Retirer un montant spécifique.
- **Fixer (=)** : Définir un solde exact.
- **Wipe Économique** : Réinitialiser les comptes d'un joueur à zéro avec fenêtre de confirmation de sécurité.
- **Préréglages rapides** : Boutons `+10 000`, `+50 000`, `+100 000`, `+500 000`, `+1 000 000`.
- Compatible avec les joueurs **en ligne** (mise à jour directe xPlayer) et **hors ligne** (mise à jour MySQL automatique).

### 🏢 4. Gestion des Comptes Sociétés (Entreprises)
- Visualisation de toutes les caisses d'entreprises (`society_police`, `society_ambulance`, `society_cardealer`, `society_mechanic`, etc.).
- Gestion de caisse directe (Créditer, Débiter, Fixer le montant d'une société).

### 🏆 5. Top 10 Fortunes & Audit
- Onglet dédié au **Top 10 des plus grandes fortunes du serveur** avec podium (Or, Argent, Bronze).
- **Bouton Export CSV** en 1 clic pour exporter l'intégralité de l'économie vers un fichier Excel / CSV pour audit comptable.

---

## 🎮 Commandes

### En Jeu (Staff / Admin)
- `/eco` : Ouvre le panel d'administration économique (Fermeture avec `Échap`).
- `/economie` ou `/ecomenu` : Alias de commande.

### En Console Serveur (FXServer)
- `eco_stats` : Affiche un rapport complet de la masse monétaire dans la console FiveM.
- `eco_top [nombre]` : Affiche le classement console des plus grandes fortunes (ex: `eco_top 10`).

---

## 📁 Installation

1. Le dossier `nxs_economy` est situé dans :
   `resources/[4.Metier]/[emploi]/nxs_economy`
2. Comme `[4.Metier]` est déjà démarré dans votre `server.cfg`, la ressource se lancera automatiquement.
3. Pour configurer les groupes autorisés, ouvrez `config.lua` :
   ```lua
   Config.AllowedGroups = {
       ['fondateur']   = true,
       ['owner']       = true,
       ['superadmin']  = true,
       ['admin']       = true,
       ['staff']       = true
   }
   ```
4. Vous pouvez également ajouter vos webhooks Discord dans `Config.Webhook` pour archiver chaque opération financière réalisée par le staff.
