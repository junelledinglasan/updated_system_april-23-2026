import { useState, useEffect } from "react";
import { submitGCashRequestAPI } from "../../api/loans";
import { getActiveGCashAccountsAPI } from "../../api/settings";
import { useLanguage } from "../../context/LanguageContext";
import { Smartphone, Copy, CheckCircle, X, AlertCircle, Upload, Image, Trash2 } from "lucide-react";
import { createClient } from "@supabase/supabase-js";

const supabase = createClient(
  import.meta.env.VITE_SUPABASE_URL,
  import.meta.env.VITE_SUPABASE_ANON_KEY
);

// ── Hindi na naka-hardcode — kinukuha na mula sa Settings (backend,
// na-e-edit ng admin sa "💳 GCash Payment" tab). Fallback lang ito. ──
const FALLBACK_GCASH_NUMBER = "0967-006-3500";
const FALLBACK_GCASH_NAME   = "LEAF MPC";

export default function GCashPayment({ loan, onClose, onSuccess }) {
  const { t } = useLanguage();
  const [step,    setStep]    = useState(1); // 1=instructions, 2=form, 3=success
  const [form,       setForm]      = useState({ amount: loan?.monthly_due || "", reference_number: "", note: "" });
  const [errors,     setErrors]    = useState({});
  const [loading,    setLoading]   = useState(false);
  const [result,     setResult]    = useState(null);
  const [copied,     setCopied]    = useState(false);
  const [screenshot, setScreenshot]= useState(null);   // File object
  const [scrPreview, setScrPreview]= useState("");     // preview URL
  const [uploading,  setUploading] = useState(false);

  // ── BAGO: maraming GCash account na puwedeng piliin ng member —
  // dating iisang number/name lang. ────────────────────────────────────
  const [gcashAccounts, setGcashAccounts] = useState([]);
  const [selectedAccountId, setSelectedAccountId] = useState(null);
  const selectedAccount = gcashAccounts.find(a => a.id === selectedAccountId) || null;

  useEffect(() => {
    getActiveGCashAccountsAPI()
      .then(data => {
        setGcashAccounts(data);
        if (data.length > 0) setSelectedAccountId(data[0].id);
      })
      .catch(() => { /* silent — walang ipapakitang account, ipapakita na lang ang generic instructions */ });
  }, []);

  const displayNumber = selectedAccount?.number || FALLBACK_GCASH_NUMBER;
  const displayName   = selectedAccount?.account_name || FALLBACK_GCASH_NAME;

  const copyNumber = () => {
    navigator.clipboard.writeText(displayNumber.replace(/-/g, ""));
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  const handleScreenshot = (e) => {
    const file = e.target.files[0];
    if (!file) return;
    if (file.size > 5 * 1024 * 1024) {
      setErrors(p => ({...p, screenshot:t("gc_file_too_large")}));
      return;
    }
    setScreenshot(file);
    setScrPreview(URL.createObjectURL(file));
    setErrors(p => ({...p, screenshot:""}));
  };

  const uploadScreenshot = async () => {
    if (!screenshot) return "";
    setUploading(true);
    try {
      const ext      = screenshot.name.split(".").pop();
      const filename = `gcash-proofs/${Date.now()}-${Math.random().toString(36).slice(2)}.${ext}`;
      const { data, error } = await supabase.storage
        .from("member-documents")
        .upload(filename, screenshot, { upsert: false });
      if (error) throw error;
      const { data: urlData } = supabase.storage
        .from("member-documents")
        .getPublicUrl(filename);
      return urlData.publicUrl || "";
    } catch(e) {
      console.error("Upload error:", e);
      return "";
    } finally {
      setUploading(false);
    }
  };

  const validate = () => {
    const e = {};
    if (!form.amount || parseFloat(form.amount) <= 0)
      e.amount = t("gc_enter_amount_paid");
    if (parseFloat(form.amount) > parseFloat(loan?.balance || 0))
      e.amount = t("gc_amount_exceeds", { bal: Number(loan?.balance).toLocaleString() });
    if (!form.reference_number.trim())
      e.reference_number = t("gc_ref_required");
    if (form.reference_number.trim().length < 10)
      e.reference_number = t("gc_ref_invalid");
    if (!screenshot)
      e.screenshot = t("gc_screenshot_required");
    return e;
  };

  const handleSubmit = async () => {
    const e = validate();
    if (Object.keys(e).length) { setErrors(e); return; }
    setLoading(true);
    try {
      let screenshotUrl = "";
      if (screenshot) {
        screenshotUrl = await uploadScreenshot();
      }

      const res = await submitGCashRequestAPI({
        loan_id:          loan.id,
        amount:           parseFloat(form.amount),
        reference_number: form.reference_number.trim(),
        note:             form.note.trim(),
        screenshot_url:   screenshotUrl,
        // ── BAGO: kasama na kung aling GCash account ang ginamit —
        // para malaman ng admin saang account dapat i-verify. ────────
        paid_to_number: displayNumber,
        paid_to_name:   displayName,
      });
      setResult(res);
      setStep(3);
      if (onSuccess) onSuccess(res);
    } catch(err) {
      const msg = err.response?.data?.error || t("gc_failed_submit");
      setErrors({ reference_number: msg });
    } finally {
      setLoading(false);
    }
  };

  return (
    <div style={{position:"fixed",inset:0,background:"rgba(0,0,0,0.6)",zIndex:9999,display:"flex",alignItems:"center",justifyContent:"center",padding:16}} onClick={onClose}>
      <div style={{background:"#fff",borderRadius:16,width:"100%",maxWidth:420,maxHeight:"90vh",overflow:"hidden",display:"flex",flexDirection:"column",boxShadow:"0 8px 32px rgba(0,0,0,0.25)"}} onClick={e=>e.stopPropagation()}>

        {/* Header */}
        <div style={{background:"linear-gradient(135deg,#007bff,#0056b3)",padding:"16px 20px",display:"flex",alignItems:"center",justifyContent:"space-between"}}>
          <div style={{display:"flex",alignItems:"center",gap:10}}>
            <div style={{background:"rgba(255,255,255,0.2)",borderRadius:10,padding:8,display:"flex"}}>
              <Smartphone size={20} color="#fff"/>
            </div>
            <div>
              <div style={{color:"#fff",fontWeight:800,fontSize:15}}>{t("gc_title")}</div>
              <div style={{color:"rgba(255,255,255,0.8)",fontSize:11}}>{t("gc_loan_colon", { id: loan?.loan_id })}</div>
            </div>
          </div>
          <button onClick={onClose} style={{background:"rgba(255,255,255,0.2)",border:"none",borderRadius:8,padding:6,cursor:"pointer",display:"flex",alignItems:"center"}}>
            <X size={16} color="#fff"/>
          </button>
        </div>

        {/* Step indicator */}
        <div style={{display:"flex",borderBottom:"1px solid #f0f0f0"}}>
          {[t("gc_step_payment_info"),t("gc_step_submit_reference"),t("gc_step_done")].map((s,i) => (
            <div key={i} style={{flex:1,padding:"10px 8px",textAlign:"center",fontSize:11,fontWeight:600,
              color:step===i+1?"#007bff":step>i+1?"#2e7d32":"#bbb",
              borderBottom:step===i+1?"2px solid #007bff":step>i+1?"2px solid #2e7d32":"2px solid transparent",
            }}>
              {step > i+1 ? <CheckCircle size={12} style={{marginRight:4}}/> : null}
              {s}
            </div>
          ))}
        </div>

        <div style={{padding:"20px",overflowY:"auto",flex:1}}>

          {/* Step 1: Instructions */}
          {step === 1 && (
            <div style={{display:"flex",flexDirection:"column",gap:16}}>
              {/* Loan info */}
              <div style={{background:"#f0f7ff",borderRadius:12,padding:"14px 16px",border:"1px solid #cce5ff"}}>
                <div style={{fontSize:12,color:"#555",marginBottom:8,fontWeight:700}}>{t("gc_loan_details")}</div>
                <div style={{display:"grid",gridTemplateColumns:"1fr 1fr",gap:8}}>
                  {[
                    [t("gc_loan_id"),     loan?.loan_id],
                    [t("gc_loan_type"),   loan?.loan_type],
                    [t("gc_balance"),     `₱${Number(loan?.balance||0).toLocaleString()}`],
                    [t("gc_monthly_due"), `₱${Number(loan?.monthly_due||0).toLocaleString()}`],
                  ].map(([k,v]) => (
                    <div key={k}>
                      <div style={{fontSize:10,color:"#888",fontWeight:600}}>{k}</div>
                      <div style={{fontSize:13,fontWeight:700,color:"#1565c0"}}>{v}</div>
                    </div>
                  ))}
                </div>
              </div>

              {/* ── BAGO: kung mahigit isa ang aktibong account,
                  pipiliin muna ng member kung saan magbabayad. ─────── */}
              {gcashAccounts.length > 1 && (
                <div style={{background:"#fff",borderRadius:12,padding:"12px 14px",border:"1px solid #e0e0e0"}}>
                  <div style={{fontSize:11,color:"#555",fontWeight:700,marginBottom:8,textTransform:"uppercase",letterSpacing:0.5}}>Choose GCash Account</div>
                  <div style={{display:"flex",flexDirection:"column",gap:8}}>
                    {gcashAccounts.map(acc => (
                      <label key={acc.id} style={{
                        display:"flex",alignItems:"center",gap:10,padding:"9px 12px",borderRadius:8,cursor:"pointer",
                        border:"1.5px solid "+(selectedAccountId===acc.id?"#2e7d32":"#e0e0e0"),
                        background:selectedAccountId===acc.id?"#e8f5e9":"#fff",
                      }}>
                        <input type="radio" name="gcashAcct" checked={selectedAccountId===acc.id} onChange={()=>setSelectedAccountId(acc.id)}/>
                        <div>
                          {acc.label && <span style={{fontSize:9,fontWeight:700,color:"#2e7d32",marginRight:6}}>{acc.label}</span>}
                          <span style={{fontSize:13,fontFamily:"monospace",fontWeight:700}}>{acc.number}</span>
                          <div style={{fontSize:11,color:"#888"}}>{acc.account_name}</div>
                        </div>
                      </label>
                    ))}
                  </div>
                </div>
              )}

              {/* GCash number */}
              <div style={{background:"#e8f5e9",borderRadius:12,padding:"16px",border:"1px solid #a5d6a7",textAlign:"center"}}>
                <div style={{fontSize:11,color:"#2e7d32",fontWeight:700,marginBottom:6,textTransform:"uppercase",letterSpacing:0.5}}>{t("gc_send_payment_to")}</div>
                <div style={{fontSize:24,fontWeight:800,color:"#1b5e20",letterSpacing:2,marginBottom:4}}>{displayNumber}</div>
                <div style={{fontSize:13,color:"#555",marginBottom:12}}>{displayName}</div>
                <button onClick={copyNumber} style={{
                  display:"inline-flex",alignItems:"center",gap:6,
                  padding:"8px 16px",borderRadius:20,cursor:"pointer",fontSize:12,fontWeight:700,
                  background:copied?"#2e7d32":"#fff",color:copied?"#fff":"#2e7d32",
                  border:"2px solid #2e7d32",transition:"all 0.2s",
                }}>
                  {copied ? <><CheckCircle size={13}/> {t("gc_copied")}</> : <><Copy size={13}/> {t("gc_copy_number")}</>}
                </button>
              </div>

              {/* Instructions */}
              <div style={{background:"#fffde7",borderRadius:10,padding:"12px 14px",border:"1px solid #ffe082"}}>
                <div style={{fontSize:12,fontWeight:700,color:"#f57f17",marginBottom:8}}>{t("gc_how_to_pay")}</div>
                {[
                  t("gc_step1"),
                  t("gc_step2", { number: displayNumber, name: displayName }),
                  t("gc_step3"),
                  t("gc_step4"),
                  t("gc_step5"),
                  t("gc_step6"),
                ].map((step, i) => (
                  <div key={i} style={{display:"flex",gap:10,marginBottom:6,fontSize:12,color:"#555"}}>
                    <span style={{width:20,height:20,borderRadius:"50%",background:"#f57f17",color:"#fff",fontSize:10,fontWeight:800,display:"flex",alignItems:"center",justifyContent:"center",flexShrink:0}}>{i+1}</span>
                    {step}
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* Step 2: Submit Reference */}
          {step === 2 && (
            <div style={{display:"flex",flexDirection:"column",gap:14}}>
              <div style={{background:"#e8f5e9",borderRadius:10,padding:"10px 14px",border:"1px solid #a5d6a7",fontSize:12,color:"#2e7d32",fontWeight:600}}>
                {t("gc_after_sending")}
              </div>

              {/* Amount */}
              <div>
                <label style={{fontSize:11,fontWeight:700,color:"#555",textTransform:"uppercase",letterSpacing:0.5}}>
                  {t("gc_amount_paid")} <span style={{color:"#e53935"}}>*</span>
                </label>
                <div style={{display:"flex",border:`1.5px solid ${errors.amount?"#e53935":"#e0e0e0"}`,borderRadius:10,overflow:"hidden",marginTop:6}}>
                  <span style={{padding:"0 12px",background:"#f5f5f5",color:"#888",display:"flex",alignItems:"center",fontSize:14,fontWeight:700}}>₱</span>
                  <input
                    type="number"
                    value={form.amount}
                    onChange={e => { setForm(p=>({...p,amount:e.target.value})); setErrors(p=>({...p,amount:""})); }}
                    placeholder={t("gc_amount_placeholder", { amt: Number(loan?.monthly_due||0).toLocaleString() })}
                    style={{flex:1,border:"none",outline:"none",padding:"11px 12px",fontSize:14,fontFamily:"inherit"}}
                  />
                </div>
                {errors.amount && <div style={{fontSize:11,color:"#e53935",marginTop:4,display:"flex",alignItems:"center",gap:4}}><AlertCircle size={11}/>{errors.amount}</div>}
              </div>

              {/* Reference Number */}
              <div>
                <label style={{fontSize:11,fontWeight:700,color:"#555",textTransform:"uppercase",letterSpacing:0.5}}>
                  {t("gc_reference_number")} <span style={{color:"#e53935"}}>*</span>
                </label>
                <input
                  type="text"
                  value={form.reference_number}
                  onChange={e => { setForm(p=>({...p,reference_number:e.target.value})); setErrors(p=>({...p,reference_number:""})); }}
                  placeholder={t("gc_ref_placeholder")}
                  maxLength={20}
                  style={{
                    width:"100%",boxSizing:"border-box",marginTop:6,
                    padding:"11px 14px",fontSize:15,fontFamily:"monospace",fontWeight:700,
                    border:`1.5px solid ${errors.reference_number?"#e53935":"#e0e0e0"}`,
                    borderRadius:10,outline:"none",letterSpacing:2,
                  }}
                />
                {errors.reference_number && <div style={{fontSize:11,color:"#e53935",marginTop:4,display:"flex",alignItems:"center",gap:4}}><AlertCircle size={11}/>{errors.reference_number}</div>}
                <div style={{fontSize:10,color:"#aaa",marginTop:4}}>{t("gc_ref_hint")}</div>
              </div>

              {/* Note (optional) */}
              <div>
                <label style={{fontSize:11,fontWeight:700,color:"#555",textTransform:"uppercase",letterSpacing:0.5}}>{t("gc_note_optional")}</label>
                <input
                  type="text"
                  value={form.note}
                  onChange={e => setForm(p=>({...p,note:e.target.value}))}
                  placeholder={t("gc_note_placeholder")}
                  style={{width:"100%",boxSizing:"border-box",marginTop:6,padding:"11px 14px",fontSize:13,border:"1.5px solid #e0e0e0",borderRadius:10,outline:"none",fontFamily:"inherit"}}
                />
              </div>

                            {/* Screenshot upload */}
              <div>
                <label style={{fontSize:11,fontWeight:700,color:"#555",textTransform:"uppercase",letterSpacing:0.5}}>
                  {t("gc_proof_payment")} <span style={{color:"#e53935"}}>*</span>
                </label>
                <div style={{marginTop:6}}>
                  {scrPreview ? (
                    <div style={{position:"relative"}}>
                      <img src={scrPreview} alt="GCash screenshot" style={{width:"100%",maxHeight:220,objectFit:"contain",borderRadius:10,border:"2px solid #90caf9",display:"block"}}/>
                      <button onClick={()=>{setScreenshot(null);setScrPreview("");}} style={{position:"absolute",top:6,right:6,background:"#c62828",border:"none",borderRadius:"50%",width:26,height:26,cursor:"pointer",display:"flex",alignItems:"center",justifyContent:"center"}}>
                        <Trash2 size={13} color="#fff"/>
                      </button>
                    </div>
                  ) : (
                    <label style={{display:"flex",flexDirection:"column",alignItems:"center",justifyContent:"center",gap:8,padding:"20px 16px",border:"2px dashed #90caf9",borderRadius:10,background:"#f0f7ff",cursor:"pointer"}}>
                      <Image size={28} color="#1565c0"/>
                      <span style={{fontSize:12,color:"#1565c0",fontWeight:700}}>{t("gc_upload_hint")}</span>
                      <span style={{fontSize:10,color:"#aaa"}}>{t("gc_upload_types")}</span>
                      <input type="file" accept="image/*" onChange={handleScreenshot} style={{display:"none"}}/>
                    </label>
                  )}
                  {errors.screenshot && <div style={{fontSize:11,color:"#e53935",marginTop:4}}>{errors.screenshot}</div>}
                </div>
              </div>

              <div style={{background:"#fff8e1",borderRadius:8,padding:"10px 12px",border:"1px solid #ffe082",fontSize:11,color:"#f57f17"}}>
                {t("gc_warning_note")}
              </div>
            </div>
          )}

          {/* Step 3: Success */}
          {step === 3 && (
            <div style={{textAlign:"center",padding:"20px 0",display:"flex",flexDirection:"column",alignItems:"center",gap:16}}>
              <div style={{width:64,height:64,borderRadius:"50%",background:"#e8f5e9",display:"flex",alignItems:"center",justifyContent:"center"}}>
                <CheckCircle size={32} color="#2e7d32"/>
              </div>
              <div>
                <div style={{fontSize:16,fontWeight:800,color:"#1b5e20",marginBottom:6}}>{t("gc_submitted_title")}</div>
                <div style={{fontSize:13,color:"#555",lineHeight:1.6}}>
                  {t("gc_submitted_sub")}
                </div>
              </div>
              <div style={{background:"#f1f8e9",borderRadius:12,padding:"14px 16px",border:"1px solid #c8e6c9",width:"100%",textAlign:"left"}}>
                {[
                  [t("gc_ref_no_label"), result?.reference_number],
                  [t("gc_amount_label"), `₱${Number(result?.amount||0).toLocaleString()}`],
                  [t("gc_status_label"), t("gc_pending_verification")],
                ].map(([k,v]) => (
                  <div key={k} style={{display:"flex",justifyContent:"space-between",padding:"5px 0",fontSize:12,borderBottom:"1px solid #e8f5e9"}}>
                    <span style={{color:"#888"}}>{k}</span>
                    <span style={{fontWeight:700,color:"#1b5e20",fontFamily:k===t("gc_ref_no_label")?"monospace":"inherit"}}>{v}</span>
                  </div>
                ))}
              </div>
              <div style={{fontSize:12,color:"#888",lineHeight:1.6}}>
                {t("gc_final_note")}
              </div>
            </div>
          )}
        </div>

        {/* Footer */}
        <div style={{padding:"14px 20px",borderTop:"1px solid #f0f0f0",display:"flex",gap:10,justifyContent:"flex-end"}}>
          {step === 1 && (<>
            <button onClick={onClose} style={{padding:"9px 18px",border:"1px solid #e0e0e0",borderRadius:9,background:"#fff",color:"#666",fontSize:13,fontWeight:600,cursor:"pointer",fontFamily:"inherit"}}>{t("gc_cancel")}</button>
            <button onClick={() => setStep(2)} style={{padding:"9px 20px",background:"#007bff",color:"#fff",border:"none",borderRadius:9,fontSize:13,fontWeight:700,cursor:"pointer",fontFamily:"inherit"}}>
              {t("gc_ive_sent")}
            </button>
          </>)}
          {step === 2 && (<>
            <button onClick={() => setStep(1)} style={{padding:"9px 18px",border:"1px solid #e0e0e0",borderRadius:9,background:"#fff",color:"#666",fontSize:13,fontWeight:600,cursor:"pointer",fontFamily:"inherit"}}>{t("gc_back")}</button>
            <button onClick={handleSubmit} disabled={loading||uploading} style={{padding:"9px 20px",background:"#2e7d32",color:"#fff",border:"none",borderRadius:9,fontSize:13,fontWeight:700,cursor:"pointer",fontFamily:"inherit",opacity:loading?0.7:1}}>
              {uploading ? t("gc_uploading") : loading ? t("gc_submitting") : t("gc_submit_reference_btn")}
            </button>
          </>)}
          {step === 3 && (
            <button onClick={onClose} style={{padding:"9px 20px",background:"#2e7d32",color:"#fff",border:"none",borderRadius:9,fontSize:13,fontWeight:700,cursor:"pointer",fontFamily:"inherit"}}>{t("gc_done")}</button>
          )}
        </div>
      </div>
    </div>
  );
}