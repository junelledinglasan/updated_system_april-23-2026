import { useState, useEffect } from "react";
import { Bar, Doughnut, Line } from "react-chartjs-2";
import {
  Chart as ChartJS,
  CategoryScale, LinearScale, BarElement, ArcElement,
  PointElement, LineElement,
  Title, Tooltip, Legend, Filler,
} from "chart.js";
import {
  getOverviewAPI, getMonthlyCollectionAPI, getLoanStatusAPI, getLoanTypeAPI,
  getPaymentBehaviorAPI, getAuditLogAPI, previewReportAPI, exportExcel, exportPDF,
  getClassificationAPI, getMemberPerformanceAPI, getTopBorrowersAPI,
  getLoanDistributionAPI, getYearlyComparisonAPI, getShareCapitalAPI,
  getOverdueAnalysisAPI, getMonthlyLoansAPI,
  getRepaymentProgressAPI, getDelinquencyAPI, getCollectionEfficiencyAPI,
  getMemberGrowthAPI, getLoanApprovalRateAPI, getUpcomingMaturitiesAPI,
  getFirstTimeBorrowersAPI, getRiskAssessmentAPI,
} from "../../api/reports";
import {
  BarChart2, TrendingUp, FileText, Link2, Users, PieChart,
  Wallet, ClipboardList, AlertTriangle, PiggyBank,
  CreditCard, Link, Trophy, BarChart, Database,
  Calendar, UserPlus, Shield,
  Activity, Clock, CheckCircle, XCircle, Percent,
  BookOpen, Layers, Award, ArrowUpRight, Coins,
  X, Download, Eye, Check,
} from "lucide-react";
import "./Reports.css";

ChartJS.register(CategoryScale, LinearScale, BarElement, ArcElement, PointElement, LineElement, Title, Tooltip, Legend, Filler);

const COLORS = ["#2e7d32","#4caf50","#f57c00","#1565c0","#c62828","#6a1b9a","#00838f","#ff8a65","#64b5f6","#ba68c8"];
const YEAR   = new Date().getFullYear();
// ── BAGO: tinanggal ang "YEARS" array (fixed 6-year list) — hindi na
// kailangan, ang year filter ay prev/next navigation na, kaya kahit
// anong taon ay maaabot. ─────────────────────────────────────────────

const REPORT_TYPES = [
  "Financial Summary","Collection Report","Loan Summary","Member Report",
  "Payment Behavior","Blockchain Audit Log","Member Performance Report",
  "Classification Analytics","Savings Report",
];

// ─── Chart default options ────────────────────────────────────────────────────
const chartOpts = (ylabel = "") => ({
  responsive: true, maintainAspectRatio: false,
  plugins: { legend: { display: false }, tooltip: { mode: "index", intersect: false } },
  scales: {
    x: { grid: { display: false }, ticks: { font: { size: 10 }, color: "#888" } },
    y: { grid: { color: "#f0f4f1" }, ticks: { font: { size: 10 }, color: "#888", callback: v => ylabel ? ylabel + v.toLocaleString() : v } },
  },
});
const donutOpts = {
  responsive: true, maintainAspectRatio: false, cutout: "62%",
  plugins: { legend: { position: "right", labels: { boxWidth: 10, font: { size: 10 }, color: "#555" } } },
};

// ─── Report Preview Modal ─────────────────────────────────────────────────────
function ReportPreviewModal({ type, dateFrom, dateTo, onClose }) {
  const [data,      setData]    = useState(null);
  const [loading,   setLoading] = useState(true);
  const [exporting, setExp]     = useState("");

  useEffect(() => {
    if (!type) return;
    setLoading(true);
    setData(null);
    previewReportAPI(type, dateFrom, dateTo)
      .then(d => setData(d))
      .catch(() => setData({ error: true }))
      .finally(() => setLoading(false));
  }, [type, dateFrom, dateTo]);

  if (!type) return null;

  const doExcel = async () => { setExp("excel"); try { await exportExcel(type, dateFrom, dateTo); } catch { alert("Export failed."); } finally { setExp(""); } };
  const doPDF   = async () => { setExp("pdf");   try { await exportPDF(type, dateFrom, dateTo);   } catch { alert("Export failed."); } finally { setExp(""); } };

  return (
    <div className="rp-overlay" onClick={onClose}>
      <div className="rp-modal rp-modal-lg" onClick={e => e.stopPropagation()}>
        <div className="rp-modal-header">
          <div>
            <div className="rp-modal-title" style={{display:"flex",alignItems:"center",gap:8}}><FileText size={17}/> {type}</div>
            <div className="rp-modal-sub">{dateFrom} to {dateTo}</div>
          </div>
          <button className="rp-modal-close" onClick={onClose}><X size={16}/></button>
        </div>
        <div className="rp-modal-body">
          {loading ? (
            <div style={{display:"flex",flexDirection:"column",alignItems:"center",gap:16,padding:"48px 20px"}}>
              <div style={{width:40,height:40,border:"4px solid #e8f5e9",borderTop:"4px solid #2e7d32",borderRadius:"50%",animation:"spin 0.8s linear infinite"}}/>
              <div style={{fontSize:13,color:"#888"}}>Generating {type}...</div>
              <div style={{fontSize:11,color:"#bbb"}}>This may take a few seconds</div>
              <style>{`@keyframes spin{to{transform:rotate(360deg)}}`}</style>
            </div>
          ) : !data || data.error ? (
            <div className="rp-no-data">Failed to load report. Try again.</div>
          ) : (
            <>
              {data.summary?.length > 0 && (
                <div className="rp-preview-summary">
                  {data.summary.map(([label, val], i) => (
                    <div key={i} className="rp-sum-item">
                      <span className="rp-sum-label">{label}</span>
                      <span className="rp-sum-val">{val}</span>
                    </div>
                  ))}
                </div>
              )}
              {data.columns?.length > 0 && (
                <>
                  <div className="rp-preview-count">
                    Showing {Math.min(data.rows?.length || 0, 50)} of {data.total_rows} records
                    {data.total_rows > 50 && " — Export for complete data"}
                  </div>
                  <div className="rp-preview-table-wrap">
                    <table className="rp-preview-table">
                      <thead><tr>{data.columns.map((c,i) => <th key={i}>{c}</th>)}</tr></thead>
                      <tbody>
                        {!data.rows?.length
                          ? <tr><td colSpan={data.columns.length} style={{textAlign:"center",padding:20,color:"#aaa"}}>No records for this period.</td></tr>
                          : data.rows.map((row,ri) => <tr key={ri}>{row.map((cell,ci) => <td key={ci}>{cell}</td>)}</tr>)
                        }
                      </tbody>
                    </table>
                  </div>
                </>
              )}
            </>
          )}
        </div>
        <div className="rp-modal-footer">
          <button className="rp-btn-cancel" onClick={onClose}>Close</button>
          <button className="rp-btn-export excel" onClick={doExcel} disabled={!!exporting} style={{display:"flex",alignItems:"center",gap:6,justifyContent:"center"}}>{exporting==="excel"?"Exporting...":<><Download size={13}/> Excel</>}</button>
          <button className="rp-btn-export pdf"   onClick={doPDF}   disabled={!!exporting} style={{display:"flex",alignItems:"center",gap:6,justifyContent:"center"}}>{exporting==="pdf"?"Exporting...":<><FileText size={13}/> PDF</>}</button>
        </div>
      </div>
    </div>
  );
}

// ─── Professional Table ───────────────────────────────────────────────────────
function ProTable({ columns, rows, empty = "No data available." }) {
  if (!rows || !rows.length) return (
    <div style={{textAlign:"center",padding:"32px",color:"#bbb",fontSize:13}}>{empty}</div>
  );
  return (
    <div className="rp-pro-table-wrap">
      <table className="rp-pro-table">
        <thead>
          <tr>{columns.map((c,i) => <th key={i} style={c.style}>{c.label}</th>)}</tr>
        </thead>
        <tbody>
          {rows.map((row, ri) => (
            <tr key={ri}>
              {columns.map((c, ci) => (
                <td key={ci} style={c.tdStyle}>
                  {c.render ? c.render(row, ri) : row[c.key]}
                </td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

// ─── Rating Badge ─────────────────────────────────────────────────────────────
function RatingBadge({ rating }) {
  const map = {
    Excellent: { bg:"#e8f5e9", color:"#1b5e20" },
    Good:      { bg:"#f1f8e9", color:"#2e7d32" },
    Fair:      { bg:"#fff8e1", color:"#f57c00" },
    Poor:      { bg:"#ffebee", color:"#c62828" },
  };
  const s = map[rating] || { bg:"#eee", color:"#555" };
  return <span style={{background:s.bg,color:s.color,border:`1px solid ${s.color}33`,borderRadius:12,padding:"2px 10px",fontSize:11,fontWeight:700}}>{rating}</span>;
}

// ─── Main ─────────────────────────────────────────────────────────────────────
export default function Reports() {
  const [activeTab,    setTab]      = useState("overview");
  const [selectedYear, setYear]     = useState(YEAR);
  const [loading,      setLoading]  = useState(true);
  const [dateFrom,     setDateFrom] = useState(`${YEAR}-01-01`);
  const [dateTo,       setDateTo]   = useState(`${YEAR}-12-31`);
  const [reportType,   setReport]   = useState("");
  const [showPreview,  setPreview]  = useState(false);
  const [exporting,    setExp]      = useState("");

  const [overview,       setOverview]      = useState({});
  const [monthly,        setMonthly]       = useState([]);
  const [loanStat,       setLoanStat]      = useState({});
  const [loanType,       setLoanType]      = useState({});
  const [payBehav,       setPayBehav]      = useState({});
  const [auditLog,       setAuditLog]      = useState([]);
  const [classification, setClass]         = useState([]);
  const [memberPerf,     setMemberPerf]    = useState([]);
  const [topBorrowers,   setTopBorrowers]  = useState({ data: [] });
  const [loanDist,       setLoanDist]      = useState([]);
  const [yearlyComp,     setYearlyComp]    = useState([]);
  const [shareCapital,   setShareCapital]  = useState([]);
  const [overdue,        setOverdue]       = useState([]);
  const [monthlyLoans,   setMonthlyLoans]  = useState([]);
  const [fetchedTabs,    setFetchedTabs]   = useState({});

  // ── New analytics state ──
  const [repayment,      setRepayment]     = useState([]);
  const [delinquency,    setDelinquency]   = useState({ count:0, data:[] });
  const [efficiency,     setEfficiency]    = useState({ data:[], expected_monthly:0 });
  const [memberGrowth,   setMemberGrowth]  = useState({ data:[], total_members:0 });
  const [approvalRate,   setApprovalRate]  = useState({ by_type:[], monthly:[] });
  const [maturities,     setMaturities]    = useState({ count:0, data:[] });
  const [firstTimers,    setFirstTimers]   = useState({ count:0, data:[] });
  const [riskData,       setRiskData]      = useState({ summary:{}, data:[] });
  const [delinqMonths,   setDelinqMonths]  = useState(1);
  const [maturMonths,    setMaturMonths]   = useState(3);

  useEffect(() => { setFetchedTabs({}); }, [selectedYear]);

  useEffect(() => {
    const key = activeTab + String(selectedYear);
    if (fetchedTabs[key]) return;
    setLoading(true);
    const load = async () => {
      try {
        if (activeTab === "overview") {
          const [ov, mn, yc, ml, eff, mat, mg] = await Promise.allSettled([
            getOverviewAPI(selectedYear), getMonthlyCollectionAPI(selectedYear),
            getYearlyComparisonAPI(), getMonthlyLoansAPI(selectedYear),
            getCollectionEfficiencyAPI(selectedYear),
            getUpcomingMaturitiesAPI(maturMonths),
            getMemberGrowthAPI(selectedYear),
          ]);
          if (ov.status==="fulfilled")  setOverview(ov.value);
          if (mn.status==="fulfilled")  setMonthly(mn.value);
          if (yc.status==="fulfilled")  setYearlyComp(yc.value);
          if (ml.status==="fulfilled")  setMonthlyLoans(ml.value);
          if (eff.status==="fulfilled") setEfficiency(eff.value);
          if (mat.status==="fulfilled") setMaturities(mat.value);
          if (mg.status==="fulfilled")  setMemberGrowth(mg.value);
        } else if (activeTab === "charts") {
          const [mn, ls, lt, pb, ld, od, ar, rp] = await Promise.allSettled([
            getMonthlyCollectionAPI(selectedYear), getLoanStatusAPI(selectedYear),
            getLoanTypeAPI(selectedYear), getPaymentBehaviorAPI(selectedYear),
            getLoanDistributionAPI(selectedYear), getOverdueAnalysisAPI(selectedYear),
            getLoanApprovalRateAPI(selectedYear), getRepaymentProgressAPI(selectedYear),
          ]);
          if (mn.status==="fulfilled") setMonthly(mn.value);
          if (ls.status==="fulfilled") setLoanStat(ls.value);
          if (lt.status==="fulfilled") setLoanType(lt.value);
          if (pb.status==="fulfilled") setPayBehav(pb.value);
          if (ld.status==="fulfilled") setLoanDist(ld.value);
          if (od.status==="fulfilled") setOverdue(od.value);
          if (ar.status==="fulfilled") setApprovalRate(ar.value);
          if (rp.status==="fulfilled") setRepayment(rp.value);
        } else if (activeTab === "classification") {
          const [cls, tb, ft] = await Promise.allSettled([
            getClassificationAPI(selectedYear), getTopBorrowersAPI(selectedYear),
            getFirstTimeBorrowersAPI(selectedYear),
          ]);
          if (cls.status==="fulfilled") setClass(cls.value);
          if (tb.status==="fulfilled")  setTopBorrowers(tb.value);
          if (ft.status==="fulfilled")  setFirstTimers(ft.value);
        } else if (activeTab === "performance") {
          const [mp, sc, dq, ra] = await Promise.allSettled([
            getMemberPerformanceAPI(selectedYear), getShareCapitalAPI(selectedYear),
            getDelinquencyAPI(delinqMonths), getRiskAssessmentAPI(),
          ]);
          if (mp.status==="fulfilled") setMemberPerf(mp.value);
          if (sc.status==="fulfilled") setShareCapital(sc.value);
          if (dq.status==="fulfilled") setDelinquency(dq.value);
          if (ra.status==="fulfilled") setRiskData(ra.value);
        } else if (activeTab === "audit") {
          const al = await getAuditLogAPI(selectedYear).catch(() => []);
          setAuditLog(al);
        }
        // ── FIX: dating may 8 pang "else if" branches dito (repayment,
        // delinquency, efficiency, growth, approval, maturities,
        // firsttimers, risk) — pero DEAD CODE ang mga ito, dahil ang
        // "activeTab" ay HINDI KAILANMAN puwedeng maging alinman sa mga
        // values na 'to (isa lang ang setTab() call sa buong file, at 6
        // lang ang tab keys doon: overview/charts/classification/
        // performance/generate/audit). Tinanggal na ang mga hindi
        // maaabot na branch na 'to — ang datos na sana kukunin nila ay
        // kinukuha na rin naman sa "overview"/"charts"/"classification"/
        // "performance" branches sa itaas, para sa mga naka-embed nang
        // bersyon ng parehong reports doon. ─────────────────────────────
        setFetchedTabs(p => ({ ...p, [key]: true }));
      } catch(e) { console.error(e); }
      finally { setLoading(false); }
    };
    load();
  }, [activeTab, selectedYear]);

  // ── Chart data ──────────────────────────────────────────────────────────────
  const monthlyBarData = {
    labels: monthly.map(m => m.month),
    datasets: [{ label:"Collection", data:monthly.map(m=>m.total), backgroundColor:"#2e7d32", borderRadius:6, hoverBackgroundColor:"#1b5e20" }],
  };
  // ── FIX: dating kulang ang fallback (5 lang, walang "Approved" at
  // "Cancelled" na estado na naidagdag na natin dati sa loans/models.py
  // STATUS_CHOICES — 7 estado na dapat ngayon). Ang fallback na 'to ay
  // makikita lang kapag walang totoong datos pa mula sa backend (zero-
  // state placeholder), pero dapat pa ring tama ang laman nito. ────────
  const loanStatData = {
    labels: Object.keys(loanStat).length ? Object.keys(loanStat) : ["For Review","Approved","Active","Declined","Completed","Overdue","Cancelled"],
    datasets: [{ data: Object.keys(loanStat).length ? Object.values(loanStat) : [0,0,0,0,0,0,0], backgroundColor:["#f57c00","#ffb300","#2e7d32","#e53935","#1565c0","#c62828","#9e9e9e"], borderRadius:6 }],
  };
  // ── FIX: dating "Regular","Emergency","Salary","Housing","Business"
  // ang fallback — LUMANG 5 loan types na 'to, na napalitan na natin ng
  // 4 bagong types (Regular Loan, Petty Cash Loan, Appliance Loan, ATM
  // Loan) sa buong system. Makikita lang ito kapag walang totoong
  // datos pa (zero-state), pero dapat pa ring tumutugma sa aktwal na
  // mga loan type na ginagamit ngayon. ─────────────────────────────────
  const loanTypeData = {
    labels: Object.keys(loanType).length ? Object.keys(loanType) : ["Regular Loan","Petty Cash Loan","Appliance Loan","ATM Loan"],
    datasets: [{ data: Object.keys(loanType).length ? Object.values(loanType) : [0,0,0,0], backgroundColor:COLORS, borderWidth:0 }],
  };
  const payBehavData = {
    labels: ["On Time","Late","Overdue"],
    datasets: [{ data:[payBehav["On Time"]||0, payBehav["Late"]||0, payBehav["Overdue"]||0], backgroundColor:["#2e7d32","#f57c00","#c62828"], borderWidth:0 }],
  };
  const loanDistData = {
    labels: loanDist.map(l=>l.range),
    datasets: [{ label:"No. of Loans", data:loanDist.map(l=>l.count), backgroundColor:COLORS, borderRadius:6 }],
  };
  const overdueData = {
    labels: overdue.map(o=>o.classification),
    datasets: [{ label:"Overdue", data:overdue.map(o=>o.overdue_count), backgroundColor:"#c62828", borderRadius:6 }],
  };
  const yearlyLineData = {
    labels: yearlyComp.map(y=>y.year),
    datasets: [
      { label:"Collections (₱)",     data:yearlyComp.map(y=>y.collections),  borderColor:"#2e7d32", backgroundColor:"rgba(46,125,50,0.1)",   fill:true, tension:0.4 },
      { label:"Loan Releases (₱)",   data:yearlyComp.map(y=>y.loan_amount),  borderColor:"#1565c0", backgroundColor:"rgba(21,101,192,0.08)", fill:true, tension:0.4 },
      { label:"Savings Deposits (₱)",data:yearlyComp.map(y=>y.savings_dep||0),borderColor:"#f57c00",backgroundColor:"rgba(245,124,0,0.08)", fill:true, tension:0.4 },
    ],
  };
  const monthlyLoansData = {
    labels: monthlyLoans.map(m=>m.month),
    datasets: [{ label:"Loan Applications", data:monthlyLoans.map(m=>m.count), borderColor:"#1565c0", backgroundColor:"rgba(21,101,192,0.08)", fill:true, tension:0.4, pointBackgroundColor:"#1565c0" }],
  };

  // ── KPI cards (financial only — no duplicates from Dashboard) ──────────────
  const KPI_CARDS = [
    { icon:<Wallet size={22} color="#2e7d32"/>,      bg:"#e8f5e9", val:`₱${Number(overview.total_collection||0).toLocaleString()}`,     label:"Total Collection (YTD)",  color:"green"  },
    { icon:<ArrowUpRight size={22} color="#1565c0"/>, bg:"#e3f2fd", val:`₱${Number(overview.total_releases||0).toLocaleString()}`,        label:"Total Loan Releases",     color:"blue"   },
    { icon:<PiggyBank size={22} color="#e65100"/>,    bg:"#fff8e1", val:`₱${Number(overview.total_savings_balance||0).toLocaleString()}`, label:"Total Savings Balance",   color:"orange" },
    { icon:<Coins size={22} color="#6a1b9a"/>,        bg:"#f3e5f5", val:`₱${Number(overview.total_share_capital||0).toLocaleString()}`,   label:"Total Share Capital",     color:"purple" },
    { icon:<Percent size={22} color="#2e7d32"/>,      bg:"#e8f5e9", val:`${overview.collection_rate||0}%`,                                label:"Collection Rate",         color:"green"  },
    { icon:<BarChart2 size={22} color="#00796b"/>,    bg:"#e0f2f1", val:`₱${Number(overview.avg_loan_amount||0).toLocaleString()}`,       label:"Average Loan Amount",     color:"teal"   },
  ];

  const clsBarData = {
    labels: classification.map(c => c.classification),
    datasets: [
      { label:"On-Time Rate (%)", data:classification.map(c=>c.on_time_rate),   backgroundColor:"#2e7d32", borderRadius:5 },
      { label:"Late Rate (%)",    data:classification.map(c=>c.total_payments>0?Math.round((c.late_payments/c.total_payments)*100):0), backgroundColor:"#f57c00", borderRadius:5 },
    ],
  };
  const clsBarOpts = {
    responsive:true, maintainAspectRatio:false,
    plugins:{
      legend:{display:true,position:"top"},
      tooltip:{
        callbacks:{
          label:(ctx) => {
            const c = classification[ctx.dataIndex];
            if (!c || c.total_payments===0) return `${ctx.dataset.label}: No payments yet`;
            return ctx.dataset.label.includes("On-Time")
              ? [`On-Time: ${ctx.parsed.y}%`, `   ${c.on_time_payments} of ${c.total_payments} payments`]
              : [`Late: ${ctx.parsed.y}%`, `   ${c.late_payments} of ${c.total_payments} payments`];
          },
        },
        backgroundColor:"rgba(20,20,20,0.9)", titleFont:{size:12,weight:"bold"}, bodyFont:{size:11}, padding:10, cornerRadius:8,
      },
    },
    scales:{ x:{grid:{display:false}}, y:{grid:{color:"#f0f4f1"},ticks:{callback:v=>v+"%"},max:100} },
  };

  const lineOpts = {
    responsive:true, maintainAspectRatio:false,
    plugins:{ legend:{display:true,position:"top",labels:{boxWidth:10,font:{size:10}}} },
    scales:{ x:{grid:{display:false}}, y:{grid:{color:"#f0f4f1"},ticks:{callback:v=>"₱"+v.toLocaleString()}} },
  };

  return (
    <div className="rp-wrapper">
      {showPreview && <ReportPreviewModal type={reportType} dateFrom={dateFrom} dateTo={dateTo} onClose={()=>setPreview(false)}/>}

      {/* Header */}
      <div className="rp-page-header">
        <div>
          <div className="rp-page-title">Reports &amp; Analytics</div>
          <div className="rp-page-sub">Financial analytics, loan performance, member insights, and report generation.</div>
        </div>
        {/* ── FIX: dating limitado lang sa 6 taon (current year ±3) ang
            dropdown na 'to — hindi mapipili ang mga taon sa labas ng
            range na 'yon. Ngayon, may prev/next arrow para makapunta sa
            KAHIT ANONG taon, hindi na basta pinipili sa fixed na
            listahan. Nananatili pa rin ang "All Years" bilang toggle. ── */}
        <div className="rp-year-selector">
          <button
            className="rp-year-btn"
            onClick={() => setYear(selectedYear === "All" ? YEAR - 1 : selectedYear - 1)}
            title="Previous year"
          >‹</button>
          <div className="rp-year-display">
            {selectedYear === "All" ? "All Years" : selectedYear}
          </div>
          <button
            className="rp-year-btn"
            onClick={() => setYear(selectedYear === "All" ? YEAR + 1 : selectedYear + 1)}
            title="Next year"
          >›</button>
          <button
            className={`rp-year-all-btn ${selectedYear === "All" ? "active" : ""}`}
            onClick={() => setYear(selectedYear === "All" ? YEAR : "All")}
          >
            {selectedYear === "All" ? "Back to This Year" : "All Years"}
          </button>
        </div>
      </div>

      {/* Tabs */}
      <div className="rp-main-tabs">
        {[
          {key:"overview",       icon:<BarChart2 size={13}/>,  label:"Overview"},
          {key:"charts",         icon:<TrendingUp size={13}/>, label:"Charts"},
          {key:"classification", icon:<PieChart size={13}/>,   label:"Classification"},
          {key:"performance",    icon:<Users size={13}/>,      label:"Performance"},
          {key:"generate",       icon:<FileText size={13}/>,   label:"Generate Report"},
          {key:"audit",          icon:<Link2 size={13}/>,      label:"Audit Log"},
        ].map(t => (
          <button key={t.key} className={`rp-main-tab ${activeTab===t.key?"active":""}`} onClick={()=>setTab(t.key)}>
            {t.icon} {t.label}
          </button>
        ))}
      </div>

      {/* ══ OVERVIEW ══════════════════════════════════════════════════════════ */}
      {activeTab === "overview" && (
        <div style={{display:"flex",flexDirection:"column",gap:16}}>
          {loading ? <div className="rp-loading">Loading...</div> : (<>
            {/* KPI Cards */}
            <div className="rp-kpi-grid">
              {KPI_CARDS.map((c,i) => (
                <div key={i} className={`rp-kpi-card ${c.color}`}>
                  <div style={{fontSize:28}}>{c.icon}</div>
                  <div className="rp-kpi-val">{c.val}</div>
                  <div className="rp-kpi-label">{c.label}</div>
                </div>
              ))}
            </div>

            {/* Charts row */}
            <div style={{display:"grid",gridTemplateColumns:"1.6fr 1fr",gap:16}}>
              <div className="rp-chart-card">
                <div className="rp-chart-title">Monthly Collection Trend</div>
                <div className="rp-chart-sub">{selectedYear} — total payments collected per month</div>
                <div style={{height:220}}>
                  {!monthly.length ? <div className="rp-no-data">No data yet.</div> : <Bar data={monthlyBarData} options={chartOpts("₱")}/>}
                </div>
              </div>
              <div className="rp-chart-card">
                <div className="rp-chart-title">Monthly Loan Applications</div>
                <div className="rp-chart-sub">{selectedYear} — number of loans applied per month</div>
                <div style={{height:220}}>
                  {!monthlyLoans.length ? <div className="rp-no-data">No data yet.</div> : <Line data={monthlyLoansData} options={chartOpts()}/>}
                </div>
              </div>
            </div>

            {/* Year-over-year */}
            <div className="rp-chart-card">
              <div className="rp-chart-title">Year-over-Year Comparison</div>
              <div className="rp-chart-sub">Collections · Loan Releases · Savings Deposits — trend across years</div>
              <div style={{height:230}}>
                {!yearlyComp.length ? <div className="rp-no-data">No data yet.</div> : <Line data={yearlyLineData} options={lineOpts}/>}
              </div>
            </div>

            {/* Collection Efficiency */}
            <div className="rp-chart-card">
              <div className="rp-chart-title" style={{display:"flex",alignItems:"center",gap:6}}><TrendingUp size={14} color="#1b5e20"/> Collection Efficiency ({selectedYear})</div>
              <div className="rp-chart-sub">Actual collected vs expected monthly collection from active loans</div>
              {!efficiency.data?.length ? <div className="rp-no-data" style={{minHeight:80}}>No data yet.</div> : (
                <ProTable
                  columns={[
                    {label:"Month",       key:"month",          tdStyle:{fontWeight:600}},
                    {label:"Expected",    key:"expected",       render:r=>`₱${Number(r.expected).toLocaleString()}`,   tdStyle:{color:"#1565c0"}},
                    {label:"Collected",   key:"collected",      render:r=>`₱${Number(r.collected).toLocaleString()}`,  tdStyle:{fontWeight:700,color:"#2e7d32"}},
                    {label:"Efficiency",  key:"efficiency_pct", render:r=>(
                      <div style={{display:"flex",alignItems:"center",gap:8}}>
                        <div style={{flex:1,height:7,background:"#f0f0f0",borderRadius:4,overflow:"hidden",minWidth:60}}>
                          <div style={{width:`${Math.min(r.efficiency_pct,100)}%`,height:"100%",background:r.efficiency_pct>=90?"#2e7d32":r.efficiency_pct>=70?"#f57c00":"#c62828",borderRadius:4}}/>
                        </div>
                        <span style={{fontWeight:700,fontSize:12,color:r.efficiency_pct>=90?"#2e7d32":r.efficiency_pct>=70?"#f57c00":"#c62828",flexShrink:0}}>{r.efficiency_pct}%</span>
                      </div>
                    )},
                    {label:"Transactions",key:"tx_count",       tdStyle:{textAlign:"center"}},
                  ]}
                  rows={efficiency.data}
                  empty="No data yet."
                />
              )}
            </div>

            {/* Upcoming Maturities */}
            <div className="rp-chart-card">
              <div style={{display:"flex",alignItems:"center",justifyContent:"space-between",marginBottom:4,flexWrap:"wrap",gap:8}}>
                <div>
                  <div className="rp-chart-title" style={{display:"flex",alignItems:"center",gap:6}}><Calendar size={14} color="#1b5e20"/> Upcoming Loan Maturities</div>
                  <div className="rp-chart-sub">Loans completing within the next {maturMonths} month{maturMonths>1?"s":""} — {maturities.count||0} loans</div>
                </div>
                <div style={{display:"flex",gap:6}}>
                  {[1,2,3,6].map(m => (
                    <button key={m} onClick={()=>{setMaturMonths(m);setFetchedTabs(p=>({...p,overview:false}));}}
                      style={{padding:"4px 12px",borderRadius:20,border:`1.5px solid ${maturMonths===m?"#1565c0":"#e0e0e0"}`,background:maturMonths===m?"#e3f2fd":"#fff",color:maturMonths===m?"#1565c0":"#888",fontWeight:700,fontSize:11,cursor:"pointer"}}>
                      {m}mo
                    </button>
                  ))}
                </div>
              </div>
              <ProTable
                columns={[
                  {label:"Loan ID",    key:"loan_id",     tdStyle:{fontFamily:"monospace",fontSize:11}},
                  {label:"Member",     key:"member_name", tdStyle:{fontWeight:600}},
                  {label:"Type",       key:"loan_type"},
                  {label:"Balance",    key:"balance",     render:r=>`₱${Number(r.balance).toLocaleString()}`, tdStyle:{fontWeight:700,color:"#c62828"}},
                  {label:"Maturity",   key:"maturity",    tdStyle:{fontWeight:600,color:"#1565c0"}},
                  {label:"Days Left",  key:"days_left",   render:r=><span style={{fontWeight:700,color:r.days_left<=30?"#c62828":r.days_left<=60?"#f57c00":"#2e7d32"}}>{r.days_left}d</span>},
                ]}
                rows={maturities.data||[]}
                empty="No upcoming maturities."
              />
            </div>

            {/* Member Growth */}
            <div className="rp-chart-card">
              <div className="rp-chart-title" style={{display:"flex",alignItems:"center",gap:6}}><Users size={14} color="#1b5e20"/> Member Growth Timeline ({selectedYear})</div>
              <div className="rp-chart-sub">New registrations per month · Total members: {memberGrowth.total_members||0}</div>
              {memberGrowth.data?.length > 0 ? (
                <div style={{height:200}}>
                  <Line
                    data={{
                      labels: memberGrowth.data.map(m=>m.month),
                      datasets: [
                        {label:"New Members",     data:memberGrowth.data.map(m=>m.new),        borderColor:"#4caf50", backgroundColor:"rgba(76,175,80,0.1)",  fill:true, tension:0.4, pointBackgroundColor:"#4caf50"},
                        {label:"Cumulative Total",data:memberGrowth.data.map(m=>m.cumulative), borderColor:"#1565c0", backgroundColor:"rgba(21,101,192,0.05)",fill:false,tension:0.4, pointBackgroundColor:"#1565c0"},
                      ],
                    }}
                    options={{responsive:true,maintainAspectRatio:false,plugins:{legend:{display:true,position:"top",labels:{boxWidth:10,font:{size:10}}}},scales:{x:{grid:{display:false}},y:{grid:{color:"#f0f4f1"},ticks:{font:{size:10}}}}}}
                  />
                </div>
              ) : <div className="rp-no-data" style={{minHeight:80}}>No registration data yet.</div>}
            </div>
          </>)}
        </div>
      )}

      {/* ══ CHARTS ════════════════════════════════════════════════════════════ */}
      {activeTab === "charts" && (
        <div style={{display:"grid",gridTemplateColumns:"repeat(2,1fr)",gap:16}}>
          <div className="rp-chart-card" style={{gridColumn:"1/-1"}}>
            <div className="rp-chart-title">Monthly Collection ({selectedYear})</div>
            <div className="rp-chart-sub">Total amount collected from loan payments each month</div>
            <div style={{height:240}}>
              {!monthly.length ? <div className="rp-no-data">No data.</div> : <Bar data={monthlyBarData} options={chartOpts("₱")}/>}
            </div>
          </div>
          <div className="rp-chart-card">
            <div className="rp-chart-title">Loan Type Breakdown</div>
            <div className="rp-chart-sub">Distribution of loans by type</div>
            <div style={{height:220}}><Doughnut data={loanTypeData} options={donutOpts}/></div>
          </div>
          <div className="rp-chart-card">
            <div className="rp-chart-title">Payment Behavior</div>
            <div className="rp-chart-sub">On-time vs late vs overdue payments</div>
            <div style={{height:220}}><Doughnut data={payBehavData} options={donutOpts}/></div>
          </div>
          <div className="rp-chart-card">
            <div className="rp-chart-title">Loan Amount Distribution</div>
            <div className="rp-chart-sub">Number of loans per amount range</div>
            <div style={{height:220}}>
              {!loanDist.length ? <div className="rp-no-data">No data.</div> : <Bar data={loanDistData} options={chartOpts()}/>}
            </div>
          </div>
          <div className="rp-chart-card">
            <div className="rp-chart-title">Overdue Loans by Classification</div>
            <div className="rp-chart-sub">Which member type has the most overdue loans</div>
            <div style={{height:220}}>
              {!overdue.length ? <div className="rp-no-data">No overdue loans.</div> : <Bar data={overdueData} options={chartOpts()}/>}
            </div>
          </div>

          {/* Approval Rate */}
          <div className="rp-chart-card" style={{gridColumn:"1/-1"}}>
            <div className="rp-chart-title" style={{display:"flex",alignItems:"center",gap:6}}><CheckCircle size={14} color="#1b5e20"/> Loan Approval Rate by Type ({selectedYear})</div>
            <div className="rp-chart-sub">Approved vs declined applications per loan type</div>
            <div style={{display:"grid",gridTemplateColumns:"repeat(4,1fr)",gap:10,marginBottom:12}}>
              {[
                {label:"Total",        val:approvalRate.total||0,          color:"#1565c0"},
                {label:"Approved",     val:approvalRate.approved||0,       color:"#2e7d32"},
                {label:"Declined",     val:approvalRate.declined||0,       color:"#c62828"},
                {label:"Approval Rate",val:`${approvalRate.approval_rate||0}%`, color:"#6a1b9a"},
              ].map((c,i) => (
                <div key={i} style={{background:"#f9fef9",borderRadius:10,padding:"12px 14px",border:"1px solid #e4f0e5",textAlign:"center"}}>
                  <div style={{fontSize:18,fontWeight:800,color:c.color}}>{c.val}</div>
                  <div style={{fontSize:10,color:"#888",fontWeight:600,marginTop:2,textTransform:"uppercase"}}>{c.label}</div>
                </div>
              ))}
            </div>
            <ProTable
              columns={[
                {label:"Loan Type",     key:"loan_type",  tdStyle:{fontWeight:600}},
                {label:"Total",         key:"total",      tdStyle:{textAlign:"center"}},
                {label:"Approved",      key:"approved",   tdStyle:{textAlign:"center",color:"#2e7d32",fontWeight:700}},
                {label:"Declined",      key:"declined",   tdStyle:{textAlign:"center",color:"#c62828"}},
                {label:"Approval Rate", key:"rate",       render:r=>(
                  <div style={{display:"flex",alignItems:"center",gap:8}}>
                    <div style={{flex:1,height:7,background:"#f0f0f0",borderRadius:4,overflow:"hidden",minWidth:60}}>
                      <div style={{width:`${r.rate}%`,height:"100%",background:r.rate>=80?"#2e7d32":r.rate>=60?"#f57c00":"#c62828",borderRadius:4}}/>
                    </div>
                    <span style={{fontWeight:700,fontSize:12,color:r.rate>=80?"#2e7d32":r.rate>=60?"#f57c00":"#c62828",flexShrink:0}}>{r.rate}%</span>
                  </div>
                )},
              ]}
              rows={approvalRate.by_type||[]}
              empty="No loan data yet."
            />
          </div>

          {/* Repayment Progress */}
          <div className="rp-chart-card" style={{gridColumn:"1/-1"}}>
            <div className="rp-chart-title" style={{display:"flex",alignItems:"center",gap:6}}><BarChart2 size={14} color="#1b5e20"/> Loan Repayment Progress</div>
            <div className="rp-chart-sub">Active and overdue loans — how much has been paid vs remaining</div>
            <ProTable
              columns={[
                {label:"Loan ID",   key:"loan_id",    tdStyle:{fontFamily:"monospace",fontSize:11}},
                {label:"Member",    key:"member_name",tdStyle:{fontWeight:600}},
                {label:"Type",      key:"loan_type"},
                {label:"Principal", key:"principal",  render:r=>`₱${Number(r.principal).toLocaleString()}`},
                {label:"Paid",      key:"paid",       render:r=>`₱${Number(r.paid).toLocaleString()}`,      tdStyle:{color:"#2e7d32",fontWeight:700}},
                {label:"Balance",   key:"balance",    render:r=>`₱${Number(r.balance).toLocaleString()}`,   tdStyle:{color:"#c62828",fontWeight:700}},
                {label:"Progress",  key:"pct_paid",   render:r=>(
                  <div style={{display:"flex",alignItems:"center",gap:8,minWidth:120}}>
                    <div style={{flex:1,height:8,background:"#f0f0f0",borderRadius:4,overflow:"hidden"}}>
                      <div style={{width:`${r.pct_paid}%`,height:"100%",background:r.pct_paid>=80?"#2e7d32":r.pct_paid>=50?"#f57c00":"#c62828",borderRadius:4}}/>
                    </div>
                    <span style={{fontSize:11,fontWeight:700,flexShrink:0,color:"#555"}}>{r.pct_paid}%</span>
                  </div>
                )},
                {label:"Status",    key:"status",     render:r=><span style={{background:r.status==="Active"?"#e8f5e9":"#ffebee",color:r.status==="Active"?"#2e7d32":"#c62828",borderRadius:20,padding:"2px 8px",fontSize:11,fontWeight:700}}>{r.status}</span>},
              ]}
              rows={repayment}
              empty="No active loans."
            />
          </div>
        </div>
      )}

      {/* ══ CLASSIFICATION ════════════════════════════════════════════════════ */}
      {activeTab === "classification" && (
        <div style={{display:"flex",flexDirection:"column",gap:16}}>
          {/* Payment performance chart */}
          <div className="rp-chart-card">
            <div className="rp-chart-title">Payment Performance by Classification ({selectedYear})</div>
            <div className="rp-chart-sub">Student vs Senior vs Employed — on-time vs late payment rates</div>
            <div style={{height:260}}>
              {classification.every(c=>c.total_payments===0)
                ? <div className="rp-no-data">No payment records for {selectedYear}.</div>
                : <Bar data={clsBarData} options={clsBarOpts}/>
              }
            </div>
          </div>

          {/* Classification cards */}
          <div style={{display:"grid",gridTemplateColumns:"repeat(3,1fr)",gap:16}}>
            {classification.map((c,i) => (
              <div key={i} className="rp-cls-card">
                <div className="rp-cls-icon">
                  {c.classification==="Student"
                    ? <BookOpen size={32} color="#1565c0"/>
                    : c.classification==="Senior"
                    ? <Award size={32} color="#e65100"/>
                    : <Layers size={32} color="#2e7d32"/>}
                </div>
                <div className="rp-cls-name">{c.classification}</div>
                <div className="rp-cls-stats">
                  {[
                    ["Members",         c.member_count],
                    ["Total Loans",     c.total_loans],
                    ["Active Loans",    c.active_loans],
                    ["Overdue Loans",   <span style={{color:"#c62828",fontWeight:700}}>{c.overdue_loans}</span>],
                    ["On-Time Rate",    <span style={{color:c.on_time_rate>=80?"#1b5e20":"#f57c00",fontWeight:700}}>{c.on_time_rate}%</span>],
                    ["Avg Loan",        `₱${Number(c.avg_loan_amount).toLocaleString()}`],
                    ["Total Collected", `₱${Number(c.total_collected).toLocaleString()}`],
                    ["Total Savings",   `₱${Number(c.total_savings||0).toLocaleString()}`],
                  ].map(([label,val],j) => (
                    <div key={j} className="rp-cls-row">
                      <span>{label}</span><strong>{val}</strong>
                    </div>
                  ))}
                </div>
              </div>
            ))}
          </div>

          {/* Top Borrowers */}
          <div className="rp-chart-card">
            <div className="rp-chart-title">Top Borrowers ({selectedYear})</div>
            <div className="rp-chart-sub">Members with the most loan applications</div>
            <ProTable
              columns={[
                {label:"#",          key:"_rank",       style:{width:40},  tdStyle:{textAlign:"center",fontWeight:700,color:"#2e7d32"}, render:(_,i)=>i+1},
                {label:"Member ID",  key:"member_id",   tdStyle:{fontFamily:"monospace",fontSize:11,color:"#555"}},
                {label:"Name",       key:"name",        tdStyle:{fontWeight:600}},
                {label:"Type",       key:"classification"},
                {label:"Loans",      key:"loan_count",  tdStyle:{textAlign:"center",fontWeight:700,color:"#1565c0"}},
                {label:"Total Amount",key:"total_amount",render:r=>`₱${Number(r.total_amount).toLocaleString()}`,tdStyle:{fontWeight:700,color:"#2e7d32"}},
                {label:"Share Capital",key:"share_capital",render:r=>`₱${Number(r.share_capital).toLocaleString()}`},
                {label:"Savings",    key:"savings_balance",render:r=>`₱${Number(r.savings_balance||0).toLocaleString()}`,tdStyle:{color:"#e65100"}},
              ]}
              rows={topBorrowers.data || []}
              empty="No borrowers yet."
            />
          </div>

          {/* First-time Borrowers */}
          <div className="rp-chart-card">
            <div style={{display:"flex",alignItems:"center",justifyContent:"space-between",marginBottom:4}}>
              <div>
                <div className="rp-chart-title" style={{display:"flex",alignItems:"center",gap:6}}><UserPlus size={14} color="#1b5e20"/> First-time Borrowers ({selectedYear})</div>
                <div className="rp-chart-sub">Members applying for their very first loan · {firstTimers.count||0} found</div>
              </div>
            </div>
            <ProTable
              columns={[
                {label:"#",          tdStyle:{textAlign:"center",width:36,fontWeight:700,color:"#2e7d32"}, render:(_,i)=>i+1},
                {label:"Member ID",  key:"member_id",    tdStyle:{fontFamily:"monospace",fontSize:11,color:"#888"}},
                {label:"Member",     key:"member_name",  tdStyle:{fontWeight:600}},
                {label:"Type",       key:"classification"},
                {label:"Loan Type",  key:"loan_type"},
                {label:"Amount",     key:"amount",       render:r=>`₱${Number(r.amount).toLocaleString()}`, tdStyle:{fontWeight:700,color:"#2e7d32"}},
                {label:"Status",     key:"status",       render:r=><span style={{background:r.status==="Active"?"#e8f5e9":r.status==="Declined"?"#ffebee":"#fff8e1",color:r.status==="Active"?"#2e7d32":r.status==="Declined"?"#c62828":"#f57c00",borderRadius:20,padding:"2px 8px",fontSize:11,fontWeight:700}}>{r.status}</span>},
                {label:"Date",       key:"applied_at",   tdStyle:{color:"#888",fontSize:11}},
              ]}
              rows={firstTimers.data||[]}
              empty={`No first-time borrowers for ${selectedYear}.`}
            />
          </div>
        </div>
      )}

      {/* ══ PERFORMANCE ═══════════════════════════════════════════════════════ */}
      {activeTab === "performance" && (
        <div style={{display:"flex",flexDirection:"column",gap:16}}>
          {/* Rating summary */}
          <div style={{display:"grid",gridTemplateColumns:"repeat(4,1fr)",gap:12}}>
            {[
              {r:"Excellent", icon:<Trophy size={22}/>,      bg:"#e8f5e9", c:"#1b5e20"},
              {r:"Good",      icon:<CheckCircle size={22}/>, bg:"#f1f8e9", c:"#2e7d32"},
              {r:"Fair",      icon:<Clock size={22}/>,       bg:"#fff8e1", c:"#f57c00"},
              {r:"Poor",      icon:<XCircle size={22}/>,     bg:"#ffebee", c:"#c62828"},
            ].map(({r,icon,bg,c}) => {
              const count = memberPerf.filter(m=>m.rating===r).length;
              return (
                <div key={r} style={{background:bg,border:`1px solid ${c}22`,borderRadius:12,padding:"16px 12px",textAlign:"center"}}>
                  <div style={{color:c,marginBottom:6,display:"flex",justifyContent:"center"}}>{icon}</div>
                  <div style={{fontSize:24,fontWeight:800,color:c}}>{count}</div>
                  <div style={{fontSize:11,color:c,fontWeight:600,marginTop:2}}>{r} Performers</div>
                </div>
              );
            })}
          </div>

          {/* Member performance table */}
          <div className="rp-chart-card">
            <div className="rp-chart-title">Member Payment Performance ({selectedYear})</div>
            <div className="rp-chart-sub">Ranked by on-time payment rate — Excellent ≥90% · Good ≥70% · Fair ≥50% · Poor &lt;50%</div>
            <ProTable
              columns={[
                {label:"#",          tdStyle:{textAlign:"center",fontWeight:700,color:"#2e7d32",width:40},  render:(_,i)=>i+1},
                {label:"Member ID",  key:"member_id",   tdStyle:{fontFamily:"monospace",fontSize:11,color:"#555"}},
                {label:"Name",       key:"name",        tdStyle:{fontWeight:600}},
                {label:"Type",       key:"classification"},
                {label:"Payments",   key:"total_payments", tdStyle:{textAlign:"center"}},
                {label:"On Time",    key:"on_time",     tdStyle:{textAlign:"center",color:"#1b5e20",fontWeight:600}},
                {label:"Late",       key:"late",        tdStyle:{textAlign:"center",color:"#f57c00"}},
                {label:"Overdue",    key:"overdue_loans",tdStyle:{textAlign:"center",color:"#c62828"}},
                {label:"Rate",       key:"on_time_rate", render:r=><span style={{fontWeight:700,color:r.on_time_rate>=80?"#1b5e20":"#f57c00"}}>{r.on_time_rate}%</span>},
                {label:"Total Paid", key:"total_paid",  render:r=>`₱${Number(r.total_paid).toLocaleString()}`, tdStyle:{fontWeight:700,color:"#2e7d32"}},
                {label:"Rating",     key:"rating",      render:r=><RatingBadge rating={r.rating}/>},
              ]}
              rows={memberPerf}
              empty="No payment data for this year."
            />
          </div>

          {/* Share Capital table */}
          <div className="rp-chart-card">
            <div className="rp-chart-title">Share Capital — Top 20 Members</div>
            <div className="rp-chart-sub">Members with highest share capital</div>
            <ProTable
              columns={[
                {label:"#",            tdStyle:{textAlign:"center",fontWeight:700,color:"#2e7d32",width:40}, render:(_,i)=>i+1},
                {label:"Member ID",    key:"member_id",   tdStyle:{fontFamily:"monospace",fontSize:11,color:"#555"}},
                {label:"Name",         key:"name",        tdStyle:{fontWeight:600}},
                {label:"Type",         key:"classification"},
                {label:"Loans",        key:"loan_count",  tdStyle:{textAlign:"center"}},
                {label:"Total Loaned", key:"total_loaned",render:r=>`₱${Number(r.total_loaned).toLocaleString()}`},
                {label:"Share Capital",key:"share_capital",render:r=>`₱${Number(r.share_capital).toLocaleString()}`,tdStyle:{fontWeight:700,color:"#1b5e20"}},
                {label:"Max Loanable", key:"max_loanable", render:r=>`₱${Number(r.max_loanable).toLocaleString()}`,tdStyle:{fontWeight:700,color:"#1565c0"}},
                {label:"Savings",      key:"savings_balance",render:r=>`₱${Number(r.savings_balance||0).toLocaleString()}`,tdStyle:{color:"#e65100"}},
              ]}
              rows={shareCapital}
              empty="No share capital data yet."
            />
          </div>

          {/* Delinquency Report */}
          <div className="rp-chart-card">
            <div style={{display:"flex",alignItems:"center",justifyContent:"space-between",marginBottom:4,flexWrap:"wrap",gap:8}}>
              <div>
                <div className="rp-chart-title" style={{display:"flex",alignItems:"center",gap:6}}><AlertTriangle size={14} color="#1b5e20"/> Delinquency Report</div>
                <div className="rp-chart-sub">Members with no payment in the past {delinqMonths} month{delinqMonths>1?"s":""} · {delinquency.count||0} found</div>
              </div>
              <div style={{display:"flex",gap:6}}>
                {[1,2,3,6].map(m => (
                  <button key={m} onClick={()=>{setDelinqMonths(m);setFetchedTabs(p=>({...p,performance:false}));}}
                    style={{padding:"4px 12px",borderRadius:20,border:`1.5px solid ${delinqMonths===m?"#c62828":"#e0e0e0"}`,background:delinqMonths===m?"#ffebee":"#fff",color:delinqMonths===m?"#c62828":"#888",fontWeight:700,fontSize:11,cursor:"pointer"}}>
                    {m}mo
                  </button>
                ))}
              </div>
            </div>
            <ProTable
              columns={[
                {label:"Loan ID",     key:"loan_id",     tdStyle:{fontFamily:"monospace",fontSize:11}},
                {label:"Member",      key:"member_name", tdStyle:{fontWeight:600}},
                {label:"Member ID",   key:"member_id",   tdStyle:{fontFamily:"monospace",fontSize:11,color:"#888"}},
                {label:"Type",        key:"loan_type"},
                {label:"Balance",     key:"balance",     render:r=>`₱${Number(r.balance).toLocaleString()}`, tdStyle:{color:"#c62828",fontWeight:700}},
                {label:"Monthly Due", key:"monthly_due", render:r=>`₱${Number(r.monthly_due).toLocaleString()}`},
                {label:"Last Payment",key:"last_payment",tdStyle:{color:"#f57c00",fontSize:11}},
                {label:"Days Since",  key:"days_since",  render:r=><span style={{fontWeight:700,color:r.days_since>90?"#c62828":r.days_since>60?"#f57c00":"#555"}}>{r.days_since}d</span>},
                {label:"Status",      key:"status",      render:r=><span style={{background:r.status==="Overdue"?"#ffebee":"#fff8e1",color:r.status==="Overdue"?"#c62828":"#f57c00",borderRadius:20,padding:"2px 8px",fontSize:11,fontWeight:700}}>{r.status}</span>},
              ]}
              rows={delinquency.data||[]}
              empty="No delinquent members found."
            />
          </div>

          {/* Risk Assessment */}
          <div className="rp-chart-card">
            <div className="rp-chart-title" style={{display:"flex",alignItems:"center",gap:6}}><Shield size={14} color="#1b5e20"/> Risk Assessment</div>
            <div className="rp-chart-sub">Members at risk of default — based on overdue status, days since last payment, and outstanding balance</div>
            <div style={{display:"grid",gridTemplateColumns:"repeat(3,1fr)",gap:10,marginBottom:12}}>
              {[
                {label:"Critical Risk",val:riskData.summary?.critical||0,bg:"#ffebee",c:"#c62828",icon:<AlertTriangle size={20}/>},
                {label:"High Risk",    val:riskData.summary?.high||0,    bg:"#fff3e0",c:"#e65100",icon:<Shield size={20}/>},
                {label:"Medium Risk",  val:riskData.summary?.medium||0,  bg:"#fff8e1",c:"#f57c00",icon:<Activity size={20}/>},
              ].map((s,i) => (
                <div key={i} style={{background:s.bg,border:`1px solid ${s.c}33`,borderRadius:10,padding:"12px",textAlign:"center"}}>
                  <div style={{color:s.c,display:"flex",justifyContent:"center",marginBottom:4}}>{s.icon}</div>
                  <div style={{fontSize:22,fontWeight:800,color:s.c,marginTop:4}}>{s.val}</div>
                  <div style={{fontSize:10,color:s.c,fontWeight:700,textTransform:"uppercase",marginTop:2}}>{s.label}</div>
                </div>
              ))}
            </div>
            <ProTable
              columns={[
                {label:"Loan ID",     key:"loan_id",     tdStyle:{fontFamily:"monospace",fontSize:11}},
                {label:"Member",      key:"member_name", tdStyle:{fontWeight:600}},
                {label:"Type",        key:"loan_type"},
                {label:"Balance",     key:"balance",     render:r=>`₱${Number(r.balance).toLocaleString()}`, tdStyle:{fontWeight:700,color:"#c62828"}},
                {label:"Last Payment",key:"last_payment",tdStyle:{color:"#888",fontSize:11}},
                {label:"Days Since",  key:"days_since",  render:r=><span style={{fontWeight:700,color:r.days_since>90?"#c62828":r.days_since>60?"#f57c00":"#555"}}>{r.days_since}d</span>},
                {label:"Risk Flags",  key:"risk_flags",  render:r=>r.risk_flags?.join(" · "),tdStyle:{fontSize:11,color:"#888"}},
                {label:"Risk Level",  key:"risk_level",  render:r=>{
                  const s={Critical:{bg:"#ffebee",c:"#c62828"},High:{bg:"#fff3e0",c:"#e65100"},Medium:{bg:"#fff8e1",c:"#f57c00"}};
                  const st=s[r.risk_level]||{bg:"#eee",c:"#555"};
                  return <span style={{background:st.bg,color:st.c,border:`1px solid ${st.c}33`,borderRadius:20,padding:"2px 10px",fontSize:11,fontWeight:700}}>{r.risk_level}</span>;
                }},
              ]}
              rows={riskData.data||[]}
              empty="No at-risk loans detected."
            />
          </div>
        </div>
      )}

      {/* ══ GENERATE REPORT ═══════════════════════════════════════════════════ */}
      {activeTab === "generate" && (
        <div style={{display:"flex",flexDirection:"column",gap:16}}>
          {/* Header */}
          <div className="rp-chart-card">
            <div style={{fontSize:18,fontWeight:800,color:"#1b5e20",marginBottom:4,display:"flex",alignItems:"center",gap:8}}><FileText size={19}/> Generate Report</div>
            <div style={{fontSize:12,color:"#888"}}>Select a report type and date range, then preview or export as Excel/PDF.</div>
          </div>

          {/* Main generate form */}
          <div style={{display:"grid",gridTemplateColumns:"1fr 1fr",gap:16}}>

            {/* Left: Report Type */}
            <div className="rp-chart-card">
              <div className="rp-chart-title" style={{marginBottom:12}}>Report Type</div>
              <div style={{display:"flex",flexDirection:"column",gap:8}}>
                {REPORT_TYPES.map(t => (
                  <button key={t} onClick={()=>setReport(t)} style={{
                    display:"flex",alignItems:"center",gap:10,
                    padding:"12px 16px",borderRadius:10,cursor:"pointer",
                    border:`1.5px solid ${reportType===t?"#2e7d32":"#e4f0e5"}`,
                    background:reportType===t?"#e8f5e9":"#fafafa",
                    color:reportType===t?"#1b5e20":"#555",
                    fontWeight:reportType===t?700:500,
                    fontSize:13,fontFamily:"inherit",
                    textAlign:"left",transition:"all 0.15s",
                  }}>
                    <span style={{fontSize:16}}>
                      {t==="Financial Summary"    ? <Wallet size={16} color="#2e7d32"/> :
                     t==="Collection Report"    ? <TrendingUp size={16} color="#1565c0"/> :
                     t==="Loan Summary"         ? <ClipboardList size={16} color="#e65100"/> :
                     t==="Member Report"        ? <Users size={16} color="#00796b"/> :
                     t==="Payment Behavior"     ? <CreditCard size={16} color="#6a1b9a"/> :
                     t==="Blockchain Audit Log" ? <Link size={16} color="#c62828"/> :
                     t==="Member Performance Report" ? <Trophy size={16} color="#f57c00"/> :
                     t==="Classification Analytics"  ? <BarChart size={16} color="#2e7d32"/> :
                     <Database size={16} color="#555"/>}
                    </span>
                    {t}
                    {reportType===t && <span style={{marginLeft:"auto",display:"flex"}}><Check size={16} color="#2e7d32"/></span>}
                  </button>
                ))}
              </div>
            </div>

            {/* Right: Date range + actions */}
            <div style={{display:"flex",flexDirection:"column",gap:16}}>

              {/* Date range */}
              <div className="rp-chart-card">
                <div className="rp-chart-title" style={{marginBottom:14}}>Date Range</div>

                {/* Quick range buttons */}
                <div style={{display:"flex",gap:6,flexWrap:"wrap",marginBottom:14}}>
                  {[
                    {label:"This Year",  from:`${new Date().getFullYear()}-01-01`, to:`${new Date().getFullYear()}-12-31`},
                    {label:"Last Year",  from:`${new Date().getFullYear()-1}-01-01`, to:`${new Date().getFullYear()-1}-12-31`},
                    {label:"This Month", from:`${new Date().getFullYear()}-${String(new Date().getMonth()+1).padStart(2,"0")}-01`, to:new Date().toISOString().slice(0,10)},
                    {label:"All Time",   from:"2020-01-01", to:new Date().toISOString().slice(0,10)},
                  ].map(r => (
                    <button key={r.label} onClick={()=>{setDateFrom(r.from);setDateTo(r.to);}} style={{
                      padding:"5px 12px",borderRadius:20,cursor:"pointer",fontSize:11,fontWeight:600,
                      border:`1px solid ${dateFrom===r.from&&dateTo===r.to?"#2e7d32":"#e0e0e0"}`,
                      background:dateFrom===r.from&&dateTo===r.to?"#e8f5e9":"#fff",
                      color:dateFrom===r.from&&dateTo===r.to?"#2e7d32":"#888",
                      fontFamily:"inherit",transition:"all 0.15s",
                    }}>{r.label}</button>
                  ))}
                </div>

                <div style={{display:"flex",flexDirection:"column",gap:12}}>
                  <div>
                    <div className="rp-gen-label" style={{marginBottom:6}}>From</div>
                    <input className="rp-gen-input" style={{width:"100%",boxSizing:"border-box",fontSize:14,padding:"11px 14px"}}
                      type="date" value={dateFrom} onChange={e=>setDateFrom(e.target.value)}/>
                  </div>
                  <div>
                    <div className="rp-gen-label" style={{marginBottom:6}}>To</div>
                    <input className="rp-gen-input" style={{width:"100%",boxSizing:"border-box",fontSize:14,padding:"11px 14px"}}
                      type="date" value={dateTo} onChange={e=>setDateTo(e.target.value)}/>
                  </div>
                </div>
              </div>

              {/* Selected report info */}
              <div className="rp-chart-card" style={{background:reportType?"#f1f8e9":"#fafafa",border:`1.5px solid ${reportType?"#c8e6c9":"#e0e0e0"}`}}>
                {reportType ? (<>
                  <div
                    style={{
                      display: "flex",
                      alignItems: "center",
                      gap: 6,
                      fontSize: 13,
                      fontWeight: 700,
                      color: "#1b5e20",
                      marginBottom: 6,
                    }}
                  >
                    <CheckCircle size={14} color="#1b5e20" />
                    Ready to Generate
                  </div>
                  <div style={{fontSize:12,color:"#555",marginBottom:4}}>
                    <strong>{reportType}</strong>
                  </div>
                  <div style={{fontSize:11,color:"#888"}}>
                    <span style={{display:"flex",alignItems:"center",gap:4}}><Calendar size={12} color="#888"/> {dateFrom} → {dateTo}</span>
                  </div>
                </>) : (
                  <div style={{fontSize:12,color:"#bbb",textAlign:"center",padding:"12px 0"}}>
                    ← Select a report type first
                  </div>
                )}
              </div>

              {/* Action buttons */}
              <div style={{display:"flex",flexDirection:"column",gap:10}}>
                <button className="rp-gen-btn preview" style={{width:"100%",padding:"13px",fontSize:14,textAlign:"center",display:"flex",alignItems:"center",justifyContent:"center",gap:8}}
                  onClick={()=>setPreview(true)} disabled={!reportType}>
                  <Eye size={15}/> Preview Report
                </button>
                <div style={{display:"grid",gridTemplateColumns:"1fr 1fr",gap:10}}>
                  <button className="rp-gen-btn excel" style={{padding:"13px",fontSize:13,textAlign:"center",display:"flex",alignItems:"center",justifyContent:"center",gap:6}}
                    disabled={!reportType||exporting==="excel"}
                    onClick={async()=>{setExp("excel");try{await exportExcel(reportType,dateFrom,dateTo);}catch{alert("Failed.");}finally{setExp("");}}}>
                    {exporting==="excel"?"Exporting...":<><Download size={13}/> Export Excel</>}
                  </button>
                  <button className="rp-gen-btn pdf" style={{padding:"13px",fontSize:13,textAlign:"center",display:"flex",alignItems:"center",justifyContent:"center",gap:6}}
                    disabled={!reportType||exporting==="pdf"}
                    onClick={async()=>{setExp("pdf");try{await exportPDF(reportType,dateFrom,dateTo);}catch{alert("Failed.");}finally{setExp("");}}}>
                    {exporting==="pdf"?"Exporting...":<><FileText size={13}/> Export PDF</>}
                  </button>
                </div>
              </div>

            </div>
          </div>
        </div>
      )}

      {/* ══ AUDIT LOG ════════════════════════════════════════════════════════ */}
      {activeTab === "audit" && (
        <div className="rp-chart-card">
          <div className="rp-chart-title" style={{display:"flex",alignItems:"center",gap:6}}><Link size={14}/> Blockchain Audit Log ({selectedYear})</div>
          <div className="rp-chart-sub">All recorded loan payments with SHA-256 hash and blockchain transaction ID</div>
          <ProTable
            columns={[
              {label:"Date",      key:"paid_at",     tdStyle:{color:"#555",fontSize:11}},
              {label:"TX ID",     key:"tx_id",       tdStyle:{fontFamily:"monospace",fontSize:10,color:"#888"}},
              {label:"Member",    key:"member",      tdStyle:{fontWeight:600}},
              {label:"Member ID", key:"member_id",   tdStyle:{fontFamily:"monospace",fontSize:11}},
              {label:"Loan ID",   key:"loan_id",     tdStyle:{fontFamily:"monospace",fontSize:11}},
              {label:"Amount",    key:"amount",      render:r=>`₱${Number(r.amount||0).toLocaleString()}`, tdStyle:{fontWeight:700,color:"#2e7d32"}},
              {label:"Balance",   key:"balance",     render:r=>`₱${Number(r.balance||0).toLocaleString()}`, tdStyle:{color:"#1565c0"}},
              {label:"Hash",      key:"hash",        tdStyle:{fontFamily:"monospace",fontSize:9,color:"#aaa",maxWidth:160,overflow:"hidden",textOverflow:"ellipsis"}},
              {label:"By",        key:"recorded_by", tdStyle:{fontSize:11,color:"#888"}},
            ]}
            rows={auditLog}
            empty={`No transactions recorded for ${selectedYear}.`}
          />
        </div>
      )}

    </div>
  );
}