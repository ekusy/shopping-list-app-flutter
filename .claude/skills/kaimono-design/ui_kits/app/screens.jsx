// Screens & larger composites: LoginScreen, ShoppingList (grouped), AddSheet.
const { useState: useStateS } = React;

// ---- Login ----
function LoginScreen({ onLogin }) {
  const [signup, setSignup] = useStateS(false);
  const [show, setShow] = useStateS(false);
  return (
    <div className="login-screen">
      <div className="login-card">
        <div className="login-brand">🧺</div>
        <div className="login-title">{signup ? 'サインアップ' : 'ログイン'}</div>
        <div className="login-sub">家族みんなの買い物リスト</div>

        <div className="field">
          <div className="label">メールアドレス</div>
          <input className="input" defaultValue="you@example.com" />
        </div>
        {signup && (
          <div className="field">
            <div className="label">ユーザー名（任意）</div>
            <input className="input" placeholder="表示名" />
          </div>
        )}
        <div className="field">
          <div className="label">パスワード</div>
          <div className="pw-field">
            <input className="input" type={show ? 'text' : 'password'} defaultValue="password" />
            <button className="pw-toggle" onClick={() => setShow(s => !s)}>{show ? '非表示' : '表示'}</button>
          </div>
        </div>

        <button className="primary-btn" onClick={onLogin}>{signup ? 'サインアップ' : 'ログイン'}</button>
        <div className="login-link">
          {signup ? 'すでにアカウントをお持ちですか？' : 'アカウントをお持ちでないですか？'}{' '}
          <b onClick={() => setSignup(s => !s)}>{signup ? 'ログイン' : 'サインアップ'}</b>
        </div>
      </div>
    </div>
  );
}

// ---- Grouped shopping list ----
function ShoppingList({
  items, tags, filter, currentUid, members,
  selectionMode, selected, collapsed, purchasedOpen,
  onToggleCollapse, onTogglePurchasedSection, onDeleteSection,
  handlers,
}) {
  const matches = (i) => filter.length === 0 ? true : filter.includes(i.tagId || '');
  const active = items.filter(i => !i.purchased && matches(i));
  const bought = items.filter(i => i.purchased);

  const tagIdSet = new Set(tags.map(t => t.id));
  const sections = [];
  tags.forEach(t => {
    const its = active.filter(i => i.tagId === t.id);
    if (its.length) sections.push({ tagId: t.id, name: t.name, items: its });
  });
  const noTag = active.filter(i => !i.tagId || !tagIdSet.has(i.tagId));
  if (noTag.length) sections.push({ tagId: null, name: 'タグなし', items: noTag });

  const card = (i) => (
    <ItemCard key={i.id} item={i} members={members} currentUid={currentUid}
      selectionMode={selectionMode} isSelected={selected.includes(i.id)}
      onToggleVolunteer={(uid) => handlers.toggleVolunteer(i.id, uid)}
      onTogglePurchased={() => handlers.togglePurchased(i.id)}
      onEdit={() => handlers.edit(i.id)}
      onDelete={() => handlers.del(i.id)}
      onSelectToggle={handlers.selectToggle}
      onEnterSelection={handlers.enterSelection} />
  );

  if (active.length === 0 && bought.length === 0) {
    return <div className="list"><div className="empty">リストは空です</div></div>;
  }

  return (
    <div className="list">
      {sections.map(s => {
        const isC = collapsed.includes(s.tagId == null ? '__no_tag__' : s.tagId);
        return (
          <div className="section" key={s.tagId || 'none'}>
            <SectionHeader tagId={s.tagId} name={s.name} count={s.items.length}
              collapsed={isC} onToggle={() => onToggleCollapse(s.tagId)}
              onDelete={() => onDeleteSection(s.tagId, s.name)} />
            {!isC && <div className="sec-body">{s.items.map(card)}</div>}
          </div>
        );
      })}

      {bought.length > 0 && (
        <div className="section sec-purchased">
          <div className="sec-head" onClick={onTogglePurchasedSection}>
            <span className="sec-dot" style={{ background: 'var(--accent-green)' }}></span>
            <span className="sec-name">購入済み ({bought.length}件)</span>
            <span className="sec-spacer"></span>
            <button className="sec-del" onClick={(e) => { e.stopPropagation(); handlers.clearPurchased(); }}>購入済みを全削除</button>
            <span className="sec-caret">{purchasedOpen ? '▲' : '▼'}</span>
          </div>
          {purchasedOpen && <div className="sec-body">{bought.map(card)}</div>}
        </div>
      )}
    </div>
  );
}

// ---- Add / edit bottom sheet ----
function AddSheet({ show, tags, editing, onClose, onSubmit }) {
  const [name, setName] = useStateS('');
  const [tagId, setTagId] = useStateS('');
  const [note, setNote] = useStateS('');
  const lastEdit = React.useRef(null);

  // sync fields when an edit target arrives
  if (editing && lastEdit.current !== editing.id) {
    lastEdit.current = editing.id;
    setName(editing.name); setTagId(editing.tagId || ''); setNote(editing.note || '');
  }
  if (!editing && lastEdit.current !== null && !show) {
    lastEdit.current = null;
  }

  const submit = () => {
    if (!name.trim()) return;
    onSubmit({ name: name.trim(), tagId: tagId || null, note });
    setName(''); setTagId(''); setNote(''); lastEdit.current = null;
  };

  return (
    <div className={'sheet' + (show ? ' show' : '')}>
      <div className="sheet-handle"></div>
      <div className="sheet-head">
        <span className="sheet-title">{editing ? 'アイテムを編集' : '詳細追加'}</span>
        <button className="iconbtn" onClick={onClose}>✕</button>
      </div>
      <div className="field">
        <div className="label">アイテム名</div>
        <input className="input" value={name} placeholder="買うもの"
          onChange={(e) => setName(e.target.value)} />
      </div>
      <div className="field">
        <div className="label">タグ</div>
        <div className="row2">
          <select className="select" value={tagId} onChange={(e) => setTagId(e.target.value)}>
            <option value="">タグなし</option>
            {tags.map(t => <option key={t.id} value={t.id}>{t.name}</option>)}
          </select>
          <button className="photo-btn">📷 写真</button>
        </div>
      </div>
      <div className="field">
        <div className="label">メモ (オプション)</div>
        <textarea className="textarea" value={note} placeholder="メモ"
          onChange={(e) => setNote(e.target.value)}></textarea>
      </div>
      <button className="primary-btn" onClick={submit}>{editing ? '保存する' : '追加'}</button>
    </div>
  );
}

Object.assign(window, { LoginScreen, ShoppingList, AddSheet });
