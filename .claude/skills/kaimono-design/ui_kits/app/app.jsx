// App root — state + flow wiring for the Kaimono mobile UI kit.
const { useState: useApp, useRef: useAppRef } = React;
const D = window.KAIMONO_DATA;

function App() {
  const [screen, setScreen] = useApp('login');
  const [items, setItems] = useApp(D.items);
  const [filter, setFilter] = useApp([]);
  const [selectionMode, setSelMode] = useApp(false);
  const [selected, setSelected] = useApp([]);
  const [collapsed, setCollapsed] = useApp([]);
  const [purchasedOpen, setPurchasedOpen] = useApp(true);
  const [overlay, setOverlay] = useApp(null);      // 'add'|'edit'|'drawer'|'switcher'
  const [editing, setEditing] = useApp(null);
  const [group, setGroup] = useApp(D.group);
  const [lang, setLang] = useApp('ja');
  const [toast, setToast] = useApp(null);
  const tId = useAppRef(null);
  const uid = D.user.uid;

  const showToast = (msg, type) => {
    setToast({ msg, type });
    if (tId.current) clearTimeout(tId.current);
    tId.current = setTimeout(() => setToast(null), 1900);
  };

  let _seq = items.length;
  const nextId = () => 'i' + (++_seq) + '_' + Date.now();

  // ---- item handlers ----
  const quickAdd = (name) => {
    setItems(prev => [...prev, { id: nextId(), name, tagId: null, note: '', buyingBy: null, purchased: false }]);
    showToast('追加しました！', 'success');
  };
  const addDetail = ({ name, tagId, note }) => {
    setItems(prev => [...prev, { id: nextId(), name, tagId, note, buyingBy: null, purchased: false }]);
    setOverlay(null);
    showToast('追加しました！', 'success');
  };
  const saveEdit = ({ name, tagId, note }) => {
    setItems(prev => prev.map(i => i.id === editing.id ? { ...i, name, tagId, note } : i));
    setOverlay(null); setEditing(null);
    showToast('保存しました！', 'success');
  };
  const toggleVolunteer = (id, who) => {
    setItems(prev => prev.map(i => i.id === id ? { ...i, buyingBy: who } : i));
    if (who) showToast('担当しました！', 'success');
  };
  const togglePurchased = (id) => {
    let nowBought = false;
    setItems(prev => prev.map(i => {
      if (i.id !== id) return i;
      nowBought = !i.purchased;
      return { ...i, purchased: !i.purchased, buyingBy: !i.purchased ? null : i.buyingBy };
    }));
    if (nowBought) showToast('購入済みにしました！', 'success');
  };
  const del = (id) => {
    setItems(prev => prev.filter(i => i.id !== id));
    showToast('削除しました');
  };
  const edit = (id) => {
    const it = items.find(i => i.id === id);
    setEditing(it); setOverlay('edit');
  };
  const clearPurchased = () => {
    setItems(prev => prev.filter(i => !i.purchased));
    showToast('削除しました');
  };
  const deleteSection = (tagId) => {
    setItems(prev => prev.filter(i => i.purchased || (tagId == null ? (i.tagId != null) : i.tagId !== tagId)));
    showToast('削除しました');
  };

  // ---- selection ----
  const enterSelection = (id) => { setSelMode(true); setSelected([id]); };
  const selectToggle = (id) => {
    setSelected(prev => {
      const next = prev.includes(id) ? prev.filter(x => x !== id) : [...prev, id];
      if (next.length === 0) setSelMode(false);
      return next;
    });
  };
  const cancelSelection = () => { setSelMode(false); setSelected([]); };
  const bulkTag = (tagId) => {
    const real = tagId === '__none__' ? null : tagId;
    setItems(prev => prev.map(i => selected.includes(i.id) ? { ...i, tagId: real } : i));
    cancelSelection();
    showToast('タグを変更しました', 'success');
  };

  // ---- filter / sections ----
  const toggleFilter = (id) => setFilter(p => p.includes(id) ? p.filter(x => x !== id) : [...p, id]);
  const toggleCollapse = (tagId) => {
    const key = tagId == null ? '__no_tag__' : tagId;
    setCollapsed(p => p.includes(key) ? p.filter(x => x !== key) : [...p, key]);
  };

  const closeOverlay = () => { setOverlay(null); setEditing(null); };

  const handlers = {
    toggleVolunteer, togglePurchased, edit, del, clearPurchased,
    selectToggle, enterSelection,
  };

  if (screen === 'login') {
    return <PhoneShell><LoginScreen onLogin={() => setScreen('dashboard')} /></PhoneShell>;
  }

  return (
    <PhoneShell>
      <AppBar groupName={group}
        onSwitch={() => setOverlay('switcher')}
        onTags={() => showToast('タグ管理を開く（プロトタイプ）')}
        onMenu={() => setOverlay('drawer')} />

      <FilterBar tags={D.tags} selected={filter} onToggle={toggleFilter} onClear={() => setFilter([])} />

      <div style={{ position: 'relative', flex: 1, minHeight: 0, display: 'flex', flexDirection: 'column' }}>
        {selectionMode && (
          <BulkBar count={selected.length} tags={D.tags} onChangeTag={bulkTag} onCancel={cancelSelection} />
        )}
        <ShoppingList
          items={items} tags={D.tags} filter={filter} currentUid={uid} members={D.members}
          selectionMode={selectionMode} selected={selected}
          collapsed={collapsed} purchasedOpen={purchasedOpen}
          onToggleCollapse={toggleCollapse}
          onTogglePurchasedSection={() => setPurchasedOpen(o => !o)}
          onDeleteSection={deleteSection}
          handlers={handlers} />
      </div>

      {!selectionMode && (
        <BottomBar onQuickAdd={quickAdd} onOpenDetail={() => { setEditing(null); setOverlay('add'); }} />
      )}

      {/* overlays */}
      <div className={'scrim' + (overlay ? ' show' : '')} onClick={closeOverlay}></div>
      <AddSheet show={overlay === 'add' || overlay === 'edit'} tags={D.tags}
        editing={overlay === 'edit' ? editing : null}
        onClose={closeOverlay}
        onSubmit={overlay === 'edit' ? saveEdit : addDetail} />
      <Drawer show={overlay === 'drawer'} lang={lang} onLang={setLang} onClose={closeOverlay}
        onSettings={() => { closeOverlay(); showToast('グループ設定（プロトタイプ）'); }}
        onProfile={() => { closeOverlay(); showToast('プロフィール（プロトタイプ）'); }}
        onLogout={() => setScreen('login')} />
      <GroupSwitcher show={overlay === 'switcher'} groups={D.groups} active={group}
        onSwitch={(g) => { setGroup(g); closeOverlay(); showToast(`「${g}」に切り替えました`, 'success'); }}
        onCreate={() => { closeOverlay(); showToast('グループを作成（プロトタイプ）'); }}
        onJoin={() => { closeOverlay(); showToast('招待コードで参加（プロトタイプ）'); }} />

      <Toast toast={toast} />
    </PhoneShell>
  );
}

ReactDOM.createRoot(document.getElementById('root')).render(<App />);
