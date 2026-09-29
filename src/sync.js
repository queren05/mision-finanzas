/* =====================================================================
   Sincronización entre dispositivos (Supabase)
   Una fila por usuario con todo el estado en JSON. Gana el cambio más reciente;
   si hay choque, lo local se guarda como copia en este dispositivo antes de sustituirlo.
   ===================================================================== */
const SYNC_SQL = `create table if not exists public.mision_state (
  user_id uuid primary key default auth.uid() references auth.users(id) on delete cascade,
  data jsonb not null,
  updated_at timestamptz not null default now()
);
alter table public.mision_state enable row level security;
drop policy if exists "solo mi fila" on public.mision_state;
create policy "solo mi fila" on public.mision_state
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create or replace function public.mision_touch() returns trigger
language plpgsql as $$ begin new.updated_at = now(); return new; end $$;
drop trigger if exists mision_touch on public.mision_state;
create trigger mision_touch before insert or update on public.mision_state
  for each row execute function public.mision_touch();`;

const Sync = {
  K: 'mision.sync.v1', c: null, st: 'off', err: '', timer: null, busy: false, dirty: false, applying: false,
  load() { try { this.c = JSON.parse(localStorage.getItem(this.K) || 'null'); } catch (e) { this.c = null; } if (this.c && this.c.access) this.st = 'idle'; },
  store() { try { localStorage.setItem(this.K, JSON.stringify(this.c)); } catch (e) { } },
  on() { return !!(this.c && this.c.access && this.c.url && this.c.anon); },
  payload() { const o = Object.assign({}, S); delete o.cache; return o; },
  key(o) { const x = Object.assign({}, o); delete x.snapshots; return JSON.stringify(x); },
  async api(path, o = {}) {
    const c = this.c; const h = { apikey: c.anon, 'Content-Type': 'application/json' };
    if (!o.noAuth && c.access) h.Authorization = 'Bearer ' + c.access;
    const r = await fetch(c.url.replace(/\/+$/, '') + path, { method: o.method || 'GET', headers: Object.assign(h, o.headers || {}), body: o.body, cache: 'no-store' });
    const t = await r.text(); let j = null; try { j = t ? JSON.parse(t) : null; } catch (e) { }
    if (!r.ok) { const e = new Error((j && (j.msg || j.message || j.error_description || j.error)) || ('HTTP ' + r.status)); e.status = r.status; throw e; }
    return j;
  },
  setSession(j) { Object.assign(this.c, { access: j.access_token, refresh: j.refresh_token, exp: Date.now() + (j.expires_in || 3600) * 1000, uid: (j.user && j.user.id) || this.c.uid }); this.store(); },
  async login(url, anon, email, pass, signup) {
    this.c = { url: url.trim(), anon: anon.trim(), email: email.trim() };
    const body = JSON.stringify({ email: this.c.email, password: pass });
    const j = signup ? await this.api('/auth/v1/signup', { method: 'POST', noAuth: true, body }) : await this.api('/auth/v1/token?grant_type=password', { method: 'POST', noAuth: true, body });
    if (!j || !j.access_token) { this.c = null; throw new Error(signup ? 'Cuenta creada. Confirma el correo que te ha enviado Supabase (o desactiva «Confirm email» en Authentication) y después pulsa Entrar.' : 'No se pudo iniciar sesión.'); }
    this.setSession(j);
  },
  logout() { this.c = null; this.st = 'off'; this.err = ''; try { localStorage.removeItem(this.K); } catch (e) { } },
  async ensure() {
    if (Date.now() < (this.c.exp || 0) - 60000) return;
    const j = await this.api('/auth/v1/token?grant_type=refresh_token', { method: 'POST', noAuth: true, body: JSON.stringify({ refresh_token: this.c.refresh }) });
    this.setSession(j);
  },
  async remoteMeta() { const r = await this.api('/rest/v1/mision_state?select=updated_at&limit=1'); return r && r[0] ? Date.parse(r[0].updated_at) : null; },
  async fetchRemote() { const r = await this.api('/rest/v1/mision_state?select=updated_at,data&limit=1'); return r && r[0] ? { at: Date.parse(r[0].updated_at), data: r[0].data } : null; },
  apply(remote, at) {
    this.applying = true;
    const localSnaps = S.snapshots || [], cache = S.cache;
    const next = migrate(remote); next.cache = cache;
    const m = new Map(); for (const s of next.snapshots || []) m.set(s.d, s); for (const s of localSnaps) m.set(s.d, s);
    next.snapshots = [...m.values()].sort((a, b) => a.d < b.d ? -1 : 1);
    S = next; saveNow();
    this.c.lastRemote = at; this.c.lastStr = this.key(this.payload()); this.dirty = false; this.store();
    this.applying = false; applyTheme(); render(); restartFeeds();
  },
  async push() {
    const r = await this.api('/rest/v1/mision_state?on_conflict=user_id', { method: 'POST', headers: { Prefer: 'resolution=merge-duplicates,return=representation' }, body: JSON.stringify({ user_id: this.c.uid, data: this.payload() }) });
    const at = r && r[0] ? Date.parse(r[0].updated_at) : Date.now();
    this.c.lastRemote = at; this.c.lastStr = this.key(this.payload()); this.c.lastPush = Date.now(); this.dirty = false; this.store();
  },
  schedule() {
    if (!this.on() || this.applying || !S) return;
    const k = this.key(this.payload()); if (k === this.c.lastStr) return;
    this.dirty = true; this.c.localAt = Date.now();
    clearTimeout(this.timer); this.timer = setTimeout(() => this.run(), 2500);
  },
  async run(firstTime) {
    if (this.busy || !this.on()) return; this.busy = true; this.st = 'syncing'; updateSyncUI();
    try {
      await this.ensure();
      const rAt = await this.remoteMeta();
      if (rAt == null) { await this.push(); }
      else if (!this.c.lastRemote || rAt > this.c.lastRemote) {
        if (firstTime === 'ask' && !S.demo && (S.txs.length || S.accounts.length)) { this.busy = false; this.st = 'idle'; return askFirstSync(); }
        if (this.dirty && (this.c.localAt || 0) > rAt) await this.push();
        else {
          if (this.dirty) { try { localStorage.setItem('mision.copia-antes-de-sincronizar', JSON.stringify(S)); } catch (e) { } }
          const rem = await this.fetchRemote(); if (rem) { this.apply(rem.data, rem.at); toast('Datos actualizados desde la nube'); }
        }
      } else if (this.dirty) await this.push();
      this.st = 'ok'; this.err = ''; this.c.lastOk = Date.now(); this.store();
    } catch (e) {
      this.st = 'error'; this.err = e.status === 401 || e.status === 400 && /refresh/i.test(e.message) ? 'La sesión ha caducado. Vuelve a entrar.' : e.status === 404 || /mision_state/.test(e.message) ? 'Falta crear la tabla en Supabase (paso 2).' : e.message;
    } finally { this.busy = false; updateSyncUI(); }
  },
};
function askFirstSync() {
  openSheet({
    title: 'Ya hay datos en la nube', html: `<div class="stack"><p style="margin:0">Tu cuenta ya tiene datos guardados y este dispositivo también. ¿Con cuáles te quedas?</p>
    <button class="btn primary block" id="sCloud">Usar los de la nube</button><button class="btn block" id="sLocal">Subir los de este dispositivo</button>
    <p class="note" style="margin:0">Lo que no elijas se guarda como copia de respaldo en este dispositivo.</p></div>`,
    onMount() {
      $('#sCloud').addEventListener('click', async () => { try { localStorage.setItem('mision.copia-antes-de-sincronizar', JSON.stringify(S)); } catch (e) { } closeSheet(); const r = await Sync.fetchRemote(); if (r) Sync.apply(r.data, r.at); toast('Sincronizado'); });
      $('#sLocal').addEventListener('click', async () => { closeSheet(); Sync.dirty = true; await Sync.push(); Sync.st = 'ok'; updateSyncUI(); toast('Datos subidos a la nube'); });
    }
  });
}
function updateSyncUI() { if (UI.route === 'more/sync') { const el = $('#syncState'); if (el) el.innerHTML = syncStateHtml(); } }
function syncStateHtml() {
  if (!Sync.on()) return '<span class="chip">Sin sincronizar</span>';
  const m = { ok: ['pos', 'Sincronizado'], syncing: ['', 'Sincronizando…'], error: ['neg', 'Error'], idle: ['', 'Conectado'] }[Sync.st] || ['', Sync.st];
  return `<span class="chip ${m[0]}">${m[1]}</span> <span class="small muted">${esc(Sync.c.email || '')}${Sync.c.lastOk ? ' · ' + ago(Sync.c.lastOk) : ''}</span>${Sync.err ? `<div class="err" style="margin-top:6px">${esc(Sync.err)}</div>` : ''}`;
}
VIEWS['more/sync'] = () => {
  const c = Sync.c || {};
  if (Sync.on()) return `<section class="card stack"><b>Sincronización activa</b><div id="syncState">${syncStateHtml()}</div>
      <p class="note" style="margin:0">Todo lo que cambies aquí aparece en tus otros dispositivos en unos segundos (al abrir la app o volver a ella).</p>
      <div class="row2"><button class="btn primary" data-action="sync-now">Sincronizar ahora</button><button class="btn danger" data-action="sync-out" data-confirm="Toca otra vez para salir">Cerrar sesión</button></div></section>
    <p class="note">Proyecto: ${esc(c.url)}</p>`;
  return `<section class="card stack"><b>Para qué sirve</b><p class="note" style="margin:0">Usa la misma cuenta en la web de tu servidor y en la app del iPhone y verás lo mismo en los dos. Los datos van a tu propio proyecto de Supabase (plan gratuito de sobra) y cada usuario solo puede leer su fila.</p></section>
  <section class="card stack"><b>1 · Crea un proyecto en Supabase</b><p class="note" style="margin:0">En supabase.com → New project. En Project Settings → API copia la <b>Project URL</b> y la clave <b>anon public</b>.</p></section>
  <section class="card stack"><b>2 · Crea la tabla</b><p class="note" style="margin:0">SQL Editor → New query → pega esto y pulsa Run:</p>
    <div class="tbl-wrap"><pre style="margin:0;padding:10px;font:11.5px/1.5 var(--f-num);white-space:pre">${esc(SYNC_SQL)}</pre></div><button class="btn sm" data-action="copy-sql">Copiar SQL</button></section>
  <section class="card form"><b>3 · Conecta este dispositivo</b>
    <label class="field"><span>Project URL</span><input type="url" id="syUrl" value="${esc(c.url || '')}" placeholder="https://xxxx.supabase.co" autocomplete="off"></label>
    <label class="field"><span>Clave anon public</span><input type="password" id="syKey" value="${esc(c.anon || '')}" placeholder="eyJhbGciOi…" autocomplete="off"></label>
    <label class="field"><span>Tu correo</span><input type="text" id="syMail" value="${esc(c.email || '')}" inputmode="email" autocomplete="username"></label>
    <label class="field"><span>Contraseña</span><input type="password" id="syPass" autocomplete="current-password"></label>
    <div class="err" id="syErr"></div>
    <div class="row2"><button class="btn primary" data-action="sync-in">Entrar</button><button class="btn" data-action="sync-up">Crear cuenta</button></div>
    <p class="note" style="margin:0">La primera vez pulsa «Crear cuenta». En los demás dispositivos, «Entrar» con los mismos datos.</p></section>`;
};
async function syncLogin(signup) {
  const url = $('#syUrl').value, key = $('#syKey').value, mail = $('#syMail').value, pass = $('#syPass').value;
  if (!/^https:\/\//.test(url.trim()) || !key.trim() || !mail.trim() || pass.length < 6) { $('#syErr').textContent = 'Rellena la URL (https://…), la clave, el correo y una contraseña de al menos 6 caracteres.'; return; }
  $('#syErr').textContent = signup ? 'Creando cuenta…' : 'Entrando…';
  try { await Sync.login(url, key, mail, pass, signup); render(); await Sync.run('ask'); }
  catch (e) { const el = $('#syErr'); if (el) el.textContent = e.message; }
}
Object.assign(ACT, {
  'sync-in': () => syncLogin(false),
  'sync-up': () => syncLogin(true),
  'sync-now': () => { Sync.dirty = Sync.dirty || Sync.key(Sync.payload()) !== Sync.c.lastStr; Sync.run(); },
  'sync-out': () => { Sync.logout(); render(); toast('Sesión cerrada. Tus datos siguen en este dispositivo.'); },
  'copy-sql': async () => { try { await navigator.clipboard.writeText(SYNC_SQL); toast('SQL copiado'); } catch (e) { toast('Selecciona el texto y cópialo a mano'); } },
});
TITLES['more/sync'] = 'Sincronización';
Sync.load();
setInterval(() => { if (!document.hidden && Sync.on()) Sync.run(); }, 45000);
document.addEventListener('visibilitychange', () => { if (!document.hidden && Sync.on()) Sync.run(); });
