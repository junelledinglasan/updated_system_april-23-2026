// src/utils/pageCache.js
// ── BAGO: cache-first na pattern para sa member portal pages — instant
// na ipinapakita ang huling nakitang datos habang tahimik na nagre-
// refresh sa likod, imbes na palaging nagpapakita ng "Loading..."
// tuwing may bagong pag-navigate. Ginagamit ng Dashboard, My Loans,
// My Savings, Announcements, My Profile, at Apply for Loan.
//
// MAHALAGA: naka-scope ang bawat cache key sa member ID (hindi lang
// sa pangalan ng page) — kaya kahit magpalit ng account sa parehong
// tab/session (hal. admin → member, o member A → member B), hindi
// makikita ng bagong account ang lumang cached data ng nauna. Kung
// walang alam na member ID pa (bago pa lang mag-load), i-treat na
// lang bilang "anon" — hindi ito magiging risk dahil isang beses lang
// gagamitin bago pa dumating ang totoong member ID.

const PREFIX = "leaf_pgcache_";

export function getPageCache(pageKey, memberId) {
  try {
    const raw = sessionStorage.getItem(`${PREFIX}${pageKey}_${memberId ?? "anon"}`);
    if (!raw) return null;
    const parsed = JSON.parse(raw);
    return parsed ?? null;
  } catch {
    return null;
  }
}

export function savePageCache(pageKey, memberId, data) {
  try {
    sessionStorage.setItem(`${PREFIX}${pageKey}_${memberId ?? "anon"}`, JSON.stringify(data));
  } catch { /* ignore — hindi kritikal, cache lang ito */ }
}

// ── Ginagamit sa logout — para talagang malinis lahat ng naka-cache
// na datos ng dating account, hindi lang yung "anon" placeholder. ────
export function clearAllPageCaches() {
  try {
    const keys = [];
    for (let i = 0; i < sessionStorage.length; i++) {
      const k = sessionStorage.key(i);
      if (k && k.startsWith(PREFIX)) keys.push(k);
    }
    keys.forEach(k => sessionStorage.removeItem(k));
  } catch { /* ignore */ }
}