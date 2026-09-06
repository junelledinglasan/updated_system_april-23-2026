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
import { useLanguage } from "../../context/LanguageContext";
import { useAuth } from "../../context/AuthContext";
import { getPageCache, savePageCache } from "../../utils/pageCache";
import "./MyLoans.css";

// ─── Receipt Modal ─────────────────────────────────────────────────────────────
function ReceiptModal({ payment, onClose }) {
  const { t } = useLanguage();
  if (!payment) return null;
  const isOnBlockchain = payment.polygon_tx && payment.network === "polygon";
  const rows = [
    [t("myloans_tx_id"),         payment.tx_id],
    [t("myloans_date_time"),     payment.paid_at],
    [t("myloans_loan_id"),       payment.loan_code],
    [t("myloans_th_amount_paid"),`₱${Number(payment.amount||0).toLocaleString()}`],
    [t("myloans_th_balance_after"), `₱${Number(payment.balance||0).toLocaleString()}`],
    [t("myloans_th_note"),       payment.note || "—"],
    [t("myloans_recorded_by"),   payment.recorded_by || "—"],
    [t("myloans_sha_hash"),      payment.hash || "—"],
    [t("myloans_blockchain"),    isOnBlockchain ? t("myloans_blockchain_mainnet") : t("myloans_blockchain_local")],
    [t("myloans_polygon_tx"),    payment.polygon_tx || "—"],
  ];
  return (
    <div style={{position:"fixed",inset:0,background:"rgba(0,0,0,0.5)",zIndex:9999,display:"flex",alignItems:"center",justifyContent:"center",padding:16}} onClick={onClose}>
      <div style={{background:"#fff",borderRadius:16,width:"100%",maxWidth:460,boxShadow:"0 8px 32px rgba(0,0,0,0.18)"}} onClick={e=>e.stopPropagation()}>
        <div style={{padding:"18px 24px",borderBottom:"1px solid #e8f5e9",display:"flex",justifyContent:"space-between",alignItems:"center"}}>
          <div>
            <div style={{fontWeight:800,fontSize:15,color:"#1b5e20",display:"flex",alignItems:"center",gap:8}}>
              <Receipt size={16} color="#1b5e20"/> {t("myloans_receipt_title")}
            </div>
            <div style={{fontSize:11,color:"#aaa",fontFamily:"monospace",marginTop:2}}>{payment.tx_id}</div>
          </div>
          <button onClick={onClose} style={{background:"none",border:"none",cursor:"pointer",color:"#888",padding:4}}><X size={18}/></button>
        </div>
        <div style={{padding:"16px 24px",display:"flex",flexDirection:"column",gap:0}}>
          <div style={{marginBottom:12}}>
            <div style={{fontSize:10,fontWeight:700,color:"#2e7d32",textTransform:"uppercase",letterSpacing:1,marginBottom:8}}>{t("myloans_member_info")}</div>
            {rows.slice(0,3).map(([k,v]) => (
              <div key={k} style={{display:"flex",justifyContent:"space-between",padding:"7px 0",borderBottom:"1px solid #f5f5f5"}}>
                <span style={{fontSize:12,color:"#888",fontWeight:600}}>{k}</span>
                <span style={{fontSize:12,color:"#333",fontWeight:400,fontFamily:k===t("myloans_tx_id")?"monospace":"inherit"}}>{v}</span>
              </div>
            ))}
          </div>
          <div style={{marginBottom:12}}>
            <div style={{fontSize:10,fontWeight:700,color:"#2e7d32",textTransform:"uppercase",letterSpacing:1,marginBottom:8}}>{t("myloans_payment_details")}</div>
            {rows.slice(3,7).map(([k,v]) => (
              <div key={k} style={{display:"flex",justifyContent:"space-between",padding:"7px 0",borderBottom:"1px solid #f5f5f5"}}>
                <span style={{fontSize:12,color:"#888",fontWeight:600}}>{k}</span>
                <span style={{fontSize:12,fontWeight:k===t("myloans_th_amount_paid")?800:400,color:k===t("myloans_th_amount_paid")?"#2e7d32":"#333"}}>{v}</span>
              </div>
            ))}
          </div>
          <div>
            <div style={{fontSize:10,fontWeight:700,color:"#2e7d32",textTransform:"uppercase",letterSpacing:1,marginBottom:8}}>{t("myloans_verification")}</div>
            {rows.slice(7).map(([k,v]) => (
              <div key={k} style={{display:"flex",justifyContent:"space-between",alignItems:"flex-start",gap:12,padding:"7px 0",borderBottom:"1px solid #f5f5f5"}}>
                <span style={{fontSize:12,color:"#888",fontWeight:600,flexShrink:0}}>{k}</span>
                <span style={{fontSize:11,color:k===t("myloans_blockchain")?(isOnBlockchain?"#2e7d32":"#f57c00"):"#555",fontFamily:k===t("myloans_sha_hash")||k===t("myloans_polygon_tx")?"monospace":"inherit",wordBreak:"break-all",textAlign:"right",fontWeight:k===t("myloans_blockchain")?700:400}}>{v}</span>
              </div>
            ))}
            {payment.polygon_tx && (
              <a href={`https://polygonscan.com/tx/${payment.polygon_tx}`} target="_blank" rel="noopener noreferrer"
                style={{display:"flex",alignItems:"center",justifyContent:"center",gap:6,color:"#7c3aed",fontWeight:600,fontSize:12,marginTop:10,padding:"8px",background:"#f3e5f5",borderRadius:8,textDecoration:"none"}}>
                {t("myloans_view_polygonscan")}
              </a>
            )}
          </div>
        </div>
        <div style={{padding:"14px 24px",borderTop:"1px solid #f0f0f0",display:"flex",gap:8,justifyContent:"flex-end"}}>
          <button onClick={onClose} style={{padding:"9px 20px",background:"#f5f5f5",border:"none",borderRadius:8,cursor:"pointer",fontSize:13,fontWeight:600,fontFamily:"inherit"}}>{t("myloans_close")}</button>
          <button onClick={()=>window.print()} style={{padding:"9px 20px",background:"#2e7d32",color:"#fff",border:"none",borderRadius:8,cursor:"pointer",fontSize:13,fontWeight:600,fontFamily:"inherit",display:"flex",alignItems:"center",gap:6}}>
            {t("myloans_print")}
          </button>
        </div>
      </div>
    </div>
  );
}

export default function MyLoans() {
  const { t } = useLanguage();
  const { user } = useAuth();
  const ctx    = useOutletContext() || {};
  const member = ctx.member || {};
  // ── FIX: dating member.id (mula sa MemberLayout) ang ginagamit
  // bilang cache key — pero `null` muna 'to sa unang saglit habang
  // hinihintay ang async profile fetch ng MemberLayout, kaya sa
  // pag-refresh, mali munang key ang tinatamaan ("anon"), hindi
  // makita ang tamang cache, kaya nagpapakitang blangko muna bago
  // lumabas ang totoong datos. Gamit na lang ngayon ang user.id mula
  // sa AuthContext — naka-load na 'to AGAD mula sa saved session,
  // hindi na kailangang maghintay ng async fetch. ────────────────────
  const scopeKey = user?.id ?? user?.username ?? null;
  const cached = getPageCache("myloans", scopeKey);
  const [loans,         setLoans]      = useState(cached?.loans || []);
  const [allLoans,      setAllLoans]   = useState(cached?.allLoans || []);
  const [payments,      setPayments]   = useState(cached?.payments || []);
  const [selectedLoan,  setSelected]   = useState(cached?.loans?.[0] || null);
  const [tab,           setTab]        = useState("details");
  const [mainTab,       setMainTab]    = useState("active");
  const [loading,       setLoading]    = useState(!cached);
  const [receipt,       setReceipt]    = useState(null);
  const [expandedLoan,  setExpanded]   = useState(null);
  const [gcashLoan,     setGcashLoan]  = useState(null);
  const [gcashRequests, setGcashReqs]  = useState(cached?.gcashRequests || []);

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
      const newAllLoans = [...activeFiltered, ...completed].sort((a,b) => b.id - a.id);
      const newPayments = p.status === "fulfilled" ? p.value : [];
      const newGcash    = gcash.status === "fulfilled" && Array.isArray(gcash.value) ? gcash.value : [];
      setLoans(activeFiltered);
      setAllLoans(newAllLoans);
      if (activeFiltered.length > 0) setSelected(activeFiltered[0]);
      setPayments(newPayments);
      setGcashReqs(newGcash);
      savePageCache("myloans", scopeKey, { loans: activeFiltered, allLoans: newAllLoans, payments: newPayments, gcashRequests: newGcash });
    }).finally(() => setLoading(false));
  }, [scopeKey]);

  const hasPendingGCash = (loanId) =>
    gcashRequests.some(r => r.loan_id === loanId && r.status === "Pending");

  if (loading) return (
    <div style={{textAlign:"center",padding:"80px",color:"#aaa",display:"flex",flexDirection:"column",alignItems:"center",gap:12}}>
      <Clock size={32} color="#c8e6c9"/>
      <div style={{fontSize:14,fontWeight:600}}>{t("myloans_loading")}</div>
    </div>
  );

  const principal  = parseFloat(selectedLoan?.amount || 0);
  const balance    = parseFloat(selectedLoan?.balance || 0);
  // ── FIX: dating "principal - balance" — nasira ito ngayon dahil
  // puwede nang LUMAKI ang balance (dahil sa 2% penalty), hindi na
  // laging lumiliit lang (dahil sa pagbabayad). Nagreresulta ito ng
  // NEGATIVE na "Total Paid" (hal. ₱10,000 - ₱10,066.67 = -₱66.67)
  // kapag may naipong penalty. Ang tamang paraan: i-sum ang AKTWAL na
  // mga payment record ng loan na 'to, hindi ang pagkakaiba lang ng
  // principal at balance. ─────────────────────────────────────────────
  const loanPaymentsForTotal = payments.filter(p => p.loan === selectedLoan?.id || String(p.loan_code) === String(selectedLoan?.loan_id));
  const totalPaid  = loanPaymentsForTotal.reduce((s,p) => s + parseFloat(p.amount||0), 0);
  const monthlyDue = parseFloat(selectedLoan?.monthly_due || 0);
  const paidPct    = principal > 0 ? Math.max(0, Math.round((totalPaid / principal) * 100)) : 0;

  const statusColor = { Active:"#2e7d32", Overdue:"#c62828", Completed:"#1565c0", Declined:"#757575" };
  const statusBg    = { Active:"#e8f5e9", Overdue:"#ffebee", Completed:"#e3f2fd", Declined:"#f5f5f5" };

  const MAIN_TABS = [
    { key:"active",  label:t("myloans_tab_active"),       icon:<CreditCard   size={14}/>, count:loans.length    },
    { key:"history", label:t("myloans_tab_history"),       icon:<ClipboardList size={14}/>, count:allLoans.length },
    { key:"all",     label:t("myloans_tab_all_payments"),  icon:<Receipt       size={14}/>, count:payments.length },
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
        <div className="ml-page-title">{t("myloans_page_title")}</div>
        <div className="ml-page-sub">{t("myloans_page_sub")}</div>
      </div>

      {/* Main Tabs */}
      <div style={{display:"flex",gap:0,background:"#fff",borderRadius:12,border:"1px solid #e8f5e9",marginBottom:20,overflow:"hidden"}}>
        {MAIN_TABS.map(mt => (
          <button key={mt.key} onClick={() => setMainTab(mt.key)} style={{
            flex:1,padding:"13px 10px",fontSize:13,fontWeight:600,cursor:"pointer",
            border:"none",
            background:mainTab===mt.key?"#1b5e20":"transparent",
            color:mainTab===mt.key?"#fff":"#888",
            display:"flex",alignItems:"center",justifyContent:"center",gap:7,
            transition:"all 0.15s",fontFamily:"inherit",
          }}>
            {mt.icon}
            {mt.label}
            <span style={{
              background:mainTab===mt.key?"rgba(255,255,255,0.2)":"#f0f0f0",
              color:mainTab===mt.key?"#fff":"#aaa",
              borderRadius:10,padding:"1px 7px",fontSize:11,fontWeight:700,
            }}>{mt.count}</span>
          </button>
        ))}
      </div>

      {/* ══ ACTIVE LOANS ══════════════════════════════════════════════════════ */}
      {mainTab === "active" && (<>
        {loans.length === 0 ? (
          <div style={{textAlign:"center",padding:"60px 20px",background:"#fff",borderRadius:14,border:"1px solid #e8f5e9",display:"flex",flexDirection:"column",alignItems:"center",gap:12}}>
            <FileText size={40} color="#c8e6c9"/>
            <div style={{fontWeight:700,fontSize:15,color:"#555"}}>{t("myloans_no_active")}</div>
            <div style={{fontSize:13,color:"#aaa"}}>{t("myloans_no_active_sub")}</div>
          </div>
        ) : (<>
          {/* Loan selector cards */}
          <div className="ml-loan-cards">
            {loans.map(loan => {
              const lp  = parseFloat(loan.amount || 0);
              const lb  = parseFloat(loan.balance || 0);
              // ── FIX: parehong ayos sa itaas — i-sum ang aktwal na
              // mga payment ng loan na 'to, hindi ang "(lp-lb)/lp" na
              // nagiging negative kapag may naipong penalty (lumalaki
              // ang balance). ─────────────────────────────────────────
              const loanPaidAmt = payments.filter(p => p.loan === loan.id || String(p.loan_code) === String(loan.loan_id)).reduce((s,p) => s + parseFloat(p.amount||0), 0);
              const pct = lp > 0 ? Math.max(0, Math.round((loanPaidAmt / lp) * 100)) : 0;
              const pending = hasPendingGCash(loan.loan_id);
              return (
                <div key={loan.loan_id} className={`ml-loan-card ${selectedLoan?.loan_id === loan.loan_id ? "selected" : ""}`}
                  onClick={() => { setSelected(loan); setTab("details"); }}>
                  <div className="ml-lc-header">
                    <span className="ml-lc-type">{loan.loan_type}</span>
                    <span className={`ml-lc-status ${(loan.status||"").toLowerCase()}`}>{loan.status}</span>
                  </div>
                  <div className="ml-lc-id">{loan.loan_id}</div>
                  {parseFloat(loan.total_penalty||0) > 0 && (
                    <div style={{display:"inline-flex",alignItems:"center",gap:4,background:"#fce4ec",color:"#c62828",borderRadius:20,padding:"2px 8px",fontSize:9.5,fontWeight:700,marginTop:4}}>
                      <AlertTriangle size={10}/> +₱{Number(loan.total_penalty).toLocaleString()} penalty
                    </div>
                  )}
                  <div className="ml-lc-balance">₱{Number(loan.balance).toLocaleString()}</div>
                  <div className="ml-lc-label">{t("myloans_remaining_balance")}</div>
                  <div className="ml-lc-bar"><div className="ml-lc-fill" style={{width:pct+"%"}}/></div>
                  <div className="ml-lc-pct">{t("myloans_pct_paid", { pct })}</div>
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
                    {pending ? t("myloans_gcash_pending") : t("myloans_pay_gcash")}
                  </button>
                </div>
              );
            })}
          </div>

          {/* GCash pending notice */}
          {gcashRequests.filter(r=>r.status==="Pending").length > 0 && (
            <div style={{background:"#fff8e1",border:"1px solid #ffe082",borderRadius:10,padding:"14px 18px",display:"flex",alignItems:"center",gap:10,fontSize:13,color:"#f57c00",fontWeight:600,marginBottom:4}}>
              <AlertTriangle size={16} color="#f57c00"/>
              {t("myloans_gcash_notice", { count: gcashRequests.filter(r=>r.status==="Pending").length })}
            </div>
          )}

          {/* Detail card */}
          <div className="ml-detail-card">
            <div className="ml-tabs">
              {[
                {key:"details",  label:t("myloans_tab_details")},
                {key:"payments", label:t("myloans_tab_payments")},
                {key:"schedule", label:t("myloans_tab_schedule")},
              ].map(tb => (
                <button key={tb.key} className={`ml-tab ${tab === tb.key ? "active" : ""}`} onClick={() => setTab(tb.key)}>
                  {tb.label}
                </button>
              ))}
            </div>

            {/* Details */}
            {tab === "details" && (<>
              {parseFloat(selectedLoan?.total_penalty||0) > 0 && (
                <div style={{margin:"0 24px 14px",padding:"10px 14px",background:"#fce4ec",border:"1px solid #f8bbd0",borderRadius:10,fontSize:12.5,color:"#c62828",display:"flex",alignItems:"center",gap:8}}>
                  <AlertTriangle size={15}/>
                  <span>You have a <strong>₱{Number(selectedLoan.total_penalty).toLocaleString()} penalty</strong> for {selectedLoan.months_overdue_penalized} month{selectedLoan.months_overdue_penalized!==1?"s":""} of late payment (2% of your Monthly Due per month). This is already included in your Remaining Balance. Pay as soon as possible to avoid further penalties.</span>
                </div>
              )}
              <div style={{padding:"20px 24px"}}>
                <div style={{display:"grid",gridTemplateColumns:"repeat(2,1fr)",gap:0,borderRadius:10,overflow:"hidden",border:"1px solid #e8f5e9"}}>
                  {[
                    [t("myloans_loan_id"),      selectedLoan?.loan_id],
                    [t("myloans_loan_type"),    selectedLoan?.loan_type],
                    [t("myloans_principal"),    `₱${principal.toLocaleString()}`],
                    [t("myloans_remaining"),    `₱${balance.toLocaleString()}`],
                    [t("myloans_total_paid"),   `₱${totalPaid.toLocaleString()}`],
                    [t("myloans_monthly_due"),  `₱${monthlyDue.toLocaleString()}`],
                    [t("myloans_term"),         t("myloans_term_months", { n: selectedLoan?.term_months })],
                    [t("myloans_release_date"), selectedLoan?.approved_at?.slice(0,10)||"—"],
                    [t("myloans_next_due"),     selectedLoan?.next_due_date||"—"],
                    [t("myloans_status"),       selectedLoan?.status],
                  ].map(([k,v],i) => (
                    <div key={k} style={{
                      padding:"13px 18px",
                      background:i%4<2?"#fff":"#f9fef9",
                      borderBottom:"1px solid #e8f5e9",
                      borderRight:i%2===0?"1px solid #e8f5e9":"none",
                      display:"flex",flexDirection:"column",gap:3,
                    }}>
                      <span style={{fontSize:10,fontWeight:700,color:"#aaa",textTransform:"uppercase",letterSpacing:0.5}}>{k}</span>
                      <span style={{fontSize:14,fontWeight:700,color:k===t("myloans_remaining")?"#c62828":k===t("myloans_total_paid")?"#2e7d32":"#1a1a1a"}}>{v}</span>
                    </div>
                  ))}
                </div>
                {/* Progress bar */}
                <div style={{marginTop:16,background:"#f5f5f5",borderRadius:20,height:10,overflow:"hidden"}}>
                  <div style={{width:paidPct+"%",height:"100%",background:"#2e7d32",borderRadius:20,transition:"width 0.5s"}}/>
                </div>
                <div style={{display:"flex",justifyContent:"space-between",marginTop:6,fontSize:11,color:"#888"}}>
                  <span>{t("myloans_pct_paid", { pct: paidPct })}</span>
                  <span>₱{balance.toLocaleString()} {t("myloans_remaining_label")}</span>
                </div>
              </div>
            </>)}

            {/* Payments */}
            {tab === "payments" && (() => {
              const loanPayments = payments.filter(p => p.loan === selectedLoan?.id || String(p.loan_code) === String(selectedLoan?.loan_id));
              // ── BAGO: isama rin ang GCash payment requests na Pending o
              // Rejected — para makita ang BUONG proseso ng pagbabayad,
              // hindi lang yung mga na-confirm na. Hindi na kasama ang
              // "Verified" requests dito dahil may kasama na silang
              // totoong Payment record sa itaas (maiiwasan ang duplicate). ──
              const loanGcash = gcashRequests.filter(r => r.loan_id === selectedLoan?.loan_id && r.status !== "Verified");
              const combined = [
                ...loanPayments.map(p => ({ kind:"payment", sortDate:p.paid_at, ...p })),
                ...loanGcash.map(r => ({ kind:"gcash", sortDate:r.created_at, ...r })),
              ].sort((a,b) => new Date(b.sortDate||0) - new Date(a.sortDate||0));

              return (
                <div className="ml-payments-table-wrap">
                  <table className="ml-payments-table">
                    <thead>
                      <tr>
                        <th>{t("myloans_th_date")}</th><th>{t("myloans_th_txid")}</th><th>{t("myloans_th_amount_paid")}</th>
                        <th>{t("myloans_th_balance_after")}</th><th>{t("myloans_th_status")}</th><th>{t("myloans_th_note")}</th><th style={{textAlign:"center"}}>{t("myloans_th_receipt")}</th>
                      </tr>
                    </thead>
                    <tbody>
                      {combined.length === 0 ? (
                        <tr><td colSpan={7} style={{textAlign:"center",color:"#aaa",padding:24,fontSize:13}}>{t("myloans_no_payments_yet")}</td></tr>
                      ) : combined.map((item, i) => item.kind === "payment" ? (
                        <tr key={`p-${i}`}>
                          <td className="cell-date">{item.paid_at?.slice(0,10)}</td>
                          <td style={{fontFamily:"monospace",fontSize:10,color:"#888"}}>{item.tx_id}</td>
                          <td className="green fw">₱{Number(item.amount||0).toLocaleString()}</td>
                          <td className="blue">₱{Number(item.balance||0).toLocaleString()}</td>
                          <td><span style={{background:"#e8f5e9",color:"#2e7d32",border:"1px solid #a5d6a7",borderRadius:20,padding:"3px 10px",fontSize:10.5,fontWeight:700}}>{t("myloans_status_completed")}</span></td>
                          <td style={{fontSize:11,color:"#888"}}>{item.note||"—"}</td>
                          <td style={{textAlign:"center"}}>
                            <button onClick={() => setReceipt(item)} style={{background:"#e8f5e9",border:"1px solid #a5d6a7",borderRadius:6,padding:"5px 12px",cursor:"pointer",fontSize:11,color:"#2e7d32",fontWeight:600,display:"flex",alignItems:"center",gap:4,margin:"0 auto"}}>
                              <Eye size={11}/> {t("myloans_view")}
                            </button>
                          </td>
                        </tr>
                      ) : (
                        <tr key={`g-${i}`}>
                          <td className="cell-date">{item.created_at?.slice(0,10)}</td>
                          <td style={{fontFamily:"monospace",fontSize:10,color:"#888"}}>{item.reference_number}</td>
                          <td className="fw">₱{Number(item.amount||0).toLocaleString()}</td>
                          <td>—</td>
                          <td>
                            {item.status === "Pending" ? (
                              <span style={{background:"#fff8e1",color:"#e65100",border:"1px solid #ffe082",borderRadius:20,padding:"3px 10px",fontSize:10.5,fontWeight:700}}>{t("myloans_status_pending_verification")}</span>
                            ) : (
                              <span style={{background:"#fce4ec",color:"#c62828",border:"1px solid #ef9a9a",borderRadius:20,padding:"3px 10px",fontSize:10.5,fontWeight:700}}>{t("myloans_status_rejected")}</span>
                            )}
                          </td>
                          <td style={{fontSize:11,color:item.status==="Rejected"?"#c62828":"#888"}}>{item.status==="Rejected" ? (item.reject_reason||"—") : t("myloans_awaiting_verification")}</td>
                          <td style={{textAlign:"center",color:"#ccc",fontSize:11}}>—</td>
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
                  <thead><tr><th>{t("myloans_th_num")}</th><th>{t("myloans_th_due_date")}</th><th>{t("myloans_th_amount")}</th><th>{t("myloans_status")}</th></tr></thead>
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
                                {isPaid ? <><CheckCircle2 size={11}/> {t("myloans_paid")}</> : <><Clock size={11}/> {t("myloans_upcoming")}</>}
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
            <div style={{textAlign:"center",padding:"40px",color:"#aaa",background:"#fff",borderRadius:12,border:"1px solid #e8f5e9"}}>{t("myloans_no_history")}</div>
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
                    {/* ── BAGO: dating "Loan Type" lang — idinagdag ang
                        Term at Date (kailan kinuha ang loan) para
                        alam agad ng member. ─────────────────────────── */}
                    <div style={{fontSize:11,color:"#aaa",marginTop:3}}>
                      {loan.loan_type} · {loan.term_months ? t("myloans_term_months", { n: loan.term_months }) : "—"} · {loan.applied_at?.slice(0,10)||"—"}
                    </div>
                  </div>
                  <div>
                    <div style={{fontSize:10,color:"#bbb",fontWeight:600,textTransform:"uppercase"}}>{t("myloans_amount_label")}</div>
                    <div style={{fontWeight:700,fontSize:14}}>₱{Number(loan.amount||0).toLocaleString()}</div>
                  </div>
                  <div>
                    <div style={{fontSize:10,color:"#bbb",fontWeight:600,textTransform:"uppercase"}}>{t("myloans_balance_label")}</div>
                    <div style={{fontWeight:700,fontSize:14,color:isPaid?"#2e7d32":"#c62828"}}>
                      {isPaid?"₱0":`₱${Number(loan.balance||0).toLocaleString()}`}
                    </div>
                  </div>
                  <div>
                    <span style={{background:sb,color:sc,border:`1px solid ${sc}33`,borderRadius:20,padding:"4px 12px",fontSize:11,fontWeight:700}}>
                      {isPaid?t("myloans_completed"):loan.status}
                    </span>
                  </div>
                  <div style={{color:"#bbb"}}>
                    {isExpanded ? <ChevronUp size={16}/> : <ChevronDown size={16}/>}
                  </div>
                </div>
                {isExpanded && (
                  <div style={{borderTop:"1px solid #e8f5e9",background:"#f9fef9"}}>
                    <div style={{padding:"12px 20px 6px",fontSize:11,fontWeight:700,color:"#2e7d32",display:"flex",alignItems:"center",gap:6}}>
                      <CreditCard size={13}/> {t("myloans_payment_history_label")} — {loan.loan_id}
                      <span style={{fontWeight:400,color:"#aaa",marginLeft:4}}>{t("myloans_payments_count", { n: loanPayments.length })}</span>
                    </div>
                    {loanPayments.length === 0 ? (
                      <div style={{padding:"14px 20px",color:"#bbb",fontSize:13,textAlign:"center"}}>{t("myloans_no_payments_recorded")}</div>
                    ) : (
                      <table style={{width:"100%",borderCollapse:"collapse",fontSize:12}}>
                        <thead><tr style={{background:"#e8f5e9"}}>
                          {[t("myloans_th_date"),t("myloans_th_txid"),t("myloans_th_amount"),t("myloans_th_balance_after"),t("myloans_th_receipt")].map(h=>(
                            <th key={h} style={{padding:"8px 16px",textAlign:h===t("myloans_th_amount")||h===t("myloans_th_balance_after")?"right":h===t("myloans_th_receipt")?"center":"left",color:"#558b2f",fontWeight:700,fontSize:11}}>{h}</th>
                          ))}
                        </tr></thead>
                        <tbody>
                          {loanPayments.map((p,pi) => (
                            <tr key={pi} style={{background:pi%2===0?"#fff":"#f9fef9",borderTop:"1px solid #e8f5e9"}}>
                              <td style={{padding:"9px 16px",color:"#666"}}>{p.paid_at?.slice(0,10)}</td>
                              <td style={{padding:"9px 16px",fontFamily:"monospace",color:"#888",fontSize:10}}>{p.tx_id}</td>
                              <td style={{padding:"9px 16px",textAlign:"right",fontWeight:700,color:"#2e7d32"}}>₱{Number(p.amount||0).toLocaleString()}</td>
                              <td style={{padding:"9px 16px",textAlign:"right",color:parseFloat(p.balance||0)===0?"#1565c0":"#c62828"}}>
                                {parseFloat(p.balance||0)===0?t("myloans_zero_fully_paid"):`₱${Number(p.balance||0).toLocaleString()}`}
                              </td>
                              <td style={{padding:"9px 16px",textAlign:"center"}}>
                                <button onClick={() => setReceipt(p)} style={{background:"#e8f5e9",border:"1px solid #a5d6a7",borderRadius:6,padding:"4px 10px",cursor:"pointer",fontSize:11,color:"#2e7d32",fontWeight:600,display:"flex",alignItems:"center",gap:4,margin:"0 auto"}}>
                                  <Eye size={10}/> {t("myloans_view")}
                                </button>
                              </td>
                            </tr>
                          ))}
                        </tbody>
                      </table>
                    )}
                    <div style={{padding:"10px 20px",fontSize:12,color:"#888",display:"flex",gap:20,borderTop:"1px solid #e8f5e9",flexWrap:"wrap"}}>
                      <span>{t("myloans_monthly_due")}: <strong>₱{Number(loan.monthly_due||0).toLocaleString()}</strong></span>
                      <span>{t("myloans_total_paid")}: <strong style={{color:"#2e7d32"}}>₱{loanPayments.reduce((s,p)=>s+Number(p.amount||0),0).toLocaleString()}</strong></span>
                      <span>{t("myloans_remaining")}: <strong style={{color:isPaid?"#1565c0":"#c62828"}}>{isPaid?t("myloans_zero_fully_paid"):`₱${Number(loan.balance||0).toLocaleString()}`}</strong></span>
                      {parseFloat(loan.total_penalty||0) > 0 && (
                        <span style={{color:"#c62828",display:"inline-flex",alignItems:"center",gap:4}}><AlertTriangle size={12}/> Penalty: <strong>₱{Number(loan.total_penalty).toLocaleString()}</strong> ({loan.months_overdue_penalized} mo. late)</span>
                      )}
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
            <div style={{textAlign:"center",padding:"40px",color:"#aaa",fontSize:13}}>{t("myloans_no_payment_records")}</div>
          ) : (<>
            {/* Summary */}
            <div style={{display:"grid",gridTemplateColumns:"repeat(3,1fr)",gap:0,borderBottom:"1px solid #e8f5e9"}}>
              {[
                [t("myloans_total_payments"), payments.length,                                                              "#1b5e20"],
                [t("myloans_total_paid"),     `₱${payments.reduce((s,p)=>s+Number(p.amount||0),0).toLocaleString()}`,      "#2e7d32"],
                [t("myloans_latest_payment"), payments[0]?.paid_at?.slice(0,10)||"—",                                      "#555"],
              ].map(([label,val,color]) => (
                <div key={label} style={{padding:"18px",textAlign:"center",borderRight:label!==t("myloans_latest_payment")?"1px solid #e8f5e9":"none"}}>
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
                    {/* ── BAGO: idinagdag ang "Term" at "Loan Date"
                        column — para malaman agad ng member kung
                        ilang buwan ang loan at kailan ito kinuha. ──── */}
                    {[t("myloans_th_date"),t("myloans_th_txid"),t("myloans_th_loan_id"),t("myloans_th_loan_type"),t("myloans_th_term"),t("myloans_th_loan_date"),t("myloans_th_amount"),t("myloans_th_balance_after"),t("myloans_th_note"),t("myloans_th_receipt")].map(h=>(
                      <th key={h} style={{padding:"12px 16px",textAlign:h===t("myloans_th_amount")||h===t("myloans_th_balance_after")?"right":"left",color:"#558b2f",fontWeight:700,borderBottom:"2px solid #e8f5e9",fontSize:11}}>{h}</th>
                    ))}
                  </tr>
                </thead>
                <tbody>
                  {payments.map((p,idx) => {
                    const matchedLoan = allLoans.find(l=>l.loan_id===p.loan_code);
                    return (
                    <tr key={idx} style={{background:idx%2===0?"#fff":"#f9fef9",borderBottom:"1px solid #f0f0f0"}}>
                      <td style={{padding:"11px 16px",color:"#555"}}>{p.paid_at?.slice(0,10)}</td>
                      <td style={{padding:"11px 16px",fontFamily:"monospace",color:"#888",fontSize:10}}>{p.tx_id}</td>
                      <td style={{padding:"11px 16px",fontFamily:"monospace",color:"#1b5e20",fontSize:11,fontWeight:700}}>{p.loan_code}</td>
                      <td style={{padding:"11px 16px"}}>
                        <span style={{background:"#f3e5f5",color:"#6a1b9a",borderRadius:20,padding:"3px 10px",fontSize:10,fontWeight:700}}>
                          {matchedLoan?.loan_type||"—"}
                        </span>
                      </td>
                      <td style={{padding:"11px 16px",color:"#555",fontSize:11}}>{matchedLoan?.term_months ? t("myloans_term_months", { n: matchedLoan.term_months }) : "—"}</td>
                      <td style={{padding:"11px 16px",color:"#555",fontSize:11}}>{matchedLoan?.applied_at?.slice(0,10)||"—"}</td>
                      <td style={{padding:"11px 16px",textAlign:"right",fontWeight:800,color:"#2e7d32"}}>₱{Number(p.amount||0).toLocaleString()}</td>
                      <td style={{padding:"11px 16px",textAlign:"right",color:parseFloat(p.balance||0)===0?"#1565c0":"#555"}}>
                        {parseFloat(p.balance||0)===0?t("myloans_fully_paid"):`₱${Number(p.balance||0).toLocaleString()}`}
                      </td>
                      <td style={{padding:"11px 16px",color:"#888",fontSize:11}}>{p.note||"—"}</td>
                      <td style={{padding:"11px 16px",textAlign:"center"}}>
                        <button onClick={() => setReceipt(p)} style={{background:"#e8f5e9",border:"1px solid #a5d6a7",borderRadius:6,padding:"5px 12px",cursor:"pointer",fontSize:11,color:"#2e7d32",fontWeight:600,display:"flex",alignItems:"center",gap:4,margin:"0 auto"}}>
                          <Eye size={11}/> {t("myloans_th_receipt")}
                        </button>
                      </td>
                    </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          </>)}
        </div>
      )}
    </div>
  );
}