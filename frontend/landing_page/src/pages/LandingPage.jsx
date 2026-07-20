import { useState, useEffect } from "react";
import {
  MapPin, Phone, Mail, Clock, Menu, X,
  Banknote, Shield, ShoppingBag, TreePine,
  ChevronRight, Smartphone,
} from "lucide-react";
import "./LandingPage.css";

const API_URL   = "http://localhost:8000/api";
const LOGIN_URL = "http://localhost:3000/login";

const SERVICES = [
  { icon: <Banknote size={28}/>,    title: "Pautang",         items: ["Regular Loan","Special Loan","Pretty Cash Loan"] },
  { icon: <Shield size={28}/>,      title: "Pag-iimpok",      items: ["Savings Deposit","Time Deposit"] },
  { icon: <ShoppingBag size={28}/>, title: "Consumer Store",  items: ["Sari-sari Store","Borloloy Accessories","Organic Fertilizer"] },
  { icon: <TreePine size={28}/>,    title: "Community",       items: ["Environmental Services","Livelihood Training","Financial Literacy"] },
];

const TIMELINE = [
  { year:"1999", title:"Founded",         text:"Established February 22, 1999 by 17 founding members with ₱11,000 starting capital. Registered with CDA on March 15, 1999 under Reg. No. LGA-3938." },
  { year:"2002", title:"PEARLS Building", text:"Adopted by Mr. Vicente 'Vic' M. Olea and moved to the PEARLS Building in Brgy. Kulapi, Lucban, Quezon at no cost (2002–2004)." },
  { year:"2006", title:"New Leadership",  text:"Management transferred to Mrs. Mylen S. Ibarrola on March 2, 2006. Office was destroyed by fire on September 26, 2006." },
  { year:"2007", title:"New Office",      text:"Relocated to 63 Concepcion St. on September 15, 2007, serving over 207 members." },
  { year:"2009", title:"Expansion",       text:"Moved to 61 Concepcion St. on November 14, 2009. Year-end: 339 members, ₱928,655.38 capital pledge, ₱2,361,288.23 total assets." },
];

const STAFF = [
  { name:"Russel S. De Ramos",        role:"Manager",                            head:true  },
  { name:"Rachele A. Cabantig",       role:"Bookkeeper"                                     },
  { name:"Maricon Aiza E. Manlutac",  role:"Cashier"                                        },
  { name:"Jade Ashley T. Venzuela",   role:"Administrative Clerk"                           },
  { name:"Napoleon M. Aves",          role:"Field Teller"                                   },
  { name:"Alden E. Cosejo",           role:"Store Clerk"                                    },
  { name:"Ethel D. Beringuel",        role:"Compliance Officer / Borloloy Staff"            },
];

const TYPE_COLOR = {
  Activity:{ bg:"#e8f5e9",color:"#1b5e20" },
  Seminar: { bg:"#e3f2fd",color:"#0d47a1" },
  Notice:  { bg:"#fff3e0",color:"#e65100" },
  General: { bg:"#f3e5f5",color:"#6a1b9a" },
  Event:   { bg:"#e8f5e9",color:"#1b5e20" },
};

const NAV = ["Home","About","History","Services","Team","Announcements","Contact"];

function initials(name){ return name.split(" ").slice(0,2).map(w=>w[0]).join(""); }

export default function LandingPage() {
  const [open,    setOpen]   = useState(false);
  const [solid,   setSolid]  = useState(false);
  const [anns,    setAnns]   = useState([]);
  const [loading, setLoad]   = useState(true);
  const [annPage, setAnnPage] = useState(1);
  const ANN_PER_PAGE = 6;

  useEffect(()=>{
    const fn = ()=>setSolid(window.scrollY>60);
    window.addEventListener("scroll",fn);
    return ()=>window.removeEventListener("scroll",fn);
  },[]);

  useEffect(()=>{
    fetch(`${API_URL}/announcements/`)
      .then(r=>r.json())
      .then(d=>setAnns(Array.isArray(d)?d:[]))
      .catch(()=>setAnns([]))
      .finally(()=>setLoad(false));
  },[]);

  const go = id => {
    document.getElementById(id.toLowerCase())?.scrollIntoView({behavior:"smooth"});
    setOpen(false);
  };

  return (
    <div className="lp">

      {/* ── Floating Download Button ── */}
      <a href="/leafmpc.apk" download className="fab-download" title="Download LEAF MPC Mobile App">
        <Smartphone size={20}/>
        <span>Download App</span>
      </a>

      {/* ── NAVBAR ── */}
      <nav className={`nav${solid?" nav--s":""}`}>
        <div className="nav-w">
          <button className="nav-logo" onClick={()=>go("home")}>
            <img src="/logo.png" alt="LEAF MPC"/>
          </button>
          <div className={`nav-links${open?" open":""}`}>
            {NAV.map(n=>(
              <button key={n} className="nav-a" onClick={()=>go(n)}>{n}</button>
            ))}
          </div>
          <div className="nav-end">
            <a className="btn-solid" href={LOGIN_URL}>Login</a>
            <button className="nav-ham" onClick={()=>setOpen(o=>!o)}>
              {open?<X size={22}/>:<Menu size={22}/>}
            </button>
          </div>
        </div>
      </nav>

      {/* ── HERO ── */}
      <section id="home" className="hero">
        <div className="hero-w">
          <div className="hero-left">
            <p className="hero-eyebrow">Est. 1999 · Lucban, Quezon · CDA Reg. No. LGA-3938</p>
            <h1 className="hero-h1">
              LEAF<br/>Multi-Purpose<br/>Cooperative
            </h1>
            <p className="hero-p">
              Lucban Environmentalist Agro-Forestry Multi-Purpose Cooperative —
              empowering members through financial services, community development,
              and environmental stewardship since 1999.
            </p>
            <div className="hero-stats">
              {[["1999","Established"],["339+","Members"],["LGA-3938","CDA Registered"]].map(([v,l])=>(
                <div key={l} className="hero-stat">
                  <span className="hero-stat-v">{v}</span>
                  <span className="hero-stat-l">{l}</span>
                </div>
              ))}
            </div>
            <div className="hero-btns">
              <a className="btn-solid" href={LOGIN_URL}>Member Portal</a>
              <button className="btn-outline" onClick={()=>go("about")}>Learn More</button>
            </div>
            <div style={{marginTop:16,display:"flex",alignItems:"center",gap:10}}>
            </div>
          </div>
          <div className="hero-right">
            <div className="hero-logo-ring">
              <img src="/logo.png" alt="LEAF MPC Logo" className="hero-logo"/>
            </div>
          </div>
        </div>
      </section>

      {/* ── ABOUT ── */}
      <section id="about" className="sec sec--white">
        <div className="ctn">
          <div className="sec-label">About Us</div>
          <h2 className="sec-h2">Who We Are</h2>
          <p className="sec-intro">
            LEAF MPC is a member-owned, community-driven cooperative registered
            with the Cooperative Development Authority. We believe financial empowerment
            and environmental responsibility go hand in hand.
          </p>
          <div className="vmc-grid">
            <div className="vmc-card">
              <div className="vmc-tag">Vision</div>
              <p>A sustainable and trusted cooperative anchored in its concern for the environment and community development.</p>
            </div>
            <div className="vmc-card">
              <div className="vmc-tag">Mission</div>
              <p>Provide responsive financial and non-financial services to members and the community it serves.</p>
            </div>
            <div className="vmc-card">
              <div className="vmc-tag">Core Values</div>
              <div className="values">
                {[["L","Loyalty and Servant-Leadership"],["E","Environment"],["A","Accountability"],["F","Fairness and Faith"]].map(([k,v])=>(
                  <div key={k} className="value-row">
                    <span className="value-k">{k}</span>
                    <span className="value-v">{v}</span>
                  </div>
                ))}
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* ── HISTORY ── */}
      <section id="history" className="sec sec--green">
        <div className="ctn">
          <div className="sec-label sec-label--lt">History</div>
          <h2 className="sec-h2 sec-h2--lt">Background &amp; History</h2>
          <div className="timeline">
            {TIMELINE.map((t,i)=>(
              <div key={i} className="tl-item">
                <div className="tl-year">{t.year}</div>
                <div className="tl-mid">
                  <div className="tl-dot"/>
                  {i<TIMELINE.length-1&&<div className="tl-line"/>}
                </div>
                <div className="tl-body">
                  <div className="tl-title">{t.title}</div>
                  <p className="tl-text">{t.text}</p>
                </div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* ── SERVICES ── */}
      <section id="services" className="sec sec--gray">
        <div className="ctn">
          <div className="sec-label">Services</div>
          <h2 className="sec-h2">What We Offer</h2>
          <div className="svc-grid">
            {SERVICES.map((s,i)=>(
              <div key={i} className="svc-card">
                <div className="svc-icon">{s.icon}</div>
                <div className="svc-title">{s.title}</div>
                <ul className="svc-list">
                  {s.items.map((it,j)=>(
                    <li key={j} className="svc-item">
                      <ChevronRight size={13} style={{flexShrink:0,marginTop:2}}/>
                      {it}
                    </li>
                  ))}
                </ul>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* ── TEAM ── */}
      <section id="team" className="sec sec--white">
        <div className="ctn">
          <div className="sec-label">Our People</div>
          <h2 className="sec-h2">Management Staff</h2>
          <div className="team-head">
            <div className="staff-card staff-card--head">
              <div className="avatar avatar--lg">{initials(STAFF[0].name)}</div>
              <div className="staff-name">{STAFF[0].name}</div>
              <div className="staff-role">{STAFF[0].role}</div>
            </div>
          </div>
          <div className="team-grid">
            {STAFF.slice(1).map((s,i)=>(
              <div key={i} className="staff-card">
                <div className="avatar">{initials(s.name)}</div>
                <div className="staff-name">{s.name}</div>
                <div className="staff-role">{s.role}</div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* ── ANNOUNCEMENTS ── */}
      <section id="announcements" className="sec sec--gray">
        <div className="ctn">
          <div className="sec-label">Announcements</div>
          <h2 className="sec-h2">Latest Updates</h2>
          <p className="sec-intro" style={{marginBottom:36}}>
            Stay informed with the latest news, events, and notices from LEAF MPC.
          </p>
          {loading ? (
            <div className="ann-empty">Loading announcements...</div>
          ) : anns.length===0 ? (
            <div className="ann-empty">No announcements yet. Check back soon!</div>
          ) : (
            <>
              <div className="ann-grid">
                {anns.slice((annPage-1)*ANN_PER_PAGE, annPage*ANN_PER_PAGE).map(a=>{
                  const type    = a.category||a.type||"General";
                  const st      = TYPE_COLOR[type]||TYPE_COLOR.General;
                  const body    = a.body||a.caption||a.content||"";
                  const date    = a.created_at||a.posted_at||"";
                  const imgUrl  = a.image_url||a.image||"";
                  return (
                    <div key={a.id} className="ann-card">
                      {imgUrl && (
                        <div className="ann-img-wrap">
                          <img src={imgUrl} alt={a.title} className="ann-img"
                            onError={e=>e.target.parentElement.style.display="none"}/>
                        </div>
                      )}
                      <div className="ann-content">
                        <div className="ann-top">
                          <span className="ann-type" style={{background:st.bg,color:st.color}}>{type}</span>
                          <span className="ann-date">{date?new Date(date).toLocaleDateString("en-PH",{month:"short",day:"numeric",year:"numeric"}):""}</span>
                        </div>
                        <div className="ann-title">{a.title}</div>
                        <p className="ann-body">{body.length>150?body.slice(0,150)+"…":body}</p>
                        <div className="ann-by">— {a.posted_by||"Admin"}</div>
                      </div>
                    </div>
                  );
                })}
              </div>
              {/* Pagination */}
              {anns.length > ANN_PER_PAGE && (
                <div className="ann-pagination">
                  <button className="ann-pg-btn" disabled={annPage===1} onClick={()=>setAnnPage(p=>p-1)}>
                    ← Prev
                  </button>
                  <span className="ann-pg-info">
                    Page {annPage} of {Math.ceil(anns.length/ANN_PER_PAGE)}
                  </span>
                  <button className="ann-pg-btn" disabled={annPage>=Math.ceil(anns.length/ANN_PER_PAGE)} onClick={()=>setAnnPage(p=>p+1)}>
                    Next →
                  </button>
                </div>
              )}
            </>
          )}
        </div>
      </section>

      {/* ── CONTACT ── */}
      <section id="contact" className="sec sec--white">
        <div className="ctn">
          <div className="sec-label">Contact</div>
          <h2 className="sec-h2">Get in Touch</h2>
          <div className="contact-grid">
            {[
              { icon:<MapPin size={22}/>, label:"Address",      val:"61 Concepcion St.\nLucban, Quezon, Philippines" },
              { icon:<Phone  size={22}/>, label:"Phone",        val:"(042) 123-4567\n0917-123-4567" },
              { icon:<Mail   size={22}/>, label:"Email",        val:"LEAFMPC@gmail.com" },
              { icon:<Clock  size={22}/>, label:"Office Hours", val:"Mon–Fri: 8:00 AM – 5:00 PM\nSat: 8:00 AM – 12:00 PM" },
            ].map((c,i)=>(
              <div key={i} className="contact-card">
                <div className="contact-icon">{c.icon}</div>
                <div className="contact-label">{c.label}</div>
                <div className="contact-val" style={{whiteSpace:"pre-line"}}>{c.val}</div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* ── FOOTER ── */}
      <footer className="footer">
        <div className="ctn">
          <div className="footer-top">
            <div className="footer-brand">
              <img src="/logo.png" alt="LEAF MPC" className="footer-logo" onError={e=>e.target.style.display="none"}/>
              <div>
                <div className="footer-name">LEAF Multi-Purpose Cooperative</div>
                <div className="footer-sub">61 Concepcion St., Lucban, Quezon</div>
                <div className="footer-sub">LEAFMPC@gmail.com</div>
              </div>
            </div>
            <div className="footer-nav">
              {NAV.map(n=>(
                <button key={n} className="footer-a" onClick={()=>go(n)}>{n}</button>
              ))}
            </div>
          </div>
          <div className="footer-hr"/>
          <div className="footer-bottom">
            © {new Date().getFullYear()} LEAF Multi-Purpose Cooperative · CDA Reg. No. LGA-3938
          </div>
        </div>
      </footer>

    </div>
  );
}