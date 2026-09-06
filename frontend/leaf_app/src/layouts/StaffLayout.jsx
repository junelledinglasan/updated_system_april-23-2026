import { useState, useEffect } from "react";
import { NavLink, Outlet, useLocation, useNavigate } from "react-router-dom";
import { useAuth } from "../context/AuthContext";
import {
  Home, CreditCard, Users, ClipboardCheck,
  FileText, BarChart2, Megaphone, LogOut,
} from "lucide-react";
import logo from "../assets/logo.png";
import { getStaffPermissionsAPI } from "../api/settings";
import "./StaffLayout.css";

// ─── Nav items per staff role ─────────────────────────────────────────────────
// Master list ng LAHAT ng possible staff nav items — ang "featureKey"
// ay tinutugma sa AVAILABLE_FEATURES sa backend (settings_app).
// "Home" ay laging kasama, hindi na kailangan i-toggle.
const ALL_STAFF_NAV = [
  { to: "/staff",               icon: <Home size={15} />,           label: "Home",               end: true,  featureKey: null              },
  { to: "/staff/members",       icon: <Users size={15} />,          label: "Manage Members",     end: false, featureKey: "members"          },
  { to: "/staff/applications",  icon: <FileText size={15} />,       label: "Online Application", end: false, featureKey: "applications"     },
  { to: "/staff/loan-payment",  icon: <CreditCard size={15} />,     label: "Loan Payment",       end: false, featureKey: "loan-payment"     },
  { to: "/staff/loan-approval", icon: <ClipboardCheck size={15} />, label: "Loan Approval",      end: false, featureKey: "loan-approval"    },
  { to: "/staff/announcement",  icon: <Megaphone size={15} />,      label: "Announcement",       end: false, featureKey: "announcement"     },
  { to: "/staff/reports",       icon: <BarChart2 size={15} />,      label: "Reports",            end: false, featureKey: "reports"          },
];

// ─── Topbar actions per page ──────────────────────────────────────────────────
// ── FIX: dati, naka-hiwalay ito PER staff_role ({cashier: {...},
// admin_clerk: {...}}) — kaya kahit bigyan ng admin ng "Manage
// Members" feature ang isang staff na "cashier"/"collector"/
// "bookkeeper" ang role, LUMALABAS ang sidebar link (tama namang
// naka-filter sa allowedFeatures) PERO HINDI lumalabas ang "+
// Register Member" button sa taas — dahil hiwalay at naka-hardcode
// ito sa staff_role, hindi sa dynamic na permission. Ngayon, base na
// lang sa PATH (kung anong page ang kasalukuyang bukas) — kung
// naka-reach ka doon (ibig sabihin, pinayagan ka na ng
// allowedFeatures), makikita mo na rin ang kaakibat na action button. ──
const PAGE_ACTIONS_BY_PATH = {
  "/staff/members": [
    { label: "+ Register Member", cls: "sl-btn-green", action: "register" },
  ],
  "/staff/loan-payment": [
    { label: "+ New F2F Payment", cls: "sl-btn-blue", action: "f2f" },
  ],
};

const STAFF_ROLE_LABELS = {
  cashier:     "Cashier",
  collector:   "Collector",
  bookkeeper:  "Bookkeeper",
  admin_clerk: "Administrative Clerk",
};

export default function StaffLayout() {
  const { user, logout } = useAuth();
  const location         = useLocation();
  const navigate         = useNavigate();
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const [clock,       setClock]       = useState("");
  const [allowedFeatures, setAllowedFeatures] = useState(null); // null = loading pa
 
  useEffect(() => {
    if (!user?.id) return;
    getStaffPermissionsAPI(user.id)
      .then(data => setAllowedFeatures(data.features || []))
      .catch(() => setAllowedFeatures([]));
  }, [user?.id]);
 
  // "Home" laging kasama; ang iba ay depende sa AllowedFeatures
  // na na-set ng Admin sa Settings — hindi na sa hardcoded staff_role.
  const navItems = allowedFeatures === null
    ? [ALL_STAFF_NAV[0]] // habang naglo-load, "Home" muna ang ipakita
    : ALL_STAFF_NAV.filter(item => item.featureKey === null || allowedFeatures.includes(item.featureKey));
  const roleLabel = STAFF_ROLE_LABELS[user?.staff_role] ?? "Staff";


  // Topbar actions based on current page — hindi na base sa role,
  // base na sa path (kaakibat na ng allowedFeatures kung naka-reach
  // dito ang staff).
  const pageActions = PAGE_ACTIONS_BY_PATH[location.pathname] ?? [];

  // Close sidebar on route change (mobile)
  useEffect(() => { setSidebarOpen(false); }, [location.pathname]);

  useEffect(() => {
    const tick = () => {
      const now  = new Date();
      const days = ["SUN","MON","TUE","WED","THU","FRI","SAT"];
      const mons = ["JAN","FEB","MAR","APR","MAY","JUN","JUL","AUG","SEP","OCT","NOV","DEC"];
      const pad  = n => String(n).padStart(2, "0");
      setClock(
        `${days[now.getDay()]} ${mons[now.getMonth()]} ${now.getDate()}, ${now.getFullYear()} — ${pad(now.getHours())}:${pad(now.getMinutes())}:${pad(now.getSeconds())}`
      );
    };
    tick();
    const id = setInterval(tick, 1000);
    return () => clearInterval(id);
  }, []);

  const handleLogout = async () => { await logout(); };

  // Action handler — dispatches custom event so child components can listen
  const handleAction = (action) => {
    window.dispatchEvent(new CustomEvent("staff-action", { detail: { action } }));
  };

  return (
    <div className="sl-layout">

      {/* Mobile sidebar overlay */}
      <div
        className={`sl-overlay-bg ${sidebarOpen ? "open" : ""}`}
        onClick={() => setSidebarOpen(false)}
      />

      {/* ── Sidebar ── */}
      <aside className={`sl-sidebar ${sidebarOpen ? "open" : ""}`}>
        <div className="sl-logo">
          <img
            src={logo}
            alt="LEAF MPC Logo"
            style={{ height: "35px", width: "300px", objectFit: "contain" }}
          />
        </div>

        <nav className="sl-nav">
          {navItems.map(item => (
            <NavLink
              key={item.to}
              to={item.to}
              end={item.end}
              className={({ isActive }) => `sl-nav-item ${isActive ? "active" : ""}`}
            >
              <span className="sl-nav-icon">{item.icon}</span>
              {item.label}
            </NavLink>
          ))}
        </nav>

        <div className="sl-sidebar-bottom">
          <div className="sl-clock">{clock}</div>
          <button className="sl-logout-btn" onClick={handleLogout}>
            <LogOut size={13} />
            LOGOUT
          </button>
        </div>
      </aside>

      {/* ── Main ── */}
      <div className="sl-main">
        <header className="sl-topbar">
          <button
            className={`sl-hamburger ${sidebarOpen ? "open" : ""}`}
            onClick={() => setSidebarOpen(o => !o)}
            aria-label="Toggle menu"
          >
            <span /><span /><span />
          </button>
          <div className="sl-topbar-left">
            <div className="sl-topbar-brand">STAFF</div>
          </div>
          <div className="sl-topbar-right">
            {pageActions.map((action, i) => (
              <button
                key={i}
                className={`sl-btn ${action.cls}`}
                onClick={() => handleAction(action.action)}
              >
                {action.label}
              </button>
            ))}
            <div className="sl-user-chip">
              <div className="sl-user-avatar">
                {user?.name?.charAt(0)?.toUpperCase() ?? "S"}
              </div>
              <div>
                <span className="sl-user-name">{user?.name ?? "Staff"}</span>
                <span className="sl-user-role">{roleLabel}</span>
              </div>
            </div>
          </div>
        </header>

        <main className="sl-content">
          <Outlet />
        </main>
      </div>

    </div>
  );
}