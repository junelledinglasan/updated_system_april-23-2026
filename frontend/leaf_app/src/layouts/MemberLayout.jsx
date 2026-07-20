import { useState, useEffect } from "react";
import { Outlet, NavLink, useNavigate, useLocation } from "react-router-dom";
import { useAuth } from "../context/AuthContext";
import { getMyProfileAPI, getMyOnlineAppAPI } from "../api/members";
import { LayoutDashboard, CreditCard, Bell, Megaphone, FileText, UserCircle, Lock, PiggyBank } from "lucide-react";
import "./MemberLayout.css";
import logo from "../assets/logo.png";

const LOCKED_ROUTES = [
  "/member/dashboard",
  "/member/my-loans",
  "/member/savings",
  "/member/apply",
];

const NAV_ITEMS = [
  { to: "/member/dashboard",     icon: <LayoutDashboard size={16}/>, label: "Dashboard",      locked: true  },
  { to: "/member/my-loans",      icon: <CreditCard      size={16}/>, label: "My Loans",       locked: true  },
  { to: "/member/savings",       icon: <PiggyBank       size={16}/>, label: "My Savings",     locked: true  },
  { to: "/member/notifications", icon: <Bell            size={16}/>, label: "Notifications",  locked: false },
  { to: "/member/announcements", icon: <Megaphone       size={16}/>, label: "Announcements",  locked: false },
  { to: "/member/apply",         icon: <FileText        size={16}/>, label: "Apply for Loan", locked: true  },
  { to: "/member/profile",       icon: <UserCircle      size={16}/>, label: "My Profile",     locked: false },
];

function OfficialMemberGate({ onClose, onApply }) {
  return (
    <div className="ml-gate-overlay" onClick={onClose}>
      <div className="ml-gate-box" onClick={e => e.stopPropagation()}>
        <div className="ml-gate-icon"><Lock size={48} color="#c62828"/></div>
        <div className="ml-gate-title">Official Members Only</div>
        <div className="ml-gate-text">
          This feature is only available to official LEAF MPC members.
          Complete your membership to unlock full access.
        </div>
        <div className="ml-gate-features">
          <div className="ml-gate-feature-title">Unlock these features:</div>
          <div className="ml-gate-feature-item">📊 Dashboard & loan overview</div>
          <div className="ml-gate-feature-item">💳 My Loans & payment history</div>
          <div className="ml-gate-feature-item">📝 Apply for loans online</div>
        </div>
        <div className="ml-gate-actions">
          <button className="ml-gate-btn-apply" onClick={onApply}>Apply for Official Membership</button>
          <button className="ml-gate-btn-cancel" onClick={onClose}>Maybe Later</button>
        </div>
      </div>
    </div>
  );
}

export default function MemberLayout() {
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
              {member.memberId !== "—" ? member.memberId : "No Member ID yet"}
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
              You are not yet an official member. Some features are locked.
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
                <span className="ml-nav-label">{item.label}</span>
                {item.to === "/member/notifications" && notifCount > 0 && (
                  <span className="ml-notif-badge">{notifCount}</span>
                )}
                {isLocked && <span className="ml-lock-icon"><Lock size={11}/></span>}
              </NavLink>
            );
          })}
        </nav>

        <div className="ml-sidebar-bottom">
          <button className="ml-logout-btn" onClick={handleLogout}>Sign Out</button>
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
          <div className="ml-topbar-title">MEMBER</div>
          <div className="ml-topbar-right">
            <button className="ml-notif-btn" onClick={() => navigate("/member/notifications")}>
              <Bell size={20} color="#2d5a1b"/>
              {notifCount > 0 && <span className="ml-notif-dot">{notifCount}</span>}
            </button>
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