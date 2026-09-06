import { useState, useEffect, useRef } from "react";
import { getAnnouncementsAPI, getAnnouncementAPI, addCommentAPI, reactToAnnouncementAPI } from "../../api/announcements";
import { useAuth } from "../../context/AuthContext";
import { useLanguage } from "../../context/LanguageContext";
import { getPageCache, savePageCache } from "../../utils/pageCache";
import { ThumbsUp, Heart, Laugh, Sparkles, Frown, Angry as AngryIcon, X, Megaphone, MessageCircle } from "lucide-react";
import "./MemberAnnouncements.css";

const TYPE_COLOR = {
  Activity:"tag-activity", Seminar:"tag-seminar", Notice:"tag-notice",
  Announcement:"tag-announce", Event:"tag-event",
};

// ── Reactions (parang Facebook) — English ang value (para tumugma sa
// backend/reactToAnnouncementAPI), naka-translate lang ang DISPLAY
// label via t("ma_reaction_..."). ────────────────────────────────────
const REACTION_TYPES = ["Like","Love","Haha","Wow","Sad","Angry"];
// ── BAGO: dating naka-emoji ito (👍❤️😂😮😢😠) — ngayon totoong
// lucide-react icons, tugma sa "walang emoji" na patakaran. Walang
// eksaktong lucide icon para sa "surprised/wow" face, kaya "Sparkles"
// ang ginamit kong pinakamalapit na alternatibo. ────────────────────
const REACTION_ICON  = { Like: ThumbsUp, Love: Heart, Haha: Laugh, Wow: Sparkles, Sad: Frown, Angry: AngryIcon };
const REACTION_COLOR = { Like:"#1565c0", Love:"#c62828", Haha:"#f57f17", Wow:"#f57f17", Sad:"#f57f17", Angry:"#e65100" };
const REACTION_KEY   = { Like:"ma_reaction_like", Love:"ma_reaction_love", Haha:"ma_reaction_haha", Wow:"ma_reaction_wow", Sad:"ma_reaction_sad", Angry:"ma_reaction_angry" };

// ── BAGO: tumatanggap na ng t() para ma-translate ang "just now" /
// "{n}m ago" / atbp. ─────────────────────────────────────────────────
function timeAgo(dateStr, t) {
  if (!dateStr) return "";
  const diff = Math.floor((Date.now() - new Date(dateStr)) / 1000);
  if (diff < 60)    return t("ma_just_now");
  if (diff < 3600)  return t("ma_mins_ago", { n: Math.floor(diff/60) });
  if (diff < 86400) return t("ma_hours_ago", { n: Math.floor(diff/3600) });
  if (diff < 604800)return t("ma_days_ago", { n: Math.floor(diff/86400) });
  return new Date(dateStr).toLocaleDateString("en-PH", { month:"short", day:"numeric", year:"numeric" });
}

function ReactionButton({ myReaction, totalReactions, reactions, onReact, stopPropagation }) {
  const { t } = useLanguage();
  const [showPicker, setShowPicker] = useState(false);
  const [showWho,    setShowWho]    = useState(false);
  const hideTimer = useRef(null);

  const openPicker = () => { clearTimeout(hideTimer.current); setShowPicker(true); };
  const scheduleHide = () => { hideTimer.current = setTimeout(() => setShowPicker(false), 300); };

  const ReactionIcon = myReaction ? REACTION_ICON[myReaction] : ThumbsUp;
  const color = myReaction ? (REACTION_COLOR[myReaction] || "#2e7d32") : "#888";
  const label = myReaction ? t(REACTION_KEY[myReaction]) : t("ma_reaction_like");

  return (
    <div className="ma-reaction-wrap" onClick={e => stopPropagation && e.stopPropagation()}>
      <div className="ma-reaction-btn-wrap" onMouseEnter={openPicker} onMouseLeave={scheduleHide}>
        {showPicker && (
          <div className="ma-reaction-picker" onMouseEnter={openPicker} onMouseLeave={scheduleHide}>
            {REACTION_TYPES.map(type => {
              const Icon = REACTION_ICON[type];
              return (
                <span key={type} className="ma-reaction-emoji" title={t(REACTION_KEY[type])}
                  onClick={(ev) => { ev.stopPropagation(); onReact(type); setShowPicker(false); }}>
                  <Icon size={16} color={REACTION_COLOR[type]}/>
                </span>
              );
            })}
          </div>
        )}
        <button className="ma-reaction-btn" style={{ color }} onClick={(e) => { e.stopPropagation(); onReact(myReaction || "Like"); }}>
          <span style={{display:"inline-flex",alignItems:"center"}}><ReactionIcon size={14}/></span>
          <span style={{ fontWeight: myReaction ? 800 : 600 }}>{label}</span>
        </button>
      </div>

      {/* ── "Reacted by" — i-hover ang count para makita ang mga pangalan ── */}
      {totalReactions > 0 && (
        <div className="ma-reacted-by-wrap" onMouseEnter={() => setShowWho(true)} onMouseLeave={() => setShowWho(false)}>
          <span className="ma-reacted-by-count">{t("ma_reacted", { n: totalReactions })}</span>
          {showWho && (
            <div className="ma-reacted-by-list">
              {(reactions || []).map(r => {
                const RIcon = REACTION_ICON[r.reaction_type] || ThumbsUp;
                return (
                  <div key={r.id} className="ma-reacted-by-item">
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

// ── Comments list + input — reusable, ginagamit sa loob ng modal ─────────
function CommentsSection({ post, user, onCommentAdded }) {
  const { t } = useLanguage();
  const [commText, setCommText] = useState("");
  const [sending,  setSending]  = useState(false);

  const submit = async () => {
    if (!commText.trim() || sending) return;
    setSending(true);
    try {
      const newComment = await addCommentAPI(post.id, commText.trim());
      setCommText("");
      // ── FIX: dating "onCommentAdded()" na walang parameter — nag-
      // trigger ito ng "refreshPosts()" (BUONG LISTAHAN refetch) sa
      // parent tuwing may bagong comment. Ngayon, ipinapasa na ang
      // bagong comment mismo pataas, para ma-update ng parent nang
      // lokal na lang (walang dagdag na network request). ──────────
      onCommentAdded(newComment);
    } catch(e) { console.error(e); }
    finally { setSending(false); }
  };

  return (
    <div className="ma-comments-section">
      {!post.comments?.length ? (
        <div className="ma-no-comments">{t("ma_no_comments")}</div>
      ) : post.comments.map(c => (
        <div key={c.id} className="ma-comment">
          <div className="ma-comment-avatar">{(c.posted_by_name || c.author || "U")[0].toUpperCase()}</div>
          <div className="ma-comment-body">
            <div className="ma-comment-author">
              {c.posted_by_name || c.author}
              {c.posted_by_role && <span className="ma-comment-time" style={{marginLeft:6,color:"#aaa",fontSize:10}}>{c.posted_by_role}</span>}
              <span className="ma-comment-time">{timeAgo(c.created_at, t)}</span>
            </div>
            <div className="ma-comment-text">{c.body || c.text}</div>
          </div>
        </div>
      ))}
      <div className="ma-comment-input-row">
        <div className="ma-comment-avatar me">{user?.name?.[0]?.toUpperCase()||"M"}</div>
        <input
          className="ma-comment-input"
          placeholder={t("ma_write_comment")}
          value={commText}
          onChange={e => setCommText(e.target.value)}
          onKeyDown={e => e.key==="Enter" && submit()}
        />
        <button className="ma-comment-send" onClick={submit} disabled={!commText.trim() || sending}>
          {sending ? "..." : t("ma_send")}
        </button>
      </div>
    </div>
  );
}

// ── Full detail "pop-up" — buong post + reactions + comments ─────────────
function PostDetailModal({ post, user, onClose, onReact, onCommentAdded }) {
  const { t } = useLanguage();
  if (!post) return null;
  const bodyText   = post.body || post.caption || post.content || "";
  const authorName = post.posted_by_name || "Admin";
  const authorRole = post.posted_by_role || "admin";

  return (
    <div className="ma-modal-overlay" onClick={onClose}>
      <div className="ma-modal-box" onClick={e => e.stopPropagation()}>
        <button className="ma-modal-close" onClick={onClose}><X size={16}/></button>
        <div className="ma-modal-scroll">
          <div className="ma-post-header">
            <div className="ma-post-meta">
              <div className="ma-post-avatar">{authorName[0].toUpperCase()}</div>
              <div>
                <div className="ma-post-author">{authorName}<span className="ma-admin-tag">{authorRole}</span></div>
                <div className="ma-post-time">{timeAgo(post.created_at, t)}</div>
              </div>
            </div>
            {post.type && <span className={`ma-type-tag ${TYPE_COLOR[post.type]||""}`}>{post.type}</span>}
          </div>

          <div className="ma-post-title">{post.title}</div>
          {bodyText && <div className="ma-post-caption-full" style={{whiteSpace:"pre-wrap"}}>{bodyText}</div>}
          {post.image_url && (
            <div className="ma-post-image-full">
              <img src={post.image_url} alt="announcement"/>
            </div>
          )}

          <div className="ma-post-footer">
            <ReactionButton myReaction={post.my_reaction} totalReactions={post.total_reactions || 0} reactions={post.reactions} onReact={(type) => onReact(post.id, type)} />
          </div>

          <div className="ma-modal-comments-title">{t("ma_comments_title")} ({post.comments?.length || 0})</div>
          <CommentsSection post={post} user={user} onCommentAdded={onCommentAdded} />
        </div>
      </div>
    </div>
  );
}

export default function MemberAnnouncements() {
  const { user } = useAuth();
  const { t }     = useLanguage();
  // ── BAGO: cache-first — pareho ang announcements para sa LAHAT ng
  // members (hindi per-member data), kaya "shared" na lang ang key,
  // hindi kailangang i-scope per member ID. Instant na ipinapakita ang
  // huling nakitang listahan habang tahimik na nagre-refresh sa likod. ──
  const cachedPosts  = getPageCache("announcements", "shared");
  const [posts,      setPosts]     = useState(cachedPosts || []);
  const [filter,     setFilter]    = useState("All");
  const [loading,    setLoading]   = useState(!cachedPosts);
  const [detailPost, setDetailPost]= useState(null); // ← post na naka-open sa popup

  useEffect(() => {
    getAnnouncementsAPI()
      .then(data => {
        setPosts(data);
        savePageCache("announcements", "shared", data);
      })
      .catch(e => console.error(e))
      .finally(() => setLoading(false));
  }, []);

  const types     = ["All", ...new Set(posts.map(p => p.type).filter(Boolean))];
  const displayed = posts.filter(p => filter === "All" || p.type === filter);

  // ── BAGO: tinanggal ang "refreshPosts" (buong list refetch) — hindi
  // na kailangan, lokal na state updates na lang ang ginagamit sa
  // reactions at comments (tingnan sa ibaba). ──────────────────────────

  // ── FIX: dating nagre-refetch ng BUONG LISTAHAN ng announcements
  // (getAnnouncementsAPI() via refreshPosts()) tuwing may nag-react sa
  // isang post — malaking overfetch. Ngayon, gagamitin muna ang
  // "result" mismo na ibinabalik ng reaction endpoint (kung buong
  // updated post ang laman nito). Kung hindi kumpleto (walang
  // "reactions" field), i-fallback na lang sa "getAnnouncementAPI
  // (postId)" — kinukuha lang ang ISANG post na 'to, hindi na ang
  // BUONG listahan. ────────────────────────────────────────────────────
  const handleReact = async (postId, reactionType) => {
    try {
      const result = await reactToAnnouncementAPI(postId, reactionType);
      const updatedPost = (result && result.reactions !== undefined) ? result : await getAnnouncementAPI(postId);
      setPosts(prev => prev.map(p => p.id === postId ? { ...p, ...updatedPost } : p));
      setDetailPost(prev => prev && prev.id === postId ? { ...prev, ...updatedPost } : prev);
    } catch(e) { console.error(e); }
  };

  // ── BAGO: mabilis na lokal na pag-update ng "comments" array ng
  // partikular na post — walang dagdag na network request, imbes na
  // buong refetch tuwing may bagong comment. ──────────────────────────
  const handleCommentAdded = (postId, newComment) => {
    const appendComment = (p) => p.id === postId ? { ...p, comments: [...(p.comments||[]), newComment] } : p;
    setPosts(prev => prev.map(appendComment));
    setDetailPost(prev => prev && prev.id === postId ? appendComment(prev) : prev);
  };

  return (
    <div className="ma-wrapper">
      {detailPost && (
        <PostDetailModal
          post={detailPost}
          user={user}
          onClose={() => setDetailPost(null)}
          onReact={handleReact}
          onCommentAdded={(newComment) => handleCommentAdded(detailPost.id, newComment)}
        />
      )}

      <div className="ma-page-header">
        <div className="ma-page-title">{t("ma_page_title")}</div>
        <div className="ma-page-sub">{t("ma_page_sub")}</div>
      </div>

      <div className="ma-filter-tabs">
        {types.map(ty => (
          <button key={ty} className={`ma-filter-tab ${filter===ty?"active":""}`} onClick={() => setFilter(ty)}>{ty === "All" ? t("ma_filter_all") : ty}</button>
        ))}
      </div>

      {loading ? (
        <div style={{textAlign:"center",padding:"48px",color:"#bbb",fontSize:13}}>{t("ma_loading")}</div>
      ) : (
        <div className="ma-feed">
          {displayed.length === 0 ? (
            <div className="ma-empty-state">
              <div className="ma-empty-icon" style={{display:"flex",justifyContent:"center"}}><Megaphone size={40} color="#ccc"/></div>
              <div className="ma-empty-text">{t("ma_no_announcements")}</div>
            </div>
          ) : displayed.map(post => {
            const bodyText     = post.body || post.caption || post.content || "";
            const preview      = bodyText.length > 200 ? bodyText.slice(0,200) + "..." : bodyText;
            const authorName   = post.posted_by_name || "Admin";
            const authorRole   = post.posted_by_role || "admin";
            const commentCount = post.comments?.length || post.comment_count || 0;

            return (
              <div key={post.id} className="ma-post-card ma-post-card-clickable" onClick={() => setDetailPost(post)}>
                <div className="ma-post-header">
                  <div className="ma-post-meta">
                    <div className="ma-post-avatar">{authorName[0].toUpperCase()}</div>
                    <div>
                      <div className="ma-post-author">{authorName}<span className="ma-admin-tag">{authorRole}</span></div>
                      <div className="ma-post-time">{timeAgo(post.created_at, t)}</div>
                    </div>
                  </div>
                  {post.type && <span className={`ma-type-tag ${TYPE_COLOR[post.type]||""}`}>{post.type}</span>}
                </div>

                <div className="ma-post-title">{post.title}</div>
                {preview && <div className="ma-post-caption" style={{whiteSpace:"pre-wrap"}}>{preview}</div>}

                {/* Image — "fit" na parang Facebook, buong picture makikita */}
                {post.image_url && (
                  <div className="ma-post-image">
                    <img src={post.image_url} alt="announcement" loading="lazy"/>
                  </div>
                )}

                <div className="ma-post-footer">
                  <ReactionButton myReaction={post.my_reaction} totalReactions={post.total_reactions || 0} reactions={post.reactions} onReact={(type) => handleReact(post.id, type)} stopPropagation/>
                  <button className="ma-comment-toggle" onClick={(e) => { e.stopPropagation(); setDetailPost(post); }} style={{display:"inline-flex",alignItems:"center",gap:5}}>
                    <MessageCircle size={13}/> {commentCount} {commentCount!==1 ? t("ma_comment_plural") : t("ma_comment_singular")}
                  </button>
                  <span className="ma-tap-hint">{t("ma_click_view")}</span>
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}