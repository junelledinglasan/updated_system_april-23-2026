import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { registerUserAPI } from "../../api/auth";
import { Info, PartyPopper, ClipboardList, User, Lock, Eye, EyeOff, Check, X } from "lucide-react";
import "./MemberRegister.css";

function FormField({ name, label, type="text", required=false, full=false, value, onChange, error, icon, showToggle=false, showValue, onToggleShow, endAdornment }) {
  // ── BAGO: dating walang icon at walang password show/hide toggle
  // ang mga field na 'to — dating hindi makita ng user ang tina-type
  // nilang password habang nagre-register, hindi tulad ng Login page
  // na meron nang ganitong feature. ─────────────────────────────────
  const effectiveType = showToggle ? (showValue ? "text" : "password") : type;
  return (
    <div className={`mr-field ${full?"mr-full":""}`}>
      <label className="mr-label">{label}{required && <span className="mr-req"> *</span>}</label>
      <div className="mr-input-wrap">
        {icon && <span className="mr-input-icon">{icon}</span>}
        <input
          className={`mr-input ${icon?"mr-input-with-icon":""} ${showToggle?"mr-input-with-toggle":""} ${error?"mr-err":""}`}
          type={effectiveType} name={name} value={value} onChange={onChange}
        />
        {showToggle && (
          <button type="button" className="mr-pw-eye" tabIndex={-1} onClick={onToggleShow}>
            {showValue ? <EyeOff size={15}/> : <Eye size={15}/>}
          </button>
        )}
        {endAdornment}
      </div>
      {error && <div className="mr-field-err">{error}</div>}
    </div>
  );
}

export default function MemberRegister() {
  const navigate  = useNavigate();
  const [loading, setLoading] = useState(false);
  const [done,    setDone]    = useState(false);
  const [errors,  setErrors]  = useState({});
  // ── BAGO: para sa password visibility toggle (Eye/EyeOff), dating
  // wala nito ang form na 'to. ─────────────────────────────────────
  const [showPw,        setShowPw]        = useState(false);
  const [showConfirmPw, setShowConfirmPw] = useState(false);

  const [form, setForm] = useState({
    first_name: "", last_name: "", middle_name: "",
    username: "", password: "", confirmPassword: "",
  });

  const handle = e => {
    setForm(p => ({ ...p, [e.target.name]: e.target.value }));
    setErrors(p => ({ ...p, [e.target.name]: "" }));
  };

  const validate = () => {
    const e = {};
    if (!form.first_name.trim())         e.first_name      = "Required";
    if (!form.last_name.trim())          e.last_name       = "Required";
    if (!form.username.trim())           e.username        = "Required";
    if (form.username.trim().length < 4) e.username        = "Min 4 characters";
    if (form.username.includes(" "))     e.username        = "No spaces allowed";
    if (!form.password)                  e.password        = "Required";
    if (form.password.length < 6)        e.password        = "Min 6 characters";
    if (form.password !== form.confirmPassword) e.confirmPassword = "Passwords do not match";
    return e;
  };

  const handleSubmit = async () => {
    const e = validate();
    if (Object.keys(e).length) { setErrors(e); return; }
    setLoading(true);
    try {
      await registerUserAPI({
        username:    form.username,
        password:    form.password,
        first_name:  form.first_name,
        last_name:   form.last_name,
        middle_name: form.middle_name,
      });
      setDone(true);
    } catch(err) {
      const d   = err.response?.data;
      const msg = d?.detail || (d?.username?.[0]) || (d && Object.values(d)[0]?.[0]) || "Registration failed.";
      setErrors({ username: msg });
    } finally { setLoading(false); }
  };

  if (done) return (
    <div className="mr-page">
      <div className="mr-success-card">
        <div className="mr-success-icon"><PartyPopper size={48} color="#f57c00"/></div>
        <div className="mr-success-title">Account Created!</div>
        <div className="mr-success-text">
          Your account has been created successfully.<br/><br/>
          You can now <strong>log in</strong> using your username and password.
          Once logged in, you can apply for official membership to unlock full access.
        </div>
        <div className="mr-success-notice" style={{display:"flex",alignItems:"flex-start",gap:8}}>
          <ClipboardList size={16} color="#2e7d32" style={{flexShrink:0,marginTop:1}}/>
          <span>After logging in, go to <strong>Apply for Membership</strong> to submit your membership application for admin approval.</span>
        </div>
        <div className="mr-success-actions">
          <button className="mr-btn-primary" onClick={() => navigate("/login")}>Go to Login</button>
        </div>
      </div>
    </div>
  );

  return (
    <div className="mr-page">
      <div className="mr-card">
        <div className="mr-header">
          {/* ── BAGO: idinagdag ang aktwal na logo image, tugma sa
              Login page — dating text lang na "LEAF MPC". ─────────── */}
          <img src="/logo.png" alt="LEAF MPC" className="mr-logo-img"/>
          <div className="mr-logo">LEAF MPC</div>
          <div className="mr-title">Create Account</div>
          <div className="mr-sub">Create your LEAF MPC account to get started.</div>
        </div>

        <div className="mr-body" style={{padding:"24px"}}>
          <div className="mr-grid">
            <div className="mr-field mr-full" style={{background:"#f1f8e9",borderRadius:10,padding:"12px 16px",borderLeft:"3px solid #2e7d32",marginBottom:4}}>
              <div style={{fontSize:12,color:"#2e7d32",fontWeight:600,display:"flex",alignItems:"center",gap:6}}><Info size={13}/> Note</div>
              <div style={{fontSize:12,color:"#555",marginTop:4,lineHeight:1.6}}>
                Creating an account does <strong>not</strong> make you an official member yet.
                After logging in, you can submit a membership application for admin review.
              </div>
            </div>

            {/* ── Name Fields ── */}
            <FormField
              name="first_name" label="First Name" required icon={<User size={14}/>}
              value={form.first_name} onChange={handle} error={errors.first_name}
            />
            <FormField
              name="last_name" label="Last Name" required icon={<User size={14}/>}
              value={form.last_name} onChange={handle} error={errors.last_name}
            />
            <FormField
              name="middle_name" label="Middle Name" icon={<User size={14}/>}
              value={form.middle_name} onChange={handle} error={errors.middle_name}
            />

            {/* ── Username ── */}
            <FormField
              name="username" label="Username" required full icon={<User size={14}/>}
              value={form.username} onChange={handle} error={errors.username}
            />
            <div className="mr-field mr-full" style={{fontSize:11,color:"#888",marginTop:-8}}>
              Min 4 characters, no spaces allowed.
            </div>

            {/* ── Password — BAGO: may show/hide toggle na ngayon,
                dating hindi makita ng user ang tina-type nilang
                password. ─────────────────────────────────────────── */}
            <FormField
              name="password" label="Password" required icon={<Lock size={14}/>}
              value={form.password} onChange={handle} error={errors.password}
              showToggle showValue={showPw} onToggleShow={() => setShowPw(p => !p)}
            />
            <FormField
              name="confirmPassword" label="Confirm Password" required icon={<Lock size={14}/>}
              value={form.confirmPassword} onChange={handle} error={errors.confirmPassword}
              showToggle showValue={showConfirmPw} onToggleShow={() => setShowConfirmPw(p => !p)}
            />
            {/* ── BAGO: live indicator kung tumutugma na ang dalawang
                password — lumalabas lang kapag may laman na ang
                Confirm Password field. ────────────────────────────── */}
            {form.confirmPassword && (
              <div className="mr-field mr-full" style={{fontSize:11,marginTop:-8,display:"flex",alignItems:"center",gap:5,color:form.password===form.confirmPassword?"#2e7d32":"#c62828"}}>
                {form.password===form.confirmPassword ? <><Check size={12}/> Passwords match</> : <><X size={12}/> Passwords do not match</>}
              </div>
            )}

            {form.password && (
              <div className="mr-strength mr-full">
                <div className="mr-strength-bars">
                  {["weak","fair","strong"].map((s,i) => (
                    <div key={s} className={`mr-bar ${form.password.length > [0,4,7][i] ? s : ""}`}/>
                  ))}
                </div>
                <span className="mr-strength-label">
                  {form.password.length < 5 ? "Weak" : form.password.length < 8 ? "Fair" : "Strong"}
                </span>
              </div>
            )}
          </div>
        </div>

        <div className="mr-footer">
          <div className="mr-footer-nav">
            <button className="mr-btn-submit" onClick={handleSubmit} disabled={loading}>
              {loading ? <span className="mr-spinner"/> : "Create Account"}
            </button>
          </div>
          <div className="mr-login-link">
            Already have an account? <button onClick={() => navigate("/login")}>Login here</button>
          </div>
        </div>
      </div>
    </div>
  );
}