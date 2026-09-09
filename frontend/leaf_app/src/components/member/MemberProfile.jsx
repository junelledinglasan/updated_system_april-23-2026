import { useState, useEffect } from "react";
import { useAuth } from "../../context/AuthContext";
import { getMyProfileAPI, getMyApplicationAPI, getMyOnlineAppAPI, updateMemberAPI } from "../../api/members";
import { useLanguage } from "../../context/LanguageContext";
import { getPageCache, savePageCache } from "../../utils/pageCache";
import api from "../../api/axiosInstance";
import { ClipboardList, Clock, CheckCircle, XCircle, Eye, EyeOff } from "lucide-react";
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

export default function MemberProfile() {
  const { user } = useAuth();
  const { t }     = useLanguage();
  // ── BAGO: cache-first — hindi tulad ng ibang pages, wala pa tayong
  // member.id sa oras na ito (kukunin pa lang mismo sa fetch). Gamit
  // na lang ang user.id/username mula sa AuthContext bilang scope key
  // — available na 'to agad sa mount, bago pa man mag-fetch. ────────
  const scopeKey = user?.id ?? user?.username ?? null;
  const cached = getPageCache("profile", scopeKey);
  const [profile,     setProfile]    = useState(cached?.profile || null);
  const [application, setApplication]= useState(cached?.application || null);
  const [isOfficial,  setIsOfficial] = useState(cached?.isOfficial || false);
  const [loading,     setLoading]    = useState(!cached);
  const [tab,         setTab]        = useState("info");
  const [editing,     setEditing]    = useState(false);
  const [form, setForm] = useState(cached?.form || { contact_number:"", email:"", address:"", occupation:"" });
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
      // ── Huwag pilitin ang "Loading..." kung may cache na tayong
      // ipinapakita — tahimik na lang mag-refresh sa likod. ─────────
      if (!getPageCache("profile", scopeKey)) setLoading(true);
      try {
        const p = await getMyProfileAPI();
        setProfile(p);
        setIsOfficial(true);
        const pm = p.pre_member_info || {};
        const newForm = {
          contact_number: pm.contact_number || p.contact || "",
          email:          pm.email          || p.email   || "",
          address:        pm.address        || "",
          occupation:     pm.occupation     || "",
        };
        setForm(newForm);
        savePageCache("profile", scopeKey, { profile: p, isOfficial: true, application: null, form: newForm });
      } catch {
        try {
          const app = await getMyOnlineAppAPI();
          setApplication(app);
          savePageCache("profile", scopeKey, { profile: null, isOfficial: false, application: app, form: null });
        } catch {
          try {
            const app = await getMyApplicationAPI();
            setApplication(app);
            savePageCache("profile", scopeKey, { profile: null, isOfficial: false, application: app, form: null });
          } catch {}
        }
      } finally { setLoading(false); }
    };
    load();
  }, [scopeKey]);

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
      const updatedProfile = { ...profile, ...form };
      setProfile(updatedProfile);
      savePageCache("profile", scopeKey, { profile: updatedProfile, isOfficial: true, application: null, form });
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
      {t("mp_loading")}
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
              {t("mp_pending_membership")}
            </div>
          </div>
        </div>

        {/* Application status */}
        <div className="mp-card">
          <div className="mp-card-title">{t("mp_application_status_title")}</div>
          {!appStatus ? (
            <div style={{padding:"32px 0",textAlign:"center",display:"flex",flexDirection:"column",alignItems:"center",gap:12}}>
              <div style={{width:64,height:64,background:"#e8f5e9",borderRadius:"50%",display:"flex",alignItems:"center",justifyContent:"center"}}><ClipboardList size={28} color="#2e7d32"/></div>
              <div style={{fontWeight:700,color:"#1b5e20",fontSize:15}}>{t("mp_no_application")}</div>
              <div style={{fontSize:13,color:"#888",maxWidth:320,lineHeight:1.6}}>{t("mp_no_application_sub")}</div>
              <a href="/member/apply-membership" style={{background:"#1b5e20",color:"#fff",borderRadius:10,padding:"11px 28px",fontWeight:700,fontSize:13,textDecoration:"none",marginTop:4}}>
                {t("mp_apply_membership")}
              </a>
            </div>
          ) : (
            <div style={{display:"flex",flexDirection:"column",gap:14}}>
              <div style={{
                display:"flex",alignItems:"flex-start",gap:14,padding:"16px",borderRadius:12,border:"1.5px solid",
                background:  appStatus==="Pending"?"#fff8e1":appStatus==="Approved"?"#e8f5e9":"#ffebee",
                borderColor: appStatus==="Pending"?"#ffe082":appStatus==="Approved"?"#a5d6a7":"#ef9a9a",
              }}>
                <div style={{flexShrink:0}}>
                  {appStatus==="Pending" ? <Clock size={30} color="#f57c00"/> : appStatus==="Approved" ? <CheckCircle size={30} color="#2e7d32"/> : <XCircle size={30} color="#c62828"/>}
                </div>
                <div style={{flex:1}}>
                  <div style={{fontWeight:800,fontSize:15,color:appStatus==="Approved"?"#1b5e20":appStatus==="Rejected"?"#c62828":"#f57c00",marginBottom:4}}>
                    {appStatus==="Pending"?t("mp_status_pending"):appStatus==="Approved"?t("mp_status_approved"):t("mp_status_rejected")}
                  </div>
                  <div style={{fontSize:12,color:"#888",marginBottom:8}}>
                    {t("mp_app_id_submitted", { id: application.app_id, date: application.created_at?.slice(0,10) })}
                  </div>
                  {appStatus==="Pending"  && <div style={{fontSize:13,color:"#5d4037"}}>{t("mp_pending_note")}</div>}
                  {appStatus==="Approved" && <div style={{fontSize:13,color:"#1b5e20"}}>{t("mp_approved_note")}</div>}
                  {appStatus==="Rejected" && application.reject_reason && <div style={{fontSize:13,color:"#c62828",fontStyle:"italic",marginTop:4}}>{t("mp_reject_reason")} {application.reject_reason}</div>}
                </div>
              </div>
              <div style={{display:"flex",gap:10,flexWrap:"wrap"}}>
                <a href="/member/profile" style={{padding:"9px 20px",background:"#f5f5f5",color:"#555",borderRadius:8,fontWeight:600,fontSize:13,textDecoration:"none"}}>{t("mp_view_profile")}</a>
                {appStatus==="Rejected" && (
                  <a href="/member/apply-membership" style={{padding:"9px 20px",background:"#1b5e20",color:"#fff",borderRadius:8,fontWeight:700,fontSize:13,textDecoration:"none"}}>{t("mp_reapply")}</a>
                )}
              </div>
            </div>
          )}
        </div>

        {/* Personal info from application */}
        {application?.last_name && (
          <div className="mp-card">
            <div className="mp-card-title">{t("mp_personal_info")}</div>
            <div className="mp-info-grid">
              {[
                [t("mp_last_name"),        application.last_name],
                [t("mp_first_name"),       application.first_name],
                [t("mp_middle_name"),      application.middle_name],
                [t("mp_birthdate"),        application.birth_date],
                [t("mp_civil_status"),     application.civil_status],
                [t("mp_classification"),   application.classification],
                [t("mp_educ_attainment"),  application.educational_attainment],
                [t("mp_occupation"),       application.occupation],
                [t("mp_contact_no"),       application.contact_number],
                [t("mp_email"),            application.email],
              ].map(([k,v]) => (
                <div key={k} className="mp-info-item">
                  <span className="mp-info-key">{k}</span>
                  <span className="mp-info-val">{v||"—"}</span>
                </div>
              ))}
              <div className="mp-info-item mp-full">
                <span className="mp-info-key">{t("mp_address")}</span>
                <span className="mp-info-val">{application.address||"—"}</span>
              </div>
              <div className="mp-info-item">
                <span className="mp-info-key">{t("mp_username")}</span>
                <span className="mp-info-val">@{user?.username||"—"}</span>
              </div>
              <div className="mp-info-item">
                <span className="mp-info-key">{t("mp_status")}</span>
                <span className="mp-info-val" style={{color:"#f57c00",fontWeight:600}}>{t("mp_pending_official")}</span>
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
      {saved && <div className="mp-toast">{t("mp_toast_updated")}</div>}

      {/* ── Header Card ── */}
      <div className="mp-header-card">
        <div className="mp-avatar-large">
          {(PROFILE.first_name?.[0] || PM.first_name?.[0] || "M").toUpperCase()}
        </div>
        <div className="mp-header-info">
          <div className="mp-header-name">{PROFILE.fullname || `${PM.first_name||""} ${PM.last_name||""}`.trim()}</div>
          <div className="mp-header-id">{PROFILE.member_id || "—"}</div>
          <div className="mp-header-since">{t("mp_member_since", { date: PROFILE.date_registered?.slice(0,10) || "—" })}</div>
        </div>
        <div className="mp-header-stats">
          <div className="mp-stat-item">
            <span className="mp-stat-val">₱{parseFloat(PROFILE.share_capital||0).toLocaleString()}</span>
            <span className="mp-stat-label">{t("mp_share_capital")}</span>
          </div>
          <div className="mp-stat-divider"/>
          <div className="mp-stat-item">
            {/* ── FIX: dating hardcoded "× 2" ito — hindi na tama
                mula nang idagdag ang Loan Multiplier feature (1x/2x/3x).
                Gamit na ngayon ang "max_loanable" mismo mula sa
                backend, na tama nang gumagalang sa multiplier ng
                member. ─────────────────────────────────────────────── */}
            <span className="mp-stat-val">₱{parseFloat(PROFILE.max_loanable||0).toLocaleString()}</span>
            <span className="mp-stat-label">{t("mp_max_loanable")}</span>
          </div>
          <div className="mp-stat-divider"/>
          <div className="mp-stat-item">
            <span className={`mp-status-badge ${(PROFILE.status||"active").toLowerCase()}`}>{PROFILE.status||"Active"}</span>
            <span className="mp-stat-label">{t("mp_status")}</span>
          </div>
        </div>
      </div>

      {/* ── Tabs ── */}
      <div className="mp-tabs">
        {[["info",t("mp_tab_info")],["security",t("mp_tab_security")]].map(([k,l]) => (
          <button key={k} className={`mp-tab ${tab===k?"active":""}`} onClick={() => setTab(k)}>{l}</button>
        ))}
      </div>

      {/* ── Personal Info Tab ── */}
      {tab === "info" && (
        <div className="mp-card">
          <div className="mp-card-header">
            <div>
              <div className="mp-card-title">{t("mp_personal_info")}</div>
              <div className="mp-card-sub" style={{fontSize:11,color:"#aaa",marginTop:2}}>
                {t("mp_card_sub_editable")}
              </div>
            </div>
            {!editing ? (
              <button className="mp-edit-btn" onClick={() => setEditing(true)}>{t("mp_edit_profile")}</button>
            ) : (
              <div style={{display:"flex",gap:8}}>
                <button className="mp-cancel-btn" onClick={() => setEditing(false)}>{t("mp_cancel")}</button>
                <button className="mp-save-btn" onClick={handleSave}>{t("mp_save_changes")}</button>
              </div>
            )}
          </div>

          {/* Section: Basic Info */}
          <div className="mp-section-label">{t("mp_basic_info")}</div>
          <div className="mp-info-grid">
            {[
              [t("mp_last_name"),        PROFILE.last_name  || PM.last_name  || "—"],
              [t("mp_first_name"),       PROFILE.first_name || PM.first_name || "—"],
              [t("mp_middle_name"),      PM.middle_name     || "—"],
              [t("mp_birthdate"),        PM.birth_date      || "—"],
              [t("mp_age"),              age !== null ? t("mp_years_old", { n: age }) : "—"],
              [t("mp_sex"),              PM.sex             || "—"],
              [t("mp_civil_status"),     PM.civil_status    || "—"],
              [t("mp_place_of_birth"),   PM.place_of_birth  || "—"],
            ].map(([k,v]) => (
              <div key={k} className="mp-info-item">
                <span className="mp-info-key">{k}</span>
                <span className="mp-info-val">{v}</span>
              </div>
            ))}
          </div>

          {/* Section: Classification */}
          <div className="mp-section-label" style={{marginTop:20}}>{t("mp_classification_education")}</div>
          <div className="mp-info-grid">
            {[
              [t("mp_classification"),   PM.classification  || PROFILE.classification || "—"],
              [t("mp_educ_attainment"),  PM.educational_attainment || "—"],
              [t("mp_tin_no"),           PM.tin_no          || "—"],
              [t("mp_sss_gsis"),         PM.sss_gsis_no     || "—"],
              [t("mp_religious_social"), PM.religious_social_affiliation || "—"],
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
              <div className="mp-section-label" style={{marginTop:20}}>{t("mp_spouse_family")}</div>
              <div className="mp-info-grid">
                {[
                  [t("mp_spouse_name"),          PM.spouse_name          || "—"],
                  [t("mp_spouse_occupation"),     PM.spouse_occupation    || "—"],
                  [t("mp_spouse_income"),         PM.spouse_income ? `₱${Number(PM.spouse_income).toLocaleString()}` : "—"],
                  [t("mp_no_dependants"),         PM.no_of_dependants     || "—"],
                  [t("mp_beneficiary"),           PM.beneficiary_name     || "—"],
                  [t("mp_relationship"),          PM.beneficiary_relationship || "—"],
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
          <div className="mp-section-label" style={{marginTop:20}}>{t("mp_contact_address")}</div>
          <div className="mp-info-grid">
            <div className="mp-info-item">
              <span className="mp-info-key">{t("mp_contact_no")}</span>
              {editing
                ? <input className="mp-edit-input" type="tel" name="contact_number" value={form.contact_number} onChange={handle}/>
                : <span className="mp-info-val">{form.contact_number || PM.contact_number || "—"}</span>
              }
            </div>
            <div className="mp-info-item">
              <span className="mp-info-key">{t("mp_email")}</span>
              {editing
                ? <input className="mp-edit-input" type="email" name="email" value={form.email} onChange={handle}/>
                : <span className="mp-info-val">{form.email || PM.email || "—"}</span>
              }
            </div>
            <div className="mp-info-item">
              <span className="mp-info-key">{t("mp_occupation")}</span>
              {editing
                ? <input className="mp-edit-input" name="occupation" value={form.occupation} onChange={handle}/>
                : <span className="mp-info-val">{form.occupation || PM.occupation || "—"}</span>
              }
            </div>
            <div className="mp-info-item mp-full">
              <span className="mp-info-key">{t("mp_address")}</span>
              {editing
                ? <input className="mp-edit-input" name="address" value={form.address} onChange={handle}/>
                : <span className="mp-info-val">{form.address || PM.address || "—"}</span>
              }
            </div>
          </div>

          {/* Section: Documents */}
          <div className="mp-section-label" style={{marginTop:20}}>{t("mp_documents_submitted")}</div>
          <div className="mp-info-grid">
            <div className="mp-info-item">
              <span className="mp-info-key">{t("mp_birth_cert")}</span>
              <span className="mp-info-val" style={{color:PM.birth_certificate?"#2e7d32":"#aaa",fontWeight:600}}>
                {PM.birth_certificate ? t("mp_submitted") : t("mp_not_submitted")}
              </span>
            </div>
            <div className="mp-info-item">
              <span className="mp-info-key">{t("mp_marriage_cert")}</span>
              <span className="mp-info-val" style={{color:PM.marriage_certificate?"#2e7d32":"#aaa",fontWeight:600}}>
                {PM.marriage_certificate ? t("mp_submitted") : t("mp_not_submitted_na")}
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
            <div className="mp-card-title">{t("mp_account_info")}</div>
            <div className="mp-cred-info-card">
              <div className="mp-cred-row">
                <span className="mp-cred-label">{t("mp_member_id")}</span>
                <span className="mp-cred-val">{PROFILE.member_id || "—"}</span>
              </div>
              <div className="mp-cred-row">
                <span className="mp-cred-label">{t("mp_username")}</span>
                <span className="mp-cred-val">{username}</span>
              </div>
              <div className="mp-cred-row">
                <span className="mp-cred-label">{t("mp_status")}</span>
                <span className="mp-cred-val" style={{color:"#69f0ae",fontWeight:700}}>{t("mp_active")}</span>
              </div>
            </div>
          </div>

          {/* Change Username */}
          <div className="mp-card">
            <div className="mp-card-title">{t("mp_change_username")}</div>
            <div className="mp-card-sub2">{t("mp_current_username")} <strong>{username}</strong></div>
            {unSaved && <div className="mp-success-banner">{t("mp_username_success")}</div>}
            <div className="mp-sec-form">
              <div className="mp-sec-field">
                <label className="mp-info-key">{t("mp_new_username")}</label>
                <input className={`mp-sec-input ${unError?"mp-sec-err":""}`} type="text"
                  placeholder={t("mp_new_username_placeholder")}
                  autoComplete="off"
                  value={newUsername} onChange={e => { setNewUsername(e.target.value); setUnError(""); }}/>
                {unError && <div className="mp-sec-error-msg">{unError}</div>}
              </div>
              <button className="mp-save-btn" onClick={handleUsernameChange}>{t("mp_update_username")}</button>
            </div>
            <div className="mp-sec-hint">{t("mp_username_hint")}</div>
          </div>

          {/* Change Password */}
          <div className="mp-card">
            <div className="mp-card-title">{t("mp_change_password")}</div>
            <div className="mp-card-sub2">{t("mp_password_sub")}</div>
            {passSaved && <div className="mp-success-banner">{t("mp_password_success")}</div>}
            {passError && <div className="mp-sec-error-banner">{passError}</div>}
            <div className="mp-sec-form">
              <div className="mp-sec-field">
                <label className="mp-info-key">{t("mp_current_password")}</label>
                <div className="mp-pass-wrap">
                  <input className="mp-sec-input" type={showCurr?"text":"password"} name="current"
                    placeholder={t("mp_current_password_placeholder")} value={passForm.current}
                    autoComplete="current-password"
                    onChange={e => { handlePass(e); setPassError(""); }}/>
                  <button type="button" className="mp-eye" onClick={() => setShowCurr(s=>!s)}>
                    {showCurr ? <EyeOff size={14}/> : <Eye size={14}/>}
                  </button>
                </div>
              </div>
              <div className="mp-sec-field">
                <label className="mp-info-key">{t("mp_new_password")}</label>
                <div className="mp-pass-wrap">
                  <input className="mp-sec-input" type={showNew?"text":"password"} name="newPass"
                    placeholder={t("mp_new_password_placeholder")} value={passForm.newPass}
                    autoComplete="new-password"
                    onChange={e => { handlePass(e); setPassError(""); }}/>
                  <button type="button" className="mp-eye" onClick={() => setShowNew(s=>!s)}>
                    {showNew ? <EyeOff size={14}/> : <Eye size={14}/>}
                  </button>
                </div>
                {passForm.newPass && (
                  <div className="mp-strength-row">
                    {["weak","fair","strong"].map((s,i) => (
                      <div key={s} className={`mp-strength-bar ${passForm.newPass.length >= [1,5,8][i] ? s : ""}`}/>
                    ))}
                    <span className="mp-strength-label">
                      {passForm.newPass.length < 5 ? t("mp_weak") : passForm.newPass.length < 8 ? t("mp_fair") : t("mp_strong")}
                    </span>
                  </div>
                )}
              </div>
              <div className="mp-sec-field">
                <label className="mp-info-key">{t("mp_confirm_password")}</label>
                <div className="mp-pass-wrap">
                  <input className="mp-sec-input" type={showConf?"text":"password"} name="confirm"
                    placeholder={t("mp_confirm_password_placeholder")} value={passForm.confirm}
                    autoComplete="new-password"
                    onChange={e => { handlePass(e); setPassError(""); }}/>
                  <button type="button" className="mp-eye" onClick={() => setShowConf(s=>!s)}>
                    {showConf ? <EyeOff size={14}/> : <Eye size={14}/>}
                  </button>
                </div>
              </div>
              <button className="mp-save-btn" onClick={handlePasswordChange}>{t("mp_update_password")}</button>
            </div>
            <div className="mp-sec-hint">{t("mp_password_hint")}</div>
          </div>
        </div>
      )}
    </div>
  );
}