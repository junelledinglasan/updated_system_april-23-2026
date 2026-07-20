import { useState, useEffect } from "react";
import { Outlet, NavLink, useNavigate, useLocation } from "react-router-dom";
import { useAuth } from "../context/AuthContext";
import {
  LayoutDashboard, Users, UserCog, FileText,
  CreditCard, CheckSquare, Megaphone, BarChart2,
  GraduationCap, UserRound, BriefcaseBusiness, Smartphone
} from "lucide-react";
import { getLoansAPI, createLoanAPI, updateLoanStatusAPI, getGCashRequestsAPI } from "../api/loans";
import { getMembersAPI, registerMemberAPI, recordSavingsAPI, getMemberSavingsAPI } from "../api/members";
import { recordPaymentAPI } from "../api/payments";
import "./AdminLayout.css";
import logo from '../assets/logo.png';

const CLASS_OPTIONS = [
  { key: "Student",  icon: <GraduationCap     size={32} strokeWidth={1.5} color="#2e7d32"/>, label: "Student"  },
  { key: "Senior",   icon: <UserRound         size={32} strokeWidth={1.5} color="#2e7d32"/>, label: "Senior"   },
  { key: "Employed", icon: <BriefcaseBusiness size={32} strokeWidth={1.5} color="#2e7d32"/>, label: "Employed" },
];

const NAV_ITEMS = [
  { to: "/admin/dashboard",    icon: <LayoutDashboard size={15} />, label: "Dashboard"          },
  { to: "/admin/members",      icon: <Users           size={15} />, label: "Manage Member"      },
  { to: "/admin/staff",        icon: <UserCog         size={15} />, label: "Manage Staff"       },
  { to: "/admin/applications", icon: <FileText        size={15} />, label: "Online Application" },
  { to: "/admin/loan-payment", icon: <CreditCard      size={15} />, label: "Loan Payment"       },
  { to: "/admin/loan-approval",      icon: <CheckSquare size={15}/>, label: "Loan Approval"    },
  { to: "/admin/gcash-verification", icon: <Smartphone  size={15}/>, label: "Online Payments"   },
  { to: "/admin/announcement",       icon: <Megaphone   size={15}/>, label: "Announcement"     },
  { to: "/admin/reports",      icon: <BarChart2       size={15} />, label: "Reports"            },
];

const PAGE_CONFIG = {
  "/admin/dashboard": {
    title: "Office Operations Dashboard",
    sub:   "Manage LEAF MPC member records and financial audits.",
    actions: [
    ],
  },
  "/admin/members": {
    title: "Manage Members",
    sub:   "View, edit, and manage all registered LEAF MPC members.",
    actions: [
      { label: "Savings/Deposit",        cls: "btn-savings",  action: "savings"      },
      { label: "Share Capital Deposit",  cls: "btn-sharecap", action: "sharecap"     },
      { label: "+ Register Member",          cls: "btn-green",    action: "register"     },
    ],
  },
  "/admin/staff": {
    title: "Manage Staff",
    sub:   "Add and manage staff accounts for office personnel.",
    actions: [],
  },
  "/admin/applications": {
    title: "Online Applications",
    sub:   "Review membership registration applications submitted online.",
    actions: [],
  },
  "/admin/loan-payment": {
    title: "Loan Payment",
    sub:   "Record F2F loan payments collected at the office.",
    actions: [
      { label: "+ New F2F Payment",      cls: "btn-blue",  action: "f2f"     },
      { label: "+ New Loan Application", cls: "btn-green", action: "newloan" },
    ],
  },
  "/admin/loan-approval": {
title: "Loan Approval",
sub:   "Evaluate and process member loan applications.",
actions: [],
},
"/admin/gcash-verification": {
title: "GCash Payment Requests",
sub:   "Verify member GCash payments and record once confirmed.",
actions: [],
},
  "/admin/announcement": {
    title: "Announcements",
    sub:   "Post activities, seminars, and notices to all members.",
    actions: [],
  },
  "/admin/reports": {
    title: "Reports & Analytics",
    sub:   "Financial summaries, loan analytics, and payment behavior reports.",
    actions: [
      { label: "⬇ Export Excel", cls: "btn-outline", action: "export" },
    ],
  },
};

const DEFAULT_CONFIG = { title: "LEAF MPC Admin", sub: "Cooperative Information System", actions: [] };

// ─── Quick F2F Payment Modal ──────────────────────────────────────────────────
function F2FModal({ onClose }) {
  const [step,     setStep]   = useState(1);
  const [loans,    setLoans]  = useState([]);
  const [selected, setSelect] = useState(null);
  const [amount,   setAmount] = useState("");
  const [note,     setNote]   = useState("");
  const [error,    setError]  = useState("");
  const [done,     setDone]   = useState(false);
  const [loading,  setLoad]   = useState(false);
  const [fetching, setFetch]  = useState(true);
  const [search,   setSearch] = useState("");

  useEffect(() => {
    getLoansAPI({ status: "Active" })
      .then(data => setLoans(data))
      .catch(e => console.error(e))
      .finally(() => setFetch(false));
  }, []);

  const filtered = loans.filter(l =>
    (l.member_name||"").toLowerCase().includes(search.toLowerCase()) ||
    (l.member_code||"").toLowerCase().includes(search.toLowerCase()) ||
    (l.loan_id||"").toLowerCase().includes(search.toLowerCase())
  );

  const parsed  = parseFloat(amount) || 0;
  const balance = parseFloat(selected?.balance || 0);
  const isValid = parsed > 0 && selected && parsed <= balance;

  const handlePay = async () => {
    if (!parsed || parsed <= 0) { setError("Enter a valid amount."); return; }
    if (parsed > balance)       { setError(`Exceeds remaining balance ₱${balance.toLocaleString()}.`); return; }
    setLoad(true);
    try {
      await recordPaymentAPI({ loan: selected.id, member: selected.member, amount: parsed, note });
      setDone(true);
    } catch { setError("Failed to record payment. Please try again."); }
    finally { setLoad(false); }
  };

  if (done) return (
    <div className="al-overlay" onClick={onClose}>
      <div className="al-modal al-modal-sm" onClick={e => e.stopPropagation()}>
        <div className="al-modal-body" style={{alignItems:"center",textAlign:"center",padding:"32px 24px",gap:12}}>
          <div style={{fontSize:40}}>✅</div>
          <div style={{fontSize:15,fontWeight:700,color:"#1b5e20"}}>Payment Recorded!</div>
          <div style={{fontSize:12,color:"#888"}}>
            ₱{parsed.toLocaleString()} payment for <strong>{selected.member_name}</strong> has been saved.
          </div>
        </div>
        <div className="al-modal-footer">
          <button className="al-btn-save" onClick={onClose}>Done</button>
        </div>
      </div>
    </div>
  );

  return (
    <div className="al-overlay" onClick={onClose}>
      <div className="al-modal" onClick={e => e.stopPropagation()}>
        <div className="al-modal-header">
          <div>
            <div className="al-modal-title">New F2F Payment</div>
            <div className="al-modal-sub">Step {step} of 2 — {step === 1 ? "Select Member Loan" : "Enter Payment Details"}</div>
          </div>
          <button className="al-modal-close" onClick={onClose}>✕</button>
        </div>
        {step === 1 && (
          <>
            <div className="al-modal-body">
              <div className="al-step-info">Select the member's active loan to record payment for.</div>
              <div className="al-search-wrap">
                <span>🔍</span>
                <input className="al-search-in" placeholder="Search by name, member ID, loan ID..." value={search} onChange={e => setSearch(e.target.value)} />
              </div>
              <div className="al-loan-list">
                {fetching ? <div style={{textAlign:"center",padding:20,color:"#aaa"}}>Loading loans...</div>
                : filtered.length === 0 ? <div style={{textAlign:"center",padding:20,color:"#aaa"}}>No active loans found.</div>
                : filtered.map(l => (
                  <div key={l.id} className={`al-loan-item ${selected?.id === l.id ? "selected" : ""}`}
                    onClick={() => { setSelect(l); setAmount(String(l.monthly_due||"")); setError(""); }}>
                    <div className="al-loan-avatar">{(l.member_name||"M")[0]}</div>
                    <div className="al-loan-info">
                      <div className="al-loan-name">{l.member_name}</div>
                      <div className="al-loan-meta">{l.member_code} · {l.loan_id}</div>
                    </div>
                    <div className="al-loan-bal">
                      <div className="al-bal-val">₱{Number(l.balance).toLocaleString()}</div>
                      <div className="al-bal-label">balance</div>
                    </div>
                  </div>
                ))}
              </div>
            </div>
            <div className="al-modal-footer">
              <button className="al-btn-cancel" onClick={onClose}>Cancel</button>
              <button className="al-btn-save" onClick={() => setStep(2)} disabled={!selected}>Next →</button>
            </div>
          </>
        )}
        {step === 2 && (
          <>
            <div className="al-modal-body">
              <div className="al-borrower-strip">
                <div className="al-loan-avatar">{(selected.member_name||"M")[0]}</div>
                <div>
                  <div className="al-loan-name">{selected.member_name}</div>
                  <div className="al-loan-meta">{selected.member_code} · {selected.loan_id} · Balance: ₱{balance.toLocaleString()}</div>
                </div>
              </div>
              <div className="al-field">
                <label className="al-label">Payment Amount (₱) <span className="al-req">*</span></label>
                <div className="al-amount-wrap">
                  <span className="al-peso">₱</span>
                  <input className="al-amount-in" type="number" min="1" max={balance}
                    value={amount} onChange={e => { setAmount(e.target.value); setError(""); }} autoFocus />
                </div>
                <div className="al-quick-row">
                  <button className="al-quick" onClick={() => { setAmount(String(selected.monthly_due||"")); setError(""); }}>Monthly ₱{Number(selected.monthly_due||0).toLocaleString()}</button>
                  <button className="al-quick" onClick={() => { setAmount(String(balance)); setError(""); }}>Full ₱{balance.toLocaleString()}</button>
                </div>
              </div>
              <div className="al-field">
                <label className="al-label">Note (optional)</label>
                <input className="al-input" type="text" value={note} onChange={e => setNote(e.target.value)} placeholder="e.g. Partial payment, advance..." maxLength={80} />
              </div>
              {error && <div className="al-error">⚠ {error}</div>}
              {isValid && (
                <div className="al-preview">
                  <div className="al-prev-row"><span>Current balance</span><span>₱{balance.toLocaleString()}</span></div>
                  <div className="al-prev-row deduct"><span>Payment</span><span>− ₱{parsed.toLocaleString()}</span></div>
                  <div className="al-prev-divider"/>
                  <div className="al-prev-row result">
                    <span>New balance</span>
                    <span className={(balance-parsed)===0?"paid-green":""}>
                      ₱{(balance-parsed).toLocaleString()}
                      {(balance-parsed)===0 && " 🎉 FULLY PAID"}
                    </span>
                  </div>
                </div>
              )}
            </div>
            <div className="al-modal-footer">
              <button className="al-btn-cancel" onClick={() => setStep(1)}>← Back</button>
              <button className="al-btn-save" onClick={handlePay} disabled={!isValid||loading}>{loading?"Saving...":"Save Payment Record"}</button>
            </div>
          </>
        )}
      </div>
    </div>
  );
}

// ─── Savings Modal ────────────────────────────────────────────────────────────
function SavingsModal({ onClose }) {
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

  useEffect(() => {
    getMembersAPI()
      .then(data => setMembers(data))
      .catch(e => console.error(e))
      .finally(() => setFetch(false));
  }, []);

  useEffect(() => {
    if (mainTab !== "history") return;
    setHistLoading(true);
    import("../api/axiosInstance").then(({ default: api }) =>
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

  if (done) return (
    <div className="al-overlay" onClick={onClose}>
      <div className="al-modal al-modal-sm" onClick={e => e.stopPropagation()}>
        <div className="al-modal-body" style={{alignItems:"center",textAlign:"center",padding:"32px 24px",gap:12}}>
          <div style={{fontSize:40}}>{type === "Deposit" ? "💰" : "💸"}</div>
          <div style={{fontSize:15,fontWeight:700,color:"#1b5e20"}}>{type} Recorded!</div>
          <div style={{fontSize:12,color:"#888"}}>
            ₱{parsed.toLocaleString()} {type.toLowerCase()} for <strong>{selected.fullname}</strong>.
            New balance: <strong>₱{newBal.toLocaleString()}</strong>
          </div>
        </div>
        <div className="al-modal-footer">
          <button className="al-btn-save" onClick={onClose}>Done</button>
        </div>
      </div>
    </div>
  );

  return (
    <div className="al-overlay" onClick={onClose}>
      <div className="al-modal" style={{maxWidth: mainTab === "history" ? 620 : 480}} onClick={e => e.stopPropagation()}>
        <div className="al-modal-header">
          <div>
            <div className="al-modal-title">🏦 Savings Transaction</div>
            <div className="al-modal-sub">
              {mainTab === "new"
                ? `Step ${step} of 2 — ${step === 1 ? "Select Member" : "Transaction Details"}`
                : "All savings transactions"}
            </div>
          </div>
          <button className="al-modal-close" onClick={onClose}>✕</button>
        </div>

        <div style={{display:"flex",borderBottom:"2px solid #f0f0f0",flexShrink:0}}>
          {[
            {key:"new",     label:"💰 New Transaction"},
            {key:"history", label:`📋 History${allSavings.length > 0 ? " ("+allSavings.length+")" : ""}`},
          ].map(t => (
            <button key={t.key} onClick={() => { setMainTab(t.key); setDone(false); setStep(1); }} style={{
              flex:1, padding:"10px 8px", fontSize:12, fontWeight:600, cursor:"pointer",
              border:"none", background:"none",
              color: mainTab===t.key ? "#e65100" : "#aaa",
              borderBottom: mainTab===t.key ? "2px solid #f57f17" : "2px solid transparent",
              marginBottom:-2, transition:"all 0.15s",
            }}>{t.label}</button>
          ))}
        </div>

        {mainTab === "new" && (<>
          {step === 1 && (
            <>
              <div className="al-modal-body">
                <div className="al-search-wrap">
                  <span>🔍</span>
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
                              <div style={{fontSize:13,fontWeight:800,color:"#f57f17"}}>✓ Selected</div>
                            </div>
                          )}
                        </div>
                      );
                    })
                  }
                </div>
              </div>
              <div className="al-modal-footer">
                <button className="al-btn-cancel" onClick={onClose}>Cancel</button>
                <button className="al-btn-save" style={{background:"#f57f17",borderColor:"#f57f17"}}
                  onClick={() => setStep(2)} disabled={!selected}>Next →</button>
              </div>
            </>
          )}
          {step === 2 && (
            <>
              <div className="al-modal-body">
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
                      }}>{t === "Deposit" ? "💰 Deposit" : "💸 Withdraw"}</button>
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
                {error && <div className="al-error">⚠ {error}</div>}
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
              <div className="al-modal-footer">
                <button className="al-btn-cancel" onClick={() => setStep(1)}>← Back</button>
                <button className="al-btn-save"
                  style={{background:type==="Deposit"?"#2e7d32":"#c62828",borderColor:type==="Deposit"?"#2e7d32":"#c62828"}}
                  onClick={handleSave} disabled={!isValid || loading}>
                  {loading ? "Saving..." : type === "Deposit" ? "💰 Record Deposit" : "💸 Record Withdrawal"}
                </button>
              </div>
            </>
          )}
        </>)}

        {mainTab === "history" && (
          <>
            <div className="al-modal-body" style={{gap:10}}>
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
              <div className="al-search-wrap">
                <span>🔍</span>
                <input className="al-search-in" placeholder="Search by member name or ID..."
                  value={histSearch} onChange={e => setHistSearch(e.target.value)} />
              </div>
              {histLoading ? (
                <div style={{textAlign:"center",padding:24,color:"#aaa",fontSize:13}}>Loading history...</div>
              ) : filteredHist.length === 0 ? (
                <div style={{textAlign:"center",padding:24,color:"#bbb",fontSize:13}}>No savings transactions found.</div>
              ) : (
                <div style={{borderRadius:8,overflow:"hidden",border:"1px solid #ffe082",maxHeight:320,overflowY:"auto"}}>
                  <table style={{width:"100%",borderCollapse:"collapse",fontSize:12}}>
                    <thead style={{position:"sticky",top:0,zIndex:1}}>
                      <tr style={{background:"#fff8e1"}}>
                        <th style={{padding:"8px 10px",textAlign:"left",fontWeight:600,color:"#777",fontSize:10}}>Date</th>
                        <th style={{padding:"8px 10px",textAlign:"left",fontWeight:600,color:"#777",fontSize:10}}>Member</th>
                        <th style={{padding:"8px 10px",textAlign:"left",fontWeight:600,color:"#777",fontSize:10}}>Type</th>
                        <th style={{padding:"8px 10px",textAlign:"right",fontWeight:600,color:"#777",fontSize:10}}>Amount</th>
                        <th style={{padding:"8px 10px",textAlign:"right",fontWeight:600,color:"#777",fontSize:10}}>Balance After</th>
                        <th style={{padding:"8px 10px",textAlign:"left",fontWeight:600,color:"#777",fontSize:10}}>Note</th>
                      </tr>
                    </thead>
                    <tbody>
                      {filteredHist.map((tx, idx) => (
                        <tr key={tx.id} style={{background:idx%2===0?"#fff":"#fffde7",borderTop:"1px solid #f5f5f5"}}>
                          <td style={{padding:"7px 10px",color:"#888",fontSize:10,whiteSpace:"nowrap"}}>{tx.created_at?.split("T")[0]}</td>
                          <td style={{padding:"7px 10px"}}>
                            <div style={{fontWeight:600,fontSize:11,color:"#222"}}>{tx.member_name}</div>
                            <div style={{fontSize:9,color:"#aaa",fontFamily:"monospace"}}>{tx.member_code}</div>
                          </td>
                          <td style={{padding:"7px 10px"}}>
                            <span style={{
                              background:tx.transaction_type==="Deposit"?"#e8f5e9":"#fce4ec",
                              color:tx.transaction_type==="Deposit"?"#2e7d32":"#c62828",
                              padding:"2px 7px",borderRadius:20,fontSize:10,fontWeight:700,
                            }}>
                              {tx.transaction_type==="Deposit"?"💰":"💸"} {tx.transaction_type}
                            </span>
                          </td>
                          <td style={{padding:"7px 10px",textAlign:"right",fontWeight:700,color:tx.transaction_type==="Deposit"?"#2e7d32":"#c62828"}}>
                            {tx.transaction_type==="Deposit"?"+":"−"}₱{Number(tx.amount).toLocaleString()}
                          </td>
                          <td style={{padding:"7px 10px",textAlign:"right",fontWeight:600,color:"#333"}}>₱{Number(tx.balance_after).toLocaleString()}</td>
                          <td style={{padding:"7px 10px",color:"#888",fontSize:10}}>{tx.note||"—"}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )}
            </div>
            <div className="al-modal-footer">
              <button className="al-btn-cancel" onClick={onClose}>Close</button>
            </div>
          </>
        )}
      </div>
    </div>
  );
}

// ─── FormField ────────────────────────────────────────────────────────────────
function RegField({ name, label, type="text", options=null, required=false, form, errors, handle, clearErr }) {
  return (
    <div className="al-field">
      <label className="al-label">{label}{required && <span className="al-req"> *</span>}</label>
      {options ? (
        <select className={`al-input ${errors[name] ? "al-input-err" : ""}`} name={name} value={form[name]||""} onChange={handle}>
          {options.map(o => <option key={o}>{o}</option>)}
        </select>
      ) : (
        <input
          className={`al-input ${errors[name] ? "al-input-err" : ""}`}
          type={type} name={name} value={form[name]||""}
          onChange={e => { handle(e); if(clearErr) clearErr(name); }}
        />
      )}
      {errors[name] && <div className="al-field-err">{errors[name]}</div>}
    </div>
  );
}

// ─── Register Member Modal ────────────────────────────────────────────────────
function RegisterModal({ onClose }) {
  const TABS = [
    { key: "personal",       label: "Personal Info"   },
    { key: "spouse",         label: "Spouse & Family" },
    { key: "classification", label: "Classification"  },
    { key: "account",        label: "Account Info"    },
  ];

  const [form, setForm] = useState({
    // Personal
    last_name: "", first_name: "", middle_name: "",
    birth_date: "", place_of_birth: "", sex: "Male",
    civil_status: "Single", educational_attainment: "",
    contact_number: "", email: "", address: "",
    occupation: "", income: "", tin_no: "", sss_gsis_no: "",
    religious_social_affiliation: "",
    share_capital: "",
    birth_certificate: false, marriage_certificate: false,
    // Spouse & Family
    spouse_name: "", spouse_occupation: "", spouse_income: "",
    no_of_dependants: "",
    beneficiary_name: "", beneficiary_relationship: "",
    credit_references: "",
    // Classification
    classification: "Employed",
    school_name: "", year_level: "", allowance: "",
    pension_income: "", job_type: "Employed", monthly_income: "",
  });

  const [errors,  setErrors]  = useState({});
  const [done,    setDone]    = useState(false);
  const [tab,     setTab]     = useState("personal");
  const [copied,  setCopied]  = useState("");
  const [loading, setLoading] = useState(false);
  const [creds,   setCreds]   = useState({ memberId: "", username: "", password: "" });

  const handle = e => {
    const val = e.target.type === "checkbox" ? e.target.checked : e.target.value;
    setForm(p => ({ ...p, [e.target.name]: val }));
    setErrors(p => ({ ...p, [e.target.name]: "" }));
  };

  const validate = () => {
    const e = {};
    if (!form.first_name.trim())     e.first_name     = "Required";
    if (!form.last_name.trim())      e.last_name      = "Required";
    if (!form.birth_date)            e.birth_date     = "Required";
    if (!form.contact_number.trim()) e.contact_number = "Required";
    if (!form.address.trim())        e.address        = "Required";
    if (form.classification === "Student" && !form.school_name.trim()) e.school_name = "Required";
    if (form.classification === "Student" && !form.year_level.trim())  e.year_level  = "Required";
    return e;
  };

  const handleSubmit = async () => {
    const e = validate();
    if (Object.keys(e).length) {
      setErrors(e);
      const personalFields = ["first_name","last_name","birth_date","contact_number","address"];
      const classFields    = ["school_name","year_level"];
      if (personalFields.some(f => e[f])) { setTab("personal");      return; }
      if (classFields.some(f => e[f]))    { setTab("classification"); return; }
      return;
    }
    setLoading(true);
    try {
      const result = await registerMemberAPI({
        first_name:                   form.first_name,
        last_name:                    form.last_name,
        middle_name:                  form.middle_name,
        birth_date:                   form.birth_date,
        place_of_birth:               form.place_of_birth,
        sex:                          form.sex,
        civil_status:                 form.civil_status,
        educational_attainment:       form.educational_attainment,
        contact_number:               form.contact_number,
        email:                        form.email,
        address:                      form.address,
        occupation:                   form.occupation,
        income:                       form.income || 0,
        tin_no:                       form.tin_no,
        sss_gsis_no:                  form.sss_gsis_no,
        religious_social_affiliation: form.religious_social_affiliation,
        birth_certificate:            form.birth_certificate,
        marriage_certificate:         form.marriage_certificate,
        spouse_name:                  form.spouse_name,
        spouse_occupation:            form.spouse_occupation,
        spouse_income:                form.spouse_income || 0,
        no_of_dependants:             form.no_of_dependants || 0,
        beneficiary_name:             form.beneficiary_name,
        beneficiary_relationship:     form.beneficiary_relationship,
        credit_references:            form.credit_references,
        classification:               form.classification,
        school_name:                  form.school_name,
        year_level:                   form.year_level,
        allowance:                    form.allowance || 0,
        pension_income:               form.pension_income || 0,
        job_type:                     form.job_type,
        monthly_income:               form.monthly_income || 0,
        share_capital:                form.share_capital || 0,
      });
      setCreds({ memberId: result.member_id, username: result.username, password: result.plain_password });
      setDone(true);
      setTab("account");
    } catch(err) {
      const msg = err.response?.data?.error || err.response?.data?.detail || "Failed to register member.";
      setErrors({ first_name: msg });
      setTab("personal");
    } finally { setLoading(false); }
  };

  const copyText = (text, key) => {
    navigator.clipboard.writeText(text).catch(() => {});
    setCopied(key);
    setTimeout(() => setCopied(""), 1800);
  };

  return (
    <div className="al-overlay" onClick={onClose}>
      <div className="al-modal al-modal-lg" onClick={e => e.stopPropagation()}>
        <div className="al-modal-header">
          <div>
            <div className="al-modal-title">Register New Member</div>
            <div className="al-modal-sub">LEAF MPC Member Application & Information Sheet</div>
          </div>
          <button className="al-modal-close" onClick={onClose}>✕</button>
        </div>

        <div className="al-reg-tabs">
          {TABS.map((t, i) => (
            <button key={t.key} className={`al-reg-tab ${tab === t.key ? "active" : ""}`}
              onClick={() => !done && setTab(t.key)}
              style={{ cursor: done ? "default" : "pointer" }}>
              <span className="al-reg-tab-num">{i + 1}</span> {t.label}
            </button>
          ))}
        </div>

        <div className="al-modal-body">

          {/* ── TAB 1: Personal Info ── */}
          {tab === "personal" && (
            <div className="al-form-grid">
              {/* Name */}
              <RegField name="last_name"   label="Surname"     required form={form} errors={errors} handle={handle} clearErr={n=>setErrors(p=>({...p,[n]:""})) }/>
              <RegField name="first_name"  label="First Name"  required form={form} errors={errors} handle={handle} clearErr={n=>setErrors(p=>({...p,[n]:""})) }/>
              <RegField name="middle_name" label="Middle Name"          form={form} errors={errors} handle={handle}/>

              {/* Address */}
              <div className="al-field al-full">
                <label className="al-label">Address <span className="al-req">*</span></label>
                <input className={`al-input ${errors.address?"al-input-err":""}`} name="address" value={form.address} onChange={handle} placeholder="Complete address"/>
                {errors.address && <div className="al-field-err">{errors.address}</div>}
              </div>

              {/* Birth */}
              <RegField name="birth_date"     label="Date of Birth"   required type="date" form={form} errors={errors} handle={handle} clearErr={n=>setErrors(p=>({...p,[n]:""})) }/>
              <RegField name="place_of_birth" label="Place of Birth"           form={form} errors={errors} handle={handle}/>

              {/* Sex & Civil Status */}
              <RegField name="sex" label="Sex" options={["Male","Female"]} form={form} errors={errors} handle={handle}/>
              <RegField name="civil_status" label="Civil Status" options={["Single","Married","Widowed","Separated"]} form={form} errors={errors} handle={handle}/>

              {/* IDs */}
              <RegField name="tin_no"      label="TIN No."      form={form} errors={errors} handle={handle}/>
              <RegField name="sss_gsis_no" label="SSS/GSIS No." form={form} errors={errors} handle={handle}/>

              {/* Occupation & Income */}
              <RegField name="occupation" label="Occupation"        form={form} errors={errors} handle={handle}/>
              <RegField name="income"     label="Monthly Income (₱)" type="number" form={form} errors={errors} handle={handle}/>

              {/* Contact */}
              <RegField name="contact_number" label="Tel. No. / CP No." required form={form} errors={errors} handle={handle} clearErr={n=>setErrors(p=>({...p,[n]:""})) }/>
              <RegField name="email"          label="Email Address"             type="email" form={form} errors={errors} handle={handle}/>

              {/* Education & Affiliation */}
              <RegField name="educational_attainment"       label="Educational Attainment" options={["Elementary","High School","Vocational","College","Post Graduate"]} form={form} errors={errors} handle={handle}/>
              <RegField name="religious_social_affiliation" label="Religious/Social Affiliation" form={form} errors={errors} handle={handle}/>

              {/* Share Capital */}
              <div className="al-field">
                <label className="al-label">Amount Paid for Membership (₱)</label>
                <div className="al-amount-wrap">
                  <span className="al-peso">₱</span>
                  <input className="al-amount-in" type="number" name="share_capital"
                    value={form.share_capital||""} onChange={handle} placeholder="e.g. 4000"/>
                </div>
                {form.share_capital > 0 && (
                  <div style={{marginTop:6,padding:"6px 10px",background:"#e8f5e9",borderRadius:8,fontSize:11,color:"#2e7d32",fontWeight:600}}>
                    Share Capital = ₱{(parseFloat(form.share_capital||0)*2).toLocaleString()} (paid × 2) · Max Loanable = ₱{(parseFloat(form.share_capital||0)*2).toLocaleString()}
                  </div>
                )}
              </div>

              {/* Documents */}
              <div className="al-field">
                <label className="al-label">Birth Certificate Submitted</label>
                <label style={{display:"flex",alignItems:"center",gap:8,marginTop:4,fontSize:13,cursor:"pointer"}}>
                  <input type="checkbox" name="birth_certificate" checked={form.birth_certificate} onChange={handle}/> Yes
                </label>
              </div>
              <div className="al-field">
                <label className="al-label">Marriage Certificate Submitted</label>
                <label style={{display:"flex",alignItems:"center",gap:8,marginTop:4,fontSize:13,cursor:"pointer"}}>
                  <input type="checkbox" name="marriage_certificate" checked={form.marriage_certificate} onChange={handle}/> Yes (if married)
                </label>
              </div>
            </div>
          )}

          {/* ── TAB 2: Spouse & Family ── */}
          {tab === "spouse" && (
            <div className="al-form-grid">
              <div style={{gridColumn:"1/-1",background:"#f9fef9",border:"1px solid #e8f5e9",borderRadius:10,padding:"12px 16px",fontSize:12,color:"#555",marginBottom:4}}>
                Fill in spouse information if married. Leave blank if not applicable.
              </div>

              {/* Spouse */}
              <RegField name="spouse_name"       label="Spouse Name"             form={form} errors={errors} handle={handle}/>
              <RegField name="spouse_occupation" label="Spouse Occupation"       form={form} errors={errors} handle={handle}/>
              <RegField name="spouse_income"     label="Spouse Monthly Income (₱)" type="number" form={form} errors={errors} handle={handle}/>
              <RegField name="no_of_dependants"  label="No. of Dependants"       type="number" form={form} errors={errors} handle={handle}/>

              {/* Divider */}
              <div style={{gridColumn:"1/-1",borderTop:"1px solid #e8f5e9",paddingTop:12,marginTop:4}}>
                <div style={{fontSize:11,fontWeight:700,color:"#2e7d32",textTransform:"uppercase",letterSpacing:1,marginBottom:12}}>Beneficiary Information</div>
              </div>

              <RegField name="beneficiary_name"         label="Beneficiary Name"         form={form} errors={errors} handle={handle}/>
              <RegField name="beneficiary_relationship" label="Relationship to Member"   form={form} errors={errors} handle={handle}/>

              {/* Divider */}
              <div style={{gridColumn:"1/-1",borderTop:"1px solid #e8f5e9",paddingTop:12,marginTop:4}}>
                <div style={{fontSize:11,fontWeight:700,color:"#2e7d32",textTransform:"uppercase",letterSpacing:1,marginBottom:12}}>Credit References</div>
              </div>

              <div className="al-field al-full">
                <label className="al-label">Credit References</label>
                <textarea className="al-input" name="credit_references" rows={3}
                  value={form.credit_references} onChange={handle}
                  placeholder="Names and contact details of credit references..."
                  style={{resize:"none"}}/>
              </div>
            </div>
          )}

          {/* ── TAB 3: Classification ── */}
          {tab === "classification" && (
            <div className="al-form-grid">
              <div className="al-field al-full">
                <label className="al-label">Member Classification <span className="al-req">*</span></label>
                <div style={{display:"flex",gap:12,marginTop:8}}>
                  {CLASS_OPTIONS.map(c => (
                    <div key={c.key} onClick={() => setForm(p => ({...p, classification: c.key}))}
                      style={{
                        flex:1, border:`2px solid ${form.classification===c.key?"#2e7d32":"#e0e0e0"}`,
                        borderRadius:10, padding:"16px 10px", textAlign:"center", cursor:"pointer",
                        background: form.classification===c.key ? "#e8f5e9" : "#fafafa", transition:"all 0.2s",
                      }}>
                      <div style={{marginBottom:6,display:"flex",justifyContent:"center"}}>{c.icon}</div>
                      <div style={{fontSize:12,fontWeight:700,color:"#2e7d32"}}>{c.label}</div>
                    </div>
                  ))}
                </div>
              </div>
              {form.classification === "Student" && (<>
                <RegField name="school_name" label="School Name" required form={form} errors={errors} handle={handle} clearErr={n=>setErrors(p=>({...p,[n]:""})) }/>
                <RegField name="year_level"  label="Year Level"  required form={form} errors={errors} handle={handle}
                  options={["Grade 7","Grade 8","Grade 9","Grade 10","Grade 11","Grade 12","1st Year","2nd Year","3rd Year","4th Year","5th Year","Graduate"]}/>
                <RegField name="allowance" label="Monthly Allowance (₱)" type="number" form={form} errors={errors} handle={handle}/>
              </>)}
              {form.classification === "Senior" && (<>
                <RegField name="educational_attainment" label="Educational Attainment"
                  options={["Elementary","High School","Vocational","College","Post Graduate"]}
                  form={form} errors={errors} handle={handle}/>
                <RegField name="pension_income" label="Monthly Pension Income (₱)" type="number" form={form} errors={errors} handle={handle}/>
              </>)}
              {form.classification === "Employed" && (<>
                <RegField name="occupation"     label="Occupation/Job Title" form={form} errors={errors} handle={handle}/>
                <RegField name="job_type"       label="Employment Type"
                  options={["Employed","Self-Employed","Business","Freelance","Other"]}
                  form={form} errors={errors} handle={handle}/>
                <RegField name="monthly_income" label="Monthly Income (₱)" type="number" form={form} errors={errors} handle={handle}/>
              </>)}
            </div>
          )}

          {/* ── TAB 4: Account ── */}
          {tab === "account" && (
            <div className="al-form-grid">
              {done ? (<>
                <div className="al-field al-full" style={{textAlign:"center",padding:"12px 0"}}>
                  <div style={{fontSize:40,marginBottom:8}}>🎉</div>
                  <div style={{fontSize:15,fontWeight:800,color:"#1b5e20",marginBottom:4}}>
                    {form.first_name} {form.last_name} is now an official member!
                  </div>
                  <div style={{fontSize:12,color:"#888"}}>Share the credentials below with the member.</div>
                </div>
                <div className="al-cred-card" style={{gridColumn:"1/-1"}}>
                  <div className="al-cred-title">Login Credentials</div>
                  <div className="al-cred-sub">Give this slip to the member</div>
                  {[["Member ID",creds.memberId,"id"],["Username",creds.username,"user"],["Password",creds.password,"pass"]].map(([k,v,key]) => (
                    <div key={k} className="al-cred-row">
                      <span className="al-cred-label">{k}</span>
                      <div className="al-cred-val-wrap">
                        <span className="al-cred-val">{v}</span>
                        <button className="al-copy-btn" onClick={() => copyText(v,key)}>
                          {copied===key ? "Copied" : "Copy"}
                        </button>
                      </div>
                    </div>
                  ))}
                </div>
                <div className="al-cred-notice" style={{gridColumn:"1/-1"}}>
                  The member can change their password anytime in My Profile after logging in.
                </div>
              </>) : (
                <div className="al-field al-full" style={{textAlign:"center",padding:"24px 0",color:"#888"}}>
                  Complete all tabs first, then submit to generate credentials.
                </div>
              )}
            </div>
          )}
        </div>

        <div className="al-modal-footer">
          {!done ? (<>
            {tab !== "personal" && (
              <button className="al-btn-cancel" onClick={() => {
                const keys = TABS.map(t => t.key);
                setTab(keys[keys.indexOf(tab) - 1]);
              }}>Previous</button>
            )}
            {tab === "personal" && <button className="al-btn-cancel" onClick={onClose}>Cancel</button>}
            {tab !== "classification" ? (
              <button className="al-btn-save" onClick={() => {
                const keys = TABS.map(t => t.key);
                setTab(keys[keys.indexOf(tab) + 1]);
              }}>Next</button>
            ) : (
              <button className="al-btn-save" onClick={handleSubmit} disabled={loading}>
                {loading ? "Registering..." : "Register Member"}
              </button>
            )}
          </>) : (
            <button className="al-btn-save" onClick={onClose}>Done</button>
          )}
        </div>
      </div>
    </div>
  );
}

// ─── New F2F Loan Application Modal ──────────────────────────────────────────
const LOAN_TYPES_LIST = ["Regular Loan","Emergency Loan","Salary Loan","Housing Loan","Business Loan"];
const MAX_TERM = { "Regular Loan":24,"Emergency Loan":12,"Salary Loan":12,"Housing Loan":48,"Business Loan":36 };

function NewLoanModal({ onClose }) {
  const [step,          setStep]         = useState(1);
  const [selMember,     setMember]        = useState(null);
  const [search,        setSearch]        = useState("");
  const [form,          setForm]          = useState({ loanType:"Regular Loan", amount:"", term:"12", purpose:"", collateral:"" });
  const [errors,        setErrors]        = useState({});
  const [done,          setDone]          = useState(false);
  const [loadingSubmit, setLoadingSubmit] = useState(false);
  const [showConfirm,   setShowConfirm]   = useState(false);
  const [refNo,         setRefNo]         = useState("");
  const [monthlyResult, setMonthlyResult] = useState(0);
  const [members,       setMembers]       = useState([]);
  const [fetching,      setFetching]      = useState(true);
  const [showRateEdit,  setShowRateEdit]  = useState(false);
  const [rates, setRates] = useState({
    serviceFeePct: 3, insurancePct: 1.25, sdPct: 1, scPct: 3,
    filingFeeAmt: 50, interestOverride: 0,
  });

  const handle = e => setForm(p => ({ ...p, [e.target.name]: e.target.value }));

  useEffect(() => {
    getMembersAPI()
      .then(data => setMembers(data))
      .catch(e => console.error(e))
      .finally(() => setFetching(false));
  }, []);

  const filtered = members.filter(m =>
    (m.fullname||"").toLowerCase().includes(search.toLowerCase()) ||
    (m.member_id||"").toLowerCase().includes(search.toLowerCase())
  );

  const shareCapital = selMember ? parseFloat(selMember.share_capital||0) : 0;
  const maxLoanable  = shareCapital;
  const amount       = parseFloat(form.amount) || 0;
  const term         = parseInt(form.term) || 12;
  const defaultRate  = amount <= 50000 ? 0.0125 : amount <= 150000 ? 0.01125 : 0.01;
  const effectiveRate= rates.interestOverride > 0 ? rates.interestOverride / 100 : defaultRate;
  const interest     = effectiveRate * amount * term;
  const serviceFee   = amount * (rates.serviceFeePct / 100);
  const filingFee    = rates.filingFeeAmt;
  const insurance    = amount * (rates.insurancePct / 100);
  const sd           = amount * (rates.sdPct / 100);
  const sc           = amount * (rates.scPct / 100);
  const totalDed     = interest + serviceFee + filingFee + insurance + sd + sc;
  const netProceeds  = amount - totalDed;
  const monthly      = amount > 0 ? ((amount + interest) / term).toFixed(2) : 0;

  const validate = () => {
    const e = {};
    if (!form.amount || parseFloat(form.amount) <= 0) e.amount  = "Enter a valid amount.";
    if (parseFloat(form.amount) < 3000) e.amount = "Minimum loan amount is ₱3,000.";
    if (!form.purpose.trim())           e.purpose = "Purpose is required.";
    return e;
  };

  const handleSubmit = async () => {
    const e = validate();
    if (Object.keys(e).length) { setErrors(e); return; }
    setLoadingSubmit(true);
    try {
      // F2F loan — create with is_f2f flag then immediately approve
      const result = await createLoanAPI({
        member:      selMember.id,
        loan_type:   form.loanType,
        amount:      parseFloat(form.amount),
        term_months: parseInt(form.term),
        purpose:     form.purpose,
        collateral:  form.collateral,
        is_f2f:      true,
      });
      // Approve immediately — F2F loans skip the approval queue
      if (result.status !== 'Active') {
        await updateLoanStatusAPI(result.id, 'Approved');
      }
      setRefNo(result.loan_id);
      setMonthlyResult(result.monthly_due);
      setDone(true);
    } catch(err) {
      setErrors({ amount: err.response?.data?.detail || "Failed to submit loan." });
    } finally { setLoadingSubmit(false); }
  };

  if (done) return (
    <div className="al-overlay" onClick={onClose}>
      <div className="al-modal al-modal-sm" onClick={e => e.stopPropagation()}>
        <div className="al-modal-header">
          <div className="al-modal-title">✅ Application Recorded!</div>
          <button className="al-modal-close" onClick={onClose}>✕</button>
        </div>
        <div className="al-modal-body" style={{gap:12}}>
          <div style={{fontSize:12,color:"#666",lineHeight:1.6}}>
            Loan application for <strong>{selMember.fullname}</strong> has been recorded.
          </div>
          <div className="al-cred-card">
            <div className="al-cred-title">📋 Application Details</div>
            <div className="al-cred-row"><span className="al-cred-label">Loan ID</span><span className="al-cred-val">{refNo}</span></div>
            <div className="al-cred-row"><span className="al-cred-label">Member</span><span className="al-cred-val">{selMember.member_id}</span></div>
            <div className="al-cred-row"><span className="al-cred-label">Loan Type</span><span className="al-cred-val">{form.loanType}</span></div>
            <div className="al-cred-row"><span className="al-cred-label">Amount</span><span className="al-cred-val">₱{parseFloat(form.amount).toLocaleString()}</span></div>
            <div className="al-cred-row"><span className="al-cred-label">Monthly</span><span className="al-cred-val">₱{parseFloat(monthlyResult||monthly).toLocaleString()}</span></div>
          </div>
          <div className="al-cred-notice">Go to Loan Approval page to process this application.</div>
        </div>
        <div className="al-modal-footer">
          <button className="al-btn-save" onClick={onClose}>Done</button>
        </div>
      </div>
    </div>
  );

  // ── Confirmation Modal ──
  if (showConfirm) return (
    <div className="al-overlay" onClick={() => setShowConfirm(false)}>
      <div className="al-modal al-modal-sm" onClick={e => e.stopPropagation()}>
        <div className="al-modal-header">
          <div className="al-modal-title">Confirm Loan Application</div>
          <button className="al-modal-close" onClick={() => setShowConfirm(false)}>✕</button>
        </div>
        <div className="al-modal-body" style={{gap:14}}>
          <div style={{background:"#e8f5e9",borderRadius:10,padding:"14px 16px",fontSize:13,color:"#1b5e20",lineHeight:1.7}}>
            <strong>Please confirm the following loan details:</strong>
            <br/><br/>
            <strong>Member:</strong> {selMember?.fullname}<br/>
            <strong>Loan Type:</strong> {form.loanType}<br/>
            <strong>Amount:</strong> ₱{parseFloat(form.amount||0).toLocaleString()}<br/>
            <strong>Term:</strong> {form.term} months<br/>
            <strong>Purpose:</strong> {form.purpose}
          </div>
          <div style={{fontSize:12,color:"#f57c00",background:"#fff8e1",borderRadius:8,padding:"10px 14px",border:"1px solid #ffe082"}}>
            ⚠ This will immediately activate the loan. Please double-check all details before confirming.
          </div>
        </div>
        <div className="al-modal-footer">
          <button className="al-btn-cancel" onClick={() => setShowConfirm(false)}>Go Back</button>
          <button className="al-btn-save" onClick={() => { setShowConfirm(false); handleSubmit(); }} disabled={loadingSubmit}>
            {loadingSubmit ? "Processing..." : "Yes, Confirm & Approve"}
          </button>
        </div>
      </div>
    </div>
  );

  return (
    <div className="al-overlay" onClick={onClose}>
      <div className="al-modal al-modal-lg" onClick={e => e.stopPropagation()}>
        <div className="al-modal-header">
          <div>
            <div className="al-modal-title">New F2F Loan Application</div>
            <div className="al-modal-sub">Step {step} of 2 — {step===1 ? "Select Member" : "Loan Details"}</div>
          </div>
          <button className="al-modal-close" onClick={onClose}>✕</button>
        </div>

        {step === 1 && (
          <>
            <div className="al-modal-body">
              <div className="al-step-info">Select the member who is applying for a loan.</div>
              <div className="al-search-wrap">
                <span>🔍</span>
                <input className="al-search-in" placeholder="Search by name or member ID..." value={search} onChange={e => setSearch(e.target.value)} />
              </div>
              <div className="al-loan-list">
                {fetching ? <div style={{textAlign:"center",padding:20,color:"#aaa"}}>Loading members...</div>
                : filtered.length===0 ? <div style={{textAlign:"center",padding:20,color:"#aaa"}}>No members found.</div>
                : filtered.map(m => (
                  <div key={m.id} className={`al-loan-item ${selMember?.id===m.id?"selected":""}`} onClick={() => setMember(m)}>
                    <div className="al-loan-avatar">{m.fullname.charAt(0)}</div>
                    <div className="al-loan-info">
                      <div className="al-loan-name">{m.fullname}</div>
                      <div className="al-loan-meta">{m.member_id}</div>
                    </div>
                    <div className="al-loan-bal">
                      <div className="al-bal-val" style={{color:"#2e7d32"}}>₱{Number(m.share_capital||0).toLocaleString()}</div>
                      <div className="al-bal-label">max loanable</div>
                    </div>
                  </div>
                ))}
              </div>
            </div>
            <div className="al-modal-footer">
              <button className="al-btn-cancel" onClick={onClose}>Cancel</button>
              <button className="al-btn-save" onClick={() => setStep(2)} disabled={!selMember}>Next →</button>
            </div>
          </>
        )}

        {step === 2 && (
          <>
            <div className="al-modal-body">
              <div className="al-borrower-strip">
                <div className="al-loan-avatar">{selMember.fullname.charAt(0)}</div>
                <div>
                  <div className="al-loan-name">{selMember.fullname}</div>
                  <div className="al-loan-meta">{selMember.member_id} · Share Capital: ₱{shareCapital.toLocaleString()} · Max Loanable: ₱{maxLoanable.toLocaleString()}</div>
                </div>
              </div>
              <div className="al-form-grid">
                <div className="al-field al-full">
                  <label className="al-label">Loan Type</label>
                  <select className="al-input" name="loanType" value={form.loanType} onChange={e => { handle(e); setErrors({}); }}>
                    {LOAN_TYPES_LIST.map(t => <option key={t}>{t}</option>)}
                  </select>
                </div>
                <div className="al-field">
                  <label className="al-label">Amount (₱) <span className="al-req">*</span></label>
                  <div className="al-amount-wrap">
                    <span className="al-peso">₱</span>
                    <input className="al-amount-in" type="number" name="amount" min="1" placeholder="Min ₱3,000"
                      value={form.amount} onChange={e => { handle(e); setErrors(p=>({...p,amount:""})); }} />
                  </div>
                  {errors.amount && <div className="al-error" style={{marginTop:4}}>{errors.amount}</div>}
                </div>
                <div className="al-field">
                  <label className="al-label">Term (months)</label>
                  <select className="al-input" name="term" value={form.term} onChange={handle}>
                    {[3,6,9,12,18,24,36,48].filter(t => t <= (MAX_TERM[form.loanType]||24)).map(t => (
                      <option key={t} value={t}>{t} months</option>
                    ))}
                  </select>
                </div>
                <div className="al-field al-full">
                  <label className="al-label">Purpose <span className="al-req">*</span></label>
                  <textarea className={`al-input ${errors.purpose?"border-red":""}`} name="purpose" rows={2}
                    placeholder="Reason for the loan..." value={form.purpose}
                    onChange={e => { handle(e); setErrors(p=>({...p,purpose:""})); }} style={{resize:"none"}} />
                  {errors.purpose && <div className="al-error" style={{marginTop:4}}>{errors.purpose}</div>}
                </div>
                <div className="al-field al-full">
                  <label className="al-label">Collateral (optional)</label>
                  <input className="al-input" name="collateral" placeholder="e.g. Land title, vehicle" value={form.collateral} onChange={handle} />
                </div>
              </div>

              {amount >= 3000 && (
                <div style={{marginTop:12}}>
                  <div style={{display:"flex",alignItems:"center",justifyContent:"space-between",marginBottom:6}}>
                    <div className="al-deduct-title" style={{margin:0}}>🧮 Loan Computation (LEAF MPC)</div>
                    <button type="button" onClick={() => setShowRateEdit(p=>!p)} style={{
                      fontSize:11,fontWeight:600,padding:"3px 10px",
                      background:showRateEdit?"#fff3e0":"#f5f5f5",
                      color:showRateEdit?"#e65100":"#888",
                      border:`1px solid ${showRateEdit?"#ffcc80":"#e0e0e0"}`,
                      borderRadius:20,cursor:"pointer",
                    }}>
                      {showRateEdit ? "✓ Done Editing" : "✏ Edit Rates"}
                    </button>
                  </div>
                  {showRateEdit && (
                    <div style={{background:"#fff8e1",border:"1px solid #ffe082",borderRadius:10,padding:"12px 14px",marginBottom:10}}>
                      <div style={{fontSize:11,fontWeight:700,color:"#f57f17",marginBottom:10}}>⚙ Customize Rates</div>
                      <div style={{display:"grid",gridTemplateColumns:"1fr 1fr",gap:10}}>
                        {[
                          ["Service Fee","serviceFeePct","%"],["Insurance","insurancePct","%"],
                          ["Savings Deposit","sdPct","%"],["Share Cap CBU","scPct","%"],
                          ["Filing Fee","filingFeeAmt","₱ (flat)"],
                        ].map(([label, key, unit]) => (
                          <div key={key}>
                            <div style={{fontSize:10,color:"#888",fontWeight:600,marginBottom:3}}>{label} ({unit})</div>
                            <div style={{display:"flex",alignItems:"center",gap:4,background:"#fff",border:"1px solid #ffe082",borderRadius:8,padding:"4px 8px"}}>
                              <input type="number" step="0.01" min="0" max={unit==="₱ (flat)"?9999:100}
                                value={rates[key]} onChange={e => setRates(p=>({...p,[key]:parseFloat(e.target.value)||0}))}
                                style={{border:"none",outline:"none",width:"100%",fontSize:12,fontWeight:700,color:"#333"}}/>
                              <span style={{fontSize:10,color:"#aaa",flexShrink:0}}>{unit==="₱ (flat)"?"₱":"%"}</span>
                            </div>
                          </div>
                        ))}
                        <div>
                          <div style={{fontSize:10,color:"#888",fontWeight:600,marginBottom:3}}>Interest Rate Override (%/mo)</div>
                          <div style={{display:"flex",alignItems:"center",gap:4,background:"#fff",border:"1px solid #ffe082",borderRadius:8,padding:"4px 8px"}}>
                            <input type="number" step="0.001" min="0" max="100"
                              value={rates.interestOverride} onChange={e => setRates(p=>({...p,interestOverride:parseFloat(e.target.value)||0}))}
                              style={{border:"none",outline:"none",width:"100%",fontSize:12,fontWeight:700,color:"#333"}}/>
                            <span style={{fontSize:10,color:"#aaa"}}>%</span>
                          </div>
                          <div style={{fontSize:9,color:"#bbb",marginTop:2}}>0 = use default tiered rate</div>
                        </div>
                      </div>
                      <button type="button" onClick={() => setRates({serviceFeePct:3,insurancePct:1.25,sdPct:1,scPct:3,filingFeeAmt:amount<=50000?50:100,interestOverride:0})}
                        style={{marginTop:10,fontSize:10,color:"#c62828",background:"none",border:"none",cursor:"pointer",textDecoration:"underline"}}>
                        ↺ Reset to defaults
                      </button>
                    </div>
                  )}
                  <div className="al-deduct-box">
                    <div className="al-deduct-row"><span className="al-deduct-label">Loan Amount</span><span className="al-deduct-val">₱{amount.toLocaleString()}</span></div>
                    <div className="al-deduct-row"><span className="al-deduct-label">Interest Rate</span><span className="al-deduct-val">{(effectiveRate*100).toFixed(3)}%/mo × {term} months{rates.interestOverride>0?" (custom)":""}</span></div>
                    <div className="al-deduct-row"><span className="al-deduct-label">Monthly Amortization</span><span className="al-deduct-val" style={{color:"#2e7d32",fontWeight:700}}>₱{parseFloat(monthly).toLocaleString(undefined,{minimumFractionDigits:2})}</span></div>
                    <div className="al-deduct-divider"/>
                    <div style={{fontSize:11,fontWeight:600,color:"#555",margin:"4px 0 4px"}}>Upfront Deductions from Loan Release:</div>
                    <div className="al-deduct-row"><span className="al-deduct-label">Interest</span><span className="al-deduct-val al-deduct-red">− ₱{interest.toFixed(2)}</span></div>
                    <div className="al-deduct-row"><span className="al-deduct-label">Service Fee ({rates.serviceFeePct}%)</span><span className="al-deduct-val al-deduct-red">− ₱{serviceFee.toFixed(2)}</span></div>
                    <div className="al-deduct-row"><span className="al-deduct-label">Filing Fee (₱{rates.filingFeeAmt})</span><span className="al-deduct-val al-deduct-red">− ₱{filingFee.toFixed(2)}</span></div>
                    <div className="al-deduct-row"><span className="al-deduct-label">Insurance ({rates.insurancePct}%)</span><span className="al-deduct-val al-deduct-red">− ₱{insurance.toFixed(2)}</span></div>
                    <div className="al-deduct-row"><span className="al-deduct-label">Savings Deposit ({rates.sdPct}%)</span><span className="al-deduct-val al-deduct-red">− ₱{sd.toFixed(2)}</span></div>
                    <div className="al-deduct-row"><span className="al-deduct-label">Share Capital CBU ({rates.scPct}%)</span><span className="al-deduct-val al-deduct-red">− ₱{sc.toFixed(2)}</span></div>
                    <div className="al-deduct-divider"/>
                    <div className="al-deduct-row al-deduct-net"><span className="al-deduct-label">Net Proceeds</span><span className="al-net-val">₱{netProceeds.toFixed(2)}</span></div>
                  </div>
                  <div className="al-deduct-notice">
                    💡 Member will receive <strong>₱{netProceeds.toFixed(2)}</strong> after all deductions.
                  </div>
                </div>
              )}
            </div>
            <div className="al-modal-footer">
              <button className="al-btn-cancel" onClick={() => setStep(1)}>← Back</button>
              <button className="al-btn-save" onClick={() => setShowConfirm(true)}>Submit Application</button>
            </div>
          </>
        )}
      </div>
    </div>
  );
}


// ─── Share Capital Deposit Modal ──────────────────────────────────────────────
function ShareCapitalModal({ onClose }) {
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

  useEffect(() => {
    getMembersAPI()
      .then(data => setMembers(data))
      .catch(e => console.error(e))
      .finally(() => setFetch(false));
  }, []);

  useEffect(() => {
    if (mainTab !== "history") return;
    setHistLoading(true);
    import("../api/axiosInstance").then(({ default: api }) =>
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

  const totalDeposits = allHistory.reduce((s,t) => s + t.amount, 0);

  const parsed   = parseFloat(amount) || 0;
  const isValid  = parsed > 0 && selected;
  const newSC    = parseFloat(selected?.share_capital || 0) + parsed;
  const newMaxLoan = newSC * 2;

  const handleSave = async () => {
    if (!parsed || parsed <= 0) { setError("Enter a valid amount."); return; }
    setLoad(true);
    try {
      await import("../api/axiosInstance").then(({ default: api }) =>
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

  if (done) return (
    <div className="al-overlay" onClick={onClose}>
      <div className="al-modal al-modal-sm" onClick={e => e.stopPropagation()}>
        <div className="al-modal-body" style={{alignItems:"center",textAlign:"center",padding:"32px 24px",gap:12}}>
          <div style={{fontSize:40}}>💰</div>
          <div style={{fontSize:15,fontWeight:700,color:"#1565c0"}}>Share Capital Deposit Recorded!</div>
          <div style={{fontSize:12,color:"#888"}}>
            ₱{parsed.toLocaleString()} deposited for <strong>{selected.fullname}</strong>.<br/>
            New Share Capital: <strong style={{color:"#1565c0"}}>₱{newSC.toLocaleString()}</strong><br/>
            New Max Loanable: <strong style={{color:"#2e7d32"}}>₱{newMaxLoan.toLocaleString()}</strong>
          </div>
        </div>
        <div className="al-modal-footer">
          <button className="al-btn-save" style={{background:"#1565c0",borderColor:"#1565c0"}} onClick={onClose}>Done</button>
        </div>
      </div>
    </div>
  );

  return (
    <div className="al-overlay" onClick={onClose}>
      <div className="al-modal" onClick={e => e.stopPropagation()}>
        <div className="al-modal-header">
          <div>
            <div className="al-modal-title">💰 Share Capital</div>
            <div className="al-modal-sub">
              {mainTab==="new"
                ? `Step ${step} of 2 — ${step===1?"Select Member":"Deposit Details"}`
                : "Share capital transaction history"}
            </div>
          </div>
          <button className="al-modal-close" onClick={onClose}>✕</button>
        </div>

        {/* Tabs */}
        <div style={{display:"flex",borderBottom:"2px solid #f0f0f0",flexShrink:0}}>
          {[
            {key:"new",     label:"💰 New Deposit"},
            {key:"history", label:`📋 History${allHistory.length > 0 ? " ("+allHistory.length+")" : ""}`},
          ].map(t => (
            <button key={t.key} onClick={() => { setMainTab(t.key); setDone(false); setStep(1); }} style={{
              flex:1, padding:"10px 8px", fontSize:12, fontWeight:600, cursor:"pointer",
              border:"none", background:"none",
              color: mainTab===t.key ? "#1565c0" : "#aaa",
              borderBottom: mainTab===t.key ? "2px solid #1565c0" : "2px solid transparent",
              marginBottom:-2, transition:"all 0.15s",
            }}>{t.label}</button>
          ))}
        </div>

        {mainTab === "new" && step === 1 && (<>
          <div className="al-modal-body">
            <div className="al-step-info">Select the member to record share capital deposit.</div>
            <div className="al-search-wrap">
              <span>🔍</span>
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
          </div>
          <div className="al-modal-footer">
            <button className="al-btn-cancel" onClick={onClose}>Cancel</button>
            <button className="al-btn-save" style={{background:"#1565c0",borderColor:"#1565c0"}}
              onClick={() => setStep(2)} disabled={!selected}>Next →</button>
          </div>
        </>)}

        {mainTab === "new" && step === 2 && (<>
          <div className="al-modal-body">
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
            {error && <div className="al-error">⚠ {error}</div>}
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
          </div>
          <div className="al-modal-footer">
            <button className="al-btn-cancel" onClick={() => setStep(1)}>← Back</button>
            <button className="al-btn-save" style={{background:"#1565c0",borderColor:"#1565c0"}}
              onClick={handleSave} disabled={!isValid||loading}>
              {loading?"Saving...":"💰 Record Deposit"}
            </button>
          </div>
        </>)}

        {/* History Tab */}
        {mainTab === "history" && (<>
          <div className="al-modal-body" style={{gap:10}}>
            <div style={{display:"grid",gridTemplateColumns:"repeat(2,1fr)",gap:8}}>
              <div style={{background:"#e3f2fd",borderRadius:8,padding:"10px 12px",textAlign:"center"}}>
                <div style={{fontSize:10,color:"#1565c0",fontWeight:600}}>Total Deposited</div>
                <div style={{fontSize:15,fontWeight:800,color:"#0d47a1"}}>₱{totalDeposits.toLocaleString()}</div>
              </div>
              <div style={{background:"#e8f5e9",borderRadius:8,padding:"10px 12px",textAlign:"center"}}>
                <div style={{fontSize:10,color:"#2e7d32",fontWeight:600}}>Transactions</div>
                <div style={{fontSize:15,fontWeight:800,color:"#1b5e20"}}>{allHistory.length}</div>
              </div>
            </div>
            <div className="al-search-wrap">
              <span>🔍</span>
              <input className="al-search-in" placeholder="Search by member name or ID..."
                value={histSearch} onChange={e => setHistSearch(e.target.value)}/>
            </div>
            {histLoading ? (
              <div style={{textAlign:"center",padding:24,color:"#aaa",fontSize:13}}>Loading history...</div>
            ) : filteredHist.length === 0 ? (
              <div style={{textAlign:"center",padding:24,color:"#bbb",fontSize:13}}>No share capital transactions found.</div>
            ) : (
              <div style={{borderRadius:8,overflow:"hidden",border:"1px solid #90caf9",maxHeight:320,overflowY:"auto"}}>
                <table style={{width:"100%",borderCollapse:"collapse",fontSize:12}}>
                  <thead style={{position:"sticky",top:0,zIndex:1}}>
                    <tr style={{background:"#e3f2fd"}}>
                      <th style={{padding:"8px 10px",textAlign:"left",fontWeight:600,color:"#777",fontSize:10}}>Date</th>
                      <th style={{padding:"8px 10px",textAlign:"left",fontWeight:600,color:"#777",fontSize:10}}>Member</th>
                      <th style={{padding:"8px 10px",textAlign:"left",fontWeight:600,color:"#777",fontSize:10}}>Type</th>
                      <th style={{padding:"8px 10px",textAlign:"right",fontWeight:600,color:"#777",fontSize:10}}>Amount</th>
                      <th style={{padding:"8px 10px",textAlign:"right",fontWeight:600,color:"#777",fontSize:10}}>Balance After</th>
                      <th style={{padding:"8px 10px",textAlign:"left",fontWeight:600,color:"#777",fontSize:10}}>Note</th>
                      <th style={{padding:"8px 10px",textAlign:"left",fontWeight:600,color:"#777",fontSize:10}}>By</th>
                    </tr>
                  </thead>
                  <tbody>
                    {filteredHist.map((t, idx) => (
                      <tr key={t.id} style={{background:idx%2===0?"#fff":"#e3f2fd22",borderTop:"1px solid #f5f5f5"}}>
                        <td style={{padding:"7px 10px",color:"#888",fontSize:10,whiteSpace:"nowrap"}}>{t.created_at}</td>
                        <td style={{padding:"7px 10px"}}>
                          <div style={{fontWeight:600,fontSize:11,color:"#222"}}>{t.member_name}</div>
                          <div style={{fontSize:9,color:"#aaa",fontFamily:"monospace"}}>{t.member_id}</div>
                        </td>
                        <td style={{padding:"7px 10px"}}>
                          <span style={{
                            background: t.txn_type==="CBU"?"#e8f5e9":t.txn_type==="Initial"?"#fff8e1":"#e3f2fd",
                            color: t.txn_type==="CBU"?"#2e7d32":t.txn_type==="Initial"?"#f57f17":"#1565c0",
                            padding:"2px 7px",borderRadius:20,fontSize:10,fontWeight:700,
                          }}>
                            {t.txn_type==="CBU"?"📈 CBU":t.txn_type==="Initial"?"🌱 Initial":"💰 Deposit"}
                          </span>
                        </td>
                        <td style={{padding:"7px 10px",textAlign:"right",fontWeight:700,color:"#1565c0"}}>
                          +₱{Number(t.amount).toLocaleString()}
                        </td>
                        <td style={{padding:"7px 10px",textAlign:"right",fontWeight:600,color:"#0d47a1"}}>
                          ₱{Number(t.balance_after).toLocaleString()}
                        </td>
                        <td style={{padding:"7px 10px",color:"#888",fontSize:10}}>{t.note||"—"}</td>
                        <td style={{padding:"7px 10px",color:"#888",fontSize:10}}>{t.recorded_by||"—"}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </div>
          <div className="al-modal-footer">
            <button className="al-btn-cancel" onClick={onClose}>Close</button>
          </div>
        </>)}

      </div>
    </div>
  );
}

// ─── Main Layout ──────────────────────────────────────────────────────────────
export default function AdminLayout() {
  const [clock,       setClock]   = useState("");
  const [showF2F,     setF2F]     = useState(false);
  const [showReg,     setReg]     = useState(false);
  const [showLoan,    setLoan]    = useState(false);
  const [showSavings, setShowSav]    = useState(false);
  const [showShareCap,  setShareCap]     = useState(false);
  const [sidebarOpen,   setSidebar]      = useState(false);
  const [gcashPending,  setGcashPending] = useState(0);
  const navigate                  = useNavigate();
  const location                  = useLocation();
  const { logout, user }          = useAuth();

  useEffect(() => { setSidebar(false); }, [location.pathname]);

  const config = PAGE_CONFIG[location.pathname] || DEFAULT_CONFIG;

  useEffect(() => {
    const tick = () => {
      const now  = new Date();
      const days = ["SUN","MON","TUE","WED","THU","FRI","SAT"];
      const mons = ["JAN","FEB","MAR","APR","MAY","JUN","JUL","AUG","SEP","OCT","NOV","DEC"];
      const pad  = n => String(n).padStart(2, "0");
      setClock(`${days[now.getDay()]} ${mons[now.getMonth()]} ${now.getDate()}, ${now.getFullYear()} — ${pad(now.getHours())}:${pad(now.getMinutes())}:${pad(now.getSeconds())}`);
    };
    tick();
    const id = setInterval(tick, 1000);
    return () => clearInterval(id);
  }, []);

  useEffect(() => {
    const fetchCount = () => {
      getGCashRequestsAPI({ status:"Pending" })
        .then(d => setGcashPending(Array.isArray(d) ? d.length : 0))
        .catch(() => {});
    };
    fetchCount();
    const id = setInterval(fetchCount, 30000);
    return () => clearInterval(id);
  }, []);

  const handleAction = (action) => {
    if (action === "f2f")      setF2F(true);
    if (action === "register") setReg(true);
    if (action === "newloan")  setLoan(true);
    if (action === "savings")   setShowSav(true);
    if (action === "sharecap")  setShareCap(true);
    if (action === "export")   alert("Export feature will be connected to the backend.");
  };

  const handleLogout = () => { logout(); navigate("/login"); };

  return (
    <div className="admin-layout">
      {showF2F     && <F2FModal      onClose={() => setF2F(false)}     />}
      {showReg     && <RegisterModal onClose={() => setReg(false)}     />}
      {showLoan    && <NewLoanModal  onClose={() => setLoan(false)}    />}
      {showSavings  && <SavingsModal       onClose={() => setShowSav(false)}   />}
      {showShareCap && <ShareCapitalModal onClose={() => setShareCap(false)} />}

      <div className={`sidebar-overlay ${sidebarOpen ? "open" : ""}`} onClick={() => setSidebar(false)} />

      <aside className={`sidebar ${sidebarOpen ? "open" : ""}`}>
        <div className="sidebar-logo">
          <div className="logo-icon">
            <img src={logo} alt="LEAF MPC Logo" style={{ height: "35px", width: "300px", objectFit: "contain" }} />
          </div>
        </div>
        <nav className="sidebar-nav">
          {NAV_ITEMS.map(item => (
            <NavLink key={item.to} to={item.to} className={({ isActive }) => "nav-item" + (isActive ? " active" : "")}>
            <span className="nav-icon">{item.icon}</span>
            {item.label}
            {item.to === "/admin/gcash-verification" && gcashPending > 0 && (
            <span style={{marginLeft:"auto",background:"#c62828",color:"#fff",borderRadius:20,padding:"1px 7px",fontSize:10,fontWeight:800}}>
            {gcashPending}
            </span>
            )}
            </NavLink>
          ))}
        </nav>
        <div className="sidebar-bottom">
          <div className="clock-display">{clock}</div>
          <button className="logout-btn" onClick={handleLogout}>LOGOUT</button>
        </div>
      </aside>

      <div className="admin-main">
        <header className="topbar">
          <button className={`hamburger ${sidebarOpen ? "open" : ""}`} onClick={() => setSidebar(s => !s)} aria-label="Toggle menu">
            <span /><span /><span />
          </button>
          <div className="topbar-left">
            <div className="topbar-brand">ADMIN</div>
          </div>
          <div className="topbar-right">
            {config.actions.map((action, i) => (
              <button key={i}
                className={action.cls !== "btn-savings" && action.cls !== "btn-sharecap" ? `btn ${action.cls}` : "btn"}
                style={
                  action.cls === "btn-savings"  ? { background:"#f57f17", borderColor:"#f57f17", color:"#fff" } :
                  action.cls === "btn-sharecap" ? { background:"#1565c0", borderColor:"#1565c0", color:"#fff" } :
                  {}
                }
                onClick={() => handleAction(action.action)}>
                {action.label}
              </button>
            ))}
            <div className="user-chip">
              <div className="user-avatar">{user?.initials?.[0] || "A"}</div>
              <div>
                <span className="user-name">{user?.name || "Admin"}</span>
                <span className="user-role">Admin</span>
              </div>
            </div>
          </div>
        </header>
        <main className="page-content">
          <Outlet />
        </main>
      </div>
    </div>
  );
}