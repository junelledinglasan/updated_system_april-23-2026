import { useState, useEffect } from "react";
import { useNavigate } from "react-router-dom";
import {
  Chart as ChartJS, CategoryScale, LinearScale,
  PointElement, LineElement, BarElement, ArcElement,
  Title, Tooltip, Legend, Filler,
} from "chart.js";
import { Line, Bar, Doughnut } from "react-chartjs-2";
import { TrendingUp, Users, UserX, UserPlus, Clock, Globe, CalendarDays, X, AlertTriangle, ArrowRight } from "lucide-react";
import { getOverviewAPI, getMonthlyCollectionAPI, getLoanStatusAPI, getLoanTypeAPI } from "../../api/reports";
import { getMemberStatsAPI, getMembersAPI } from "../../api/members";
import { getOnlineApplicationsAPI } from "../../api/members";
import { getDueDatesAPI, getLoansAPI } from "../../api/loans";
import { getActivityLogAPI } from "../../api/activity";
import "./Dashboard.css";

ChartJS.register(CategoryScale, LinearScale, PointElement, LineElement, BarElement, ArcElement, Title, Tooltip, Legend, Filler);

const MONTHS = ["January","February","March","April","May","June","July","August","September","October","November","December"];
const ACTIVITY_DOT_COLORS = { payment:"#4caf50", application:"#1565c0", pending:"#f57c00", register:"#4caf50", declined:"#e53935" };

function StatCard({ label, value, icon }) {
  return (
    <div className="stat-card" style={{display:"flex",alignItems:"center",justifyContent:"space-between",gap:10,background:"#fff",borderRadius:14,border:"1px solid #eef2ee",padding:"16px 18px",minWidth:0}}>
      <div style={{minWidth:0}}>
        <div className="stat-label" style={{fontSize:12,color:"#888",fontWeight:600,marginBottom:4,whiteSpace:"nowrap",overflow:"hidden",textOverflow:"ellipsis"}}>{label}</div>
        <div className="stat-value" style={{fontSize:20,fontWeight:800,color:"#222",whiteSpace:"nowrap",overflow:"hidden",textOverflow:"ellipsis"}}>{value}</div>
      </div>
      <div className="stat-icon" style={{flexShrink:0,width:44,height:44,borderRadius:12,background:"#f7faf7",display:"flex",alignItems:"center",justifyContent:"center"}}>{icon}</div>
    </div>
  );
}

function DueDateModal({ date, members, onClose }) {
  if (!date) return null;
  const formatted = new Date(date + "T00:00:00").toLocaleDateString("en-PH", { weekday:"long", year:"numeric", month:"long", day:"numeric" });
  return (
    <div className="cal-modal-overlay" onClick={onClose}>
      <div className="cal-modal-box" onClick={e=>e.stopPropagation()}>
        <div className="cal-modal-header">
          <div><div className="cal-modal-title" style={{display:"flex",alignItems:"center",gap:8}}><CalendarDays size={16}/> Collection Due</div><div className="cal-modal-sub">{formatted}</div></div>
          <button className="cal-modal-close" onClick={onClose}><X size={16}/></button>
        </div>
        <div className="cal-modal-body">
          {members.length===0 ? (
            <div className="cal-modal-empty">No members due on this date.</div>
          ) : (
            <div className="cal-due-list">
              {members.map((m,i)=>(
                <div key={i} className={`cal-due-item ${m.status==="Overdue"?"overdue":""}`}>
                  <div className="cal-due-avatar">{(m.member_name||"M")[0]}</div>
                  <div className="cal-due-info">
                    <div className="cal-due-name">{m.member_name}</div>
                    <div className="cal-due-meta">{m.member_id} · {m.loan_type}</div>
                  </div>
                  <div className="cal-due-amount">
                    <div className="cal-due-monthly">₱{Number(m.monthly_due).toLocaleString()}</div>
                    <div className="cal-due-label">monthly due</div>
                    {m.status==="Overdue" && <div className="cal-overdue-tag">OVERDUE</div>}
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
        <div className="cal-modal-footer">
          <div className="cal-modal-total">
            Total: <strong>₱{members.reduce((s,m)=>s+Number(m.monthly_due),0).toLocaleString()}</strong> from <strong>{members.length}</strong> member{members.length!==1?"s":""}
          </div>
          <button className="cal-modal-done" onClick={onClose}>Close</button>
        </div>
      </div>
    </div>
  );
}

function CollectionCalendar() {
  const today = new Date();
  const [year,    setYear]    = useState(today.getFullYear());
  const [month,   setMonth]   = useState(today.getMonth());
  const [dueDates,setDueDates]= useState({});
  const [selDate, setSelDate] = useState(null);
  const [loading, setLoading] = useState(false);

  const firstDay      = new Date(year, month, 1).getDay();
  const totalDays     = new Date(year, month + 1, 0).getDate();
  const prevMonthDays = new Date(year, month, 0).getDate();

  const prev = () => { if(month===0){setMonth(11);setYear(y=>y-1);}else setMonth(m=>m-1); };
  const next = () => { if(month===11){setMonth(0);setYear(y=>y+1);}else setMonth(m=>m+1); };

  useEffect(() => {
    setLoading(true);
    const mm = String(month+1).padStart(2,"0");
    getDueDatesAPI(`${year}-${mm}`)
      .then(data => setDueDates(data))
      .catch(e => console.error(e))
      .finally(() => setLoading(false));
  }, [year, month]);

  const days = ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"];

  const handleDayClick = (d) => {
    const mm  = String(month+1).padStart(2,"0");
    const dd  = String(d).padStart(2,"0");
    const key = `${year}-${mm}-${dd}`;
    if (dueDates[key]?.length > 0) setSelDate(key);
  };

  return (
    <>
      {selDate && <DueDateModal date={selDate} members={dueDates[selDate]||[]} onClose={()=>setSelDate(null)}/>}
      <div className="chart-card">
        <div className="card-header">
          <div><div className="card-title">Collection Calendar</div><div className="card-sub">{MONTHS[month]} {year}</div></div>
          <div className="legend">
            <div className="legend-item"><div className="legend-dot" style={{background:"#2e7d32"}}/>Today</div>
            <div className="legend-item"><div className="legend-dot" style={{background:"#c8e6c9"}}/>Due Date</div>
          </div>
        </div>
        <div className="cal-nav">
          <button className="cal-nav-btn" onClick={prev}>◀</button>
          <span className="cal-month-label">{MONTHS[month]} {year}</span>
          <button className="cal-nav-btn" onClick={next}>▶</button>
        </div>
        <div className="cal-grid">
          {days.map(d=><div key={d} className="cal-day-label">{d}</div>)}
          {Array.from({length:firstDay},(_,i)=>(
            <div key={`prev-${i}`} className="cal-day other-month">{prevMonthDays-firstDay+1+i}</div>
          ))}
          {Array.from({length:totalDays},(_,i)=>{
            const d   = i+1;
            const mm  = String(month+1).padStart(2,"0");
            const dd  = String(d).padStart(2,"0");
            const key = `${year}-${mm}-${dd}`;
            const isToday    = d===today.getDate()&&month===today.getMonth()&&year===today.getFullYear();
            const hasDue     = dueDates[key]?.length > 0;
            const hasOverdue = dueDates[key]?.some(m=>m.status==="Overdue");
            let cls = "cal-day";
            if (isToday) cls += " today";
            else if (hasOverdue) cls += " has-overdue";
            else if (hasDue) cls += " has-event clickable";
            if (hasDue && !isToday) cls += " clickable";
            return (
              <div key={d} className={cls} onClick={()=>handleDayClick(d)} title={hasDue?`${dueDates[key].length} member(s) due`:""}>
                {d}
                {hasDue && <span className="cal-due-dot">{dueDates[key].length}</span>}
              </div>
            );
          })}
        </div>
        {loading && <div style={{textAlign:"center",fontSize:11,color:"#aaa",padding:"4px 0"}}>Loading due dates...</div>}
      </div>
    </>
  );
}

function ActivityLog({ log }) {
  return (
    <div className="chart-card">
      <div className="card-header">
        <div><div className="card-title">Recent Activity Log</div><div className="card-sub">Latest system events</div></div>
      </div>
      <div className="activity-list">
        {log.length === 0 ? (
          <div style={{textAlign:"center",color:"#aaa",padding:"20px 0",fontSize:13}}>No recent activity yet.</div>
        ) : log.map((item,i) => (
          <div key={i} className="activity-item">
            <div className="activity-dot" style={{background: ACTIVITY_DOT_COLORS[item.type]||"#aaa"}}/>
            <div>
              <div className="activity-text">{item.text}</div>
              <div className="activity-time">{item.time}</div>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

export default function Dashboard() {
  const navigate = useNavigate();
  const [stats,      setStats]    = useState({ totalShareCapital:0, activeMembers:0, inactiveMembers:0, newMembersThisMonth:0, pendingLoanApprovals:0, onlineApplicants:0 });
  const [monthly,    setMonthly]  = useState([]);
  const [memberGrowth, setMemberGrowth] = useState([]);
  const [loanStat,   setLoanStat] = useState({});
  const [loanType,   setLoanType] = useState({});
  const [actLog,     setActLog]   = useState([]);
  // ── BAGO: "Overdue Alert" widget — para makita agad ng admin kung
  // sinong miyembro ang bagong-overdue, kasama ang kasalukuyang Loan
  // Multiplier nila, para makapag-desisyon kung babaguhin (hal.
  // i-downgrade papuntang 2x kung mahinang magbayad). ──────────────────
  const [overdueAlerts, setOverdueAlerts] = useState([]);
  const [loading,    setLoading]  = useState(true);

  useEffect(() => {
    const load = async () => {
      try {
        const currentYear = new Date().getFullYear();
        const [overview, mon, ls, lt, activeLoansRes, onlineApps, activity, membersRes] = await Promise.allSettled([
          getOverviewAPI(currentYear),
          getMonthlyCollectionAPI(currentYear),
          getLoanStatusAPI("All"),
          getLoanTypeAPI("All"),
          getLoansAPI(),
          getOnlineApplicationsAPI(),
          getActivityLogAPI(7),
          getMembersAPI(),
        ]);

        if (overview.status === "fulfilled") {
          const d = overview.value;

          // ── Online applicants — count Pending from online applications ──
          let onlineCount = 0;
          if (onlineApps.status === "fulfilled") {
            const appList = onlineApps.value.applications || (Array.isArray(onlineApps.value) ? onlineApps.value : []);
            onlineCount = appList.filter(a => a.application_status === "Pending").length;
          }

          // ── BAGO: Active/Inactive member counts — kinukuha mula sa
          // parehong members list (client-side count), para consistent
          // ang basehan ng dalawang stat na 'to sa isa't isa. ─────────
          let activeCount = d.active_members || 0;
          let inactiveCount = 0;
          let newThisMonth = 0;
          let growthByMonth = Array(12).fill(0);
          if (membersRes.status === "fulfilled") {
            const memberList = Array.isArray(membersRes.value) ? membersRes.value : (membersRes.value.results || []);
            activeCount = memberList.filter(m => m.status === "Active" || m.membership_status === "Active").length;
            inactiveCount = memberList.filter(m => m.status === "Inactive" || m.membership_status === "Inactive").length;

            // ── BAGO: "New Members This Month" + buong-taong growth
            // trend — parehong base sa "membership_date" ng bawat
            // member. ──────────────────────────────────────────────
            const now = new Date();
            memberList.forEach(m => {
              if (!m.membership_date) return;
              const d2 = new Date(m.membership_date);
              if (d2.getFullYear() === now.getFullYear()) {
                growthByMonth[d2.getMonth()] += 1;
                if (d2.getMonth() === now.getMonth()) newThisMonth += 1;
              }
            });
          }
          setMemberGrowth(growthByMonth);

          setStats({
            totalShareCapital:    d.total_share_capital || 0,
            activeMembers:        activeCount,
            inactiveMembers:      inactiveCount,
            newMembersThisMonth:  newThisMonth,
            pendingLoanApprovals: d.pending_loans       || 0,
            onlineApplicants:     onlineCount,
          });
        }

        if (mon.status === "fulfilled") setMonthly(mon.value);
        if (ls.status  === "fulfilled") setLoanStat(ls.value);

        // ── Loan type breakdown from active loans ──
        if (activeLoansRes.status === "fulfilled") {
          const actLoans = activeLoansRes.value.filter(l => ["Active","Overdue"].includes(l.status));
          const breakdown = {};
          actLoans.forEach(l => {
            const t = l.loan_type || "Other";
            breakdown[t] = (breakdown[t] || 0) + 1;
          });
          if (Object.keys(breakdown).length > 0) setLoanType(breakdown);
          else if (lt.status === "fulfilled") setLoanType(lt.value);

          // ── BAGO: "Overdue Alert" — kunin ang mga Overdue loans,
          // i-cross-reference sa members list para makuha ang
          // kasalukuyang Loan Multiplier ng bawat isa. ─────────────────
          const overdueLoans = actLoans.filter(l => l.status === "Overdue");
          if (overdueLoans.length > 0 && membersRes.status === "fulfilled") {
            const memberList = Array.isArray(membersRes.value) ? membersRes.value : (membersRes.value.results || []);
            const alerts = overdueLoans.map(l => {
              const mem = memberList.find(m => m.id === l.member);
              return {
                loan_id: l.loan_id,
                member_id: l.member,
                member_name: l.member_name,
                member_code: l.member_code,
                loan_multiplier: mem?.loan_multiplier || 1,
                total_penalty: parseFloat(l.total_penalty || 0),
                months_overdue: l.months_overdue_penalized || 0,
                balance: parseFloat(l.balance || 0),
              };
            });
            setOverdueAlerts(alerts);
          }
        } else if (lt.status === "fulfilled") {
          setLoanType(lt.value);
        }

        if (activity.status === "fulfilled") setActLog(activity.value);

      } catch(e) { console.error(e); }
      finally { setLoading(false); }
    };
    load();
  }, []);

  const monthLabels = monthly.map(m=>m.month);
  const monthValues = monthly.map(m=>m.total);

  const lineData = {
    labels: monthLabels.length ? monthLabels : ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"],
    datasets: [{
      label: "Collection",
      data: monthValues.length ? monthValues : Array(12).fill(0),
      borderColor: "#2e7d32", backgroundColor: "rgba(46,125,50,0.08)",
      fill: true, tension: 0.4, pointRadius: 3, pointBackgroundColor: "#2e7d32", borderWidth: 2,
    }],
  };

  // ── BAGO: "Member Growth" chart — bagong miyembro per month, buong
  // taon, kaparehong istilo ng "Overall Collection" chart. ────────────
  const memberGrowthData = {
    labels: ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"],
    datasets: [{
      label: "New Members",
      data: memberGrowth.length ? memberGrowth : Array(12).fill(0),
      borderColor: "#1565c0", backgroundColor: "rgba(21,101,192,0.08)",
      fill: true, tension: 0.4, pointRadius: 3, pointBackgroundColor: "#1565c0", borderWidth: 2,
    }],
  };

  const barLabels = Object.keys(loanStat);
  const barData = {
    labels: barLabels.length ? barLabels : ["For Review","Active","Declined","Completed","Overdue"],
    datasets: [{
      data: barLabels.length ? Object.values(loanStat) : [0,0,0,0,0],
      backgroundColor: ["#f57c00","#2e7d32","#e53935","#1565c0","#c62828"],
      borderRadius: 5, borderSkipped: false,
    }],
  };

  const donutLabels = Object.keys(loanType);
  // ── FIX: dating luma pang loan types ang fallback dito (Regular/
  // Emergency/Salary/Housing/Business) — tugma na ngayon sa bagong 4
  // types (Regular, Petty Cash, Appliance, ATM). ──────────────────────
  const doughnutData = {
    labels: donutLabels.length ? donutLabels : ["Regular Loan","Petty Cash Loan","Appliance Loan","ATM Loan"],
    datasets: [{
      data: donutLabels.length ? Object.values(loanType) : [0,0,0,0],
      backgroundColor: ["#2e7d32","#4caf50","#f57c00","#1565c0"],
      borderWidth: 0, hoverOffset: 4,
    }],
  };

  const lineOptions     = { responsive:true, plugins:{ legend:{display:false}, tooltip:{mode:"index",intersect:false} }, scales:{ x:{grid:{display:false}}, y:{grid:{color:"#f0f4f1"}, ticks:{callback:v=>"₱"+v.toLocaleString()}} } };
  // ── BAGO: hiwalay na options para sa Member Growth chart — walang
  // peso formatting (bilang ng tao, hindi pera), buong numero lang
  // ang ticks. ─────────────────────────────────────────────────────────
  const memberGrowthOptions = { responsive:true, plugins:{ legend:{display:false}, tooltip:{mode:"index",intersect:false} }, scales:{ x:{grid:{display:false}}, y:{grid:{color:"#f0f4f1"}, ticks:{precision:0}} } };
  const barOptions      = { responsive:true, plugins:{legend:{display:false}}, scales:{ x:{grid:{display:false}}, y:{grid:{color:"#f0f4f1"}} } };
  const doughnutOptions = { responsive:true, cutout:"68%", plugins:{ legend:{position:"bottom",labels:{boxWidth:8,padding:8,font:{size:10}}} } };

  return (
    <div className="dashboard-content">
      {/* ── BAGO: dating walang visible na title/description sa loob
          ng page content mismo (naka-asa lang sa PAGE_CONFIG na
          hindi naman pala nire-render sa topbar). Idinagdag dito,
          tulad ng pattern sa ibang pages (Manage Members, atbp.). ──── */}
      <div style={{marginBottom:18}}>
        <div style={{fontSize:24,fontWeight:800,color:"#1b5e20",lineHeight:1.2,letterSpacing:"-0.3px"}}>Office Operations Dashboard</div>
        <div style={{fontSize:11,color:"#aaa",marginTop:3}}>Manage LEAF MPC member records and financial audits.</div>
      </div>
      {/* ── FIX: dating 4 lang ang design ng ".stat-grid" CSS class,
          6 na ngayon ang cards — nagmumukhang basta na lang naka-
          patong-patong. Explicit na inline grid na ngayon: 3 columns
          x 2 rows, pantay-pantay lahat. ────────────────────────────── */}
      <div className="stat-grid" style={{display:"grid",gridTemplateColumns:"repeat(3, 1fr)",gap:16}}>
        <StatCard label="Total Share Capital"    value={`₱${Number(stats.totalShareCapital).toLocaleString()}`} icon={<TrendingUp size={22} color="#2e7d32"/>}/>
        <StatCard label="Active Members"         value={stats.activeMembers}                                    icon={<Users size={22} color="#1565c0"/>}/>
        {/* ── BAGO: hiwalay na "Inactive Members" card — dating wala,
            kailangan makita ito bilang sarili nitong stat, hindi
            pinagsama sa Active. ─────────────────────────────────────── */}
        <StatCard label="Inactive Members"       value={stats.inactiveMembers}                                  icon={<UserX size={22} color="#757575"/>}/>
        {/* ── BAGO: "New Members This Month" — growth indicator. ──── */}
        <StatCard label="New Members This Month" value={stats.newMembersThisMonth}                              icon={<UserPlus size={22} color="#2e7d32"/>}/>
        <StatCard label="Pending Loan Approvals" value={stats.pendingLoanApprovals}                             icon={<Clock size={22} color="#f57c00"/>}/>
        <StatCard label="Online Applicants"      value={stats.onlineApplicants}                                 icon={<Globe size={22} color="#6a1b9a"/>}/>
      </div>

      {/* ── FIX: dating 2 lang ang design ng ".chart-row" CSS class,
          3 na ngayon ang charts. Explicit na inline grid — pantay-
          pantay na 3 columns. ─────────────────────────────────────── */}
      <div className="chart-row" style={{display:"grid",gridTemplateColumns:"repeat(3, 1fr)",gap:16}}>
        <div className="chart-card">
          <div className="card-header">
            <div><div className="card-title">Overall Collection</div><div className="card-sub">Monthly collection trend</div></div>
            <div className="legend"><div className="legend-item"><div className="legend-dot" style={{background:"#2e7d32"}}/>Collection</div></div>
          </div>
          <div style={{height:220}}><Line data={lineData} options={{...lineOptions, maintainAspectRatio:false}}/></div>
        </div>
        {/* ── BAGO: "Member Growth" chart — bagong miyembro per month,
            kasabay ng Overall Collection dahil parehong monthly trend
            charts. ──────────────────────────────────────────────────── */}
        <div className="chart-card">
          <div className="card-header">
            <div><div className="card-title">Member Growth</div><div className="card-sub">New registrations per month</div></div>
            <div className="legend"><div className="legend-item"><div className="legend-dot" style={{background:"#1565c0"}}/>New Members</div></div>
          </div>
          <div style={{height:220}}><Line data={memberGrowthData} options={{...memberGrowthOptions, maintainAspectRatio:false}}/></div>
        </div>
        <div className="chart-card">
          <div className="card-header"><div><div className="card-title">Loan Status Summary</div><div className="card-sub">All-time distribution</div></div></div>
          <div style={{height:220}}><Bar data={barData} options={{...barOptions, maintainAspectRatio:false}}/></div>
        </div>
      </div>

      {/* ── BAGO: "Overdue Alert" widget — makikita agad ng admin ang
          mga miyembrong may bagong-overdue na loan, kasama ang
          kasalukuyang Loan Multiplier nila, para agad silang
          makapag-desisyon (hal. i-downgrade papuntang 2x kung mahinang
          magbayad, o panatilihin sa 3x). Lumalabas lang kapag may
          talagang overdue. ─────────────────────────────────────────── */}
      {overdueAlerts.length > 0 && (
        <div style={{background:"#fff", border:"1px solid #f8bbd0", borderRadius:12, padding:16, marginBottom:16, boxShadow:"0 1px 4px rgba(0,0,0,0.03)"}}>
          <div style={{display:"flex", alignItems:"center", gap:8, marginBottom:12}}>
            <AlertTriangle size={16} color="#c62828"/>
            <div style={{fontSize:14, fontWeight:800, color:"#c62828"}}>Overdue Loan Alert ({overdueAlerts.length})</div>
          </div>
          <div style={{fontSize:11.5, color:"#888", marginBottom:12}}>
            Ang mga miyembrong ito ay may loan na naliban na sa due date. Suriin kung dapat baguhin ang kanilang Loan Multiplier.
          </div>
          <div style={{display:"flex", flexDirection:"column", gap:8}}>
            {overdueAlerts.map(a => (
              <div key={a.loan_id} style={{display:"flex", alignItems:"center", justifyContent:"space-between", background:"#fce4ec", borderRadius:8, padding:"10px 14px", flexWrap:"wrap", gap:8}}>
                <div>
                  <div style={{fontSize:12.5, fontWeight:700, color:"#1b1b1b"}}>{a.member_name} <span style={{fontWeight:400, color:"#888", fontFamily:"monospace", fontSize:10.5}}>{a.member_code}</span></div>
                  <div style={{fontSize:11, color:"#c62828"}}>
                    {a.loan_id} · {a.months_overdue} month{a.months_overdue!==1?"s":""} overdue
                    {a.total_penalty > 0 && <> · +₱{a.total_penalty.toLocaleString()} penalty</>}
                    {" · "}Current multiplier: <strong>{a.loan_multiplier}×</strong>
                  </div>
                </div>
                <button onClick={() => navigate("/admin/members", { state: { openMemberId: a.member_id } })} style={{
                  display:"flex", alignItems:"center", gap:6, background:"#c62828", color:"#fff",
                  border:"none", borderRadius:8, padding:"7px 14px", fontSize:11.5, fontWeight:700, cursor:"pointer",
                }}>
                  Review Member <ArrowRight size={13}/>
                </button>
              </div>
            ))}
          </div>
        </div>
      )}

      <div className="bottom-row">
        <CollectionCalendar/>
        <ActivityLog log={actLog}/>
        <div className="chart-card">
          <div className="card-header"><div><div className="card-title">Loan Type Breakdown</div><div className="card-sub">Active & Overdue by category</div></div></div>
          <div style={{height:220,display:"flex",alignItems:"center",justifyContent:"center"}}>
            <Doughnut data={doughnutData} options={{...doughnutOptions, maintainAspectRatio:false}}/>
          </div>
        </div>
      </div>
    </div>
  );
}