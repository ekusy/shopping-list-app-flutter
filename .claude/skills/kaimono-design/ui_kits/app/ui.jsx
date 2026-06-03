// Shared UI primitives for the Kaimono app kit.
// Iconography matches the real app: emoji + unicode glyphs (▼ ▲ ☰ ✕ ＋ etc.) —
// no icon-font ligatures, so it renders identically everywhere.
const { useState, useEffect, useRef } = React;

// ---- Tiny status-bar SVG icons (decorative) ----
function StatusIcons() {
  const c = '#2C3E50';
  return (
    <div className="sb-r">
      <svg width="17" height="13" viewBox="0 0 17 13" fill={c}><rect x="0" y="9" width="3" height="4" rx="1"/><rect x="4.5" y="6" width="3" height="7" rx="1"/><rect x="9" y="3" width="3" height="10" rx="1"/><rect x="13.5" y="0" width="3" height="13" rx="1"/></svg>
      <svg width="17" height="13" viewBox="0 0 18 14" fill={c}><path d="M9 14l9-11A14 14 0 0 0 0 3l9 11z"/></svg>
      <svg width="24" height="13" viewBox="0 0 26 14"><rect x="0.5" y="0.5" width="22" height="13" rx="3.5" fill="none" stroke={c} opacity="0.5"/><rect x="2" y="2" width="17" height="10" rx="2" fill={c}/><rect x="24" y="4" width="2" height="6" rx="1" fill={c} opacity="0.5"/></svg>
    </div>
  );
}

// ---- Phone shell: bezel + status bar + gesture nav ----
function PhoneShell({ children }) {
  return (
    <div className="phone">
      <div className="statusbar">
        <span>9:41</span>
        <div className="punch"></div>
        <StatusIcons />
      </div>
      <div className="screen">{children}</div>
      <div className="navpill"></div>
    </div>
  );
}

// ---- App bar ----
function AppBar({ groupName, onSwitch, onTags, onMenu }) {
  return (
    <div className="appbar">
      <button className="appbar-title" onClick={onSwitch}>
        <span className="nm">{groupName}</span>
        <span className="caret-sm">▼</span>
      </button>
      <div className="appbar-spacer"></div>
      <button className="btn-tonal" onClick={onTags}>タグ</button>
      <button className="iconbtn" onClick={onMenu} aria-label="メニューを開く">☰</button>
    </div>
  );
}

// ---- Filter bar (tag chips) ----
const TAG_COLORS = { t1: 'var(--accent-apricot)', t2: 'var(--primary)', t3: 'var(--accent-green)' };

function FilterBar({ tags, selected, onToggle, onClear }) {
  return (
    <div className="filterbar">
      <button className={'chip' + (selected.length === 0 ? ' sel' : '')} onClick={onClear}>すべて</button>
      {tags.map(t => (
        <button key={t.id}
          className={'chip' + (selected.includes(t.id) ? ' sel' : '')}
          onClick={() => onToggle(t.id)}>
          <span className="tdot" style={{ background: TAG_COLORS[t.id] }}></span>{t.name}
        </button>
      ))}
    </div>
  );
}

// ---- Tag section header ----
function SectionHeader({ tagId, name, count, collapsed, onToggle, onDelete }) {
  return (
    <div className="sec-head" onClick={onToggle}>
      <span className="sec-dot" style={{ background: TAG_COLORS[tagId] || 'var(--text-secondary)' }}></span>
      <span className="sec-name">{name}</span>
      <span className="sec-count">{count}件</span>
      <span className="sec-spacer"></span>
      {onDelete && (
        <button className="sec-del" onClick={(e) => { e.stopPropagation(); onDelete(); }}>
          このセクションを削除
        </button>
      )}
      <span className="sec-caret">{collapsed ? '▼' : '▲'}</span>
    </div>
  );
}

// ---- Bulk action bar ----
function BulkBar({ count, tags, onChangeTag, onCancel }) {
  return (
    <div className="bulkbar">
      <span className="cnt">{count}件選択中</span>
      <select defaultValue="" onChange={(e) => onChangeTag(e.target.value || null)}>
        <option value="" disabled>タグを変更</option>
        <option value="__none__">タグなし</option>
        {tags.map(t => <option key={t.id} value={t.id}>{t.name}</option>)}
      </select>
      <button className="x" onClick={onCancel}>キャンセル</button>
    </div>
  );
}

// ---- Bottom bar: quick add + FAB ----
function BottomBar({ onQuickAdd, onOpenDetail, disabled }) {
  const [val, setVal] = useState('');
  const submit = () => {
    const t = val.trim();
    if (!t) return;
    onQuickAdd(t);
    setVal('');
  };
  return (
    <div className="bottombar">
      <div className="qa-field">
        <input className="qa-input" value={val} placeholder="商品を追加…"
          disabled={disabled}
          onChange={(e) => setVal(e.target.value)}
          onKeyDown={(e) => { if (e.key === 'Enter') submit(); }} />
        <button className="qa-add" onClick={submit} disabled={!val.trim()}>追加</button>
      </div>
      <button className="fab" onClick={onOpenDetail} aria-label="詳細追加">＋</button>
    </div>
  );
}

// ---- Drawer (sidebar) — plain ListTiles, matching the real app ----
function Drawer({ show, lang, onLang, onClose, onProfile, onSettings, onLogout }) {
  return (
    <div className={'drawer' + (show ? ' show' : '')}>
      <div className="drawer-eyebrow">言語 / LANGUAGE</div>
      <div className="lang-row">
        <button className={'lang-btn' + (lang === 'ja' ? ' active' : '')} onClick={() => onLang('ja')}>JA</button>
        <button className={'lang-btn' + (lang === 'en' ? ' active' : '')} onClick={() => onLang('en')}>EN</button>
      </div>
      <div className="drawer-sep"></div>
      <div className="drawer-item" onClick={onSettings}>グループ設定</div>
      <div className="drawer-item" onClick={onProfile}>プロフィール</div>
      <div className="drawer-item danger" onClick={onLogout}>ログアウト</div>
    </div>
  );
}

// ---- Group switcher modal ----
function GroupSwitcher({ show, groups, active, onSwitch, onCreate, onJoin }) {
  return (
    <div className={'modal-card' + (show ? ' show' : '')}>
      <div className="modal-title">グループを切り替え</div>
      <div className="modal-sep"></div>
      {groups.map(g => (
        <div className="grow-row" key={g}>
          <span className="gname">{g}</span>
          {g === active
            ? <span className="mini-badge">使用中</span>
            : <button className="mini-btn" onClick={() => onSwitch(g)}>切り替え</button>}
        </div>
      ))}
      <div className="modal-sep"></div>
      <div className="modal-link" onClick={onCreate}>＋ 新規グループを作成</div>
      <div className="modal-link" onClick={onJoin}>🔑 招待コードで参加</div>
    </div>
  );
}

// ---- Toast ----
function Toast({ toast }) {
  if (!toast) return null;
  const icon = toast.type === 'success' ? '✅' : toast.type === 'error' ? '⚠️' : '';
  return (
    <div className="toast-wrap">
      <div className={'toast show ' + (toast.type || '')}>
        {icon && <span>{icon}</span>}{toast.msg}
      </div>
    </div>
  );
}

Object.assign(window, {
  PhoneShell, AppBar, FilterBar, SectionHeader, BulkBar,
  BottomBar, Drawer, GroupSwitcher, Toast, TAG_COLORS, StatusIcons,
});
