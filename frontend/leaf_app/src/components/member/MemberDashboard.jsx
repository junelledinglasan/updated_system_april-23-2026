import { useState, useEffect } from "react";
import { useOutletContext, useNavigate } from "react-router-dom";
import { Line, Doughnut } from "react-chartjs-2";
import {
  Chart as ChartJS, CategoryScale, LinearScale,
  PointElement, LineElement, ArcElement,
  Title, Tooltip, Legend, Filler,
} from "chart.js";
import { Wallet, CalendarClock, CheckCircle2, TrendingUp, CreditCard, Megaphone, Bell } from "lucide-react";
import { getLoansAPI } from "../../api/loans";
import { getPaymentsAPI } from "../../api/payments";
import { getAnnouncementsAPI } from "../../api/announcements";
import "./MemberDashboard.css";

ChartJS.register(CategoryScale, LinearScale, PointElement, LineElement, ArcElement, Title, Tooltip, Legend, Filler);

function NonOfficialWelcome({ member, navigate }) {
  const firstname = member.name.split(" ")[0];
  return (
    <div className="md-wrapper">
      <div className="md-banner">
        <div>
          <div className="md-banner-greeting">Welcome, {firstname}! 👋</div>
          <div className="md-banner-sub">You're almost there. Complete your membership to unlock all features.</div>
        </div>
        <div className="md-banner-chip">
          <div className="md-banner-avatar">{member.initials}</div>
          <div>
            <div className="md-banner-name">{member.name}</div>
            <div className="md-banner-id">Pending Membership</div>
          </div>
          <span className="md-pending-badge">Pending</span>
        </div>
      </div>
      <div className="md-unofficial-card">
        <div className="md-unofficial-header">
          <div className="md-unofficial-icon">⏳</div>
          <div>
            <div className="md-unofficial-title">Account Not Yet Official</div>
            <div className="md-unofficial-sub">Your account is created but you are not yet an official LEAF MPC member. Some features are currently locked.</div>
          </div>
        </div>
        <div className="md-access-grid">
          <div className="md-access-col locked-col">
            <div className="md-access-col-title">🔒 Locked Features</div>
            <div className="md-access-item locked">Dashboard overview</div>
            <div className="md-access-item locked">My Loans & payments</div>
            <div className="md-access-item locked">Apply for Loan</div>
          </div>
          <div className="md-access-col open-col">
            <div className="md-access-col-title">✅ Available Now</div>
            <div className="md-access-item open">Notifications</div>
            <div className="md-access-item open">Announcements</div>
            <div className="md-access-item open">My Profile</div>
          </div>
        </div>
        <div className="md-unofficial-actions">
          <button className="md-cta-primary" onClick={() => navigate("/member/apply-membership")}>Apply for Official Membership</button>
        </div>
      </div>
    </div>
  );
}

export default function MemberDashboard() {
  const ctx      = useOutletContext() || {};
  const navigate = useNavigate();
  const member   = ctx.member || { name: "Member", memberId: "—", initials: "M", isOfficial: false };

  // ALL hooks declared BEFORE any conditional return — Rules of Hooks
  const [loans,    setLoans]    = useState([]);
  const [payments, setPayments] = useState([]);
  const [notifs,   setNotifs]   = useState([]);
  const [loading,  setLoading]  = useState(true);

  useEffect(() => {
    if (!member.isOfficial) { setLoading(false); return; }
    Promise.allSettled([getLoansAPI(), getPaymentsAPI(), getAnnouncementsAPI()])
      .then(([l, p, n]) => {
        if (l.status === "fulfilled") setLoans(l.value);
        if (p.status === "fulfilled") setPayments(p.value);
        if (n.status === "fulfilled") setNotifs(n.value.slice(0, 3));
      }).finally(() => setLoading(false));
  }, [member.isOfficial]);

  // Conditional return AFTER all hooks
  if (!member.isOfficial) return <NonOfficialWelcome member={member} navigate={navigate} />;

  const activeLoan   = loans.find(l => l.status === "Active") || loans[0] || null;
  const totalLoan    = parseFloat(activeLoan?.amount || 0);
  const balance      = parseFloat(activeLoan?.balance || 0);
  const totalPaid    = totalLoan - balance;
  const monthlyDue   = parseFloat(activeLoan?.monthly_due || 0);
  const paidPct      = totalLoan > 0 ? Math.round((totalPaid / totalLoan) * 100) : 0;
  const shareCapital = parseFloat(member.share_capital || 0);
  const firstname    = member.name.split(" ")[0];

  const lineData = {
    labels: payments.slice(0,6).map(p => p.paid_at?.slice(0,7) || ""),
    datasets: [{ label:"Payment", data: payments.slice(0,6).map(p => parseFloat(p.amount)),
      borderColor:"#2e7d32", backgroundColor:"rgba(46,125,50,0.08)",
      fill:true, tension:0.4, pointRadius:4, pointBackgroundColor:"#2e7d32", borderWidth:2 }],
  };
  const doughnutData = {
    labels: ["Paid","Remaining"],
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
          <div className="md-banner-greeting">Good day, {firstname}!</div>
          <div className="md-banner-sub">Here's a summary of your LEAF MPC account.</div>
        </div>
        <div className="md-banner-chip">
          <div className="md-banner-avatar">{member.initials}</div>
          <div><div className="md-banner-name">{member.name}</div><div className="md-banner-id">{member.memberId}</div></div>
          <span className="md-active-badge">Active</span>
        </div>
      </div>

      <div className="md-kpi-grid">
        <div className="md-kpi-card md-kpi-danger">
          <div className="md-kpi-icon"><Wallet size={22} color="#c62828"/></div>
          <div>
            <div className="md-kpi-label">Remaining Balance</div>
            <div className="md-kpi-val red">₱{balance.toLocaleString()}</div>
            <div className="md-kpi-sub">{activeLoan?.loan_type || "No active loan"} · {activeLoan?.loan_id || "—"}</div>
          </div>
        </div>
        <div className="md-kpi-card">
          <div className="md-kpi-icon"><CalendarClock size={22} color="#e65100"/></div>
          <div>
            <div className="md-kpi-label">Next Payment Due</div>
            <div className="md-kpi-val orange">₱{monthlyDue.toLocaleString()}</div>
            <div className="md-kpi-sub">{activeLoan?.next_due_date || "—"}</div>
          </div>
        </div>
        <div className="md-kpi-card">
          <div className="md-kpi-icon"><CheckCircle2 size={22} color="#2e7d32"/></div>
          <div>
            <div className="md-kpi-label">Total Paid</div>
            <div className="md-kpi-val green">₱{totalPaid.toLocaleString()}</div>
            <div className="md-kpi-sub">{paidPct}% of loan completed</div>
          </div>
        </div>
        <div className="md-kpi-card">
          <div className="md-kpi-icon"><TrendingUp size={22} color="#1565c0"/></div>
          <div>
            <div className="md-kpi-label">Share Capital</div>
            <div className="md-kpi-val blue">₱{shareCapital.toLocaleString()}</div>
            <div className="md-kpi-sub">Max loanable: ₱{shareCapital.toLocaleString()}</div>
          </div>
        </div>
      </div>

      <div className="md-mid-row">
        <div className="md-card md-progress-card">
          <div className="md-card-title">Loan Repayment Progress</div>
          <div className="md-card-sub">{activeLoan?.loan_type || "—"} — {activeLoan?.loan_id || "—"}</div>
          <div className="md-progress-bar-wrap">
            <div className="md-progress-bar"><div className="md-progress-fill" style={{width:paidPct+"%"}}/></div>
            <div className="md-progress-labels">
              <span className="green fw">₱{totalPaid.toLocaleString()} paid</span>
              <span>{paidPct}%</span>
              <span className="red">₱{balance.toLocaleString()} left</span>
            </div>
          </div>
          <div className="md-loan-details">
            <div className="md-loan-detail-item"><span className="md-ld-label">Principal</span><span className="md-ld-val">₱{totalLoan.toLocaleString()}</span></div>
            <div className="md-loan-detail-item"><span className="md-ld-label">Monthly Due</span><span className="md-ld-val green">₱{monthlyDue.toLocaleString()}</span></div>
            <div className="md-loan-detail-item"><span className="md-ld-label">Status</span><span className="md-loan-status-badge current">{activeLoan?.status || "—"}</span></div>
            <div className="md-loan-detail-item"><span className="md-ld-label">Next Due</span><span className="md-ld-val">{activeLoan?.next_due_date || "—"}</span></div>
          </div>
        </div>
        <div className="md-card">
          <div className="md-card-title">Loan Breakdown</div>
          <div className="md-card-sub">Paid vs Remaining</div>
          <div style={{height:200}}><Doughnut data={doughnutData} options={doughnutOpts}/></div>
        </div>
      </div>

      <div className="md-bot-row">
        <div className="md-card">
          <div className="md-card-title">Payment History</div>
          <div className="md-card-sub">Last 6 months</div>
          <div style={{height:180}}>
            {payments.length===0
              ? <div style={{textAlign:"center",padding:"40px",color:"#aaa",fontSize:13}}>No payment history yet.</div>
              : <Line data={lineData} options={lineOpts}/>}
          </div>
        </div>
        <div className="md-card">
          <div className="md-card-header-row">
            <div><div className="md-card-title">Recent Transactions</div><div className="md-card-sub">Latest payment records</div></div>
            <button className="md-view-all-btn" onClick={()=>navigate("/member/my-loans")}>View All →</button>
          </div>
          <div className="md-tx-list">
            {payments.length===0
              ? <div style={{textAlign:"center",padding:"20px",color:"#aaa",fontSize:12}}>No transactions yet.</div>
              : payments.slice(0,5).map((tx,i)=>(
                <div key={i} className="md-tx-item">
                  <div className="md-tx-icon payment"><CreditCard size={16} color="#2e7d32"/></div>
                  <div className="md-tx-info"><div className="md-tx-desc">Loan Payment</div><div className="md-tx-date">{tx.paid_at}</div></div>
                  <div className="md-tx-amount red">−₱{Number(tx.amount).toLocaleString()}</div>
                </div>
              ))}
          </div>
        </div>
        <div className="md-card">
          <div className="md-card-header-row">
            <div><div className="md-card-title">Announcements</div><div className="md-card-sub">Latest updates</div></div>
            <button className="md-view-all-btn" onClick={()=>navigate("/member/announcements")}>View All →</button>
          </div>
          <div className="md-notif-list">
            {notifs.length===0
              ? <div style={{textAlign:"center",padding:"20px",color:"#aaa",fontSize:12}}>No announcements yet.</div>
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