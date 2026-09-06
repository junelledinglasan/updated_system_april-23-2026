import { useState, useEffect } from "react";
import { getOnlineApplicationsAPI, getOnlineApplicationAPI, updateOnlineAppStatusAPI } from "../../api/members";
import { Search, Paperclip, Users, CheckCircle, XCircle, AlertTriangle, ExternalLink, Loader, X, Lock } from "lucide-react";
import "./OnlineApplications.css";

const STATUS_TABS   = ["All", "Pending", "Approved", "Rejected"];
const ROWS_PER_PAGE = 8;
const STATUS_COLOR  = {
  Pending:  "status-pending",
  Approved: "status-approved",
  Rejected: "status-rejected",
};

// ─── View Modal ───────────────────────────────────────────────────────────────
function ViewModal({ app, loadingDetails=false, onClose, onApprove, onReject }) {
  const [rejectMode, setRejectMode] = useState(false);
  const [reason,     setReason]     = useState("");
  // ── BAGO: tinanggal ang "idTab" state — hindi na kailangan dahil
  // isa na lang na Birth Certificate image ang ipinapakita, wala nang
  // front/back tab switcher. ───────────────────────────────────────

  if (!app) return null;
  const status = app.application_status || app.status || "Pending";

  const handleReject = () => {
    if (!reason.trim()) return;
    onReject(app.id, reason);
  };

  // ── BAGO: dating plain na text lang (label sa itaas, value sa
  // ibaba, walang background/border) — ngayon "chip"-style box, tugma
  // sa established na pattern sa ibang bahagi ng system (hal.
  // ManageMember.jsx). ─────────────────────────────────────────────────
  // ── BAGO: dating plain na section lang (title + grid, walang
  // card/border/background) — ngayon may white card, subtle border,
  // at green accent bar sa tabi ng title, para mas malinaw ang
  // paghihiwalay ng bawat seksyon. ─────────────────────────────────────
  const SectionCard = ({ title, icon, children }) => (
    <div style={{background:"#fff", border:"1px solid #e8f5e9", borderRadius:12, padding:16, boxShadow:"0 1px 4px rgba(0,0,0,0.03)"}}>
      <div style={{display:"flex", alignItems:"center", gap:8, marginBottom:12}}>
        <div style={{width:4, height:16, background:"#2e7d32", borderRadius:2}}/>
        <div style={{fontSize:12,fontWeight:700,color:"#1b5e20",textTransform:"uppercase",letterSpacing:0.5,display:"flex",alignItems:"center",gap:6}}>
          {icon}{title}
        </div>
      </div>
      {children}
    </div>
  );

  const InfoRow = ({ label, value, mono=false, full=false }) => (
    <div className={full ? "oa-full" : ""} style={{
      background:"#f9fef9", border:"1px solid #e8f5e9", borderRadius:8,
      padding:"8px 12px", display:"flex", flexDirection:"column", gap:2,
    }}>
      <span style={{fontSize:9.5,fontWeight:700,color:"#8a9a7a",textTransform:"uppercase",letterSpacing:0.4}}>{label}</span>
      <span style={{fontSize:12.5,color:"#222",fontWeight:600,fontFamily:mono?"monospace":"inherit",overflow:"hidden",textOverflow:"ellipsis",whiteSpace:"nowrap"}}>{value || "—"}</span>
    </div>
  );

  // ── BAGO: dating "Valid ID" (front + back, 2 images) — ngayon
  // "Birth Certificate" na lang (1 imahe), tugma sa binago natin sa
  // member-side ApplyMembership.jsx. ──────────────────────────────────
  const hasBirthCert = !!app.id_front_url;
  const hasSpouseInfo = !!(app.spouse_name || app.beneficiary_name);

  return (
    <div className="oa-modal-overlay" onClick={onClose}>
      <div className="oa-modal-box oa-modal-lg" onClick={e => e.stopPropagation()}>
        <div className="oa-modal-header">
          <div>
            <div className="oa-modal-title">Membership Application</div>
            <div className="oa-modal-sub">{app.app_id} · Submitted {app.created_at?.slice(0,10)}</div>
          </div>
          <div style={{ display:"flex", alignItems:"center", gap:10 }}>
            <span className={`oa-badge ${STATUS_COLOR[status] || ""}`}>{status}</span>
            <button className="oa-modal-close" onClick={onClose}><X size={16}/></button>
          </div>
        </div>

        <div className="oa-modal-body" style={{background:"#f7faf7"}}>
          {loadingDetails ? (
            <div style={{textAlign:"center",padding:"32px 0",color:"#aaa"}}>
              <Loader size={24} style={{marginBottom:8}}/>
              <div>Loading full application details...</div>
            </div>
          ) : (<>
            {/* ── Personal Info ── */}
            <SectionCard title="Personal Information">
              <div className="oa-info-grid">
                <InfoRow label="Last Name"              value={app.last_name} />
                <InfoRow label="First Name"             value={app.first_name} />
                <InfoRow label="Middle Name"            value={app.middle_name} />
                <InfoRow label="Birthdate"              value={app.birth_date} />
                <InfoRow label="Place of Birth"         value={app.place_of_birth} />
                <InfoRow label="Sex"                    value={app.sex} />
                <InfoRow label="Civil Status"           value={app.civil_status} />
                <InfoRow label="TIN No."                value={app.tin_no} />
                <InfoRow label="SSS/GSIS No."           value={app.sss_gsis_no} />
                <InfoRow label="Classification"         value={app.classification} />
                <InfoRow label="Educational Attainment" value={app.educational_attainment} />
                <InfoRow label="Occupation"             value={app.occupation} />
                <InfoRow label="Monthly Income"         value={app.income && app.income !== "0.00" ? `₱${Number(app.income).toLocaleString()}` : "—"} />
                <InfoRow label="Contact No."            value={app.contact_number} mono />
                <InfoRow label="Email"                  value={app.email} mono />
                <InfoRow label="Religious/Social Affiliation" value={app.religious_social_affiliation} />
                <InfoRow label="Address"                value={app.address} full />
                <InfoRow label="Birth Certificate"      value={app.birth_certificate ? <span style={{display:"inline-flex",alignItems:"center",gap:4,color:"#2e7d32"}}><CheckCircle size={13}/> Submitted</span> : <span style={{display:"inline-flex",alignItems:"center",gap:4,color:"#c62828"}}><XCircle size={13}/> Not submitted</span>} />
                <InfoRow label="Marriage Certificate"   value={app.marriage_certificate ? <span style={{display:"inline-flex",alignItems:"center",gap:4,color:"#2e7d32"}}><CheckCircle size={13}/> Submitted</span> : <span style={{display:"inline-flex",alignItems:"center",gap:4,color:"#c62828"}}><XCircle size={13}/> Not submitted</span>} />
              </div>
            </SectionCard>

            {/* ── Spouse & Family ── */}
            {hasSpouseInfo && (
              <SectionCard title="Spouse & Family" icon={<Users size={14}/>}>
                <div className="oa-info-grid">
                  <InfoRow label="Spouse Name"        value={app.spouse_name} />
                  <InfoRow label="Spouse Occupation"  value={app.spouse_occupation} />
                  <InfoRow label="Spouse Income"      value={app.spouse_income && app.spouse_income !== "0.00" ? `₱${Number(app.spouse_income).toLocaleString()}` : "—"} />
                  <InfoRow label="No. of Dependants"  value={app.no_of_dependants} />
                  <InfoRow label="Beneficiary Name"   value={app.beneficiary_name} />
                  <InfoRow label="Relationship"       value={app.beneficiary_relationship} />
                  {app.credit_references && (
                    <InfoRow label="Credit References" value={app.credit_references} full />
                  )}
                </div>
              </SectionCard>
            )}

            {/* ── Birth Certificate Image ── */}
            <SectionCard title="Birth Certificate Verification" icon={<Paperclip size={14}/>}>
              {!hasBirthCert ? (
                <div style={{padding:"16px",background:"#fff8e1",borderRadius:8,border:"1px solid #ffe082",fontSize:12,color:"#f57c00",display:"flex",alignItems:"center",gap:8}}>
                  <AlertTriangle size={14}/> No Birth Certificate uploaded by the applicant.
                </div>
              ) : (
                <>
                  <div style={{textAlign:"center"}}>
                    <img
                      src={app.id_front_url}
                      alt="Birth Certificate"
                      style={{maxWidth:"100%",maxHeight:320,borderRadius:10,border:"2px solid #a5d6a7",objectFit:"contain"}}
                    />
                    <div style={{marginTop:8,fontSize:11,color:"#888"}}>
                      <a href={app.id_front_url} target="_blank" rel="noopener noreferrer" style={{color:"#2e7d32",display:"inline-flex",alignItems:"center",gap:4}}>
                        <ExternalLink size={12}/> Open full size
                      </a>
                    </div>
                  </div>

                  <div style={{marginTop:10,padding:"8px 12px",background:"#e8f5e9",borderRadius:8,fontSize:11,color:"#2e7d32",fontWeight:600,display:"flex",alignItems:"center",gap:6}}>
                    <CheckCircle size={13}/> Please verify that the name and other details on the Birth Certificate match the information provided in the form above before approving.
                  </div>
                </>
              )}
            </SectionCard>

            {/* ── Account Credentials ── */}
            {(app.username || app.plain_password) && (
              <SectionCard title="Account Credentials" icon={<Lock size={14}/>}>
                <div className="oa-info-grid">
                  <InfoRow label="Username" value={app.username} mono />
                  <InfoRow label="Password"  value={app.plain_password} mono />
                </div>
              </SectionCard>
            )}

            {status === "Rejected" && app.reject_reason && (
              <div className="oa-notice oa-notice-rejected" style={{display:"flex",alignItems:"center",gap:6}}>
                <XCircle size={14}/> Rejected: <strong>{app.reject_reason}</strong>
              </div>
            )}
            {status === "Approved" && (
              <div className="oa-notice oa-notice-approved" style={{display:"flex",alignItems:"center",gap:6}}>
                <CheckCircle size={14}/> This application has been <strong>approved</strong>.
              </div>
            )}

            {rejectMode && (
              <SectionCard title="Reason for Rejection" icon={<XCircle size={14}/>}>
                <textarea
                  className="oa-textarea"
                  placeholder="e.g. Incomplete requirements, ID does not match provided info..."
                  value={reason}
                  onChange={e => setReason(e.target.value)}
                  rows={3}
                  autoFocus
                />
              </SectionCard>
            )}
          </>)}
        </div>

        <div className="oa-modal-footer">
          {!rejectMode ? (
            <>
              <button className="oa-btn-cancel" onClick={onClose}>Close</button>
              {status === "Pending" && (
                <>
                  <button className="oa-btn-reject-soft" onClick={() => setRejectMode(true)} style={{display:"flex",alignItems:"center",gap:6}}><XCircle size={14}/> Reject</button>
                  <button className="oa-btn-approve" onClick={() => onApprove(app.id)} style={{display:"flex",alignItems:"center",gap:6}}><CheckCircle size={14}/> Approve</button>
                </>
              )}
            </>
          ) : (
            <>
              <button className="oa-btn-cancel" onClick={() => { setRejectMode(false); setReason(""); }}>← Back</button>
              <button className="oa-btn-reject-confirm" onClick={handleReject} disabled={!reason.trim()}>Confirm Rejection</button>
            </>
          )}
        </div>
      </div>
    </div>
  );
}

// ─── Main Component ───────────────────────────────────────────────────────────
export default function OnlineApplications() {
  const [apps,         setApps]        = useState([]);
  const [loading,      setLoading]     = useState(true);
  const [search,       setSearch]      = useState("");
  const [filterStatus, setFilter]      = useState("All");
  const [currentPage,  setPage]        = useState(1);
  const [viewApp,      setViewApp]     = useState(null);
  const [fullAppData,  setFullAppData] = useState(null);
  const [loadingApp,   setLoadingApp]  = useState(false);
  const [toast,        setToast]       = useState(null);
  const [approvedCount, setApprovedCount] = useState(0);
  const [totalCount,    setTotalCount]    = useState(0);

  const fetchApps = async () => {
    setLoading(true);
    try {
      const res = await getOnlineApplicationsAPI();
      const appList = res.applications || (Array.isArray(res) ? res : []);
      setApps(appList);
      setApprovedCount(appList.filter(a => a.application_status === "Approved").length);
      setTotalCount(res.total_count || appList.length);
    } catch (err) {
      console.error("Failed to fetch online applications:", err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { fetchApps(); }, []);

  const handleViewApp = async (app) => {
    setViewApp(app);
    setFullAppData(null);
    setLoadingApp(true);
    try {
      const full = await getOnlineApplicationAPI(app.id);
      setFullAppData(full);
    } catch(e) {
      setFullAppData(app);
    } finally {
      setLoadingApp(false);
    }
  };

  const showToast = (msg, type="success") => {
    setToast({ msg, type });
    setTimeout(() => setToast(null), 3500);
  };

  const counts = {
    total:    totalCount || apps.length,
    pending:  apps.filter(a => a.application_status === "Pending").length,
    approved: approvedCount,
    rejected: apps.filter(a => a.application_status === "Rejected").length,
  };

  const filtered = apps.filter(a => {
    const matchStatus = filterStatus === "All" || a.application_status === filterStatus;
    const q = search.toLowerCase();
    const fullname = (a.fullname || `${a.first_name} ${a.last_name}`).toLowerCase();
    return matchStatus && (
      (a.app_id || "").toLowerCase().includes(q) ||
      fullname.includes(q) ||
      (a.contact_number || "").includes(q) ||
      (a.email || "").toLowerCase().includes(q) ||
      (a.occupation || "").toLowerCase().includes(q)
    );
  });

  const totalPages = Math.max(1, Math.ceil(filtered.length / ROWS_PER_PAGE));
  const safePage   = Math.min(currentPage, totalPages);
  const paginated  = filtered.slice((safePage - 1) * ROWS_PER_PAGE, safePage * ROWS_PER_PAGE);

  const handleApprove = async (id) => {
    try {
      await updateOnlineAppStatusAPI(id, { application_status: "Approved" });
      setApps(prev => prev.map(a => a.id === id ? { ...a, application_status: "Approved" } : a));
      setFullAppData(prev => prev ? { ...prev, application_status: "Approved" } : null);
      showToast("Application approved successfully!", "success");
    } catch(err) {
      showToast("Failed to approve application.", "danger");
    }
  };

  const handleReject = async (id, reason) => {
    try {
      await updateOnlineAppStatusAPI(id, { application_status: "Rejected", reject_reason: reason });
      setApps(prev => prev.map(a => a.id === id ? { ...a, application_status: "Rejected" } : a));
      setViewApp(null);
      setFullAppData(null);
      showToast("Application rejected.", "danger");
    } catch(err) {
      showToast("Failed to reject application.", "danger");
    }
  };

  const currentViewApp = fullAppData || viewApp;

  return (
    <div className="oa-wrapper">
      {toast && <div className={`oa-toast oa-toast-${toast.type}`}>{toast.msg}</div>}

      <ViewModal
        app={currentViewApp}
        loadingDetails={loadingApp}
        onClose={() => { setViewApp(null); setFullAppData(null); }}
        onApprove={handleApprove}
        onReject={handleReject}
      />

      <div className="oa-page-header">
        <div>
          <div className="oa-page-title">Online Applications</div>
          <div className="oa-page-sub">Review membership registration forms submitted online by applicants.</div>
        </div>
      </div>

      <div className="oa-summary-grid">
        <div className="oa-summary-card" onClick={() => { setFilter("All"); setPage(1); }}>
          <div className="oa-sum-val">{counts.total}</div><div className="oa-sum-label">Total Received</div>
        </div>
        <div className="oa-summary-card" onClick={() => { setFilter("Pending"); setPage(1); }}>
          <div className="oa-sum-val pending-val">{counts.pending}</div><div className="oa-sum-label">For Review</div>
        </div>
        <div className="oa-summary-card" onClick={() => { setFilter("Approved"); setPage(1); }}>
          <div className="oa-sum-val approved-val">{counts.approved}</div><div className="oa-sum-label">Approved</div>
        </div>
        <div className="oa-summary-card" onClick={() => { setFilter("Rejected"); setPage(1); }}>
          <div className="oa-sum-val rejected-val">{counts.rejected}</div><div className="oa-sum-label">Rejected</div>
        </div>
      </div>

      <div className="oa-card">
        <div className="oa-toolbar">
          <div className="oa-search-wrap">
            <span className="oa-search-icon"><Search size={13} color="#aaa"/></span>
            <input
              className="oa-search-input"
              placeholder="Search by App ID, Name, Contact, or Email..."
              value={search}
              onChange={e => { setSearch(e.target.value); setPage(1); }}
            />
            {search && <button className="oa-clear-btn" onClick={() => { setSearch(""); setPage(1); }}><X size={13}/></button>}
          </div>
          <div className="oa-status-tabs">
            {STATUS_TABS.map(s => (
              <button
                key={s}
                className={`oa-status-tab ${filterStatus===s?"active":""} tab-${s.toLowerCase()}`}
                onClick={() => { setFilter(s); setPage(1); }}
              >
                {s}
                {s !== "All" && <span className="oa-tab-count">{apps.filter(a => a.application_status===s).length}</span>}
              </button>
            ))}
          </div>
        </div>

        <div className="oa-table-wrap">
          <table className="oa-table">
            <thead>
              <tr>
                <th style={{ width:"14%" }}>App ID</th>
                <th style={{ width:"20%" }}>Full Name</th>
                <th style={{ width:"10%" }}>Birthdate</th>
                <th style={{ width:"13%" }}>Contact No.</th>
                <th style={{ width:"17%" }}>Email</th>
                <th style={{ width:"10%" }}>Occupation</th>
                <th style={{ width:"8%",textAlign:"center" }}>Birth Cert.</th>
                <th style={{ width:"8%" }}>Submitted</th>
              </tr>
            </thead>
            <tbody>
              {loading ? (
                <tr><td colSpan={8} className="oa-empty">Loading applications...</td></tr>
              ) : paginated.length === 0 ? (
                <tr><td colSpan={8} className="oa-empty">No applications found.</td></tr>
              ) : paginated.map(app => {
                const appStatus = app.application_status || "Pending";
                const hasBirthCert = app.id_front_url;
                return (
                  <tr
                    key={app.id}
                    className={`oa-clickable-row row-${appStatus.toLowerCase()}`}
                    onClick={() => handleViewApp(app)}
                  >
                    <td>
                      <div className="oa-id-cell">
                        <span className="mono cell-id">{app.app_id}</span>
                        <span className={`oa-badge ${STATUS_COLOR[appStatus] || ""}`}>{appStatus}</span>
                      </div>
                    </td>
                    <td className="cell-name">{app.fullname || `${app.last_name}, ${app.first_name}`}</td>
                    <td className="cell-date">{app.birth_date}</td>
                    <td className="mono">{app.contact_number}</td>
                    <td className="cell-email">{app.email}</td>
                    <td>{app.occupation}</td>
                    <td style={{textAlign:"center"}}>
                      <span title={hasBirthCert?"Birth Certificate uploaded":"No Birth Certificate"} style={{display:"inline-flex"}}>
                        {hasBirthCert ? <CheckCircle size={16} color="#2e7d32"/> : <XCircle size={16} color="#c62828"/>}
                      </span>
                    </td>
                    <td className="cell-date">{app.created_at?.slice(0,10)}</td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>

        <div className="oa-footer">
          <div className="oa-count">
            Showing {filtered.length===0 ? 0 : (safePage-1)*ROWS_PER_PAGE+1}–{Math.min(safePage*ROWS_PER_PAGE, filtered.length)} of {filtered.length} application{filtered.length!==1?"s":""}
            <span className="oa-click-hint"> — click any row to view & process</span>
          </div>
          <div className="oa-pagination">
            <button className="oa-page-btn" disabled={safePage===1} onClick={e=>{e.stopPropagation();setPage(p=>p-1);}}>← Prev</button>
            {Array.from({length:totalPages},(_,i)=>i+1)
              .filter(p=>p===1||p===totalPages||Math.abs(p-safePage)<=1)
              .reduce((acc,p,i,arr)=>{if(i>0&&p-arr[i-1]>1)acc.push("...");acc.push(p);return acc;},[])
              .map((p,i)=>p==="..."?<span key={`e${i}`} className="oa-ellipsis">…</span>:
                <button key={p} className={`oa-page-btn oa-page-num ${safePage===p?"active":""}`} onClick={e=>{e.stopPropagation();setPage(p);}}>{p}</button>
              )}
            <button className="oa-page-btn" disabled={safePage===totalPages} onClick={e=>{e.stopPropagation();setPage(p=>p+1);}}>Next →</button>
          </div>
        </div>
      </div>
    </div>
  );
}