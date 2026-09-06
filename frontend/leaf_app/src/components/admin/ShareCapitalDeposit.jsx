import { useState, useEffect } from "react";
import { useNavigate } from "react-router-dom";
import { Wallet, Search, ClipboardList, AlertTriangle, TrendingUp, Sprout } from "lucide-react";
import { getMembersAPI } from "../../api/members";

// ── BAGO: dating overlay modal na naka-toggle lang sa loob ng
// AdminLayout.jsx (state-based) — ngayon sarili nang FILE/ROUTE ito
// (/admin/share-capital-deposit), dahil nasa sidebar na siya bilang
// tunay na nav item, tulad ng ibang pages. ────────────────────────────
export default function ShareCapitalDeposit() {
  const navigate = useNavigate();
  const onClose = () => navigate(-1);

  const [mainTab,     setMainTab]  = useState("new");
  const [step,        setStep]     = useState(1);
  const [members,     setMembers]  = useState([]);
  const [selected,    setSelect]   = useState(null);
  const [amount,      setAmount]   = useState("");
  const [note,        setNote]     = useState("");
  const [error,       setError]    = useState("");
  const [done,        setDone]     = useState(false);
  const [loading,     setLoad]     = useState(false);
  const [fetching,    setFetch]    = useState(true);
  const [search,      setSearch]   = useState("");
  const [allHistory,  setAllHistory]  = useState([]);
  const [histLoading, setHistLoading] = useState(false);
  const [histSearch,  setHistSearch]  = useState("");
  // ── BAGO: dating flat na listahan lang ng LAHAT ng transactions —
  // ngayon naka-group per member, makikita muna ang MEMBER, tapos
  // i-expand para makita ang kanilang mga record. ────────────────────
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
      api.get("/members/share-capital-history/")
    )
      .then(res => setAllHistory(Array.isArray(res.data) ? res.data : []))
      .catch(() => setAllHistory([]))
      .finally(() => setHistLoading(false));
  }, [mainTab]);

  const filtered = members.filter(m =>
    (m.fullname||"").toLowerCase().includes(search.toLowerCase()) ||
    (m.member_id||"").toLowerCase().includes(search.toLowerCase())
  );

  const filteredHist = allHistory.filter(t =>
    (t.member_name||"").toLowerCase().includes(histSearch.toLowerCase()) ||
    (t.member_id||"").toLowerCase().includes(histSearch.toLowerCase())
  );

  // ── BAGO: i-group ang mga transaction per member. ────────────────
  const memberGroups = (() => {
    const groups = {};
    filteredHist.forEach(t => {
      const key = t.member_id || t.member_name;
      if (!groups[key]) groups[key] = { member_name: t.member_name, member_id: t.member_id, txs: [] };
      groups[key].txs.push(t);
    });
    return Object.values(groups).sort((a,b) => (b.txs[0]?.id||0) - (a.txs[0]?.id||0));
  })();

  const totalDeposits = allHistory.reduce((s,t) => s + t.amount, 0);

  const parsed   = parseFloat(amount) || 0;
  const isValid  = parsed > 0 && selected;
  const newSC    = parseFloat(selected?.share_capital || 0) + parsed;
  // ── FIX: dating naka-hardcode na "newSC * 2" — hindi ginagamit ang
  // totoong Loan Multiplier (1x/2x/3x) ng partikular na member. ───────
  const newMaxLoan = newSC * (selected?.loan_multiplier || 1);

  const handleSave = async () => {
    if (!parsed || parsed <= 0) { setError("Enter a valid amount."); return; }
    setLoad(true);
    try {
      await import("../../api/axiosInstance").then(({ default: api }) =>
        api.post(`/members/${selected.id}/share-capital-deposit/`, {
          amount: parsed,
          note: note || "Share capital deposit",
          txn_type: "Deposit",
        })
      );
      setDone(true);
    } catch(e) {
      setError(e.response?.data?.error || "Failed to record deposit.");
    } finally { setLoad(false); }
  };

  // ── FIX: dating "position:fixed,inset:0" — mali dahil totoong
  // ROUTE na ito sa loob ng AdminLayout, dapat normal content lang
  // sa loob ng <Outlet/>. ───────────────────────────────────────────
  if (done) return (
    <div style={{maxWidth:500,margin:"40px auto",padding:"32px 24px",textAlign:"center",background:"#fff",borderRadius:14,border:"1px solid #e4f0e5"}}>
      <div style={{display:"flex",justifyContent:"center"}}><Wallet size={40} color="#1565c0"/></div>
      <div style={{fontSize:15,fontWeight:700,color:"#1565c0",marginTop:8}}>Share Capital Deposit Recorded!</div>
      <div style={{fontSize:12,color:"#888",marginTop:8}}>
        ₱{parsed.toLocaleString()} deposited for <strong>{selected.fullname}</strong>.<br/>
        New Share Capital: <strong style={{color:"#1565c0"}}>₱{newSC.toLocaleString()}</strong><br/>
        New Max Loanable: <strong style={{color:"#2e7d32"}}>₱{newMaxLoan.toLocaleString()}</strong>
      </div>
      <button className="al-btn-save" style={{background:"#1565c0",borderColor:"#1565c0",marginTop:20,width:"100%"}} onClick={onClose}>Done</button>
    </div>
  );

  return (
    <div style={{padding:"20px 24px 32px",width:"100%",boxSizing:"border-box"}}>
      {/* ── BAGO: eksaktong tugma sa padding convention ng
          ManageMember.css (.mm-wrapper). ────────────────────────── */}
      {/* ── BAGO: dating walang visible na title/description sa loob
          ng page content mismo. ─────────────────────────────────── */}
      <div style={{marginBottom:18}}>
        <div style={{fontSize:24,fontWeight:800,color:"#1b5e20",lineHeight:1.2,letterSpacing:"-0.3px"}}>Share Capital</div>
        <div style={{fontSize:11,color:"#aaa",marginTop:3}}>Record share capital deposits for members.</div>
      </div>
      <div style={{textAlign:"center",fontSize:12,color:"#888",marginBottom:14}}>
        {mainTab==="new"
          ? `Step ${step} of 2 — ${step===1?"Select Member":"Deposit Details"}`
          : "Share capital transaction history, grouped per member"}
      </div>

      <div style={{display:"flex",background:"#fff",borderRadius:12,border:"1px solid #e4f0e5",marginBottom:16,overflow:"hidden"}}>
          {[
            {key:"new",     icon:<Wallet size={14}/>,       label:"New Deposit"},
            {key:"history", icon:<ClipboardList size={14}/>, label:`History${allHistory.length > 0 ? " ("+allHistory.length+")" : ""}`},
          ].map(t => (
            <button key={t.key} onClick={() => { setMainTab(t.key); setDone(false); setStep(1); setExpandedMember(null); }} style={{
              flex:1, padding:"12px 8px", fontSize:12.5, fontWeight:700, cursor:"pointer",
              border:"none",
              color: mainTab===t.key ? "#fff" : "#888",
              background: mainTab===t.key ? "#1565c0" : "transparent",
              transition:"all 0.15s",
              display:"flex", alignItems:"center", justifyContent:"center", gap:6,
            }}>{t.icon} {t.label}</button>
          ))}
        </div>

        {mainTab === "new" && step === 1 && (
          <div style={{background:"#fff",borderRadius:14,border:"1px solid #e4f0e5",padding:20}}>
            <div className="al-step-info">Select the member to record share capital deposit.</div>
            <div className="al-search-wrap" style={{marginBottom:16,padding:"10px 14px",gap:10}}>
              <Search size={13} color="#aaa"/>
              <input className="al-search-in" placeholder="Search by name or member ID..."
                value={search} onChange={e => setSearch(e.target.value)} autoFocus/>
            </div>
            <div className="al-loan-list">
              {fetching
                ? <div style={{textAlign:"center",padding:24,color:"#aaa"}}>Loading members...</div>
                : filtered.length===0
                ? <div style={{textAlign:"center",padding:24,color:"#aaa"}}>No members found.</div>
                : filtered.map(m => {
                  const sc = parseFloat(m.share_capital||0);
                  const isSelected = selected?.id === m.id;
                  return (
                    <div key={m.id} className={`al-loan-item ${isSelected?"selected":""}`}
                      onClick={() => { setSelect(m); setError(""); }}>
                      <div className="al-loan-avatar" style={{
                        background: isSelected?"#1565c0":"#e3f2fd",
                        color: isSelected?"#fff":"#1565c0",
                        border:`2px solid ${isSelected?"#1565c0":"#bbdefb"}`,
                      }}>{(m.fullname||"M")[0]}</div>
                      <div className="al-loan-info">
                        <div className="al-loan-name">{m.fullname}</div>
                        <div className="al-loan-meta">{m.member_id}</div>
                      </div>
                      <div style={{textAlign:"right",flexShrink:0}}>
                        <div style={{fontSize:13,fontWeight:800,color:"#1565c0"}}>₱{sc.toLocaleString()}</div>
                        <div style={{fontSize:9,color:"#aaa",textTransform:"uppercase"}}>share capital</div>
                      </div>
                    </div>
                  );
                })
              }
            </div>
            <div style={{display:"flex",justifyContent:"flex-end",gap:10,marginTop:16}}>
              <button className="al-btn-cancel" onClick={onClose}>Cancel</button>
              <button className="al-btn-save" style={{background:"#1565c0",borderColor:"#1565c0"}}
                onClick={() => setStep(2)} disabled={!selected}>Next →</button>
            </div>
          </div>
        )}

        {mainTab === "new" && step === 2 && (
          <div style={{background:"#fff",borderRadius:14,border:"1px solid #e4f0e5",padding:20}}>
            <div className="al-borrower-strip" style={{background:"#e3f2fd",borderColor:"#90caf9"}}>
              <div className="al-loan-avatar" style={{background:"#1565c0",color:"#fff",border:"2px solid #90caf9"}}>
                {(selected.fullname||"M")[0]}
              </div>
              <div style={{flex:1}}>
                <div className="al-loan-name">{selected.fullname}</div>
                <div className="al-loan-meta">{selected.member_id}</div>
              </div>
              <div style={{background:"#e3f2fd",border:"1px solid #90caf9",borderRadius:10,padding:"6px 14px",textAlign:"center"}}>
                <div style={{fontSize:10,color:"#1565c0",fontWeight:600,textTransform:"uppercase"}}>Current SC</div>
                <div style={{fontSize:16,fontWeight:800,color:"#0d47a1"}}>₱{Number(selected.share_capital||0).toLocaleString()}</div>
              </div>
            </div>

            <div className="al-field">
              <label className="al-label">Deposit Amount (₱) <span className="al-req">*</span></label>
              <div className="al-amount-wrap">
                <span className="al-peso">₱</span>
                <input className="al-amount-in" type="number" min="1"
                  value={amount} onChange={e => { setAmount(e.target.value); setError(""); }} autoFocus/>
              </div>
            </div>
            <div className="al-field">
              <label className="al-label">Note (optional)</label>
              <input className="al-input" type="text" value={note}
                onChange={e => setNote(e.target.value)}
                placeholder="e.g. Additional share capital, membership fee..." maxLength={100}/>
            </div>
            {error && <div className="al-error" style={{display:"flex",alignItems:"center",gap:6}}><AlertTriangle size={13}/> {error}</div>}
            {isValid && (
              <div className="al-preview">
                <div className="al-prev-row"><span>Current Share Capital</span><span>₱{Number(selected.share_capital||0).toLocaleString()}</span></div>
                <div className="al-prev-row deduct">
                  <span>Deposit</span>
                  <span style={{color:"#1565c0",fontWeight:700}}>+ ₱{parsed.toLocaleString()}</span>
                </div>
                <div className="al-prev-divider"/>
                <div className="al-prev-row result">
                  <span>New Share Capital</span>
                  <span style={{color:"#1565c0",fontWeight:800}}>₱{newSC.toLocaleString()}</span>
                </div>
                <div className="al-prev-row" style={{fontSize:11,color:"#888"}}>
                  <span>New Max Loanable</span>
                  <span style={{color:"#2e7d32",fontWeight:700}}>₱{newMaxLoan.toLocaleString()}</span>
                </div>
              </div>
            )}
            <div style={{display:"flex",justifyContent:"flex-end",gap:10,marginTop:16}}>
              <button className="al-btn-cancel" onClick={() => setStep(1)}>← Back</button>
              <button className="al-btn-save" style={{background:"#1565c0",borderColor:"#1565c0"}}
                onClick={handleSave} disabled={!isValid||loading}>
                {loading?"Saving...":<span style={{display:"flex",alignItems:"center",justifyContent:"center",gap:6}}><Wallet size={14}/> Record Deposit</span>}
              </button>
            </div>
          </div>
        )}

        {/* History Tab */}
        {mainTab === "history" && (
          <div>
            <div style={{display:"grid",gridTemplateColumns:"repeat(2,1fr)",gap:8,marginBottom:14}}>
              <div style={{background:"#e3f2fd",borderRadius:8,padding:"10px 12px",textAlign:"center"}}>
                <div style={{fontSize:10,color:"#1565c0",fontWeight:600}}>Total Deposited</div>
                <div style={{fontSize:15,fontWeight:800,color:"#0d47a1"}}>₱{totalDeposits.toLocaleString()}</div>
              </div>
              <div style={{background:"#e8f5e9",borderRadius:8,padding:"10px 12px",textAlign:"center"}}>
                <div style={{fontSize:10,color:"#2e7d32",fontWeight:600}}>Transactions</div>
                <div style={{fontSize:15,fontWeight:800,color:"#1b5e20"}}>{allHistory.length}</div>
              </div>
            </div>
            <div className="al-search-wrap" style={{marginBottom:14}}>
              <Search size={13} color="#aaa"/>
              <input className="al-search-in" placeholder="Search by member name or ID..."
                value={histSearch} onChange={e => setHistSearch(e.target.value)}/>
            </div>
            {histLoading ? (
              <div style={{textAlign:"center",padding:24,color:"#aaa",fontSize:13}}>Loading history...</div>
            ) : memberGroups.length === 0 ? (
              <div style={{textAlign:"center",padding:24,color:"#bbb",fontSize:13}}>No share capital transactions found.</div>
            ) : (
              // ── BAGO: naka-group per MEMBER — i-click para makita
              // ang kanilang mga record. ───────────────────────────────
              memberGroups.map(g => {
                const isOpen = expandedMember === g.member_id;
                const memberTotal = g.txs.reduce((s,t) => s + parseFloat(t.amount||0), 0);
                return (
                  <div key={g.member_id} style={{background:"#fff",borderRadius:12,border:`1.5px solid ${isOpen?"#90caf9":"#e4f0e5"}`,marginBottom:10,overflow:"hidden"}}>
                    <div onClick={() => setExpandedMember(isOpen ? null : g.member_id)} style={{display:"flex",alignItems:"center",gap:12,padding:"14px 18px",cursor:"pointer",background:isOpen?"#e3f2fd":"#fff"}}>
                      <div style={{width:36,height:36,borderRadius:"50%",background:"#e3f2fd",color:"#1565c0",display:"flex",alignItems:"center",justifyContent:"center",fontWeight:700,flexShrink:0}}>{(g.member_name||"M")[0]}</div>
                      <div style={{flex:1,minWidth:0}}>
                        <div style={{fontWeight:700,fontSize:13,color:"#222"}}>{g.member_name}</div>
                        <div style={{fontSize:10.5,color:"#aaa",fontFamily:"monospace"}}>{g.member_id} · {g.txs.length} transaction{g.txs.length!==1?"s":""}</div>
                      </div>
                      <div style={{textAlign:"right",flexShrink:0}}>
                        <div style={{fontSize:14,fontWeight:800,color:"#1565c0"}}>+₱{memberTotal.toLocaleString()}</div>
                        <div style={{fontSize:9,color:"#bbb"}}>total</div>
                      </div>
                      <span style={{color:"#bbb",fontSize:13}}>{isOpen?"▲":"▼"}</span>
                    </div>
                    {isOpen && (
                      <div style={{borderTop:"1px solid #e3f2fd",overflowX:"auto"}}>
                        <table style={{width:"100%",borderCollapse:"collapse",fontSize:12}}>
                          <thead>
                            <tr style={{background:"#e3f2fd"}}>
                              <th style={{padding:"8px 14px",textAlign:"left",fontWeight:600,color:"#777",fontSize:10}}>Date</th>
                              <th style={{padding:"8px 14px",textAlign:"left",fontWeight:600,color:"#777",fontSize:10}}>Type</th>
                              <th style={{padding:"8px 14px",textAlign:"right",fontWeight:600,color:"#777",fontSize:10}}>Amount</th>
                              <th style={{padding:"8px 14px",textAlign:"right",fontWeight:600,color:"#777",fontSize:10}}>Balance After</th>
                              <th style={{padding:"8px 14px",textAlign:"left",fontWeight:600,color:"#777",fontSize:10}}>Note</th>
                              <th style={{padding:"8px 14px",textAlign:"left",fontWeight:600,color:"#777",fontSize:10}}>By</th>
                            </tr>
                          </thead>
                          <tbody>
                            {g.txs.map((t, idx) => (
                              <tr key={t.id} style={{background:idx%2===0?"#fff":"#f7fbff",borderTop:"1px solid #f5f5f5"}}>
                                <td style={{padding:"7px 14px",color:"#888",fontSize:10,whiteSpace:"nowrap"}}>{t.created_at}</td>
                                <td style={{padding:"7px 14px"}}>
                                  <span style={{
                                    background: t.txn_type==="CBU"?"#e8f5e9":t.txn_type==="Initial"?"#fff8e1":"#e3f2fd",
                                    color: t.txn_type==="CBU"?"#2e7d32":t.txn_type==="Initial"?"#f57f17":"#1565c0",
                                    padding:"2px 7px",borderRadius:20,fontSize:10,fontWeight:700,display:"inline-flex",alignItems:"center",gap:3,
                                  }}>
                                    {t.txn_type==="CBU"?<><TrendingUp size={10}/> CBU</>:t.txn_type==="Initial"?<><Sprout size={10}/> Initial</>:<><Wallet size={10}/> Deposit</>}
                                  </span>
                                </td>
                                <td style={{padding:"7px 14px",textAlign:"right",fontWeight:700,color:"#1565c0"}}>
                                  +₱{Number(t.amount).toLocaleString()}
                                </td>
                                <td style={{padding:"7px 14px",textAlign:"right",fontWeight:600,color:"#0d47a1"}}>
                                  ₱{Number(t.balance_after).toLocaleString()}
                                </td>
                                <td style={{padding:"7px 14px",color:"#888",fontSize:10}}>{t.note||"—"}</td>
                                <td style={{padding:"7px 14px",color:"#888",fontSize:10}}>{t.recorded_by||"—"}</td>
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