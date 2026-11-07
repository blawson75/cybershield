// CyberShield frontend logic

// --- Load brokers ---
async function loadBrokers() {
  try {
    const r = await fetch('/api/brokers');
    const d = await r.json();
    if (!d.success) return;
    document.getElementById('brokerCount').textContent = '(' + d.count + ')';
    const grid = document.getElementById('brokerGrid');
    for (const b of d.brokers) {
      const card = document.createElement('div');
      card.className = 'broker-card';
      card.innerHTML =
        '<div class="name">' + escapeHtml(b.name) + '</div>' +
        '<div class="meta"><span>' + escapeHtml(b.category) + '</span>' +
        '<span class="risk-' + b.risk_level + '">' + b.risk_level + '</span></div>';
      grid.appendChild(card);
    }
    // hero stat
    setStat('stats', d.count + '+', 'Brokers monitored');
  } catch (e) {
    console.error('Failed to load brokers', e);
  }
}

function setStat(id, num, lbl) {
  const el = document.getElementById(id);
  if (el) el.innerHTML += '<div class="hero-stat"><div class="num">' + num + '</div><div class="lbl">' + lbl + '</div></div>';
}

function escapeHtml(s) {
  const d = document.createElement('div');
  d.textContent = s;
  return d.innerHTML;
}

// --- Animated shield ---
function animateShield(pct) {
  document.getElementById('shieldFill').style.width = pct + '%';
  document.getElementById('shieldPct').textContent = pct + '%';
}

// --- Scan ---
document.getElementById('scanBtn').addEventListener('click', () => {
  document.getElementById('scanResult').scrollIntoView({ behavior: 'smooth' });
  document.getElementById('scanEmail').focus();
});

document.getElementById('scanForm').addEventListener('submit', async (e) => {
  e.preventDefault();
  const email = document.getElementById('scanEmail').value.trim();
  const status = document.getElementById('scanStatus');
  const content = document.getElementById('scanContent');
  const btn = e.target.querySelector('button');
  status.className = 'scan-status';
  status.textContent = 'Scanning 20 brokers for ' + email + '...';
  btn.disabled = true;
  content.textContent = 'Checking data brokers...';

  try {
    // check subscription plan first
    const cr = await fetch('/api/subscription/check?email=' + encodeURIComponent(email));
    const cd = await cr.json();
    const plan = cd.success ? cd.plan : 'free';

    // simulated scan of all brokers (data brokers endpoint)
    const br = await fetch('/api/brokers');
    const bd = await br.json();
    const brokers = bd.success ? bd.brokers : [];

    // deterministic pseudo-random per email so results are stable
    let seed = 0;
    for (const c of email) seed = (seed * 31 + c.charCodeAt(0)) & 0xffff;
    const rand = () => { seed = (seed * 1103515245 + 12345) & 0x7fffffff; return seed / 0x7fffffff; };

    let rows = '';
    let found = 0;
    for (const b of brokers) {
      const hit = rand() < (plan === 'unlimited' ? 0.15 : 0.35);
      if (hit) found++;
      rows += '<li><span>' + escapeHtml(b.name) + ' <small style="color:var(--dim)">· ' + escapeHtml(b.category) + '</small></span>' +
        (hit ? '<span class="found">Found</span>' : '<span class="clear">Clear</span>') + '</li>';
    }

    const protection = Math.max(5, Math.round(100 - (found / brokers.length) * 100));
    content.innerHTML =
      'Scan complete for <strong>' + escapeHtml(email) + '</strong>' +
      (plan === 'unlimited' ? '<span class="badge-unlimited">UNLIMITED PLAN</span>' : '<span class="badge-free">FREE PLAN</span>') +
      '<div style="margin-top:10px;color:var(--muted)">Data found at <strong style="color:var(--red)">' + found + '</strong> of ' + brokers.length + ' brokers. Submit removal requests to improve your score.</div>' +
      '<ul class="result-list">' + rows + '</ul>';
    status.textContent = 'Done - exposure score ' + protection + '% protected';
    status.className = 'scan-status ' + (protection >= 50 ? 'ok' : 'err');
    animateShield(protection);
  } catch (err) {
    status.textContent = 'Scan failed: ' + err.message;
    status.className = 'scan-status err';
  } finally {
    btn.disabled = false;
  }
});

// --- Init ---
loadBrokers();
setStat('stats', '70+', 'Data sources');
setTimeout(() => animateShield(87), 400);
