// Sample data for the Kaimono UI kit prototype. Mirrors the app's domain
// model (items / tags / groups / members) with realistic Japanese copy.
window.KAIMONO_DATA = {
  user: { uid: 'u1', name: 'あなた' },
  members: { u1: 'あなた', u2: 'はると', u3: 'みお' },
  group: 'わが家のリスト',
  groups: ['わが家のリスト', 'シェアハウス', '部活の合宿'],
  tags: [
    { id: 't1', name: '急ぎ' },
    { id: 't2', name: 'まとめ買い' },
    { id: 't3', name: '日用品' },
  ],
  items: [
    { id: 'i1', name: '牛乳 1本',            tagId: 't1', note: '',            buyingBy: null, purchased: false },
    { id: 'i2', name: '卵 1パック',          tagId: 't1', note: '特売の日に', buyingBy: 'u1', purchased: false },
    { id: 'i3', name: 'トイレットペーパー',  tagId: 't3', note: '',            buyingBy: 'u2', purchased: false },
    { id: 'i4', name: '食器用洗剤',          tagId: 't3', note: '',            buyingBy: null, purchased: false },
    { id: 'i5', name: 'お米 5kg',            tagId: 't2', note: '',            buyingBy: null, purchased: false },
    { id: 'i6', name: 'バナナ 1房',          tagId: null, note: '',            buyingBy: null, purchased: false },
    { id: 'i7', name: '食パン',              tagId: 't1', note: '',            buyingBy: null, purchased: true  },
    { id: 'i8', name: 'ヨーグルト',          tagId: 't2', note: '',            buyingBy: null, purchased: true  },
  ],
};
