import { useState, useEffect } from "react";
import { getLoansAPI, getGCashRequestsAPI } from "../../api/loans";
import { getPaymentsAPI } from "../../api/payments";
import { useOutletContext } from "react-router-dom";
import {
  Eye, X, Smartphone, CreditCard, ClipboardList,
  Receipt, ChevronDown, ChevronUp, CheckCircle2,
  AlertTriangle, Clock, FileText,
} from "lucide-react";
import GCashPayment from "./GCashPayment";
import "./MyLoans.css";

// ─── Receipt Modal ─────────────────────────────────────────────────────────────
function ReceiptModal({ payment, onClose }) {
  if (!payment) return null;
  const isOnBlockchain = payment.polygon_tx && payment.network === "polygon";
  const rows = [
    ["Transaction ID", payment.tx_id],
    ["Date & Time",    payment.paid_at],
    ["Loan ID",        payment.loan_code],
    ["Amount Paid",    `₱${Number(payment.amount||0).toLocaleString()}`],
    ["Balance After",  `₱${Number(payment.balance||0).toLocaleString()}`],
    ["Note",           payment.note || "—"],
    ["Recorded By",    payment.recorded_by || "—"],
    ["SHA-256 Hash",   payment.hash || "—"],
    ["Blockchain",     isOnBlockchain ? "Polygon Mainnet" : "Local only"],
    ["Polygon TX",     payment.polygon_tx || "—"],
  ];
  return (
    <div style={{position:"fixed",inset:0,background:"rgba(0,0,0,0.5)",zIndex:9999,display:"flex",alignItems:"center",justifyContent:"center",padding:16}} onClick={onClose}>
      <div style={{background:"#fff",borderRadius:16,width:"100%",maxWidth:460,boxShadow:"0 8px 32px rgba(0,0,0,0.18)"}} onClick={e=>e.stopPropagation()}>
        <div style={{padding:"18px 24px",borderBottom:"1px solid #e8f5e9",display:"flex",justifyContent:"space-between",alignItems:"center"}}>
          <div>
            <div style={{fontWeight:800,fontSize:15,color:"#1b5e20",display:"flex",alignItems:"center",gap:8}}>
              <Receipt size={16} color="#1b5e20"/> Transaction Receipt
            </div>
            <div style={{fontSize:11,color:"#aaa",fontFamily:"monospace",marginTop:2}}>{payment.tx_id}</div>
          </div>
          <button onClick={onClose} style={{background:"none",border:"none",cursor:"pointer",color:"#888",padding:4}}><X size={18}/></button>
        </div>
        <div style={{padding:"16px 24px",display:"flex",flexDirection:"column",gap:0}}>
          <div style={{marginBottom:12}}>
            <div style={{fontSize:10,fontWeight:700,color:"#2e7d32",textTransform:"uppercase",letterSpacing:1,marginBottom:8}}>Member Information</div>
            {rows.slice(0,3).map(([k,v]) => (
              <div key={k} style={{display:"flex",justifyContent:"space-between",padding:"7px 0",borderBottom:"1px solid #f5f5f5"}}>
                <span style={{fontSize:12,color:"#888",fontWeight:600}}>{k}</span>
                <span style={{fontSize:12,color:"#333",fontWeight:400,fontFamily:k==="Transaction ID"?"monospace":"inherit"}}>{v}</span>
              </div>
            ))}
          </div>
          <div style={{marginBottom:12}}>
            <div style={{fontSize:10,fontWeight:700,color:"#2e7d32",textTransform:"uppercase",letterSpacing:1,marginBottom:8}}>Payment Details</div>
            {rows.slice(3,7).map(([k,v]) => (
              <div key={k} style={{display:"flex",justifyContent:"space-between",padding:"7px 0",borderBottom:"1px solid #f5f5f5"}}>
                <span style={{fontSize:12,color:"#888",fontWeight:600}}>{k}</span>
                <span style={{fontSize:12,fontWeight:k==="Amount Paid"?800:400,color:k==="Amount Paid"?"#2e7d32":"#333"}}>{v}</span>
              </div>
            ))}
          </div>
          <div>
            <div style={{fontSize:10,fontWeight:700,color:"#2e7d32",textTransform:"uppercase",letterSpacing:1,marginBottom:8}}>Verification</div>
            {rows.slice(7).map(([k,v]) => (
              <div key={k} style={{display:"flex",justifyContent:"space-between",alignItems:"flex-start",gap:12,padding:"7px 0",borderBottom:"1px solid #f5f5f5"}}>
                <span style={{fontSize:12,color:"#888",fontWeight:600,flexShrink:0}}>{k}</span>
                <span style={{fontSize:11,color:k==="Blockchain"?(isOnBlockchain?"#2e7d32":"#f57c00"):"#555",fontFamily:k==="SHA-256 Hash"||k==="Polygon TX"?"monospace":"inherit",wordBreak:"break-all",textAlign:"right",fontWeight:k==="Blockchain"?700:400}}>{v}</span>
              </div>
            ))}
            {payment.polygon_tx && (
              <a href={`https://polygonscan.com/tx/${payment.polygon_tx}`} target="_blank" rel="noopener noreferrer"
                style={{display:"flex",alignItems:"center",justifyContent:"center",gap:6,color:"#7c3aed",fontWeight:600,fontSize:12,marginTop:10,padding:"8px",background:"#f3e5f5",borderRadius:8,textDecoration:"none"}}>
                View on Polygonscan
              </a>
            )}
          </div>
        </div>
        <div style={{padding:"14px 24px",borderTop:"1px solid #f0f0f0",display:"flex",gap:8,justifyContent:"flex-end"}}>
          <button onClick={onClose} style={{padding:"9px 20px",background:"#f5f5f5",border:"none",borderRadius:8,cursor:"pointer",fontSize:13,fontWeight:600,fontFamily:"inherit"}}>Close</button>
          <button onClick={()=>window.print()} style={{padding:"9px 20px",background:"#2e7d32",color:"#fff",border:"none",borderRadius:8,cursor:"pointer",fontSize:13,fontWeight:600,fontFamily:"inherit",display:"flex",alignItems:"center",gap:6}}>
            Print
          </button>
        </div>
      </div>
    </div>
  );
}

export default function MyLoans() {
  const ctx    = useOutletContext() || {};
  const [loans,         setLoans]      = useState([]);
  const [allLoans,      setAllLoans]   = useState([]);
  const [payments,      setPayments]   = useState([]);
  const [selectedLoan,  setSelected]   = useState(null);
  const [tab,           setTab]        = useState("details");
  const [mainTab,       setMainTab]    = useState("active");
  const [loading,       setLoading]    = useState(true);
  const [receipt,       setReceipt]    = useState(null);
  const [expandedLoan,  setExpanded]   = useState(null);
  const [gcashLoan,     setGcashLoan]  = useState(null);
  const [gcashRequests, setGcashReqs]  = useState([]);

  useEffect(() => {
    Promise.allSettled([
      getLoansAPI(),
      getLoansAPI({ status: "Completed" }),
      getPaymentsAPI(),
      getGCashRequestsAPI(),
    ]).then(([l, lc, p, gcash]) => {
      const active    = l.status    === "fulfilled" ? l.value    : [];
      const completed = lc.status   === "fulfilled" ? lc.value   : [];
      const activeFiltered = active.filter(loan => loan.status === "Active" || loan.status === "Overdue");
      setLoans(activeFiltered);
      setAllLoans([...activeFiltered, ...completed].sort((a,b) => b.id - a.id));
      if (activeFiltered.length > 0) setSelected(activeFiltered[0]);
      if (p.status     === "fulfilled") setPayments(p.value);
      if (gcash.status === "fulfilled") setGcashReqs(Array.isArray(gcash.value) ? gcash.value : []);
    }).finally(() => setLoading(false));
  }, []);

  const hasPendingGCash = (loanId) =>
    gcashRequests.some(r => r.loan_id === loanId && r.status === "Pending");

  if (loading) return (
    <div style={{textAlign:"center",padding:"80px",color:"#aaa",display:"flex",flexDirection:"column",alignItems:"center",gap:12}}>
      <Clock size={32} color="#c8e6c9"/>
      <div style={{fontSize:14,fontWeight:600}}>Loading loans...</div>
    </div>
  );

  const principal  = parseFloat(selectedLoan?.amount || 0);
  const balance    = parseFloat(selectedLoan?.balance || 0);
  const totalPaid  = principal - balance;
  const monthlyDue = parseFloat(selectedLoan?.monthly_due || 0);
  const paidPct    = principal > 0 ? Math.round((totalPaid / principal) * 100) : 0;

  const statusColor = { Active:"#2e7d32", Overdue:"#c62828", Completed:"#1565c0", Declined:"#757575" };
  const statusBg    = { Active:"#e8f5e9", Overdue:"#ffebee", Completed:"#e3f2fd", Declined:"#f5f5f5" };

  const MAIN_TABS = [
    { key:"active",  label:"Active Loans",  icon:<CreditCard   size={14}/>, count:loans.length    },
    { key:"history", label:"Loan History",  icon:<ClipboardList size={14}/>, count:allLoans.length },
    { key:"all",     label:"All Payments",  icon:<Receipt       size={14}/>, count:payments.length },
  ];

  return (
    <div className="ml-wrapper">
      <ReceiptModal payment={receipt} onClose={() => setReceipt(null)}/>

      {gcashLoan && (
        <GCashPayment
          loan={gcashLoan}
          onClose={() => setGcashLoan(null)}
          onSuccess={(res) => {
            setGcashLoan(null);
            setGcashReqs(prev => [...prev, { ...res, loan_id: gcashLoan.loan_id, status:"Pending" }]);
          }}
        />
      )}

      {/* Page Header */}
      <div className="ml-page-header">
        <div className="ml-page-title">My Loans</div>
        <div className="ml-page-sub">View your loans, payment history, and receipts.</div>
      </div>

      {/* Main Tabs */}
      <div style={{display:"flex",gap:0,background:"#fff",borderRadius:12,border:"1px solid #e8f5e9",marginBottom:20,overflow:"hidden"}}>
        {MAIN_TABS.map(t => (
          <button key={t.key} onClick={() => setMainTab(t.key)} style={{
            flex:1,padding:"13px 10px",fontSize:13,fontWeight:600,cursor:"pointer",
            border:"none",
            background:mainTab===t.key?"#1b5e20":"transparent",
            color:mainTab===t.key?"#fff":"#888",
            display:"flex",alignItems:"center",justifyContent:"center",gap:7,
            transition:"all 0.15s",fontFamily:"inherit",
          }}>
            {t.icon}
            {t.label}
            <span style={{
              background:mainTab===t.key?"rgba(255,255,255,0.2)":"#f0f0f0",
              color:mainTab===t.key?"#fff":"#aaa",
              borderRadius:10,padding:"1px 7px",fontSize:11,fontWeight:700,
            }}>{t.count}</span>
          </button>
        ))}
      </div>

      {/* ══ ACTIVE LOANS ══════════════════════════════════════════════════════ */}
      {mainTab === "active" && (<>
        {loans.length === 0 ? (
          <div style={{textAlign:"center",padding:"60px 20px",background:"#fff",borderRadius:14,border:"1px solid #e8f5e9",display:"flex",flexDirection:"column",alignItems:"center",gap:12}}>
            <FileText size={40} color="#c8e6c9"/>
            <div style={{fontWeight:700,fontSize:15,color:"#555"}}>No active loans</div>
            <div style={{fontSize:13,color:"#aaa"}}>You have no active loan records at the moment.</div>
          </div>
        ) : (<>
          {/* Loan selector cards */}
          <div className="ml-loan-cards">
            {loans.map(loan => {
              const lp  = parseFloat(loan.amount || 0);
              const lb  = parseFloat(loan.balance || 0);
              const pct = lp > 0 ? Math.round(((lp - lb) / lp) * 100) : 0;
              const pending = hasPendingGCash(loan.loan_id);
              return (
                <div key={loan.loan_id} className={`ml-loan-card ${selectedLoan?.loan_id === loan.loan_id ? "selected" : ""}`}
                  onClick={() => { setSelected(loan); setTab("details"); }}>
                  <div className="ml-lc-header">
                    <span className="ml-lc-type">{loan.loan_type}</span>
                    <span className={`ml-lc-status ${(loan.status||"").toLowerCase()}`}>{loan.status}</span>
                  </div>
                  <div className="ml-lc-id">{loan.loan_id}</div>
                  <div className="ml-lc-balance">₱{Number(loan.balance).toLocaleString()}</div>
                  <div className="ml-lc-label">remaining balance</div>
                  <div className="ml-lc-bar"><div className="ml-lc-fill" style={{width:pct+"%"}}/></div>
                  <div className="ml-lc-pct">{pct}% paid</div>
                  <button
                    onClick={e => { e.stopPropagation(); setGcashLoan(loan); }}
                    disabled={pending}
                    style={{
                      marginTop:10,width:"100%",padding:"9px",borderRadius:8,
                      cursor:pending?"default":"pointer",border:"none",
                      fontWeight:700,fontSize:12,fontFamily:"inherit",
                      display:"flex",alignItems:"center",justifyContent:"center",gap:6,
                      background:pending?"#f5f5f5":"#1976d2",
                      color:pending?"#aaa":"#fff",transition:"all 0.15s",
                    }}
                  >
                    <Smartphone size={13}/>
                    {pending ? "GCash Pending Verification" : "Pay via GCash"}
                  </button>
                </div>
              );
            })}
          </div>

          {/* GCash pending notice */}
          {gcashRequests.filter(r=>r.status==="Pending").length > 0 && (
            <div style={{background:"#fff8e1",border:"1px solid #ffe082",borderRadius:10,padding:"14px 18px",display:"flex",alignItems:"center",gap:10,fontSize:13,color:"#f57c00",fontWeight:600,marginBottom:4}}>
              <AlertTriangle size={16} color="#f57c00"/>
              You have {gcashRequests.filter(r=>r.status==="Pending").length} GCash payment request(s) pending admin verification. You will be notified once verified.
            </div>
          )}

          {/* Detail card */}
          <div className="ml-detail-card">
            <div className="ml-tabs">
              {[
                {key:"details",  label:"Loan Details"},
                {key:"payments", label:"Payment History"},
                {key:"schedule", label:"Amortization"},
              ].map(t => (
                <button key={t.key} className={`ml-tab ${tab === t.key ? "active" : ""}`} onClick={() => setTab(t.key)}>
                  {t.label}
                </button>
              ))}
            </div>

            {/* Details */}
            {tab === "details" && (
              <div style={{padding:"20px 24px"}}>
                <div style={{display:"grid",gridTemplateColumns:"repeat(2,1fr)",gap:0,borderRadius:10,overflow:"hidden",border:"1px solid #e8f5e9"}}>
                  {[
                    ["Loan ID",      selectedLoan?.loan_id],
                    ["Loan Type",    selectedLoan?.loan_type],
                    ["Principal",    `₱${principal.toLocaleString()}`],
                    ["Remaining",    `₱${balance.toLocaleString()}`],
                    ["Total Paid",   `₱${totalPaid.toLocaleString()}`],
                    ["Monthly Due",  `₱${monthlyDue.toLocaleString()}`],
                    ["Term",         `${selectedLoan?.term_months} months`],
                    ["Release Date", selectedLoan?.approved_at?.slice(0,10)||"—"],
                    ["Next Due",     selectedLoan?.next_due_date||"—"],
                    ["Status",       selectedLoan?.status],
                  ].map(([k,v],i) => (
                    <div key={k} style={{
                      padding:"13px 18px",
                      background:i%4<2?"#fff":"#f9fef9",
                      borderBottom:"1px solid #e8f5e9",
                      borderRight:i%2===0?"1px solid #e8f5e9":"none",
                      display:"flex",flexDirection:"column",gap:3,
                    }}>
                      <span style={{fontSize:10,fontWeight:700,color:"#aaa",textTransform:"uppercase",letterSpacing:0.5}}>{k}</span>
                      <span style={{fontSize:14,fontWeight:700,color:k==="Remaining"?"#c62828":k==="Total Paid"?"#2e7d32":"#1a1a1a"}}>{v}</span>
                    </div>
                  ))}
                </div>
                {/* Progress bar */}
                <div style={{marginTop:16,background:"#f5f5f5",borderRadius:20,height:10,overflow:"hidden"}}>
                  <div style={{width:paidPct+"%",height:"100%",background:"#2e7d32",borderRadius:20,transition:"width 0.5s"}}/>
                </div>
                <div style={{display:"flex",justifyContent:"space-between",marginTop:6,fontSize:11,color:"#888"}}>
                  <span>{paidPct}% paid</span>
                  <span>₱{balance.toLocaleString()} remaining</span>
                </div>
              </div>
            )}

            {/* Payments */}
            {tab === "payments" && (() => {
              const loanPayments = payments.filter(p => p.loan === selectedLoan?.id || String(p.loan_code) === String(selectedLoan?.loan_id));
              return (
                <div className="ml-payments-table-wrap">
                  <table className="ml-payments-table">
                    <thead>
                      <tr>
                        <th>Date</th><th>TX ID</th><th>Amount Paid</th>
                        <th>Balance After</th><th>Note</th><th style={{textAlign:"center"}}>Receipt</th>
                      </tr>
                    </thead>
                    <tbody>
                      {loanPayments.length === 0 ? (
                        <tr><td colSpan={6} style={{textAlign:"center",color:"#aaa",padding:24,fontSize:13}}>No payments yet.</td></tr>
                      ) : loanPayments.map((p, i) => (
                        <tr key={i}>
                          <td className="cell-date">{p.paid_at?.slice(0,10)}</td>
                          <td style={{fontFamily:"monospace",fontSize:10,color:"#888"}}>{p.tx_id}</td>
                          <td className="green fw">₱{Number(p.amount||0).toLocaleString()}</td>
                          <td className="blue">₱{Number(p.balance||0).toLocaleString()}</td>
                          <td style={{fontSize:11,color:"#888"}}>{p.note||"—"}</td>
                          <td style={{textAlign:"center"}}>
                            <button onClick={() => setReceipt(p)} style={{background:"#e8f5e9",border:"1px solid #a5d6a7",borderRadius:6,padding:"5px 12px",cursor:"pointer",fontSize:11,color:"#2e7d32",fontWeight:600,display:"flex",alignItems:"center",gap:4,margin:"0 auto"}}>
                              <Eye size={11}/> View
                            </button>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              );
            })()}

            {/* Amortization */}
            {tab === "schedule" && (
              <div className="ml-payments-table-wrap">
                <table className="ml-payments-table">
                  <thead><tr><th>#</th><th>Due Date</th><th>Amount</th><th>Status</th></tr></thead>
                  <tbody>
                    {(() => {
                      const loanPayments = payments.filter(p => p.loan === selectedLoan?.id);
                      const totalPaidAmt = loanPayments.reduce((s,p) => s + parseFloat(p.amount||0), 0);
                      const monthsPaid   = monthlyDue > 0 ? Math.floor(totalPaidAmt / monthlyDue) : 0;
                      return Array.from({ length: selectedLoan?.term_months || 0 }, (_, i) => {
                        const d = new Date(selectedLoan?.approved_at || selectedLoan?.applied_at || Date.now());
                        d.setMonth(d.getMonth() + i + 1);
                        const isPaid = i < monthsPaid;
                        return (
                          <tr key={i}>
                            <td className="cell-center">{i + 1}</td>
                            <td className="cell-date">{d.toISOString().slice(0,10)}</td>
                            <td className="fw">₱{monthlyDue.toLocaleString()}</td>
                            <td>
                              <span className={`ml-sched-badge ${isPaid?"paid":"upcoming"}`}>
                                {isPaid ? <><CheckCircle2 size={11}/> Paid</> : <><Clock size={11}/> Upcoming</>}
                              </span>
                            </td>
                          </tr>
                        );
                      });
                    })()}
                  </tbody>
                </table>
              </div>
            )}
          </div>
        </>)}
      </>)}

      {/* ══ LOAN HISTORY ══════════════════════════════════════════════════════ */}
      {mainTab === "history" && (
        <div style={{display:"flex",flexDirection:"column",gap:10}}>
          {allLoans.length === 0 ? (
            <div style={{textAlign:"center",padding:"40px",color:"#aaa",background:"#fff",borderRadius:12,border:"1px solid #e8f5e9"}}>No loan history yet.</div>
          ) : allLoans.map((loan, idx) => {
            const isExpanded   = expandedLoan === loan.loan_id;
            const isPaid       = loan.status === "Completed" || parseFloat(loan.balance||0) === 0;
            const sc           = isPaid ? "#1565c0" : (statusColor[loan.status]||"#555");
            const sb           = isPaid ? "#e3f2fd" : (statusBg[loan.status]||"#f5f5f5");
            const loanPayments = payments.filter(p => p.loan === loan.id || String(p.loan_code) === String(loan.loan_id));

            return (
              <div key={loan.loan_id} style={{borderRadius:12,border:`1.5px solid ${isExpanded?"#a5d6a7":"#e8f5e9"}`,overflow:"hidden",background:"#fff"}}>
                <div onClick={() => setExpanded(isExpanded ? null : loan.loan_id)} style={{
                  display:"grid",gridTemplateColumns:"1.5fr 1fr 1fr 1fr auto",
                  padding:"14px 20px",cursor:"pointer",gap:8,alignItems:"center",
                  background:isExpanded?"#f1f8e9":"#fff",
                }}>
                  <div>
                    <div style={{fontFamily:"monospace",color:"#1b5e20",fontWeight:800,fontSize:13}}>{loan.loan_id}</div>
                    <div style={{fontSize:11,color:"#aaa",marginTop:3}}>{loan.loan_type}</div>
                  </div>
                  <div>
                    <div style={{fontSize:10,color:"#bbb",fontWeight:600,textTransform:"uppercase"}}>Amount</div>
                    <div style={{fontWeight:700,fontSize:14}}>₱{Number(loan.amount||0).toLocaleString()}</div>
                  </div>
                  <div>
                    <div style={{fontSize:10,color:"#bbb",fontWeight:600,textTransform:"uppercase"}}>Balance</div>
                    <div style={{fontWeight:700,fontSize:14,color:isPaid?"#2e7d32":"#c62828"}}>
                      {isPaid?"₱0":`₱${Number(loan.balance||0).toLocaleString()}`}
                    </div>
                  </div>
                  <div>
                    <span style={{background:sb,color:sc,border:`1px solid ${sc}33`,borderRadius:20,padding:"4px 12px",fontSize:11,fontWeight:700}}>
                      {isPaid?"Completed":loan.status}
                    </span>
                  </div>
                  <div style={{color:"#bbb"}}>
                    {isExpanded ? <ChevronUp size={16}/> : <ChevronDown size={16}/>}
                  </div>
                </div>
                {isExpanded && (
                  <div style={{borderTop:"1px solid #e8f5e9",background:"#f9fef9"}}>
                    <div style={{padding:"12px 20px 6px",fontSize:11,fontWeight:700,color:"#2e7d32",display:"flex",alignItems:"center",gap:6}}>
                      <CreditCard size={13}/> Payment History — {loan.loan_id}
                      <span style={{fontWeight:400,color:"#aaa",marginLeft:4}}>({loanPayments.length} payments)</span>
                    </div>
                    {loanPayments.length === 0 ? (
                      <div style={{padding:"14px 20px",color:"#bbb",fontSize:13,textAlign:"center"}}>No payments recorded yet.</div>
                    ) : (
                      <table style={{width:"100%",borderCollapse:"collapse",fontSize:12}}>
                        <thead><tr style={{background:"#e8f5e9"}}>
                          {["Date","TX ID","Amount","Balance After","Receipt"].map(h=>(
                            <th key={h} style={{padding:"8px 16px",textAlign:h==="Amount"||h==="Balance After"?"right":h==="Receipt"?"center":"left",color:"#558b2f",fontWeight:700,fontSize:11}}>{h}</th>
                          ))}
                        </tr></thead>
                        <tbody>
                          {loanPayments.map((p,pi) => (
                            <tr key={pi} style={{background:pi%2===0?"#fff":"#f9fef9",borderTop:"1px solid #e8f5e9"}}>
                              <td style={{padding:"9px 16px",color:"#666"}}>{p.paid_at?.slice(0,10)}</td>
                              <td style={{padding:"9px 16px",fontFamily:"monospace",color:"#888",fontSize:10}}>{p.tx_id}</td>
                              <td style={{padding:"9px 16px",textAlign:"right",fontWeight:700,color:"#2e7d32"}}>₱{Number(p.amount||0).toLocaleString()}</td>
                              <td style={{padding:"9px 16px",textAlign:"right",color:parseFloat(p.balance||0)===0?"#1565c0":"#c62828"}}>
                                {parseFloat(p.balance||0)===0?"₱0 — Fully Paid":`₱${Number(p.balance||0).toLocaleString()}`}
                              </td>
                              <td style={{padding:"9px 16px",textAlign:"center"}}>
                                <button onClick={() => setReceipt(p)} style={{background:"#e8f5e9",border:"1px solid #a5d6a7",borderRadius:6,padding:"4px 10px",cursor:"pointer",fontSize:11,color:"#2e7d32",fontWeight:600,display:"flex",alignItems:"center",gap:4,margin:"0 auto"}}>
                                  <Eye size={10}/> View
                                </button>
                              </td>
                            </tr>
                          ))}
                        </tbody>
                      </table>
                    )}
                    <div style={{padding:"10px 20px",fontSize:12,color:"#888",display:"flex",gap:20,borderTop:"1px solid #e8f5e9",flexWrap:"wrap"}}>
                      <span>Monthly Due: <strong>₱{Number(loan.monthly_due||0).toLocaleString()}</strong></span>
                      <span>Total Paid: <strong style={{color:"#2e7d32"}}>₱{loanPayments.reduce((s,p)=>s+Number(p.amount||0),0).toLocaleString()}</strong></span>
                      <span>Remaining: <strong style={{color:isPaid?"#1565c0":"#c62828"}}>{isPaid?"₱0 — Fully Paid":`₱${Number(loan.balance||0).toLocaleString()}`}</strong></span>
                    </div>
                  </div>
                )}
              </div>
            );
          })}
        </div>
      )}

      {/* ══ ALL PAYMENTS ══════════════════════════════════════════════════════ */}
      {mainTab === "all" && (
        <div style={{background:"#fff",borderRadius:14,border:"1px solid #e8f5e9",overflow:"hidden"}}>
          {payments.length === 0 ? (
            <div style={{textAlign:"center",padding:"40px",color:"#aaa",fontSize:13}}>No payment records yet.</div>
          ) : (<>
            {/* Summary */}
            <div style={{display:"grid",gridTemplateColumns:"repeat(3,1fr)",gap:0,borderBottom:"1px solid #e8f5e9"}}>
              {[
                ["Total Payments", payments.length,                                                              "#1b5e20"],
                ["Total Paid",     `₱${payments.reduce((s,p)=>s+Number(p.amount||0),0).toLocaleString()}`,      "#2e7d32"],
                ["Latest Payment", payments[0]?.paid_at?.slice(0,10)||"—",                                      "#555"],
              ].map(([label,val,color],i) => (
                <div key={label} style={{padding:"18px",textAlign:"center",borderRight:i<2?"1px solid #e8f5e9":"none"}}>
                  <div style={{fontSize:10,color:"#aaa",fontWeight:700,textTransform:"uppercase",letterSpacing:0.5,marginBottom:6}}>{label}</div>
                  <div style={{fontSize:20,fontWeight:800,color}}>{val}</div>
                </div>
              ))}
            </div>
            {/* Table */}
            <div style={{overflowX:"auto"}}>
              <table style={{width:"100%",borderCollapse:"collapse",fontSize:12}}>
                <thead>
                  <tr style={{background:"#f9fef9"}}>
                    {["Date","TX ID","Loan ID","Loan Type","Amount","Balance After","Note","Receipt"].map(h=>(
                      <th key={h} style={{padding:"12px 16px",textAlign:h==="Amount"||h==="Balance After"?"right":"left",color:"#558b2f",fontWeight:700,borderBottom:"2px solid #e8f5e9",fontSize:11}}>{h}</th>
                    ))}
                  </tr>
                </thead>
                <tbody>
                  {payments.map((p,idx) => (
                    <tr key={idx} style={{background:idx%2===0?"#fff":"#f9fef9",borderBottom:"1px solid #f0f0f0"}}>
                      <td style={{padding:"11px 16px",color:"#555"}}>{p.paid_at?.slice(0,10)}</td>
                      <td style={{padding:"11px 16px",fontFamily:"monospace",color:"#888",fontSize:10}}>{p.tx_id}</td>
                      <td style={{padding:"11px 16px",fontFamily:"monospace",color:"#1b5e20",fontSize:11,fontWeight:700}}>{p.loan_code}</td>
                      <td style={{padding:"11px 16px"}}>
                        <span style={{background:"#f3e5f5",color:"#6a1b9a",borderRadius:20,padding:"3px 10px",fontSize:10,fontWeight:700}}>
                          {allLoans.find(l=>l.loan_id===p.loan_code)?.loan_type||"—"}
                        </span>
                      </td>
                      <td style={{padding:"11px 16px",textAlign:"right",fontWeight:800,color:"#2e7d32"}}>₱{Number(p.amount||0).toLocaleString()}</td>
                      <td style={{padding:"11px 16px",textAlign:"right",color:parseFloat(p.balance||0)===0?"#1565c0":"#555"}}>
                        {parseFloat(p.balance||0)===0?"Fully Paid":`₱${Number(p.balance||0).toLocaleString()}`}
                      </td>
                      <td style={{padding:"11px 16px",color:"#888",fontSize:11}}>{p.note||"—"}</td>
                      <td style={{padding:"11px 16px",textAlign:"center"}}>
                        <button onClick={() => setReceipt(p)} style={{background:"#e8f5e9",border:"1px solid #a5d6a7",borderRadius:6,padding:"5px 12px",cursor:"pointer",fontSize:11,color:"#2e7d32",fontWeight:600,display:"flex",alignItems:"center",gap:4,margin:"0 auto"}}>
                          <Eye size={11}/> Receipt
                        </button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </>)}
        </div>
      )}
    </div>
  );
}