import { useState, useEffect } from "react";
import { getStaffListAPI, addStaffAPI, editStaffAPI, resetStaffPasswordAPI, deleteStaffAPI } from "../../api/auth";
import { Pencil, KeyRound, Eye, EyeOff, UserPlus, Trash2 } from "lucide-react";
import "./ManageStaff.css";

// ── FIX: nawawala dati ang "Bookkeeper" dito — meron naman itong
// default features ('reports') at label sa buong system, pero hindi
// ito puwedeng piliin kapag gumagawa ng bagong staff account. ───────
const STAFF_ROLE_OPTIONS = [
  { value: "cashier",     label: "Cashier"               },
  { value: "collector",   label: "Collector"             },
  { value: "bookkeeper",  label: "Bookkeeper"            },
  { value: "admin_clerk", label: "Administrative Clerk"  },
];

const STAFF_ROLE_LABELS = {
  cashier:     "Cashier",
  collector:   "Collector",
  bookkeeper:  "Bookkeeper",
  admin_clerk: "Administrative Clerk",
};

// ─── Add Staff Modal ──────────────────────────────────────────────────────────
function AddStaffModal({ onClose, onSuccess }) {
  const [form,    setForm]    = useState({ name: "", username: "", password: "", confirm: "", staff_role: "" });
  const [errors,  setErrors]  = useState({});
  const [showPw,  setShowPw]  = useState(false);
  const [done,    setDone]    = useState(null);
  const [loading, setLoading] = useState(false);

  const handle = e => {
    setForm(p => ({ ...p, [e.target.name]: e.target.value }));
    setErrors(p => ({ ...p, [e.target.name]: "" }));
  };

  const validate = () => {
    const e = {};
    if (!form.name.trim())        e.name       = "Name is required.";
    if (!form.username.trim())    e.username   = "Username is required.";
    if (form.username.length < 4) e.username   = "Minimum 4 characters.";
    if (!form.staff_role)         e.staff_role = "Please select a role.";
    if (!form.password)           e.password   = "Password is required.";
    if (form.password.length < 6) e.password   = "Minimum 6 characters.";
    if (form.password !== form.confirm) e.confirm = "Passwords do not match.";
    return e;
  };

  const handleSubmit = async () => {
    const e = validate();
    if (Object.keys(e).length) { setErrors(e); return; }
    setLoading(true);
    try {
      const staff = await addStaffAPI({
        name:       form.name,
        username:   form.username,
        password:   form.password,
        staff_role: form.staff_role,
      });
      setDone(staff);
      onSuccess?.();
    } catch (err) {
      const msg = err.response?.data?.username?.[0] || err.response?.data?.detail || "Username already exists.";
      setErrors({ username: msg });
    } finally {
      setLoading(false);
    }
  };

  if (done) return (
    <div className="ms-overlay" onClick={onClose}>
      <div className="ms-modal ms-modal-sm" onClick={e => e.stopPropagation()}>
        <div className="ms-modal-body" style={{ alignItems:"center", textAlign:"center", padding:"32px 24px", gap:12 }}>
          <div style={{ fontSize:40 }}>✅</div>
          <div style={{ fontSize:15, fontWeight:700, color:"#1b5e20" }}>Staff Account Created!</div>
          <div style={{ fontSize:12, color:"#555", lineHeight:1.6 }}>
            <strong>{done.name}</strong> can now log in using the credentials below.
          </div>
          <div className="ms-cred-box">
            <div className="ms-cred-row"><span className="ms-cred-label">Name</span><span className="ms-cred-val">{done.name}</span></div>
            <div className="ms-cred-row"><span className="ms-cred-label">Username</span><span className="ms-cred-val">{done.username}</span></div>
            <div className="ms-cred-row"><span className="ms-cred-label">Role</span><span className="ms-cred-val">{STAFF_ROLE_LABELS[done.staff_role] ?? done.staff_role}</span></div>
            <div className="ms-cred-row"><span className="ms-cred-label">Password</span><span className="ms-cred-val">{form.password}</span></div>
          </div>
          <div style={{ fontSize:11, color:"#aaa" }}>Give these credentials to the staff member.</div>
        </div>
        <div className="ms-modal-footer">
          <button className="ms-btn-save" onClick={onClose}>Done</button>
        </div>
      </div>
    </div>
  );

  return (
    <div className="ms-overlay" onClick={onClose}>
      <div className="ms-modal" onClick={e => e.stopPropagation()}>
        <div className="ms-modal-header">
          <div>
            <div className="ms-modal-title">Add New Staff</div>
            <div className="ms-modal-sub">Create a staff account for office personnel</div>
          </div>
          <button className="ms-modal-close" onClick={onClose}>✕</button>
        </div>
        <div className="ms-modal-body">
          <div className="ms-field">
            <label className="ms-label">Full Name <span className="ms-req">*</span></label>
            <input className={`ms-input ${errors.name?"ms-input-err":""}`} type="text" name="name" value={form.name} onChange={handle} placeholder="e.g. Juan Dela Cruz" autoFocus />
            {errors.name && <div className="ms-field-err">{errors.name}</div>}
          </div>
          <div className="ms-field">
            <label className="ms-label">Username <span className="ms-req">*</span></label>
            <input className={`ms-input ${errors.username?"ms-input-err":""}`} type="text" name="username" value={form.username} onChange={handle} placeholder="e.g. juan123" />
            {errors.username && <div className="ms-field-err">{errors.username}</div>}
          </div>
          <div className="ms-field">
            <label className="ms-label">Staff Role <span className="ms-req">*</span></label>
            <select
              className={`ms-input ${errors.staff_role ? "ms-input-err" : ""}`}
              name="staff_role"
              value={form.staff_role}
              onChange={handle}
            >
              <option value="">— Select a role —</option>
              {STAFF_ROLE_OPTIONS.map(o => (
                <option key={o.value} value={o.value}>{o.label}</option>
              ))}
            </select>
            {errors.staff_role && <div className="ms-field-err">{errors.staff_role}</div>}
          </div>
          <div className="ms-field">
            <label className="ms-label">Password <span className="ms-req">*</span></label>
            <div className="ms-pw-wrap">
              <input className={`ms-input ${errors.password?"ms-input-err":""}`} type={showPw?"text":"password"} name="password" value={form.password} onChange={handle} placeholder="At least 6 characters" />
              <button className="ms-pw-toggle" onClick={() => setShowPw(p=>!p)} type="button" tabIndex={-1}>{showPw ? <EyeOff size={14}/> : <Eye size={14}/>}</button>
            </div>
            {errors.password && <div className="ms-field-err">{errors.password}</div>}
          </div>
          <div className="ms-field">
            <label className="ms-label">Confirm Password <span className="ms-req">*</span></label>
            <input className={`ms-input ${errors.confirm?"ms-input-err":""}`} type={showPw?"text":"password"} name="confirm" value={form.confirm} onChange={handle} placeholder="Re-enter password" />
            {errors.confirm && <div className="ms-field-err">{errors.confirm}</div>}
          </div>
        </div>
        <div className="ms-modal-footer">
          <button className="ms-btn-cancel" onClick={onClose}>Cancel</button>
          <button className="ms-btn-save" onClick={handleSubmit} disabled={loading}>
            {loading ? "Creating..." : "Create Staff Account"}
          </button>
        </div>
      </div>
    </div>
  );
}

// ─── Edit Staff Modal ─────────────────────────────────────────────────────────
function EditStaffModal({ staff, onClose, onSuccess }) {
  const [form,    setForm]    = useState({ name: staff.name, username: staff.username, staff_role: staff.staff_role ?? "" });
  const [errors,  setErrors]  = useState({});
  const [done,    setDone]    = useState(false);
  const [loading, setLoading] = useState(false);

  const handle = e => {
    setForm(p => ({ ...p, [e.target.name]: e.target.value }));
    setErrors(p => ({ ...p, [e.target.name]: "" }));
  };

  const handleSubmit = async () => {
    const e = {};
    if (!form.name.trim())     e.name       = "Name is required.";
    if (!form.username.trim()) e.username   = "Username is required.";
    if (!form.staff_role)      e.staff_role = "Please select a role.";
    if (Object.keys(e).length) { setErrors(e); return; }
    setLoading(true);
    try {
      await editStaffAPI(staff.id, { name: form.name, username: form.username, staff_role: form.staff_role });
      setDone(true);
      onSuccess?.();
    } catch (err) {
      const msg = err.response?.data?.username?.[0] || "Username already taken.";
      setErrors({ username: msg });
    } finally {
      setLoading(false);
    }
  };

  if (done) return (
    <div className="ms-overlay" onClick={onClose}>
      <div className="ms-modal ms-modal-sm" onClick={e => e.stopPropagation()}>
        <div className="ms-modal-body" style={{ alignItems:"center", textAlign:"center", padding:"32px 24px", gap:12 }}>
          <div style={{ fontSize:40 }}>✅</div>
          <div style={{ fontSize:15, fontWeight:700, color:"#1b5e20" }}>Staff Updated!</div>
          <div style={{ fontSize:12, color:"#888" }}>Staff account has been successfully updated.</div>
        </div>
        <div className="ms-modal-footer"><button className="ms-btn-save" onClick={onClose}>Done</button></div>
      </div>
    </div>
  );

  return (
    <div className="ms-overlay" onClick={onClose}>
      <div className="ms-modal" onClick={e => e.stopPropagation()}>
        <div className="ms-modal-header">
          <div>
            <div className="ms-modal-title">Edit Staff Account</div>
            <div className="ms-modal-sub">Update staff name, username and role</div>
          </div>
          <button className="ms-modal-close" onClick={onClose}>✕</button>
        </div>
        <div className="ms-modal-body">
          <div className="ms-field">
            <label className="ms-label">Full Name <span className="ms-req">*</span></label>
            <input className={`ms-input ${errors.name?"ms-input-err":""}`} type="text" name="name" value={form.name} onChange={handle} autoFocus />
            {errors.name && <div className="ms-field-err">{errors.name}</div>}
          </div>
          <div className="ms-field">
            <label className="ms-label">Username <span className="ms-req">*</span></label>
            <input className={`ms-input ${errors.username?"ms-input-err":""}`} type="text" name="username" value={form.username} onChange={handle} />
            {errors.username && <div className="ms-field-err">{errors.username}</div>}
          </div>
          <div className="ms-field">
            <label className="ms-label">Staff Role <span className="ms-req">*</span></label>
            <select
              className={`ms-input ${errors.staff_role ? "ms-input-err" : ""}`}
              name="staff_role"
              value={form.staff_role}
              onChange={handle}
            >
              <option value="">— Select a role —</option>
              {STAFF_ROLE_OPTIONS.map(o => (
                <option key={o.value} value={o.value}>{o.label}</option>
              ))}
            </select>
            {errors.staff_role && <div className="ms-field-err">{errors.staff_role}</div>}
          </div>
        </div>
        <div className="ms-modal-footer">
          <button className="ms-btn-cancel" onClick={onClose}>Cancel</button>
          <button className="ms-btn-save" onClick={handleSubmit} disabled={loading}>
            {loading ? "Saving..." : "Save Changes"}
          </button>
        </div>
      </div>
    </div>
  );
}

// ─── Reset Password Modal ─────────────────────────────────────────────────────
function ResetPasswordModal({ staff, onClose }) {
  const [form,    setForm]    = useState({ password: "", confirm: "" });
  const [errors,  setErrors]  = useState({});
  const [showPw,  setShowPw]  = useState(false);
  const [done,    setDone]    = useState(false);
  const [loading, setLoading] = useState(false);

  const handle = e => {
    setForm(p => ({ ...p, [e.target.name]: e.target.value }));
    setErrors(p => ({ ...p, [e.target.name]: "" }));
  };

  const handleSubmit = async () => {
    const e = {};
    if (!form.password)           e.password = "New password is required.";
    if (form.password.length < 6) e.password = "Minimum 6 characters.";
    if (form.password !== form.confirm) e.confirm = "Passwords do not match.";
    if (Object.keys(e).length) { setErrors(e); return; }
    setLoading(true);
    try {
      await resetStaffPasswordAPI(staff.id, form.password);
      setDone(true);
    } catch {
      setErrors({ password: "Failed to reset password. Please try again." });
    } finally {
      setLoading(false);
    }
  };

  if (done) return (
    <div className="ms-overlay" onClick={onClose}>
      <div className="ms-modal ms-modal-sm" onClick={e => e.stopPropagation()}>
        <div className="ms-modal-body" style={{ alignItems:"center", textAlign:"center", padding:"32px 24px", gap:12 }}>
          <div style={{ fontSize:40 }}>🔑</div>
          <div style={{ fontSize:15, fontWeight:700, color:"#1b5e20" }}>Password Reset!</div>
          <div style={{ fontSize:12, color:"#555", lineHeight:1.6 }}>
            New password for <strong>{staff.name}</strong> has been set.
          </div>
          <div className="ms-cred-box">
            <div className="ms-cred-row"><span className="ms-cred-label">Username</span><span className="ms-cred-val">{staff.username}</span></div>
            <div className="ms-cred-row"><span className="ms-cred-label">New Password</span><span className="ms-cred-val">{form.password}</span></div>
          </div>
        </div>
        <div className="ms-modal-footer"><button className="ms-btn-save" onClick={onClose}>Done</button></div>
      </div>
    </div>
  );

  return (
    <div className="ms-overlay" onClick={onClose}>
      <div className="ms-modal" onClick={e => e.stopPropagation()}>
        <div className="ms-modal-header">
          <div>
            <div className="ms-modal-title">Reset Password</div>
            <div className="ms-modal-sub">Set a new password for {staff.name}</div>
          </div>
          <button className="ms-modal-close" onClick={onClose}>✕</button>
        </div>
        <div className="ms-modal-body">
          <div className="ms-staff-strip">
            <div className="ms-staff-avatar">{staff.name?.[0]?.toUpperCase() || "S"}</div>
            <div>
              <div className="ms-staff-name">{staff.name}</div>
              <div className="ms-staff-meta">@{staff.username} · {STAFF_ROLE_LABELS[staff.staff_role] ?? "Staff"}</div>
            </div>
          </div>
          <div className="ms-field">
            <label className="ms-label">New Password <span className="ms-req">*</span></label>
            <div className="ms-pw-wrap">
              <input className={`ms-input ${errors.password?"ms-input-err":""}`} type={showPw?"text":"password"} name="password" value={form.password} onChange={handle} placeholder="At least 6 characters" autoFocus />
              <button className="ms-pw-toggle" onClick={() => setShowPw(p=>!p)} type="button" tabIndex={-1}>{showPw ? <EyeOff size={14}/> : <Eye size={14}/>}</button>
            </div>
            {errors.password && <div className="ms-field-err">{errors.password}</div>}
          </div>
          <div className="ms-field">
            <label className="ms-label">Confirm New Password <span className="ms-req">*</span></label>
            <input className={`ms-input ${errors.confirm?"ms-input-err":""}`} type={showPw?"text":"password"} name="confirm" value={form.confirm} onChange={handle} placeholder="Re-enter new password" />
            {errors.confirm && <div className="ms-field-err">{errors.confirm}</div>}
          </div>
        </div>
        <div className="ms-modal-footer">
          <button className="ms-btn-cancel" onClick={onClose}>Cancel</button>
          <button className="ms-btn-save" onClick={handleSubmit} disabled={loading}>
            {loading ? "Resetting..." : "Reset Password"}
          </button>
        </div>
      </div>
    </div>
  );
}

// ─── Delete Confirm Modal ─────────────────────────────────────────────────────
function DeleteStaffModal({ staff, onClose, onConfirm }) {
  const [loading, setLoading] = useState(false);
  if (!staff) return null;

  const handleConfirm = async () => {
    setLoading(true);
    await onConfirm(staff.id);
    setLoading(false);
  };

  return (
    <div className="ms-overlay" onClick={onClose}>
      <div className="ms-modal ms-modal-sm" onClick={e => e.stopPropagation()}>
        <div className="ms-modal-header">
          <div className="ms-modal-title" style={{color:"#c62828"}}>Delete Staff Account</div>
          <button className="ms-modal-close" onClick={onClose}>✕</button>
        </div>
        <div className="ms-modal-body" style={{alignItems:"center",textAlign:"center",padding:"24px",gap:12}}>
          <div style={{fontSize:40}}>⚠️</div>
          <div style={{fontSize:14,fontWeight:700,color:"#333"}}>
            Are you sure you want to delete this staff account?
          </div>
          <div className="ms-cred-box" style={{textAlign:"left"}}>
            <div className="ms-cred-row"><span className="ms-cred-label">Name</span><span className="ms-cred-val">{staff.name}</span></div>
            <div className="ms-cred-row"><span className="ms-cred-label">Username</span><span className="ms-cred-val">@{staff.username}</span></div>
            <div className="ms-cred-row"><span className="ms-cred-label">Role</span><span className="ms-cred-val">{STAFF_ROLE_LABELS[staff.staff_role] ?? "—"}</span></div>
          </div>
          <div style={{fontSize:12,color:"#e53935",background:"#fce4ec",padding:"8px 12px",borderRadius:8}}>
            This action cannot be undone.
          </div>
        </div>
        <div className="ms-modal-footer">
          <button className="ms-btn-cancel" onClick={onClose}>Cancel</button>
          <button
            onClick={handleConfirm}
            disabled={loading}
            style={{background:"#c62828",color:"#fff",border:"none",borderRadius:8,padding:"8px 20px",fontWeight:700,cursor:"pointer",fontSize:13}}
          >
            {loading ? "Deleting..." : "Yes, Delete"}
          </button>
        </div>
      </div>
    </div>
  );
}

// ─── Main ManageStaff Page ────────────────────────────────────────────────────
export default function ManageStaff() {
  const [staffList,    setStaffList]   = useState([]);
  const [loading,      setLoading]     = useState(true);
  const [showAdd,      setShowAdd]     = useState(false);
  const [editTarget,   setEditTarget]  = useState(null);
  const [resetTarget,  setResetTarget] = useState(null);
  const [deleteTarget, setDeleteTarget]= useState(null);
  const [toast,        setToast]       = useState(null);

  const showToast = (msg, type="success") => {
    setToast({msg, type});
    setTimeout(() => setToast(null), 3000);
  };

  const fetchStaff = async () => {
    setLoading(true);
    try {
      const data = await getStaffListAPI();
      setStaffList(data);
    } catch (err) {
      console.error("Failed to fetch staff:", err);
    } finally {
      setLoading(false);
    }
  };

  const handleDelete = async (id) => {
    try {
      await deleteStaffAPI(id);
      setDeleteTarget(null);
      showToast("Staff account deleted.", "danger");
      fetchStaff();
    } catch {
      showToast("Failed to delete staff.", "danger");
    }
  };

  useEffect(() => { fetchStaff(); }, []);

  return (
    <div className="ms-wrap">

      {toast && (
        <div style={{
          position:"fixed", top:20, right:20, zIndex:9999,
          background: toast.type==="danger" ? "#c62828" : "#2e7d32",
          color:"#fff", padding:"10px 20px", borderRadius:8,
          fontSize:13, fontWeight:600, boxShadow:"0 4px 12px rgba(0,0,0,0.2)"
        }}>{toast.msg}</div>
      )}

      {showAdd      && <AddStaffModal    onClose={() => setShowAdd(false)}        onSuccess={fetchStaff} />}
      {editTarget   && <EditStaffModal   staff={editTarget}   onClose={() => setEditTarget(null)}   onSuccess={fetchStaff} />}
      {resetTarget  && <ResetPasswordModal staff={resetTarget} onClose={() => setResetTarget(null)} />}
      {deleteTarget && <DeleteStaffModal  staff={deleteTarget} onClose={() => setDeleteTarget(null)} onConfirm={handleDelete} />}

      {/* Header */}
      <div className="ms-header">
        <div>
          <div className="ms-title">Manage Staff</div>
          <div className="ms-sub">View, add, and manage staff accounts for office personnel.</div>
        </div>
        <button className="ms-add-btn" onClick={() => setShowAdd(true)}><UserPlus size={14}/> Add Staff</button>
      </div>

      {/* Stats */}
      <div className="ms-stats-row">
        <div className="ms-stat-card">
          <div className="ms-stat-val">{staffList.length}</div>
          <div className="ms-stat-label">Total Staff</div>
        </div>
        <div className="ms-stat-card">
          <div className="ms-stat-val" style={{ color:"#2e7d32" }}>{staffList.filter(s => s.is_active).length}</div>
          <div className="ms-stat-label">Active</div>
        </div>
      </div>

      {/* Table */}
      <div className="ms-table-card">
        {loading ? (
          <div className="ms-empty">
            <div className="ms-empty-text">Loading staff...</div>
          </div>
        ) : staffList.length === 0 ? (
          <div className="ms-empty">
            <div className="ms-empty-icon" style={{fontSize:36,opacity:0.3}}>👤</div>
            <div className="ms-empty-text">No staff accounts yet.</div>
            <button className="ms-add-btn" onClick={() => setShowAdd(true)}><UserPlus size={14}/> Add First Staff</button>
          </div>
        ) : (
          <table className="ms-table">
            <thead>
              <tr>
                <th>#</th>
                <th>Full Name</th>
                <th>Username</th>
                <th>Role</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {staffList.map((s, i) => (
                <tr key={s.id}>
                  <td className="ms-td-num">{i + 1}</td>
                  <td>
                    <div className="ms-name-cell">
                      <div className="ms-avatar">{s.name?.[0]?.toUpperCase() || "S"}</div>
                      <span>{s.name}</span>
                    </div>
                  </td>
                  <td className="ms-td-user">@{s.username}</td>
                  <td>
                    <span className="ms-role-badge">
                      {STAFF_ROLE_LABELS[s.staff_role] ?? "—"}
                    </span>
                  </td>
                  <td>
                    <div className="ms-action-row">
                      <button className="ms-action-btn edit"  onClick={() => setEditTarget(s)}><Pencil size={11}/> Edit</button>
                      <button className="ms-action-btn reset" onClick={() => setResetTarget(s)}><KeyRound size={11}/> Reset Password</button>
                      <button className="ms-action-btn delete" onClick={() => setDeleteTarget(s)} style={{background:"#fce4ec",color:"#c62828",border:"1px solid #ef9a9a"}}><Trash2 size={11}/> Delete</button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>

    </div>
  );
}