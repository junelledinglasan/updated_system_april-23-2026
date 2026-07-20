import { useState, useEffect } from "react";
import { useOutletContext, useNavigate } from "react-router-dom";
import {
  CalendarClock, Megaphone, CheckCircle2, XCircle,
  Trophy, Settings, AlertTriangle, Bell, Clock, X,
  Smartphone, CreditCard, PiggyBank, FileText, CheckCheck,
} from "lucide-react";
import { getAnnouncementsAPI }              from "../../api/announcements";
import { getLoansAPI, getGCashRequestsAPI } from "../../api/loans";
import { getPaymentsAPI }                   from "../../api/payments";
import { getMyApplicationAPI, getMyOnlineAppAPI, getMemberSavingsAPI } from "../../api/members";
import { useAuth }                          from "../../context/AuthContext";
import "./Notifications.css";

const TYPE_META = {
  due:        { icon:<CalendarClock size={20} color="#e65100"/>, label:"Payment Due",       bg:"#fff8e1", border:"#ffe082", text:"#e65100" },
  notice:     { icon:<Megaphone     size={20} color="#1565c0"/>, label:"Announcement",      bg:"#e3f2fd", border:"#90caf9", text:"#1565c0" },
  approved:   { icon:<CheckCircle2  size={20} color="#1b5e20"/>, label:"Approved",          bg:"#e8f5e9", border:"#a5d6a7", text:"#1b5e20" },
  rejected:   { icon:<XCircle       size={20} color="#c62828"/>, label:"Rejected",          bg:"#ffebee", border:"#ef9a9a", text:"#c62828" },
  membership: { icon:<Trophy        size={20} color="#1b5e20"/>, label:"Membership",        bg:"#e8f5e9", border:"#a5d6a7", text:"#1b5e20" },
  system:     { icon:<Settings      size={20} color="#555"/>,    label:"System",            bg:"#f5f5f5", border:"#e0e0e0", text:"#555"    },
  overdue:    { icon:<AlertTriangle size={20} color="#c62828"/>, label:"Overdue",           bg:"#ffebee", border:"#ef9a9a", text:"#c62828" },
  gcash:      { icon:<Smartphone    size={20} color="#007bff"/>, label:"GCash Payment",     bg:"#e3f2fd", border:"#90caf9", text:"#007bff" },
  payment:    { icon:<CreditCard    size={20} color="#2e7d32"/>, label:"Payment Recorded",  bg:"#e8f5e9", border:"#a5d6a7", text:"#2e7d32" },
  savings:    { icon:<PiggyBank     size={20} color="#e65100"/>, label:"Savings",           bg:"#fff8e1", border:"#ffe082", text:"#e65100" },
  loan:       { icon:<FileText      size={20} color="#1565c0"/>, label:"Loan",              bg:"#e3f2fd", border:"#90caf9", text:"#1565c0" },
  completed:  { icon:<CheckCheck    size={20} color="#1565c0"/>, label:"Loan Completed",    bg:"#e3f2fd", border:"#90caf9", text:"#1565c0" },
};

const FILTERS = ["All","Unread","Loans","Payments","GCash","Savings","Announcements","Membership","System"];

function timeAgo(dateStr) {
  if (!dateStr) return "";
  const diff = Date.now() - new Date(dateStr).getTime();
  const mins = Math.floor(diff / 60000);
  const hrs  = Math.floor(diff / 3600000);
  const days = Math.floor(diff / 86400000);
  if (mins < 1)  return "Just now";
  if (mins < 60) return `${mins} minute${mins !== 1 ? "s" : ""} ago`;
  if (hrs  < 24) return `${hrs} hour${hrs !== 1 ? "s" : ""} ago`;
  if (days < 7)  return `${days} day${days !== 1 ? "s" : ""} ago`;
  return new Date(dateStr).toLocaleDateString("en-PH", { month:"short", day:"numeric" });
}

function NotifModal({ notif, onClose, onNavigate }) {
  if (!notif) return null;
  const meta = TYPE_META[notif.type] || TYPE_META.system;
  return (
    <div className="nf-modal-overlay" onClick={onClose}>
      <div className="nf-modal-box" onClick={e => e.stopPropagation()}>
        <div className="nf-modal-header" style={{ borderBottom:`3px solid ${meta.border}` }}>
          <div className="nf-modal-icon-wrap" style={{ background:meta.bg, borderRadius:12, width:52, height:52, display:"flex", alignItems:"center", justifyContent:"center", flexShrink:0 }}>
            {meta.icon && <span style={{transform:"scale(1.4)"}}>{meta.icon}</span>}
          </div>
          <div className="nf-modal-header-info">
            <div className="nf-modal-type-badge" style={{ background:meta.bg, color:meta.text, border:`1px solid ${meta.border}` }}>
              {meta.label}
            </div>
            <div className="nf-modal-time">{notif.time}</div>
          </div>
          <button className="nf-modal-close" onClick={onClose}><X size={16}/></button>
        </div>
        <div className="nf-modal-body">
          <div className="nf-modal-title">{notif.title}</div>
          <div className="nf-modal-msg">{notif.msg}</div>
        </div>
        <div className="nf-modal-footer">
          <button className="nf-modal-btn-close" onClick={onClose}>Close</button>
          {notif.route && (
            <button className="nf-modal-btn-go" onClick={() => { onClose(); onNavigate(notif.route); }}>
              {notif.actionLabel || "View Details"} →
            </button>
          )}
        </div>
      </div>
    </div>
  );
}

const STORAGE_KEY = "leaf_read_notifs";
function getReadIds() { try { return new Set(JSON.parse(localStorage.getItem(STORAGE_KEY) || "[]")); } catch { return new Set(); } }
function saveReadIds(ids) { try { localStorage.setItem(STORAGE_KEY, JSON.stringify([...ids])); } catch {} }

export default function Notifications() {
  const ctx           = useOutletContext() || {};
  const { setNotif, member } = ctx;
  const navigate      = useNavigate();
  const { user }      = useAuth();
  const isUser        = user?.role === "user";

  const [notifs,   setNotifs]  = useState([]);
  const [loading,  setLoading] = useState(true);
  const [filter,   setFilter]  = useState("All");
  const [selected, setSelected]= useState(null);
  const [readIds,  setReadIds] = useState(getReadIds);

  useEffect(() => {
    const build = async () => {
      setLoading(true);
      try {
        const built = [];

        // ── 1. WELCOME ──────────────────────────────────────────────────────
        built.push({
          id:"welcome-system", type:"system",
          title:"Welcome to LEAF MPC",
          msg:`Hello, ${user?.name || "Member"}! Welcome to the LEAF MPC Management System. Stay updated on your loans, payments, and cooperative news here.`,
          time:"Just now", date:new Date().toISOString(), read:true, route:null,
        });

        if (isUser) {
          built.push({
            id:"system-info-portal", type:"system",
            title:"About the LEAF MPC Portal",
            msg:"Apply for membership, track your application, and view announcements. Full features unlock once you become an official member.",
            time:"Just now", date:new Date().toISOString(), read:true, route:null,
          });
        }

        // ── 2. MEMBERSHIP STATUS ─────────────────────────────────────────────
        let hasApplication = false;
        try {
          const app = isUser ? await getMyOnlineAppAPI() : await getMyApplicationAPI();
          if (app?.application_status === "Approved") {
            hasApplication = true;
            built.push({
              id:"membership-approved", type:"membership",
              title:"Membership Application Approved",
              msg:`Congratulations! Your application (${app.app_id}) has been approved! Please visit the LEAF MPC office to complete your membership. Requirements to bring: (1) 2 pieces 2x2 ID picture, white background (2) Photocopy of Birth Certificate, PSA copy preferred (3) Photocopy of Marriage Certificate, if married — optional (4) Valid Government-issued ID (5) Initial Share Capital Payment, minimum ₱4,000. Office hours: Mon–Fri, 8:00 AM – 5:00 PM, LEAF MPC Office, Lucban, Quezon.`,
              time:timeAgo(app.reviewed_at || app.created_at), date:app.reviewed_at || app.created_at,
              read:false, route:"/member/apply-membership", actionLabel:"View Requirements",
            });
          } else if (app?.application_status === "Rejected") {
            hasApplication = true;
            built.push({
              id:"membership-rejected", type:"rejected",
              title:"Membership Application Not Approved",
              msg:`Your application (${app.app_id}) was not approved.${app.reject_reason ? " Reason: " + app.reject_reason : ""} You may re-apply or visit the office.`,
              time:timeAgo(app.reviewed_at || app.created_at), date:app.reviewed_at || app.created_at,
              read:false, route:"/member/apply-membership", actionLabel:"Re-apply",
            });
          } else if (app?.application_status === "Pending") {
            hasApplication = true;
            built.push({
              id:"membership-pending", type:"system",
              title:"Membership Application Under Review",
              msg:`Your application (${app.app_id}) is currently under review. Thank you for your patience.`,
              time:timeAgo(app.created_at), date:app.created_at, read:true, route:null,
            });
          }
        } catch {}

        if (isUser && !hasApplication) {
          built.push({
            id:"no-application", type:"membership",
            title:"Complete Your Membership Application",
            msg:`Hi ${user?.name || "there"}! You haven't submitted a membership application yet. Apply now to become an official LEAF MPC member.`,
            time:"Just now", date:new Date().toISOString(),
            read:false, route:"/member/apply-membership", actionLabel:"Apply for Membership",
          });
        }

        // ── 3. ANNOUNCEMENTS ─────────────────────────────────────────────────
        try {
          const anns = await getAnnouncementsAPI();
          anns.slice(0, 10).forEach(a => built.push({
            id:`ann-${a.id}`, type:"notice",
            title:a.title,
            msg:a.body || a.caption || a.content || "No content available.",
            time:timeAgo(a.created_at || a.posted_at), date:a.created_at || a.posted_at,
            read:false, route:"/member/announcements", actionLabel:"View Announcement",
          }));
        } catch {}

        // ── 4. LOANS ─────────────────────────────────────────────────────────
        if (!isUser) {
          try {
            const allLoans = await getLoansAPI();

            // Overdue loans
            allLoans.filter(l => l.status === "Overdue").forEach(l => built.push({
              id:`overdue-${l.id}`, type:"overdue",
              title:`⚠ Overdue Payment — ${l.loan_id}`,
              msg:`Your ${l.loan_type} (${l.loan_id}) is OVERDUE with balance ₱${Number(l.balance).toLocaleString()}. Please settle immediately to avoid additional penalties.`,
              time:timeAgo(l.next_due_date), date:l.next_due_date,
              read:false, route:"/member/my-loans", actionLabel:"Pay Now",
            }));

            // Active loans — payment reminder
            allLoans.filter(l => l.status === "Active").forEach(l => built.push({
              id:`due-${l.id}`, type:"due",
              title:`Payment Reminder — ${l.loan_id}`,
              msg:`Your monthly payment of ₱${Number(l.monthly_due).toLocaleString()} for ${l.loan_type} (${l.loan_id}) is due on ${l.next_due_date || "—"}. Pay on time to avoid penalties.`,
              time:timeAgo(l.next_due_date), date:l.next_due_date,
              read:false, route:"/member/my-loans", actionLabel:"View My Loans",
            }));

            // Active loans — approved notification
            allLoans.filter(l => l.status === "Active").forEach(l => built.push({
              id:`approved-${l.id}`, type:"approved",
              title:`Loan Approved — ${l.loan_id}`,
              msg:`Your ${l.loan_type} for ₱${Number(l.amount).toLocaleString()} has been approved and activated. Monthly due: ₱${Number(l.monthly_due).toLocaleString()}. Visit the office to sign documents.`,
              time:timeAgo(l.approved_at), date:l.approved_at,
              read:true, route:"/member/my-loans", actionLabel:"View Loan Details",
            }));

            // For Review loans — submitted, waiting
            allLoans.filter(l => l.status === "For Review").forEach(l => built.push({
              id:`forreview-${l.id}`, type:"loan",
              title:`Loan Application Submitted — ${l.loan_id}`,
              msg:`Your ${l.loan_type} application for ₱${Number(l.amount).toLocaleString()} (${l.loan_id}) has been submitted and is waiting for admin review.`,
              time:timeAgo(l.applied_at), date:l.applied_at,
              read:true, route:"/member/my-loans", actionLabel:"View Status",
            }));

            // Declined loans
            allLoans.filter(l => l.status === "Declined").forEach(l => built.push({
              id:`declined-${l.id}`, type:"rejected",
              title:`Loan Application Declined — ${l.loan_id}`,
              msg:`Your ${l.loan_type} application for ₱${Number(l.amount).toLocaleString()} was declined.${l.decline_reason ? " Reason: " + l.decline_reason : ""} You may re-apply or visit the office.`,
              time:timeAgo(l.applied_at), date:l.applied_at,
              read:false, route:"/member/my-loans", actionLabel:"View My Loans",
            }));

            // Completed loans
            allLoans.filter(l => l.status === "Completed").forEach(l => built.push({
              id:`completed-${l.id}`, type:"completed",
              title:`Loan Fully Paid — ${l.loan_id}`,
              msg:`Congratulations! Your ${l.loan_type} (${l.loan_id}) for ₱${Number(l.amount).toLocaleString()} has been fully paid. Thank you for being a responsible member!`,
              time:timeAgo(l.approved_at), date:l.approved_at,
              read:true, route:"/member/my-loans", actionLabel:"View History",
            }));
          } catch {}

          // ── 5. RECENT PAYMENTS ─────────────────────────────────────────────
          try {
            const payments = await getPaymentsAPI();
            payments.slice(0, 5).forEach(p => built.push({
              id:`payment-${p.id || p.tx_id}`, type:"payment",
              title:`Payment Recorded — ₱${Number(p.amount).toLocaleString()}`,
              msg:`Your payment of ₱${Number(p.amount).toLocaleString()} for loan ${p.loan_code} has been recorded (TX: ${p.tx_id}). Remaining balance: ₱${Number(p.balance).toLocaleString()}.`,
              time:timeAgo(p.paid_at), date:p.paid_at,
              read:true, route:"/member/my-loans", actionLabel:"View Payment History",
            }));
          } catch {}

          // ── 6. GCASH PAYMENT REQUESTS ──────────────────────────────────────
          try {
            const gcashReqs = await getGCashRequestsAPI();
            if (Array.isArray(gcashReqs)) {
              gcashReqs.forEach(r => {
                if (r.status === "Verified") {
                  built.push({
                    id:`gcash-verified-${r.id}`, type:"gcash",
                    title:"GCash Payment Verified",
                    msg:`Your GCash payment of ₱${Number(r.amount).toLocaleString()} for loan ${r.loan_id} (Ref: ${r.reference_number}) has been verified and recorded by admin on ${r.verified_at}.`,
                    time:timeAgo(r.verified_at), date:r.verified_at,
                    read:false, route:"/member/my-loans", actionLabel:"View Payment",
                  });
                } else if (r.status === "Rejected") {
                  built.push({
                    id:`gcash-rejected-${r.id}`, type:"gcash",
                    title:"GCash Payment Not Verified",
                    msg:`Your GCash payment (Ref: ${r.reference_number}, ₱${Number(r.amount).toLocaleString()}) for loan ${r.loan_id} was not verified. Reason: ${r.reject_reason}. Please resubmit with the correct reference number.`,
                    time:timeAgo(r.verified_at), date:r.verified_at,
                    read:false, route:"/member/my-loans", actionLabel:"Resubmit Payment",
                  });
                } else if (r.status === "Pending") {
                  built.push({
                    id:`gcash-pending-${r.id}`, type:"gcash",
                    title:"GCash Payment Pending Verification",
                    msg:`Your GCash payment (Ref: ${r.reference_number}, ₱${Number(r.amount).toLocaleString()}) for loan ${r.loan_id} is waiting for admin verification.`,
                    time:timeAgo(r.created_at), date:r.created_at,
                    read:true, route:"/member/my-loans", actionLabel:"View My Loans",
                  });
                }
              });
            }
          } catch {}

          // ── 7. SAVINGS ────────────────────────────────────────────────────
          try {
            // FIX: dati "me" (literal string) ang ipinapasa dito — palaging
            // 404 kasi ang backend endpoint ay umaasa sa totoong numeric
            // Member ID, hindi sa "me". Gamitin natin ang member.id na
            // galing sa MemberLayout's outlet context.
            if (member?.id) {
              const savings = await getMemberSavingsAPI(member.id);
              if (savings?.transactions?.length > 0) {
                savings.transactions.slice(0, 3).forEach((tx, i) => built.push({
                  id:`savings-${tx.id || i}`, type:"savings",
                  title:`Savings ${tx.transaction_type} — ₱${Number(tx.amount).toLocaleString()}`,
                  msg:`A ${tx.transaction_type.toLowerCase()} of ₱${Number(tx.amount).toLocaleString()} was recorded to your savings.${tx.note ? " Note: " + tx.note : ""} New balance: ₱${Number(tx.balance_after).toLocaleString()}.`,
                  time:timeAgo(tx.created_at), date:tx.created_at,
                  read:true, route:"/member/dashboard", actionLabel:"View Dashboard",
                }));
              }
            }
          } catch {}
        }

        // ── Sort: unread first then by date ──────────────────────────────────
        built.sort((a, b) => {
          if (!a.read && b.read)  return -1;
          if (a.read  && !b.read) return 1;
          return new Date(b.date || 0) - new Date(a.date || 0);
        });

        const currentReadIds = getReadIds();
        const withRead = built.map(n => ({ ...n, read: n.read || currentReadIds.has(n.id) }));
        setNotifs(withRead);
        if (setNotif) setNotif(withRead.filter(n => !n.read).length);
      } catch(e) { console.error(e); }
      finally { setLoading(false); }
    };
    build();
  }, [isUser, member?.id]);

  const unreadCount = notifs.filter(n => !n.read).length;

  const markAllRead = () => {
    const allIds = new Set(notifs.map(n => n.id));
    saveReadIds(allIds);
    setReadIds(allIds);
    setNotifs(prev => prev.map(n => ({ ...n, read: true })));
    if (setNotif) setNotif(0);
  };

  const handleClick = (notif) => {
    const newReadIds = new Set([...readIds, notif.id]);
    saveReadIds(newReadIds);
    setReadIds(newReadIds);
    setNotifs(prev => prev.map(n => n.id === notif.id ? { ...n, read: true } : n));
    if (setNotif) setNotif(notifs.filter(n => !n.read && n.id !== notif.id).length);
    setSelected({ ...notif, read: true });
  };

  const filtered = notifs.filter(n => {
    if (filter === "All")           return true;
    if (filter === "Unread")        return !n.read;
    if (filter === "Loans")         return ["loan","approved","rejected","overdue","due","completed"].includes(n.type);
    if (filter === "Payments")      return n.type === "payment";
    if (filter === "GCash")         return n.type === "gcash";
    if (filter === "Savings")       return n.type === "savings";
    if (filter === "Announcements") return n.type === "notice";
    if (filter === "Membership")    return ["membership","rejected"].includes(n.type);
    if (filter === "System")        return n.type === "system";
    return true;
  });

  return (
    <div className="nf-wrapper">
      {selected && <NotifModal notif={selected} onClose={() => setSelected(null)} onNavigate={navigate}/>}

      <div className="nf-page-header">
        <div>
          <div className="nf-page-title">Notifications</div>
          <div className="nf-page-sub">Stay updated on payments, loans, announcements, and more.</div>
        </div>
        {unreadCount > 0 && (
          <button className="nf-mark-all-btn" onClick={markAllRead}>
            <CheckCircle2 size={13}/> Mark all as read
          </button>
        )}
      </div>

      <div className="nf-summary-row">
        <div className="nf-chip total">  <span>{notifs.length}</span> Total</div>
        <div className="nf-chip unread"> <span>{unreadCount}</span> Unread</div>
        <div className="nf-chip due">    <span>{notifs.filter(n => n.type === "due" || n.type === "overdue").length}</span> Payment Due</div>
        <div className="nf-chip notice"> <span>{notifs.filter(n => n.type === "notice").length}</span> Announcements</div>
      </div>

      <div className="nf-filter-tabs">
        {FILTERS.map(f => (
          <button key={f} className={`nf-filter-tab ${filter === f ? "active" : ""}`} onClick={() => setFilter(f)}>
            {f}
            {f === "Unread" && unreadCount > 0 && <span className="nf-filter-count">{unreadCount}</span>}
          </button>
        ))}
      </div>

      <div className="nf-card">
        {loading ? (
          <div className="nf-empty">
            <div className="nf-empty-icon"><Clock size={36} color="#ccc"/></div>
            <div className="nf-empty-text">Loading notifications...</div>
          </div>
        ) : filtered.length === 0 ? (
          <div className="nf-empty">
            <div className="nf-empty-icon"><Bell size={36} color="#ccc"/></div>
            <div className="nf-empty-text">No notifications</div>
          </div>
        ) : filtered.map(n => {
          const meta = TYPE_META[n.type] || TYPE_META.system;
          return (
            <div key={n.id} className={`nf-item ${!n.read ? "unread" : ""}`} onClick={() => handleClick(n)}>
              <div className="nf-icon-wrap" style={{ background:meta.bg, borderRadius:10, width:40, height:40, minWidth:40, display:"flex", alignItems:"center", justifyContent:"center" }}>
                {meta.icon}
              </div>
              <div className="nf-body">
                <div className="nf-item-header">
                  <div className="nf-item-title">{n.title}</div>
                  <div className="nf-item-time">{n.time}</div>
                </div>
                <div className="nf-item-preview">
                  {n.msg.length > 90 ? n.msg.slice(0, 90) + "..." : n.msg}
                </div>
                {n.route && (
                  <div className="nf-item-action" style={{ color:meta.text }}>
                    {n.actionLabel} →
                  </div>
                )}
              </div>
              {!n.read && <div className="nf-unread-dot"/>}
            </div>
          );
        })}
      </div>
    </div>
  );
}