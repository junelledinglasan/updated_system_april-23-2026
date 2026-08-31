import { useState, useEffect } from "react";
import { useOutletContext } from "react-router-dom";
import { getMyProfileAPI } from "../../api/members";
import { createLoanAPI, getLoansAPI, updateLoanAPI } from "../../api/loans";
import { getPaymentsAPI } from "../../api/payments";
import { useLanguage } from "../../context/LanguageContext";
import { useAuth } from "../../context/AuthContext";
import { getPageCache, savePageCache } from "../../utils/pageCache";
import { Home, AlertTriangle, Briefcase, HardHat, Store, CheckCircle, XCircle } from "lucide-react";
import "./LoanApplication.css";

// ── BAGO: "descKey" imbes na "desc" — dahil module-level constant ito
// (walang access sa t() sa labas ng component), resolve na lang sa
// render time gamit ang t(lt.descKey). ──────────────────────────────
const LOAN_TYPES = [
  { type:"Regular Loan",   icon:<Home          size={26} color="#2e7d32"/>, color:"#e8f5e9", border:"#a5d6a7", descKey:"la_loan_type_regular_desc",   maxAmt:50000,  maxTerm:24 },
  { type:"Emergency Loan", icon:<AlertTriangle size={26} color="#c62828"/>, color:"#fce4ec", border:"#ef9a9a", descKey:"la_loan_type_emergency_desc", maxAmt:20000,  maxTerm:12 },
  { type:"Salary Loan",    icon:<Briefcase     size={26} color="#1565c0"/>, color:"#e3f2fd", border:"#90caf9", descKey:"la_loan_type_salary_desc",    maxAmt:30000,  maxTerm:12 },
  { type:"Housing Loan",   icon:<HardHat       size={26} color="#e65100"/>, color:"#fff8e1", border:"#ffcc80", descKey:"la_loan_type_housing_desc",   maxAmt:100000, maxTerm:48 },
  { type:"Business Loan",  icon:<Store         size={26} color="#6a1b9a"/>, color:"#f3e5f5", border:"#ce93d8", descKey:"la_loan_type_business_desc",  maxAmt:80000,  maxTerm:36 },
];

// ── BAGO: "key" imbes na "label" — parehong dahilan, resolve sa
// render time via getStatusMeta(status, t). ─────────────────────────
const STATUS_META = {
  "For Review": { bg:"#fff8e1", color:"#e65100", key:"la_status_for_review" },
  "Approved":   { bg:"#fff8e1", color:"#e65100", key:"la_status_approved" },
  "Active":     { bg:"#e8f5e9", color:"#2e7d32", key:"la_status_active" },
  "Declined":   { bg:"#fce4ec", color:"#c62828", key:"la_status_declined" },
  "Completed":  { bg:"#e3f2fd", color:"#1565c0", key:"la_status_completed" },
  "Overdue":    { bg:"#ffebee", color:"#b71c1c", key:"la_status_overdue" },
  "Cancelled":  { bg:"#f5f5f5", color:"#777",    key:"la_status_cancelled" },
};
function getStatusMeta(status, t) {
  const m = STATUS_META[status];
  if (!m) return { bg:"#f5f5f5", color:"#888", label: status };
  return { bg: m.bg, color: m.color, label: t(m.key) };
}

// ─── Eligibility Checker ───────────────────────────────────────────────────────
function checkEligibility(loans, shareCapital, t) {
  const issues = [];
  const passed = [];
  const maxLoanable = shareCapital * 2;

  const activeLoans   = loans.filter(l => l.status === "Active");
  const overdueLoans  = loans.filter(l => l.status === "Overdue");
  const pendingLoans  = loans.filter(l => l.status === "For Review");
  const approvedLoans = loans.filter(l => l.status === "Approved");
  const completedLoans= loans.filter(l => l.status === "Completed");

  if (shareCapital >= 4000) {
    passed.push(t("la_pass_share_capital", { sc: `₱${shareCapital.toLocaleString()}`, max: `₱${maxLoanable.toLocaleString()}` }));
  } else {
    issues.push(t("la_issue_insufficient_sc", { sc: `₱${shareCapital.toLocaleString()}` }));
  }

  if (overdueLoans.length === 0) {
    passed.push(t("la_pass_no_overdue"));
  } else {
    issues.push(t("la_issue_overdue", { n: overdueLoans.length, ids: overdueLoans.map(l => l.loan_id).join(", ") }));
  }

  if (activeLoans.length === 0 && approvedLoans.length === 0 && pendingLoans.length === 0) {
    passed.push(t("la_pass_no_pending"));
  } else {
    if (approvedLoans.length > 0) {
      issues.push(t("la_issue_for_release", { n: approvedLoans.length, ids: approvedLoans.map(l => l.loan_id).join(", ") }));
    }
    const activePending = [...activeLoans, ...pendingLoans];
    if (activePending.length > 0) {
      issues.push(t("la_issue_active_pending", { n: activePending.length, ids: activePending.map(l => l.loan_id).join(", ") }));
    }
  }

  if (completedLoans.length > 0) {
    passed.push(t("la_pass_good_history", { n: completedLoans.length }));
  }

  return { eligible: issues.length === 0, issues, passed, maxLoanable, approvedLoans };
}

// ─── Loan Recommendation Engine ───────────────────────────────────────────────
function getLoanRecommendation(shareCapital, classification, monthlyIncome, loans) {
  const maxLoanable    = shareCapital * 2;
  const completedLoans = loans.filter(l => l.status === "Completed");
  const hasGoodHistory = completedLoans.length > 0;

  let recAmtPct  = hasGoodHistory ? 0.8 : 0.5;
  let recAmount  = Math.floor(maxLoanable * recAmtPct / 1000) * 1000;
  recAmount      = Math.max(3000, Math.min(recAmount, maxLoanable));

  const rate       = recAmount <= 50000 ? 0.0125 : recAmount <= 150000 ? 0.01125 : 0.01;
  const maxMonthly = monthlyIncome * 0.30;

  let recTerm = 12;
  if (monthlyIncome > 0) {
    const denominator = maxMonthly - (rate * recAmount);
    if (denominator > 0) {
      recTerm = Math.ceil(recAmount / denominator);
      const availTerms = [3,6,9,12,18,24,36,48];
      recTerm = availTerms.find(t => t >= recTerm) || 48;
    } else {
      recTerm = 48;
    }
  }

  let recType = "Regular Loan";
  if (classification === "Student")  recType = "Emergency Loan";
  if (classification === "Senior")   recType = "Regular Loan";
  if (classification === "Employed") {
    if (monthlyIncome >= 15000)      recType = "Salary Loan";
    else                             recType = "Regular Loan";
  }

  const interest    = rate * recAmount * recTerm;
  const monthlyDue  = (recAmount + interest) / recTerm;
  const debtRatio   = monthlyIncome > 0 ? (monthlyDue / monthlyIncome) * 100 : 0;

  return {
    amount:       recAmount,
    term:         recTerm,
    type:         recType,
    monthlyDue:   Math.round(monthlyDue),
    debtRatio:    Math.round(debtRatio),
    hasGoodHistory,
    maxLoanable,
    monthlyIncome,
  };
}

export default function LoanApplication() {
  const { t } = useLanguage();
  const { user } = useAuth();
  const ctx = useOutletContext() || {};
  // ── BAGO: cache-first — hindi natin agad alam ang member.id dito
  // (kukunin pa lang sa fetch), kaya gamit muna ang user.id/username
  // mula sa AuthContext bilang scope key, tulad ng ginawa sa
  // MemberProfile.jsx. ─────────────────────────────────────────────
  const scopeKey = user?.id ?? user?.username ?? null;
  const cached = getPageCache("apply-loan", scopeKey);

  const [step,           setStep]          = useState(1);
  const [shareCapital,   setShareCapital]  = useState(cached?.shareCapital || 0);
  const [monthlyIncome,  setMonthlyIncome] = useState(cached?.monthlyIncome || 0);
  const [classification, setClassification]= useState(cached?.classification || "Employed");
  const [loadingProfile, setLoadingProfile]= useState(!cached);
  const [selType,        setSelType]       = useState(null);
  const [form,           setForm]          = useState({ amount:"", term:"12", purpose:"", collateral:"", note:"" });
  const [errors,         setErrors]        = useState({});
  const [submitted,      setDone]          = useState(false);
  const [loading,        setLoading]       = useState(false);
  const [myLoans,        setMyLoans]       = useState(cached?.myLoans || []);
  const [loadingLoans,   setLoadingLoans]  = useState(!cached);
  const [showHistory,    setShowHistory]   = useState(false);
  const [selectedLoan,   setSelectedLoan]  = useState(null);
  const [loanPayments,   setLoanPayments]  = useState([]);
  const [loadingPay,     setLoadingPay]    = useState(false);
  const [editingId,      setEditingId]     = useState(null);
  const [editedNotice,   setEditedNotice]  = useState(false);
  const [cancelTarget,   setCancelTarget]  = useState(null);
  const [cancelling,     setCancelling]    = useState(false);
  const [cancelError,    setCancelError]   = useState("");
  const [formError,      setFormError]     = useState("");
  const [checkingId,     setCheckingId]    = useState(null);
  const [staleNotice,    setStaleNotice]   = useState("");

  useEffect(() => {
    Promise.allSettled([getMyProfileAPI(), getLoansAPI()]).then(([profRes, loansRes]) => {
      let newShareCapital = 0, newIncome = 0, newClassification = "Employed";
      if (profRes.status === "fulfilled") {
        const p = profRes.value;
        newShareCapital = parseFloat(p.share_capital || 0);
        newIncome = parseFloat(
          p.job_profile?.monthly_income ||
          p.senior_profile?.pension_income ||
          p.student_profile?.allowance ||
          p.pre_member_info?.income || 0
        );
        newClassification = p.pre_member_info?.classification || p.classification || "Employed";
        setShareCapital(newShareCapital);
        setMonthlyIncome(newIncome);
        setClassification(newClassification);
      } else {
        setShareCapital(0);
      }
      setLoadingProfile(false);

      const newMyLoans = loansRes.status === "fulfilled" ? loansRes.value : [];
      setMyLoans(newMyLoans);
      setLoadingLoans(false);

      savePageCache("apply-loan", scopeKey, {
        shareCapital: newShareCapital, monthlyIncome: newIncome,
        classification: newClassification, myLoans: newMyLoans,
      });
    });
  }, [scopeKey]);

  const eligibility   = checkEligibility(myLoans, shareCapital, t);
  const recommendation= getLoanRecommendation(shareCapital, classification, monthlyIncome, myLoans);
  const amount       = parseFloat(form.amount) || 0;
  const term         = parseInt(form.term) || 12;
  const selectedType = LOAN_TYPES.find(l => l.type === selType);

  const monthlyRate  = amount <= 50000 ? 0.0125 : amount <= 150000 ? 0.01125 : 0.01;
  const interest     = monthlyRate * amount * term;
  const serviceFee   = amount * 0.03;
  const filingFee    = amount <= 50000 ? 50 : 100;
  const insurance    = amount * 0.0125;
  const sd           = amount * 0.01;
  const sc           = amount * 0.03;
  const totalDed     = interest + serviceFee + filingFee + insurance + sd + sc;
  const netProceeds  = amount - totalDed;
  const monthlyEst   = amount > 0 ? (amount + interest) / term : 0;

  const maxLoanable     = shareCapital * 2;
  const showComputation = amount >= 3000 && amount <= maxLoanable && selType && step === 2;

  const handle = e => setForm(p => ({ ...p, [e.target.name]: e.target.value }));

  const handleAmountChange = e => {
    const digitsOnly = e.target.value.replace(/[^0-9]/g, "");
    if (digitsOnly === "") { setForm(p => ({ ...p, amount: "" })); setErrors(p => ({...p, amount:""})); return; }
    const parsed = parseInt(digitsOnly, 10);
    if (isNaN(parsed)) return;
    if (maxLoanable > 0 && parsed > maxLoanable) return; // tanggihan, huwag baguhin
    setForm(p => ({ ...p, amount: digitsOnly }));
    setErrors(p => ({...p, amount:""}));
  };

  const refreshLoans = async () => {
    try {
      const loans = await getLoansAPI();
      setMyLoans(loans);
      // ── I-sync din ang cache — para hindi maging stale sa susunod
      // na pagbisita, dahil dito madalas nagbabago ang status. ──────
      savePageCache("apply-loan", scopeKey, { shareCapital, monthlyIncome, classification, myLoans: loans });
      return loans;
    } catch {
      return myLoans;
    }
  };

  const handleEditClick = async (loan) => {
    setCheckingId(loan.id);
    setStaleNotice("");
    const loans = await refreshLoans();
    setCheckingId(null);
    const fresh = loans.find(l => l.id === loan.id);
    if (!fresh || fresh.status !== "For Review") {
      setStaleNotice(t("la_stale_notice", { loan_id: loan.loan_id, status: fresh ? fresh.status : "unknown" }));
      return;
    }
    setEditingId(fresh.id);
    setSelType(fresh.loan_type);
    setForm({
      amount:     String(Math.round(parseFloat(fresh.amount) || 0)),
      term:       String(fresh.term_months),
      purpose:    fresh.purpose || "",
      collateral: fresh.collateral || "",
      note:       "",
    });
    setErrors({});
    setFormError("");
    setStep(2);
    setShowHistory(false);
  };

  const handleCancelClick = async (loan) => {
    setCheckingId(loan.id);
    setStaleNotice("");
    const loans = await refreshLoans();
    setCheckingId(null);
    const fresh = loans.find(l => l.id === loan.id);
    if (!fresh || fresh.status !== "For Review") {
      setStaleNotice(t("la_stale_notice", { loan_id: loan.loan_id, status: fresh ? fresh.status : "unknown" }));
      return;
    }
    setCancelTarget(fresh);
    setCancelError("");
  };

  const handleCancelEdit = () => {
    setEditingId(null);
    setStep(1); setSelType(null);
    setForm({ amount:"", term:"12", purpose:"", collateral:"", note:"" });
    setErrors({});
    setFormError("");
  };

  const handleCancelLoan = async () => {
    if (!cancelTarget) return;
    setCancelling(true);
    setCancelError("");
    try {
      await updateLoanAPI(cancelTarget.id, { status: "Cancelled" });
      const loans = await getLoansAPI();
      setMyLoans(loans);
      savePageCache("apply-loan", scopeKey, { shareCapital, monthlyIncome, classification, myLoans: loans });
      setCancelTarget(null);
    } catch (err) {
      setCancelError(err.response?.data?.error || t("la_failed_cancel"));
    } finally {
      setCancelling(false);
    }
  };

  const handleLoanClick = async (loan) => {
    setSelectedLoan(loan);
    setLoadingPay(true);
    try {
      const all = await getPaymentsAPI();
      setLoanPayments(all.filter(p => p.loan_code === loan.loan_id));
    } catch { setLoanPayments([]); }
    finally { setLoadingPay(false); }
  };

  const validate = () => {
    const e = {};
    if (!form.amount || parseFloat(form.amount) < 3000)
      e.amount = t("la_min_amount");
    if (parseFloat(form.amount) > maxLoanable)
      e.amount = t("la_exceeds_max", { amt: `₱${maxLoanable.toLocaleString()}` });
    if (!form.purpose.trim())
      e.purpose = t("la_purpose_required");
    return e;
  };

  const handleSubmit = async () => {
    if (!editingId && !eligibility.eligible) return;
    if (loading) return;
    const e = validate();
    if (Object.keys(e).length) { setErrors(e); return; }
    setFormError("");
    setLoading(true);
    try {
      const payload = {
        loan_type:   selType,
        amount:      parseFloat(form.amount),
        term_months: parseInt(form.term),
        purpose:     form.purpose,
        collateral:  form.collateral || "",
      };
      if (editingId) {
        await updateLoanAPI(editingId, payload);
        setEditedNotice(true);
        setEditingId(null);
      } else {
        await createLoanAPI(payload);
        setDone(true);
      }
      const loans = await getLoansAPI();
      setMyLoans(loans);
      savePageCache("apply-loan", scopeKey, { shareCapital, monthlyIncome, classification, myLoans: loans });
    } catch(err) {
      const data = err.response?.data;
      const msg  = data?.non_field_errors?.[0] || data?.amount?.[0] || data?.error || data?.detail || t("la_failed_submit");
      setFormError(msg);
      if (editingId && /For Review/i.test(msg)) {
        setEditingId(null);
        const loans = await getLoansAPI();
        setMyLoans(loans);
        savePageCache("apply-loan", scopeKey, { shareCapital, monthlyIncome, classification, myLoans: loans });
      }
    } finally { setLoading(false); }
  };

  // ── Loan Detail Modal ─────────────────────────────────────────────────────
  const LoanDetailModal = () => {
    if (!selectedLoan) return null;
    const st = getStatusMeta(selectedLoan.status, t);
    return (
      <div style={{position:"fixed",inset:0,background:"rgba(0,0,0,0.4)",zIndex:1000,display:"flex",alignItems:"center",justifyContent:"center",padding:16}}
        onClick={() => setSelectedLoan(null)}>
        <div style={{background:"#fff",borderRadius:16,width:"100%",maxWidth:520,maxHeight:"85vh",overflow:"hidden",display:"flex",flexDirection:"column"}}
          onClick={e => e.stopPropagation()}>
          <div style={{padding:"16px 20px",borderBottom:"1px solid #f0f4f1",display:"flex",justifyContent:"space-between",alignItems:"center"}}>
            <div>
              <div style={{fontSize:14,fontWeight:700,color:"#1b5e20"}}>{selectedLoan.loan_id}</div>
              <div style={{fontSize:11,color:"#aaa",marginTop:2}}>{selectedLoan.loan_type} · {selectedLoan.applied_at?.slice(0,10)}</div>
            </div>
            <button onClick={() => setSelectedLoan(null)} style={{background:"none",border:"none",fontSize:18,cursor:"pointer",color:"#aaa"}}>✕</button>
          </div>
          <div style={{padding:"12px 20px",background:"#f9fef9",borderBottom:"1px solid #f0f4f1",display:"flex",gap:16,flexWrap:"wrap"}}>
            {[[t("la_review_amount"),`₱${Number(selectedLoan.amount).toLocaleString()}`],[t("myloans_balance_label"),`₱${Number(selectedLoan.balance).toLocaleString()}`],[t("gc_monthly_due"),`₱${Number(selectedLoan.monthly_due).toLocaleString()}`]].map(([k,v])=>(
              <div key={k} style={{display:"flex",flexDirection:"column",gap:2}}>
                <span style={{fontSize:10,color:"#aaa",fontWeight:700,textTransform:"uppercase"}}>{k}</span>
                <span style={{fontSize:15,fontWeight:700,color:"#1b5e20"}}>{v}</span>
              </div>
            ))}
            <div style={{display:"flex",flexDirection:"column",gap:2}}>
              <span style={{fontSize:10,color:"#aaa",fontWeight:700,textTransform:"uppercase"}}>{t("myloans_status")}</span>
              <span style={{fontSize:12,fontWeight:700,padding:"2px 10px",borderRadius:20,background:st.bg,color:st.color}}>{st.label}</span>
            </div>
          </div>
          <div style={{padding:"12px 20px 4px",borderBottom:"1px solid #f0f4f1"}}>
            <div style={{fontSize:12,fontWeight:700,color:"#555"}}>💳 {t("myloans_tab_payments")}</div>
          </div>
          <div style={{overflowY:"auto",flex:1,padding:"0 20px 16px"}}>
            {loadingPay
              ? <div style={{textAlign:"center",color:"#aaa",padding:"24px 0",fontSize:13}}>{t("myloans_loading")}</div>
              : loanPayments.length === 0
              ? <div style={{textAlign:"center",color:"#aaa",padding:"24px 0",fontSize:13}}>{t("myloans_no_payments_recorded")}</div>
              : <table style={{width:"100%",borderCollapse:"collapse",marginTop:8}}>
                  <thead><tr style={{background:"#f9fef9"}}>
                    {[t("myloans_th_date"),t("myloans_th_txid"),t("myloans_th_amount"),t("myloans_th_balance_after"),t("myloans_th_note")].map(h=>(
                      <th key={h} style={{fontSize:10,color:"#aaa",fontWeight:700,padding:"8px 6px",textAlign:h===t("myloans_th_amount")||h===t("myloans_th_balance_after")?"right":"left",borderBottom:"1px solid #e8f5e9"}}>{h}</th>
                    ))}
                  </tr></thead>
                  <tbody>{loanPayments.map((p,i)=>(
                    <tr key={i} style={{borderBottom:"1px solid #f5f5f5"}}>
                      <td style={{fontSize:11,color:"#555",padding:"9px 6px"}}>{p.paid_at?.slice(0,10)}</td>
                      <td style={{fontSize:10,color:"#888",padding:"9px 6px",fontFamily:"monospace"}}>{p.tx_id}</td>
                      <td style={{fontSize:12,fontWeight:700,color:"#2e7d32",padding:"9px 6px",textAlign:"right"}}>₱{Number(p.amount).toLocaleString()}</td>
                      <td style={{fontSize:12,color:"#1565c0",padding:"9px 6px",textAlign:"right"}}>₱{Number(p.balance).toLocaleString()}</td>
                      <td style={{fontSize:11,color:"#888",padding:"9px 6px"}}>{p.note||"—"}</td>
                    </tr>
                  ))}</tbody>
                </table>}
          </div>
          <div style={{padding:"12px 20px",borderTop:"1px solid #f0f4f1",display:"flex",justifyContent:"space-between",alignItems:"center"}}>
            <div style={{fontSize:11,color:"#aaa"}}>
              {loanPayments.length} · Total: <strong style={{color:"#2e7d32"}}>₱{loanPayments.reduce((s,p)=>s+Number(p.amount||0),0).toLocaleString()}</strong>
            </div>
            <button onClick={() => setSelectedLoan(null)} style={{padding:"7px 18px",background:"#2e7d32",color:"#fff",border:"none",borderRadius:8,fontSize:12,fontWeight:600,cursor:"pointer"}}>{t("myloans_close")}</button>
          </div>
        </div>
      </div>
    );
  };

  // ── Edit Success Screen ──
  if (editedNotice) return (
    <div className="la-wrapper">
      <div className="la-success-card">
        <div className="la-success-icon">✅</div>
        <div className="la-success-title">{t("la_updated_title")}</div>
        <div className="la-success-text">{t("la_updated_text")}</div>
        <button className="la-new-btn" style={{marginTop:16}} onClick={() => {
          setEditedNotice(false);
          setStep(1); setSelType(null);
          setForm({ amount:"", term:"12", purpose:"", collateral:"", note:"" });
        }}>{t("la_back_to_apply")}</button>
      </div>
    </div>
  );

  // ── "Are you sure?" confirmation ──
  const CancelConfirmModal = () => {
    if (!cancelTarget) return null;
    return (
      <div style={{position:"fixed",inset:0,background:"rgba(0,0,0,0.4)",zIndex:1001,display:"flex",alignItems:"center",justifyContent:"center",padding:16}}
        onClick={() => !cancelling && setCancelTarget(null)}>
        <div style={{background:"#fff",borderRadius:16,width:"100%",maxWidth:400,padding:"24px 22px",textAlign:"center"}}
          onClick={e => e.stopPropagation()}>
          <div style={{fontSize:36,marginBottom:8}}>⚠️</div>
          <div style={{fontWeight:800,fontSize:15,color:"#c62828",marginBottom:8}}>{t("la_cancel_confirm_title")}</div>
          <div style={{fontSize:13,color:"#666",lineHeight:1.6,marginBottom:4}}>
            {t("la_cancel_confirm_text", { id: cancelTarget.loan_id, amount: `₱${Number(cancelTarget.amount).toLocaleString()}` })}
          </div>
          {cancelError && <div style={{fontSize:12,color:"#c62828",background:"#fce4ec",borderRadius:8,padding:"8px 12px",marginTop:10}}>{cancelError}</div>}
          <div style={{display:"flex",gap:10,marginTop:18}}>
            <button onClick={() => setCancelTarget(null)} disabled={cancelling}
              style={{flex:1,padding:"10px",borderRadius:8,border:"1px solid #e0e0e0",background:"#fff",color:"#555",fontWeight:600,fontSize:13,cursor:"pointer"}}
            >{t("la_no_keep")}</button>
            <button onClick={handleCancelLoan} disabled={cancelling}
              style={{flex:1,padding:"10px",borderRadius:8,border:"none",background:"#c62828",color:"#fff",fontWeight:700,fontSize:13,cursor:"pointer"}}
            >{cancelling ? t("la_cancelling") : t("la_yes_cancel")}</button>
          </div>
        </div>
      </div>
    );
  };

  // ── Success Screen ──
  if (submitted) return (
    <div className="la-wrapper">
      <div className="la-success-card">
        <div className="la-success-icon">✅</div>
        <div className="la-success-title">{t("la_submitted_title")}</div>
        <div className="la-success-text">
          {t("la_submitted_text", { type: selType, amount: `₱${parseFloat(form.amount).toLocaleString()}` })}
        </div>
        {myLoans.length > 0 && (
          <div className="la-history-box" style={{marginTop:16,textAlign:"left"}}>
            <div className="la-history-title">📋 {t("la_page_title")}</div>
            {myLoans.map((l, i) => {
              const st = getStatusMeta(l.status, t);
              return (
                <div key={i} className="la-history-item">
                  <div className="la-history-left">
                    <div className="la-history-id">{l.loan_id}</div>
                    <div className="la-history-type">{l.loan_type}</div>
                    <div className="la-history-date">{l.applied_at?.slice(0,10)}</div>
                  </div>
                  <div className="la-history-right">
                    <div className="la-history-amount">₱{Number(l.amount).toLocaleString()}</div>
                    <span className="la-status-badge" style={{background:st.bg,color:st.color}}>{st.label}</span>
                    {l.decline_reason && <div className="la-history-reason">"{l.decline_reason}"</div>}
                  </div>
                </div>
              );
            })}
          </div>
        )}
        <button className="la-new-btn" style={{marginTop:16}} onClick={() => {
          setStep(1); setSelType(null);
          setForm({ amount:"", term:"12", purpose:"", collateral:"", note:"" });
          setDone(false);
        }}>{t("la_submit_another")}</button>
      </div>
    </div>
  );

  return (
    <div className="la-wrapper">
      <LoanDetailModal/>
      <CancelConfirmModal/>

      <div className="la-page-header">
        <div className="la-page-title">{t("la_page_title")}</div>
        <div className="la-page-sub">{t("la_page_sub")}</div>
      </div>

      {staleNotice && (
        <div style={{display:"flex",justifyContent:"space-between",alignItems:"center",gap:10,background:"#fff3e0",border:"1px solid #ffb74d",borderRadius:10,padding:"10px 16px",marginBottom:16}}>
          <span style={{fontSize:12.5,color:"#7a4a00"}}>⚠️ {staleNotice}</span>
          <button onClick={() => setStaleNotice("")} style={{background:"none",border:"none",fontSize:14,cursor:"pointer",color:"#7a4a00",flexShrink:0}}>✕</button>
        </div>
      )}

      {editingId && (
        <div style={{background:"#e3f2fd",border:"1px solid #90caf9",borderRadius:10,padding:"10px 16px",marginBottom:16}}>
          <span style={{fontSize:13,fontWeight:700,color:"#1565c0"}}>{t("la_editing_banner")}</span>
        </div>
      )}

      {eligibility.approvedLoans.length > 0 && (
        <div style={{
          background:"linear-gradient(135deg,#fff3e0,#ffe0b2)",
          border:"1.5px solid #ffb74d", borderRadius:12,
          padding:"16px 18px", marginBottom:16,
          display:"flex", alignItems:"center", gap:14, flexWrap:"wrap",
        }}>
          <div style={{fontSize:28,flexShrink:0}}>📦</div>
          <div style={{flex:1,minWidth:220}}>
            <div style={{fontWeight:800,fontSize:14,color:"#e65100"}}>
              {eligibility.approvedLoans.length === 1
                ? t("la_ready_release_one", { loan_id: eligibility.approvedLoans[0].loan_id })
                : t("la_ready_release_many", { n: eligibility.approvedLoans.length })}
            </div>
            <div style={{fontSize:12,color:"#7a4a00",marginTop:2}}>
              {eligibility.approvedLoans.length === 1
                ? t("la_ready_release_sub_one", { amt: `₱${Number(eligibility.approvedLoans[0].amount).toLocaleString()}` })
                : t("la_ready_release_sub_many")}
            </div>
          </div>
        </div>
      )}

      {/* ── Eligibility Status ── */}
      <div style={{
        background: eligibility.eligible ? "#e8f5e9" : "#ffebee",
        border: `1.5px solid ${eligibility.eligible ? "#a5d6a7" : "#ef9a9a"}`,
        borderRadius:12, padding:"16px 18px", marginBottom:16,
      }}>
        <div style={{display:"flex",alignItems:"center",gap:8,marginBottom:10}}>
          {eligibility.eligible
            ? <CheckCircle size={18} color="#2e7d32"/>
            : <XCircle size={18} color="#c62828"/>}
          <span style={{fontWeight:800,fontSize:14,color:eligibility.eligible?"#1b5e20":"#c62828"}}>
            {eligibility.eligible ? t("la_eligible_yes") : t("la_eligible_no")}
          </span>
        </div>

        {eligibility.passed.map((p,i) => (
          <div key={i} style={{display:"flex",alignItems:"center",gap:6,fontSize:12,color:"#2e7d32",marginBottom:4}}>
            <CheckCircle size={12} color="#2e7d32"/> {p}
          </div>
        ))}

        {eligibility.issues.map((issue,i) => (
          <div key={i} style={{display:"flex",alignItems:"flex-start",gap:6,fontSize:12,color:"#c62828",background:"#fff",borderRadius:8,padding:"8px 12px",border:"1px solid #ef9a9a",marginTop:6}}>
            <AlertTriangle size={13} style={{flexShrink:0,marginTop:1}}/> {issue}
          </div>
        ))}

        <div style={{display:"flex",gap:12,marginTop:12,flexWrap:"wrap"}}>
          {[
            [t("la_stat_share_capital"),  `₱${shareCapital.toLocaleString()}`,                                          "#1b5e20"],
            [t("la_stat_max_loanable"),   `₱${maxLoanable.toLocaleString()}`,                                          "#1565c0"],
            [t("la_stat_active_loans"),   myLoans.filter(l=>["Active","Overdue"].includes(l.status)).length,            myLoans.filter(l=>["Active","Overdue"].includes(l.status)).length>0?"#c62828":"#2e7d32"],
            [t("la_stat_for_release"),    eligibility.approvedLoans.length,                                             eligibility.approvedLoans.length>0?"#e65100":"#2e7d32"],
            [t("la_stat_completed_loans"),myLoans.filter(l=>l.status==="Completed").length,                             "#2e7d32"],
          ].map(([label,val,color])=>(
            <div key={label} style={{background:"rgba(255,255,255,0.75)",borderRadius:8,padding:"8px 14px",textAlign:"center"}}>
              <div style={{fontSize:10,color:"#666",fontWeight:600,textTransform:"uppercase"}}>{label}</div>
              <div style={{fontSize:16,fontWeight:800,color}}>{val}</div>
            </div>
          ))}
        </div>
      </div>

      {/* ── Loan Recommendation ── */}
      {eligibility.eligible && (
        <div style={{
          background:"linear-gradient(135deg,#1b5e20,#2e7d32)",
          borderRadius:14, padding:"18px 20px", marginBottom:16,
          boxShadow:"0 4px 14px rgba(27,94,32,0.25)",
        }}>
          <div style={{display:"flex",alignItems:"center",gap:8,marginBottom:14}}>
            <div style={{background:"rgba(255,255,255,0.2)",borderRadius:8,padding:6,display:"flex"}}>
              <span style={{fontSize:16}}>💡</span>
            </div>
            <div>
              <div style={{color:"#fff",fontWeight:800,fontSize:14}}>{t("la_recommendation_title")}</div>
              <div style={{color:"rgba(255,255,255,0.7)",fontSize:11}}>
                {recommendation.monthlyIncome > 0 ? t("la_recommendation_sub_income") : t("la_recommendation_sub")}
              </div>
            </div>
          </div>

          <div style={{display:"grid",gridTemplateColumns:"repeat(3,1fr)",gap:10,marginBottom:14}}>
            {[
              {
                label:t("la_rec_type"),
                value:recommendation.type,
                sub:t("la_rec_type_sub"),
                icon:"📋",
              },
              {
                label:t("la_rec_amount"),
                value:`₱${recommendation.amount.toLocaleString()}`,
                sub:t("la_rec_amount_sub", { amt: `₱${recommendation.maxLoanable.toLocaleString()}` }),
                icon:"💰",
              },
              {
                label:t("la_rec_term"),
                value:`${recommendation.term} months`,
                sub:recommendation.monthlyIncome > 0
                  ? t("la_rec_term_sub_income", { amt: `₱${recommendation.monthlyDue.toLocaleString()}` })
                  : t("la_rec_term_sub"),
                icon:"📅",
              },
            ].map((c,i) => (
              <div key={i} style={{background:"rgba(255,255,255,0.12)",borderRadius:10,padding:"12px 14px"}}>
                <div style={{fontSize:16,marginBottom:4}}>{c.icon}</div>
                <div style={{fontSize:11,color:"rgba(255,255,255,0.6)",marginBottom:2}}>{c.label}</div>
                <div style={{fontSize:14,fontWeight:800,color:"#fff"}}>{c.value}</div>
                <div style={{fontSize:10,color:"rgba(255,255,255,0.5)",marginTop:2}}>{c.sub}</div>
              </div>
            ))}
          </div>

          {recommendation.monthlyIncome > 0 && (
            <div style={{background:"rgba(255,255,255,0.1)",borderRadius:8,padding:"10px 14px",display:"flex",alignItems:"center",gap:8}}>
              <div style={{flex:1}}>
                <div style={{fontSize:11,color:"rgba(255,255,255,0.7)",marginBottom:4}}>
                  {t("la_debt_ratio")}
                </div>
                <div style={{background:"rgba(255,255,255,0.2)",borderRadius:20,height:6,overflow:"hidden"}}>
                  <div style={{
                    width:`${Math.min(recommendation.debtRatio,100)}%`,
                    height:"100%",borderRadius:20,
                    background:recommendation.debtRatio<=30?"#69f0ae":recommendation.debtRatio<=40?"#ffeb3b":"#ff5252",
                    transition:"width 0.6s",
                  }}/>
                </div>
              </div>
              <div style={{textAlign:"right",flexShrink:0}}>
                <div style={{fontSize:18,fontWeight:800,color:recommendation.debtRatio<=30?"#69f0ae":recommendation.debtRatio<=40?"#ffeb3b":"#ff5252"}}>
                  {recommendation.debtRatio}%
                </div>
                <div style={{fontSize:10,color:"rgba(255,255,255,0.5)"}}>
                  {recommendation.debtRatio<=30?t("la_debt_good"):t("la_debt_high")}
                </div>
              </div>
            </div>
          )}

          <button
            onClick={() => {
              setSelType(recommendation.type);
              setForm(p => ({
                ...p,
                amount: String(recommendation.amount),
                term:   String(recommendation.term),
              }));
              setStep(2);
            }}
            style={{
              marginTop:12, width:"100%", padding:"11px",
              background:"rgba(255,255,255,0.95)", color:"#1b5e20",
              border:"none", borderRadius:10, fontSize:13, fontWeight:800,
              cursor:"pointer", fontFamily:"inherit",
              transition:"all 0.15s",
            }}
          >
            {t("la_apply_recommended")}
          </button>
        </div>
      )}

      {/* Loan History */}
      <div className="la-card" style={{marginBottom:16}}>
        <div className="la-history-header" onClick={() => setShowHistory(h => !h)} style={{cursor:"pointer",display:"flex",justifyContent:"space-between",alignItems:"center"}}>
          <div className="la-card-title" style={{margin:0}}>{t("la_my_applications", { n: myLoans.length })}</div>
          <span style={{fontSize:12,color:"#888"}}>{showHistory ? t("la_hide") : t("la_show")}</span>
        </div>
        {showHistory && (
          <div style={{marginTop:12}}>
            {loadingLoans
              ? <div style={{textAlign:"center",color:"#aaa",padding:"16px 0",fontSize:13}}>{t("myloans_loading")}</div>
              : myLoans.length === 0
              ? <div style={{textAlign:"center",color:"#aaa",padding:"16px 0",fontSize:13}}>{t("la_no_applications")}</div>
              : myLoans.map((l, i) => {
                  const st = getStatusMeta(l.status, t);
                  const canManage = l.status === "For Review";
                  return (
                    <div key={i} className="la-history-item" onClick={() => handleLoanClick(l)} style={{cursor:"pointer"}}
                      onMouseEnter={e=>e.currentTarget.style.background="#f9fef9"}
                      onMouseLeave={e=>e.currentTarget.style.background=""}>
                      <div className="la-history-left">
                        <div className="la-history-id">{l.loan_id}</div>
                        <div className="la-history-type">{l.loan_type}</div>
                        <div className="la-history-date">{l.applied_at?.slice(0,10)}</div>
                      </div>
                      <div className="la-history-right">
                        <div className="la-history-amount">₱{Number(l.amount).toLocaleString()}</div>
                        <span className="la-status-badge" style={{background:st.bg,color:st.color}}>{st.label}</span>
                        {l.decline_reason && <div className="la-history-reason">"{l.decline_reason}"</div>}
                        {canManage && (
                          <div style={{display:"flex",gap:6,marginTop:6}} onClick={e => e.stopPropagation()}>
                            <button
                              onClick={() => handleEditClick(l)}
                              disabled={checkingId === l.id}
                              style={{fontSize:11,fontWeight:600,padding:"4px 10px",borderRadius:6,border:"1px solid #90caf9",background:"#e3f2fd",color:"#1565c0",cursor:checkingId===l.id?"default":"pointer",opacity:checkingId===l.id?0.6:1}}
                            >{checkingId===l.id ? t("la_checking") : t("la_edit")}</button>
                            <button
                              onClick={() => handleCancelClick(l)}
                              disabled={checkingId === l.id}
                              style={{fontSize:11,fontWeight:600,padding:"4px 10px",borderRadius:6,border:"1px solid #ef9a9a",background:"#fce4ec",color:"#c62828",cursor:checkingId===l.id?"default":"pointer",opacity:checkingId===l.id?0.6:1}}
                            >{checkingId===l.id ? t("la_checking") : t("la_cancel")}</button>
                          </div>
                        )}
                      </div>
                    </div>
                  );
                })}
          </div>
        )}
      </div>

      {!editingId && !eligibility.eligible ? (
        <div style={{background:"#fff3e0",border:"1.5px solid #ffcc80",borderRadius:12,padding:"24px",textAlign:"center"}}>
          <AlertTriangle size={36} color="#e65100" style={{marginBottom:8}}/>
          <div style={{fontWeight:700,fontSize:15,color:"#e65100",marginBottom:8}}>{t("la_cannot_apply")}</div>
          <div style={{fontSize:13,color:"#666",lineHeight:1.6}}>
            {t("la_cannot_apply_sub")}
          </div>
        </div>
      ) : (<>

        <div className="la-steps">
          {[t("la_step_type"),t("la_step_details"),t("la_step_review")].map((s,i) => (
            <div key={i} className={`la-step ${step >= i+1?"active":""} ${step > i+1?"done":""}`}>
              <div className="la-step-dot">{step > i+1 ? "✓" : i+1}</div>
              <div className="la-step-label">{s}</div>
            </div>
          ))}
        </div>

        {step === 1 && (
          <div className="la-card">
            <div className="la-card-title">{t("la_choose_loan_type")}</div>
            <div className="la-loan-types">
              {LOAN_TYPES.map(lt => (
                <div key={lt.type} className={`la-type-card ${selType===lt.type?"selected":""}`}
                  onClick={() => setSelType(lt.type)}
                  style={selType===lt.type ? {borderColor:lt.border,background:lt.color} : {}}>
                  <div className="la-type-icon" style={{background:lt.color,border:`1.5px solid ${lt.border}`,borderRadius:14,width:56,height:56,minWidth:56,display:"flex",alignItems:"center",justifyContent:"center",margin:"0 auto 10px"}}>
                    {lt.icon}
                  </div>
                  <div className="la-type-name">{lt.type}</div>
                  <div className="la-type-desc">{t(lt.descKey)}</div>
                  <div className="la-type-max">{t("la_up_to_months", { amt: `₱${lt.maxAmt.toLocaleString()}`, term: lt.maxTerm })}</div>
                </div>
              ))}
            </div>
            <div className="la-card-footer">
              <div/>
              <button className="la-btn-next" onClick={() => setStep(2)} disabled={!selType}>{t("la_next_loan_details")}</button>
            </div>
          </div>
        )}

        {step === 2 && selectedType && (
          <div className="la-card">
            <div style={{display:"flex",alignItems:"center",gap:12,marginBottom:18}}>
              <div style={{background:selectedType.color,border:`1.5px solid ${selectedType.border}`,borderRadius:12,width:44,height:44,display:"flex",alignItems:"center",justifyContent:"center",flexShrink:0}}>{selectedType.icon}</div>
              <div>
                <div className="la-card-title" style={{margin:0}}>{t("la_step_details")}</div>
                <div style={{fontSize:11,color:"#aaa",marginTop:2}}>{selectedType.type}</div>
              </div>
            </div>
            <div className="la-form-grid">
              <div className="la-field">
                <label className="la-label">{t("la_loan_amount")} <span className="la-req">*</span></label>
                <div className="la-amount-wrap">
                  <span className="la-peso">₱</span>
                  <input className={`la-amount-input ${errors.amount?"la-err":""}`} type="text" inputMode="numeric" pattern="[0-9]*" name="amount"
                    value={form.amount} onChange={handleAmountChange}
                    placeholder={t("la_amount_placeholder", { amt: `₱${maxLoanable.toLocaleString()}` })}/>
                </div>
                {errors.amount && <div className="la-field-err">{errors.amount}</div>}
                <div style={{fontSize:10,color:"#888",marginTop:4}}>{t("la_max_loanable_share", { amt: `₱${maxLoanable.toLocaleString()}` })}</div>
              </div>
              <div className="la-field">
                <label className="la-label">{t("la_loan_term")}</label>
                <select className="la-select" name="term" value={form.term} onChange={handle}>
                  {[3,6,9,12,18,24,36,48].filter(t2 => t2 <= selectedType.maxTerm).map(t2 => (
                    <option key={t2} value={t2}>{t("la_months_option", { n: t2 })}</option>
                  ))}
                </select>
              </div>
              <div className="la-field la-full">
                <label className="la-label">{t("la_purpose")} <span className="la-req">*</span></label>
                <textarea className={`la-textarea ${errors.purpose?"la-err":""}`} name="purpose" rows={3}
                  placeholder={t("la_purpose_placeholder")} value={form.purpose}
                  onChange={e => { handle(e); setErrors(p => ({...p,purpose:""})); }}/>
                {errors.purpose && <div className="la-field-err">{errors.purpose}</div>}
              </div>
              <div className="la-field">
                <label className="la-label">{t("la_collateral")}</label>
                <input className="la-input" type="text" name="collateral" value={form.collateral} onChange={handle} placeholder={t("la_collateral_placeholder")}/>
              </div>
              <div className="la-field">
                <label className="la-label">{t("la_additional_notes")}</label>
                <input className="la-input" type="text" name="note" value={form.note} onChange={handle} placeholder={t("la_optional")}/>
              </div>
            </div>
            {showComputation && (
              <div className="la-computation">
                <div className="la-comp-title">{t("la_computation_title")}</div>
                <div className="la-comp-summary">
                  <div className="la-comp-row"><span>{t("la_interest_rate")}</span><span className="fw">{(monthlyRate*100).toFixed(3)}% / mo × {term} months</span></div>
                  <div className="la-comp-row"><span>{t("la_total_interest")}</span><span className="orange fw">₱{interest.toFixed(2)}</span></div>
                  <div className="la-comp-row highlight"><span>{t("la_monthly_amortization")}</span><span className="green fw">₱{monthlyEst.toFixed(2)}</span></div>
                </div>
                <div className="la-comp-deductions">
                  <div className="la-comp-ded-title">{t("la_upfront_deductions")}</div>
                  <div className="la-ded-row"><span>{t("la_loan_amount_row")}</span><span>₱{amount.toLocaleString()}</span></div>
                  <div className="la-ded-divider"/>
                  <div className="la-ded-row"><span>{t("la_interest_row")} <span className="la-ded-rate">({(monthlyRate*100)}% × {term} mos)</span></span><span className="red">− ₱{interest.toFixed(2)}</span></div>
                  <div className="la-ded-row"><span>{t("la_service_fee")}</span><span className="red">− ₱{serviceFee.toFixed(2)}</span></div>
                  <div className="la-ded-row"><span>{t("la_filing_fee")}</span><span className="red">− ₱{filingFee.toFixed(2)}</span></div>
                  <div className="la-ded-row"><span>{t("la_insurance")}</span><span className="red">− ₱{insurance.toFixed(2)}</span></div>
                  <div className="la-ded-row"><span>{t("la_savings_deposit")}</span><span className="red">− ₱{sd.toFixed(2)}</span></div>
                  <div className="la-ded-row"><span>{t("la_sc_cbu")}</span><span className="red">− ₱{sc.toFixed(2)}</span></div>
                  <div className="la-ded-divider"/>
                  <div className="la-ded-row la-ded-total"><span>{t("la_total_deductions")}</span><span className="red fw">− ₱{totalDed.toFixed(2)}</span></div>
                  <div className="la-ded-row la-ded-net"><span>{t("la_net_proceeds")}</span><span className="green fw">₱{netProceeds.toFixed(2)}</span></div>
                </div>
              </div>
            )}
            <div className="la-card-footer">
              <button className="la-btn-back" onClick={() => setStep(1)}>{t("la_back")}</button>
              <button className="la-btn-next" onClick={() => {
                const e = validate();
                if (Object.keys(e).length) { setErrors(e); return; }
                setStep(3);
              }}>{t("la_next_review")}</button>
            </div>
          </div>
        )}

        {step === 3 && (
          <div className="la-card">
            <div style={{display:"flex",alignItems:"center",gap:12,marginBottom:18}}>
              <div style={{background:selectedType?.color,border:`1.5px solid ${selectedType?.border}`,borderRadius:12,width:44,height:44,display:"flex",alignItems:"center",justifyContent:"center",flexShrink:0}}>{selectedType?.icon}</div>
              <div>
                <div className="la-card-title" style={{margin:0}}>{t("la_review_title")}</div>
                <div style={{fontSize:11,color:"#aaa",marginTop:2}}>{t("la_review_sub")}</div>
              </div>
            </div>
            <div className="la-review-grid">
              {[
                [t("la_review_loan_type"),      selType],
                [t("la_review_amount"),         `₱${amount.toLocaleString()}`],
                [t("la_review_term"),           `${term} months`],
                [t("la_review_interest_rate"),  `${(monthlyRate*100).toFixed(3)}% / month`],
                [t("la_review_total_interest"), `₱${interest.toFixed(2)}`],
                [t("la_review_monthly_amort"),  `₱${monthlyEst.toFixed(2)}`],
                [t("la_review_net_proceeds"),   `₱${netProceeds.toFixed(2)}`],
                [t("la_review_purpose"),        form.purpose],
                [t("la_review_collateral"),     form.collateral || t("la_none")],
              ].map(([k,v]) => (
                <div key={k} className="la-review-item">
                  <span className="la-review-key">{k}</span>
                  <span className={`la-review-val ${k===t("la_review_amount")||k===t("la_review_net_proceeds")?"green fw":k===t("la_review_total_interest")?"orange":""}`}>{v}</span>
                </div>
              ))}
            </div>
            {formError && (
              <div style={{display:"flex",alignItems:"flex-start",gap:6,fontSize:12.5,color:"#c62828",background:"#fce4ec",borderRadius:8,padding:"10px 14px",border:"1px solid #ef9a9a",marginBottom:12}}>
                <AlertTriangle size={14} style={{flexShrink:0,marginTop:1}}/> {formError}
              </div>
            )}
            <div className="la-review-notice">
              {t("la_confirm_notice")}
            </div>
            <div className="la-card-footer">
              <button className="la-btn-back" onClick={() => setStep(2)} disabled={loading}>{t("la_back")}</button>
              <button className="la-btn-submit" onClick={handleSubmit} disabled={loading} style={{display:"flex",alignItems:"center",justifyContent:"center",gap:8}}>
                {loading && (
                  <span style={{
                    display:"inline-block", width:13, height:13,
                    border:"2px solid rgba(255,255,255,0.4)", borderTopColor:"#fff",
                    borderRadius:"50%", animation:"la-spin 0.7s linear infinite",
                  }}/>
                )}
                {loading ? (editingId ? t("la_updating") : t("la_submitting")) : (editingId ? t("la_update_application") : t("la_submit_application"))}
              </button>
              <style>{`@keyframes la-spin { to { transform: rotate(360deg); } }`}</style>
            </div>
          </div>
        )}

        {editingId && (
          <button onClick={handleCancelEdit} disabled={loading} style={{width:"100%",marginTop:12,padding:"11px",borderRadius:10,border:"1px solid #ef9a9a",background:"#fff",color:"#c62828",fontWeight:700,fontSize:13,cursor:"pointer"}}>{t("la_cancel_edit")}</button>
        )}
      </>)}
    </div>
  );
}