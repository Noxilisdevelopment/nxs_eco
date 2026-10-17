/* ====================================================================
   NXS ECONOMY - JAVASCRIPT CONTROLLER
   ==================================================================== */

const state = {
    data: null,
    currency: { Symbol: '$', Position: 'after', Separator: ' ' },
    activeTab: 'tab-players',
    filterStatus: 'all',
    searchQuery: '',
    sortOption: 'total_desc',
    currentPage: 1,
    pageSize: 20,
    selectedPlayer: null,
    selectedSociety: null,
    selectedAccount: 'money',
};

// ====================================================================
// UTILS & FORMATTERS
// ====================================================================

function formatMoney(amount) {
    const num = Math.floor(Number(amount) || 0);
    const sep = state.currency.Separator || ' ';
    const formatted = num.toString().replace(/\B(?=(\d{3})+(?!\d))/g, sep);
    const sym = state.currency.Symbol || '$';
    return state.currency.Position === 'before' ? `${sym} ${formatted}` : `${formatted} ${sym}`;
}

function escapeHtml(str) {
    if (!str) return '';
    return String(str)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#039;');
}

function showToast(message, type = 'info') {
    const container = document.getElementById('toast-container');
    if (!container) return;
    const toast = document.createElement('div');
    toast.className = `toast ${type}`;
    toast.textContent = message;
    container.appendChild(toast);
    setTimeout(() => {
        toast.style.opacity = '0';
        toast.style.transition = 'opacity 0.25s ease';
        setTimeout(() => toast.remove(), 250);
    }, 2800);
}

function sendNui(event, data = {}) {
    return fetch(`https://nxs_economy/${event}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data)
    }).catch(err => console.error(`Error sending NUI event ${event}:`, err));
}

// ====================================================================
// RENDERING OVERVIEW
// ====================================================================

function renderOverview() {
    if (!state.data || !state.data.stats) return;
    const s = state.data.stats;

    document.getElementById('stat-grand-total').textContent = formatMoney(s.grandTotal || 0);
    document.getElementById('stat-total-cash').textContent = formatMoney(s.totalCash || 0);
    document.getElementById('stat-total-bank').textContent = formatMoney(s.totalBank || 0);
    document.getElementById('stat-total-societies').textContent = formatMoney(s.totalSocieties || 0);

    const richest = s.richestPlayer || { name: 'Aucun', total: 0 };
    document.getElementById('stat-richest-name').textContent = escapeHtml(richest.name);
    document.getElementById('stat-richest-amount').textContent = formatMoney(richest.total);

    document.getElementById('count-all-players').textContent = s.totalPlayers || 0;
    document.getElementById('count-all-societies').textContent = (state.data.societies || []).length;
    document.getElementById('filter-online-count').textContent = s.onlinePlayers || 0;
    document.getElementById('filter-offline-count').textContent = Math.max(0, (s.totalPlayers || 0) - (s.onlinePlayers || 0));
}

// ====================================================================
// RENDERING PLAYERS
// ====================================================================

function getFilteredPlayers() {
    if (!state.data || !state.data.players) return [];
    let list = state.data.players;

    if (state.filterStatus === 'online') {
        list = list.filter(p => p.online);
    } else if (state.filterStatus === 'offline') {
        list = list.filter(p => !p.online);
    }

    if (state.searchQuery.trim() !== '') {
        const q = state.searchQuery.toLowerCase().trim();
        list = list.filter(p => {
            const nameMatch = (p.name || '').toLowerCase().includes(q);
            const idfMatch = (p.identifier || '').toLowerCase().includes(q);
            const srvMatch = p.serverId && String(p.serverId) === q;
            const jobMatch = (p.job || '').toLowerCase().includes(q);
            return nameMatch || idfMatch || srvMatch || jobMatch;
        });
    }

    list = [...list];
    switch (state.sortOption) {
        case 'total_desc':
            list.sort((a, b) => (b.total || 0) - (a.total || 0));
            break;
        case 'total_asc':
            list.sort((a, b) => (a.total || 0) - (b.total || 0));
            break;
        case 'cash_desc':
            list.sort((a, b) => (b.cash || 0) - (a.cash || 0));
            break;
        case 'bank_desc':
            list.sort((a, b) => (b.bank || 0) - (a.bank || 0));
            break;
        case 'name_asc':
            list.sort((a, b) => (a.name || '').localeCompare(b.name || ''));
            break;
    }

    return list;
}

function renderPlayers() {
    const tbody = document.getElementById('players-table-body');
    const emptyMsg = document.getElementById('no-players-msg');
    const allFiltered = getFilteredPlayers();

    const totalCount = allFiltered.length;
    const totalPages = Math.max(1, Math.ceil(totalCount / state.pageSize));
    if (state.currentPage > totalPages) state.currentPage = totalPages;

    const startIdx = (state.currentPage - 1) * state.pageSize;
    const pageItems = allFiltered.slice(startIdx, startIdx + state.pageSize);

    tbody.innerHTML = '';

    if (pageItems.length === 0) {
        emptyMsg.style.display = 'block';
    } else {
        emptyMsg.style.display = 'none';
        pageItems.forEach(player => {
            const tr = document.createElement('tr');

            const statusHtml = player.online
                ? `<span class="status-tag online">En ligne #${player.serverId}</span>`
                : `<span class="status-tag offline">Hors ligne</span>`;

            tr.innerHTML = `
                <td>
                    <div class="p-cell">
                        <span class="p-name">${escapeHtml(player.name)}</span>
                        <span class="p-id">${escapeHtml(player.identifier)}</span>
                    </div>
                </td>
                <td>${statusHtml}</td>
                <td>
                    <div class="job-lbl">${escapeHtml(player.job || 'Chômeur')}</div>
                    <div class="job-grd">${escapeHtml(player.jobGrade || '')}</div>
                </td>
                <td class="text-right amt cash-color">${formatMoney(player.cash)}</td>
                <td class="text-right amt bank-color">${formatMoney(player.bank)}</td>
                <td class="text-right amt red-color">${formatMoney(player.blackMoney)}</td>
                <td class="text-right amt-total">${formatMoney(player.total)}</td>
                <td class="text-center">
                    <button class="btn-manage" data-id="${escapeHtml(player.identifier)}">Gérer</button>
                </td>
            `;

            tr.querySelector('.btn-manage').addEventListener('click', () => {
                openPlayerModal(player);
            });

            tbody.appendChild(tr);
        });
    }

    const endIdx = Math.min(startIdx + state.pageSize, totalCount);
    document.getElementById('pagination-info').textContent = totalCount === 0
        ? 'Aucun résultat'
        : `${startIdx + 1} - ${endIdx} sur ${totalCount} joueur(s)`;
    document.getElementById('page-current').textContent = `Page ${state.currentPage} / ${totalPages}`;
    document.getElementById('btn-page-prev').disabled = state.currentPage <= 1;
    document.getElementById('btn-page-next').disabled = state.currentPage >= totalPages;
}

// ====================================================================
// RENDERING SOCIETIES
// ====================================================================

function renderSocieties() {
    const tbody = document.getElementById('societies-table-body');
    const emptyMsg = document.getElementById('no-societies-msg');
    const societies = (state.data && state.data.societies) || [];

    tbody.innerHTML = '';
    if (societies.length === 0) {
        emptyMsg.style.display = 'block';
        return;
    }
    emptyMsg.style.display = 'none';

    societies.forEach(soc => {
        const tr = document.createElement('tr');
        tr.innerHTML = `
            <td>
                <span class="p-name">${escapeHtml(soc.label)}</span>
            </td>
            <td>
                <span class="p-id">${escapeHtml(soc.name)}</span>
            </td>
            <td class="text-right amt-total soc-color">
                ${formatMoney(soc.money)}
            </td>
            <td class="text-center">
                <button class="btn-manage btn-soc-action">Modifier</button>
            </td>
        `;

        tr.querySelector('.btn-soc-action').addEventListener('click', () => {
            openSocietyModal(soc);
        });

        tbody.appendChild(tr);
    });
}

// ====================================================================
// RENDERING LEADERBOARD
// ====================================================================

function renderLeaderboard() {
    const container = document.getElementById('leaderboard-container');
    container.innerHTML = '';

    if (!state.data || !state.data.players) return;
    const top10 = state.data.players.slice(0, 10);

    top10.forEach((player, idx) => {
        const rank = idx + 1;
        const row = document.createElement('div');
        row.className = `leader-row pos-${rank}`;

        const statusText = player.online ? `En ligne #${player.serverId}` : 'Hors ligne';

        row.innerHTML = `
            <div class="leader-left">
                <div class="leader-pos">#${rank}</div>
                <div class="leader-details">
                    <h4>${escapeHtml(player.name)}</h4>
                    <p>${escapeHtml(player.job || 'Chômeur')} • ${statusText}</p>
                </div>
            </div>
            <div class="leader-right">
                <div class="leader-tot">${formatMoney(player.total)}</div>
                <div class="leader-sub">Liq: ${formatMoney(player.cash)} | Bq: ${formatMoney(player.bank)}</div>
            </div>
        `;

        row.addEventListener('click', () => {
            openPlayerModal(player);
        });

        container.appendChild(row);
    });
}

// ====================================================================
// MODALS
// ====================================================================

function openPlayerModal(player) {
    state.selectedPlayer = player;
    state.selectedAccount = 'money';

    document.getElementById('modal-player-name').textContent = player.name;
    document.getElementById('modal-player-identifier').textContent = player.identifier;

    document.getElementById('m-val-cash').textContent = formatMoney(player.cash);
    document.getElementById('m-val-bank').textContent = formatMoney(player.bank);
    document.getElementById('m-val-black').textContent = formatMoney(player.blackMoney);

    document.getElementById('modal-amount').value = '';
    document.getElementById('modal-reason').value = '';

    document.querySelectorAll('.seg-btn').forEach(btn => {
        btn.classList.toggle('active', btn.dataset.account === state.selectedAccount);
    });

    document.getElementById('player-modal').style.display = 'flex';
}

function closePlayerModal() {
    document.getElementById('player-modal').style.display = 'none';
    state.selectedPlayer = null;
}

function openSocietyModal(soc) {
    state.selectedSociety = soc;
    document.getElementById('modal-soc-name').textContent = soc.label;
    document.getElementById('modal-soc-id').textContent = soc.name;
    document.getElementById('m-soc-bal').textContent = formatMoney(soc.money);
    document.getElementById('modal-soc-amount').value = '';
    document.getElementById('modal-soc-reason').value = '';

    document.getElementById('society-modal').style.display = 'flex';
}

function closeSocietyModal() {
    document.getElementById('society-modal').style.display = 'none';
    state.selectedSociety = null;
}

let confirmCb = null;
function showConfirm(title, desc, onOk) {
    document.getElementById('confirm-title').textContent = title;
    document.getElementById('confirm-desc').textContent = desc;
    confirmCb = onOk;
    document.getElementById('confirm-modal').style.display = 'flex';
}

function hideConfirm() {
    document.getElementById('confirm-modal').style.display = 'none';
    confirmCb = null;
}

// ====================================================================
// CSV EXPORT
// ====================================================================

function exportCSV() {
    if (!state.data || !state.data.players || state.data.players.length === 0) {
        showToast("Aucune donnée à exporter.", "error");
        return;
    }

    let csv = "Identifiant;Nom RP;Statut;Metier;Grade;Argent Liquide;Argent Banque;Argent Sale;Total\r\n";
    state.data.players.forEach(p => {
        const row = [
            `"${p.identifier}"`,
            `"${p.name || ''}"`,
            p.online ? "En ligne" : "Hors ligne",
            `"${p.job || ''}"`,
            `"${p.jobGrade || ''}"`,
            p.cash || 0,
            p.bank || 0,
            p.blackMoney || 0,
            p.total || 0
        ];
        csv += row.join(";") + "\r\n";
    });

    const blob = new Blob(["\uFEFF" + csv], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `economie_${new Date().toISOString().slice(0, 10)}.csv`;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
    showToast("Audit exporté avec succès !", "success");
}

// ====================================================================
// EVENT BINDINGS
// ====================================================================

document.addEventListener('DOMContentLoaded', () => {
    // Refresh
    const btnRefresh = document.getElementById('btn-refresh');
    btnRefresh.addEventListener('click', () => {
        const icon = btnRefresh.querySelector('.icon-refresh');
        icon.classList.add('spinning');
        sendNui('refreshData').then(res => res && res.json()).then(resp => {
            if (resp && resp.success) {
                state.data = resp.data;
                renderOverview();
                renderPlayers();
                renderSocieties();
                renderLeaderboard();
                showToast("Données actualisées !", "success");
            }
        }).finally(() => {
            setTimeout(() => icon.classList.remove('spinning'), 500);
        });
    });

    // Close
    document.getElementById('btn-close').addEventListener('click', () => {
        sendNui('closeUI');
    });

    // Click outside panel to close
    document.getElementById('app').addEventListener('click', (e) => {
        if (e.target.id === 'app') {
            sendNui('closeUI');
        }
    });

    // Export
    document.getElementById('btn-export').addEventListener('click', exportCSV);

    // Tabs
    document.querySelectorAll('.tab').forEach(tab => {
        tab.addEventListener('click', () => {
            document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
            document.querySelectorAll('.tab-panel').forEach(p => p.classList.remove('active'));

            tab.classList.add('active');
            const targetId = tab.dataset.tab;
            document.getElementById(targetId).classList.add('active');
            state.activeTab = targetId;

            document.getElementById('players-tools').style.display = (targetId === 'tab-players') ? 'flex' : 'none';

            if (targetId === 'tab-players') renderPlayers();
            if (targetId === 'tab-societies') renderSocieties();
            if (targetId === 'tab-leaderboard') renderLeaderboard();
        });
    });

    // Search
    const searchInput = document.getElementById('player-search');
    const searchClear = document.getElementById('search-clear');
    searchInput.addEventListener('input', (e) => {
        state.searchQuery = e.target.value;
        searchClear.style.display = state.searchQuery ? 'block' : 'none';
        state.currentPage = 1;
        renderPlayers();
    });
    searchClear.addEventListener('click', () => {
        searchInput.value = '';
        state.searchQuery = '';
        searchClear.style.display = 'none';
        state.currentPage = 1;
        renderPlayers();
    });

    // Filter
    document.querySelectorAll('.filter-btn').forEach(btn => {
        btn.addEventListener('click', () => {
            document.querySelectorAll('.filter-btn').forEach(b => b.classList.remove('active'));
            btn.classList.add('active');
            state.filterStatus = btn.dataset.filter;
            state.currentPage = 1;
            renderPlayers();
        });
    });

    // Sort
    document.getElementById('sort-select').addEventListener('change', (e) => {
        state.sortOption = e.target.value;
        state.currentPage = 1;
        renderPlayers();
    });

    // Pager
    document.getElementById('btn-page-prev').addEventListener('click', () => {
        if (state.currentPage > 1) {
            state.currentPage--;
            renderPlayers();
        }
    });
    document.getElementById('btn-page-next').addEventListener('click', () => {
        state.currentPage++;
        renderPlayers();
    });

    // Segmented account pills
    document.querySelectorAll('.seg-btn').forEach(btn => {
        btn.addEventListener('click', () => {
            document.querySelectorAll('.seg-btn').forEach(b => b.classList.remove('active'));
            btn.classList.add('active');
            state.selectedAccount = btn.dataset.account;
        });
    });

    // Presets Player
    document.querySelectorAll('.preset-btn').forEach(btn => {
        btn.addEventListener('click', () => {
            const cur = Number(document.getElementById('modal-amount').value) || 0;
            const add = Number(btn.dataset.amount) || 0;
            document.getElementById('modal-amount').value = cur + add;
        });
    });

    // Presets Society
    document.querySelectorAll('.preset-soc-btn').forEach(btn => {
        btn.addEventListener('click', () => {
            const cur = Number(document.getElementById('modal-soc-amount').value) || 0;
            const add = Number(btn.dataset.amount) || 0;
            document.getElementById('modal-soc-amount').value = cur + add;
        });
    });

    // Modal Close
    document.getElementById('btn-close-modal').addEventListener('click', closePlayerModal);
    document.getElementById('btn-close-soc-modal').addEventListener('click', closeSocietyModal);

    // Player Actions
    document.getElementById('btn-act-give').addEventListener('click', () => {
        const amount = Number(document.getElementById('modal-amount').value);
        if (!amount || amount <= 0) return showToast("Montant invalide", "error");
        sendNui('executePlayerAction', {
            identifier: state.selectedPlayer.identifier,
            action: 'give',
            account: state.selectedAccount,
            amount: amount,
            reason: document.getElementById('modal-reason').value
        });
        closePlayerModal();
    });

    document.getElementById('btn-act-remove').addEventListener('click', () => {
        const amount = Number(document.getElementById('modal-amount').value);
        if (!amount || amount <= 0) return showToast("Montant invalide", "error");
        sendNui('executePlayerAction', {
            identifier: state.selectedPlayer.identifier,
            action: 'remove',
            account: state.selectedAccount,
            amount: amount,
            reason: document.getElementById('modal-reason').value
        });
        closePlayerModal();
    });

    document.getElementById('btn-act-set').addEventListener('click', () => {
        const amount = Number(document.getElementById('modal-amount').value);
        if (isNaN(amount) || amount < 0) return showToast("Montant invalide", "error");
        sendNui('executePlayerAction', {
            identifier: state.selectedPlayer.identifier,
            action: 'set',
            account: state.selectedAccount,
            amount: amount,
            reason: document.getElementById('modal-reason').value
        });
        closePlayerModal();
    });

    document.getElementById('btn-act-wipe').addEventListener('click', () => {
        const pName = state.selectedPlayer.name;
        showConfirm(
            "Wipe des comptes",
            `Remettre à zéro tous les comptes de ${pName} ?`,
            () => {
                sendNui('executePlayerAction', {
                    identifier: state.selectedPlayer.identifier,
                    action: 'wipe',
                    amount: 0,
                    reason: document.getElementById('modal-reason').value || 'Wipe Économique'
                });
                closePlayerModal();
            }
        );
    });

    // Society Actions
    document.getElementById('btn-soc-give').addEventListener('click', () => {
        const amount = Number(document.getElementById('modal-soc-amount').value);
        if (!amount || amount <= 0) return showToast("Montant invalide", "error");
        sendNui('executeSocietyAction', {
            accountName: state.selectedSociety.name,
            action: 'give',
            amount: amount,
            reason: document.getElementById('modal-soc-reason').value
        });
        closeSocietyModal();
    });

    document.getElementById('btn-soc-remove').addEventListener('click', () => {
        const amount = Number(document.getElementById('modal-soc-amount').value);
        if (!amount || amount <= 0) return showToast("Montant invalide", "error");
        sendNui('executeSocietyAction', {
            accountName: state.selectedSociety.name,
            action: 'remove',
            amount: amount,
            reason: document.getElementById('modal-soc-reason').value
        });
        closeSocietyModal();
    });

    document.getElementById('btn-soc-set').addEventListener('click', () => {
        const amount = Number(document.getElementById('modal-soc-amount').value);
        if (isNaN(amount) || amount < 0) return showToast("Montant invalide", "error");
        sendNui('executeSocietyAction', {
            accountName: state.selectedSociety.name,
            action: 'set',
            amount: amount,
            reason: document.getElementById('modal-soc-reason').value
        });
        closeSocietyModal();
    });

    // Confirm
    document.getElementById('btn-confirm-cancel').addEventListener('click', hideConfirm);
    document.getElementById('btn-confirm-ok').addEventListener('click', () => {
        if (confirmCb) confirmCb();
        hideConfirm();
    });
});

// Escape key
window.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
        const confirmModal = document.getElementById('confirm-modal');
        const playerModal = document.getElementById('player-modal');
        const socModal = document.getElementById('society-modal');

        if (confirmModal && confirmModal.style.display === 'flex') {
            hideConfirm();
            return;
        }
        if (playerModal && playerModal.style.display === 'flex') {
            closePlayerModal();
            return;
        }
        if (socModal && socModal.style.display === 'flex') {
            closeSocietyModal();
            return;
        }

        const app = document.getElementById('app');
        if (app && app.style.display !== 'none') {
            sendNui('closeUI');
        }
    }
});

// Messages
window.addEventListener('message', (event) => {
    const item = event.data;
    if (!item) return;

    if (item.action === 'open') {
        state.data = item.data;
        if (item.currency) state.currency = item.currency;
        document.getElementById('app').style.display = 'flex';
        renderOverview();
        renderPlayers();
        renderSocieties();
        renderLeaderboard();
    } else if (item.action === 'close') {
        document.getElementById('app').style.display = 'none';
        closePlayerModal();
        closeSocietyModal();
        hideConfirm();
    } else if (item.action === 'updateData') {
        state.data = item.data;
        renderOverview();
        renderPlayers();
        renderSocieties();
        renderLeaderboard();
        showToast("Mise à jour effectuée !", "success");
    }
});

// Standalone Preview
if (window.location.protocol === 'file:' || !window.GetParentResourceName) {
    window.addEventListener('load', () => {
        const mockData = {
            stats: {
                totalEconomy: 14785400,
                totalCash: 3120500,
                totalBank: 11664900,
                totalBlackMoney: 450000,
                totalSocieties: 5240000,
                grandTotal: 20025400,
                totalPlayers: 184,
                onlinePlayers: 14,
                averageMoney: 80355,
                richestPlayer: {
                    name: 'Alexandre Fontaine',
                    total: 3450000,
                    online: true
                }
            },
            players: [
                { identifier: 'license:33f6aabddfd16c6d8eceeb3b81d92d541c6f48ec', name: 'Alexandre Fontaine', online: true, serverId: 1, cash: 250000, bank: 3200000, blackMoney: 0, total: 3450000, job: 'Gouvernement', jobGrade: 'Gouverneur', group: 'fondateur' },
                { identifier: 'license:8a27d4c7b89e102f431908d17203eefb40129a99', name: 'Marco Rossi', online: true, serverId: 4, cash: 540000, bank: 2100000, blackMoney: 120000, total: 2760000, job: 'Tequilala', jobGrade: 'Patron', group: 'user' },
                { identifier: 'license:1100001111c4878a992bc03948eec1928374a2b1', name: 'Sarah Jenkins', online: true, serverId: 7, cash: 120000, bank: 1850000, blackMoney: 0, total: 1970000, job: 'Police LSPD', jobGrade: 'Capitaine', group: 'admin' },
                { identifier: 'license:44f128ab901726cf889210092837418293021944', name: 'Thomas Vercetti', online: false, serverId: null, cash: 95000, bank: 1420000, blackMoney: 230000, total: 1745000, job: 'Concessionnaire', jobGrade: 'Gérant', group: 'user' },
                { identifier: 'license:9920194817263548192039485710293847561029', name: 'Elena Rostova', online: false, serverId: null, cash: 45000, bank: 1250000, blackMoney: 0, total: 1295000, job: 'Avocat DOJ', jobGrade: 'Associé', group: 'user' },
                { identifier: 'license:7738291048291039481726354819203948571029', name: 'David Miller', online: true, serverId: 12, cash: 62000, bank: 980000, blackMoney: 0, total: 1042000, job: 'EMS Hopital', jobGrade: 'Médecin Chef', group: 'staff' },
                { identifier: 'license:6655443322110099887766554433221100998877', name: 'Lucas Martin', online: false, serverId: null, cash: 31000, bank: 820000, blackMoney: 50000, total: 901000, job: 'Mécano Benny', jobGrade: 'Chef Mécano', group: 'user' }
            ],
            societies: [
                { name: 'society_police', label: 'Police Nationale (LSPD)', money: 2150000 },
                { name: 'society_ambulance', label: 'Services de Santé (EMS)', money: 1420000 },
                { name: 'society_cardealer', label: 'Concessionnaire Automobile', money: 890000 },
                { name: 'society_mechanic', label: 'Garage Benny', money: 520000 },
                { name: 'society_taxi', label: 'Compagnie Taxi', money: 260000 }
            ]
        };

        window.postMessage({
            action: 'open',
            data: mockData,
            currency: { Symbol: '$', Position: 'after', Separator: ' ' }
        }, '*');
    });
}
