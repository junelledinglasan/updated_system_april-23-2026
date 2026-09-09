import { useState, useRef, useEffect } from "react";
import { X, Upload, RotateCcw, Image as ImageIcon, Check, Smartphone, Plus, Pencil, Trash2, Lock } from "lucide-react";
import { uploadSystemLogoAPI, resetSystemLogoAPI, getAvailableFeaturesAPI, getStaffPermissionsListAPI, updateStaffPermissionsAPI, getGCashAccountsAPI, createGCashAccountAPI, updateGCashAccountAPI, deleteGCashAccountAPI } from "../../api/settings";
import "./SettingsModal.css";

const STAFF_ROLE_LABELS = {
  cashier: "Cashier", collector: "Collector", bookkeeper: "Bookkeeper", admin_clerk: "Administrative Clerk",
};

// ── BAGO: salamin ng "DEFAULT_FEATURES_BY_ROLE" sa backend
// (settings_app/models.py) — ginagamit lang para malaman kung
// "default" pa ang kasalukuyang permissions ng isang staff (hindi pa
// na-customize), para maipakita ito sa admin at hindi malito kung
// bakit may naka-check na agad kahit hindi pa sila mismo nag-set. ────
const DEFAULT_FEATURES_BY_ROLE = {
  cashier:     ["loan-payment"],
  collector:   ["loan-payment"],
  bookkeeper:  ["reports"],
  admin_clerk: ["members", "applications", "loan-approval", "announcement", "reports"],
};

// ─── Settings Modal — Logo Customization + Staff Feature Permissions + GCash ──
export default function SettingsModal({ onClose, logoUrl, onLogoUpdated }) {
  const [tab,      setTab]      = useState("logo");
  const [preview,  setPreview]  = useState(null);
  const [file,     setFile]     = useState(null);
  const [loading,  setLoading]  = useState(false);
  const [error,    setError]    = useState("");
  const [success,  setSuccess]  = useState("");
  const fileInputRef = useRef(null);

  // ── Staff Permissions state ──
  const [features,    setFeatures]    = useState([]);
  const [staffList,   setStaffList]   = useState([]);
  const [staffLoading, setStaffLoading] = useState(true);
  const [expandedStaff, setExpanded]  = useState(null);
  const [savingStaff,  setSavingStaff] = useState(null);
  const [localPerms,   setLocalPerms] = useState({}); // { staffId: [feature keys] }

  // ── BAGO: maraming GCash account (multiple accounts) — dating
  // iisang number/name lang. ───────────────────────────────────────────
  const [gcashLoading, setGcashLoading] = useState(true);
  const [gcashAccounts, setGcashAccounts] = useState([]);
  const [gcashError,   setGcashError]   = useState("");
  const [gcashSuccess, setGcashSuccess] = useState("");
  const [editingId,    setEditingId]    = useState(null); // id ng account na kasalukuyang ine-edit
  const [editForm,     setEditForm]     = useState({ label:"", number:"", account_name:"" });
  const [showAddForm,  setShowAddForm]  = useState(false);
  const [addForm,      setAddForm]      = useState({ label:"", number:"", account_name:"" });
  const [gcashSaving,  setGcashSaving]  = useState(false);

  const TABS = [
    { key: "logo", icon: <ImageIcon size={13}/>, label: "Logo" },
    { key: "staff-permissions", icon: <Lock size={13}/>, label: "Staff Permissions" },
    { key: "gcash", icon: <Smartphone size={13}/>, label: "GCash Payment" },
  ];

  useEffect(() => {
    if (tab !== "staff-permissions" || features.length > 0) return;
    setStaffLoading(true);
    Promise.all([getAvailableFeaturesAPI(), getStaffPermissionsListAPI()])
      .then(([feats, staff]) => {
        setFeatures(feats);
        setStaffList(staff);
        const perms = {};
        staff.forEach(s => { perms[s.staff_id] = s.features || []; });
        setLocalPerms(perms);
      })
      .catch(() => {})
      .finally(() => setStaffLoading(false));
  }, [tab, features.length]);

  // ── BAGO: kunin ang listahan ng LAHAT ng GCash accounts ──────────────
  const fetchGcashAccounts = () => {
    setGcashLoading(true);
    getGCashAccountsAPI()
      .then(data => setGcashAccounts(data))
      .catch(() => setGcashError("Failed to load GCash accounts."))
      .finally(() => setGcashLoading(false));
  };

  useEffect(() => {
    if (tab !== "gcash" || gcashAccounts.length > 0) return;
    fetchGcashAccounts();
  }, [tab]);

  const toggleFeature = (staffId, key) => {
    setLocalPerms(prev => {
      const current = prev[staffId] || [];
      const next = current.includes(key) ? current.filter(k => k !== key) : [...current, key];
      return { ...prev, [staffId]: next };
    });
  };

  const handleSavePermissions = async (staffId) => {
    setSavingStaff(staffId);
    try {
      await updateStaffPermissionsAPI(staffId, localPerms[staffId] || []);
      setStaffList(prev => prev.map(s => s.staff_id === staffId ? { ...s, features: localPerms[staffId] } : s));
    } catch { /* silent — pwedeng dagdagan ng error banner kung kailangan */ }
    finally { setSavingStaff(null); }
  };

  // ── BAGO: mga CRUD handler para sa maraming GCash account ────────────
  const handleAddAccount = async () => {
    setGcashError(""); setGcashSuccess("");
    if (!addForm.number.trim())       { setGcashError("GCash number is required."); return; }
    if (!addForm.account_name.trim()) { setGcashError("Account name is required."); return; }
    setGcashSaving(true);
    try {
      const created = await createGCashAccountAPI({
        label: addForm.label.trim(), number: addForm.number.trim(), account_name: addForm.account_name.trim(),
      });
      setGcashAccounts(prev => [...prev, created]);
      setAddForm({ label:"", number:"", account_name:"" });
      setShowAddForm(false);
      setGcashSuccess("New GCash account added!");
      setTimeout(() => setGcashSuccess(""), 3000);
    } catch (err) {
      setGcashError(err.response?.data?.error || "Failed to add GCash account.");
    } finally { setGcashSaving(false); }
  };

  const startEdit = (acc) => { setEditingId(acc.id); setEditForm({ label:acc.label||"", number:acc.number, account_name:acc.account_name }); setGcashError(""); };

  const handleSaveEdit = async (id) => {
    setGcashError("");
    if (!editForm.number.trim())       { setGcashError("GCash number is required."); return; }
    if (!editForm.account_name.trim()) { setGcashError("Account name is required."); return; }
    setGcashSaving(true);
    try {
      const updated = await updateGCashAccountAPI(id, {
        label: editForm.label.trim(), number: editForm.number.trim(), account_name: editForm.account_name.trim(),
      });
      setGcashAccounts(prev => prev.map(a => a.id === id ? updated : a));
      setEditingId(null);
    } catch (err) {
      setGcashError(err.response?.data?.error || "Failed to update GCash account.");
    } finally { setGcashSaving(false); }
  };

  const handleToggleActive = async (acc) => {
    try {
      const updated = await updateGCashAccountAPI(acc.id, { is_active: !acc.is_active });
      setGcashAccounts(prev => prev.map(a => a.id === acc.id ? updated : a));
    } catch { setGcashError("Failed to update account status."); }
  };

  const handleDeleteAccount = async (id) => {
    if (!window.confirm("Delete this GCash account? This cannot be undone.")) return;
    try {
      await deleteGCashAccountAPI(id);
      setGcashAccounts(prev => prev.filter(a => a.id !== id));
    } catch { setGcashError("Failed to delete GCash account."); }
  };

  const handleFileSelect = (f) => {
    if (!f) return;
    if (f.size > 2 * 1024 * 1024) {
      setError("File too large. Maximum is 2MB.");
      return;
    }
    if (!["image/png", "image/jpeg", "image/webp", "image/svg+xml"].includes(f.type)) {
      setError("Only PNG, JPG, WEBP, or SVG files are allowed.");
      return;
    }
    setError("");
    setFile(f);
    setPreview(URL.createObjectURL(f));
  };

  const handleUpload = async () => {
    if (!file) { setError("Please choose an image first."); return; }
    setLoading(true);
    setError("");
    try {
      const res = await uploadSystemLogoAPI(file);
      onLogoUpdated(res.logo_url);
      setSuccess("Logo updated successfully! It is now applied across the whole system.");
      setFile(null);
      setPreview(null);
      setTimeout(() => setSuccess(""), 3500);
    } catch (err) {
      setError(err.response?.data?.error || "Failed to upload logo. Please try again.");
    } finally {
      setLoading(false);
    }
  };

  const handleReset = async () => {
    setLoading(true);
    setError("");
    try {
      await resetSystemLogoAPI();
      onLogoUpdated(null);
      setSuccess("Logo reset to the default LEAF MPC logo.");
      setTimeout(() => setSuccess(""), 3500);
    } catch (err) {
      setError("Failed to reset logo.");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="stg-overlay" onClick={onClose}>
      <div className="stg-modal" onClick={e => e.stopPropagation()}>
        <div className="stg-header">
          <div>
            <div className="stg-title">Settings</div>
            <div className="stg-sub">Customize your LEAF MPC system.</div>
          </div>
          <button className="stg-close" onClick={onClose}><X size={16}/></button>
        </div>

        <div className="stg-tabs">
          {TABS.map(t => (
            <button key={t.key} className={`stg-tab ${tab === t.key ? "active" : ""}`} onClick={() => setTab(t.key)} style={{display:"flex",alignItems:"center",justifyContent:"center",gap:6}}>
              {t.icon}{t.label}
            </button>
          ))}
        </div>

        <div className="stg-body">
          {tab === "logo" && (
            <div className="stg-logo-section">
              <div className="stg-field-label">Current Logo</div>
              <div className="stg-current-logo-wrap">
                {logoUrl
                  ? <img src={logoUrl} alt="Current logo" className="stg-current-logo"/>
                  : <div className="stg-no-logo"><ImageIcon size={28} color="#bbb"/><span>Using default LEAF MPC logo</span></div>
                }
              </div>

              <div className="stg-field-label" style={{marginTop:18}}>Upload New Logo</div>
              <div className="stg-upload-hint">Recommended: transparent PNG or SVG, wide aspect ratio (e.g. 300×60px). Max 2MB.</div>

              {preview ? (
                <div className="stg-preview-wrap">
                  <img src={preview} alt="New logo preview" className="stg-preview-img"/>
                  <button className="stg-remove-preview" onClick={() => { setFile(null); setPreview(null); }} style={{display:"inline-flex",alignItems:"center",gap:4}}><X size={12}/> Remove</button>
                </div>
              ) : (
                <label className="stg-dropzone" onClick={() => fileInputRef.current?.click()}>
                  <Upload size={26} color="#2e7d32"/>
                  <div className="stg-dropzone-text">Click to choose an image</div>
                  <div className="stg-dropzone-sub">PNG, JPG, WEBP, or SVG</div>
                  <input ref={fileInputRef} type="file" accept="image/png,image/jpeg,image/webp,image/svg+xml"
                    style={{display:"none"}} onChange={e => handleFileSelect(e.target.files[0])}/>
                </label>
              )}

              {error   && <div className="stg-error-banner">{error}</div>}
              {success && <div className="stg-success-banner">{success}</div>}

              <div className="stg-actions">
                <button className="stg-btn-reset" onClick={handleReset} disabled={loading || !logoUrl}>
                  <RotateCcw size={13}/> Reset to Default
                </button>
                <button className="stg-btn-save" onClick={handleUpload} disabled={loading || !file}>
                  {loading ? "Uploading..." : "Save Logo"}
                </button>
              </div>
            </div>
          )}

          {tab === "staff-permissions" && (
            <div className="stg-perm-section">
              <div className="stg-upload-hint" style={{marginBottom:14}}>
                Piliin kung anong mga module ang makikita ng bawat staff account. Kapag walang check, hindi lalabas sa portal nila ang feature na 'yon.
              </div>
              {staffLoading ? (
                <div style={{textAlign:"center",padding:"30px 0",color:"#aaa",fontSize:12}}>Loading staff accounts...</div>
              ) : staffList.length === 0 ? (
                <div style={{textAlign:"center",padding:"30px 0",color:"#aaa",fontSize:12}}>No staff accounts found.</div>
              ) : (
                <div className="stg-staff-list">
                  {staffList.map(s => {
                    const isOpen = expandedStaff === s.staff_id;
                    const perms  = localPerms[s.staff_id] || [];
                    const dirty  = JSON.stringify([...perms].sort()) !== JSON.stringify([...(s.features||[])].sort());
                    // ── BAGO: "(default)" indicator — para malinaw sa
                    // admin kung ito pa rin ang sensible na panimulang
                    // set (base sa role) at hindi pa sila mismo
                    // nag-customize. ─────────────────────────────────
                    const roleDefaults = DEFAULT_FEATURES_BY_ROLE[s.staff_role] || [];
                    const isDefault = JSON.stringify([...perms].sort()) === JSON.stringify([...roleDefaults].sort());
                    return (
                      <div key={s.staff_id} className="stg-staff-card">
                        <button className="stg-staff-header" onClick={() => setExpanded(isOpen ? null : s.staff_id)}>
                          <div>
                            <div className="stg-staff-name">{s.staff_name}</div>
                            <div className="stg-staff-role">
                              {STAFF_ROLE_LABELS[s.staff_role] || s.staff_role || "Staff"} · {perms.length} feature{perms.length!==1?"s":""} enabled
                              {isDefault && <span style={{marginLeft:6,color:"#888",fontStyle:"italic"}}>(default)</span>}
                            </div>
                          </div>
                          <span className="stg-staff-chevron">{isOpen ? "▲" : "▼"}</span>
                        </button>
                        {isOpen && (
                          <div className="stg-staff-body">
                            <div className="stg-feature-grid">
                              {features.map(f => (
                                <label key={f.key} className="stg-feature-check">
                                  <input type="checkbox" checked={perms.includes(f.key)} onChange={() => toggleFeature(s.staff_id, f.key)}/>
                                  <span>{f.label}</span>
                                </label>
                              ))}
                            </div>
                            <button className="stg-btn-save" style={{marginTop:12, width:"100%"}}
                              disabled={!dirty || savingStaff === s.staff_id}
                              onClick={() => handleSavePermissions(s.staff_id)}>
                              {savingStaff === s.staff_id ? "Saving..." : dirty ? "Save Changes" : <><Check size={13}/> Saved</>}
                            </button>
                          </div>
                        )}
                      </div>
                    );
                  })}
                </div>
              )}
            </div>
          )}

          {/* ── BAGO: GCash Payment tab — dating iisang number/name lang,
              ngayon puwede nang magdagdag ng ILAN pang account, para
              maiwasan ang limit ng isang account lang. ─────────────── */}
          {tab === "gcash" && (
            <div className="stg-logo-section">
              <div className="stg-upload-hint" style={{marginBottom:14, display:"flex", alignItems:"center", gap:8}}>
                <Smartphone size={15} color="#2e7d32"/>
                Ang mga aktibong account sa ibaba ay ipapakita bilang mga choices sa member sa "Pay via GCash" modal. Puwede kang magdagdag ng ilan pa para maiwasan ang limit ng isang account lang.
              </div>

              {gcashError   && <div className="stg-error-banner">{gcashError}</div>}
              {gcashSuccess && <div className="stg-success-banner">{gcashSuccess}</div>}

              {gcashLoading ? (
                <div style={{textAlign:"center",padding:"30px 0",color:"#aaa",fontSize:12}}>Loading GCash accounts...</div>
              ) : (
                <>
                  <div style={{display:"flex",flexDirection:"column",gap:10,marginBottom:14}}>
                    {gcashAccounts.map(acc => (
                      <div key={acc.id} style={{border:"1.5px solid "+(acc.is_active?"#c8e6c9":"#eee"),borderRadius:10,padding:"12px 14px",background:acc.is_active?"#f9fef9":"#fafafa"}}>
                        {editingId === acc.id ? (
                          <div style={{display:"flex",flexDirection:"column",gap:8}}>
                            <input type="text" value={editForm.label} onChange={e=>setEditForm(f=>({...f,label:e.target.value}))} placeholder="Label (e.g. Primary)" style={{padding:"8px 10px",fontSize:12,border:"1.5px solid #e0e0e0",borderRadius:8,outline:"none",fontFamily:"inherit"}}/>
                            <input type="text" value={editForm.number} onChange={e=>setEditForm(f=>({...f,number:e.target.value}))} placeholder="GCash Number" style={{padding:"8px 10px",fontSize:13,fontFamily:"monospace",fontWeight:700,border:"1.5px solid #e0e0e0",borderRadius:8,outline:"none"}}/>
                            <input type="text" value={editForm.account_name} onChange={e=>setEditForm(f=>({...f,account_name:e.target.value}))} placeholder="Account Name" style={{padding:"8px 10px",fontSize:12,border:"1.5px solid #e0e0e0",borderRadius:8,outline:"none",fontFamily:"inherit"}}/>
                            <div style={{display:"flex",gap:8,justifyContent:"flex-end"}}>
                              <button onClick={()=>setEditingId(null)} style={{padding:"6px 12px",fontSize:11.5,fontWeight:600,border:"1.5px solid #ddd",borderRadius:8,background:"#fff",cursor:"pointer"}}>Cancel</button>
                              <button onClick={()=>handleSaveEdit(acc.id)} disabled={gcashSaving} style={{padding:"6px 12px",fontSize:11.5,fontWeight:700,border:"none",borderRadius:8,background:"#2e7d32",color:"#fff",cursor:"pointer"}}>Save</button>
                            </div>
                          </div>
                        ) : (
                          <div style={{display:"flex",alignItems:"center",justifyContent:"space-between",gap:10,flexWrap:"wrap"}}>
                            <div>
                              <div style={{display:"flex",alignItems:"center",gap:8}}>
                                {acc.label && <span style={{fontSize:9.5,fontWeight:700,color:"#2e7d32",background:"#e8f5e9",borderRadius:20,padding:"1px 8px"}}>{acc.label}</span>}
                                {!acc.is_active && <span style={{fontSize:9.5,fontWeight:700,color:"#888",background:"#eee",borderRadius:20,padding:"1px 8px"}}>Inactive</span>}
                              </div>
                              <div style={{fontSize:14,fontFamily:"monospace",fontWeight:700,marginTop:4}}>{acc.number}</div>
                              <div style={{fontSize:11.5,color:"#666"}}>{acc.account_name}</div>
                            </div>
                            <div style={{display:"flex",alignItems:"center",gap:6}}>
                              <label style={{display:"flex",alignItems:"center",gap:5,fontSize:10.5,color:"#666",cursor:"pointer"}}>
                                <input type="checkbox" checked={acc.is_active} onChange={()=>handleToggleActive(acc)}/> Active
                              </label>
                              <button onClick={()=>startEdit(acc)} title="Edit" style={{padding:6,border:"1.5px solid #e0e0e0",borderRadius:8,background:"#fff",cursor:"pointer",display:"flex"}}><Pencil size={13} color="#555"/></button>
                              <button onClick={()=>handleDeleteAccount(acc.id)} title="Delete" style={{padding:6,border:"1.5px solid #ef9a9a",borderRadius:8,background:"#fff",cursor:"pointer",display:"flex"}}><Trash2 size={13} color="#c62828"/></button>
                            </div>
                          </div>
                        )}
                      </div>
                    ))}
                  </div>

                  {showAddForm ? (
                    <div style={{border:"1.5px dashed #a5d6a7",borderRadius:10,padding:14,background:"#f9fef9"}}>
                      <div className="stg-field-label">Label (optional)</div>
                      <input type="text" value={addForm.label} onChange={e=>setAddForm(f=>({...f,label:e.target.value}))} placeholder="e.g. Backup" style={{width:"100%",boxSizing:"border-box",marginTop:6,marginBottom:10,padding:"9px 12px",fontSize:12,border:"1.5px solid #e0e0e0",borderRadius:8,outline:"none",fontFamily:"inherit"}}/>
                      <div className="stg-field-label">GCash Number</div>
                      <input type="text" value={addForm.number} onChange={e=>setAddForm(f=>({...f,number:e.target.value}))} placeholder="e.g. 0967-006-3500" style={{width:"100%",boxSizing:"border-box",marginTop:6,marginBottom:10,padding:"9px 12px",fontSize:13,fontFamily:"monospace",fontWeight:700,border:"1.5px solid #e0e0e0",borderRadius:8,outline:"none"}}/>
                      <div className="stg-field-label">Account Name</div>
                      <input type="text" value={addForm.account_name} onChange={e=>setAddForm(f=>({...f,account_name:e.target.value}))} placeholder="e.g. LEAF MPC" style={{width:"100%",boxSizing:"border-box",marginTop:6,padding:"9px 12px",fontSize:12,border:"1.5px solid #e0e0e0",borderRadius:8,outline:"none",fontFamily:"inherit"}}/>
                      <div style={{display:"flex",gap:8,justifyContent:"flex-end",marginTop:12}}>
                        <button onClick={()=>{setShowAddForm(false);setAddForm({label:"",number:"",account_name:""});}} style={{padding:"8px 14px",fontSize:12,fontWeight:600,border:"1.5px solid #ddd",borderRadius:8,background:"#fff",cursor:"pointer"}}>Cancel</button>
                        <button onClick={handleAddAccount} disabled={gcashSaving} style={{padding:"8px 16px",fontSize:12,fontWeight:700,border:"none",borderRadius:8,background:"#2e7d32",color:"#fff",cursor:"pointer"}}>{gcashSaving?"Adding...":"Add Account"}</button>
                      </div>
                    </div>
                  ) : (
                    <button onClick={()=>setShowAddForm(true)} style={{width:"100%",display:"flex",alignItems:"center",justifyContent:"center",gap:6,padding:"11px",fontSize:12.5,fontWeight:700,color:"#2e7d32",border:"1.5px dashed #a5d6a7",borderRadius:10,background:"#f9fef9",cursor:"pointer"}}>
                      <Plus size={14}/> Add Another GCash Account
                    </button>
                  )}
                </>
              )}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}