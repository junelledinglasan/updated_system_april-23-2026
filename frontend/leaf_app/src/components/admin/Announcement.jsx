import { useState, useEffect, useRef } from "react";
import { getAnnouncementsAPI, getAnnouncementAPI, createAnnouncementAPI, updateAnnouncementAPI, deleteAnnouncementAPI, addCommentAPI, deleteCommentAPI, reactToAnnouncementAPI } from "../../api/announcements";
import { useAuth } from "../../context/AuthContext";
import { Search, Pin, Bell, Pencil, Trash2, MessageCircle, X, ThumbsUp, Heart, Laugh, Frown, Angry as AngryIcon, Sparkles, AlertTriangle, Paperclip } from "lucide-react";
import "./Announcement.css";

const POST_TYPES = ["Activity","Seminar","Notice","Announcement","Event"];
const TYPE_COLOR = { Activity:"type-activity", Seminar:"type-seminar", Notice:"type-notice", Announcement:"type-announce", Event:"type-event" };

// ── Reactions (parang Facebook) ──────────────────────────────────────────
// ── BAGO: dating naka-emoji ito (👍❤️😂😮😢😠) — ngayon totoong
// lucide-react icons, tugma sa "walang emoji" na patakaran sa buong
// system. Walang eksaktong lucide icon para sa "surprised/wow" face,
// kaya "Sparkles" ang ginamit kong pinakamalapit na alternatibo. ──────
const REACTION_ICON  = { Like: ThumbsUp, Love: Heart, Haha: Laugh, Wow: Sparkles, Sad: Frown, Angry: AngryIcon };
const REACTION_COLOR = { Like:"#1565c0", Love:"#c62828", Haha:"#f57f17", Wow:"#f57f17", Sad:"#f57f17", Angry:"#e65100" };

// ── Reaction button + "Reacted by" list (hover sa count = makikita ang mga pangalan) ──
function ReactionButton({ myReaction, totalReactions, reactions, onReact, stopPropagation }) {
  const [showPicker, setShowPicker] = useState(false);
  const [showWho,    setShowWho]    = useState(false);
  const hideTimer = useRef(null);

  const openPicker = () => { clearTimeout(hideTimer.current); setShowPicker(true); };
  const scheduleHide = () => { hideTimer.current = setTimeout(() => setShowPicker(false), 300); };

  const ReactionIcon = myReaction ? REACTION_ICON[myReaction] : ThumbsUp;
  const color = myReaction ? (REACTION_COLOR[myReaction] || "#2e7d32") : "#888";
  const label = myReaction || "Like";

  return (
    <div className="an-reaction-wrap" onClick={e => stopPropagation && e.stopPropagation()}>
      <div className="an-reaction-btn-wrap" onMouseEnter={openPicker} onMouseLeave={scheduleHide}>
        {showPicker && (
          <div className="an-reaction-picker" onMouseEnter={openPicker} onMouseLeave={scheduleHide}>
            {Object.entries(REACTION_ICON).map(([type, Icon]) => (
              <span key={type} className="an-reaction-emoji" title={type}
                onClick={(ev) => { ev.stopPropagation(); onReact(type); setShowPicker(false); }}>
                <Icon size={16} color={REACTION_COLOR[type]}/>
              </span>
            ))}
          </div>
        )}
        <button className="an-reaction-btn" style={{ color }} onClick={(e) => { e.stopPropagation(); onReact(myReaction || "Like"); }}>
          <span style={{display:"inline-flex",alignItems:"center"}}><ReactionIcon size={14}/></span>
          <span style={{ fontWeight: myReaction ? 800 : 600 }}>{label}</span>
        </button>
      </div>

      {/* ── "Reacted by" — parang Facebook, i-hover ang count para makita ang mga pangalan ── */}
      {totalReactions > 0 && (
        <div className="an-reacted-by-wrap" onMouseEnter={() => setShowWho(true)} onMouseLeave={() => setShowWho(false)}>
          <span className="an-reacted-by-count">{totalReactions} reacted</span>
          {showWho && (
            <div className="an-reacted-by-list">
              {(reactions || []).map(r => {
                const RIcon = REACTION_ICON[r.reaction_type] || ThumbsUp;
                return (
                  <div key={r.id} className="an-reacted-by-item">
                    <span style={{display:"inline-flex",alignItems:"center"}}><RIcon size={13} color={REACTION_COLOR[r.reaction_type]}/></span>
                    <span>{r.posted_by_name}</span>
                  </div>
                );
              })}
            </div>
          )}
        </div>
      )}
    </div>
  );
}

// ─── Create / Edit Post Modal ──────────────────────────────────────────────────
function PostModal({ editPost, onClose, onSave }) {
  const [type,    setType]    = useState(editPost?.type   ||"Activity");
  const [title,   setTitle]   = useState(editPost?.title  ||"");
  const [caption, setCaption] = useState(editPost?.body||editPost?.caption||"");
  const [pinned,  setPinned]  = useState(editPost?.pinned ||false);
  const [image,   setImage]   = useState(null);
  const [preview, setPreview] = useState(editPost?.image_url||null);
  const [errors,  setErrors]  = useState({});
  const [loading, setLoading] = useState(false);

  const handleImageChange = (e) => {
    const file = e.target.files[0];
    if (!file) return;
    setImage(file);
    setPreview(URL.createObjectURL(file));
  };

  const validate = () => {
    const e = {};
    if (!title.trim())   e.title   = "Title is required.";
    if (!caption.trim()) e.caption = "Caption is required.";
    return e;
  };

  const handleSubmit = async () => {
    const e = validate();
    if (Object.keys(e).length) { setErrors(e); return; }
    setLoading(true);
    try {
      const formData = new FormData();
      formData.append("type",    type);
      formData.append("title",   title);
      formData.append("body",    caption);
      formData.append("pinned",  pinned);
      if (image) formData.append("image", image);
      await onSave(formData);
    } finally { setLoading(false); }
  };

  return (
    <div className="an-overlay" onClick={onClose}>
      <div className="an-modal an-modal-lg" onClick={e=>e.stopPropagation()}>
        <div className="an-modal-header">
          <div className="an-modal-title">{editPost?"Edit Post":"Create New Post"}</div>
          <button className="an-modal-close" onClick={onClose}><X size={16}/></button>
        </div>
        <div className="an-modal-body">
          {/* Type pills */}
          <div className="an-form-row">
            <div className="an-field flex1">
              <label className="an-label">Post Type <span className="an-req">*</span></label>
              <div className="an-type-pills">
                {POST_TYPES.map(t=>(
                  <button key={t} className={`an-type-pill ${TYPE_COLOR[t]} ${type===t?"selected":""}`} onClick={()=>setType(t)} type="button">{t}</button>
                ))}
              </div>
            </div>
            <div className="an-field">
              <label className="an-label">Options</label>
              <label className="an-checkbox-wrap">
                <input type="checkbox" checked={pinned} onChange={e=>setPinned(e.target.checked)}/>
                <span style={{display:"inline-flex",alignItems:"center",gap:4}}><Pin size={13}/> Pin this post</span>
              </label>
            </div>
          </div>
          {/* Title */}
          <div className="an-field">
            <label className="an-label">Title <span className="an-req">*</span></label>
            <input className={`an-input ${errors.title?"input-error":""}`} type="text" value={title} onChange={e=>{setTitle(e.target.value);setErrors(p=>({...p,title:""}));}} placeholder="e.g. Annual General Assembly 2026" maxLength={100}/>
            {errors.title && <div className="an-error">{errors.title}</div>}
          </div>
          {/* Caption */}
          <div className="an-field">
            <label className="an-label">Caption / Description <span className="an-req">*</span></label>
            <textarea className={`an-textarea ${errors.caption?"input-error":""}`} value={caption} onChange={e=>{setCaption(e.target.value);setErrors(p=>({...p,caption:""}));}} placeholder="Write the announcement details here..." rows={5}/>
            {errors.caption && <div className="an-error">{errors.caption}</div>}
          </div>
          {/* Image upload */}
          <div className="an-field">
            <label className="an-label">Attach Image <span className="an-label-optional">(optional)</span></label>
            <label className="an-image-upload-label">
              <input type="file" accept="image/*" onChange={handleImageChange} style={{display:"none"}}/>
              <div className="an-image-upload-btn" style={{display:"flex",alignItems:"center",justifyContent:"center",gap:6}}><Paperclip size={14}/> Choose Image</div>
            </label>
            {preview && (
              <div className="an-image-preview-wrap">
                <img src={preview} alt="preview" className="an-image-preview"/>
                <button className="an-image-remove" onClick={()=>{setImage(null);setPreview(null);}} style={{display:"flex",alignItems:"center",gap:4,justifyContent:"center"}}><X size={12}/> Remove</button>
              </div>
            )}
          </div>
        </div>
        <div className="an-modal-footer">
          <button className="an-btn-cancel" onClick={onClose}>Cancel</button>
          <button className="an-btn-save" onClick={handleSubmit} disabled={loading}>{loading?"Saving...":editPost?"Save Changes":"Post Announcement"}</button>
        </div>
      </div>
    </div>
  );
}

// ─── View Post Modal ───────────────────────────────────────────────────────────
function ViewPostModal({ post, onClose, onEdit, onDelete, currentUser, onCommentChange, onReact }) {
  const [comment,  setComment]  = useState("");
  const [comments, setComments] = useState(post?.comments||[]);
  const [loading,  setLoading]  = useState(false);
  if (!post) return null;

  // ── FIX: dating may useEffect dito na tumatawag ng getAnnouncementsAPI()
  // (KINUKUHA ANG BUONG LISTAHAN ng LAHAT ng announcements) tuwing
  // magbubukas ng isang post, para lang makuha ang comments ng ISANG
  // post na 'yon — malaking overfetch, ito ang pangunahing dahilan ng
  // pagkabagal ng loading. Tinanggal na ito — ang "post.comments" mula
  // sa parent ay sapat na, dahil sync na ito sa optimistic local updates
  // sa add/delete comment sa ibaba. ────────────────────────────────────
  useEffect(() => { setComments(post?.comments||[]); }, [post?.id, post?.comments]);

  const handleAddComment = async () => {
    if (!comment.trim()) return;
    setLoading(true);
    try {
      const newComment = await addCommentAPI(post.id, comment);
      setComments(prev => [...prev, newComment]);
      setComment("");
      // ── FIX: tinanggal ang "onRefresh()" dito — dating nagre-refetch
      // ng BUONG LISTAHAN ng announcements para lang sa ISANG bagong
      // comment, kahit na-update na naman nang tama ang lokal na state
      // sa itaas. Sa halip, "onCommentChange" na lang — mabilis na
      // lokal na pag-update ng comment_count sa parent, walang network
      // request. ──────────────────────────────────────────────────────
      if (onCommentChange) onCommentChange(post.id, 1);
    } catch { alert("Failed to add comment."); }
    finally { setLoading(false); }
  };

  const handleDeleteComment = async (cId) => {
    try {
      await deleteCommentAPI(post.id, cId);
      setComments(prev => prev.filter(c => c.id !== cId));
      // ── FIX: tinanggal din ang "onRefresh()" dito, parehong dahilan. ──
      if (onCommentChange) onCommentChange(post.id, -1);
    } catch { alert("Failed to delete comment."); }
  };

  return (
    <div className="an-overlay" onClick={onClose}>
      <div className="an-modal an-modal-view" onClick={e=>e.stopPropagation()}>
        <div className="an-modal-header">
          <div className="an-modal-title">{post.title}</div>
          <button className="an-modal-close" onClick={onClose}><X size={16}/></button>
        </div>
        <div className="an-modal-body">
          <div className="an-view-meta">
            <span className={`an-type-badge ${TYPE_COLOR[post.type]}`}>{post.type}</span>
            <span className="an-view-author">by {post.posted_by_name||"Admin"}</span>
            <span className="an-view-date">{post.created_at}</span>
          </div>
          {/* ── Image — "fit" na parang Facebook, hindi naka-crop ── */}
          {post.image_url && (
            <div className="an-view-image-wrap">
              <img src={post.image_url} alt="post" className="an-view-image"/>
            </div>
          )}
          <div className="an-view-body" style={{whiteSpace:"pre-wrap",lineHeight:1.7,color:"#333",fontSize:14}}>
            {post.body||post.caption}
          </div>

          {/* ── Reaction bar ── */}
          <div className="an-view-reaction-row">
            <ReactionButton
              myReaction={post.my_reaction}
              totalReactions={post.total_reactions || 0}
              reactions={post.reactions}
              onReact={(type) => onReact(post.id, type)}
            />
          </div>

          <div className="an-comments-section">
            <div className="an-comments-title" style={{display:"flex",alignItems:"center",gap:6}}><MessageCircle size={14}/> Comments ({comments.length})</div>
            <div className="an-comments-list">
              {comments.length===0
                ? <div className="an-no-comments">No comments yet. Be the first to comment!</div>
                : comments.map(c=>(
                  <div key={c.id} className="an-comment">
                    <div className="an-comment-avatar">{(c.posted_by_name||"U")[0]}</div>
                    <div className="an-comment-body">
                      <div className="an-comment-author">{c.posted_by_name}<span className="an-comment-role">{c.posted_by_role}</span></div>
                      <div className="an-comment-text">{c.body}</div>
                      <div className="an-comment-time">{c.created_at}</div>
                    </div>
                    {(currentUser?.role==="admin"||currentUser?.id===c.posted_by) && (
                      <button className="an-comment-del" onClick={()=>handleDeleteComment(c.id)}><X size={12}/></button>
                    )}
                  </div>
                ))
              }
            </div>
            <div className="an-comment-input-wrap">
              <input className="an-comment-input" placeholder="Write a comment..." value={comment} onChange={e=>setComment(e.target.value)} onKeyDown={e=>{if(e.key==="Enter"&&!e.shiftKey)handleAddComment();}}/>
              <button className="an-comment-send" onClick={handleAddComment} disabled={!comment.trim()||loading}>{loading?"...":"Send"}</button>
            </div>
          </div>
        </div>
        <div className="an-modal-footer">
          <button className="an-btn-cancel" onClick={onClose}>Close</button>
          {(currentUser?.role==="admin"||currentUser?.role==="staff") && (
            <>
              <button className="an-btn-edit" onClick={()=>onEdit(post)} style={{display:"flex",alignItems:"center",gap:6}}><Pencil size={13}/> Edit</button>
              <button className="an-btn-delete" onClick={()=>onDelete(post.id)} style={{display:"flex",alignItems:"center",gap:6}}><Trash2 size={13}/> Delete</button>
            </>
          )}
        </div>
      </div>
    </div>
  );
}

// ─── Main Component ────────────────────────────────────────────────────────────
export default function Announcement() {
  const { user } = useAuth();
  const [posts,      setPosts]    = useState([]);
  const [loading,    setLoading]  = useState(true);
  const [filter,     setFilter]   = useState("All");
  const [search,     setSearch]   = useState("");
  const [showCreate, setCreate]   = useState(false);
  const [editPost,   setEditPost] = useState(null);
  const [viewPost,   setViewPost] = useState(null);
  const [deleteId,   setDeleteId] = useState(null);
  const [toast,      setToast]    = useState(null);

  const showToast = (msg,type="success") => { setToast({msg,type}); setTimeout(()=>setToast(null),3000); };

  const fetchPosts = async (silent = false) => {
    if (!silent) setLoading(true);
    try { const data = await getAnnouncementsAPI(); setPosts(data); }
    catch(e) { console.error(e); }
    finally { if (!silent) setLoading(false); }
  };

  useEffect(() => { fetchPosts(); }, []);

  const handleCreate = async (data) => {
    try {
      const newPost = await createAnnouncementAPI(data);
      setCreate(false);
      showToast("Announcement posted successfully!");
      setPosts(prev => [newPost, ...prev]);
    } catch(err) {
      console.error("[CREATE ERROR]", err.response?.data || err.message);
      const msg = err.response?.data?.detail
        || Object.values(err.response?.data||{})[0]?.[0]
        || "Failed to post announcement.";
      showToast(msg, "danger");
    }
  };

  const handleEdit = async (data) => {
    try {
      const updated = await updateAnnouncementAPI(editPost.id, data);
      setEditPost(null); setViewPost(null);
      showToast("Announcement updated!");
      setPosts(prev => prev.map(p => p.id === editPost.id ? updated : p));
    } catch(err) {
      console.error("[UPDATE ERROR]", err.response?.data || err.message);
      const msg = err.response?.data?.detail
        || Object.values(err.response?.data||{})[0]?.[0]
        || "Failed to update.";
      showToast(msg, "danger");
    }
  };

  const handleDelete = async (id) => {
    setDeleteId(id);
  };

  const confirmDelete = async () => {
    try {
      await deleteAnnouncementAPI(deleteId);
      setViewPost(null);
      setDeleteId(null);
      showToast("Announcement deleted.", "danger");
      setPosts(prev => prev.filter(p => p.id !== deleteId));
    } catch { showToast("Failed to delete.", "danger"); }
  };

  // ── FIX: dating nagre-refetch ng BUONG LISTAHAN ng announcements
  // (getAnnouncementsAPI()) tuwing may nag-react sa isang post — malaking
  // overfetch, isa pa sa pangunahing dahilan ng pagkabagal. Ngayon,
  // gagamitin muna ang "result" mismo na ibinabalik ng reaction endpoint
  // (kung buong updated post ang laman nito). Kung hindi kumpleto ang
  // laman nito (walang "reactions" field), i-fallback na lang sa
  // "getAnnouncementAPI(postId)" — kinukuha lang ang ISANG post na 'to,
  // hindi na ang BUONG listahan. ───────────────────────────────────────
  const handleReact = async (postId, reactionType) => {
    try {
      const result = await reactToAnnouncementAPI(postId, reactionType);
      const updatedPost = (result && result.reactions !== undefined) ? result : await getAnnouncementAPI(postId);
      setPosts(prev => prev.map(p => p.id === postId ? { ...p, ...updatedPost } : p));
      setViewPost(prev => prev && prev.id === postId ? { ...prev, ...updatedPost } : prev);
    } catch(e) { console.error(e); }
  };

  // ── BAGO: mabilis na lokal na pag-update ng comment_count — walang
  // network request, imbes na buong refetch tuwing may bagong comment. ──
  const handleCommentChange = (postId, delta) => {
    setPosts(prev => prev.map(p => p.id === postId ? { ...p, comment_count: Math.max(0, (p.comment_count||0) + delta) } : p));
    setViewPost(prev => prev && prev.id === postId ? { ...prev, comment_count: Math.max(0, (prev.comment_count||0) + delta) } : prev);
  };

  const filtered = posts.filter(p => {
    const matchType = filter==="All" || p.type===filter;
    const q = search.toLowerCase();
    return matchType && (
      (p.title||"").toLowerCase().includes(q) ||
      (p.body||"").toLowerCase().includes(q)
    );
  });

  const pinnedPosts  = filtered.filter(p => p.pinned);
  const regularPosts = filtered.filter(p => !p.pinned);
  const sortedPosts  = [...pinnedPosts, ...regularPosts];

  const stats = {
    total:    posts.length,
    pinned:   posts.filter(p=>p.pinned).length,
    comments: posts.reduce((sum,p)=>sum+(p.comment_count||0),0),
    notified: posts.filter(p=>p.notified).length,
  };

  return (
    <div className="an-wrapper">
      {toast && <div className={`an-toast an-toast-${toast.type}`}>{toast.msg}</div>}
      {showCreate && <PostModal onClose={()=>setCreate(false)} onSave={handleCreate}/>}
      {editPost   && <PostModal editPost={editPost} onClose={()=>setEditPost(null)} onSave={handleEdit}/>}
      {viewPost   && <ViewPostModal post={viewPost} onClose={()=>setViewPost(null)} onEdit={p=>{setViewPost(null);setEditPost(p);}} onDelete={handleDelete} currentUser={user} onCommentChange={handleCommentChange} onReact={handleReact}/>}

      {/* ── Custom Delete Confirmation Modal ── */}
      {deleteId && (
        <div className="an-overlay" onClick={()=>setDeleteId(null)}>
          <div className="an-modal" style={{maxWidth:400}} onClick={e=>e.stopPropagation()}>
            <div className="an-modal-header">
              <div className="an-modal-title" style={{color:"#c62828",display:"flex",alignItems:"center",gap:6}}><Trash2 size={15}/> Delete Announcement</div>
              <button className="an-modal-close" onClick={()=>setDeleteId(null)}><X size={16}/></button>
            </div>
            <div className="an-modal-body" style={{textAlign:"center",padding:"24px 20px"}}>
              <div style={{display:"flex",justifyContent:"center",marginBottom:12}}><AlertTriangle size={36} color="#f57c00"/></div>
              <div style={{fontSize:15,fontWeight:600,color:"#333",marginBottom:8}}>Are you sure you want to delete this announcement?</div>
              <div style={{fontSize:13,color:"#999"}}>This action cannot be undone.</div>
            </div>
            <div className="an-modal-footer">
              <button className="an-btn-cancel" onClick={()=>setDeleteId(null)}>Cancel</button>
              <button onClick={confirmDelete} style={{background:"#c62828",color:"#fff",border:"none",padding:"8px 20px",borderRadius:8,fontWeight:600,cursor:"pointer"}}>Yes, Delete</button>
            </div>
          </div>
        </div>
      )}

      {/* Header */}
      <div className="an-page-header">
        <div>
          <div className="an-page-title">ANNOUNCEMENT</div>
          <div className="an-page-sub">Post activities, seminars, and notices to members. Posts are sent as notifications and appear in the member newsfeed.</div>
        </div>
        <button className="an-create-btn" onClick={()=>setCreate(true)}>+Create Post</button>
      </div>

      {/* Stats */}
      <div className="an-stats-row">
        <div className="an-stat-chip"><span className="an-stat-num">{stats.total}</span> Total Post</div>
        <div className="an-stat-chip"><span className="an-stat-num">{stats.pinned}</span> Pined</div>
        <div className="an-stat-chip"><span className="an-stat-num">{stats.comments}</span> Comments</div>
        <div className="an-stat-chip notified"><span className="an-stat-num">{stats.notified}</span> Notified</div>
      </div>

      {/* Search + Filter */}
      <div className="an-filter-bar">
        <div className="an-search-wrap">
          <Search size={13} color="#aaa"/>
          <input className="an-search-input" placeholder="Search Post....." value={search} onChange={e=>setSearch(e.target.value)}/>
          {search && <button className="an-clear-btn" onClick={()=>setSearch("")}><X size={13}/></button>}
        </div>
        <div className="an-filter-tabs">
          {["All",...POST_TYPES].map(t=>(
            <button key={t} className={`an-filter-tab ${filter===t?"active":""}`} onClick={()=>setFilter(t)}>{t}</button>
          ))}
        </div>
      </div>

      {/* Posts */}
      {loading ? (
        <div className="an-empty">Loading announcements...</div>
      ) : sortedPosts.length===0 ? (
        <div className="an-empty">No announcements found.</div>
      ) : (
        <div className="an-posts-list">
          {sortedPosts.map(post => {
            const bodyText = post.body || post.caption || "";
            return (
              <div key={post.id} className={`an-post-card ${post.pinned?"pinned":""}`} onClick={()=>setViewPost(post)}>
                {post.pinned && <div className="an-pinned-bar" style={{display:"flex",alignItems:"center",gap:6}}><Pin size={12}/> Pinned</div>}
                <div className="an-post-inner">
                  <div className="an-post-avatar">{(post.posted_by_name||"A")[0].toUpperCase()}</div>
                  <div className="an-post-content">

                    {/* Top row — author, role, date, type badge, actions */}
                    <div className="an-post-top">
                      <div className="an-post-meta">
                        <span className="an-post-author">{post.posted_by_name||"Admin"}</span>
                        <span className={`an-post-role-badge ${post.posted_by_role==="admin"?"role-admin":"role-staff"}`}>{post.posted_by_role||"admin"}</span>
                        <span className="an-post-date">{post.created_at}</span>
                      </div>
                      <div className="an-post-right" onClick={e=>e.stopPropagation()}>
                        <span className={`an-type-badge ${TYPE_COLOR[post.type]}`}>{post.type}</span>
                        {post.notified && <span className="an-notified-badge" style={{display:"inline-flex",alignItems:"center",gap:4}}><Bell size={11}/> Notified</span>}
                        {(user?.role==="admin"||user?.role==="staff") && (<>
                          <button className="an-icon-btn edit"   title="Edit"   onClick={e=>{e.stopPropagation();setEditPost(post);}}><Pencil size={12}/></button>
                          <button className="an-icon-btn delete" title="Delete" onClick={e=>{e.stopPropagation();handleDelete(post.id);}}><Trash2 size={12}/></button>
                        </>)}
                      </div>
                    </div>

                    {/* Title */}
                    <div className="an-post-title">{post.title}</div>

                    {/* Caption */}
                    <div className="an-post-caption">
                      {bodyText.length > 180
                        ? <>{bodyText.slice(0,180)}<span className="an-see-more"> ... See more</span></>
                        : bodyText
                      }
                    </div>

                    {/* Image — "fit" na parang Facebook */}
                    {post.image_url && (
                      <div className="an-post-image-wrap">
                        <img src={post.image_url} alt="post" className="an-post-image" loading="lazy"/>
                      </div>
                    )}

                    {/* Footer — Reaction + Comment count */}
                    <div className="an-post-footer">
                      <ReactionButton
                        myReaction={post.my_reaction}
                        totalReactions={post.total_reactions || 0}
                        reactions={post.reactions}
                        onReact={(type) => handleReact(post.id, type)}
                        stopPropagation
                      />
                      <span className="an-comment-count"><MessageCircle size={13}/> {post.comment_count||0} Comments</span>
                    </div>

                  </div>
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}