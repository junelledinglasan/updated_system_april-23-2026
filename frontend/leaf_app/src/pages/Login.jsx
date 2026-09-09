import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { useAuth } from "../context/AuthContext";
import { Leaf, Eye, EyeOff, Lock, User, AlertTriangle, LogIn } from "lucide-react";
import "./Login.css";

export default function Login() {
  const { login, loading } = useAuth();
  const navigate = useNavigate();

  const [form,   setForm]   = useState({ username: "", password: "" });
  const [error,  setError]  = useState("");
  const [showPw, setShowPw] = useState(false);
  const [showMsg,setShowMsg]= useState(false);

  const handle = e => {
    setForm(p => ({ ...p, [e.target.name]: e.target.value }));
    setError("");
  };

  const handleSubmit = async () => {
    if (!form.username.trim()) { setError("Please enter your username."); return; }
    if (!form.password)        { setError("Please enter your password."); return; }

    const result = await login(form.username, form.password);

    if (!result.success) {
      setError(result.message);
      return;
    }

    if (result.role === "admin")  navigate("/admin/dashboard",  { replace: true });
    if (result.role === "staff")  navigate("/staff",            { replace: true });
    if (result.role === "member") navigate("/member/dashboard", { replace: true });
    if (result.role === "user")   navigate("/member/dashboard", { replace: true });
  };

  const handleKeyDown = e => {
    if (e.key === "Enter") handleSubmit();
  };

  return (
    <div className="login-page">

      {/* Forgot Password Modal */}
      {showMsg && (
        <div className="login-msg-overlay" onClick={() => setShowMsg(false)}>
          <div className="login-msg-box" onClick={e => e.stopPropagation()}>
            <div className="login-msg-icon"><Lock size={32} color="#2e7d32"/></div>
            <div className="login-msg-title">Forgot Password?</div>
            <div className="login-msg-text">
              Para sa password reset, mangyaring bumisita sa opisina o makipag-ugnayan sa LEAF MPC administrator.
            </div>
            <button className="login-msg-btn" onClick={() => setShowMsg(false)}>Got it</button>
          </div>
        </div>
      )}

      {/* Left Panel */}
      <div className="login-left">
        <div className="login-left-content">
          <div className="login-logo-placeholder">
            <img src="/logo.png" alt="LEAF MPC" className="login-logo-img" />
          </div>
          <div className="login-left-title">Cooperative Management System</div>
          <div className="login-left-sub">Admin, Staff and Member Portal</div>
        </div>
      </div>

      {/* Right Panel */}
      <div className="login-right">
        <div className="login-card">

          {/* ── BAGO: mobile-only branding — dating nawawala nang
              tuluyan ang buong logo/pangalan ng system kapag maliit
              ang screen (natatago ang buong .login-left panel), kaya
              parang "plain" na lang na card ang natitira. Ito ay
              lumalabas LANG sa maliit na screen (tingnan ang CSS). ── */}
          <div className="login-mobile-brand">
            <img src="/logo.png" alt="LEAF MPC" className="login-mobile-brand-img"/>
            <div className="login-mobile-brand-text">Cooperative Management System</div>
          </div>

          {/* ── BAGO: dating plain na leaf icon lang — ngayon may
              circular badge background para mas prominent at hindi
              "plain." ─────────────────────────────────────────────── */}
          <div className="login-card-icon">
            <div className="login-icon-badge">
              <Leaf size={22} color="#fff" fill="#fff"/>
            </div>
          </div>
          <div className="login-card-title">Login</div>
          <div className="login-card-sub">Enter your credentials to continue</div>

          <div className="login-form">

            <div className="login-field">
              <label className="login-label">Username</label>
              <div className="login-input-wrap">
                <User size={15} className="login-input-icon"/>
                <input
                  className={`login-input login-input-with-icon ${error ? "login-input-err" : ""}`}
                  type="text"
                  name="username"
                  placeholder="Enter your username"
                  value={form.username}
                  onChange={handle}
                  onKeyDown={handleKeyDown}
                  autoComplete="username"
                  autoFocus
                />
              </div>
            </div>

            <div className="login-field">
              <label className="login-label">Password</label>
              <div className="login-pw-wrap">
                <Lock size={15} className="login-input-icon"/>
                <input
                  className={`login-input login-input-with-icon ${error ? "login-input-err" : ""}`}
                  type={showPw ? "text" : "password"}
                  name="password"
                  placeholder="Enter your password"
                  value={form.password}
                  onChange={handle}
                  onKeyDown={handleKeyDown}
                  autoComplete="current-password"
                />
                <button
                  className="login-pw-eye"
                  onClick={() => setShowPw(p => !p)}
                  tabIndex={-1}
                  type="button"
                >
                  {showPw ? <EyeOff size={16}/> : <Eye size={16}/>}
                </button>
              </div>
            </div>

            <div className="login-links-row">
              <button className="login-link" onClick={() => setShowMsg(true)}>
                Forgot Password?
              </button>
              <button className="login-link" onClick={() => navigate("/register")}>
                Create Account
              </button>
            </div>

            {error && <div className="login-error"><AlertTriangle size={13}/> {error}</div>}

            <button
              className="login-btn"
              onClick={handleSubmit}
              disabled={loading}
            >
              {loading ? <span className="login-spinner" /> : <><LogIn size={16}/> Login</>}
            </button>

          </div>

          <div className="login-notice">
            <Lock size={12}/> Your account will automatically be directed to the correct portal
          </div>

        </div>
      </div>
    </div>
  );
}