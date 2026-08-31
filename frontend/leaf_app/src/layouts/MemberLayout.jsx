import { useState, useEffect } from "react";
import { Outlet, NavLink, useNavigate, useLocation } from "react-router-dom";
import { useAuth } from "../context/AuthContext";
import { LanguageProvider, useLanguage } from "../context/LanguageContext";
import { getMyProfileAPI, getMyOnlineAppAPI } from "../api/members";
import { LayoutDashboard, CreditCard, Bell, Megaphone, FileText, UserCircle, Lock, PiggyBank, Globe } from "lucide-react";
import "./MemberLayout.css";
import logo from "../assets/logo.png";

const LOCKED_ROUTES = [
  "/member/dashboard",
  "/member/my-loans",
  "/member/savings",
  "/member/apply",
];

const NAV_ITEMS = [
  { to: "/member/dashboard",     icon: <LayoutDashboard size={16}/>, labelKey: "ml_nav_dashboard",     locked: true  },
  { to: "/member/my-loans",      icon: <CreditCard      size={16}/>, labelKey: "ml_nav_my_loans",       locked: true  },
  { to: "/member/savings",       icon: <PiggyBank       size={16}/>, labelKey: "ml_nav_my_savings",     locked: true  },
  { to: "/member/notifications", icon: <Bell            size={16}/>, labelKey: "ml_nav_notifications",  locked: false },
  { to: "/member/announcements", icon: <Megaphone       size={16}/>, labelKey: "ml_nav_announcements",  locked: false },
  { to: "/member/apply",         icon: <FileText        size={16}/>, labelKey: "ml_nav_apply_loan",     locked: true  },
  { to: "/member/profile",       icon: <UserCircle      size={16}/>, labelKey: "ml_nav_profile",        locked: false },
];

function OfficialMemberGate({ onClose, onApply }) {
  const { t } = useLanguage();
  return (
    <div className="ml-gate-overlay" onClick={onClose}>
      <div className="ml-gate-box" onClick={e => e.stopPropagation()}>
        <div className="ml-gate-icon"><Lock size={48} color="#c62828"/></div>
        <div className="ml-gate-title">{t("ml_gate_title")}</div>
        <div className="ml-gate-text">
          {t("ml_gate_text")}
        </div>
        <div className="ml-gate-features">
          <div className="ml-gate-feature-title">{t("ml_gate_unlock_title")}</div>
          <div className="ml-gate-feature-item">{t("ml_gate_feature1")}</div>
          <div className="ml-gate-feature-item">{t("ml_gate_feature2")}</div>
          <div className="ml-gate-feature-item">{t("ml_gate_feature3")}</div>
        </div>
        <div className="ml-gate-actions">
          <button className="ml-gate-btn-apply" onClick={onApply}>{t("dash_apply_membership_btn")}</button>
          <button className="ml-gate-btn-cancel" onClick={onClose}>{t("ml_gate_maybe_later")}</button>
        </div>
      </div>
    </div>
  );
}

// ── BAGO: EN/FIL toggle button — nasa topbar-right, katulad ng
// pwesto ng mga controls sa admin's topbar (kaliwa ng avatar). ──────
function LanguageToggle() {
  const { language, toggleLanguage } = useLanguage();
  return (
    <button
      onClick={toggleLanguage}
      title={language === "en" ? "Switch to Filipino" : "Switch to English"}
      style={{
        display: "flex", alignItems: "center", gap: 6,
        padding: "6px 12px", borderRadius: 20,
        border: "1px solid #c8e6c9", background: "#f1f8f1",
        color: "#2e7d32", fontSize: 12, fontWeight: 700,
        cursor: "pointer", marginRight: 10, fontFamily: "inherit",
      }}
    >
      <Globe size={13}/> {language === "en" ? "ENGLISH" : "FILIPINO"}
    </button>
  );
}

// ── BAGO: nilipat ang buong laman ng MemberLayout papunta sa isang
// inner component, dahil kailangang naka-loob sa <LanguageProvider>
// ang useLanguage() hook (hindi puwedeng gamitin sa parehong
// component na siyang nagpo-provide nito). ──────────────────────────
function MemberLayoutInner() {
  const { t } = useLanguage();
  const [sidebarOpen,   setSidebar]    = useState(false);
  const [notifCount,    setNotif]      = useState(0);
  const [showGate,      setShowGate]   = useState(false);
  const [memberData,    setMemberData] = useState(null);
  const [loadingMember, setLoading]    = useState(true);
  const navigate  = useNavigate();
  const location  = useLocation();
  const { logout, user } = useAuth();

  useEffect(() => { setSidebar(false); }, [location.pathname]);

  useEffect(() => {
    const fetch = async () => {
      setLoading(true);
      try {
        // ── Try to get official member profile first ──
        const profile = await getMyProfileAPI();
        setMemberData({ ...profile, isOfficial: true });
      } catch {
        try {
          // ── Fallback: check online application status ──
          const app = await getMyOnlineAppAPI();
          setMemberData({ isOfficial: false, appStatus: app.application_status });
        } catch {
          setMemberData({ isOfficial: false, appStatus: null });
        }
      } finally { setLoading(false); }
    };
    fetch();
  }, []);

  const isOfficial = memberData?.isOfficial || false;

  useEffect(() => {
    if (!loadingMember && !isOfficial && LOCKED_ROUTES.includes(location.pathname)) {
      navigate("/member/notifications", { replace: true });
    }
  }, [location.pathname, isOfficial, loadingMember]);

  const handleLogout = () => { logout(); navigate("/login"); };

  const handleNavClick = (item, e) => {
    if (item.locked && !isOfficial) { e.preventDefault(); setShowGate(true); }
  };

  const member = {
    id:            memberData?.id || null,
    name:          memberData?.fullname || user?.name || "Member",
    memberId:      memberData?.member_id || "—",
    initials:      (memberData?.first_name?.[0] || user?.name?.[0] || "M").toUpperCase(),
    isOfficial:    isOfficial,
    share_capital: memberData?.share_capital || 0,
  };

  return (
    <div className="ml-layout">

      {showGate && (
        <OfficialMemberGate
          onClose={() => setShowGate(false)}
          onApply={() => { setShowGate(false); navigate("/member/apply-membership"); }}
        />
      )}

      <div className={`ml-overlay ${sidebarOpen ? "open" : ""}`} onClick={() => setSidebar(false)} />

      <aside className={`ml-sidebar ${sidebarOpen ? "open" : ""}`}>
        <div className="ml-logo">
          <img src={logo} alt="LEAF MPC Logo" style={{ height: "35px", width: "160px", objectFit: "contain" }}/>
        </div>

        <div className="ml-profile-strip">
          <div className="ml-avatar">{member.initials}</div>
          <div className="ml-profile-info">
            <div className="ml-profile-name">{member.name}</div>
            <div className="ml-profile-id">
              {member.memberId !== "—" ? member.memberId : t("ml_no_member_id")}
            </div>
          </div>
          <span
            className={`ml-status-dot ${isOfficial ? "active" : "pending"}`}
            title={isOfficial ? "Official Member" : "Not yet official"}
          />
        </div>

        {!isOfficial && (
          <div className="ml-unofficial-notice">
            <span>⚠️</span>
            <div className="ml-unofficial-text">
              {t("ml_unofficial_notice")}
            </div>
          </div>
        )}

        <nav className="ml-nav">
          {NAV_ITEMS.map(item => {
            const isLocked = item.locked && !isOfficial;
            return (
              <NavLink
                key={item.to}
                to={item.to}
                className={({ isActive }) =>
                  "ml-nav-item" +
                  (isActive && !isLocked ? " active" : "") +
                  (isLocked ? " locked" : "")
                }
                onClick={e => handleNavClick(item, e)}
              >
                <span className="ml-nav-icon">{item.icon}</span>
                <span className="ml-nav-label">{t(item.labelKey)}</span>
                {item.to === "/member/notifications" && notifCount > 0 && (
                  <span className="ml-notif-badge">{notifCount}</span>
                )}
                {isLocked && <span className="ml-lock-icon"><Lock size={11}/></span>}
              </NavLink>
            );
          })}
        </nav>

        <div className="ml-sidebar-bottom">
          <button className="ml-logout-btn" onClick={handleLogout}>{t("ml_sign_out")}</button>
        </div>
      </aside>

      <div className="ml-main">
        <header className="ml-topbar">
          <button
            className={`ml-hamburger ${sidebarOpen ? "open" : ""}`}
            onClick={() => setSidebar(s => !s)}
            aria-label="Toggle menu"
          >
            <span /><span /><span />
          </button>
          <div className="ml-topbar-title">{t("ml_topbar_title")}</div>
          <div className="ml-topbar-right">
            {/* ── BAGO: EN/FIL language toggle — katabi ng avatar,
                katulad ng lokasyon ng mga controls sa admin topbar. ── */}
            <LanguageToggle/>
            <div className="ml-topbar-avatar">{member.initials}</div>
          </div>
        </header>

        <main className="ml-content">
          <Outlet context={{ member, notifCount, setNotif }} />
        </main>
      </div>
    </div>
  );
}

export default function MemberLayout() {
  return (
    <LanguageProvider>
      <MemberLayoutInner/>
    </LanguageProvider>
  );
}