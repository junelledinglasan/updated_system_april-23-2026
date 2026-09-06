import { useState, useEffect, useRef } from "react";
import { Outlet, NavLink, useNavigate, useLocation } from "react-router-dom";
import { useAuth } from "../context/AuthContext";
import {
  LayoutDashboard, Users, UserCog, FileText,
  CreditCard, CheckSquare, Megaphone, BarChart2,
  GraduationCap, UserRound, BriefcaseBusiness, Smartphone,
  PiggyBank, Landmark
} from "lucide-react";
import { getLoansAPI, createLoanAPI, updateLoanStatusAPI, getGCashRequestsAPI } from "../api/loans";
import { getMembersAPI, registerMemberAPI } from "../api/members";
import { recordPaymentAPI } from "../api/payments";
import { getSystemLogoAPI } from "../api/settings";
import SettingsModal from "../components/admin/SettingsModal";
import { Settings as SettingsIcon, LogOut, ChevronDown } from "lucide-react";
import "./AdminLayout.css";
import logo from '../assets/logo.png';

const CLASS_OPTIONS = [
  { key: "Student",  icon: <GraduationCap     size={32} strokeWidth={1.5} color="#2e7d32"/>, label: "Student"  },
  { key: "Senior",   icon: <UserRound         size={32} strokeWidth={1.5} color="#2e7d32"/>, label: "Senior"   },
  { key: "Employed", icon: <BriefcaseBusiness size={32} strokeWidth={1.5} color="#2e7d32"/>, label: "Employed" },
];

const NAV_ITEMS = [
  { to: "/admin/dashboard",    icon: <LayoutDashboard size={15} />, label: "Dashboard"          },
  { to: "/admin/members",      icon: <Users           size={15} />, label: "Manage Member"      },
  // ── BAGO: dating top-bar buttons lang ito (sa Manage Members page
  // lang lumalabas) — ngayon nasa sidebar na, accessible mula sa
  // KAHIT ANONG page, para madaling mahanap. "action" (hindi "to") —
  // hindi nag-na-navigate, nagbubukas lang ng modal. ──────────────────
  // ── BAGO: dating "action" na buttons (nagbubukas ng modal via
  // state) — ngayon totoong ROUTES na sila, kaya "to" na ang ginamit
  // (NavLink), tulad ng ibang totoong pages — makakakuha na rin sila
  // ng "active" highlighting kapag nandoon ang admin. ──────────────────
  { to: "/admin/savings-deposit",       icon: <PiggyBank size={15} />, label: "Savings/Deposit"       },
  { to: "/admin/share-capital-deposit", icon: <Landmark  size={15} />, label: "Share Capital Deposit" },
  { to: "/admin/staff",        icon: <UserCog         size={15} />, label: "Manage Staff"       },
  { to: "/admin/applications", icon: <FileText        size={15} />, label: "Online Application" },
  { to: "/admin/loan-payment", icon: <CreditCard      size={15} />, label: "Loan Payment"       },
  { to: "/admin/loan-approval",      icon: <CheckSquare size={15}/>, label: "Loan Approval"    },
  { to: "/admin/gcash-verification", icon: <Smartphone  size={15}/>, label: "Online Payments"   },
  { to: "/admin/announcement",       icon: <Megaphone   size={15}/>, label: "Announcement"     },
  { to: "/admin/reports",      icon: <BarChart2       size={15} />, label: "Reports"            },
];

const PAGE_CONFIG = {
  "/admin/dashboard": {
    title: "Office Operations Dashboard",
    sub:   "Manage LEAF MPC member records and financial audits.",
    actions: [
    ],
  },
  "/admin/members": {
    title: "Manage Members",
    sub:   "View, edit, and manage all registered LEAF MPC members.",
    actions: [
      // ── BAGO: inalis ang "Savings/Deposit" at "Share Capital
      // Deposit" dito — nasa sidebar na sila ngayon (tingnan ang
      // NAV_ITEMS), accessible mula sa kahit anong page. ─────────────
      { label: "+ Register Member",          cls: "btn-green",    action: "register"     },
    ],
  },
  "/admin/staff": {
    title: "Manage Staff",
    sub:   "Add and manage staff accounts for office personnel.",
    actions: [],
  },
  "/admin/applications": {
    title: "Online Applications",
    sub:   "Review membership registration applications submitted online.",
    actions: [],
  },
  "/admin/loan-payment": {
    title: "Loan Payment",
    sub:   "Record F2F loan payments collected at the office.",
    actions: [
      { label: "+ New F2F Payment",      cls: "btn-blue",  action: "f2f"     },
      { label: "+ New Loan Application", cls: "btn-green", action: "newloan" },
    ],
  },
  "/admin/loan-approval": {
title: "Loan Approval",
sub:   "Evaluate and process member loan applications.",
actions: [],
},
"/admin/gcash-verification": {
title: "GCash Payment Requests",
sub:   "Verify member GCash payments and record once confirmed.",
actions: [],
},
  "/admin/announcement": {
    title: "Announcements",
    sub:   "Post activities, seminars, and notices to all members.",
    actions: [],
  },
  "/admin/reports": {
    title: "Reports & Analytics",
    sub:   "Financial summaries, loan analytics, and payment behavior reports.",
    actions: [
      { label: "⬇ Export Excel", cls: "btn-outline", action: "export" },
    ],
  },
  // ── BAGO: entries para sa dalawang bagong routes (dating modals). ──
  "/admin/savings-deposit": {
    title: "Savings Transaction",
    sub:   "Record deposits and withdrawals for member savings accounts.",
    actions: [],
  },
  "/admin/share-capital-deposit": {
    title: "Share Capital",
    sub:   "Record share capital deposits for members.",
    actions: [],
  },
};

const DEFAULT_CONFIG = { title: "LEAF MPC Admin", sub: "Cooperative Information System", actions: [] };

// ─── Quick F2F Payment Modal ──────────────────────────────────────────────────
function F2FModal({ onClose }) {
  const [step,     setStep]   = useState(1);
  const [loans,    setLoans]  = useState([]);
  const [selected, setSelect] = useState(null);
  const [amount,   setAmount] = useState("");
  const [note,     setNote]   = useState("");
  const [error,    setError]  = useState("");
  const [done,     setDone]   = useState(false);
  const [loading,  setLoad]   = useState(false);
  const [fetching, setFetch]  = useState(true);
  const [search,   setSearch] = useState("");

  useEffect(() => {
    getLoansAPI({ status: "Active" })
      .then(data => setLoans(data))
      .catch(e => console.error(e))
      .finally(() => setFetch(false));
  }, []);

  const filtered = loans.filter(l =>
    (l.member_name||"").toLowerCase().includes(search.toLowerCase()) ||
    (l.member_code||"").toLowerCase().includes(search.toLowerCase()) ||
    (l.loan_id||"").toLowerCase().includes(search.toLowerCase())
  );

  const parsed  = parseFloat(amount) || 0;
  const balance = parseFloat(selected?.balance || 0);
  const isValid = parsed > 0 && selected && parsed <= balance;

  const handlePay = async () => {
    if (!parsed || parsed <= 0) { setError("Enter a valid amount."); return; }
    if (parsed > balance)       { setError(`Exceeds remaining balance ₱${balance.toLocaleString()}.`); return; }
    setLoad(true);
    try {
      await recordPaymentAPI({ loan: selected.id, member: selected.member, amount: parsed, note });
      setDone(true);
    } catch { setError("Failed to record payment. Please try again."); }
    finally { setLoad(false); }
  };

  if (done) return (
    <div className="al-overlay" onClick={onClose}>
      <div className="al-modal al-modal-sm" onClick={e => e.stopPropagation()}>
        <div className="al-modal-body" style={{alignItems:"center",textAlign:"center",padding:"32px 24px",gap:12}}>
          <div style={{fontSize:40}}>✅</div>
          <div style={{fontSize:15,fontWeight:700,color:"#1b5e20"}}>Payment Recorded!</div>
          <div style={{fontSize:12,color:"#888"}}>
            ₱{parsed.toLocaleString()} payment for <strong>{selected.member_name}</strong> has been saved.
          </div>
        </div>
        <div className="al-modal-footer">
          <button className="al-btn-save" onClick={onClose}>Done</button>
        </div>
      </div>
    </div>
  );

  return (
    <div className="al-overlay" onClick={onClose}>
      <div className="al-modal" onClick={e => e.stopPropagation()}>
        <div className="al-modal-header">
          <div>
            <div className="al-modal-title">New F2F Payment</div>
            <div className="al-modal-sub">Step {step} of 2 — {step === 1 ? "Select Member Loan" : "Enter Payment Details"}</div>
          </div>
          <button className="al-modal-close" onClick={onClose}>✕</button>
        </div>
        {step === 1 && (
          <>
            <div className="al-modal-body">
              <div className="al-step-info">Select the member's active loan to record payment for.</div>
              <div className="al-search-wrap">
                <span>🔍</span>
                <input className="al-search-in" placeholder="Search by name, member ID, loan ID..." value={search} onChange={e => setSearch(e.target.value)} />
              </div>
              <div className="al-loan-list">
                {fetching ? <div style={{textAlign:"center",padding:20,color:"#aaa"}}>Loading loans...</div>
                : filtered.length === 0 ? <div style={{textAlign:"center",padding:20,color:"#aaa"}}>No active loans found.</div>
                : filtered.map(l => (
                  <div key={l.id} className={`al-loan-item ${selected?.id === l.id ? "selected" : ""}`}
                    onClick={() => { setSelect(l); setAmount(String(l.monthly_due||"")); setError(""); }}>
                    <div className="al-loan-avatar">{(l.member_name||"M")[0]}</div>
                    <div className="al-loan-info">
                      <div className="al-loan-name">{l.member_name}</div>
                      <div className="al-loan-meta">{l.member_code} · {l.loan_id}</div>
                    </div>
                    <div className="al-loan-bal">
                      <div className="al-bal-val">₱{Number(l.balance).toLocaleString()}</div>
                      <div className="al-bal-label">balance</div>
                    </div>
                  </div>
                ))}
              </div>
            </div>
            <div className="al-modal-footer">
              <button className="al-btn-cancel" onClick={onClose}>Cancel</button>
              <button className="al-btn-save" onClick={() => setStep(2)} disabled={!selected}>Next →</button>
            </div>
          </>
        )}
        {step === 2 && (
          <>
            <div className="al-modal-body">
              <div className="al-borrower-strip">
                <div className="al-loan-avatar">{(selected.member_name||"M")[0]}</div>
                <div>
                  <div className="al-loan-name">{selected.member_name}</div>
                  <div className="al-loan-meta">{selected.member_code} · {selected.loan_id} · Balance: ₱{balance.toLocaleString()}</div>
                </div>
              </div>
              <div className="al-field">
                <label className="al-label">Payment Amount (₱) <span className="al-req">*</span></label>
                <div className="al-amount-wrap">
                  <span className="al-peso">₱</span>
                  <input className="al-amount-in" type="number" min="1" max={balance}
                    value={amount} onChange={e => { setAmount(e.target.value); setError(""); }} autoFocus />
                </div>
                <div className="al-quick-row">
                  <button className="al-quick" onClick={() => { setAmount(String(selected.monthly_due||"")); setError(""); }}>Monthly ₱{Number(selected.monthly_due||0).toLocaleString()}</button>
                  <button className="al-quick" onClick={() => { setAmount(String(balance)); setError(""); }}>Full ₱{balance.toLocaleString()}</button>
                </div>
              </div>
              <div className="al-field">
                <label className="al-label">Note (optional)</label>
                <input className="al-input" type="text" value={note} onChange={e => setNote(e.target.value)} placeholder="e.g. Partial payment, advance..." maxLength={80} />
              </div>
              {error && <div className="al-error">⚠ {error}</div>}
              {isValid && (
                <div className="al-preview">
                  <div className="al-prev-row"><span>Current balance</span><span>₱{balance.toLocaleString()}</span></div>
                  <div className="al-prev-row deduct"><span>Payment</span><span>− ₱{parsed.toLocaleString()}</span></div>
                  <div className="al-prev-divider"/>
                  <div className="al-prev-row result">
                    <span>New balance</span>
                    <span className={(balance-parsed)===0?"paid-green":""}>
                      ₱{(balance-parsed).toLocaleString()}
                      {(balance-parsed)===0 && " 🎉 FULLY PAID"}
                    </span>
                  </div>
                </div>
              )}
            </div>
            <div className="al-modal-footer">
              <button className="al-btn-cancel" onClick={() => setStep(1)}>← Back</button>
              <button className="al-btn-save" onClick={handlePay} disabled={!isValid||loading}>{loading?"Saving...":"Save Payment Record"}</button>
            </div>
          </>
        )}
      </div>
    </div>
  );
}

// ─── Savings Modal ────────────────────────────────────────────────────────────
function usePhAddress() {
  const [regions,    setRegions]    = useState([]);
  const [provinces,  setProvinces]  = useState([]);
  const [cities,     setCities]     = useState([]);
  const [barangays,  setBarangays]  = useState([]);
  const [loadingProv, setLoadProv]  = useState(false);
  const [loadingCity, setLoadCity]  = useState(false);
  const [loadingBrgy, setLoadBrgy]  = useState(false);

  useEffect(() => {
    fetch("https://psgc.gitlab.io/api/regions/")
      .then(r => r.json())
      .then(d => setRegions(d.sort((a,b) => a.name.localeCompare(b.name))))
      .catch(() => {});
  }, []);

  const loadProvinces = async (regionCode) => {
    if (!regionCode) { setProvinces([]); setCities([]); setBarangays([]); return; }
    setLoadProv(true);
    try {
      const r = await fetch(`https://psgc.gitlab.io/api/regions/${regionCode}/provinces/`);
      const d = await r.json();
      setProvinces(d.sort((a,b) => a.name.localeCompare(b.name)));
      setCities([]); setBarangays([]);
    } catch {} finally { setLoadProv(false); }
  };

  const loadCities = async (provinceCode) => {
    if (!provinceCode) { setCities([]); setBarangays([]); return; }
    setLoadCity(true);
    try {
      const r = await fetch(`https://psgc.gitlab.io/api/provinces/${provinceCode}/cities-municipalities/`);
      const d = await r.json();
      setCities(d.sort((a,b) => a.name.localeCompare(b.name)));
      setBarangays([]);
    } catch {} finally { setLoadCity(false); }
  };

  const loadBarangays = async (cityCode) => {
    if (!cityCode) { setBarangays([]); return; }
    setLoadBrgy(true);
    try {
      const r = await fetch(`https://psgc.gitlab.io/api/cities-municipalities/${cityCode}/barangays/`);
      const d = await r.json();
      setBarangays(d.sort((a,b) => a.name.localeCompare(b.name)));
    } catch {} finally { setLoadBrgy(false); }
  };

  return { regions, provinces, cities, barangays, loadProvinces, loadCities, loadBarangays, loadingProv, loadingCity, loadingBrgy };
}

// ─── FormField Component ──────────────────────────────────────────────────────
function RegField({ name, label, type="text", options=null, required=false, optional=false, form, errors, handle, clearErr, full=false, placeholder="" }) {
  return (
    <div className={`al-field ${full ? "al-full" : ""}`}>
      <label className="al-label">
        {label}
        {required && <span className="al-req"> *</span>}
        {optional && <span className="al-opt"> (optional)</span>}
      </label>
      {options ? (
        <select className={`al-input ${errors[name] ? "al-input-err" : ""}`} name={name} value={form[name]||""} onChange={handle}>
          {options.map(o => typeof o === "object"
            ? <option key={o.value} value={o.value}>{o.label}</option>
            : <option key={o}>{o}</option>
          )}
        </select>
      ) : (
        <input
          className={`al-input ${errors[name] ? "al-input-err" : ""}`}
          type={type} name={name} value={form[name]||""}
          placeholder={placeholder}
          onChange={e => { handle(e); if(clearErr) clearErr(name); }}
        />
      )}
      {errors[name] && <div className="al-field-err">{errors[name]}</div>}
    </div>
  );
}

// ─── Register Member Modal ────────────────────────────────────────────────────
function RegisterModal({ onClose }) {
  const TABS = [
    { key: "personal",       label: "Personal Info"   },
    { key: "spouse",         label: "Spouse & Family" },
    { key: "classification", label: "Classification"  },
    { key: "account",        label: "Account Info"    },
  ];

  const [form, setForm] = useState({
    last_name: "", first_name: "", middle_name: "",
    birth_date: "", place_of_birth: "", sex: "Male", sex_other: "",
    civil_status: "Single", educational_attainment: "",
    contact_number: "", email: "", 
    // Address fields
    region: "", province: "", city: "", barangay: "", street: "",
    address: "",
    occupation: "", income: "", tin_no: "", sss_gsis_no: "",
    religious_social_affiliation: "",
    share_capital: "",
    birth_certificate: false, marriage_certificate: false,
    spouse_name: "", spouse_occupation: "", spouse_income: "",
    no_of_dependants: "",
    beneficiary_name: "", beneficiary_relationship: "",
    credit_references: "",
    classification: "Employed",
    school_name: "", year_level: "", allowance: "",
    pension_income: "", job_type: "Employed", monthly_income: "",
  });

  const [errors,  setErrors]  = useState({});
  const [done,    setDone]    = useState(false);
  const [tab,     setTab]     = useState("personal");
  const [copied,  setCopied]  = useState("");
  const [loading, setLoading] = useState(false);
  const [creds,   setCreds]   = useState({ memberId: "", username: "", password: "" });

  // Philippine address
  const ph = usePhAddress();

  // Address selections
  const [selRegion,   setSelRegion]   = useState(null);
  const [selProvince, setSelProvince] = useState(null);
  const [selCity,     setSelCity]     = useState(null);

  const handle = e => {
    const val = e.target.type === "checkbox" ? e.target.checked : e.target.value;
    setForm(p => ({ ...p, [e.target.name]: val }));
    setErrors(p => ({ ...p, [e.target.name]: "" }));
  };

  // Build full address string whenever components change
  useEffect(() => {
    const parts = [form.street, form.barangay, form.city, form.province, form.region].filter(Boolean);
    setForm(p => ({ ...p, address: parts.join(", ") }));
  }, [form.street, form.barangay, form.city, form.province, form.region]);

  const SEX_OPTIONS = ["Male", "Female", "Non-binary", "Prefer not to say", "Other"];

  const validate = () => {
    const e = {};
    if (!form.first_name.trim())     e.first_name     = "Required";
    if (!form.last_name.trim())      e.last_name      = "Required";
    if (!form.birth_date)            e.birth_date     = "Required";
    if (!form.contact_number.trim()) e.contact_number = "Required";
    if (!form.address.trim())        e.address        = "Required";
    if (form.sex === "Other" && !form.sex_other.trim()) e.sex_other = "Please specify";
    if (form.classification === "Student" && !form.school_name.trim()) e.school_name = "Required";
    if (form.classification === "Student" && !form.year_level.trim())  e.year_level  = "Required";
    return e;
  };

  const handleSubmit = async () => {
    const e = validate();
    if (Object.keys(e).length) {
      setErrors(e);
      const personalFields = ["first_name","last_name","birth_date","contact_number","address","sex_other"];
      const classFields    = ["school_name","year_level"];
      if (personalFields.some(f => e[f])) { setTab("personal");      return; }
      if (classFields.some(f => e[f]))    { setTab("classification"); return; }
      return;
    }
    setLoading(true);
    try {
      const finalSex = form.sex === "Other" ? form.sex_other : form.sex;
      const result = await registerMemberAPI({
        first_name:                   form.first_name,
        last_name:                    form.last_name,
        middle_name:                  form.middle_name,
        birth_date:                   form.birth_date,
        place_of_birth:               form.place_of_birth,
        sex:                          finalSex,
        civil_status:                 form.civil_status,
        educational_attainment:       form.educational_attainment,
        contact_number:               form.contact_number,
        email:                        form.email,
        address:                      form.address,
        occupation:                   form.occupation,
        income:                       form.income || 0,
        tin_no:                       form.tin_no,
        sss_gsis_no:                  form.sss_gsis_no,
        religious_social_affiliation: form.religious_social_affiliation,
        birth_certificate:            form.birth_certificate,
        marriage_certificate:         form.marriage_certificate,
        spouse_name:                  form.spouse_name,
        spouse_occupation:            form.spouse_occupation,
        spouse_income:                form.spouse_income || 0,
        no_of_dependants:             form.no_of_dependants || 0,
        beneficiary_name:             form.beneficiary_name,
        beneficiary_relationship:     form.beneficiary_relationship,
        credit_references:            form.credit_references,
        classification:               form.classification,
        school_name:                  form.school_name,
        year_level:                   form.year_level,
        allowance:                    form.allowance || 0,
        pension_income:               form.pension_income || 0,
        job_type:                     form.job_type,
        monthly_income:               form.monthly_income || 0,
        share_capital:                form.share_capital || 0,
      });
      setCreds({ memberId: result.member_id, username: result.username, password: result.plain_password });
      setDone(true);
      setTab("account");
    } catch(err) {
      const msg = err.response?.data?.error || err.response?.data?.detail || "Failed to register member.";
      setErrors({ first_name: msg });
      setTab("personal");
    } finally { setLoading(false); }
  };

  const copyText = (text, key) => {
    navigator.clipboard.writeText(text).catch(() => {});
    setCopied(key);
    setTimeout(() => setCopied(""), 1800);
  };

  return (
    <div className="al-overlay" onClick={onClose}>
      <div className="al-modal al-modal-lg" onClick={e => e.stopPropagation()}>

        {/* Header */}
        <div className="al-modal-header">
          <div>
            <div className="al-modal-title">Register New Member</div>
            <div className="al-modal-sub">LEAF MPC Member Application & Information Sheet</div>
          </div>
          <button className="al-modal-close" onClick={onClose}>✕</button>
        </div>

        {/* Tabs */}
        <div className="al-reg-tabs">
          {TABS.map((t, i) => (
            <button key={t.key} className={`al-reg-tab ${tab === t.key ? "active" : ""}`}
              onClick={() => !done && setTab(t.key)}
              style={{ cursor: done ? "default" : "pointer" }}>
              <span className="al-reg-tab-num">{i + 1}</span> {t.label}
            </button>
          ))}
        </div>

        <div>

          {/* ── TAB 1: Personal Info ── */}
          {tab === "personal" && (
            <div className="al-form-grid">

              {/* Section: Name */}
              <div className="al-full" style={{gridColumn:"1/-1"}}>
                <div className="al-section-header">Full Name</div>
              </div>
              <RegField name="last_name"   label="Surname"     required form={form} errors={errors} handle={handle} clearErr={n=>setErrors(p=>({...p,[n]:""})) }/>
              <RegField name="first_name"  label="First Name"  required form={form} errors={errors} handle={handle} clearErr={n=>setErrors(p=>({...p,[n]:""})) }/>
              <RegField name="middle_name" label="Middle Name"  optional form={form} errors={errors} handle={handle}/>

              {/* Section: Birth */}
              <div style={{gridColumn:"1/-1",marginTop:4}}>
                <div className="al-section-header">Birth Information</div>
              </div>
              <RegField name="birth_date"     label="Date of Birth"  required type="date" form={form} errors={errors} handle={handle} clearErr={n=>setErrors(p=>({...p,[n]:""})) }/>
              <RegField name="place_of_birth" label="Place of Birth"  required form={form} errors={errors} handle={handle} placeholder="e.g. Lucban, Quezon"/>

              {/* Section: Personal Details */}
              <div style={{gridColumn:"1/-1",marginTop:4}}>
                <div className="al-section-header">Personal Details</div>
              </div>

              {/* Sex */}
              <div className="al-field">
                <label className="al-label">Sex <span className="al-req"> *</span></label>
                <select className="al-input" name="sex" value={form.sex} onChange={handle}>
                  {SEX_OPTIONS.map(o => <option key={o}>{o}</option>)}
                </select>
              </div>
              {form.sex === "Other" && (
                <div className="al-field">
                  <label className="al-label">Please specify <span className="al-req"> *</span></label>
                  <input
                    className={`al-input ${errors.sex_other ? "al-input-err" : ""}`}
                    name="sex_other" value={form.sex_other} onChange={handle}
                    placeholder="Enter your gender identity"/>
                  {errors.sex_other && <div className="al-field-err">{errors.sex_other}</div>}
                </div>
              )}

              <RegField name="civil_status" label="Civil Status" required options={["Single","Married","Widowed","Separated"]} form={form} errors={errors} handle={handle}/>
              <RegField name="educational_attainment" label="Educational Attainment" required options={["","Elementary","High School","Vocational","College","Post Graduate"]} form={form} errors={errors} handle={handle}/>
              <RegField name="religious_social_affiliation" label="Religious/Social Affiliation" required form={form} errors={errors} handle={handle} placeholder="e.g. Roman Catholic, INC"/>
              <RegField name="tin_no"      label="TIN No."       optional form={form} errors={errors} handle={handle} placeholder="000-000-000"/>
              <RegField name="sss_gsis_no" label="SSS/GSIS No."  optional form={form} errors={errors} handle={handle} placeholder="00-0000000-0"/>

              {/* Section: Address */}
              <div style={{gridColumn:"1/-1",marginTop:4}}>
                <div className="al-section-header">Address <span className="al-req"> *</span></div>
                <div style={{fontSize:11,color:"#888",marginTop:2,marginBottom:8}}>Select from dropdowns to auto-fill address, or type street/sitio manually.</div>
              </div>

              {/* Region */}
              <div className="al-field">
                <label className="al-label">Region <span className="al-req"> *</span></label>
                <select className="al-input" value={selRegion?.code||""} onChange={e => {
                  const r = ph.regions.find(x=>x.code===e.target.value);
                  setSelRegion(r||null); setSelProvince(null); setSelCity(null);
                  setForm(p=>({...p, region: r?.name||"", province:"", city:"", barangay:""}));
                  if (r) ph.loadProvinces(r.code);
                }}>
                  <option value="">— Select Region —</option>
                  {ph.regions.map(r => <option key={r.code} value={r.code}>{r.name}</option>)}
                </select>
              </div>

              {/* Province */}
              <div className="al-field">
                <label className="al-label">Province <span className="al-req"> *</span></label>
                <select className="al-input" value={selProvince?.code||""} disabled={!selRegion||ph.loadingProv}
                  onChange={e => {
                    const p = ph.provinces.find(x=>x.code===e.target.value);
                    setSelProvince(p||null); setSelCity(null);
                    setForm(prev=>({...prev, province: p?.name||"", city:"", barangay:""}));
                    if (p) ph.loadCities(p.code);
                  }}>
                  <option value="">{ph.loadingProv ? "Loading..." : "— Select Province —"}</option>
                  {ph.provinces.map(p => <option key={p.code} value={p.code}>{p.name}</option>)}
                </select>
              </div>

              {/* City/Municipality */}
              <div className="al-field">
                <label className="al-label">City / Municipality <span className="al-req"> *</span></label>
                <select className="al-input" value={selCity?.code||""} disabled={!selProvince||ph.loadingCity}
                  onChange={e => {
                    const c = ph.cities.find(x=>x.code===e.target.value);
                    setSelCity(c||null);
                    setForm(prev=>({...prev, city: c?.name||"", barangay:""}));
                    if (c) ph.loadBarangays(c.code);
                  }}>
                  <option value="">{ph.loadingCity ? "Loading..." : "— Select City/Municipality —"}</option>
                  {ph.cities.map(c => <option key={c.code} value={c.code}>{c.name}</option>)}
                </select>
              </div>

              {/* Barangay */}
              <div className="al-field">
                <label className="al-label">Barangay <span className="al-req"> *</span></label>
                <select className="al-input" value={form.barangay} disabled={!selCity||ph.loadingBrgy}
                  onChange={e => setForm(p=>({...p, barangay: e.target.value}))}>
                  <option value="">{ph.loadingBrgy ? "Loading..." : "— Select Barangay —"}</option>
                  {ph.barangays.map(b => <option key={b.code} value={b.name}>{b.name}</option>)}
                </select>
              </div>

              {/* Street/Sitio */}
              <div className="al-field al-full">
                <label className="al-label">House No. / Street / Sitio <span className="al-opt"> (optional)</span></label>
                <input className="al-input" name="street" value={form.street} onChange={handle}
                  placeholder="e.g. 12 Rizal St., Sitio Maligaya"/>
              </div>

              {/* Full address preview */}
              {form.address && (
                <div className="al-full" style={{gridColumn:"1/-1"}}>
                  <div style={{background:"#e8f5e9",borderRadius:8,padding:"10px 14px",fontSize:12,color:"#1b5e20",display:"flex",gap:8,alignItems:"flex-start"}}>
                    <span style={{fontWeight:700,flexShrink:0}}>Full address:</span>
                    <span>{form.address}</span>
                  </div>
                </div>
              )}
              {errors.address && <div className="al-field-err al-full" style={{gridColumn:"1/-1"}}>{errors.address}</div>}

              {/* Section: Contact */}
              <div style={{gridColumn:"1/-1",marginTop:4}}>
                <div className="al-section-header">Contact Information</div>
              </div>
              <RegField name="contact_number" label="Tel. No. / CP No."  required form={form} errors={errors} handle={handle} clearErr={n=>setErrors(p=>({...p,[n]:""})) } placeholder="09XXXXXXXXX"/>
              <RegField name="email"          label="Email Address"       required type="email" form={form} errors={errors} handle={handle} placeholder="email@example.com"/>

              {/* Section: Employment */}
              <div style={{gridColumn:"1/-1",marginTop:4}}>
                <div className="al-section-header">Employment</div>
              </div>
              <RegField name="occupation" label="Occupation"          required form={form} errors={errors} handle={handle} placeholder="e.g. Teacher, Farmer"/>
              <RegField name="income"     label="Monthly Income (₱)"  required type="number" form={form} errors={errors} handle={handle}/>

              {/* Section: Membership */}
              <div style={{gridColumn:"1/-1",marginTop:4}}>
                <div className="al-section-header">Membership Payment</div>
              </div>
              <div className="al-field">
                <label className="al-label">Amount Paid (₱) <span className="al-req"> *</span></label>
                <div className="al-amount-wrap">
                  <span className="al-peso">₱</span>
                  <input className="al-amount-in" type="number" name="share_capital"
                    value={form.share_capital||""} onChange={handle} placeholder="e.g. 4000"/>
                </div>
                {form.share_capital > 0 && (
                  <div style={{marginTop:6,padding:"6px 10px",background:"#e8f5e9",borderRadius:8,fontSize:11,color:"#2e7d32",fontWeight:600}}>
                    {/* ── FIX: dating naka-hardcode na "× 2" — pero
                        default na 1× (unang loan) ang bagong
                        naka-register na member sa Loan Multiplier
                        system natin, hindi 2×. ──────────────────────── */}
                    Share Capital = ₱{(parseFloat(form.share_capital||0)).toLocaleString()} · Max Loanable = ₱{(parseFloat(form.share_capital||0)).toLocaleString()} (1× — first loan)
                  </div>
                )}
              </div>

              {/* Documents */}
              <div className="al-field">
                <label className="al-label">Birth Certificate <span className="al-opt"> (optional)</span></label>
                <label style={{display:"flex",alignItems:"center",gap:8,marginTop:4,fontSize:13,cursor:"pointer"}}>
                  <input type="checkbox" name="birth_certificate" checked={form.birth_certificate} onChange={handle}/> Submitted
                </label>
              </div>
              <div className="al-field">
                <label className="al-label">Marriage Certificate <span className="al-opt"> (optional)</span></label>
                <label style={{display:"flex",alignItems:"center",gap:8,marginTop:4,fontSize:13,cursor:"pointer"}}>
                  <input type="checkbox" name="marriage_certificate" checked={form.marriage_certificate} onChange={handle}/> Submitted (if married)
                </label>
              </div>
            </div>
          )}

          {/* ── TAB 2: Spouse & Family ── */}
          {tab === "spouse" && (
            <div className="al-form-grid">
              <div style={{gridColumn:"1/-1",background:"#f9fef9",border:"1px solid #e8f5e9",borderRadius:10,padding:"12px 16px",fontSize:12,color:"#555",marginBottom:4}}>
                Fill in if married. All fields in this tab are optional.
              </div>
              <div style={{gridColumn:"1/-1"}}><div className="al-section-header">Spouse Information</div></div>
              <RegField name="spouse_name"       label="Spouse Name"               optional form={form} errors={errors} handle={handle}/>
              <RegField name="spouse_occupation" label="Spouse Occupation"          optional form={form} errors={errors} handle={handle}/>
              <RegField name="spouse_income"     label="Spouse Monthly Income (₱)"  optional type="number" form={form} errors={errors} handle={handle}/>
              <RegField name="no_of_dependants"  label="No. of Dependants"           optional type="number" form={form} errors={errors} handle={handle}/>

              <div style={{gridColumn:"1/-1",marginTop:4}}><div className="al-section-header">Beneficiary Information</div></div>
              <RegField name="beneficiary_name"         label="Beneficiary Name"         optional form={form} errors={errors} handle={handle}/>
              <RegField name="beneficiary_relationship" label="Relationship to Member"    optional form={form} errors={errors} handle={handle}/>

              <div style={{gridColumn:"1/-1",marginTop:4}}><div className="al-section-header">Credit References</div></div>
              <div className="al-field al-full">
                <label className="al-label">Credit References <span className="al-opt"> (optional)</span></label>
                <textarea className="al-input" name="credit_references" rows={3}
                  value={form.credit_references} onChange={handle}
                  placeholder="Names and contact details of credit references..."
                  style={{resize:"none"}}/>
              </div>
            </div>
          )}

          {/* ── TAB 3: Classification ── */}
          {tab === "classification" && (
            <div className="al-form-grid">
              <div className="al-field al-full">
                <label className="al-label">Member Classification <span className="al-req"> *</span></label>
                <div style={{display:"flex",gap:12,marginTop:8}}>
                  {CLASS_OPTIONS.map(c => (
                    <div key={c.key} onClick={() => setForm(p => ({...p, classification: c.key}))}
                      style={{
                        flex:1, border:`2px solid ${form.classification===c.key?"#2e7d32":"#e0e0e0"}`,
                        borderRadius:10, padding:"16px 10px", textAlign:"center", cursor:"pointer",
                        background: form.classification===c.key ? "#e8f5e9" : "#fafafa", transition:"all 0.2s",
                      }}>
                      <div style={{marginBottom:6,display:"flex",justifyContent:"center"}}>{c.icon}</div>
                      <div style={{fontSize:12,fontWeight:700,color:"#2e7d32"}}>{c.label}</div>
                    </div>
                  ))}
                </div>
              </div>
              {form.classification === "Student" && (<>
                <RegField name="school_name" label="School Name"    required form={form} errors={errors} handle={handle} clearErr={n=>setErrors(p=>({...p,[n]:""})) }/>
                <RegField name="year_level"  label="Year Level"     required form={form} errors={errors} handle={handle}
                  options={["","Grade 7","Grade 8","Grade 9","Grade 10","Grade 11","Grade 12","1st Year","2nd Year","3rd Year","4th Year","5th Year","Graduate"]}/>
                <RegField name="allowance"   label="Monthly Allowance (₱)" required type="number" form={form} errors={errors} handle={handle}/>
              </>)}
              {form.classification === "Senior" && (<>
                <RegField name="educational_attainment" label="Educational Attainment" required
                  options={["","Elementary","High School","Vocational","College","Post Graduate"]}
                  form={form} errors={errors} handle={handle}/>
                <RegField name="pension_income" label="Monthly Pension Income (₱)" required type="number" form={form} errors={errors} handle={handle}/>
              </>)}
              {form.classification === "Employed" && (<>
                <RegField name="occupation"     label="Occupation/Job Title" required form={form} errors={errors} handle={handle}/>
                <RegField name="job_type"       label="Employment Type"     required
                  options={["Employed","Self-Employed","Business","Freelance","Other"]}
                  form={form} errors={errors} handle={handle}/>
                <RegField name="monthly_income" label="Monthly Income (₱)"  required type="number" form={form} errors={errors} handle={handle}/>
              </>)}
            </div>
          )}

          {/* ── TAB 4: Account ── */}
          {tab === "account" && (
            <div className="al-form-grid">
              {done ? (<>
                <div className="al-field al-full" style={{textAlign:"center",padding:"12px 0"}}>
                  <div style={{fontSize:40,marginBottom:8}}>🎉</div>
                  <div style={{fontSize:15,fontWeight:800,color:"#1b5e20",marginBottom:4}}>
                    {form.first_name} {form.last_name} is now an official member!
                  </div>
                  <div style={{fontSize:12,color:"#888"}}>Share the credentials below with the member.</div>
                </div>
                <div className="al-cred-card" style={{gridColumn:"1/-1"}}>
                  <div className="al-cred-title">Login Credentials</div>
                  <div className="al-cred-sub">Give this slip to the member</div>
                  {[["Member ID",creds.memberId,"id"],["Username",creds.username,"user"],["Password",creds.password,"pass"]].map(([k,v,key]) => (
                    <div key={k} className="al-cred-row">
                      <span className="al-cred-label">{k}</span>
                      <div className="al-cred-val-wrap">
                        <span className="al-cred-val">{v}</span>
                        <button className="al-copy-btn" onClick={() => copyText(v,key)}>
                          {copied===key ? "Copied" : "Copy"}
                        </button>
                      </div>
                    </div>
                  ))}
                </div>
                <div className="al-cred-notice" style={{gridColumn:"1/-1"}}>
                  The member can change their password anytime in My Profile after logging in.
                </div>
              </>) : (
                <div className="al-field al-full" style={{textAlign:"center",padding:"24px 0",color:"#888"}}>
                  Complete all tabs first, then submit to generate credentials.
                </div>
              )}
            </div>
          )}
        </div>

        <div style={{display:"flex",justifyContent:"flex-end",gap:10,marginTop:16}}>
          {!done ? (<>
            {tab !== "personal" && (
              <button className="al-btn-cancel" onClick={() => {
                const keys = TABS.map(t => t.key);
                setTab(keys[keys.indexOf(tab) - 1]);
              }}>Previous</button>
            )}
            {tab === "personal" && <button className="al-btn-cancel" onClick={onClose}>Cancel</button>}
            {tab !== "classification" ? (
              <button className="al-btn-save" onClick={() => {
                const keys = TABS.map(t => t.key);
                setTab(keys[keys.indexOf(tab) + 1]);
              }}>Next</button>
            ) : (
              <button className="al-btn-save" onClick={handleSubmit} disabled={loading}>
                {loading ? "Registering..." : "Register Member"}
              </button>
            )}
          </>) : (
            <button className="al-btn-save" onClick={onClose}>Done</button>
          )}
        </div>
      </div>
    </div>
  );
}


// ─── New F2F Loan Application Modal ──────────────────────────────────────────
// ── BAGO: 4 na bagong loan types (Regular, Petty Cash, Appliance,
// ATM) — pinalitan ang dating 5 (Regular, Emergency, Salary, Housing,
// Business), tugma na sa binago nating LOAN_TYPES sa member-side
// LoanApplication.jsx. ──────────────────────────────────────────────
const LOAN_TYPES_LIST = ["Regular Loan","Petty Cash Loan","Appliance Loan","ATM Loan"];

function NewLoanModal({ onClose }) {
  // ── BAGO: para awtomatikong ma-navigate papunta sa Loan Approval
  // page pagkatapos mag-submit — dati, ang "Done" ay basta nagsasara
  // lang ng modal, walang refresh sa listahan (ibang route/component
  // ang Loan Approval page, hindi kilala ng AdminLayout modal na 'to
  // ang fetch function nito). Sa pag-navigate, awtomatikong tatakbo
  // ang sariling fetch effect ng Loan Approval page sa mount, kaya
  // makikita agad ang bagong loan. ─────────────────────────────────
  const navigate = useNavigate();
  const [step,          setStep]         = useState(1);
  const [selMember,     setMember]        = useState(null);
  const [search,        setSearch]        = useState("");
  const [form,          setForm]          = useState({ loanType:"Regular Loan", amount:"", term:"12", purpose:"", collateral:"" });
  const [errors,        setErrors]        = useState({});
  const [done,          setDone]          = useState(false);
  const [loadingSubmit, setLoadingSubmit] = useState(false);
  const [refNo,         setRefNo]         = useState("");
  const [monthlyResult, setMonthlyResult] = useState(0);
  const [members,       setMembers]       = useState([]);
  const [fetching,      setFetching]      = useState(true);
  const [showRateEdit,  setShowRateEdit]  = useState(false);
  const [rates, setRates] = useState({
    serviceFeePct: 3, insurancePct: 1.25, sdPct: 1, scPct: 3,
    filingFeeAmt: 50, interestOverride: 0,
  });

  const handle = e => setForm(p => ({ ...p, [e.target.name]: e.target.value }));

  useEffect(() => {
    getMembersAPI()
      .then(data => setMembers(data))
      .catch(e => console.error(e))
      .finally(() => setFetching(false));
  }, []);

  const filtered = members.filter(m =>
    (m.fullname||"").toLowerCase().includes(search.toLowerCase()) ||
    (m.member_id||"").toLowerCase().includes(search.toLowerCase())
  );

  const shareCapital = selMember ? parseFloat(selMember.share_capital||0) : 0;
  // ── FIX: dating "maxLoanable = shareCapital" lang — WALANG
  // multiplier man lang (hindi man lang yung lumang "× 2"). Gamit na
  // ngayon ang totoong "max_loanable" field mula sa member data (na
  // kumukuha na sa admin-editable na Loan Multiplier). May fallback
  // pa rin sa shareCapital kung sakaling wala talagang "max_loanable"
  // sa response (hal. luma pang cached data). ─────────────────────────
  const maxLoanable  = selMember ? parseFloat(selMember.max_loanable || selMember.share_capital || 0) : 0;
  const amount       = parseFloat(form.amount) || 0;
  const term         = parseInt(form.term) || 12;
  const defaultRate  = amount <= 50000 ? 0.0125 : amount <= 150000 ? 0.01125 : 0.01;
  const effectiveRate= rates.interestOverride > 0 ? rates.interestOverride / 100 : defaultRate;
  const interest     = effectiveRate * amount * term;
  const serviceFee   = amount * (rates.serviceFeePct / 100);
  const filingFee    = rates.filingFeeAmt;
  const insurance    = amount * (rates.insurancePct / 100);
  const sd           = amount * (rates.sdPct / 100);
  const sc           = amount * (rates.scPct / 100);
  const totalDed     = interest + serviceFee + filingFee + insurance + sd + sc;
  const netProceeds  = amount - totalDed;
  // ── FIX: dating "(amount + interest) / term" — dito ang aktwal na
  // bug, hindi lang sa display. Kaparehong ayos ng backend
  // (serializers.py) at member-side LoanApplication.jsx. ─────────────
  const monthly      = amount > 0 ? (amount / term).toFixed(2) : 0;

  const validate = () => {
    const e = {};
    if (!form.amount || parseFloat(form.amount) <= 0) e.amount  = "Enter a valid amount.";
    // ── BAGO: tinanggal ang fixed na ₱3,000 minimum — desisyon na
    // lang ng admin/member kung magkano, basta hindi lalagpas sa max
    // loanable (na ino-enforce na rin habang nagta-type, hindi lang
    // sa submit). ───────────────────────────────────────────────────
    else if (parseFloat(form.amount) > maxLoanable) e.amount = `Amount exceeds max loanable of ₱${maxLoanable.toLocaleString()}.`;
    if (!form.purpose.trim())           e.purpose = "Purpose is required.";
    return e;
  };

  // ── BAGO: refs para sa "scroll-to-error" — kapag may hindi na-fill
  // na required field, awtomatikong mag-s-scroll at mag-fo-focus dito
  // imbes na basta magpakita ng error text na baka hindi mapansin. ─────
  const amountRef  = useRef(null);
  const purposeRef = useRef(null);
  const fieldRefs  = { amount: amountRef, purpose: purposeRef };

  const scrollToFirstError = (errs) => {
    const order = ["amount", "purpose"];
    const firstKey = order.find(k => errs[k]);
    const ref = firstKey && fieldRefs[firstKey];
    if (ref?.current) {
      ref.current.scrollIntoView({ behavior: "smooth", block: "center" });
      ref.current.focus({ preventScroll: true });
    }
  };

  const handleSubmit = async () => {
    const e = validate();
    if (Object.keys(e).length) { setErrors(e); scrollToFirstError(e); return; }
    setLoadingSubmit(true);
    try {
      // ── FIX: dating walang "is_f2f: true" na ipinapadala — kaya sa
      // backend, "For Review" ang default na status, tapos manual pang
      // ino-override papuntang "Approved" (na para sa PENDING-RELEASE
      // queue, ginagamit ng ONLINE applications na kailangan pang i-
      // approve/i-release). Pero F2F ito — kasama na ang member sa
      // opisina, ibinibigay na agad ang pera doon mismo — dapat
      // DERETSO sa "Active" status, hindi dumaan pa sa For Release.
      // Sa pagpasa ng "is_f2f: true", awtomatiko nang gagawing "Active"
      // ng backend serializer, KASAMA na ang auto 1% savings deposit
      // (na dati rin nale-skip dahil hindi na-trigger ang F2F path). ──
      const result = await createLoanAPI({
        member:      selMember.id,
        loan_type:   form.loanType,
        amount:      parseFloat(form.amount),
        term_months: parseInt(form.term),
        purpose:     form.purpose,
        collateral:  form.collateral,
        is_f2f:      true,
      });
      setRefNo(result.loan_id);
      setMonthlyResult(result.monthly_due);
      setDone(true);
    } catch(err) {
      setErrors({ amount: err.response?.data?.detail || "Failed to submit loan." });
    } finally { setLoadingSubmit(false); }
  };

  // ── FIX: dating "/admin/loan-approval" ang tinutungo — mali, dahil
  // yun ay para sa mga loan na "For Review"/"Approved" pa (naghihintay
  // ng aksyon), na para sa ONLINE applications. Ang F2F loan (Active
  // na agad) ay dapat DERETSO makita sa "Loan Payment" page (kung
  // saan naka-list ang mga Active loans). ─────────────────────────────
  const handleDone = () => {
    onClose();
    navigate("/admin/loan-payment");
  };

  if (done) return (
    <div className="al-overlay" onClick={handleDone}>
      <div className="al-modal al-modal-sm" onClick={e => e.stopPropagation()}>
        <div className="al-modal-header">
          <div className="al-modal-title">✅ Application Recorded!</div>
          <button className="al-modal-close" onClick={handleDone}>✕</button>
        </div>
        <div className="al-modal-body" style={{gap:12}}>
          <div style={{fontSize:12,color:"#666",lineHeight:1.6}}>
            Loan application for <strong>{selMember.fullname}</strong> has been recorded.
          </div>
          <div className="al-cred-card">
            <div className="al-cred-title">📋 Application Details</div>
            <div className="al-cred-row"><span className="al-cred-label">Loan ID</span><span className="al-cred-val">{refNo}</span></div>
            <div className="al-cred-row"><span className="al-cred-label">Member</span><span className="al-cred-val">{selMember.member_id}</span></div>
            <div className="al-cred-row"><span className="al-cred-label">Loan Type</span><span className="al-cred-val">{form.loanType}</span></div>
            <div className="al-cred-row"><span className="al-cred-label">Amount</span><span className="al-cred-val">₱{parseFloat(form.amount).toLocaleString()}</span></div>
            <div className="al-cred-row"><span className="al-cred-label">Monthly</span><span className="al-cred-val">₱{parseFloat(monthlyResult||monthly).toLocaleString()}</span></div>
          </div>
          <div className="al-cred-notice">Redirecting you to Loan Payment — this loan is now Active and ready for collection.</div>
        </div>
        <div className="al-modal-footer">
          <button className="al-btn-save" onClick={handleDone}>Go to Loan Payment →</button>
        </div>
      </div>
    </div>
  );

  return (
    <div className="al-overlay" onClick={onClose}>
      <div className="al-modal al-modal-lg" onClick={e => e.stopPropagation()}>
        <div className="al-modal-header">
          <div>
            <div className="al-modal-title">New F2F Loan Application</div>
            <div className="al-modal-sub">Step {step} of 2 — {step===1 ? "Select Member" : "Loan Details"}</div>
          </div>
          <button className="al-modal-close" onClick={onClose}>✕</button>
        </div>

        {step === 1 && (
          <>
            <div className="al-modal-body">
              <div className="al-step-info">Select the member who is applying for a loan.</div>
              <div className="al-search-wrap">
                <span>🔍</span>
                <input className="al-search-in" placeholder="Search by name or member ID..." value={search} onChange={e => setSearch(e.target.value)} />
              </div>
              <div className="al-loan-list">
                {fetching ? <div style={{textAlign:"center",padding:20,color:"#aaa"}}>Loading members...</div>
                : filtered.length===0 ? <div style={{textAlign:"center",padding:20,color:"#aaa"}}>No members found.</div>
                : filtered.map(m => (
                  <div key={m.id} className={`al-loan-item ${selMember?.id===m.id?"selected":""}`} onClick={() => setMember(m)}>
                    <div className="al-loan-avatar">{m.fullname.charAt(0)}</div>
                    <div className="al-loan-info">
                      <div className="al-loan-name">{m.fullname}</div>
                      <div className="al-loan-meta">{m.member_id}</div>
                    </div>
                    <div className="al-loan-bal">
                      {/* ── FIX: dating "m.share_capital" ang ipinapakita
                          bilang "max loanable" — mali, walang
                          multiplier. Gamit na ngayon ang totoong
                          "max_loanable" field, may fallback pa rin sa
                          share_capital kung wala talaga. ──────────── */}
                      <div className="al-bal-val" style={{color:"#2e7d32"}}>₱{Number(m.max_loanable || m.share_capital || 0).toLocaleString()}</div>
                      <div className="al-bal-label">max loanable</div>
                    </div>
                  </div>
                ))}
              </div>
            </div>
            <div className="al-modal-footer">
              <button className="al-btn-cancel" onClick={onClose}>Cancel</button>
              <button className="al-btn-save" onClick={() => setStep(2)} disabled={!selMember}>Next →</button>
            </div>
          </>
        )}

        {step === 2 && (
          <>
            <div className="al-modal-body">
              <div className="al-borrower-strip">
                <div className="al-loan-avatar">{selMember.fullname.charAt(0)}</div>
                <div>
                  <div className="al-loan-name">{selMember.fullname}</div>
                  <div className="al-loan-meta">{selMember.member_id} · Share Capital: ₱{shareCapital.toLocaleString()} · Max Loanable: ₱{maxLoanable.toLocaleString()}</div>
                </div>
              </div>
              <div className="al-form-grid">
                <div className="al-field al-full">
                  <label className="al-label">Loan Type</label>
                  <select className="al-input" name="loanType" value={form.loanType} onChange={e => { handle(e); setErrors({}); }}>
                    {LOAN_TYPES_LIST.map(t => <option key={t}>{t}</option>)}
                  </select>
                </div>
                <div className="al-field">
                  <label className="al-label">Amount (₱) <span className="al-req">*</span></label>
                  <div className="al-amount-wrap">
                    <span className="al-peso">₱</span>
                    {/* ── FIX: dating "min"/"max" HTML attributes lang —
                        HINDI talaga pinipigilan ng mga 'yan ang direktang
                        pag-type sa keyboard (spinner buttons/validation
                        styling lang ang epekto nila, hindi input mismo).
                        Kaya kahit ₱8,000 lang ang max, puwede pa ring
                        mag-type ng ₱15,000. Gumagamit na ngayon ng
                        custom na onChange handler na TUMATANGGI sa
                        keystroke mismo kapag lalagpas na sa max —
                        kaparehong pattern ng member-side LoanApplication.jsx. ──
                        BAGO RIN: tinanggal ang ₱3,000 minimum — desisyon
                        na lang ng admin/member kung magkano, basta
                        hindi lalagpas sa max. ─────────────────────────── */}
                    <input ref={amountRef} className="al-amount-in" type="text" inputMode="numeric" name="amount" placeholder="Enter amount"
                      value={form.amount} onChange={e => {
                        const digitsOnly = e.target.value.replace(/[^0-9]/g, "");
                        if (digitsOnly === "") { setForm(p => ({...p, amount: ""})); setErrors(p=>({...p,amount:""})); return; }
                        const parsed = parseInt(digitsOnly, 10);
                        if (maxLoanable > 0 && parsed > maxLoanable) return; // tanggihan, huwag baguhin
                        setForm(p => ({...p, amount: digitsOnly}));
                        setErrors(p=>({...p,amount:""}));
                      }} />
                  </div>
                  <div style={{fontSize:10,color:"#888",marginTop:4}}>Max Loanable: ₱{maxLoanable.toLocaleString()}</div>
                  {errors.amount && <div className="al-error" style={{marginTop:4}}>{errors.amount}</div>}
                </div>
                <div className="al-field">
                  <label className="al-label">Term (months)</label>
                  {/* ── BAGO: dating "jump" na options (3,6,9,12,18,24,
                      36,48) — ngayon sunod-sunod na 1-12 buwan, dahil
                      dito na lang talaga pipili ang admin. ─────────── */}
                  <select className="al-input" name="term" value={form.term} onChange={handle}>
                    {Array.from({length:12}, (_,i) => i+1).map(t => (
                      <option key={t} value={t}>{t} month{t!==1?"s":""}</option>
                    ))}
                  </select>
                </div>
                <div className="al-field al-full">
                  <label className="al-label">Purpose <span className="al-req">*</span></label>
                  <textarea ref={purposeRef} className={`al-input ${errors.purpose?"border-red":""}`} name="purpose" rows={2}
                    placeholder="Reason for the loan..." value={form.purpose}
                    onChange={e => { handle(e); setErrors(p=>({...p,purpose:""})); }} style={{resize:"none"}} />
                  {errors.purpose && <div className="al-error" style={{marginTop:4}}>{errors.purpose}</div>}
                </div>
                <div className="al-field al-full">
                  <label className="al-label">Collateral (optional)</label>
                  <input className="al-input" name="collateral" placeholder="e.g. Land title, vehicle" value={form.collateral} onChange={handle} />
                </div>
              </div>

              {amount >= 3000 && (
                <div style={{marginTop:12}}>
                  <div style={{display:"flex",alignItems:"center",justifyContent:"space-between",marginBottom:6}}>
                    <div className="al-deduct-title" style={{margin:0}}>🧮 Loan Computation (LEAF MPC)</div>
                    <button type="button" onClick={() => setShowRateEdit(p=>!p)} style={{
                      fontSize:11,fontWeight:600,padding:"3px 10px",
                      background:showRateEdit?"#fff3e0":"#f5f5f5",
                      color:showRateEdit?"#e65100":"#888",
                      border:`1px solid ${showRateEdit?"#ffcc80":"#e0e0e0"}`,
                      borderRadius:20,cursor:"pointer",
                    }}>
                      {showRateEdit ? "✓ Done Editing" : "✏ Edit Rates"}
                    </button>
                  </div>
                  {showRateEdit && (
                    <div style={{background:"#fff8e1",border:"1px solid #ffe082",borderRadius:10,padding:"12px 14px",marginBottom:10}}>
                      <div style={{fontSize:11,fontWeight:700,color:"#f57f17",marginBottom:10}}>⚙ Customize Rates</div>
                      <div style={{display:"grid",gridTemplateColumns:"1fr 1fr",gap:10}}>
                        {[
                          ["Service Fee","serviceFeePct","%"],["Insurance","insurancePct","%"],
                          ["Savings Deposit","sdPct","%"],["Share Cap CBU","scPct","%"],
                          ["Filing Fee","filingFeeAmt","₱ (flat)"],
                        ].map(([label, key, unit]) => (
                          <div key={key}>
                            <div style={{fontSize:10,color:"#888",fontWeight:600,marginBottom:3}}>{label} ({unit})</div>
                            <div style={{display:"flex",alignItems:"center",gap:4,background:"#fff",border:"1px solid #ffe082",borderRadius:8,padding:"4px 8px"}}>
                              <input type="number" step="0.01" min="0" max={unit==="₱ (flat)"?9999:100}
                                value={rates[key]} onChange={e => setRates(p=>({...p,[key]:parseFloat(e.target.value)||0}))}
                                style={{border:"none",outline:"none",width:"100%",fontSize:12,fontWeight:700,color:"#333"}}/>
                              <span style={{fontSize:10,color:"#aaa",flexShrink:0}}>{unit==="₱ (flat)"?"₱":"%"}</span>
                            </div>
                          </div>
                        ))}
                        <div>
                          <div style={{fontSize:10,color:"#888",fontWeight:600,marginBottom:3}}>Interest Rate Override (%/mo)</div>
                          <div style={{display:"flex",alignItems:"center",gap:4,background:"#fff",border:"1px solid #ffe082",borderRadius:8,padding:"4px 8px"}}>
                            <input type="number" step="0.001" min="0" max="100"
                              value={rates.interestOverride} onChange={e => setRates(p=>({...p,interestOverride:parseFloat(e.target.value)||0}))}
                              style={{border:"none",outline:"none",width:"100%",fontSize:12,fontWeight:700,color:"#333"}}/>
                            <span style={{fontSize:10,color:"#aaa"}}>%</span>
                          </div>
                          <div style={{fontSize:9,color:"#bbb",marginTop:2}}>0 = use default tiered rate</div>
                        </div>
                      </div>
                      <button type="button" onClick={() => setRates({serviceFeePct:3,insurancePct:1.25,sdPct:1,scPct:3,filingFeeAmt:amount<=50000?50:100,interestOverride:0})}
                        style={{marginTop:10,fontSize:10,color:"#c62828",background:"none",border:"none",cursor:"pointer",textDecoration:"underline"}}>
                        ↺ Reset to defaults
                      </button>
                    </div>
                  )}
                  <div className="al-deduct-box">
                    <div className="al-deduct-row"><span className="al-deduct-label">Loan Amount</span><span className="al-deduct-val">₱{amount.toLocaleString()}</span></div>
                    <div className="al-deduct-row"><span className="al-deduct-label">Monthly Amortization</span><span className="al-deduct-val" style={{color:"#2e7d32",fontWeight:700}}>₱{parseFloat(monthly).toLocaleString(undefined,{minimumFractionDigits:2})}</span></div>
                    <div className="al-deduct-divider"/>
                    <div style={{fontSize:11,fontWeight:600,color:"#555",margin:"4px 0 4px"}}>Upfront Deductions from Loan Release:</div>
                    {/* ── FIX: dating hiwalay na "Interest Rate" row sa
                        itaas + "Interest" deduction row sa ibaba —
                        parehong nagpapakita ng interest, kaya nagmumu-
                        khang naka-doble ang kaltas kahit hindi naman
                        (isa lang talaga ang aktwal na binabawas). Ngayon
                        isang linya na lang — ang rate info ay nailipat
                        dito sa loob ng "Interest" deduction mismo. ────── */}
                    <div className="al-deduct-row"><span className="al-deduct-label">Interest <span style={{fontSize:10,color:"#999",fontWeight:400}}>({(effectiveRate*100).toFixed(3)}%/mo × {term} months{rates.interestOverride>0?" (custom)":""})</span></span><span className="al-deduct-val al-deduct-red">− ₱{interest.toFixed(2)}</span></div>
                    <div className="al-deduct-row"><span className="al-deduct-label">Service Fee ({rates.serviceFeePct}%)</span><span className="al-deduct-val al-deduct-red">− ₱{serviceFee.toFixed(2)}</span></div>
                    <div className="al-deduct-row"><span className="al-deduct-label">Filing Fee (₱{rates.filingFeeAmt})</span><span className="al-deduct-val al-deduct-red">− ₱{filingFee.toFixed(2)}</span></div>
                    <div className="al-deduct-row"><span className="al-deduct-label">Insurance ({rates.insurancePct}%)</span><span className="al-deduct-val al-deduct-red">− ₱{insurance.toFixed(2)}</span></div>
                    <div className="al-deduct-row"><span className="al-deduct-label">Savings Deposit ({rates.sdPct}%)</span><span className="al-deduct-val al-deduct-red">− ₱{sd.toFixed(2)}</span></div>
                    <div className="al-deduct-row"><span className="al-deduct-label">Share Capital CBU ({rates.scPct}%)</span><span className="al-deduct-val al-deduct-red">− ₱{sc.toFixed(2)}</span></div>
                    <div className="al-deduct-divider"/>
                    <div className="al-deduct-row al-deduct-net"><span className="al-deduct-label">Net Proceeds</span><span className="al-net-val">₱{netProceeds.toFixed(2)}</span></div>
                  </div>
                  <div className="al-deduct-notice">
                    💡 Member will receive <strong>₱{netProceeds.toFixed(2)}</strong> after all deductions.
                  </div>
                </div>
              )}
            </div>
            <div className="al-modal-footer">
              <button className="al-btn-cancel" onClick={() => setStep(1)} disabled={loadingSubmit}>← Back</button>
              {/* ── BAGO: dating walang loading indicator man lang habang
                  nagsu-submit — walang paraan para malaman ng admin na
                  na-click na nang tama ang button, puwedeng ma-double-
                  click. Ngayon, naka-disable ang button at may spinner +
                  "Submitting..." text habang nagpo-proseso. ────────── */}
              <button className="al-btn-save" onClick={handleSubmit} disabled={loadingSubmit} style={{display:"flex",alignItems:"center",justifyContent:"center",gap:8}}>
                {loadingSubmit && (
                  <span style={{
                    display:"inline-block", width:13, height:13,
                    border:"2px solid rgba(255,255,255,0.4)", borderTopColor:"#fff",
                    borderRadius:"50%", animation:"al-spin 0.7s linear infinite",
                  }}/>
                )}
                {loadingSubmit ? "Submitting..." : "Submit Application"}
              </button>
              <style>{`@keyframes al-spin { to { transform: rotate(360deg); } }`}</style>
            </div>
          </>
        )}
      </div>
    </div>
  );
}


// ─── Share Capital Deposit Modal ──────────────────────────────────────────────
// ─── Main Layout ──────────────────────────────────────────────────────────────
export default function AdminLayout() {
  const [clock,       setClock]   = useState("");
  const [showF2F,     setF2F]     = useState(false);
  const [showReg,     setReg]     = useState(false);
  const [showLoan,    setLoan]    = useState(false);
  // ── BAGO: tinanggal ang "showSavings"/"showShareCap" state — mga
  // tunay na ROUTES na ito ngayon (SavingsDeposit.jsx,
  // ShareCapitalDeposit.jsx), hindi na modal na naka-toggle dito. ─────
  const [sidebarOpen,   setSidebar]      = useState(false);
  const [gcashPending,  setGcashPending] = useState(0);
  const [logoUrl,       setLogoUrl]      = useState(null);
  const [showSettings,  setShowSettings] = useState(false);
  const [showProfileMenu, setShowProfileMenu] = useState(false);
  const navigate                  = useNavigate();
  const location                  = useLocation();
  const { logout, user }          = useAuth();

  useEffect(() => { setSidebar(false); }, [location.pathname]);

  useEffect(() => {
      getSystemLogoAPI()
        .then(data => setLogoUrl(data.logo_url))
        .catch(() => {});
    }, []);


  const config = PAGE_CONFIG[location.pathname] || DEFAULT_CONFIG;

  useEffect(() => {
    const tick = () => {
      const now  = new Date();
      const days = ["SUN","MON","TUE","WED","THU","FRI","SAT"];
      const mons = ["JAN","FEB","MAR","APR","MAY","JUN","JUL","AUG","SEP","OCT","NOV","DEC"];
      const pad  = n => String(n).padStart(2, "0");
      setClock(`${days[now.getDay()]} ${mons[now.getMonth()]} ${now.getDate()}, ${now.getFullYear()} — ${pad(now.getHours())}:${pad(now.getMinutes())}:${pad(now.getSeconds())}`);
    };
    tick();
    const id = setInterval(tick, 1000);
    return () => clearInterval(id);
  }, []);

  useEffect(() => {
    const fetchCount = () => {
      getGCashRequestsAPI({ status:"Pending" })
        .then(d => setGcashPending(Array.isArray(d) ? d.length : 0))
        .catch(() => {});
    };
    fetchCount();
    const id = setInterval(fetchCount, 30000);
    return () => clearInterval(id);
  }, []);

  const handleAction = (action) => {
    if (action === "f2f")      setF2F(true);
    if (action === "register") setReg(true);
    if (action === "newloan")  setLoan(true);
    if (action === "export")   alert("Export feature will be connected to the backend.");
  };

  const handleLogout = () => { logout(); navigate("/login"); };

  return (
    <div className="admin-layout">
      {showF2F     && <F2FModal      onClose={() => setF2F(false)}     />}
      {showReg     && <RegisterModal onClose={() => setReg(false)}     />}
      {showLoan    && <NewLoanModal  onClose={() => setLoan(false)}    />}

      <div className={`sidebar-overlay ${sidebarOpen ? "open" : ""}`} onClick={() => setSidebar(false)} />

      <aside className={`sidebar ${sidebarOpen ? "open" : ""}`}>
        <div className="sidebar-logo">
          <div className="logo-icon">
            <img src={logoUrl || logo} alt="LEAF MPC Logo" style={{ height: "35px", width: "300px", objectFit: "contain" }} />
          </div>
        </div>
        <nav className="sidebar-nav">
          {NAV_ITEMS.map(item => (
            // ── BAGO: kung "action" (hindi "to") ang meron, button na
            // nagbubukas ng modal ito (Savings/Deposit, Share Capital
            // Deposit) imbes na NavLink na nag-na-navigate. ──────────
            item.action ? (
              <button key={item.action} onClick={() => handleAction(item.action)} className="nav-item" style={{width:"100%",textAlign:"left",background:"none",border:"none",cursor:"pointer"}}>
                <span className="nav-icon">{item.icon}</span>
                {item.label}
              </button>
            ) : (
              <NavLink key={item.to} to={item.to} className={({ isActive }) => "nav-item" + (isActive ? " active" : "")}>
              <span className="nav-icon">{item.icon}</span>
              {item.label}
              {item.to === "/admin/gcash-verification" && gcashPending > 0 && (
              <span style={{marginLeft:"auto",background:"#c62828",color:"#fff",borderRadius:20,padding:"1px 7px",fontSize:10,fontWeight:800}}>
              {gcashPending}
              </span>
              )}
              </NavLink>
            )
          ))}
        </nav>
        <div className="sidebar-bottom">
          <div className="clock-display">{clock}</div>
          <button className="logout-btn" onClick={handleLogout}>LOGOUT</button>
        </div>
      </aside>

      <div className="admin-main">
        <header className="topbar">
          <button className={`hamburger ${sidebarOpen ? "open" : ""}`} onClick={() => setSidebar(s => !s)} aria-label="Toggle menu">
            <span /><span /><span />
          </button>
          <div className="topbar-left">
            <div className="topbar-brand">ADMIN</div>
          </div>
          <div className="topbar-right">
            {config.actions.map((action, i) => (
              <button key={i}
                className={action.cls !== "btn-savings" && action.cls !== "btn-sharecap" ? `btn ${action.cls}` : "btn"}
                style={
                  action.cls === "btn-savings"  ? { background:"#f57f17", borderColor:"#f57f17", color:"#fff" } :
                  action.cls === "btn-sharecap" ? { background:"#1565c0", borderColor:"#1565c0", color:"#fff" } :
                  {}
                }
                onClick={() => handleAction(action.action)}>
                {action.label}
              </button>
            ))}
            <div className="al-profile-dropdown-wrap">
              <div className="user-chip" style={{cursor:"pointer"}} onClick={() => setShowProfileMenu(p => !p)}>
                <div className="user-avatar">{user?.initials?.[0] || "A"}</div>
                <div>
                  <span className="user-name">{user?.name || "Admin"}</span>
                  <span className="user-role">Admin</span>
                </div>
                <ChevronDown size={14} color="#999" style={{marginLeft:4}}/>
              </div>
              {showProfileMenu && (
                <>
                  <div style={{position:"fixed",inset:0,zIndex:190}} onClick={() => setShowProfileMenu(false)}/>
                  <div className="al-profile-dropdown">
                    <div className="al-profile-dropdown-header">
                      <div className="al-profile-dropdown-name">{user?.name || "Admin"}</div>
                      <div className="al-profile-dropdown-role">Administrator</div>
                    </div>
                    <button className="al-profile-dropdown-item" onClick={() => { setShowProfileMenu(false); setShowSettings(true); }}>
                      <SettingsIcon size={14}/> Settings
                    </button>
                    <button className="al-profile-dropdown-item danger" onClick={handleLogout}>
                      <LogOut size={14}/> Logout
                    </button>
                  </div>
                </>
              )}
            </div>
          </div>
        </header>
 
        {showSettings && (
          <SettingsModal
            onClose={() => setShowSettings(false)}
            logoUrl={logoUrl}
            onLogoUpdated={setLogoUrl}
          />
        )}
        <main className="page-content">
          <Outlet />
        </main>
      </div>
    </div>
  );
}