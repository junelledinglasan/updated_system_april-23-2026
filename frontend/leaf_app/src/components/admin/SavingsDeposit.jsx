import { useState, useEffect } from "react";
import { useNavigate } from "react-router-dom";
import { PiggyBank, ArrowDownCircle, ArrowUpCircle, Search, ClipboardList, Check, AlertTriangle } from "lucide-react";
import { getMembersAPI, recordSavingsAPI, getMemberSavingsAPI } from "../../api/members";

// ── BAGO: dating overlay modal na naka-toggle lang sa loob ng
// AdminLayout.jsx (state-based) — ngayon sarili nang FILE/ROUTE ito
// (/admin/savings-deposit), dahil nasa sidebar na siya bilang tunay
// na nav item, tulad ng ibang pages. ──────────────────────────────────
export default function SavingsDeposit() {
  const navigate = useNavigate();
  const onClose = () => navigate(-1);

  const [mainTab,  setMainTab] = useState("new");
  const [step,     setStep]    = useState(1);
  const [members,  setMembers] = useState([]);
  // balances fetched on-demand when member is selected
  const [selected, setSelect]  = useState(null);
  const [type,     setType]    = useState("Deposit");
  const [amount,   setAmount]  = useState("");
  const [note,     setNote]    = useState("");
  const [error,    setError]   = useState("");
  const [done,     setDone]    = useState(false);
  const [loading,  setLoad]    = useState(false);
  const [fetching, setFetch]   = useState(true);
  const [search,   setSearch]  = useState("");
  const [balance,  setBalance] = useState(0);
  const [allSavings,  setAllSavings] = useState([]);
  const [histSearch,  setHistSearch] = useState("");
  const [histLoading, setHistLoading]= useState(false);
  // ── BAGO: dating flat na listahan lang ng LAHAT ng transactions
  // (magkakahalo ang lahat ng member) — ngayon naka-group per member,
  // makikita muna ang MEMBER, tapos i-expand para makita ang kanilang
  // mga record. ─────────────────────────────────────────────────────
  const [expandedMember, setExpandedMember] = useState(null);

  useEffect(() => {
    getMembersAPI()
      .then(data => setMembers(data))
      .catch(e => console.error(e))
      .finally(() => setFetch(false));
  }, []);

  useEffect(() => {
    if (mainTab !== "history") return;
    setHistLoading(true);
    import("../../api/axiosInstance").then(({ default: api }) =>
      api.get("/members/savings/?limit=100&ordering=-created_at")
    )
      .then(res => setAllSavings(Array.isArray(res.data) ? res.data : []))
      .catch(() => setAllSavings([]))
      .finally(() => setHistLoading(false));
  }, [mainTab]);

  useEffect(() => {
    if (!selected) return;
    // ── Fetch savings balance only for the selected member ──
    getMemberSavingsAPI(selected.id)
      .then(s => setBalance(s.balance || 0))
      .catch(() => setBalance(0));
  }, [selected]);

  const filtered = members.filter(m =>
    (m.fullname||"").toLowerCase().includes(search.toLowerCase()) ||
    (m.member_id||"").toLowerCase().includes(search.toLowerCase())
  );

  const filteredHist = allSavings.filter(tx =>
    (tx.member_name||"").toLowerCase().includes(histSearch.toLowerCase()) ||
    (tx.member_code||"").toLowerCase().includes(histSearch.toLowerCase())
  );

  // ── BAGO: i-group ang mga transaction per member — ito na ang
  // makikita bilang listahan (isang row bawat member), i-expand para
  // makita ang kanilang mga record. ────────────────────────────────
  const memberGroups = (() => {
    const groups = {};
    filteredHist.forEach(tx => {
      const key = tx.member_code || tx.member_name;
      if (!groups[key]) groups[key] = { member_name: tx.member_name, member_code: tx.member_code, txs: [] };
      groups[key].txs.push(tx);
    });
    return Object.values(groups).sort((a,b) => (b.txs[0]?.id||0) - (a.txs[0]?.id||0));
  })();

  const totalDeposit  = allSavings.filter(t => t.transaction_type === "Deposit").reduce((s,t) => s + parseFloat(t.amount||0), 0);
  const totalWithdraw = allSavings.filter(t => t.transaction_type === "Withdraw").reduce((s,t) => s + parseFloat(t.amount||0), 0);

  const parsed  = parseFloat(amount) || 0;
  const isValid = parsed > 0 && selected && (type === "Deposit" || parsed <= balance);
  const newBal  = type === "Deposit" ? balance + parsed : balance - parsed;

  const handleSave = async () => {
    if (!parsed || parsed <= 0) { setError("Enter a valid amount."); return; }
    if (type === "Withdraw" && parsed > balance) {
      setError(`Insufficient balance. Current: ₱${balance.toLocaleString()}`);
      return;
    }
    setLoad(true);
    try {
      await recordSavingsAPI({ member: selected.id, transaction_type: type, amount: parsed, note });
      setDone(true);
    } catch(e) {
      setError(e.response?.data?.error || "Failed to record transaction.");
    } finally { setLoad(false); }
  };

  // ── FIX: dating "position:fixed,inset:0" (sariling full-screen
  // overlay na tumatakip sa BUONG screen kasama ang sidebar) — mali
  // 'yon dahil totoong ROUTE na ito sa loob ng AdminLayout, dapat
  // lumabas lang ito bilang normal na content sa loob ng <Outlet/>
  // (tulad ng Dashboard, Manage Member, atbp.) — kasama pa rin ang
  // sidebar/topbar ng AdminLayout. ─────────────────────────────────────
  if (done) return (
    <div style={{maxWidth:500,margin:"40px auto",padding:"32px 24px",textAlign:"center",background:"#fff",borderRadius:14,border:"1px solid #e4f0e5"}}>
      <div style={{display:"flex",justifyContent:"center"}}>{type === "Deposit" ? <ArrowDownCircle size={40} color="#2e7d32"/> : <ArrowUpCircle size={40} color="#c62828"/>}</div>
      <div style={{fontSize:15,fontWeight:700,color:"#1b5e20",marginTop:8}}>{type} Recorded!</div>
      <div style={{fontSize:12,color:"#888",marginTop:8}}>
        ₱{parsed.toLocaleString()} {type.toLowerCase()} for <strong>{selected.fullname}</strong>.
        New balance: <strong>₱{newBal.toLocaleString()}</strong>
      </div>
      <button className="al-btn-save" style={{marginTop:20,width:"100%"}} onClick={onClose}>Done</button>
    </div>
  );

  return (
    <div style={{padding:"20px 24px 32px",width:"100%",boxSizing:"border-box"}}>
      {/* ── BAGO: dating maxWidth:1000 lang (ad-hoc) — ngayon eksaktong
          tugma sa padding convention ng ManageMember.css (.mm-wrapper),
          para consistent ang spacing sa buong system. ─────────────── */}
      {/* ── BAGO: dating walang visible na title/description sa loob
          ng page content mismo. ─────────────────────────────────── */}
      <div style={{marginBottom:18}}>
        <div style={{fontSize:24,fontWeight:800,color:"#1b5e20",lineHeight:1.2,letterSpacing:"-0.3px"}}>Savings Transaction</div>
        <div style={{fontSize:11,color:"#aaa",marginTop:3}}>Record deposits and withdrawals for member savings accounts.</div>
      </div>
      <div style={{textAlign:"center",fontSize:12,color:"#888",marginBottom:14}}>
        {mainTab === "new"
          ? `Step ${step} of 2 — ${step === 1 ? "Select Member" : "Transaction Details"}`
          : "All savings transactions, grouped per member"}
      </div>

      <div style={{display:"flex",background:"#fff",borderRadius:12,border:"1px solid #e4f0e5",marginBottom:16,overflow:"hidden"}}>
        {[
          {key:"new",     icon:<PiggyBank size={14}/>,      label:"New Transaction"},
          {key:"history", icon:<ClipboardList size={14}/>,  label:`History${allSavings.length > 0 ? " ("+allSavings.length+")" : ""}`},
        ].map(t => (
          <button key={t.key} onClick={() => { setMainTab(t.key); setDone(false); setStep(1); setExpandedMember(null); }} style={{
              flex:1, padding:"12px 8px", fontSize:12.5, fontWeight:700, cursor:"pointer",
              border:"none",
              color: mainTab===t.key ? "#fff" : "#888",
              background: mainTab===t.key ? "#f57f17" : "transparent",
              transition:"all 0.15s",
              display:"flex", alignItems:"center", justifyContent:"center", gap:6,
            }}>{t.icon} {t.label}</button>
          ))}
        </div>

        {mainTab === "new" && (<>
          {step === 1 && (
            <div style={{background:"#fff",borderRadius:14,border:"1px solid #e4f0e5",padding:20}}>
              <div>
                <div className="al-search-wrap" style={{marginBottom:16,padding:"10px 14px",gap:10}}>
                  <Search size={13} color="#aaa"/>
                  <input className="al-search-in" placeholder="Search by name or member ID..."
                    value={search} onChange={e => setSearch(e.target.value)} autoFocus />
                </div>
                <div className="al-loan-list">
                  {fetching
                    ? <div style={{textAlign:"center",padding:24,color:"#aaa",fontSize:13}}>Loading members...</div>
                    : filtered.length === 0
                    ? <div style={{textAlign:"center",padding:24,color:"#aaa",fontSize:13}}>No members found.</div>
                    : filtered.map(m => {
                      const isSelected = selected?.id === m.id;
                      return (
                        <div key={m.id} className={`al-loan-item ${isSelected ? "selected" : ""}`}
                          onClick={() => { setSelect(m); setError(""); }}>
                          <div className="al-loan-avatar" style={{
                            background: isSelected ? "#f57f17" : "#fff3e0",
                            color: isSelected ? "#fff" : "#f57f17",
                            border: `2px solid ${isSelected ? "#f57f17" : "#ffe0b2"}`,
                          }}>{(m.fullname||"M")[0]}</div>
                          <div className="al-loan-info">
                            <div className="al-loan-name">{m.fullname}</div>
                            <div className="al-loan-meta">{m.member_id}</div>
                          </div>
                          {isSelected && (
                            <div style={{textAlign:"right",flexShrink:0}}>
                              <div style={{fontSize:13,fontWeight:800,color:"#f57f17",display:"flex",alignItems:"center",gap:4}}><Check size={14}/> Selected</div>
                            </div>
                          )}
                        </div>
                      );
                    })
                  }
                </div>
              </div>
              <div style={{display:"flex",justifyContent:"flex-end",gap:10,marginTop:16}}>
                <button className="al-btn-cancel" onClick={onClose}>Cancel</button>
                <button className="al-btn-save" style={{background:"#f57f17",borderColor:"#f57f17"}}
                  onClick={() => setStep(2)} disabled={!selected}>Next →</button>
              </div>
            </div>
          )}
          {step === 2 && (
            <div style={{background:"#fff",borderRadius:14,border:"1px solid #e4f0e5",padding:20}}>
              <div>
                <div className="al-borrower-strip" style={{background:"#fff8e1",borderColor:"#ffe082"}}>
                  <div className="al-loan-avatar" style={{background:"#f57f17",color:"#fff",border:"2px solid #ffe082"}}>
                    {(selected.fullname||"M")[0]}
                  </div>
                  <div style={{flex:1}}>
                    <div className="al-loan-name">{selected.fullname}</div>
                    <div className="al-loan-meta">{selected.member_id}</div>
                  </div>
                  <div style={{background:"#fff3e0",border:"1px solid #ffe0b2",borderRadius:10,padding:"6px 14px",textAlign:"center"}}>
                    <div style={{fontSize:10,color:"#f57f17",fontWeight:600,textTransform:"uppercase"}}>Balance</div>
                    <div style={{fontSize:16,fontWeight:800,color:"#e65100"}}>₱{balance.toLocaleString()}</div>
                  </div>
                </div>
                <div className="al-field">
                  <label className="al-label">Transaction Type</label>
                  <div style={{display:"flex",gap:8}}>
                    {["Deposit","Withdraw"].map(t => (
                      <button key={t} onClick={() => { setType(t); setError(""); }} style={{
                        flex:1, padding:"12px",
                        border:`2px solid ${type===t?(t==="Deposit"?"#2e7d32":"#c62828"):"#e0e0e0"}`,
                        borderRadius:10, cursor:"pointer",
                        background: type===t?(t==="Deposit"?"#e8f5e9":"#fce4ec"):"#fafafa",
                        fontWeight:700, fontSize:13,
                        color: type===t?(t==="Deposit"?"#1b5e20":"#c62828"):"#aaa",
                        transition:"all 0.2s",
                      }}><span style={{display:"flex",alignItems:"center",justifyContent:"center",gap:6}}>{t === "Deposit" ? <ArrowDownCircle size={15}/> : <ArrowUpCircle size={15}/>} {t}</span></button>
                    ))}
                  </div>
                </div>
                <div className="al-field">
                  <label className="al-label">Amount (₱) <span className="al-req">*</span></label>
                  <div className="al-amount-wrap">
                    <span className="al-peso">₱</span>
                    <input className="al-amount-in" type="number" min="1"
                      value={amount} onChange={e => { setAmount(e.target.value); setError(""); }} autoFocus />
                  </div>
                </div>
                <div className="al-field">
                  <label className="al-label">Note (optional)</label>
                  <input className="al-input" type="text" value={note}
                    onChange={e => setNote(e.target.value)}
                    placeholder="e.g. Monthly deposit, emergency withdrawal..." maxLength={100} />
                </div>
                {error && <div className="al-error" style={{display:"flex",alignItems:"center",gap:6}}><AlertTriangle size={13}/> {error}</div>}
                {isValid && (
                  <div className="al-preview">
                    <div className="al-prev-row"><span>Current Balance</span><span>₱{balance.toLocaleString()}</span></div>
                    <div className="al-prev-row deduct">
                      <span>{type === "Deposit" ? "Deposit" : "Withdrawal"}</span>
                      <span style={{color:type==="Deposit"?"#2e7d32":"#c62828",fontWeight:700}}>
                        {type === "Deposit" ? "+" : "−"} ₱{parsed.toLocaleString()}
                      </span>
                    </div>
                    <div className="al-prev-divider"/>
                    <div className="al-prev-row result">
                      <span>New Balance</span>
                      <span style={{color:"#e65100",fontWeight:800}}>₱{newBal.toLocaleString()}</span>
                    </div>
                  </div>
                )}
              </div>
              <div style={{display:"flex",justifyContent:"flex-end",gap:10,marginTop:16}}>
                <button className="al-btn-cancel" onClick={() => setStep(1)}>← Back</button>
                <button className="al-btn-save"
                  style={{background:type==="Deposit"?"#2e7d32":"#c62828",borderColor:type==="Deposit"?"#2e7d32":"#c62828"}}
                  onClick={handleSave} disabled={!isValid || loading}>
                  {loading ? "Saving..." : <span style={{display:"flex",alignItems:"center",justifyContent:"center",gap:6}}>{type === "Deposit" ? <ArrowDownCircle size={14}/> : <ArrowUpCircle size={14}/>} Record {type === "Deposit" ? "Deposit" : "Withdrawal"}</span>}
                </button>
              </div>
            </div>
          )}
        </>)}

        {mainTab === "history" && (
          <div>
            <div style={{display:"grid",gridTemplateColumns:"repeat(3,1fr)",gap:8}}>
                <div style={{background:"#e8f5e9",borderRadius:8,padding:"10px 12px",textAlign:"center"}}>
                  <div style={{fontSize:10,color:"#558b2f",fontWeight:600}}>Total Deposits</div>
                  <div style={{fontSize:15,fontWeight:800,color:"#1b5e20"}}>₱{totalDeposit.toLocaleString()}</div>
                </div>
                <div style={{background:"#fce4ec",borderRadius:8,padding:"10px 12px",textAlign:"center"}}>
                  <div style={{fontSize:10,color:"#c62828",fontWeight:600}}>Total Withdrawals</div>
                  <div style={{fontSize:15,fontWeight:800,color:"#c62828"}}>₱{totalWithdraw.toLocaleString()}</div>
                </div>
                <div style={{background:"#fff8e1",borderRadius:8,padding:"10px 12px",textAlign:"center"}}>
                  <div style={{fontSize:10,color:"#f57f17",fontWeight:600}}>Transactions</div>
                  <div style={{fontSize:15,fontWeight:800,color:"#e65100"}}>{allSavings.length}</div>
                </div>
              </div>
              <div className="al-search-wrap" style={{marginBottom:16,padding:"10px 14px",gap:10}}>
                <Search size={13} color="#aaa"/>
                <input className="al-search-in" placeholder="Search by member name or ID..."
                  value={histSearch} onChange={e => setHistSearch(e.target.value)} />
              </div>
              {histLoading ? (
                <div style={{textAlign:"center",padding:24,color:"#aaa",fontSize:13}}>Loading history...</div>
              ) : memberGroups.length === 0 ? (
                <div style={{textAlign:"center",padding:24,color:"#bbb",fontSize:13}}>No savings transactions found.</div>
              ) : (
                // ── BAGO: dating flat na table lang ng LAHAT ng
                // transactions — ngayon naka-group per MEMBER, i-click
                // para makita ang kanilang mga record. ─────────────────
                memberGroups.map(g => {
                  const isOpen = expandedMember === g.member_code;
                  const memberTotal = g.txs.reduce((s,t) => s + (t.transaction_type==="Deposit"?1:-1)*parseFloat(t.amount||0), 0);
                  return (
                    <div key={g.member_code} style={{background:"#fff",borderRadius:12,border:`1.5px solid ${isOpen?"#ffcc80":"#f0e6c8"}`,marginBottom:10,overflow:"hidden"}}>
                      <div onClick={() => setExpandedMember(isOpen ? null : g.member_code)} style={{display:"flex",alignItems:"center",gap:12,padding:"14px 18px",cursor:"pointer",background:isOpen?"#fff8e1":"#fff"}}>
                        <div style={{width:36,height:36,borderRadius:"50%",background:"#fff3e0",color:"#f57f17",display:"flex",alignItems:"center",justifyContent:"center",fontWeight:700,flexShrink:0}}>{(g.member_name||"M")[0]}</div>
                        <div style={{flex:1,minWidth:0}}>
                          <div style={{fontWeight:700,fontSize:13,color:"#222"}}>{g.member_name}</div>
                          <div style={{fontSize:10.5,color:"#aaa",fontFamily:"monospace"}}>{g.member_code} · {g.txs.length} transaction{g.txs.length!==1?"s":""}</div>
                        </div>
                        <div style={{textAlign:"right",flexShrink:0}}>
                          <div style={{fontSize:14,fontWeight:800,color:memberTotal>=0?"#2e7d32":"#c62828"}}>{memberTotal>=0?"+":""}₱{memberTotal.toLocaleString()}</div>
                          <div style={{fontSize:9,color:"#bbb"}}>net</div>
                        </div>
                        <span style={{color:"#bbb",fontSize:13}}>{isOpen?"▲":"▼"}</span>
                      </div>
                      {isOpen && (
                        <div style={{borderTop:"1px solid #f5e9d0",overflowX:"auto"}}>
                          <table style={{width:"100%",borderCollapse:"collapse",fontSize:12}}>
                            <thead>
                              <tr style={{background:"#fff8e1"}}>
                                <th style={{padding:"8px 14px",textAlign:"left",fontWeight:600,color:"#777",fontSize:10}}>Date</th>
                                <th style={{padding:"8px 14px",textAlign:"left",fontWeight:600,color:"#777",fontSize:10}}>Type</th>
                                <th style={{padding:"8px 14px",textAlign:"right",fontWeight:600,color:"#777",fontSize:10}}>Amount</th>
                                <th style={{padding:"8px 14px",textAlign:"right",fontWeight:600,color:"#777",fontSize:10}}>Balance After</th>
                                <th style={{padding:"8px 14px",textAlign:"left",fontWeight:600,color:"#777",fontSize:10}}>Note</th>
                              </tr>
                            </thead>
                            <tbody>
                              {g.txs.map((tx, idx) => (
                                <tr key={tx.id} style={{background:idx%2===0?"#fff":"#fffde7",borderTop:"1px solid #f5f5f5"}}>
                                  <td style={{padding:"7px 14px",color:"#888",fontSize:10,whiteSpace:"nowrap"}}>{tx.created_at?.split("T")[0]}</td>
                                  <td style={{padding:"7px 14px"}}>
                                    <span style={{
                                      background:tx.transaction_type==="Deposit"?"#e8f5e9":"#fce4ec",
                                      color:tx.transaction_type==="Deposit"?"#2e7d32":"#c62828",
                                      padding:"2px 7px",borderRadius:20,fontSize:10,fontWeight:700,display:"inline-flex",alignItems:"center",gap:3,
                                    }}>
                                      {tx.transaction_type==="Deposit"?<ArrowDownCircle size={11}/>:<ArrowUpCircle size={11}/>} {tx.transaction_type}
                                    </span>
                                  </td>
                                  <td style={{padding:"7px 14px",textAlign:"right",fontWeight:700,color:tx.transaction_type==="Deposit"?"#2e7d32":"#c62828"}}>
                                    {tx.transaction_type==="Deposit"?"+":"−"}₱{Number(tx.amount).toLocaleString()}
                                  </td>
                                  <td style={{padding:"7px 14px",textAlign:"right",fontWeight:600,color:"#333"}}>₱{Number(tx.balance_after).toLocaleString()}</td>
                                  <td style={{padding:"7px 14px",color:"#888",fontSize:10}}>{tx.note||"—"}</td>
                                </tr>
                              ))}
                            </tbody>
                          </table>
                        </div>
                      )}
                    </div>
                  );
                })
              )}
            </div>
        )}
    </div>
  );
}