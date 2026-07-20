import { useState, useEffect } from "react";
import { useAuth } from "../../context/AuthContext";
import { getMyProfileAPI, getMyApplicationAPI, getMyOnlineAppAPI, updateMemberAPI } from "../../api/members";
import api from "../../api/axiosInstance";
import "./MemberProfile.css";

function computeAge(birthDate) {
  if (!birthDate) return null;
  const today = new Date();
  const bd    = new Date(birthDate);
  let age = today.getFullYear() - bd.getFullYear();
  const m = today.getMonth() - bd.getMonth();
  if (m < 0 || (m === 0 && today.getDate() < bd.getDate())) age--;
  return age;
}

function InfoRow({ label, value, editing=false, name, form, onChange, type="text", full=false }) {
  return (
    <div className={`mp-info-item${full?" mp-full":""}`}>
      <span className="mp-info-key">{label}</span>
      {editing
        ? <input className="mp-edit-input" type={type} name={name} value={form[name]||""} onChange={onChange}/>
        : <span className="mp-info-val">{value||"—"}</span>
      }
    </div>
  );
}

export default function MemberProfile() {
  const { user } = useAuth();
  const [profile,     setProfile]    = useState(null);
  const [application, setApplication]= useState(null);
  const [isOfficial,  setIsOfficial] = useState(false);
  const [loading,     setLoading]    = useState(true);
  const [tab,         setTab]        = useState("info");
  const [editing,     setEditing]    = useState(false);
  const [form, setForm] = useState({ contact_number:"", email:"", address:"", occupation:"" });
  const [saved,       setSaved]      = useState(false);

  const [username,    setUsername]   = useState(user?.username || "");
  const [newUsername, setNewUsername]= useState("");
  const [unError,     setUnError]    = useState("");
  const [unSaved,     setUnSaved]    = useState(false);
  const [passForm,    setPassForm]   = useState({ current:"", newPass:"", confirm:"" });
  const [passError,   setPassError]  = useState("");
  const [passSaved,   setPassSaved]  = useState(false);
  const [showCurr,    setShowCurr]   = useState(false);
  const [showNew,     setShowNew]    = useState(false);
  const [showConf,    setShowConf]   = useState(false);

  useEffect(() => {
    const load = async () => {
      setLoading(true);
      try {
        const p = await getMyProfileAPI();
        setProfile(p);
        setIsOfficial(true);
        const pm = p.pre_member_info || {};
        setForm({
          contact_number: pm.contact_number || p.contact || "",
          email:          pm.email          || p.email   || "",
          address:        pm.address        || "",
          occupation:     pm.occupation     || "",
        });
      } catch {
        try {
          const app = await getMyOnlineAppAPI();
          setApplication(app);
        } catch {
          try {
            const app = await getMyApplicationAPI();
            setApplication(app);
          } catch {}
        }
      } finally { setLoading(false); }
    };
    load();
  }, []);

  const PROFILE = profile || {};
  const PM      = PROFILE.pre_member_info || {};

  const handle     = e => setForm(p => ({ ...p, [e.target.name]: e.target.value }));
  const handlePass = e => setPassForm(p => ({ ...p, [e.target.name]: e.target.value }));

  const handleSave = async () => {
    try {
      await updateMemberAPI(profile.id, {
        contact_number: form.contact_number,
        email:          form.email,
        address:        form.address,
        occupation:     form.occupation,
      });
      setProfile(p => ({ ...p, ...form }));
      setSaved(true); setEditing(false);
      setTimeout(() => setSaved(false), 2500);
    } catch(e) { console.error(e); }
  };

  const handleUsernameChange = async () => {
    if (!newUsername.trim())         { setUnError("Username cannot be empty."); return; }
    if (newUsername.trim().length<4) { setUnError("Username must be at least 4 characters."); return; }
    if (/\s/.test(newUsername))      { setUnError("Username cannot have spaces."); return; }
    try {
      await api.patch("/auth/me/update/", { username: newUsername.trim() });
      setUsername(newUsername.trim());
      setNewUsername(""); setUnError("");
      setUnSaved(true); setTimeout(() => setUnSaved(false), 2500);
    } catch(err) {
      setUnError(err.response?.data?.username?.[0] || "Failed to update username.");
    }
  };

  const handlePasswordChange = async () => {
    if (passForm.newPass.length < 6)          { setPassError("New password must be at least 6 characters."); return; }
    if (passForm.newPass !== passForm.confirm) { setPassError("Passwords do not match."); return; }
    try {
      await api.post("/auth/change-password/", { current_password: passForm.current, new_password: passForm.newPass });
      setPassForm({ current:"", newPass:"", confirm:"" });
      setPassError(""); setPassSaved(true);
      setTimeout(() => setPassSaved(false), 2500);
    } catch(err) {
      setPassError(err.response?.data?.detail || "Current password is incorrect.");
    }
  };

  if (loading) return (
    <div style={{display:"flex",alignItems:"center",justifyContent:"center",padding:"80px",color:"#aaa",fontSize:14}}>
      Loading profile...
    </div>
  );

  // ── Non-official member view ──────────────────────────────────────────────
  if (!isOfficial) {
    const appStatus = application?.application_status || null;
    return (
      <div className="mp-wrapper">
        {/* Header */}
        <div className="mp-header-card">
          <div className="mp-avatar-large">{(user?.name?.[0]||"M").toUpperCase()}</div>
          <div className="mp-header-info">
            <div className="mp-header-name">{user?.name || "Member"}</div>
            <div className="mp-header-id">@{user?.username || "—"}</div>
            <div className="mp-header-since" style={{color:"#f57c00",fontWeight:600,fontSize:12,marginTop:4}}>
              Pending Membership
            </div>
          </div>
        </div>

        {/* Application status */}
        <div className="mp-card">
          <div className="mp-card-title">Membership Application Status</div>
          {!appStatus ? (
            <div style={{padding:"32px 0",textAlign:"center",display:"flex",flexDirection:"column",alignItems:"center",gap:12}}>
              <div style={{width:64,height:64,background:"#e8f5e9",borderRadius:"50%",display:"flex",alignItems:"center",justifyContent:"center",fontSize:28}}>📋</div>
              <div style={{fontWeight:700,color:"#1b5e20",fontSize:15}}>No application submitted yet</div>
              <div style={{fontSize:13,color:"#888",maxWidth:320,lineHeight:1.6}}>Submit a membership application to become an official LEAF MPC member.</div>
              <a href="/member/apply-membership" style={{background:"#1b5e20",color:"#fff",borderRadius:10,padding:"11px 28px",fontWeight:700,fontSize:13,textDecoration:"none",marginTop:4}}>
                Apply for Membership
              </a>
            </div>
          ) : (
            <div style={{display:"flex",flexDirection:"column",gap:14}}>
              <div style={{
                display:"flex",alignItems:"flex-start",gap:14,padding:"16px",borderRadius:12,border:"1.5px solid",
                background:  appStatus==="Pending"?"#fff8e1":appStatus==="Approved"?"#e8f5e9":"#ffebee",
                borderColor: appStatus==="Pending"?"#ffe082":appStatus==="Approved"?"#a5d6a7":"#ef9a9a",
              }}>
                <div style={{fontSize:32,flexShrink:0}}>{appStatus==="Pending"?"⏳":appStatus==="Approved"?"✅":"❌"}</div>
                <div style={{flex:1}}>
                  <div style={{fontWeight:800,fontSize:15,color:appStatus==="Approved"?"#1b5e20":appStatus==="Rejected"?"#c62828":"#f57c00",marginBottom:4}}>
                    {appStatus==="Pending"?"Application Under Review":appStatus==="Approved"?"Application Approved!":"Application Rejected"}
                  </div>
                  <div style={{fontSize:12,color:"#888",marginBottom:8}}>
                    App ID: <strong>{application.app_id}</strong> · Submitted {application.created_at?.slice(0,10)}
                  </div>
                  {appStatus==="Pending"  && <div style={{fontSize:13,color:"#5d4037"}}>Please wait for the admin to review your application.</div>}
                  {appStatus==="Approved" && <div style={{fontSize:13,color:"#1b5e20"}}>Please visit the LEAF MPC office to complete the process. Bring your 2x2 ID picture, Birth Certificate, Valid ID, and ₱4,000 minimum share capital.</div>}
                  {appStatus==="Rejected" && application.reject_reason && <div style={{fontSize:13,color:"#c62828",fontStyle:"italic",marginTop:4}}>Reason: {application.reject_reason}</div>}
                </div>
              </div>
              <div style={{display:"flex",gap:10,flexWrap:"wrap"}}>
                <a href="/member/profile" style={{padding:"9px 20px",background:"#f5f5f5",color:"#555",borderRadius:8,fontWeight:600,fontSize:13,textDecoration:"none"}}>View Profile</a>
                {appStatus==="Rejected" && (
                  <a href="/member/apply-membership" style={{padding:"9px 20px",background:"#1b5e20",color:"#fff",borderRadius:8,fontWeight:700,fontSize:13,textDecoration:"none"}}>Re-apply for Membership</a>
                )}
              </div>
            </div>
          )}
        </div>

        {/* Personal info from application */}
        {application?.last_name && (
          <div className="mp-card">
            <div className="mp-card-title">Personal Information</div>
            <div className="mp-info-grid">
              {[
                ["Last Name",        application.last_name],
                ["First Name",       application.first_name],
                ["Middle Name",      application.middle_name],
                ["Birthdate",        application.birth_date],
                ["Civil Status",     application.civil_status],
                ["Classification",   application.classification],
                ["Educ. Attainment", application.educational_attainment],
                ["Occupation",       application.occupation],
                ["Contact No.",      application.contact_number],
                ["Email",            application.email],
              ].map(([k,v]) => (
                <div key={k} className="mp-info-item">
                  <span className="mp-info-key">{k}</span>
                  <span className="mp-info-val">{v||"—"}</span>
                </div>
              ))}
              <div className="mp-info-item mp-full">
                <span className="mp-info-key">Address</span>
                <span className="mp-info-val">{application.address||"—"}</span>
              </div>
              <div className="mp-info-item">
                <span className="mp-info-key">Username</span>
                <span className="mp-info-val">@{user?.username||"—"}</span>
              </div>
              <div className="mp-info-item">
                <span className="mp-info-key">Status</span>
                <span className="mp-info-val" style={{color:"#f57c00",fontWeight:600}}>Pending Official Membership</span>
              </div>
            </div>
          </div>
        )}
      </div>
    );
  }

  const age = computeAge(PM.birth_date);

  // ── Official member view ──────────────────────────────────────────────────
  return (
    <div className="mp-wrapper">
      {saved && <div className="mp-toast">Profile updated successfully!</div>}

      {/* ── Header Card ── */}
      <div className="mp-header-card">
        <div className="mp-avatar-large">
          {(PROFILE.first_name?.[0] || PM.first_name?.[0] || "M").toUpperCase()}
        </div>
        <div className="mp-header-info">
          <div className="mp-header-name">{PROFILE.fullname || `${PM.first_name||""} ${PM.last_name||""}`.trim()}</div>
          <div className="mp-header-id">{PROFILE.member_id || "—"}</div>
          <div className="mp-header-since">Member since {PROFILE.date_registered?.slice(0,10) || "—"}</div>
        </div>
        <div className="mp-header-stats">
          <div className="mp-stat-item">
            <span className="mp-stat-val">₱{parseFloat(PROFILE.share_capital||0).toLocaleString()}</span>
            <span className="mp-stat-label">Share Capital</span>
          </div>
          <div className="mp-stat-divider"/>
          <div className="mp-stat-item">
            <span className="mp-stat-val">₱{(parseFloat(PROFILE.share_capital||0)*2).toLocaleString()}</span>
            <span className="mp-stat-label">Max Loanable</span>
          </div>
          <div className="mp-stat-divider"/>
          <div className="mp-stat-item">
            <span className={`mp-status-badge ${(PROFILE.status||"active").toLowerCase()}`}>{PROFILE.status||"Active"}</span>
            <span className="mp-stat-label">Status</span>
          </div>
        </div>
      </div>

      {/* ── Tabs ── */}
      <div className="mp-tabs">
        {[["info","Personal Info"],["security","Account & Security"]].map(([k,l]) => (
          <button key={k} className={`mp-tab ${tab===k?"active":""}`} onClick={() => setTab(k)}>{l}</button>
        ))}
      </div>

      {/* ── Personal Info Tab ── */}
      {tab === "info" && (
        <div className="mp-card">
          <div className="mp-card-header">
            <div>
              <div className="mp-card-title">Personal Information</div>
              <div className="mp-card-sub" style={{fontSize:11,color:"#aaa",marginTop:2}}>
                Contact details, address, and occupation are editable.
              </div>
            </div>
            {!editing ? (
              <button className="mp-edit-btn" onClick={() => setEditing(true)}>Edit Profile</button>
            ) : (
              <div style={{display:"flex",gap:8}}>
                <button className="mp-cancel-btn" onClick={() => setEditing(false)}>Cancel</button>
                <button className="mp-save-btn" onClick={handleSave}>Save Changes</button>
              </div>
            )}
          </div>

          {/* Section: Basic Info */}
          <div className="mp-section-label">Basic Information</div>
          <div className="mp-info-grid">
            {[
              ["Last Name",        PROFILE.last_name  || PM.last_name  || "—"],
              ["First Name",       PROFILE.first_name || PM.first_name || "—"],
              ["Middle Name",      PM.middle_name     || "—"],
              ["Date of Birth",    PM.birth_date      || "—"],
              ["Age",              age !== null ? `${age} years old` : "—"],
              ["Sex",              PM.sex             || "—"],
              ["Civil Status",     PM.civil_status    || "—"],
              ["Place of Birth",   PM.place_of_birth  || "—"],
            ].map(([k,v]) => (
              <div key={k} className="mp-info-item">
                <span className="mp-info-key">{k}</span>
                <span className="mp-info-val">{v}</span>
              </div>
            ))}
          </div>

          {/* Section: Classification */}
          <div className="mp-section-label" style={{marginTop:20}}>Classification & Education</div>
          <div className="mp-info-grid">
            {[
              ["Classification",   PM.classification  || PROFILE.classification || "—"],
              ["Educ. Attainment", PM.educational_attainment || "—"],
              ["TIN No.",          PM.tin_no          || "—"],
              ["SSS/GSIS No.",     PM.sss_gsis_no     || "—"],
              ["Religious/Social", PM.religious_social_affiliation || "—"],
            ].map(([k,v]) => (
              <div key={k} className="mp-info-item">
                <span className="mp-info-key">{k}</span>
                <span className="mp-info-val">{v}</span>
              </div>
            ))}
          </div>

          {/* Section: Spouse & Family */}
          {(PM.spouse_name || PM.beneficiary_name) && (
            <>
              <div className="mp-section-label" style={{marginTop:20}}>Spouse & Family</div>
              <div className="mp-info-grid">
                {[
                  ["Spouse Name",          PM.spouse_name          || "—"],
                  ["Spouse Occupation",     PM.spouse_occupation    || "—"],
                  ["Spouse Income",         PM.spouse_income ? `₱${Number(PM.spouse_income).toLocaleString()}` : "—"],
                  ["No. of Dependants",     PM.no_of_dependants     || "—"],
                  ["Beneficiary",          PM.beneficiary_name     || "—"],
                  ["Relationship",          PM.beneficiary_relationship || "—"],
                ].map(([k,v]) => (
                  <div key={k} className="mp-info-item">
                    <span className="mp-info-key">{k}</span>
                    <span className="mp-info-val">{v}</span>
                  </div>
                ))}
              </div>
            </>
          )}

          {/* Section: Contact (Editable) */}
          <div className="mp-section-label" style={{marginTop:20}}>Contact & Address</div>
          <div className="mp-info-grid">
            <div className="mp-info-item">
              <span className="mp-info-key">Contact No.</span>
              {editing
                ? <input className="mp-edit-input" type="tel" name="contact_number" value={form.contact_number} onChange={handle}/>
                : <span className="mp-info-val">{form.contact_number || PM.contact_number || "—"}</span>
              }
            </div>
            <div className="mp-info-item">
              <span className="mp-info-key">Email</span>
              {editing
                ? <input className="mp-edit-input" type="email" name="email" value={form.email} onChange={handle}/>
                : <span className="mp-info-val">{form.email || PM.email || "—"}</span>
              }
            </div>
            <div className="mp-info-item">
              <span className="mp-info-key">Occupation</span>
              {editing
                ? <input className="mp-edit-input" name="occupation" value={form.occupation} onChange={handle}/>
                : <span className="mp-info-val">{form.occupation || PM.occupation || "—"}</span>
              }
            </div>
            <div className="mp-info-item mp-full">
              <span className="mp-info-key">Address</span>
              {editing
                ? <input className="mp-edit-input" name="address" value={form.address} onChange={handle}/>
                : <span className="mp-info-val">{form.address || PM.address || "—"}</span>
              }
            </div>
          </div>

          {/* Section: Documents */}
          <div className="mp-section-label" style={{marginTop:20}}>Documents Submitted</div>
          <div className="mp-info-grid">
            <div className="mp-info-item">
              <span className="mp-info-key">Birth Certificate</span>
              <span className="mp-info-val" style={{color:PM.birth_certificate?"#2e7d32":"#aaa",fontWeight:600}}>
                {PM.birth_certificate ? "Submitted" : "Not submitted"}
              </span>
            </div>
            <div className="mp-info-item">
              <span className="mp-info-key">Marriage Certificate</span>
              <span className="mp-info-val" style={{color:PM.marriage_certificate?"#2e7d32":"#aaa",fontWeight:600}}>
                {PM.marriage_certificate ? "Submitted" : "Not submitted / N/A"}
              </span>
            </div>
          </div>
        </div>
      )}

      {/* ── Security Tab ── */}
      {tab === "security" && (
        <div style={{display:"flex",flexDirection:"column",gap:16}}>
          {/* Hidden dummy inputs to prevent browser autofill */}
          <input type="text"     style={{display:"none"}} autoComplete="username"     readOnly/>
          <input type="password" style={{display:"none"}} autoComplete="new-password" readOnly/>

          {/* Account Info */}
          <div className="mp-card">
            <div className="mp-card-title">Account Information</div>
            <div className="mp-cred-info-card">
              <div className="mp-cred-row">
                <span className="mp-cred-label">Member ID</span>
                <span className="mp-cred-val">{PROFILE.member_id || "—"}</span>
              </div>
              <div className="mp-cred-row">
                <span className="mp-cred-label">Username</span>
                <span className="mp-cred-val">{username}</span>
              </div>
              <div className="mp-cred-row">
                <span className="mp-cred-label">Status</span>
                <span className="mp-cred-val" style={{color:"#69f0ae",fontWeight:700}}>Active</span>
              </div>
            </div>
          </div>

          {/* Change Username */}
          <div className="mp-card">
            <div className="mp-card-title">Change Username</div>
            <div className="mp-card-sub2">Current username: <strong>{username}</strong></div>
            {unSaved && <div className="mp-success-banner">Username changed successfully!</div>}
            <div className="mp-sec-form">
              <div className="mp-sec-field">
                <label className="mp-info-key">New Username</label>
                <input className={`mp-sec-input ${unError?"mp-sec-err":""}`} type="text"
                  placeholder="Enter new username (min. 4 characters)"
                  autoComplete="off"
                  value={newUsername} onChange={e => { setNewUsername(e.target.value); setUnError(""); }}/>
                {unError && <div className="mp-sec-error-msg">{unError}</div>}
              </div>
              <button className="mp-save-btn" onClick={handleUsernameChange}>Update Username</button>
            </div>
            <div className="mp-sec-hint">Your username is used to log in to the LEAF MPC member portal.</div>
          </div>

          {/* Change Password */}
          <div className="mp-card">
            <div className="mp-card-title">Change Password</div>
            <div className="mp-card-sub2">Keep your account secure with a strong password.</div>
            {passSaved && <div className="mp-success-banner">Password changed successfully!</div>}
            {passError && <div className="mp-sec-error-banner">{passError}</div>}
            <div className="mp-sec-form">
              <div className="mp-sec-field">
                <label className="mp-info-key">Current Password</label>
                <div className="mp-pass-wrap">
                  <input className="mp-sec-input" type={showCurr?"text":"password"} name="current"
                    placeholder="Enter current password" value={passForm.current}
                    autoComplete="current-password"
                    onChange={e => { handlePass(e); setPassError(""); }}/>
                  <button type="button" className="mp-eye" onClick={() => setShowCurr(s=>!s)}>
                    {showCurr?"🙈":"👁"}
                  </button>
                </div>
              </div>
              <div className="mp-sec-field">
                <label className="mp-info-key">New Password</label>
                <div className="mp-pass-wrap">
                  <input className="mp-sec-input" type={showNew?"text":"password"} name="newPass"
                    placeholder="New password (min. 6 characters)" value={passForm.newPass}
                    autoComplete="new-password"
                    onChange={e => { handlePass(e); setPassError(""); }}/>
                  <button type="button" className="mp-eye" onClick={() => setShowNew(s=>!s)}>
                    {showNew?"🙈":"👁"}
                  </button>
                </div>
                {passForm.newPass && (
                  <div className="mp-strength-row">
                    {["weak","fair","strong"].map((s,i) => (
                      <div key={s} className={`mp-strength-bar ${passForm.newPass.length >= [1,5,8][i] ? s : ""}`}/>
                    ))}
                    <span className="mp-strength-label">
                      {passForm.newPass.length < 5 ? "Weak" : passForm.newPass.length < 8 ? "Fair" : "Strong"}
                    </span>
                  </div>
                )}
              </div>
              <div className="mp-sec-field">
                <label className="mp-info-key">Confirm New Password</label>
                <div className="mp-pass-wrap">
                  <input className="mp-sec-input" type={showConf?"text":"password"} name="confirm"
                    placeholder="Re-enter new password" value={passForm.confirm}
                    autoComplete="new-password"
                    onChange={e => { handlePass(e); setPassError(""); }}/>
                  <button type="button" className="mp-eye" onClick={() => setShowConf(s=>!s)}>
                    {showConf?"🙈":"👁"}
                  </button>
                </div>
              </div>
              <button className="mp-save-btn" onClick={handlePasswordChange}>Update Password</button>
            </div>
            <div className="mp-sec-hint">Forgot your current password? Visit the LEAF MPC office for a password reset.</div>
          </div>
        </div>
      )}
    </div>
  );
}