import { useState, useEffect } from "react";
import { getLoansAPI } from "../../api/loans";
import { getPaymentsAPI, getPaymentStatsAPI, recordPaymentAPI } from "../../api/payments";
import { Search, Eye, ChevronDown, ChevronUp, Wallet, AlertTriangle, BarChart3, Receipt, History, X, CheckCircle, PartyPopper, Link, Printer, CreditCard, Calendar, ClipboardList } from "lucide-react";
import api from "../../api/axiosInstance";
import "./LoanPayment.css";
import logo from '../../assets/logo.png';

const ROWS_PER_PAGE = 8;

function RecordModal({ loan, onClose, onSave }) {
  const [amount, setAmount] = useState(loan ? String(loan.monthly_due||loan.monthlyDue||"") : "");
  const [note,   setNote]   = useState("");
  const [error,  setError]  = useState("");
  const [loading,setLoading]= useState(false);
  if (!loan) return null;
  const balance  = parseFloat(loan.balance||0);
  const parsed   = parseFloat(amount)||0;
  const newBal   = balance - parsed;
  const isValid  = parsed>0 && parsed<=balance;
  const submit = async () => {
    if (!parsed||parsed<=0)   { setError("Please enter a valid amount."); return; }
    if (parsed>balance)       { setError(`Exceeds remaining balance of ₱${balance.toLocaleString()}.`); return; }
    setLoading(true);
    try { await onSave({ loan, amount: parsed, note }); }
    catch { setError("Failed to record payment. Please try again."); }
    finally { setLoading(false); }
  };
  return (
    <div className="lp-overlay" onClick={onClose}>
      <div className="lp-modal" onClick={e=>e.stopPropagation()}>
        <div className="lp-modal-header">
          <div><div className="lp-modal-title">Record Payment</div><div className="lp-modal-sub">F2F — Office Collection</div></div>
          <button className="lp-modal-close" onClick={onClose}><X size={16}/></button>
        </div>
        <div className="lp-modal-body">
          <div className="lp-borrower-strip">
            <div className="lp-avatar">{(loan.member_name||loan.fullname||"M")[0]}</div>
            <div className="lp-borrower-info">
              <div className="lp-borrower-name">{loan.member_name||loan.fullname}</div>
              <div className="lp-borrower-meta">{loan.member_code||loan.memberId} · {loan.loan_id||loan.loanId} · {loan.loan_type||loan.loanType}</div>
            </div>
          </div>
          <div className="lp-balance-row" style={{display:"grid",gridTemplateColumns:"repeat(4, 1fr)",gap:10}}>
            <div className="lp-bal-item"><span className="lp-bal-label">Principal</span><span className="lp-bal-val">₱{Number(loan.amount||0).toLocaleString()}</span></div>
            <div className="lp-bal-item highlight"><span className="lp-bal-label">Remaining Balance</span><span className="lp-bal-val danger">₱{balance.toLocaleString()}</span></div>
            <div className="lp-bal-item"><span className="lp-bal-label">Monthly Due</span><span className="lp-bal-val green">₱{Number(loan.monthly_due||0).toLocaleString()}</span></div>
            <div className="lp-bal-item"><span className="lp-bal-label">Term</span><span className="lp-bal-val">{loan.term_months||loan.termMonths||"—"} months</span></div>
          </div>
          <div className="lp-field">
            <label className="lp-field-label">Payment Amount (₱) <span className="lp-required">*</span></label>
            <div className="lp-amount-wrap">
              <span className="lp-peso">₱</span>
              <input className="lp-amount-input" type="number" min="1" max={balance} value={amount} onChange={e=>{setAmount(e.target.value);setError("");}} autoFocus/>
            </div>
            <div className="lp-quick-btns">
              <button className="lp-quick" onClick={()=>{setAmount(String(loan.monthly_due||0));setError("");}}>Monthly Due ₱{Number(loan.monthly_due||0).toLocaleString()}</button>
              <button className="lp-quick" onClick={()=>{setAmount(String(balance));setError("");}}>Full Balance ₱{balance.toLocaleString()}</button>
            </div>
          </div>
          <div className="lp-field">
            <label className="lp-field-label">Note (optional)</label>
            <input className="lp-input" type="text" value={note} onChange={e=>setNote(e.target.value)} placeholder="e.g. Partial payment, advance payment..." maxLength={80}/>
          </div>
          {error && <div className="lp-error" style={{display:"flex",alignItems:"center",gap:6}}><AlertTriangle size={13}/> {error}</div>}
          {isValid && (
            <div className="lp-preview">
              <div className="lp-prev-row"><span>Current balance</span><span>₱{balance.toLocaleString()}</span></div>
              <div className="lp-prev-row deduct"><span>Payment</span><span>− ₱{parsed.toLocaleString()}</span></div>
              <div className="lp-prev-divider"/>
              <div className="lp-prev-row result">
                <span>New balance</span>
                <span className={newBal===0?"paid-val":""}>₱{newBal.toLocaleString()}{newBal===0&&<span className="lp-paid-tag" style={{display:"inline-flex",alignItems:"center",gap:4}}> FULLY PAID <PartyPopper size={13}/></span>}</span>
              </div>
            </div>
          )}
        </div>
        <div className="lp-modal-footer">
          <button className="lp-btn-cancel" onClick={onClose}>Cancel</button>
          <button className="lp-btn-save" onClick={submit} disabled={!isValid||loading}>{loading?"Saving...":"Save Payment Record"}</button>
        </div>
      </div>
    </div>
  );
}

// ── ReceiptModal — updated with professional print layout ──────────────────────
function ReceiptModal({ tx, onClose, allLoansForLookup }) {
  if (!tx) return null;
  const isOnBlockchain = tx.polygon_tx && tx.network === 'polygon';
  const explorerUrl    = tx.polygon_tx ? `https://polygonscan.com/tx/${tx.polygon_tx}` : null;
  const isFullyPaid    = parseFloat(tx.balance || 0) === 0;
  // ── BAGO: hinahanap ang orihinal na loan record gamit ang loan_code
  // ng payment, para makuha ang "Loan Type" at "Loan Amount" (orihinal
  // na halaga ng loan) — wala kasi ito sa payment record mismo. ───────
  const matchedLoan = (allLoansForLookup||[]).find(l => l.loan_id === (tx.loan_code || tx.loanId));

  const handlePrint = () => {
    // Set print-specific data attributes so CSS can show only the receipt
    document.body.setAttribute('data-printing', 'receipt');
    window.print();
    setTimeout(() => document.body.removeAttribute('data-printing'), 1000);
  };

  return (
    <div className="lp-overlay" onClick={onClose}>
      <div className="lp-modal lp-modal-sm lp-receipt-modal" onClick={e=>e.stopPropagation()}>
        <div className="lp-modal-header no-print">
          <div>
            <div className="lp-modal-title">Transaction Receipt</div>
            <div className="lp-modal-sub mono">{tx.tx_id||tx.txId}</div>
          </div>
          <button className="lp-modal-close" onClick={onClose}><X size={16}/></button>
        </div>

        {/* ── Printable Receipt Area ── */}
        <div className="lp-modal-body lp-printable-receipt" id="receipt-print-area">

          {/* Receipt Header — visible on print */}
          <div className="lp-receipt-print-header">
            <div className="lp-receipt-logo"><img src={logo} alt="LEAF MPC Logo" style={{ height: "35px", width: "300px", objectFit: "contain" }} /></div>
            <div className="lp-receipt-org">LEAF Multi-Purpose Cooperative</div>
            <div className="lp-receipt-org-sub">61 Conception St, Lucban, Quezon Province</div>
            <div className="lp-receipt-title-line">OFFICIAL PAYMENT RECEIPT</div>
            <div className="lp-receipt-tx-id">{tx.tx_id || tx.txId}</div>
          </div>

          {/* Status Banner */}
          {isFullyPaid && (
            <div className="lp-receipt-paid-banner">
              LOAN FULLY PAID
            </div>
          )}

          {/* Member & Loan Info */}
          <div className="lp-receipt-section">
            <div className="lp-receipt-section-title">Member Information</div>
            <div className="lp-receipt-row-item">
              <span className="lp-rk">Member Name</span>
              <span className="lp-rv">{tx.member_name || tx.fullname || "—"}</span>
            </div>
            <div className="lp-receipt-row-item">
              <span className="lp-rk">Member ID</span>
              <span className="lp-rv mono">{tx.member_code || tx.memberId || "—"}</span>
            </div>
            <div className="lp-receipt-row-item">
              <span className="lp-rk">Loan ID</span>
              <span className="lp-rv mono">{tx.loan_code || tx.loanId || "—"}</span>
            </div>
            {/* ── BAGO: Loan Type at Loan Amount (orihinal) — kulang
                dati, hinanap na lang gamit ang loan_code ng payment. ── */}
            <div className="lp-receipt-row-item">
              <span className="lp-rk">Loan Type</span>
              <span className="lp-rv">{matchedLoan?.loan_type || "—"}</span>
            </div>
            <div className="lp-receipt-row-item">
              <span className="lp-rk">Loan Amount</span>
              <span className="lp-rv">{matchedLoan ? `₱${Number(matchedLoan.amount||0).toLocaleString()}` : "—"}</span>
            </div>
          </div>

          <div className="lp-receipt-divider"/>

          {/* Payment Details */}
          <div className="lp-receipt-section">
            <div className="lp-receipt-section-title">Payment Details</div>
            <div className="lp-receipt-row-item">
              <span className="lp-rk">Amount Paid</span>
              <span className="lp-rv green fw">₱{Number(tx.amount||0).toLocaleString(undefined,{minimumFractionDigits:2,maximumFractionDigits:2})}</span>
            </div>
            <div className="lp-receipt-row-item">
              <span className="lp-rk">Balance After</span>
              <span className="lp-rv" style={{color: isFullyPaid ? "#1565c0" : "#c62828", fontWeight:700, display:"inline-flex", alignItems:"center", gap:4}}>
                {isFullyPaid ? <>₱0.00 — FULLY PAID <CheckCircle size={13}/></> : `₱${Number(tx.balance||0).toLocaleString(undefined,{minimumFractionDigits:2,maximumFractionDigits:2})}`}
              </span>
            </div>
            <div className="lp-receipt-row-item">
              <span className="lp-rk">Date & Time</span>
              <span className="lp-rv">{tx.paid_at ? new Date(tx.paid_at).toLocaleString("en-PH", {timeZone:"Asia/Manila",dateStyle:"long",timeStyle:"short"}) : "—"}</span>
            </div>
            <div className="lp-receipt-row-item">
              <span className="lp-rk">Note</span>
              <span className="lp-rv">{tx.note || "—"}</span>
            </div>
            <div className="lp-receipt-row-item">
              <span className="lp-rk">Recorded By</span>
              <span className="lp-rv">{tx.recorded_by || "—"}</span>
            </div>
          </div>

          <div className="lp-receipt-divider"/>

          {/* Blockchain Info */}
          <div className="lp-receipt-section">
            <div className="lp-receipt-section-title">Verification</div>
            <div className="lp-receipt-row-item">
              <span className="lp-rk">SHA-256 Hash</span>
              <span className="lp-rv mono hash-text" style={{fontSize:10,wordBreak:"break-all"}}>{tx.hash || "—"}</span>
            </div>
            <div className="lp-receipt-row-item">
              <span className="lp-rk">Blockchain</span>
              <span className="lp-rv" style={{display:"inline-flex",alignItems:"center",gap:4}}>{isOnBlockchain ? "Polygon Mainnet" : <><AlertTriangle size={12}/> Local only</>}</span>
            </div>
            {tx.polygon_tx && (
              <div className="lp-receipt-row-item">
                <span className="lp-rk">Polygon TX</span>
                <span className="lp-rv mono hash-text" style={{fontSize:10,wordBreak:"break-all"}}>{tx.polygon_tx}</span>
              </div>
            )}
            {tx.block_number && (
              <div className="lp-receipt-row-item">
                <span className="lp-rk">Block Number</span>
                <span className="lp-rv mono">{tx.block_number}</span>
              </div>
            )}
          </div>

          {/* Polygonscan link — screen only */}
          {explorerUrl && (
            <div className="no-print" style={{marginTop:12,textAlign:'center'}}>
              <a href={explorerUrl} target="_blank" rel="noopener noreferrer" style={{color:'#7c3aed',fontWeight:600,fontSize:13,display:"inline-flex",alignItems:"center",gap:6}}>
                <Link size={13}/> View on Polygonscan
              </a>
            </div>
          )}

          {/* Print Footer */}
          <div className="lp-receipt-print-footer">
            <div className="lp-receipt-footer-line">Thank you for your payment!</div>
            <div className="lp-receipt-footer-sub">LEAF MPC · 61 Conception St, Lucban, Quezon Province · 09153810368</div>
            <div className="lp-receipt-footer-sub">This is an official receipt. Please keep for your records.</div>
            <div className="lp-receipt-footer-sub" style={{marginTop:24,borderTop:"1px solid #ccc",paddingTop:8}}>
              Received by: _______________________
            </div>
          </div>
        </div>

        <div className="lp-modal-footer no-print">
          <button className="lp-btn-cancel" onClick={onClose}>Close</button>
          <button className="lp-btn-print" onClick={handlePrint} style={{display:"flex",alignItems:"center",gap:6,justifyContent:"center"}}><Printer size={14}/> Print Receipt</button>
        </div>
      </div>
    </div>
  );
}

function parsePaidAtDate(paid_at) {
  if (!paid_at) return "Unknown";
  const d = new Date(paid_at);
  if (isNaN(d.getTime())) return paid_at.split("T")[0] || "Unknown";
  return d.toLocaleDateString("en-CA", { timeZone: "Asia/Manila" });
}

function groupByDate(transactions) {
  const groups = {};
  transactions.forEach(tx => {
    const dateStr = parsePaidAtDate(tx.paid_at);
    if (!groups[dateStr]) groups[dateStr] = [];
    groups[dateStr].push(tx);
  });
  return Object.entries(groups).sort((a, b) => {
    const maxIdA = Math.max(...a[1].map(t => t.id || 0));
    const maxIdB = Math.max(...b[1].map(t => t.id || 0));
    return maxIdB - maxIdA;
  });
}

function formatDateLabel(dateStr) {
  if (dateStr === "Unknown") return "Unknown Date";
  const todayStr     = new Date().toLocaleDateString("en-CA", { timeZone: "Asia/Manila" });
  const yesterdayD   = new Date();
  yesterdayD.setDate(yesterdayD.getDate() - 1);
  const yesterdayStr = yesterdayD.toLocaleDateString("en-CA", { timeZone: "Asia/Manila" });
  if (dateStr === todayStr)     return "Today";
  if (dateStr === yesterdayStr) return "Yesterday";
  const date = new Date(dateStr + "T00:00:00");
  return date.toLocaleDateString("en-PH", { weekday:"long", year:"numeric", month:"long", day:"numeric" });
}

function DailyGroup({ dateStr, txList, onViewTx }) {
  const [expanded, setExpanded] = useState(true);
  const dailyTotal = txList.reduce((s, t) => s + parseFloat(t.amount || 0), 0);
  return (
    <div className="lp-daily-group">
      <div className="lp-daily-header" onClick={() => setExpanded(e => !e)}>
        <div className="lp-daily-header-left">
          <span className="lp-daily-chevron">{expanded ? <ChevronUp size={14}/> : <ChevronDown size={14}/>}</span>
          <span className="lp-daily-date">{formatDateLabel(dateStr)}</span>
          <span className="lp-daily-date-sub">{dateStr !== "Unknown" ? dateStr : ""}</span>
        </div>
        <div className="lp-daily-header-right">
          <span className="lp-daily-count">{txList.length} transaction{txList.length !== 1 ? "s" : ""}</span>
          <span className="lp-daily-total">₱{dailyTotal.toLocaleString(undefined, {minimumFractionDigits:2, maximumFractionDigits:2})}</span>
        </div>
      </div>
      {expanded && (
        <table className="lp-table history-table lp-daily-table">
          <thead>
            <tr>
              <th style={{width:"16%"}}>TX ID</th>
              <th style={{width:"11%"}}>Loan ID</th>
              <th style={{width:"11%"}}>Member ID</th>
              <th style={{width:"18%"}}>Full Name</th>
              <th style={{width:"9%"}}>Amount</th>
              <th style={{width:"10%"}}>Balance After</th>
              <th style={{width:"13%"}}>Time</th>
              <th style={{width:"8%"}}>Hash</th>
              <th style={{width:"4%",textAlign:"center"}}>View</th>
            </tr>
          </thead>
          <tbody>
            {txList.map((t, idx) => (
              <tr key={t.id||t.txId} className={idx % 2 === 0 ? "row-even" : "row-odd"}>
                <td className="mono cell-id">{t.tx_id}</td>
                <td className="mono">{t.loan_code}</td>
                <td className="mono">{t.member_code}</td>
                <td className="cell-name">{t.member_name}</td>
                <td className="fw green">₱{Number(t.amount||0).toLocaleString()}</td>
                <td className="blue">₱{Number(t.balance||0).toLocaleString()}</td>
                <td className="cell-date">{t.paid_at ? new Date(t.paid_at).toLocaleTimeString("en-PH", {timeZone:"Asia/Manila", hour:"2-digit", minute:"2-digit", second:"2-digit", hour12:false}) : "—"}</td>
                <td><span className="hash-text" style={{display:"inline-flex",alignItems:"center",gap:3}}>{t.polygon_tx ? <><Link size={10}/> {t.polygon_tx.slice(0,10)}...</> : t.hash?.substring(0,16)+'...'}</span></td>
                <td style={{textAlign:"center"}}><button className="lp-view-btn" onClick={() => onViewTx(t)}><Eye size={12}/></button></td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </div>
  );
}

function LoanHistoryRow({ loan, transactions, idx }) {
  const [expanded, setExpanded] = useState(false);
  const payments  = transactions.filter(p => String(p.loan_code).trim() === String(loan.loan_id).trim());
  const totalPaid = payments.reduce((s,p) => s + parseFloat(p.amount||0), 0);
  const isPaid    = loan.status === "Completed" || parseFloat(loan.balance||0) === 0;

  const statusColor = { Active:"#2e7d32", Overdue:"#c62828", Completed:"#1565c0", "For Review":"#e65100", Declined:"#757575" };
  const statusBg    = { Active:"#e8f5e9", Overdue:"#ffebee", Completed:"#e3f2fd", "For Review":"#fff8e1", Declined:"#f5f5f5" };
  const sc = isPaid ? "#1565c0" : (statusColor[loan.status] || "#555");
  const sb = isPaid ? "#e3f2fd" : (statusBg[loan.status]   || "#f5f5f5");

  return (
    <div style={{borderRadius:10, border:`1px solid ${expanded?"#a5d6a7":"#e0e0e0"}`, overflow:"hidden", marginBottom:8, transition:"border 0.2s"}}>
      <div onClick={() => setExpanded(e => !e)} style={{
        display:"grid", gridTemplateColumns:"1.5fr 1fr 1fr 1fr 1fr auto",
        padding:"10px 14px", cursor:"pointer", gap:8,
        background: expanded ? "#f1f8e9" : idx%2===0 ? "#fff" : "#fafafa",
        alignItems:"center",
      }}>
        <div>
          <div style={{fontFamily:"monospace",color:"#1b5e20",fontWeight:700,fontSize:12}}>{loan.loan_id}</div>
          <div style={{fontSize:10,color:"#888",marginTop:1}}>{loan.member_name} · {loan.member_code}</div>
        </div>
        <div>
          <div style={{fontSize:10,color:"#999"}}>Type</div>
          <div style={{fontSize:11,fontWeight:600}}>{loan.loan_type}</div>
        </div>
        <div>
          <div style={{fontSize:10,color:"#999"}}>Amount</div>
          <div style={{fontWeight:700,fontSize:13}}>₱{Number(loan.amount||0).toLocaleString()}</div>
        </div>
        <div>
          <div style={{fontSize:10,color:"#999"}}>Balance</div>
          <div style={{fontWeight:700,fontSize:13,color:isPaid?"#2e7d32":"#c62828",display:"flex",alignItems:"center",gap:4}}>
            {isPaid ? <>₱0 <CheckCircle size={12}/></> : `₱${Number(loan.balance||0).toLocaleString()}`}
          </div>
        </div>
        <div>
          <span style={{background:sb,color:sc,border:`1px solid ${sc}33`,borderRadius:20,padding:"3px 10px",fontSize:11,fontWeight:700}}>
            {isPaid?"Completed":loan.status}
          </span>
        </div>
        <div style={{fontSize:13,color:"#bbb",userSelect:"none",paddingRight:4}}>
          {expanded ? <ChevronUp size={14}/> : <ChevronDown size={14}/>}
        </div>
      </div>
      {expanded && (
        <div style={{borderTop:"1px solid #e8f5e9",background:"#f9fef9"}}>
          <div style={{padding:"8px 14px 4px",fontSize:11,fontWeight:700,color:"#2e7d32",display:"flex",alignItems:"center",gap:8}}>
            <CreditCard size={13}/> Payment History — {loan.loan_id}
            <span style={{fontWeight:400,color:"#aaa",fontSize:10}}>({payments.length} payment{payments.length!==1?"s":""})</span>
          </div>
          {payments.length === 0 ? (
            <div style={{padding:"12px 14px",color:"#bbb",fontSize:12,textAlign:"center"}}>No payments recorded yet.</div>
          ) : (
            <table style={{width:"100%",borderCollapse:"collapse",fontSize:11}}>
              <thead>
                <tr style={{background:"#e8f5e9"}}>
                  <th style={{padding:"6px 14px",textAlign:"left",color:"#558b2f",fontWeight:600}}>Date</th>
                  <th style={{padding:"6px 14px",textAlign:"left",color:"#558b2f",fontWeight:600}}>TX ID</th>
                  <th style={{padding:"6px 14px",textAlign:"right",color:"#558b2f",fontWeight:600}}>Amount Paid</th>
                  <th style={{padding:"6px 14px",textAlign:"right",color:"#558b2f",fontWeight:600}}>Balance After</th>
                  <th style={{padding:"6px 14px",textAlign:"left",color:"#558b2f",fontWeight:600}}>Recorded By</th>
                  <th style={{padding:"6px 14px",textAlign:"left",color:"#558b2f",fontWeight:600}}>Note</th>
                </tr>
              </thead>
              <tbody>
                {payments.map((p,pi) => (
                  <tr key={p.tx_id||pi} style={{background:pi%2===0?"#fff":"#f1f8e9",borderTop:"1px solid #e8f5e9"}}>
                    <td style={{padding:"6px 14px",color:"#666",fontSize:10}}>{p.paid_at?.slice(0,10)}</td>
                    <td style={{padding:"6px 14px",fontFamily:"monospace",color:"#1b5e20",fontSize:10}}>{p.tx_id}</td>
                    <td style={{padding:"6px 14px",textAlign:"right",fontWeight:700,color:"#2e7d32"}}>₱{Number(p.amount||0).toLocaleString()}</td>
                    <td style={{padding:"6px 14px",textAlign:"right",fontWeight:600,color:parseFloat(p.balance||0)===0?"#1565c0":"#c62828",display:"flex",alignItems:"center",justifyContent:"flex-end",gap:3}}>
                      {parseFloat(p.balance||0)===0?<>₱0 <CheckCircle size={11}/></>:` ₱${Number(p.balance||0).toLocaleString()}`}
                    </td>
                    <td style={{padding:"6px 14px",color:"#888",fontSize:10}}>{p.recorded_by||"—"}</td>
                    <td style={{padding:"6px 14px",color:"#aaa",fontSize:10}}>{p.note||"—"}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
          <div style={{padding:"8px 14px",display:"flex",gap:16,fontSize:11,color:"#888",borderTop:"1px solid #e8f5e9",flexWrap:"wrap"}}>
            <span>Monthly Due: <strong style={{color:"#555"}}>₱{Number(loan.monthly_due||0).toLocaleString()}</strong></span>
            <span>Total Paid: <strong style={{color:"#2e7d32"}}>₱{totalPaid.toLocaleString()}</strong></span>
            <span>Remaining: <strong style={{color:isPaid?"#1565c0":"#c62828",display:"inline-flex",alignItems:"center",gap:4}}>{isPaid?<>₱0 — Fully Paid <CheckCircle size={12}/></>:`₱${Number(loan.balance||0).toLocaleString()}`}</strong></span>
          </div>
        </div>
      )}
    </div>
  );
}

export default function LoanPayment() {
  const [loans,           setLoans]          = useState([]);
  const [allLoans,        setAllLoans]       = useState([]);
  const [allLoansLoading, setAllLoansLoading]= useState(false);
  const [allLoansFetched, setAllLoansFetched]= useState(false);
  const [transactions,    setTx]             = useState([]);
  const [pStats,          setPStats]         = useState({ total_collected:0, transaction_count:0 });
  const [loading,         setLoading]        = useState(true);
  const [activeTab,       setTab]            = useState("loans");
  const [search,          setSearch]         = useState("");
  const [filterStatus,    setFilter]         = useState("All");
  const [loanHistFilter,  setLoanHistFilter] = useState("All");
  const [page,            setPage]           = useState(1);
  const [recordLoan,      setRecord]         = useState(null);
  const [viewTx,          setViewTx]         = useState(null);
  const [toast,           setToast]          = useState(null);
  const [historyView,     setHistoryView]    = useState("daily");
  const [loanHistory,     setLoanHistory]    = useState(null);
  const [loanHistoryData, setLoanHistoryData]= useState([]);

  const handleViewLoanHistory = (e, loan) => {
    e.stopPropagation();
    const filtered = transactions.filter(
      p => String(p.loan_code).trim() === String(loan.loan_id).trim()
    );
    setLoanHistoryData(filtered);
    setLoanHistory(loan);
  };

  const showToast = (msg,type="success") => { setToast({msg,type}); setTimeout(()=>setToast(null),3500); };

  const fetchData = async () => {
    setLoading(true);
    try {
      const [lActive, lOverdue, t, s] = await Promise.allSettled([
        getLoansAPI({ status: "Active" }),
        getLoansAPI({ status: "Overdue" }),
        getPaymentsAPI(),
        getPaymentStatsAPI(),
      ]);
      const activeLoans  = lActive.status  === "fulfilled" ? lActive.value  : [];
      const overdueLoans = lOverdue.status === "fulfilled" ? lOverdue.value : [];
      setLoans([...activeLoans, ...overdueLoans]);
      if (t.status==="fulfilled") setTx(t.value);
      if (s.status==="fulfilled") setPStats(s.value);
    } catch(e) { console.error(e); }
    finally { setLoading(false); }
  };

  const fetchAllLoans = async () => {
    if (allLoansFetched) return;
    setAllLoansLoading(true);
    try {
      const [active, overdue, completed, declined] = await Promise.allSettled([
        getLoansAPI({ status: "Active" }),
        getLoansAPI({ status: "Overdue" }),
        getLoansAPI({ status: "Completed" }),
        getLoansAPI({ status: "Declined" }),
      ]);
      const all = [
        ...(active.status    === "fulfilled" ? active.value    : []),
        ...(overdue.status   === "fulfilled" ? overdue.value   : []),
        ...(completed.status === "fulfilled" ? completed.value : []),
        ...(declined.status  === "fulfilled" ? declined.value  : []),
      ].sort((a,b) => b.id - a.id);
      setAllLoans(all);
      setAllLoansFetched(true);
    } catch(e) { console.error(e); }
    finally { setAllLoansLoading(false); }
  };

  useEffect(() => { fetchData(); }, []);
  // ── BAGO: proactive na kinukuha ang "allLoans" (kasama ang mga
  // Completed na loan) tuwing bubuksan ang isang receipt — dati,
  // hindi ito na-fefetch hangga't hindi binibisita ang "Loan History"
  // tab, kaya walang makikitang Loan Type/Amount kung fully-paid na
  // pala ang loan (wala na ito sa "Active Loans" list). ─────────────
  useEffect(() => { if (viewTx) fetchAllLoans(); }, [viewTx]);

  const totalCollected   = parseFloat(pStats.total_collected||0);
  const overdueCount     = loans.filter(l=>l.status==="Overdue").length;
  const totalOutstanding = loans.reduce((s,l)=>s+parseFloat(l.balance||0),0);

  // ── FIX: After save, auto-show receipt modal ──────────────────────────────
  const handleSave = async ({ loan, amount, note }) => {
    try {
      const payment = await recordPaymentAPI({ loan: loan.id, member: loan.member, amount, note });
      setRecord(null);
      showToast(`Payment of ₱${amount.toLocaleString()} recorded successfully.`);

      const newBalance  = Math.max(0, parseFloat(loan.balance||0) - amount);
      const isFullyPaid = newBalance <= 0;

      setLoans(prev =>
        prev.map(l => l.id === loan.id ? { ...l, balance: newBalance, status: isFullyPaid ? "Completed" : l.status } : l)
            .filter(l => l.status !== "Completed")
      );

      if (payment) {
        const normalized = {
          ...payment,
          member_name: payment.member_name || loan.member_name || "",
          member_code: payment.member_code || loan.member_code || "",
          loan_code:   payment.loan_code   || loan.loan_id     || "",
          paid_at:     payment.paid_at     || new Date().toISOString(),
        };
        setTx(prev => [normalized, ...prev]);

        if (loanHistory && loanHistory.id === loan.id) {
          setLoanHistoryData(prev => [normalized, ...prev]);
          setLoanHistory(prev => ({ ...prev, balance: newBalance }));
        }

        // ── Auto-show receipt modal after successful payment ──
        setViewTx(normalized);
      }

      setPStats(prev => ({
        ...prev,
        total_collected:   (parseFloat(prev.total_collected||0) + amount).toFixed(2),
        transaction_count: (parseInt(prev.transaction_count||0) + 1),
      }));
    } catch { showToast("Failed to record payment.", "danger"); }
  };

  const filteredLoans = loans.filter(l => {
    const matchS = filterStatus==="All" || l.status===filterStatus;
    const q = search.toLowerCase();
    return matchS && (
      (l.loan_id||"").toLowerCase().includes(q) ||
      (l.member_name||"").toLowerCase().includes(q) ||
      (l.member_code||"").toLowerCase().includes(q) ||
      (l.loan_type||"").toLowerCase().includes(q)
    );
  });

  const filteredTx = transactions.filter(t => {
    const q = search.toLowerCase();
    return (t.tx_id||"").toLowerCase().includes(q) ||
           (t.member_name||"").toLowerCase().includes(q) ||
           (t.loan_code||"").toLowerCase().includes(q);
  });

  const filteredAllLoans = allLoans.filter(l => {
    const matchS = loanHistFilter==="All" || l.status===loanHistFilter;
    const q = search.toLowerCase();
    return matchS && (
      (l.loan_id||"").toLowerCase().includes(q) ||
      (l.member_name||"").toLowerCase().includes(q) ||
      (l.member_code||"").toLowerCase().includes(q)
    );
  });

  const totalPages     = Math.max(1, Math.ceil((activeTab==="loans" ? filteredLoans : filteredTx).length / ROWS_PER_PAGE));
  const safePage       = Math.min(page, totalPages);
  const paginatedLoans = filteredLoans.slice((safePage-1)*ROWS_PER_PAGE, safePage*ROWS_PER_PAGE);
  const paginatedTx    = filteredTx.slice((safePage-1)*ROWS_PER_PAGE, safePage*ROWS_PER_PAGE);

  const switchTab = tab => {
    setTab(tab); setPage(1); setSearch(""); setFilter("All");
    if (tab === "loanhistory") fetchAllLoans();
  };

  const dailyGroups = groupByDate(filteredTx);

  const Pagination = ({ list }) => (
    <div className="lp-footer">
      <div className="lp-count">
        Showing {list.length===0?0:(safePage-1)*ROWS_PER_PAGE+1}–{Math.min(safePage*ROWS_PER_PAGE,list.length)} of {list.length} record{list.length!==1?"s":""}
      </div>
      <div className="lp-pagination">
        <button className="lp-page-btn" disabled={safePage===1} onClick={()=>setPage(p=>p-1)}>← Prev</button>
        {Array.from({length:totalPages},(_,i)=>i+1)
          .filter(p=>p===1||p===totalPages||Math.abs(p-safePage)<=1)
          .reduce((acc,p,i,arr)=>{if(i>0&&p-arr[i-1]>1)acc.push("...");acc.push(p);return acc;},[])
          .map((p,i)=>p==="..."
            ? <span key={`e${i}`} className="lp-ellipsis">…</span>
            : <button key={p} className={`lp-page-btn lp-page-num ${safePage===p?"active":""}`} onClick={()=>setPage(p)}>{p}</button>
          )}
        <button className="lp-page-btn" disabled={safePage===totalPages} onClick={()=>setPage(p=>p+1)}>Next →</button>
      </div>
    </div>
  );

  const LoanHistoryModal = () => {
    if (!loanHistory) return null;
    return (
      <div className="lp-overlay" onClick={() => setLoanHistory(null)}>
        <div className="lp-modal" onClick={e => e.stopPropagation()}>
          <div className="lp-modal-header">
            <div>
              <div className="lp-modal-title">Payment History</div>
              <div className="lp-modal-sub">{loanHistory.loan_id} · {loanHistory.member_name}</div>
            </div>
            <button className="lp-modal-close" onClick={() => setLoanHistory(null)}><X size={16}/></button>
          </div>
          <div className="lp-modal-body">
            <div className="lp-balance-row">
              <div className="lp-bal-item"><span className="lp-bal-label">Loan Amount</span><span className="lp-bal-val">₱{Number(loanHistory.amount||0).toLocaleString()}</span></div>
              <div className="lp-bal-item highlight"><span className="lp-bal-label">Remaining Balance</span><span className="lp-bal-val danger">₱{Number(loanHistory.balance||0).toLocaleString()}</span></div>
              <div className="lp-bal-item"><span className="lp-bal-label">Monthly Due</span><span className="lp-bal-val green">₱{Number(loanHistory.monthly_due||0).toLocaleString()}</span></div>
            </div>
            {loanHistoryData.length === 0 ? (
              <div style={{textAlign:"center",padding:"24px",color:"#aaa"}}>No payments recorded yet.</div>
            ) : (
              <table style={{width:"100%",borderCollapse:"collapse",marginTop:12}}>
                <thead>
                  <tr style={{background:"#f9fef9"}}>
                    <th style={{fontSize:10,color:"#aaa",fontWeight:700,padding:"8px 6px",textAlign:"left",borderBottom:"1px solid #e8f5e9"}}>Date</th>
                    <th style={{fontSize:10,color:"#aaa",fontWeight:700,padding:"8px 6px",textAlign:"left",borderBottom:"1px solid #e8f5e9"}}>TX ID</th>
                    <th style={{fontSize:10,color:"#aaa",fontWeight:700,padding:"8px 6px",textAlign:"right",borderBottom:"1px solid #e8f5e9"}}>Amount</th>
                    <th style={{fontSize:10,color:"#aaa",fontWeight:700,padding:"8px 6px",textAlign:"right",borderBottom:"1px solid #e8f5e9"}}>Balance After</th>
                    <th style={{fontSize:10,color:"#aaa",fontWeight:700,padding:"8px 6px",textAlign:"left",borderBottom:"1px solid #e8f5e9"}}>Note</th>
                  </tr>
                </thead>
                <tbody>
                  {loanHistoryData.map((p,i) => (
                    <tr key={i} style={{borderBottom:"1px solid #f5f5f5"}}>
                      <td style={{fontSize:11,color:"#555",padding:"8px 6px"}}>{p.paid_at?.slice(0,10)}</td>
                      <td style={{fontSize:10,color:"#888",padding:"8px 6px",fontFamily:"monospace"}}>{p.tx_id}</td>
                      <td style={{fontSize:12,fontWeight:700,color:"#2e7d32",padding:"8px 6px",textAlign:"right"}}>₱{Number(p.amount||0).toLocaleString()}</td>
                      <td style={{fontSize:12,color:"#1565c0",padding:"8px 6px",textAlign:"right"}}>₱{Number(p.balance||0).toLocaleString()}</td>
                      <td style={{fontSize:11,color:"#888",padding:"8px 6px"}}>{p.note||"—"}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
            <div style={{marginTop:12,fontSize:12,color:"#888",textAlign:"right"}}>
              {loanHistoryData.length} payment{loanHistoryData.length!==1?"s":""} · Total: <strong style={{color:"#2e7d32"}}>₱{loanHistoryData.reduce((s,p)=>s+Number(p.amount||0),0).toLocaleString()}</strong>
            </div>
          </div>
          <div className="lp-modal-footer">
            <button className="lp-btn-cancel" onClick={() => setLoanHistory(null)}>Close</button>
          </div>
        </div>
      </div>
    );
  };

  return (
    <div className="lp-wrapper">
      {toast && <div className={`lp-toast lp-toast-${toast.type}`}>{toast.msg}</div>}
      <RecordModal loan={recordLoan} onClose={()=>setRecord(null)} onSave={handleSave}/>
      <LoanHistoryModal/>
      <ReceiptModal tx={viewTx} onClose={()=>setViewTx(null)} allLoansForLookup={[...loans, ...allLoans]}/>

      <div className="lp-page-header">
        <div>
          <div className="lp-page-title">Loan Payment</div>
          <div className="lp-page-sub">Record and track F2F loan payments collected at the office.</div>
        </div>
      </div>

      <div className="lp-summary-grid">
        <div className="lp-summary-card"><div className="lp-sum-icon" style={{background:"#e8f5e9",display:"flex",alignItems:"center",justifyContent:"center"}}><Wallet size={20} color="#2e7d32"/></div><div><div className="lp-sum-val">₱{totalCollected.toLocaleString()}</div><div className="lp-sum-label">Total Collected</div></div></div>
        <div className="lp-summary-card clickable" onClick={()=>{switchTab("loans");setFilter("Overdue");}}><div className="lp-sum-icon" style={{background:"#fce4ec",display:"flex",alignItems:"center",justifyContent:"center"}}><AlertTriangle size={20} color="#c62828"/></div><div><div className="lp-sum-val danger">{overdueCount}</div><div className="lp-sum-label">Overdue Loans</div></div></div>
        <div className="lp-summary-card"><div className="lp-sum-icon" style={{background:"#e3f2fd",display:"flex",alignItems:"center",justifyContent:"center"}}><BarChart3 size={20} color="#1565c0"/></div><div><div className="lp-sum-val blue">₱{totalOutstanding.toLocaleString()}</div><div className="lp-sum-label">Total Outstanding</div></div></div>
        <div className="lp-summary-card clickable" onClick={()=>switchTab("history")}><div className="lp-sum-icon" style={{background:"#f3e5f5",display:"flex",alignItems:"center",justifyContent:"center"}}><Receipt size={20} color="#6a1b9a"/></div><div><div className="lp-sum-val purple">{transactions.length}</div><div className="lp-sum-label">Transactions Recorded</div></div></div>
      </div>

      <div className="lp-card">
        <div className="lp-toolbar">
          <div className="lp-tabs">
            <button className={`lp-tab ${activeTab==="loans"?"active":""}`} onClick={()=>switchTab("loans")}>
              Active Loans <span className="lp-tab-count">{loans.length}</span>
            </button>
            <button className={`lp-tab ${activeTab==="history"?"active":""}`} onClick={()=>switchTab("history")}>
              Payment History <span className="lp-tab-count">{transactions.length}</span>
            </button>
            <button className={`lp-tab ${activeTab==="loanhistory"?"active":""}`} onClick={()=>switchTab("loanhistory")}>
              <History size={12}/> Loan History <span className="lp-tab-count">{allLoans.length||""}</span>
            </button>
          </div>
          <div className="lp-toolbar-right">
            <div className="lp-search-wrap">
              <span className="lp-search-icon"><Search size={13} color="#aaa"/></span>
              <input className="lp-search-input" placeholder="Search..." value={search} onChange={e=>{setSearch(e.target.value);setPage(1);}}/>
              {search && <button className="lp-clear-btn" onClick={()=>{setSearch("");setPage(1);}}><X size={13}/></button>}
            </div>
            {activeTab==="history" && (
              <div className="lp-filter-tabs">
                <button className={`lp-filter-tab ${historyView==="daily"?"active ftab-all":""}`} onClick={()=>setHistoryView("daily")} style={{display:"inline-flex",alignItems:"center",gap:6}}><Calendar size={13}/> Daily View</button>
                <button className={`lp-filter-tab ${historyView==="all"?"active ftab-all":""}`} onClick={()=>setHistoryView("all")} style={{display:"inline-flex",alignItems:"center",gap:6}}><ClipboardList size={13}/> All Transactions</button>
              </div>
            )}
            {activeTab==="loanhistory" && (
              <div className="lp-filter-tabs">
                {["All","Active","Overdue","Completed","Declined"].map(s=>(
                  <button key={s} className={`lp-filter-tab ${loanHistFilter===s?"active ftab-all":""}`} onClick={()=>setLoanHistFilter(s)}>{s}</button>
                ))}
              </div>
            )}
          </div>
        </div>

        {activeTab==="loans" && (
          <div className="lp-table-wrap">
            <table className="lp-table">
              <thead><tr>
                <th style={{width:"11%"}}>Loan ID</th>
                <th style={{width:"9%"}}>Member ID</th>
                <th style={{width:"12%"}}>Full Name</th>
                <th style={{width:"11%"}}>Loan Type</th>
                <th style={{width:"6%"}}>Term</th>
                <th style={{width:"9%"}}>Amount</th>
                <th style={{width:"9%"}}>Balance</th>
                <th style={{width:"9%"}}>Monthly Due</th>
                <th style={{width:"6%"}}>Status</th>
                <th style={{width:"8%",textAlign:"center"}}>Action</th>
              </tr></thead>
              <tbody>
                {loading ? <tr><td colSpan={10} className="lp-empty">Loading...</td></tr>
                : paginatedLoans.length===0 ? <tr><td colSpan={10} className="lp-empty">No loans found.</td></tr>
                : paginatedLoans.map((l,idx)=>(
                  <tr key={l.id}
                    className={`${idx%2===0?"row-even":"row-odd"} lp-clickable-row`}
                    onClick={()=>{ if(parseFloat(l.balance||0)>0) setRecord(l); }}
                    style={{cursor: parseFloat(l.balance||0)>0 ? "pointer" : "default"}}
                    title={parseFloat(l.balance||0)>0 ? "Click to record payment" : "Fully paid"}
                  >
                    <td className="mono cell-id">{l.loan_id}</td>
                    <td className="mono">{l.member_code}</td>
                    <td className="cell-name">{l.member_name}</td>
                    <td><span className="lp-type-pill">{l.loan_type}</span></td>
                    <td className="fw">{l.term_months||"—"} months</td>
                    <td className="fw">₱{Number(l.amount||0).toLocaleString()}</td>
                    <td className={`fw ${l.status==="Overdue"?"danger":"blue"}`}>₱{Number(l.balance||0).toLocaleString()}</td>
                    <td className="fw green">₱{Number(l.monthly_due||0).toLocaleString()}</td>
                    <td><span className={`lp-loan-badge lp-${(l.status||"").toLowerCase()}`}>{l.status}</span></td>
                    <td style={{textAlign:"center"}} onClick={e=>e.stopPropagation()}>
                      <button className="lp-view-btn" onClick={e=>handleViewLoanHistory(e,l)} title="View payment history">
                        <Eye size={12}/>
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}

        {activeTab==="history" && historyView==="daily" && (
          <div className="lp-daily-view">
            {loading ? <div className="lp-empty">Loading...</div>
            : dailyGroups.length===0 ? <div className="lp-empty">No transactions found.</div>
            : dailyGroups.map(([dateStr, txList]) => (
              <DailyGroup key={dateStr} dateStr={dateStr} txList={txList} onViewTx={setViewTx}/>
            ))}
          </div>
        )}

        {activeTab==="history" && historyView==="all" && (
          <div className="lp-table-wrap">
            <table className="lp-table history-table">
              <thead><tr>
                <th style={{width:"16%"}}>TX ID</th>
                <th style={{width:"11%"}}>Loan ID</th>
                <th style={{width:"11%"}}>Member ID</th>
                <th style={{width:"16%"}}>Full Name</th>
                <th style={{width:"9%"}}>Amount</th>
                <th style={{width:"10%"}}>Balance After</th>
                <th style={{width:"13%"}}>Date & Time</th>
                <th style={{width:"10%"}}>Hash</th>
                <th style={{width:"4%",textAlign:"center"}}>View</th>
              </tr></thead>
              <tbody>
                {loading ? <tr><td colSpan={9} className="lp-empty">Loading...</td></tr>
                : paginatedTx.length===0 ? <tr><td colSpan={9} className="lp-empty">No transactions found.</td></tr>
                : paginatedTx.map((t,idx)=>(
                  <tr key={t.id||t.txId} className={idx%2===0?"row-even":"row-odd"}>
                    <td className="mono cell-id">{t.tx_id}</td>
                    <td className="mono">{t.loan_code}</td>
                    <td className="mono">{t.member_code}</td>
                    <td className="cell-name">{t.member_name}</td>
                    <td className="fw green">₱{Number(t.amount||0).toLocaleString()}</td>
                    <td className="blue">₱{Number(t.balance||0).toLocaleString()}</td>
                    <td className="cell-date">{t.paid_at}</td>
                    <td><span className="hash-text" style={{display:"inline-flex",alignItems:"center",gap:3}}>{t.polygon_tx ? <><Link size={10}/> {t.polygon_tx.slice(0,10)}...</> : t.hash}</span></td>
                    <td style={{textAlign:"center"}}><button className="lp-view-btn" onClick={()=>setViewTx(t)}><Eye size={12}/></button></td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}

        {activeTab==="loanhistory" && (
          <div style={{padding:"12px 16px"}}>
            {allLoansLoading ? (
              <div className="lp-empty">Loading loan history...</div>
            ) : filteredAllLoans.length === 0 ? (
              <div className="lp-empty">No loans found.</div>
            ) : (
              <>
                <div style={{fontSize:12,color:"#888",marginBottom:10,fontWeight:600}}>
                  {filteredAllLoans.length} loan{filteredAllLoans.length!==1?"s":""} found · Click a row to see payment history
                </div>
                {filteredAllLoans.map((loan, idx) => (
                  <LoanHistoryRow key={loan.id} loan={loan} transactions={transactions} idx={idx}/>
                ))}
              </>
            )}
          </div>
        )}

        {activeTab==="loans" && <Pagination list={filteredLoans}/>}
        {activeTab==="history" && historyView==="all" && <Pagination list={filteredTx}/>}

        {activeTab==="history" && historyView==="daily" && (
          <div className="lp-footer">
            <div className="lp-count">
              {dailyGroups.length} day{dailyGroups.length!==1?"s":""} · {filteredTx.length} total transaction{filteredTx.length!==1?"s":""}
            </div>
            <div className="lp-daily-grand-total">
              Grand Total: <strong>₱{filteredTx.reduce((s,t)=>s+parseFloat(t.amount||0),0).toLocaleString(undefined,{minimumFractionDigits:2,maximumFractionDigits:2})}</strong>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}