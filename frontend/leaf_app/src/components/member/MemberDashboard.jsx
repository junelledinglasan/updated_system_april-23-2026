import { useState, useEffect } from "react";
import { useOutletContext, useNavigate } from "react-router-dom";
import { Line, Doughnut } from "react-chartjs-2";
import {
  Chart as ChartJS, CategoryScale, LinearScale,
  PointElement, LineElement, ArcElement,
  Title, Tooltip, Legend, Filler,
} from "chart.js";
import { Wallet, CalendarClock, CheckCircle2, TrendingUp, CreditCard, Megaphone, Clock, AlertTriangle } from "lucide-react";
import { getLoansAPI } from "../../api/loans";
import { getPaymentsAPI } from "../../api/payments";
import { getAnnouncementsAPI } from "../../api/announcements";
import { useLanguage } from "../../context/LanguageContext";
import { useAuth } from "../../context/AuthContext";
import { getPageCache, savePageCache } from "../../utils/pageCache";
import "./MemberDashboard.css";

ChartJS.register(CategoryScale, LinearScale, PointElement, LineElement, ArcElement, Title, Tooltip, Legend, Filler);

function NonOfficialWelcome({ member, navigate }) {
  // ── BAGO: useLanguage() hook para sa translations ────────────────
  const { t } = useLanguage();
  const firstname = member.name.split(" ")[0];
  return (
    <div className="md-wrapper">
      <div className="md-banner">
        <div>
          <div className="md-banner-greeting">{t("dash_welcome", { firstname })}</div>
          <div className="md-banner-sub">{t("dash_almost_there")}</div>
        </div>
        <div className="md-banner-chip">
          <div className="md-banner-avatar">{member.initials}</div>
          <div>
            <div className="md-banner-name">{member.name}</div>
            <div className="md-banner-id">{t("dash_pending_membership")}</div>
          </div>
          <span className="md-pending-badge">{t("dash_pending")}</span>
        </div>
      </div>
      <div className="md-unofficial-card">
        <div className="md-unofficial-header">
          <div className="md-unofficial-icon"><Clock size={22} color="#e65100"/></div>
          <div>
            <div className="md-unofficial-title">{t("dash_not_official_title")}</div>
            <div className="md-unofficial-sub">{t("dash_not_official_sub")}</div>
          </div>
        </div>
        <div className="md-access-grid">
          <div className="md-access-col locked-col">
            <div className="md-access-col-title">{t("dash_locked_features")}</div>
            <div className="md-access-item locked">{t("dash_locked_dashboard")}</div>
            <div className="md-access-item locked">{t("dash_locked_loans")}</div>
            <div className="md-access-item locked">{t("dash_locked_apply")}</div>
          </div>
          <div className="md-access-col open-col">
            <div className="md-access-col-title">{t("dash_available_now")}</div>
            <div className="md-access-item open">{t("nav_notifications")}</div>
            <div className="md-access-item open">{t("nav_announcements")}</div>
            <div className="md-access-item open">{t("nav_profile")}</div>
          </div>
        </div>
        <div className="md-unofficial-actions">
          <button className="md-cta-primary" onClick={() => navigate("/member/apply-membership")}>{t("dash_apply_membership_btn")}</button>
        </div>
      </div>
    </div>
  );
}

export default function MemberDashboard() {
  const ctx      = useOutletContext() || {};
  const navigate = useNavigate();
  const member   = ctx.member || { name: "Member", memberId: "—", initials: "M", isOfficial: false };
  const { user } = useAuth();
  // ── BAGO: useLanguage() hook para sa translations ────────────────
  const { t } = useLanguage();

  // ALL hooks declared BEFORE any conditional return — Rules of Hooks
  // ── FIX: dating member.id ang cache key — pero `null` muna 'to sa
  // unang saglit pag-refresh (hinihintay pa ang async profile fetch
  // ng MemberLayout), kaya mali munang key ang tinatamaan, hindi
  // makita ang tamang cache. Gamit na lang ngayon ang user.id mula
  // sa AuthContext — available na agad mula sa saved session. ────────
  const scopeKey = user?.id ?? user?.username ?? null;
  const cached = getPageCache("dashboard", scopeKey);
  const [loans,    setLoans]    = useState(cached?.loans || []);
  const [payments, setPayments] = useState(cached?.payments || []);
  const [notifs,   setNotifs]   = useState(cached?.notifs || []);
  const [loading,  setLoading]  = useState(!cached);

  useEffect(() => {
    if (!member.isOfficial) { setLoading(false); return; }
    Promise.allSettled([getLoansAPI(), getPaymentsAPI(), getAnnouncementsAPI()])
      .then(([l, p, n]) => {
        const newLoans    = l.status === "fulfilled" ? l.value : [];
        const newPayments = p.status === "fulfilled" ? p.value : [];
        const newNotifs   = n.status === "fulfilled" ? n.value.slice(0, 3) : [];
        setLoans(newLoans);
        setPayments(newPayments);
        setNotifs(newNotifs);
        savePageCache("dashboard", scopeKey, { loans: newLoans, payments: newPayments, notifs: newNotifs });
      }).finally(() => setLoading(false));
  }, [member.isOfficial, scopeKey]);

  // Conditional return AFTER all hooks
  if (!member.isOfficial) return <NonOfficialWelcome member={member} navigate={navigate} />;

  // ── FIX: dating "status === 'Active'" LANG ang hinahanap — kaya
  // kung ang tanging loan ng member ay "Overdue" na (hindi "Active"),
  // nahuhulog ito sa "loans[0]" fallback sa halip, na puwedeng MALING
  // loan ang ipakita kung marami silang loans. Isinama na ngayon ang
  // "Overdue" bilang parehong "kasalukuyang" loan. ────────────────────
  const activeLoan   = loans.find(l => ["Active","Overdue"].includes(l.status)) || loans[0] || null;
  const totalLoan    = parseFloat(activeLoan?.amount || 0);
  const balance      = parseFloat(activeLoan?.balance || 0);
  // ── FIX: dating "totalLoan - balance" — nasira ito ngayon dahil
  // puwede nang LUMAKI ang balance (dahil sa 2% penalty), hindi na
  // laging lumiliit lang (dahil sa pagbabayad). Nagreresulta ito ng
  // NEGATIVE na "Total Paid" kapag may naipong penalty. Ang tamang
  // paraan: i-sum ang AKTWAL na mga payment record ng loan na 'to. ──
  const loanPaymentsForTotal = payments.filter(p => p.loan === activeLoan?.id || String(p.loan_code) === String(activeLoan?.loan_id));
  const totalPaid    = loanPaymentsForTotal.reduce((s,p) => s + parseFloat(p.amount||0), 0);
  const monthlyDue   = parseFloat(activeLoan?.monthly_due || 0);
  const paidPct      = totalLoan > 0 ? Math.max(0, Math.min(100, Math.round((totalPaid / totalLoan) * 100))) : 0;
  const totalPenalty = parseFloat(activeLoan?.total_penalty || 0);
  const monthsOverdue = activeLoan?.months_overdue_penalized || 0;
  const shareCapital = parseFloat(member.share_capital || 0);
  const firstname    = member.name.split(" ")[0];

  const lineData = {
    labels: payments.slice(0,6).map(p => p.paid_at?.slice(0,7) || ""),
    datasets: [{ label:"Payment", data: payments.slice(0,6).map(p => parseFloat(p.amount)),
      borderColor:"#2e7d32", backgroundColor:"rgba(46,125,50,0.08)",
      fill:true, tension:0.4, pointRadius:4, pointBackgroundColor:"#2e7d32", borderWidth:2 }],
  };
  const doughnutData = {
    labels: [t("dash_paid"), t("dash_left")],
    datasets: [{ data:[totalPaid, balance], backgroundColor:["#2e7d32","#e8f5e9"], borderWidth:0, hoverOffset:4 }],
  };
  const lineOpts = {
    responsive:true, maintainAspectRatio:false, plugins:{legend:{display:false}},
    scales:{ x:{grid:{display:false},ticks:{font:{size:10}}}, y:{grid:{color:"#f0f4f1"},ticks:{font:{size:10},callback:v=>"₱"+v.toLocaleString()}} },
  };
  const doughnutOpts = {
    responsive:true, maintainAspectRatio:false, cutout:"68%",
    plugins:{legend:{position:"bottom",labels:{boxWidth:10,padding:10,font:{size:10}}}},
  };

  return (
    <div className="md-wrapper">
      <div className="md-banner">
        <div>
          <div className="md-banner-greeting">{t("dash_good_day", { firstname })}</div>
          <div className="md-banner-sub">{t("dash_summary_sub")}</div>
        </div>
        <div className="md-banner-chip">
          <div className="md-banner-avatar">{member.initials}</div>
          <div><div className="md-banner-name">{member.name}</div><div className="md-banner-id">{member.memberId}</div></div>
          <span className="md-active-badge">{t("dash_active")}</span>
        </div>
      </div>

      {/* ── BAGO: penalty warning — makikita agad ng member kung bakit
          tumaas ang balance nila, sa pinaka-unang bahagi ng dashboard
          na tinitingnan nila. ─────────────────────────────────────── */}
      {totalPenalty > 0 && (
        <div style={{background:"#fce4ec", border:"1px solid #f8bbd0", borderRadius:12, padding:"12px 16px", marginBottom:16, display:"flex", alignItems:"center", gap:10}}>
          <AlertTriangle size={18} color="#c62828"/>
          <div style={{fontSize:12.5, color:"#c62828", lineHeight:1.5}}>
            You have a <strong>₱{totalPenalty.toLocaleString()} penalty</strong> for {monthsOverdue} month{monthsOverdue!==1?"s":""} of late payment (2% of your Monthly Due per month), already included in your Remaining Balance. Pay as soon as possible to avoid further penalties.
          </div>
        </div>
      )}

      <div className="md-kpi-grid">
        <div className="md-kpi-card md-kpi-danger">
          <div className="md-kpi-icon"><Wallet size={22} color="#c62828"/></div>
          <div>
            <div className="md-kpi-label">{t("dash_remaining_balance")}</div>
            <div className="md-kpi-val red">₱{balance.toLocaleString()}</div>
            <div className="md-kpi-sub">{activeLoan?.loan_type || t("dash_no_active_loan")} · {activeLoan?.loan_id || "—"}</div>
          </div>
        </div>
        <div className="md-kpi-card">
          <div className="md-kpi-icon"><CalendarClock size={22} color="#e65100"/></div>
          <div>
            <div className="md-kpi-label">{t("dash_next_payment_due")}</div>
            <div className="md-kpi-val orange">₱{monthlyDue.toLocaleString()}</div>
            <div className="md-kpi-sub">{activeLoan?.next_due_date || "—"}</div>
          </div>
        </div>
        <div className="md-kpi-card">
          <div className="md-kpi-icon"><CheckCircle2 size={22} color="#2e7d32"/></div>
          <div>
            <div className="md-kpi-label">{t("dash_total_paid")}</div>
            <div className="md-kpi-val green">₱{totalPaid.toLocaleString()}</div>
            <div className="md-kpi-sub">{t("dash_pct_completed", { pct: paidPct })}</div>
          </div>
        </div>
        <div className="md-kpi-card">
          <div className="md-kpi-icon"><TrendingUp size={22} color="#1565c0"/></div>
          <div>
            <div className="md-kpi-label">{t("dash_share_capital")}</div>
            <div className="md-kpi-val blue">₱{shareCapital.toLocaleString()}</div>
            <div className="md-kpi-sub">{t("dash_max_loanable", { amt: `₱${shareCapital.toLocaleString()}` })}</div>
          </div>
        </div>
      </div>

      <div className="md-mid-row">
        <div className="md-card md-progress-card">
          <div className="md-card-title">{t("dash_repayment_progress")}</div>
          <div className="md-card-sub">{activeLoan?.loan_type || "—"} — {activeLoan?.loan_id || "—"}</div>
          <div className="md-progress-bar-wrap">
            <div className="md-progress-bar"><div className="md-progress-fill" style={{width:paidPct+"%"}}/></div>
            <div className="md-progress-labels">
              <span className="green fw">₱{totalPaid.toLocaleString()} {t("dash_paid")}</span>
              <span>{paidPct}%</span>
              <span className="red">₱{balance.toLocaleString()} {t("dash_left")}</span>
            </div>
          </div>
          <div className="md-loan-details">
            <div className="md-loan-detail-item"><span className="md-ld-label">{t("dash_principal")}</span><span className="md-ld-val">₱{totalLoan.toLocaleString()}</span></div>
            <div className="md-loan-detail-item"><span className="md-ld-label">{t("dash_monthly_due")}</span><span className="md-ld-val green">₱{monthlyDue.toLocaleString()}</span></div>
            <div className="md-loan-detail-item"><span className="md-ld-label">{t("dash_status")}</span><span className="md-loan-status-badge current" style={activeLoan?.status==="Overdue"?{background:"#ffebee",color:"#c62828",borderColor:"#ef9a9a"}:undefined}>{activeLoan?.status || "—"}</span></div>
            <div className="md-loan-detail-item"><span className="md-ld-label">{t("dash_next_due")}</span><span className="md-ld-val">{activeLoan?.next_due_date || "—"}</span></div>
          </div>
        </div>
        <div className="md-card">
          <div className="md-card-title">{t("dash_loan_breakdown")}</div>
          <div className="md-card-sub">{t("dash_paid_vs_remaining")}</div>
          <div style={{height:200}}><Doughnut data={doughnutData} options={doughnutOpts}/></div>
        </div>
      </div>

      <div className="md-bot-row">
        <div className="md-card">
          <div className="md-card-title">{t("dash_payment_history")}</div>
          <div className="md-card-sub">{t("dash_last_6_months")}</div>
          <div style={{height:180}}>
            {payments.length===0
              ? <div style={{textAlign:"center",padding:"40px",color:"#aaa",fontSize:13}}>{t("dash_no_payment_history")}</div>
              : <Line data={lineData} options={lineOpts}/>}
          </div>
        </div>
        <div className="md-card">
          <div className="md-card-header-row">
            <div><div className="md-card-title">{t("dash_recent_transactions")}</div><div className="md-card-sub">{t("dash_latest_payment_records")}</div></div>
            <button className="md-view-all-btn" onClick={()=>navigate("/member/my-loans")}>{t("dash_view_all")}</button>
          </div>
          <div className="md-tx-list">
            {payments.length===0
              ? <div style={{textAlign:"center",padding:"20px",color:"#aaa",fontSize:12}}>{t("dash_no_transactions")}</div>
              : payments.slice(0,5).map((tx,i)=>(
                <div key={i} className="md-tx-item">
                  <div className="md-tx-icon payment"><CreditCard size={16} color="#2e7d32"/></div>
                  <div className="md-tx-info"><div className="md-tx-desc">{t("dash_loan_payment")}</div><div className="md-tx-date">{tx.paid_at}</div></div>
                  <div className="md-tx-amount red">−₱{Number(tx.amount).toLocaleString()}</div>
                </div>
              ))}
          </div>
        </div>
        <div className="md-card">
          <div className="md-card-header-row">
            <div><div className="md-card-title">{t("dash_announcements")}</div><div className="md-card-sub">{t("dash_latest_updates")}</div></div>
            <button className="md-view-all-btn" onClick={()=>navigate("/member/announcements")}>{t("dash_view_all")}</button>
          </div>
          <div className="md-notif-list">
            {notifs.length===0
              ? <div style={{textAlign:"center",padding:"20px",color:"#aaa",fontSize:12}}>{t("dash_no_announcements")}</div>
              : notifs.map((n,i)=>(
                <div key={i} className="md-notif-item">
                  <div className="md-notif-icon"><Megaphone size={16} color="#1565c0"/></div>
                  <div className="md-notif-body">
                    <div className="md-notif-msg">{n.title}</div>
                    <div className="md-notif-time">{n.created_at}</div>
                  </div>
                </div>
              ))}
          </div>
        </div>
      </div>
    </div>
  );
}