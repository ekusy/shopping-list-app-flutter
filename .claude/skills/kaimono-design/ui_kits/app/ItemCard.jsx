// ItemCard — refreshed card with swipe-to-reveal actions and long-press
// multi-select. Resting state is intentionally clean: only the check, name,
// buyer state and a single primary "買うよ" affordance show. Edit/delete live
// behind a swipe; long-press enters bulk-selection mode.
const { useState: useStateIC, useRef: useRefIC } = React;

function ItemCard({
  item, members, currentUid,
  selectionMode, isSelected,
  onToggleVolunteer, onTogglePurchased, onEdit, onDelete,
  onSelectToggle, onEnterSelection,
}) {
  const [dragX, setDragX] = useStateIC(0);
  const [dragging, setDragging] = useStateIC(false);
  const st = useRefIC({ x: 0, y: 0, base: 0, mode: 'idle', opened: false, lp: null });

  const declaredBy = item.buyingBy;
  const isMine = declaredBy && declaredBy === currentUid;
  const isOthers = declaredBy && !isMine;
  const declarerName = declaredBy ? (members[declaredBy] || declaredBy) : '';
  const bought = item.purchased;
  const OPEN = -132;

  const clearLP = () => { if (st.current.lp) { clearTimeout(st.current.lp); st.current.lp = null; } };

  const down = (e) => {
    if (selectionMode) return;
    const p = st.current;
    p.x = e.clientX; p.y = e.clientY; p.base = dragX; p.mode = 'idle';
    p.lp = setTimeout(() => {
      if (p.mode === 'idle') { p.mode = 'lp'; onEnterSelection(item.id); }
    }, 470);
  };
  const move = (e) => {
    if (selectionMode) return;
    const p = st.current;
    const dx = e.clientX - p.x, dy = e.clientY - p.y;
    if (p.mode === 'idle' && (Math.abs(dx) > 8 || Math.abs(dy) > 8)) {
      clearLP();
      if (Math.abs(dx) > Math.abs(dy)) {
        p.mode = 'swipe';
        try { e.currentTarget.setPointerCapture(e.pointerId); } catch (_) {}
        setDragging(true);
      } else { p.mode = 'scroll'; }
    }
    if (p.mode === 'swipe') {
      const nx = Math.max(OPEN, Math.min(0, p.base + dx));
      setDragX(nx);
    }
  };
  const up = () => {
    if (selectionMode) return;
    const p = st.current;
    clearLP();
    if (p.mode === 'swipe') {
      const open = dragX < OPEN / 2.3;
      p.opened = open;
      setDragX(open ? OPEN : 0);
      setDragging(false);
    } else if (p.mode === 'idle' && p.opened) {
      p.opened = false; setDragX(0);
    }
    p.mode = 'idle';
  };

  const close = () => { st.current.opened = false; setDragX(0); };

  const cardClass = 'card'
    + (dragging ? ' dragging' : '')
    + (bought ? ' bought' : (declaredBy ? ' vol' : ''))
    + (selectionMode && isSelected ? ' selected' : '');

  return (
    <div className="card-wrap">
      {/* revealed actions behind */}
      {!selectionMode && (
        <div className="swipe-actions">
          {bought
            ? <button className="swipe-btn edit" onClick={() => { close(); onTogglePurchased(); }}>
                <span className="sa-ico">↩</span>戻す</button>
            : <button className="swipe-btn edit" onClick={() => { close(); onEdit(); }}>
                <span className="sa-ico">✏️</span>編集</button>}
          <button className="swipe-btn del" onClick={() => { close(); onDelete(); }}>
            <span className="sa-ico">🗑️</span>削除</button>
        </div>
      )}

      <div className={cardClass}
        style={{ transform: `translateX(${dragX}px)` }}
        onPointerDown={down} onPointerMove={move} onPointerUp={up} onPointerCancel={up}
        onClick={() => { if (selectionMode) onSelectToggle(item.id); }}>
        <div className="card-row">
          {selectionMode ? (
            <span className={'check sel' + (isSelected ? ' picked' : '')}>
              {isSelected && <span className="ck">✓</span>}
            </span>
          ) : (
            <span className={'check' + (bought ? ' on' : '')}
              onClick={(e) => { e.stopPropagation(); onTogglePurchased(); }}>
              {bought && <span className="ck">✓</span>}
            </span>
          )}

          <span className="item-name">{item.name}</span>

          {/* buyer state / volunteer affordance */}
          {!selectionMode && !bought && (
            isMine ? (
              <span className="badge mine" onClick={(e) => { e.stopPropagation(); onToggleVolunteer(null); }}>
                🙋 私が買います <span className="badge-x">✕</span>
              </span>
            ) : isOthers ? (
              <React.Fragment>
                <span className="badge others">👤 {declarerName}</span>
                <button className="buy-pill" onClick={(e) => { e.stopPropagation(); onToggleVolunteer(currentUid); }}>代わりに</button>
              </React.Fragment>
            ) : (
              <button className="buy-pill" onClick={(e) => { e.stopPropagation(); onToggleVolunteer(currentUid); }}>
                🙋 買うよ
              </button>
            )
          )}
        </div>

        {item.note ? <div className="card-note">{item.note}</div> : null}
      </div>
    </div>
  );
}

window.ItemCard = ItemCard;
