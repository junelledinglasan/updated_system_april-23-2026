import { useState, useEffect } from "react";
import { getGCashRequestsAPI, verifyGCashRequestAPI } from "../../api/loans";
import { Smartphone, CheckCircle, XCircle, Clock, Search, Eye } from "lucide-react";

const STATUS_COLOR = {
  Pending:  { bg:"#fff8e1", color:"#f57c00", border:"#ffe082" },
  Verified: { bg:"#e8f5e9", color:"#2e7d32", border:"#a5d6a7" },
  Rejected: { bg:"#ffebee", color:"#c62828", border:"#ef9a9a" },
};

function RequestDetailModal({ req, onClose, onVerify, onReject }) {
  const [rejectMode,    setRejectMode]    = useState(false);
  const [rejectReason,  setRejectReason]  = useState("");
  const [loading,       setLoading]       = useState(false);

  if (!req) return null;
  const sc = STATUS_COLOR[req.status] || STATUS_COLOR.Pending;

  const handleVerify = async () => {
    setLoading(true);
    try { await onVerify(req.id); onClose(); }
    catch(e) { alert(e.response?.data?.error || "Failed to verify."); }
    finally { setLoading(false); }
  };

  const handleReject = async () => {
    if (!rejectReason.trim()) return;
    setLoading(true);
    try { await onReject(req.id, rejectReason); onClose(); }
    catch(e) { alert(e.response?.data?.error || "Failed to reject."); }
    finally { setLoading(false); }
  };

  return (
    <div style={{position:"fixed",inset:0,background:"rgba(0,0,0,0.55)",zIndex:9999,display:"flex",alignItems:"center",justifyContent:"center",padding:16}} onClick={onClose}>
      <div style={{background:"#fff",borderRadius:16,width:"100%",maxWidth:500,maxHeight:"90vh",overflow:"hidden",display:"flex",flexDirection:"column"}} onClick={e=>e.stopPropagation()}>

        {/* Header */}
        <div style={{padding:"14px 18px",borderBottom:"1px solid #f0f0f0",display:"flex",justifyContent:"space-between",alignItems:"center"}}>
          <div>
            <div style={{fontWeight:800,fontSize:14,color:"#1b5e20",display:"flex",alignItems:"center",gap:6}}>
              <Smartphone size={16} color="#007bff"/> GCash Payment Request
            </div>
            <div style={{fontSize:11,color:"#aaa",marginTop:2}}>{req.created_at}</div>
          </div>
          <button onClick={onClose} style={{background:"none",border:"none",cursor:"pointer",color:"#aaa",fontSize:18}}>✕</button>
        </div>

        <div style={{padding:"16px 18px",overflowY:"auto",flex:1,display:"flex",flexDirection:"column",gap:14}}>

          {/* Status badge */}
          <div style={{display:"flex",justifyContent:"center"}}>
            <span style={{background:sc.bg,color:sc.color,border:`1px solid ${sc.border}`,borderRadius:20,padding:"6px 20px",fontSize:13,fontWeight:800}}>
              {req.status === "Pending" ? <><Clock size={13}/> Pending Verification</> :
               req.status === "Verified" ? <><CheckCircle size={13}/> Verified</> :
               <><XCircle size={13}/> Rejected</>}
            </span>
          </div>

          {/* Member + Loan Info */}
          <div style={{background:"#f8f9fa",borderRadius:10,padding:"12px 14px",display:"grid",gridTemplateColumns:"1fr 1fr",gap:10}}>
            {[
              ["Member",     req.member_name],
              ["Member ID",  req.member_id],
              ["Loan ID",    req.loan_id],
              ["Amount",     `₱${Number(req.amount).toLocaleString()}`],
            ].map(([k,v]) => (
              <div key={k}>
                <div style={{fontSize:10,color:"#888",fontWeight:600,textTransform:"uppercase"}}>{k}</div>
                <div style={{fontSize:13,fontWeight:700,color:"#222",fontFamily:k==="Member ID"||k==="Loan ID"?"monospace":"inherit"}}>{v}</div>
              </div>
            ))}
          </div>

          {/* Reference Number — most important */}
          <div style={{background:"#e3f2fd",borderRadius:12,padding:"16px",textAlign:"center",border:"2px solid #90caf9"}}>
            <div style={{fontSize:11,color:"#1565c0",fontWeight:700,marginBottom:6,textTransform:"uppercase",letterSpacing:0.5}}>GCash Reference Number</div>
            <div style={{fontSize:28,fontWeight:800,color:"#0d47a1",letterSpacing:3,fontFamily:"monospace"}}>{req.reference_number}</div>
            <div style={{fontSize:11,color:"#888",marginTop:6}}>Verify this in your GCash app → Transaction History</div>
          </div>

          {/* Amount highlight */}
          <div style={{background:"#e8f5e9",borderRadius:10,padding:"12px 16px",textAlign:"center",border:"1px solid #a5d6a7"}}>
            <div style={{fontSize:11,color:"#2e7d32",fontWeight:600}}>Payment Amount</div>
            <div style={{fontSize:24,fontWeight:800,color:"#1b5e20"}}>₱{Number(req.amount).toLocaleString()}</div>
          </div>

          {/* Screenshot proof — always shown */}
          <div>
            <div style={{fontSize:12,fontWeight:700,color:"#555",marginBottom:8,display:"flex",alignItems:"center",gap:6}}>
              🖼 Payment Proof Screenshot
              {!req.screenshot_url && <span style={{fontSize:10,color:"#c62828",fontWeight:600,background:"#ffebee",padding:"2px 8px",borderRadius:10,border:"1px solid #ef9a9a"}}>⚠ No screenshot submitted</span>}
            </div>
            {req.screenshot_url ? (
              <div>
                <div style={{borderRadius:10,overflow:"hidden",border:"2px solid #90caf9",background:"#f0f7ff"}}>
                  <img
                    src={req.screenshot_url}
                    alt="GCash proof"
                    style={{width:"100%",maxHeight:300,objectFit:"contain",display:"block",cursor:"pointer"}}
                    onClick={() => window.open(req.screenshot_url, "_blank")}
                  />
                </div>
                <a href={req.screenshot_url} target="_blank" rel="noopener noreferrer"
                  style={{fontSize:11,color:"#1565c0",fontWeight:600,display:"block",marginTop:6}}>
                  🔗 Open full size
                </a>
              </div>
            ) : (
              <div style={{background:"#f5f5f5",border:"1.5px dashed #e0e0e0",borderRadius:10,padding:"28px",textAlign:"center",color:"#bbb",fontSize:12}}>
                No payment screenshot was submitted.
              </div>
            )}
          </div>

          {req.note && (
            <div style={{background:"#fff8e1",borderRadius:8,padding:"10px 14px",border:"1px solid #ffe082",fontSize:12,color:"#555"}}>
              <strong>Note:</strong> {req.note}
            </div>
          )}

          {req.status === "Verified" && (
            <div style={{background:"#e8f5e9",borderRadius:8,padding:"10px 14px",border:"1px solid #a5d6a7",fontSize:12,color:"#2e7d32",fontWeight:600}}>
              ✅ Verified by {req.verified_by} on {req.verified_at}
            </div>
          )}

          {req.status === "Rejected" && req.reject_reason && (
            <div style={{background:"#ffebee",borderRadius:8,padding:"10px 14px",border:"1px solid #ef9a9a",fontSize:12,color:"#c62828"}}>
              ❌ Rejected: {req.reject_reason}
            </div>
          )}

          {/* Reject reason input */}
          {rejectMode && (
            <div>
              <div style={{fontSize:11,fontWeight:700,color:"#c62828",marginBottom:6,textTransform:"uppercase"}}>Reason for Rejection</div>
              <textarea
                value={rejectReason}
                onChange={e => setRejectReason(e.target.value)}
                placeholder="e.g. Reference number not found in GCash, amount does not match..."
                rows={3}
                autoFocus
                style={{width:"100%",boxSizing:"border-box",padding:"10px 12px",fontSize:13,border:"1.5px solid #ef9a9a",borderRadius:8,outline:"none",resize:"vertical",fontFamily:"inherit"}}
              />
            </div>
          )}
        </div>

        {/* Footer */}
        <div style={{padding:"12px 18px",borderTop:"1px solid #f0f0f0",display:"flex",gap:8,justifyContent:"flex-end"}}>
          {req.status === "Pending" && !rejectMode ? (<>
            <button onClick={onClose} style={{padding:"8px 16px",border:"1px solid #e0e0e0",borderRadius:8,background:"#fff",color:"#666",fontSize:12,fontWeight:600,cursor:"pointer",fontFamily:"inherit"}}>Close</button>
            <button onClick={() => setRejectMode(true)} style={{padding:"8px 16px",border:"1.5px solid #ef9a9a",borderRadius:8,background:"#ffebee",color:"#c62828",fontSize:12,fontWeight:700,cursor:"pointer",fontFamily:"inherit",display:"flex",alignItems:"center",gap:5}}>
              <XCircle size={13}/> Reject
            </button>
            <button onClick={handleVerify} disabled={loading} style={{padding:"8px 18px",background:"#2e7d32",color:"#fff",border:"none",borderRadius:8,fontSize:12,fontWeight:700,cursor:"pointer",fontFamily:"inherit",display:"flex",alignItems:"center",gap:5,opacity:loading?0.7:1}}>
              <CheckCircle size={13}/> {loading?"Verifying...":"Verify & Record Payment"}
            </button>
          </>) : rejectMode ? (<>
            <button onClick={() => { setRejectMode(false); setRejectReason(""); }} style={{padding:"8px 16px",border:"1px solid #e0e0e0",borderRadius:8,background:"#fff",color:"#666",fontSize:12,fontWeight:600,cursor:"pointer",fontFamily:"inherit"}}>← Back</button>
            <button onClick={handleReject} disabled={!rejectReason.trim()||loading} style={{padding:"8px 18px",background:"#c62828",color:"#fff",border:"none",borderRadius:8,fontSize:12,fontWeight:700,cursor:"pointer",fontFamily:"inherit",opacity:!rejectReason.trim()||loading?0.5:1}}>
              {loading?"Rejecting...":"Confirm Rejection"}
            </button>
          </>) : (
            <button onClick={onClose} style={{padding:"8px 18px",background:"#2e7d32",color:"#fff",border:"none",borderRadius:8,fontSize:12,fontWeight:700,cursor:"pointer",fontFamily:"inherit"}}>Close</button>
          )}
        </div>
      </div>
    </div>
  );
}

export default function GCashVerification() {
  const [requests,  setRequests]  = useState([]);
  const [loading,   setLoading]   = useState(true);
  const [filter,    setFilter]    = useState("Pending");
  const [search,    setSearch]    = useState("");
  const [selected,  setSelected]  = useState(null);
  const [toast,     setToast]     = useState(null);

  const showToast = (msg, type="success") => {
    setToast({ msg, type });
    setTimeout(() => setToast(null), 3000);
  };

  const fetchRequests = async () => {
    setLoading(true);
    try {
      const data = await getGCashRequestsAPI(filter !== "All" ? { status: filter } : {});
      setRequests(Array.isArray(data) ? data : []);
    } catch(e) {
      console.error(e);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { fetchRequests(); }, [filter]);

  const handleVerify = async (id) => {
    await verifyGCashRequestAPI(id, { action: "verify" });
    showToast("Payment verified and recorded!", "success");
    fetchRequests();
  };

  const handleReject = async (id, reason) => {
    await verifyGCashRequestAPI(id, { action: "reject", reject_reason: reason });
    showToast("Payment request rejected.", "danger");
    fetchRequests();
  };

  const filtered = requests.filter(r => {
    const q = search.toLowerCase();
    return (
      r.member_name?.toLowerCase().includes(q) ||
      r.member_id?.toLowerCase().includes(q) ||
      r.loan_id?.toLowerCase().includes(q) ||
      r.reference_number?.toLowerCase().includes(q)
    );
  });

  const counts = {
    Pending:  requests.filter(r=>r.status==="Pending").length,
    Verified: requests.filter(r=>r.status==="Verified").length,
    Rejected: requests.filter(r=>r.status==="Rejected").length,
  };

  return (
    <div style={{display:"flex",flexDirection:"column",gap:20,padding:"28px 32px",maxWidth:"100%"}}>
      {toast && (
        <div style={{position:"fixed",top:20,right:20,zIndex:9999,padding:"12px 20px",borderRadius:10,background:toast.type==="success"?"#2e7d32":"#c62828",color:"#fff",fontWeight:700,fontSize:13,boxShadow:"0 4px 12px rgba(0,0,0,0.2)"}}>
          {toast.msg}
        </div>
      )}

      {selected && (
        <RequestDetailModal
          req={selected}
          onClose={() => setSelected(null)}
          onVerify={handleVerify}
          onReject={handleReject}
        />
      )}

      {/* Header */}
      <div style={{display:"flex",alignItems:"center",gap:10}}>
        <div style={{background:"#e3f2fd",borderRadius:10,padding:10,display:"flex"}}>
          <Smartphone size={20} color="#1565c0"/>
        </div>
        <div>
          <div style={{fontSize:16,fontWeight:800,color:"#1b5e20"}}>GCash Payment Requests</div>
          <div style={{fontSize:11,color:"#aaa"}}>Verify member GCash payments before recording</div>
        </div>
      </div>

      {/* Summary cards */}
      <div style={{display:"grid",gridTemplateColumns:"repeat(3,1fr)",gap:12}}>
        {[
          {label:"Pending Verification", val:counts.Pending,  bg:"#fff8e1", color:"#f57c00", icon:<Clock size={18}/>},
          {label:"Verified & Recorded",  val:counts.Verified, bg:"#e8f5e9", color:"#2e7d32", icon:<CheckCircle size={18}/>},
          {label:"Rejected",             val:counts.Rejected, bg:"#ffebee", color:"#c62828", icon:<XCircle size={18}/>},
        ].map((c,i) => (
          <div key={i} style={{background:c.bg,borderRadius:12,padding:"14px 16px",border:`1px solid ${c.color}22`,display:"flex",alignItems:"center",gap:12,cursor:"pointer"}} onClick={()=>setFilter(["Pending","Verified","Rejected"][i])}>
            <div style={{color:c.color}}>{c.icon}</div>
            <div>
              <div style={{fontSize:22,fontWeight:800,color:c.color}}>{c.val}</div>
              <div style={{fontSize:10,color:c.color,fontWeight:600,textTransform:"uppercase",letterSpacing:0.3}}>{c.label}</div>
            </div>
          </div>
        ))}
      </div>

      {/* Filter + Search */}
      <div style={{display:"flex",gap:10,flexWrap:"wrap",alignItems:"center"}}>
        <div style={{display:"flex",gap:6}}>
          {["All","Pending","Verified","Rejected"].map(s => (
            <button key={s} onClick={()=>setFilter(s)} style={{
              padding:"6px 14px",borderRadius:20,fontSize:12,fontWeight:700,cursor:"pointer",fontFamily:"inherit",
              border:`1.5px solid ${filter===s?"#1565c0":"#e0e0e0"}`,
              background:filter===s?"#e3f2fd":"#fff",
              color:filter===s?"#1565c0":"#888",
              transition:"all 0.15s",
            }}>{s}{s!=="All"&&counts[s]>0?` (${counts[s]})`:""}</button>
          ))}
        </div>
        <div style={{display:"flex",alignItems:"center",gap:6,background:"#f5f5f5",borderRadius:8,padding:"7px 12px",flex:1,minWidth:200}}>
          <Search size={13} color="#aaa"/>
          <input
            value={search}
            onChange={e=>setSearch(e.target.value)}
            placeholder="Search by name, member ID, loan ID, reference..."
            style={{border:"none",outline:"none",background:"transparent",fontSize:12,fontFamily:"inherit",flex:1}}
          />
        </div>
      </div>

      {/* Table */}
      <div style={{background:"#fff",borderRadius:12,border:"1px solid #e0e0e0",overflow:"hidden"}}>
        {loading ? (
          <div style={{textAlign:"center",padding:"40px",color:"#aaa",fontSize:13}}>Loading requests...</div>
        ) : filtered.length === 0 ? (
          <div style={{textAlign:"center",padding:"40px",color:"#bbb",fontSize:13}}>No {filter !== "All" ? filter.toLowerCase() : ""} GCash requests.</div>
        ) : (
          <table style={{width:"100%",borderCollapse:"collapse",fontSize:12}}>
            <thead>
              <tr style={{background:"#f8f9fa",borderBottom:"2px solid #e0e0e0"}}>
                {["Date","Member","Loan ID","Reference No.","Amount","Proof","Status","Action"].map(h => (
                  <th key={h} style={{padding:"10px 14px",textAlign:"left",fontWeight:700,color:"#555",fontSize:11,textTransform:"uppercase",letterSpacing:0.3}}>{h}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {filtered.map((r,i) => {
                const sc = STATUS_COLOR[r.status] || STATUS_COLOR.Pending;
                return (
                  <tr key={r.id} style={{background:i%2===0?"#fff":"#fafafa",borderBottom:"1px solid #f0f0f0",cursor:"pointer"}} onClick={()=>setSelected(r)}>
                    <td style={{padding:"10px 14px",color:"#888",fontSize:11}}>{r.created_at?.slice(0,10)}</td>
                    <td style={{padding:"12px 18px"}}>
                      <div style={{fontWeight:600,color:"#333"}}>{r.member_name}</div>
                      <div style={{fontSize:10,color:"#aaa",fontFamily:"monospace"}}>{r.member_id}</div>
                    </td>
                    <td style={{padding:"10px 14px",fontFamily:"monospace",color:"#1565c0",fontSize:11}}>{r.loan_id}</td>
                    <td style={{padding:"10px 14px",fontFamily:"monospace",fontWeight:700,color:"#0d47a1",letterSpacing:1}}>{r.reference_number}</td>
                    <td style={{padding:"10px 14px",fontWeight:700,color:"#2e7d32"}}>₱{Number(r.amount).toLocaleString()}</td>
                    <td style={{padding:"10px 14px",textAlign:"center"}}>
                      {r.screenshot_url
                        ? <a href={r.screenshot_url} target="_blank" rel="noopener noreferrer" style={{fontSize:18}} title="View proof">🖼</a>
                        : <span style={{color:"#ccc",fontSize:12}}>—</span>}
                    </td>
                    <td style={{padding:"12px 18px"}}>
                      <span style={{background:sc.bg,color:sc.color,border:`1px solid ${sc.border}`,borderRadius:20,padding:"3px 10px",fontSize:11,fontWeight:700}}>{r.status}</span>
                    </td>
                    <td style={{padding:"12px 18px"}}>
                      <button onClick={e=>{e.stopPropagation();setSelected(r);}} style={{display:"flex",alignItems:"center",gap:4,padding:"5px 10px",border:"1px solid #e0e0e0",borderRadius:6,background:"#f5f5f5",color:"#555",fontSize:11,fontWeight:600,cursor:"pointer"}}>
                        <Eye size={11}/> View
                      </button>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        )}
      </div>
    </div>
  );
}