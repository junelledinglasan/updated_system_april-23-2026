import { useState, useRef, useEffect } from "react";
import { X, Upload, RotateCcw, Image as ImageIcon, Check, Smartphone } from "lucide-react";
import { uploadSystemLogoAPI, resetSystemLogoAPI, getAvailableFeaturesAPI, getStaffPermissionsListAPI, updateStaffPermissionsAPI, getGCashSettingsAPI, updateGCashSettingsAPI } from "../../api/settings";
import "./SettingsModal.css";

const STAFF_ROLE_LABELS = {
  cashier: "Cashier", collector: "Collector", bookkeeper: "Bookkeeper", admin_clerk: "Administrative Clerk",
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

  // ── BAGO: GCash Payment settings state ──────────────────────────────
  const [gcashLoading, setGcashLoading] = useState(true);
  const [gcashNumber,  setGcashNumber]  = useState("");
  const [gcashName,    setGcashName]    = useState("");
  const [gcashSaved,   setGcashSaved]   = useState({ gcash_number: "", gcash_name: "" });
  const [gcashSaving,  setGcashSaving]  = useState(false);
  const [gcashError,   setGcashError]   = useState("");
  const [gcashSuccess, setGcashSuccess] = useState("");

  const TABS = [
    { key: "logo", label: "🖼️ Logo" },
    { key: "staff-permissions", label: "🔐 Staff Permissions" },
    { key: "gcash", label: "💳 GCash Payment" },
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

  // ── BAGO: kunin ang kasalukuyang GCash settings pagkabukas ng tab ──
  useEffect(() => {
    if (tab !== "gcash" || (gcashNumber && gcashSaved.gcash_number)) return;
    setGcashLoading(true);
    getGCashSettingsAPI()
      .then(data => {
        setGcashNumber(data.gcash_number || "");
        setGcashName(data.gcash_name || "");
        setGcashSaved(data);
      })
      .catch(() => setGcashError("Failed to load current GCash settings."))
      .finally(() => setGcashLoading(false));
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

  // ── BAGO: i-save ang bagong GCash number/account name ───────────────
  const handleSaveGCash = async () => {
    setGcashError("");
    setGcashSuccess("");
    if (!gcashNumber.trim()) { setGcashError("GCash number is required."); return; }
    if (!gcashName.trim())   { setGcashError("Account name is required."); return; }
    setGcashSaving(true);
    try {
      const res = await updateGCashSettingsAPI({ gcash_number: gcashNumber.trim(), gcash_name: gcashName.trim() });
      setGcashSaved(res);
      setGcashSuccess("GCash payment details updated! Members will see the new number right away.");
      setTimeout(() => setGcashSuccess(""), 3500);
    } catch (err) {
      setGcashError(err.response?.data?.error || "Failed to update GCash settings.");
    } finally {
      setGcashSaving(false);
    }
  };

  const gcashDirty = gcashNumber.trim() !== (gcashSaved.gcash_number || "") || gcashName.trim() !== (gcashSaved.gcash_name || "");

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
            <button key={t.key} className={`stg-tab ${tab === t.key ? "active" : ""}`} onClick={() => setTab(t.key)}>
              {t.label}
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
                  <button className="stg-remove-preview" onClick={() => { setFile(null); setPreview(null); }}>✕ Remove</button>
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
                    return (
                      <div key={s.staff_id} className="stg-staff-card">
                        <button className="stg-staff-header" onClick={() => setExpanded(isOpen ? null : s.staff_id)}>
                          <div>
                            <div className="stg-staff-name">{s.staff_name}</div>
                            <div className="stg-staff-role">{STAFF_ROLE_LABELS[s.staff_role] || s.staff_role || "Staff"} · {perms.length} feature{perms.length!==1?"s":""} enabled</div>
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

          {/* ── BAGO: GCash Payment tab — para ma-edit ng admin ang
              GCash number/account name na ipinapakita sa members. ─── */}
          {tab === "gcash" && (
            <div className="stg-logo-section">
              <div className="stg-upload-hint" style={{marginBottom:14, display:"flex", alignItems:"center", gap:8}}>
                <Smartphone size={15} color="#2e7d32"/>
                Ito ang numero at pangalan na makikita ng mga member sa "Pay via GCash" na modal kapag nagbabayad sila ng loan.
              </div>

              {gcashLoading ? (
                <div style={{textAlign:"center",padding:"30px 0",color:"#aaa",fontSize:12}}>Loading current settings...</div>
              ) : (
                <>
                  <div className="stg-field-label">GCash Number</div>
                  <input
                    type="text"
                    value={gcashNumber}
                    onChange={e => { setGcashNumber(e.target.value); setGcashError(""); }}
                    placeholder="e.g. 0967-006-3500"
                    style={{width:"100%",boxSizing:"border-box",marginTop:6,marginBottom:14,padding:"11px 14px",fontSize:14,fontFamily:"monospace",fontWeight:700,letterSpacing:1,border:"1.5px solid #e0e0e0",borderRadius:10,outline:"none"}}
                  />

                  <div className="stg-field-label">Account Name</div>
                  <input
                    type="text"
                    value={gcashName}
                    onChange={e => { setGcashName(e.target.value); setGcashError(""); }}
                    placeholder="e.g. LEAF MPC"
                    style={{width:"100%",boxSizing:"border-box",marginTop:6,padding:"11px 14px",fontSize:14,border:"1.5px solid #e0e0e0",borderRadius:10,outline:"none",fontFamily:"inherit"}}
                  />

                  {gcashError   && <div className="stg-error-banner">{gcashError}</div>}
                  {gcashSuccess && <div className="stg-success-banner">{gcashSuccess}</div>}

                  <div className="stg-actions">
                    <button className="stg-btn-save" style={{marginLeft:"auto"}}
                      disabled={!gcashDirty || gcashSaving}
                      onClick={handleSaveGCash}>
                      {gcashSaving ? "Saving..." : "Save GCash Details"}
                    </button>
                  </div>
                </>
              )}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}