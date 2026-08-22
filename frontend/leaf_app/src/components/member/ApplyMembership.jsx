import { useState, useEffect } from "react";
import { useNavigate } from "react-router-dom";
import { useAuth } from "../../context/AuthContext";
import { submitApplicationAPI, getMyOnlineAppAPI } from "../../api/members";
import { GraduationCap, UserRound, BriefcaseBusiness, Upload, X, CheckCircle } from "lucide-react";
import { createClient } from "@supabase/supabase-js";
import "./ApplyMembership.css";

const SUPABASE_URL = import.meta.env.VITE_SUPABASE_URL || "https://vmicqkrguocawwntvizm.supabase.co";
const SUPABASE_KEY = import.meta.env.VITE_SUPABASE_ANON_KEY || "";
const supabase = SUPABASE_KEY ? createClient(SUPABASE_URL, SUPABASE_KEY) : null;

function FormField({ name, label, type="text", options=null, required=false, full=false, value, onChange, error }) {
  return (
    <div className={`am-field ${full ? "am-full" : ""}`}>
      <label className="am-label">{label}{required && <span className="am-req"> *</span>}</label>
      {options ? (
        <select className={`am-input ${error ? "am-input-err" : ""}`} name={name} value={value} onChange={onChange}>
          {options.map(o => typeof o === "object"
            ? <option key={o.value} value={o.value}>{o.label}</option>
            : <option key={o}>{o}</option>
          )}
        </select>
      ) : type === "checkbox" ? (
        <label className="am-checkbox-label">
          <input type="checkbox" name={name} checked={!!value} onChange={onChange}/>
          <span>Yes</span>
        </label>
      ) : type === "textarea" ? (
        <textarea className={`am-input ${error ? "am-input-err" : ""}`} name={name} value={value} onChange={onChange} rows={3} style={{resize:"none"}}/>
      ) : (
        <input className={`am-input ${error ? "am-input-err" : ""}`} type={type} name={name} value={value} onChange={onChange}/>
      )}
      {error && <div className="am-field-err">{error}</div>}
    </div>
  );
}

function IDUploadField({ label, required, file, preview, onSelect, onClear, error }) {
  return (
    <div className="am-field am-full">
      <label className="am-label">{label}{required && <span className="am-req"> *</span>}</label>
      {preview ? (
        <div style={{position:"relative",display:"inline-block",marginTop:6,width:"100%"}}>
          <img src={preview} alt={label} style={{width:"100%",maxWidth:320,borderRadius:10,border:"2px solid #a5d6a7",objectFit:"cover",maxHeight:180}}/>
          <button type="button" onClick={onClear} style={{position:"absolute",top:6,right:6,background:"#c62828",color:"#fff",border:"none",borderRadius:"50%",width:26,height:26,cursor:"pointer",display:"flex",alignItems:"center",justifyContent:"center"}}>
            <X size={13}/>
          </button>
          <div style={{marginTop:6,fontSize:11,color:"#2e7d32",display:"flex",alignItems:"center",gap:4}}>
            <CheckCircle size={12}/> {file?.name}
          </div>
        </div>
      ) : (
        <label style={{display:"flex",flexDirection:"column",alignItems:"center",justifyContent:"center",border:`2px dashed ${error?"#e53935":"#c8e6c9"}`,borderRadius:10,padding:"28px 16px",cursor:"pointer",background:error?"#fff5f5":"#f9fef9",marginTop:6,gap:8,transition:"all 0.2s"}}>
          <Upload size={30} color={error?"#e53935":"#2e7d32"}/>
          <div style={{fontSize:13,fontWeight:600,color:error?"#e53935":"#2e7d32"}}>Click to upload</div>
          <div style={{fontSize:11,color:"#aaa"}}>JPG, PNG, WEBP · Max 5MB</div>
          <input type="file" accept="image/jpeg,image/png,image/webp" style={{display:"none"}} onChange={e => { if(e.target.files[0]) onSelect(e.target.files[0]); }}/>
        </label>
      )}
      {error && <div className="am-field-err">{error}</div>}
    </div>
  );
}

// ─── Philippine Address Auto-complete (Region → Province → City → Barangay) ──
// Parehong PSGC API na ginamit sa AdminLayout's RegisterModal.
const PSGC_BASE = "https://psgc.gitlab.io/api";

function PhAddressPicker({ onAddressChange, error }) {
  const [regions,    setRegions]    = useState([]);
  const [provinces,  setProvinces]  = useState([]);
  const [cities,     setCities]     = useState([]);
  const [barangays,  setBarangays]  = useState([]);
  const [selRegion,   setSelRegion]   = useState(null);
  const [selProvince, setSelProvince] = useState(null);
  const [selCity,     setSelCity]     = useState(null);
  const [selBarangay, setSelBarangay] = useState(null);
  const [street, setStreet] = useState("");
  const [loadingLevel, setLoadingLevel] = useState(null);

  useEffect(() => {
    fetch(`${PSGC_BASE}/regions/`).then(r=>r.json()).then(d=>setRegions(Array.isArray(d)?d.sort((a,b)=>a.name.localeCompare(b.name)):[])).catch(()=>{});
  }, []);

  const emit = (r, p, c, b, st) => {
    const parts = [st, b?`Brgy. ${b.name}`:null, c?.name, p?.name, r?.name].filter(Boolean);
    onAddressChange(parts.join(", "));
  };

  const handleRegion = async (code) => {
    const r = regions.find(x => x.code === code) || null;
    setSelRegion(r); setSelProvince(null); setSelCity(null); setSelBarangay(null);
    setProvinces([]); setCities([]); setBarangays([]);
    emit(r, null, null, null, street);
    if (!r) return;
    setLoadingLevel("province");
    const d = await fetch(`${PSGC_BASE}/regions/${code}/provinces/`).then(r=>r.json()).catch(()=>[]);
    setProvinces(Array.isArray(d)?d.sort((a,b)=>a.name.localeCompare(b.name)):[]);
    setLoadingLevel(null);
  };

  const handleProvince = async (code) => {
    const p = provinces.find(x => x.code === code) || null;
    setSelProvince(p); setSelCity(null); setSelBarangay(null);
    setCities([]); setBarangays([]);
    emit(selRegion, p, null, null, street);
    if (!p) return;
    setLoadingLevel("city");
    const d = await fetch(`${PSGC_BASE}/provinces/${code}/cities-municipalities/`).then(r=>r.json()).catch(()=>[]);
    setCities(Array.isArray(d)?d.sort((a,b)=>a.name.localeCompare(b.name)):[]);
    setLoadingLevel(null);
  };

  const handleCity = async (code) => {
    const c = cities.find(x => x.code === code) || null;
    setSelCity(c); setSelBarangay(null);
    setBarangays([]);
    emit(selRegion, selProvince, c, null, street);
    if (!c) return;
    setLoadingLevel("barangay");
    const d = await fetch(`${PSGC_BASE}/cities-municipalities/${code}/barangays/`).then(r=>r.json()).catch(()=>[]);
    setBarangays(Array.isArray(d)?d.sort((a,b)=>a.name.localeCompare(b.name)):[]);
    setLoadingLevel(null);
  };

  const handleBarangay = (code) => {
    const b = barangays.find(x => x.code === code) || null;
    setSelBarangay(b);
    emit(selRegion, selProvince, selCity, b, street);
  };

  const handleStreet = (val) => {
    setStreet(val);
    emit(selRegion, selProvince, selCity, selBarangay, val);
  };

  const preview = [street, selBarangay?`Brgy. ${selBarangay.name}`:null, selCity?.name, selProvince?.name, selRegion?.name].filter(Boolean).join(", ");

  return (
    <div className="am-field am-full">
      <div className="am-form-grid" style={{gridColumn:"1/-1"}}>
        <div className="am-field">
          <label className="am-label">Region<span className="am-req"> *</span></label>
          <select className={`am-input ${error?"am-input-err":""}`} value={selRegion?.code||""} onChange={e=>handleRegion(e.target.value)}>
            <option value="">Select...</option>
            {regions.map(r=><option key={r.code} value={r.code}>{r.name}</option>)}
          </select>
        </div>
        <div className="am-field">
          <label className="am-label">Province<span className="am-req"> *</span></label>
          <select className="am-input" value={selProvince?.code||""} onChange={e=>handleProvince(e.target.value)} disabled={!selRegion}>
            <option value="">{loadingLevel==="province"?"Loading...":"Select..."}</option>
            {provinces.map(p=><option key={p.code} value={p.code}>{p.name}</option>)}
          </select>
        </div>
        <div className="am-field">
          <label className="am-label">City / Municipality<span className="am-req"> *</span></label>
          <select className="am-input" value={selCity?.code||""} onChange={e=>handleCity(e.target.value)} disabled={!selProvince}>
            <option value="">{loadingLevel==="city"?"Loading...":"Select..."}</option>
            {cities.map(c=><option key={c.code} value={c.code}>{c.name}</option>)}
          </select>
        </div>
        <div className="am-field">
          <label className="am-label">Barangay<span className="am-req"> *</span></label>
          <select className="am-input" value={selBarangay?.code||""} onChange={e=>handleBarangay(e.target.value)} disabled={!selCity}>
            <option value="">{loadingLevel==="barangay"?"Loading...":"Select..."}</option>
            {barangays.map(b=><option key={b.code} value={b.code}>{b.name}</option>)}
          </select>
        </div>
        <div className="am-field am-full">
          <label className="am-label">House No. / Street / Sitio <span className="am-label-optional">(optional)</span></label>
          <input className="am-input" value={street} onChange={e=>handleStreet(e.target.value)} placeholder="e.g. 123 Rizal St."/>
        </div>
      </div>
      {preview && (
        <div style={{marginTop:8,padding:"8px 12px",background:"#f1f8e9",borderRadius:8,fontSize:11,color:"#2e7d32",fontWeight:600}}>
          📍 {preview}
        </div>
      )}
      {error && <div className="am-field-err" style={{marginTop:6}}>{error}</div>}
    </div>
  );
}

const CLASS_OPTIONS = [
  { key: "Student",  icon: <GraduationCap     size={40} strokeWidth={1.5} color="#2e7d32"/>, label: "Student"  },
  { key: "Senior",   icon: <UserRound         size={40} strokeWidth={1.5} color="#2e7d32"/>, label: "Senior"   },
  { key: "Employed", icon: <BriefcaseBusiness size={40} strokeWidth={1.5} color="#2e7d32"/>, label: "Employed" },
];

const TABS = [
  { key: "personal",       label: "Personal Info"   },
  { key: "spouse",         label: "Spouse & Family" },
  { key: "classification", label: "Classification"  },
  { key: "verification",   label: "Verification"    },
];

export default function ApplyMembership() {
  const { user }  = useAuth();
  const navigate  = useNavigate();

  const [tab,            setTab]           = useState("personal");
  const [errors,         setErrors]        = useState({});
  const [done,           setDone]          = useState(false);
  const [loading,        setLoading]       = useState(false);
  const [existingApp,    setExistingApp]   = useState(null);
  const [checkingApp,    setCheckingApp]   = useState(true);
  const [resubmit,       setResubmit]      = useState(false);
  const [uploadProgress, setUploadProgress]= useState("");

  const [idFrontFile,    setIdFrontFile]    = useState(null);
  const [idBackFile,     setIdBackFile]     = useState(null);
  const [idFrontPreview, setIdFrontPreview] = useState(null);
  const [idBackPreview,  setIdBackPreview]  = useState(null);

  const [form, setForm] = useState({
    // Personal
    last_name:                    "",
    first_name:                   user?.name?.split(" ")[0] || "",
    middle_name:                  "",
    birth_date:                   "",
    place_of_birth:               "",
    sex:                          "Male",
    sex_other:                    "",
    civil_status:                 "Single",
    educational_attainment:       "",
    contact_number:               "",
    email:                        "",
    address:                      "",
    occupation:                   "",
    income:                       "",
    tin_no:                       "",
    sss_gsis_no:                  "",
    religious_social_affiliation: "",
    birth_certificate:            false,
    marriage_certificate:         false,
    // Spouse & Family
    spouse_name:                  "",
    spouse_occupation:            "",
    spouse_income:                "",
    no_of_dependants:             "",
    beneficiary_name:             "",
    beneficiary_relationship:     "",
    credit_references:            "",
    // Classification
    classification:               "Employed",
    school_name:                  "",
    year_level:                   "",
    allowance:                    "",
    pension_income:               "",
    job_type:                     "Employed",
    monthly_income:               "",
  });

  useEffect(() => {
    getMyOnlineAppAPI()
      .then(app => setExistingApp(app))
      .catch(() => setExistingApp(null))
      .finally(() => setCheckingApp(false));
  }, []);

  const handle = e => {
    const val = e.target.type === "checkbox" ? e.target.checked : e.target.value;
    setForm(p => ({ ...p, [e.target.name]: val }));
    setErrors(p => ({ ...p, [e.target.name]: "" }));
  };

  const handleIdSelect = (side, file) => {
    if (file.size > 5 * 1024 * 1024) {
      setErrors(p => ({ ...p, [`id_${side}`]: "File too large. Maximum is 5MB." }));
      return;
    }
    const preview = URL.createObjectURL(file);
    if (side === "front") { setIdFrontFile(file); setIdFrontPreview(preview); }
    else                  { setIdBackFile(file);  setIdBackPreview(preview);  }
    setErrors(p => ({ ...p, [`id_${side}`]: "" }));
  };

  const handleIdClear = side => {
    if (side === "front") { setIdFrontFile(null); setIdFrontPreview(null); }
    else                  { setIdBackFile(null);  setIdBackPreview(null);  }
  };

  const uploadToSupabase = async (file, path) => {
    if (!supabase) throw new Error("Supabase is not configured.");
    const { error } = await supabase.storage.from("member-documents").upload(path, file, { upsert: true, contentType: file.type });
    if (error) throw new Error(`Upload failed: ${error.message}`);
    const { data: urlData } = supabase.storage.from("member-documents").getPublicUrl(path);
    return urlData.publicUrl;
  };

  const validate = () => {
    const e = {};
    if (!form.first_name.trim())     e.first_name     = "Required";
    if (!form.last_name.trim())      e.last_name      = "Required";
    if (!form.birth_date)            e.birth_date     = "Required";
    if (!form.place_of_birth.trim()) e.place_of_birth = "Required";
    if (!form.sex || !form.sex.trim()) e.sex          = "Required";
    if (!form.contact_number.trim()) e.contact_number = "Required";
    if (!form.email.trim())          e.email          = "Required";
    else if (!/^\S+@\S+\.\S+$/.test(form.email)) e.email = "Please enter a valid email address.";
    if (!form.address.trim())        e.address        = "Please complete the address dropdowns above.";
    if (form.sex === "Other" && !(form.sex_other||"").trim()) e.sex_other = "Please specify";
    if (!form.occupation.trim())     e.occupation     = "Required";
    if (form.classification === "Student") {
      if (!form.school_name.trim()) e.school_name = "Required";
      if (!form.year_level.trim())  e.year_level  = "Required";
    }
    if (!idFrontFile) e.id_front = "Please upload the front side of your Valid ID.";
    if (!idBackFile)  e.id_back  = "Please upload the back side of your Valid ID.";
    return e;
  };

  const handleSubmit = async () => {
    const e = validate();
    if (Object.keys(e).length) {
      setErrors(e);
      const personalFields = ["first_name","last_name","birth_date","place_of_birth","sex","sex_other","contact_number","email","address","occupation"];
      const classFields    = ["school_name","year_level"];
      const idFields       = ["id_front","id_back"];
      if (personalFields.some(f => e[f])) { setTab("personal");       return; }
      if (classFields.some(f => e[f]))    { setTab("classification");  return; }
      if (idFields.some(f => e[f]))       { setTab("verification");    return; }
      return;
    }
    if (!supabase) {
      setErrors({ id_front: "Supabase is not configured. Add VITE_SUPABASE_ANON_KEY to your .env file." });
      setTab("verification");
      return;
    }
    setLoading(true);
    try {
      const ts     = Date.now();
      const userId = user?.id || "unknown";
      setUploadProgress("Uploading Valid ID (front)...");
      const idFrontUrl = await uploadToSupabase(idFrontFile, `valid-ids/${userId}_${ts}_front.${idFrontFile.name.split(".").pop()}`);
      setUploadProgress("Uploading Valid ID (back)...");
      const idBackUrl  = await uploadToSupabase(idBackFile,  `valid-ids/${userId}_${ts}_back.${idBackFile.name.split(".").pop()}`);
      setUploadProgress("Submitting application...");
      await submitApplicationAPI({
        first_name:                   form.first_name,
        last_name:                    form.last_name,
        middle_name:                  form.middle_name,
        birth_date:                   form.birth_date,
        place_of_birth:               form.place_of_birth,
        sex:                          form.sex === "Other" ? form.sex_other : form.sex,
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
        id_front_url:                 idFrontUrl,
        id_back_url:                  idBackUrl,
      });
      setDone(true);
    } catch(err) {
      const msg = err.response?.data?.error || err.response?.data?.detail || err.message || "Failed to submit. Please try again.";
      if (msg.toLowerCase().includes("upload") || msg.toLowerCase().includes("supabase")) {
        setErrors({ id_front: msg }); setTab("verification");
      } else {
        setErrors({ first_name: msg }); setTab("personal");
      }
    } finally { setLoading(false); setUploadProgress(""); }
  };

  if (checkingApp) return (
    <div className="am-wrap">
      <div className="am-card" style={{textAlign:"center",padding:"60px 20px",color:"#aaa"}}>
        Checking application status...
      </div>
    </div>
  );

  if (done) return (
    <div className="am-wrap">
      <div className="am-success-card">
        <div className="am-success-icon">🎉</div>
        <div className="am-success-title">Application Submitted!</div>
        <div className="am-success-text">
          Your membership application has been submitted successfully.
          The admin or staff will review it and notify you once processed.
        </div>
        <div className="am-success-notice">
          <div className="am-notice-icon">📋</div>
          <div>You can check the status in your notifications. You will be contacted once your application is reviewed.</div>
        </div>
        <div className="am-success-actions">
          <button className="am-btn-primary" onClick={() => navigate("/member/notifications")}>Go to Notifications</button>
          <button className="am-btn-secondary" onClick={() => navigate("/member/profile")}>View My Profile</button>
        </div>
      </div>
    </div>
  );

  if (existingApp && !resubmit) {
    const status     = existingApp.application_status;
    const isPending  = status === "Pending";
    const isApproved = status === "Approved";
    const isRejected = status === "Rejected";
    return (
      <div className="am-wrap">
        <div className="am-card">
          <div className="am-card-header">
            <div className="am-title">Membership Application</div>
          </div>
          <div style={{padding:"24px 28px",display:"flex",flexDirection:"column",gap:20}}>
            <div style={{display:"flex",alignItems:"center",gap:16,padding:"20px",borderRadius:12,border:"1.5px solid",
              background:isPending?"#fff8e1":isApproved?"#e8f5e9":"#ffebee",
              borderColor:isPending?"#ffe082":isApproved?"#a5d6a7":"#ef9a9a"}}>
              <div style={{fontSize:40}}>{isPending?"⏳":isApproved?"✅":"❌"}</div>
              <div>
                <div style={{fontWeight:700,fontSize:16,color:isPending?"#f57c00":isApproved?"#1b5e20":"#c62828"}}>
                  {isPending?"Application Under Review":isApproved?"Application Approved!":"Application Rejected"}
                </div>
                <div style={{fontSize:12,color:"#888",marginTop:4}}>
                  Application ID: <strong>{existingApp.app_id}</strong> · Submitted {existingApp.created_at?.slice(0,10)}
                </div>
                {isRejected && existingApp.reject_reason && (
                  <div style={{marginTop:8,fontSize:12,color:"#c62828",fontStyle:"italic"}}>Reason: {existingApp.reject_reason}</div>
                )}
                {isPending && <div style={{marginTop:8,fontSize:12,color:"#555"}}>Please wait for the admin to review your application.</div>}
                {isApproved && (
                  <div style={{marginTop:8,fontSize:12,color:"#555"}}>
                    Please visit the LEAF MPC office to complete the process.<br/>
                    <strong>Bring:</strong> 2x2 ID picture, Birth Certificate, Marriage Certificate (if married), Valid ID, and ₱4,000 minimum share capital.
                  </div>
                )}
              </div>
            </div>
            <div style={{display:"flex",gap:12,flexWrap:"wrap"}}>
              <button className="am-btn-secondary" onClick={() => navigate("/member/profile")}>View My Profile</button>
              {isRejected && <button className="am-btn-primary" onClick={() => setResubmit(true)}>Re-apply for Membership</button>}
            </div>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="am-wrap">
      <div className="am-card">
        <div className="am-card-header">
          <div className="am-title">{resubmit ? "Re-apply for Membership" : "Apply for Official Membership"}</div>
          <div className="am-sub">Fill out the LEAF MPC Member Application & Information Sheet below.</div>
        </div>

        {resubmit && (
          <div style={{margin:"0 28px",padding:"10px 14px",background:"#fff8e1",border:"1px solid #ffe082",borderRadius:8,fontSize:12,color:"#f57c00",fontWeight:600}}>
            You are re-applying after a previous rejection. Make sure to correct the issues before submitting.
          </div>
        )}

        <div className="am-info-notice">
          <div className="am-notice-icon">ℹ️</div>
          <div>Make sure all information is accurate. A valid ID is required for verification. Admin will review and contact you after submission.</div>
        </div>

        <div className="am-tabs">
          {TABS.map((t, i) => (
            <button key={t.key} className={`am-tab ${tab === t.key ? "active" : ""}`} onClick={() => setTab(t.key)}>
              <span className="am-tab-num">{i + 1}</span> {t.label}
            </button>
          ))}
        </div>

        <div className="am-form-body">

          {/* ── TAB 1: Personal Info ── */}
          {tab === "personal" && (
            <div className="am-form-grid">
              <FormField name="last_name"   label="Surname"    required value={form.last_name}   onChange={handle} error={errors.last_name}/>
              <FormField name="first_name"  label="First Name" required value={form.first_name}  onChange={handle} error={errors.first_name}/>
              <FormField name="middle_name" label="Middle Name"          value={form.middle_name} onChange={handle}/>

              <PhAddressPicker onAddressChange={addr => setForm(p => ({ ...p, address: addr }))} error={errors.address}/>

              <FormField name="birth_date"     label="Date of Birth"  required type="date" value={form.birth_date}     onChange={handle} error={errors.birth_date}/>
              <FormField name="place_of_birth" label="Place of Birth" required value={form.place_of_birth} onChange={handle} error={errors.place_of_birth}/>

              <FormField name="sex"          label="Sex"          required options={["Male","Female","Non-binary","Prefer not to say","Other"]}                     value={form.sex}          onChange={handle} error={errors.sex}/>
              {form.sex === "Other" && (
                <FormField name="sex_other" label="Please specify" required value={form.sex_other||""} onChange={handle} error={errors.sex_other}/>
              )}
              <FormField name="civil_status" label="Civil Status" options={["Single","Married","Widowed","Separated"]}                    value={form.civil_status} onChange={handle}/>

              <FormField name="tin_no"      label="TIN No."      value={form.tin_no}      onChange={handle}/>
              <FormField name="sss_gsis_no" label="SSS/GSIS No." value={form.sss_gsis_no} onChange={handle}/>

              <FormField name="occupation" label="Occupation"        required value={form.occupation} onChange={handle} error={errors.occupation}/>
              <FormField name="income"     label="Monthly Income (₱)" type="number" value={form.income} onChange={handle}/>

              <FormField name="contact_number" label="Tel. No. / CP No." required value={form.contact_number} onChange={handle} error={errors.contact_number}/>
              <FormField name="email"          label="Email Address"    type="email" required value={form.email} onChange={handle} error={errors.email}/>

              <FormField name="educational_attainment"       label="Educational Attainment"      options={["Elementary","High School","Vocational","College","Post Graduate"]} value={form.educational_attainment}       onChange={handle}/>
              <FormField name="religious_social_affiliation" label="Religious/Social Affiliation" value={form.religious_social_affiliation} onChange={handle}/>

              <div className="am-field">
                <label className="am-label">Birth Certificate Submitted</label>
                <label className="am-checkbox-label"><input type="checkbox" name="birth_certificate" checked={form.birth_certificate} onChange={handle}/><span>Yes</span></label>
              </div>
              <div className="am-field">
                <label className="am-label">Marriage Certificate Submitted</label>
                <label className="am-checkbox-label"><input type="checkbox" name="marriage_certificate" checked={form.marriage_certificate} onChange={handle}/><span>Yes (if married)</span></label>
              </div>
            </div>
          )}

          {/* ── TAB 2: Spouse & Family ── */}
          {tab === "spouse" && (
            <div className="am-form-grid">
              <div style={{gridColumn:"1/-1",background:"#f9fef9",border:"1px solid #e8f5e9",borderRadius:10,padding:"12px 16px",fontSize:12,color:"#555"}}>
                Fill in spouse information if married. Leave blank if not applicable.
              </div>

              <FormField name="spouse_name"       label="Spouse Name"               value={form.spouse_name}       onChange={handle}/>
              <FormField name="spouse_occupation" label="Spouse Occupation"          value={form.spouse_occupation} onChange={handle}/>
              <FormField name="spouse_income"     label="Spouse Monthly Income (₱)"  type="number" value={form.spouse_income}     onChange={handle}/>
              <FormField name="no_of_dependants"  label="No. of Dependants"          type="number" value={form.no_of_dependants}  onChange={handle}/>

              <div style={{gridColumn:"1/-1",borderTop:"1px solid #e8f5e9",paddingTop:16,marginTop:4}}>
                <div style={{fontSize:11,fontWeight:700,color:"#2e7d32",textTransform:"uppercase",letterSpacing:1,marginBottom:12}}>Beneficiary Information</div>
              </div>
              <FormField name="beneficiary_name"         label="Beneficiary Name"        value={form.beneficiary_name}         onChange={handle}/>
              <FormField name="beneficiary_relationship" label="Relationship to Applicant" value={form.beneficiary_relationship} onChange={handle}/>

              <div style={{gridColumn:"1/-1",borderTop:"1px solid #e8f5e9",paddingTop:16,marginTop:4}}>
                <div style={{fontSize:11,fontWeight:700,color:"#2e7d32",textTransform:"uppercase",letterSpacing:1,marginBottom:12}}>Credit References</div>
              </div>
              <FormField name="credit_references" label="Credit References" type="textarea" full value={form.credit_references} onChange={handle}/>
            </div>
          )}

          {/* ── TAB 3: Classification ── */}
          {tab === "classification" && (
            <div className="am-form-grid">
              <div className="am-field am-full">
                <label className="am-label">Member Classification <span className="am-req">*</span></label>
                <div className="am-class-options">
                  {CLASS_OPTIONS.map(c => (
                    <div key={c.key} className={`am-class-card ${form.classification === c.key ? "selected" : ""}`}
                      onClick={() => setForm(p => ({ ...p, classification: c.key }))}>
                      <div className="am-class-icon">{c.icon}</div>
                      <div className="am-class-name">{c.label}</div>
                    </div>
                  ))}
                </div>
              </div>
              {form.classification === "Student" && (<>
                <FormField name="school_name" label="School Name" required value={form.school_name} onChange={handle} error={errors.school_name}/>
                <FormField name="year_level"  label="Year Level"  required value={form.year_level}  onChange={handle} error={errors.year_level}
                  options={["Grade 7","Grade 8","Grade 9","Grade 10","Grade 11","Grade 12","1st Year","2nd Year","3rd Year","4th Year","5th Year","Graduate"]}/>
                <FormField name="allowance" label="Monthly Allowance (₱)" type="number" value={form.allowance} onChange={handle}/>
              </>)}
              {form.classification === "Senior" && (<>
                <FormField name="educational_attainment" label="Educational Attainment"
                  options={["Elementary","High School","Vocational","College","Post Graduate"]}
                  value={form.educational_attainment} onChange={handle}/>
                <FormField name="pension_income" label="Monthly Pension Income (₱)" type="number" value={form.pension_income} onChange={handle}/>
              </>)}
              {form.classification === "Employed" && (<>
                <FormField name="occupation"     label="Occupation/Job Title" value={form.occupation}     onChange={handle}/>
                <FormField name="job_type"       label="Employment Type"
                  options={["Employed","Self-Employed","Business","Freelance","Other"]}
                  value={form.job_type} onChange={handle}/>
                <FormField name="monthly_income" label="Monthly Income (₱)" type="number" value={form.monthly_income} onChange={handle}/>
              </>)}
            </div>
          )}

          {/* ── TAB 4: Verification ── */}
          {tab === "verification" && (
            <div className="am-form-grid">
              <div className="am-field am-full" style={{background:"#e8f5e9",borderRadius:10,padding:"14px 16px",border:"1px solid #c8e6c9"}}>
                <div style={{fontSize:13,fontWeight:700,color:"#1b5e20",marginBottom:6}}>Valid ID Verification (Required)</div>
                <div style={{fontSize:12,color:"#555",lineHeight:1.7}}>
                  Upload a clear photo of your <strong>Valid ID — both front and back sides</strong>.<br/>
                  Accepted: PhilSys · Driver's License · Passport · SSS · GSIS · PRC · Voter's ID · Postal ID · Senior Citizen's ID · School ID
                </div>
              </div>

              {!supabase && (
                <div className="am-field am-full" style={{background:"#ffebee",borderRadius:8,padding:"12px 14px",border:"1px solid #ef9a9a",fontSize:12,color:"#c62828",fontWeight:600}}>
                  ID upload is not yet configured. Please add VITE_SUPABASE_ANON_KEY to your .env file.
                </div>
              )}

              <IDUploadField label="Valid ID — Front Side" required file={idFrontFile} preview={idFrontPreview} onSelect={f => handleIdSelect("front", f)} onClear={() => handleIdClear("front")} error={errors.id_front}/>
              <IDUploadField label="Valid ID — Back Side"  required file={idBackFile}  preview={idBackPreview}  onSelect={f => handleIdSelect("back", f)}  onClear={() => handleIdClear("back")}  error={errors.id_back}/>

              <div className="am-field am-full" style={{background:"#fff8e1",borderRadius:8,padding:"10px 14px",border:"1px solid #ffe082",fontSize:11,color:"#f57c00"}}>
                Make sure the ID photo is clear and fully readable. Blurry or incomplete images may cause rejection.
              </div>
            </div>
          )}
        </div>

        <div className="am-form-footer">
          {uploadProgress && (
            <div style={{fontSize:12,color:"#2e7d32",fontWeight:600,marginBottom:8,textAlign:"center",padding:"8px",background:"#e8f5e9",borderRadius:8}}>
              {uploadProgress}
            </div>
          )}
          <div className="am-tab-nav">
            {tab !== "personal" && (
              <button className="am-btn-back" onClick={() => {
                const keys = TABS.map(t => t.key);
                setTab(keys[keys.indexOf(tab) - 1]);
              }}>Previous</button>
            )}
            {tab !== "verification" ? (
              <button className="am-btn-next" onClick={() => {
                const keys = TABS.map(t => t.key);
                setTab(keys[keys.indexOf(tab) + 1]);
              }}>Next</button>
            ) : (
              <button className={`am-btn-submit ${loading ? "loading" : ""}`} onClick={handleSubmit}
                disabled={loading || !supabase} title={!supabase ? "Supabase not configured" : ""}>
                {loading ? <span className="am-spinner"/> : resubmit ? "Re-submit Application" : "Submit Application"}
              </button>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}