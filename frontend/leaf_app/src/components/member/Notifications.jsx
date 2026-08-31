import { useState, useEffect, useRef } from "react";
import { useOutletContext, useNavigate } from "react-router-dom";
import {
  CalendarClock, Megaphone, CheckCircle2, XCircle,
  Trophy, Settings, AlertTriangle, Bell, Clock, X,
  Smartphone, CreditCard, PiggyBank, FileText, CheckCheck,
  MapPin, Wallet, Check,
} from "lucide-react";
import { getAnnouncementsAPI }              from "../../api/announcements";
import { getLoansAPI, getGCashRequestsAPI } from "../../api/loans";
import { getPaymentsAPI }                   from "../../api/payments";
import { getMyApplicationAPI, getMyOnlineAppAPI, getMemberSavingsAPI, getMemberShareCapitalAPI } from "../../api/members";
import { useAuth }                          from "../../context/AuthContext";
import { useLanguage }                      from "../../context/LanguageContext";
import "./Notifications.css";

const TYPE_META = {
  due:             { icon:<CalendarClock size={20} color="#e65100"/>, key:"nf_type_due",        bg:"#fff8e1", border:"#ffe082", text:"#e65100" },
  notice:          { icon:<Megaphone     size={20} color="#1565c0"/>, key:"nf_type_notice",      bg:"#e3f2fd", border:"#90caf9", text:"#1565c0" },
  approved:        { icon:<CheckCircle2  size={20} color="#1b5e20"/>, key:"nf_type_approved",    bg:"#e8f5e9", border:"#a5d6a7", text:"#1b5e20" },
  pending_release: { icon:<Wallet        size={20} color="#e65100"/>, key:"nf_type_pending_release", bg:"#fff8e1", border:"#ffe082", text:"#e65100" },
  rejected:        { icon:<XCircle       size={20} color="#c62828"/>, key:"nf_type_rejected",    bg:"#ffebee", border:"#ef9a9a", text:"#c62828" },
  membership:      { icon:<Trophy        size={20} color="#1b5e20"/>, key:"nf_type_membership",  bg:"#e8f5e9", border:"#a5d6a7", text:"#1b5e20" },
  system:          { icon:<Settings      size={20} color="#555"/>,    key:"nf_type_system",      bg:"#f5f5f5", border:"#e0e0e0", text:"#555"    },
  overdue:         { icon:<AlertTriangle size={20} color="#c62828"/>, key:"nf_type_overdue",     bg:"#ffebee", border:"#ef9a9a", text:"#c62828" },
  gcash:           { icon:<Smartphone    size={20} color="#007bff"/>, key:"nf_type_gcash",       bg:"#e3f2fd", border:"#90caf9", text:"#007bff" },
  payment:         { icon:<CreditCard    size={20} color="#2e7d32"/>, key:"nf_type_payment",     bg:"#e8f5e9", border:"#a5d6a7", text:"#2e7d32" },
  savings:         { icon:<PiggyBank     size={20} color="#e65100"/>, key:"nf_type_savings",     bg:"#fff8e1", border:"#ffe082", text:"#e65100" },
  sharecap:        { icon:<Wallet        size={20} color="#6a1b9a"/>, key:"nf_type_sharecap",    bg:"#f3e5f5", border:"#ce93d8", text:"#6a1b9a" },
  loan:            { icon:<FileText      size={20} color="#1565c0"/>, key:"nf_type_loan",        bg:"#e3f2fd", border:"#90caf9", text:"#1565c0" },
  completed:       { icon:<CheckCheck    size={20} color="#1565c0"/>, key:"nf_type_completed",   bg:"#e3f2fd", border:"#90caf9", text:"#1565c0" },
};
function getTypeMeta(type, t) {
  const m = TYPE_META[type] || TYPE_META.system;
  return { ...m, label: t(m.key) };
}

const FILTER_DEFS = [
  ["All",           "nf_filter_all"],
  ["Unread",        "nf_filter_unread"],
  ["Loans",         "nf_filter_loans"],
  ["Payments",      "nf_filter_payments"],
  ["GCash",         "nf_filter_gcash"],
  ["Savings",       "nf_filter_savings"],
  ["Share Capital", "nf_filter_sharecap"],
  ["Announcements", "nf_filter_announcements"],
  ["Membership",    "nf_filter_membership"],
  ["System",        "nf_filter_system"],
];

function parseApiDate(dateStr) {
  if (!dateStr) return null;
  const normal = new Date(dateStr);
  if (isNaN(normal.getTime())) return null;

  const twoMinFromNow = Date.now() + 2 * 60000;
  if (normal.getTime() <= twoMinFromNow) return normal;

  const hasTimezone = /Z$|[+-]\d{2}:?\d{2}$/.test(dateStr.trim());
  if (!hasTimezone) {
    const asUtc = new Date(`${dateStr}Z`);
    if (!isNaN(asUtc.getTime()) && asUtc.getTime() <= twoMinFromNow) return asUtc;
  }
  return normal;
}

function dueLabel(dueDateStr) {
  if (!dueDateStr) return "Upcoming";
  const due   = new Date(`${dueDateStr}T00:00:00`);
  const today = new Date();
  today.setHours(0,0,0,0);
  const diffDays = Math.round((due - today) / 86400000);
  if (diffDays < 0)  return `Was due ${Math.abs(diffDays)} day${Math.abs(diffDays)!==1?"s":""} ago`;
  if (diffDays === 0) return "Due today";
  if (diffDays === 1) return "Due tomorrow";
  return `Due in ${diffDays} days`;
}

function timeAgo(dateStr, t) {
  if (!dateStr) return "";
  const parsed = parseApiDate(dateStr);
  if (!parsed) return "";
  const diff = Date.now() - parsed.getTime();
  const mins = Math.floor(diff / 60000);
  const hrs  = Math.floor(diff / 3600000);
  const days = Math.floor(diff / 86400000);
  if (mins < 1)  return t("ma_just_now");
  if (mins < 60) return t("ma_mins_ago", { n: mins });
  if (hrs  < 24) return t("ma_hours_ago", { n: hrs });
  if (days < 7)  return t("ma_days_ago", { n: days });
  return parsed.toLocaleDateString("en-PH", { month:"short", day:"numeric" });
}

// ══════════════════════════════════════════════════════════════════════════
// BAGO: hiwalay na function — kinukuha lang ang RAW na API results (na
// naka-imbak na sa memory, hindi na kailangang i-fetch ulit sa network)
// at yun lang ang isina-salin papuntang notification objects gamit ang
// kasalukuyang `t`. Dating naka-halo ang fetching (network calls) at ang
// translation sa iisang function, kaya kapag nag-toggle ng language,
// wala talagang nangyayari (walang re-fetch trigger), o kung mag-navigate
// palayo't balik, kailangan pang hintayin ulit ang 7 API calls bago
// makita ang bagong wika. Ngayon: sabay na fetch + build sa unang pag-
// load, pero kapag nag-toggle lang ng language, dito na lang tatawag
// gamit ang cached raw data — instant, walang network. ─────────────────
// ══════════════════════════════════════════════════════════════════════════
function buildNotifsFromRaw(raw, t) {
  const {
    user, isUser,
    appResult, annResult, loansResult, paymentsResult,
    gcashResult, savingsResult, sharecapResult,
  } = raw;

  const built = [];

  built.push({
    id:"welcome-system", type:"system",
    title:t("nf_welcome_title"),
    msg:t("nf_welcome_msg", { name: user?.name || "Member" }),
    time:t("ma_just_now"), date:raw.fetchedAt, read:false, route:null,
  });
  if (isUser) {
    built.push({
      id:"system-info-portal", type:"system",
      title:t("nf_portal_info_title"),
      msg:t("nf_portal_info_msg"),
      time:t("ma_just_now"), date:raw.fetchedAt, read:false, route:null,
    });
  }

  let hasApplication = false;
  if (appResult.status === "fulfilled" && appResult.value) {
    const app = appResult.value;
    if (app?.application_status === "Approved") {
      hasApplication = true;
      built.push({
        id:"membership-approved", type:"membership",
        title:t("nf_mem_approved_title"),
        msg:t("nf_mem_approved_msg", { id: app.app_id }),
        requirements:[
          t("nf_req_1"), t("nf_req_2"), t("nf_req_3"), t("nf_req_4"), t("nf_req_5"),
        ],
        highlight:t("nf_office_hours"),
        time:timeAgo(app.reviewed_at || app.created_at, t), date:app.reviewed_at || app.created_at,
        read:false, route:"/member/apply-membership", actionLabel:t("nf_action_view_requirements"),
      });
    } else if (app?.application_status === "Rejected") {
      hasApplication = true;
      built.push({
        id:"membership-rejected", type:"rejected",
        title:t("nf_mem_rejected_title"),
        msg:t("nf_mem_rejected_msg", { id: app.app_id, reason: app.reject_reason ? t("nf_reason_suffix", { reason: app.reject_reason }) : "" }),
        time:timeAgo(app.reviewed_at || app.created_at, t), date:app.reviewed_at || app.created_at,
        read:false, route:"/member/apply-membership", actionLabel:t("nf_action_reapply"),
      });
    } else if (app?.application_status === "Pending") {
      hasApplication = true;
      built.push({
        id:"membership-pending", type:"system",
        title:t("nf_mem_pending_title"),
        msg:t("nf_mem_pending_msg", { id: app.app_id }),
        time:timeAgo(app.created_at, t), date:app.created_at, read:false, route:null,
      });
    }
  }
  if (isUser && !hasApplication) {
    built.push({
      id:"no-application", type:"membership",
      title:t("nf_no_app_title"),
      msg:t("nf_no_app_msg", { name: user?.name || "there" }),
      time:t("ma_just_now"), date:raw.fetchedAt,
      read:false, route:"/member/apply-membership", actionLabel:t("nf_action_apply_membership"),
    });
  }

  if (annResult.status === "fulfilled" && Array.isArray(annResult.value)) {
    annResult.value.slice(0, 10).forEach(a => built.push({
      id:`ann-${a.id}`, type:"notice",
      title:a.title,
      msg:a.body || a.caption || a.content || "—",
      time:timeAgo(a.created_at || a.posted_at, t), date:a.created_at || a.posted_at,
      read:false, route:"/member/announcements", actionLabel:t("nf_action_view_announcement"),
    }));
  }

  if (!isUser) {
    if (loansResult.status === "fulfilled" && Array.isArray(loansResult.value)) {
      const allLoans = loansResult.value;

      allLoans.filter(l => l.status === "Overdue").forEach(l => built.push({
        id:`overdue-${l.id}`, type:"overdue",
        title:t("nf_overdue_title", { id: l.loan_id }),
        msg:t("nf_overdue_msg", { type: l.loan_type }),
        details:[[t("nf_detail_loan_id"), l.loan_id], [t("nf_detail_balance"), `₱${Number(l.balance).toLocaleString()}`], [t("nf_detail_due_date"), l.next_due_date || "—"]],
        time:timeAgo(l.next_due_date, t), date:l.next_due_date,
        read:false, route:"/member/my-loans", actionLabel:t("nf_action_pay_now"),
      }));

      allLoans.filter(l => l.status === "Approved").forEach(l => built.push({
        id:`pending-release-${l.id}`, type:"pending_release",
        title:t("nf_loan_approved_title", { id: l.loan_id }),
        msg:t("nf_pending_release_msg", { type: l.loan_type }),
        details:[[t("nf_detail_loan_id"), l.loan_id], [t("nf_detail_amount"), `₱${Number(l.amount).toLocaleString()}`]],
        time:timeAgo(l.approved_at, t), date:l.approved_at,
        read:false, route:"/member/my-loans", actionLabel:t("nf_action_view_my_loans"),
      }));

      allLoans.filter(l => l.status === "Active").forEach(l => {
        if (l.next_due_date) {
          const due   = new Date(`${l.next_due_date}T00:00:00`);
          const today = new Date(); today.setHours(0,0,0,0);
          const diffDays = Math.round((due - today) / 86400000);
          if (diffDays <= 3) {
            built.push({
              id:`due-${l.id}`, type:"due",
              title:t("nf_reminder_title", { id: l.loan_id }),
              msg:t("nf_reminder_msg", { type: l.loan_type }),
              details:[[t("nf_detail_loan_id"), l.loan_id], [t("nf_detail_amount_due"), `₱${Number(l.monthly_due).toLocaleString()}`], [t("nf_detail_due_date"), l.next_due_date || "—"]],
              time:dueLabel(l.next_due_date), date:l.approved_at || l.next_due_date,
              read:false, route:"/member/my-loans", actionLabel:t("nf_action_view_my_loans"),
            });
          }
        }
        built.push({
          id:`approved-${l.id}`, type:"approved",
          title:t("nf_loan_approved_title", { id: l.loan_id }),
          msg:t("nf_loan_approved_msg", { type: l.loan_type }),
          details:[[t("nf_detail_loan_id"), l.loan_id], [t("nf_detail_amount"), `₱${Number(l.amount).toLocaleString()}`], [t("nf_detail_monthly_due"), `₱${Number(l.monthly_due).toLocaleString()}`]],
          time:timeAgo(l.approved_at, t), date:l.approved_at,
          read:false, route:"/member/my-loans", actionLabel:t("nf_action_view_loan_details"),
        });
      });

      allLoans.filter(l => l.status === "For Review").forEach(l => built.push({
        id:`forreview-${l.id}`, type:"loan",
        title:t("nf_forreview_title", { id: l.loan_id }),
        msg:t("nf_forreview_msg", { type: l.loan_type }),
        details:[[t("nf_detail_loan_id"), l.loan_id], [t("nf_detail_amount"), `₱${Number(l.amount).toLocaleString()}`]],
        time:timeAgo(l.applied_at, t), date:l.applied_at,
        read:false, route:"/member/my-loans", actionLabel:t("nf_action_view_status"),
      }));

      allLoans.filter(l => l.status === "Declined").forEach(l => built.push({
        id:`declined-${l.id}`, type:"rejected",
        title:t("nf_declined_title", { id: l.loan_id }),
        msg:t("nf_declined_msg", { type: l.loan_type, reason: l.decline_reason ? t("nf_reason_suffix", { reason: l.decline_reason }) : "" }),
        details:[[t("nf_detail_loan_id"), l.loan_id], [t("nf_detail_amount"), `₱${Number(l.amount).toLocaleString()}`]],
        time:timeAgo(l.applied_at, t), date:l.applied_at,
        read:false, route:"/member/my-loans", actionLabel:t("nf_action_view_my_loans"),
      }));

      allLoans.filter(l => l.status === "Completed").forEach(l => built.push({
        id:`completed-${l.id}`, type:"completed",
        title:t("nf_completed_title", { id: l.loan_id }),
        msg:t("nf_completed_msg", { type: l.loan_type }),
        details:[[t("nf_detail_loan_id"), l.loan_id], [t("nf_detail_amount"), `₱${Number(l.amount).toLocaleString()}`]],
        time:timeAgo(l.approved_at, t), date:l.approved_at,
        read:false, route:"/member/my-loans", actionLabel:t("nf_action_view_history"),
      }));
    }

    if (paymentsResult.status === "fulfilled" && Array.isArray(paymentsResult.value)) {
      paymentsResult.value.slice(0, 5).forEach(p => built.push({
        id:`payment-${p.id || p.tx_id}`, type:"payment",
        title:t("nf_payment_title", { amt: `₱${Number(p.amount).toLocaleString()}` }),
        msg:t("nf_payment_msg"),
        details:[[t("nf_detail_loan"), p.loan_code], [t("nf_detail_tx_id"), p.tx_id], [t("nf_detail_amount_paid"), `₱${Number(p.amount).toLocaleString()}`], [t("nf_detail_remaining_balance"), `₱${Number(p.balance).toLocaleString()}`]],
        time:timeAgo(p.paid_at, t), date:p.paid_at,
        read:false, route:"/member/my-loans", actionLabel:t("nf_action_view_payment_history"),
      }));
    }

    if (gcashResult.status === "fulfilled" && Array.isArray(gcashResult.value)) {
      gcashResult.value.forEach(r => {
        const effectiveDate = r.verified_at || r.created_at;
        if (r.status === "Verified") {
          built.push({
            id:`gcash-verified-${r.id}`, type:"gcash",
            title:t("nf_gcash_verified_title"),
            msg:t("nf_gcash_verified_msg"),
            details:[[t("nf_detail_loan"), r.loan_id], [t("nf_detail_reference_no"), r.reference_number], [t("nf_detail_amount"), `₱${Number(r.amount).toLocaleString()}`]],
            time:timeAgo(effectiveDate, t), date:effectiveDate,
            read:false, route:"/member/my-loans", actionLabel:t("nf_action_view_payment"),
          });
        } else if (r.status === "Rejected") {
          built.push({
            id:`gcash-rejected-${r.id}`, type:"gcash",
            title:t("nf_gcash_rejected_title"),
            msg:t("nf_gcash_rejected_msg", { reason: r.reject_reason ? t("nf_reason_suffix", { reason: r.reject_reason }) : "" }),
            details:[[t("nf_detail_loan"), r.loan_id], [t("nf_detail_reference_no"), r.reference_number], [t("nf_detail_amount"), `₱${Number(r.amount).toLocaleString()}`]],
            time:timeAgo(effectiveDate, t), date:effectiveDate,
            read:false, route:"/member/my-loans", actionLabel:t("nf_action_resubmit"),
          });
        } else if (r.status === "Pending") {
          built.push({
            id:`gcash-pending-${r.id}`, type:"gcash",
            title:t("nf_gcash_pending_title"),
            msg:t("nf_gcash_pending_msg"),
            details:[[t("nf_detail_loan"), r.loan_id], [t("nf_detail_reference_no"), r.reference_number], [t("nf_detail_amount"), `₱${Number(r.amount).toLocaleString()}`]],
            time:timeAgo(r.created_at, t), date:r.created_at,
            read:false, route:"/member/my-loans", actionLabel:t("nf_action_view_my_loans"),
          });
        }
      });
    }

    if (savingsResult.status === "fulfilled" && savingsResult.value?.transactions?.length > 0) {
      savingsResult.value.transactions.slice(0, 3).forEach((tx, i) => {
        const typeLabel = tx.transaction_type === "Deposit" ? t("nf_txn_deposit") : tx.transaction_type === "Withdraw" ? t("nf_txn_withdraw") : tx.transaction_type;
        built.push({
          id:`savings-${tx.id || i}`, type:"savings",
          title:t("nf_savings_title", { type: typeLabel, amt: `₱${Number(tx.amount).toLocaleString()}` }),
          msg:t("nf_savings_msg", { type: typeLabel.toLowerCase() }),
          details:[[t("nf_detail_amount"), `₱${Number(tx.amount).toLocaleString()}`], [t("nf_detail_new_balance"), `₱${Number(tx.balance_after).toLocaleString()}`], ...(tx.note ? [[t("nf_detail_note"), tx.note]] : [])],
          time:timeAgo(tx.created_at, t), date:tx.created_at,
          read:false, route:"/member/dashboard", actionLabel:t("nf_action_view_dashboard"),
        });
      });
    }

    if (sharecapResult.status === "fulfilled" && Array.isArray(sharecapResult.value)) {
      sharecapResult.value.slice(0, 3).forEach((tItem, i) => {
        const typeLabel = tItem.txn_type || "Deposit";
        built.push({
          id:`sharecap-${tItem.id || i}`, type:"sharecap",
          title:t("nf_sharecap_title", { type: typeLabel, amt: `₱${Number(tItem.amount).toLocaleString()}` }),
          msg:t("nf_sharecap_msg", { type: typeLabel.toLowerCase() }),
          details:[[t("nf_detail_amount"), `₱${Number(tItem.amount).toLocaleString()}`], [t("nf_detail_new_balance"), `₱${Number(tItem.balance_after).toLocaleString()}`], [t("nf_detail_max_loanable"), `₱${(Number(tItem.balance_after)*2).toLocaleString()}`], ...(tItem.note ? [[t("nf_detail_note"), tItem.note]] : [])],
          time:timeAgo(tItem.created_at, t), date:tItem.created_at,
          read:false, route:"/member/dashboard", actionLabel:t("nf_action_view_dashboard"),
        });
      });
    }
  }

  return built;
}

// ─── Notification Detail Modal ─────────────────────────────────────────────
function NotifModal({ notif, onClose, onNavigate }) {
  const { t } = useLanguage();
  if (!notif) return null;
  const meta = getTypeMeta(notif.type, t);
  return (
    <div className="nf-modal-overlay" onClick={onClose}>
      <div className="nf-modal-box" onClick={e => e.stopPropagation()}>
        <div className="nf-modal-header">
          <div className="nf-modal-icon-wrap" style={{ background:meta.bg, borderColor:meta.border }}>
            <span style={{transform:"scale(1.3)"}}>{meta.icon}</span>
          </div>
          <div className="nf-modal-header-info">
            <div className="nf-modal-type-badge" style={{ background:meta.bg, color:meta.text, border:`1px solid ${meta.border}` }}>
              {meta.label}
            </div>
            <div className="nf-modal-time"><Clock size={12}/> {notif.time}</div>
          </div>
          <button className="nf-modal-close" onClick={onClose}><X size={16}/></button>
        </div>

        <div className="nf-modal-body">
          <div className="nf-modal-title">{notif.title}</div>

          <div className="nf-modal-msg-card">
            <div className="nf-modal-msg">{notif.msg}</div>
          </div>

          {notif.requirements && notif.requirements.length > 0 && (
            <div className="nf-modal-req-box">
              <div className="nf-modal-req-title">{t("nf_requirements_title")}</div>
              {notif.requirements.map((r, i) => (
                <div key={i} className="nf-modal-req-item">
                  <div className="nf-modal-req-check"><Check size={11} color="#fff"/></div>
                  <div className="nf-modal-req-text">{r}</div>
                </div>
              ))}
            </div>
          )}

          {notif.highlight && (
            <div className="nf-modal-highlight">
              <MapPin size={15} color="#1565c0" style={{flexShrink:0,marginTop:1}}/>
              <div className="nf-modal-highlight-text">{notif.highlight}</div>
            </div>
          )}

          {notif.details && notif.details.length > 0 && (
            <div className="nf-modal-details">
              {notif.details.map(([k, v], i) => (
                <div key={i} className="nf-modal-detail-row">
                  <span className="nf-modal-detail-key">{k}</span>
                  <span className="nf-modal-detail-val">{v}</span>
                </div>
              ))}
            </div>
          )}
        </div>

        <div className="nf-modal-footer">
          <button className="nf-modal-btn-close" onClick={onClose}>{t("nf_close")}</button>
          {notif.route && (
            <button className="nf-modal-btn-go" onClick={() => { onClose(); onNavigate(notif.route); }}>
              {notif.actionLabel}  →
            </button>
          )}
        </div>
      </div>
    </div>
  );
}

// ── FIX: naka-scope na ngayon per-account ang parehong keys (dating
// fixed/shared ang keys na 'to) — kaya kahit magpalit ng account sa
// parehong browser/tab, hindi na maghahalo ang read-status at cached
// notification list ng magkaibang users. ────────────────────────────
const STORAGE_KEY_BASE = "leaf_read_notifs";
function getReadIds(scopeKey) { try { return new Set(JSON.parse(localStorage.getItem(`${STORAGE_KEY_BASE}_${scopeKey ?? "anon"}`) || "[]")); } catch { return new Set(); } }
function saveReadIds(scopeKey, ids) { try { localStorage.setItem(`${STORAGE_KEY_BASE}_${scopeKey ?? "anon"}`, JSON.stringify([...ids])); } catch {} }

const CACHE_KEY_BASE = "leaf_notifs_cache";
function getCachedNotifs(scopeKey) {
  try {
    const raw = sessionStorage.getItem(`${CACHE_KEY_BASE}_${scopeKey ?? "anon"}`);
    if (!raw) return null;
    const parsed = JSON.parse(raw);
    return Array.isArray(parsed) ? parsed : null;
  } catch { return null; }
}
function saveCachedNotifs(scopeKey, notifs) {
  try { sessionStorage.setItem(`${CACHE_KEY_BASE}_${scopeKey ?? "anon"}`, JSON.stringify(notifs)); } catch {}
}

export default function Notifications() {
  const ctx           = useOutletContext() || {};
  const { setNotif, member } = ctx;
  const navigate      = useNavigate();
  const { user }      = useAuth();
  const { t, language } = useLanguage();
  const isUser        = user?.role === "user";
  // ── BAGO: scope key para hindi maghalo ang read-status/cache ng
  // magkaibang accounts sa parehong browser. ──────────────────────────
  const scopeKey = user?.id ?? user?.username ?? null;

  const cachedNotifs  = getCachedNotifs(scopeKey);
  const [notifs,   setNotifs]  = useState(cachedNotifs || []);
  const [loading,  setLoading] = useState(!cachedNotifs);
  const [filter,   setFilter]  = useState("All");
  const [selected, setSelected]= useState(null);
  const [readIds,  setReadIds] = useState(() => getReadIds(scopeKey));

  // ── BAGO: hawak dito ang RAW (untranslated) na resulta ng huling
  // successful fetch — ginagamit ng language-toggle effect sa ibaba
  // para instant na mag-rebuild nang walang bagong network calls. ────
  const rawRef = useRef(null);

  const finalizeAndSet = (built) => {
    built.sort((a, b) => (parseApiDate(b.date)?.getTime() || 0) - (parseApiDate(a.date)?.getTime() || 0));
    const currentReadIds = getReadIds(scopeKey);
    const withRead = built.map(n => ({ ...n, read: n.read || currentReadIds.has(n.id) }));
    setNotifs(withRead);
    saveCachedNotifs(scopeKey, withRead);
    if (setNotif) setNotif(withRead.filter(n => !n.read).length);
  };

  // ── Fetch (mount / user o member pagbabago lang) ────────────────────
  useEffect(() => {
    const fetchAndBuild = async () => {
      if (!getCachedNotifs(scopeKey)) setLoading(true);
      try {
        const [
          appResult, annResult, loansResult, paymentsResult,
          gcashResult, savingsResult, sharecapResult,
        ] = await Promise.allSettled([
          isUser ? getMyOnlineAppAPI() : getMyApplicationAPI(),
          getAnnouncementsAPI(),
          !isUser ? getLoansAPI() : Promise.resolve(null),
          !isUser ? getPaymentsAPI() : Promise.resolve(null),
          !isUser ? getGCashRequestsAPI() : Promise.resolve(null),
          (!isUser && member?.id) ? getMemberSavingsAPI(member.id) : Promise.resolve(null),
          (!isUser && member?.id) ? getMemberShareCapitalAPI(member.id) : Promise.resolve(null),
        ]);

        // ── I-save ang RAW results — dito na lang babalik ang
        // language-toggle effect sa halip na mag-fetch ulit. ────────
        rawRef.current = {
          user, isUser, fetchedAt: new Date().toISOString(),
          appResult, annResult, loansResult, paymentsResult,
          gcashResult, savingsResult, sharecapResult,
        };

        finalizeAndSet(buildNotifsFromRaw(rawRef.current, t));
      } catch(e) { console.error(e); }
      finally { setLoading(false); }
    };
    fetchAndBuild();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isUser, member?.id]);

  // ── BAGO: language toggle lang — muling i-translate gamit ang
  // CACHED na raw data, walang bagong network calls, instant. ─────────
  useEffect(() => {
    if (!rawRef.current) return; // hihintayin muna ang unang fetch
    finalizeAndSet(buildNotifsFromRaw(rawRef.current, t));
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [language]);

  const unreadCount = notifs.filter(n => !n.read).length;

  // ── FIX: dating basta na lang sinusulat ang `notifs.map(id)` (kasalu-
  // kuyang list lang) papunta sa localStorage — kung may dating na-basa
  // nang notification na wala na sa kasalukuyang build (hal. lumang
  // announcement na lumabas na sa window), nabubura ang record nito.
  // Ngayon: sariwang kinukuha muna ang laman ng localStorage bago i-
  // merge — hindi na kailanman nag-o-overwrite, laging nagme-merge. ───
  const markAllRead = () => {
    const allIds = new Set([...getReadIds(scopeKey), ...notifs.map(n => n.id)]);
    saveReadIds(scopeKey, allIds);
    setReadIds(allIds);
    setNotifs(prev => prev.map(n => ({ ...n, read: true })));
    if (setNotif) setNotif(0);
  };

  // ── FIX: parehong dahilan — ang `readIds` (React state) ay puwedeng
  // maging luma kumpara sa localStorage (hal. kung dalawang tabs ng
  // parehong account ang bukas, magkaiba ang state ng bawat isa pero
  // parehong localStorage). Kung gagamitin ang lumang state bilang
  // batayan sa pag-save, mabubura ang mga bagong idinagdag sa ibang
  // tab. Laging kumukuha na lang ngayon ng SARIWANG copy mula sa
  // localStorage bago i-merge, hindi na yung potensyal na lumang
  // `readIds` state. ───────────────────────────────────────────────
  const handleClick = (notif) => {
    const newReadIds = new Set([...getReadIds(scopeKey), notif.id]);
    saveReadIds(scopeKey, newReadIds);
    setReadIds(newReadIds);
    setNotifs(prev => prev.map(n => n.id === notif.id ? { ...n, read: true } : n));
    if (setNotif) setNotif(notifs.filter(n => !n.read && n.id !== notif.id).length);
    setSelected({ ...notif, read: true });
  };

  const filtered = notifs.filter(n => {
    if (filter === "All")           return true;
    if (filter === "Unread")        return !n.read;
    if (filter === "Loans")         return ["loan","approved","pending_release","rejected","overdue","due","completed"].includes(n.type);
    if (filter === "Payments")      return n.type === "payment";
    if (filter === "GCash")         return n.type === "gcash";
    if (filter === "Savings")       return n.type === "savings";
    if (filter === "Share Capital") return n.type === "sharecap";
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
          <div className="nf-page-title">{t("nf_page_title")}</div>
          <div className="nf-page-sub">{t("nf_page_sub")}</div>
        </div>
        {unreadCount > 0 && (
          <button className="nf-mark-all-btn" onClick={markAllRead}>
            <CheckCircle2 size={13}/> {t("nf_mark_all_read")}
          </button>
        )}
      </div>

      <div className="nf-filter-tabs">
        {FILTER_DEFS.map(([f, labelKey]) => (
          <button key={f} className={`nf-filter-tab ${filter === f ? "active" : ""}`} onClick={() => setFilter(f)}>
            {t(labelKey)}
            {f === "Unread" && unreadCount > 0 && <span className="nf-filter-count">{unreadCount}</span>}
          </button>
        ))}
      </div>

      <div className="nf-card">
        {loading ? (
          <div className="nf-empty">
            <div className="nf-empty-icon"><Clock size={36} color="#ccc"/></div>
            <div className="nf-empty-text">{t("nf_loading")}</div>
          </div>
        ) : filtered.length === 0 ? (
          <div className="nf-empty">
            <div className="nf-empty-icon"><Bell size={36} color="#ccc"/></div>
            <div className="nf-empty-text">{t("nf_empty")}</div>
          </div>
        ) : filtered.map(n => {
          const meta = getTypeMeta(n.type, t);
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