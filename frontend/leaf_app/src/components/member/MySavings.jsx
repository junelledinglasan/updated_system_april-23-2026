import { useState, useEffect } from "react";
import { useOutletContext } from "react-router-dom";
import { ArrowDownCircle, ArrowUpCircle, Receipt, PiggyBank } from "lucide-react";
import { getMemberSavingsAPI } from "../../api/members";
import { useLanguage } from "../../context/LanguageContext";
import { useAuth } from "../../context/AuthContext";
import { getPageCache, savePageCache } from "../../utils/pageCache";
import "./MySavings.css";

export default function MySavings() {
  const { t } = useLanguage();
  const { user } = useAuth();
  const ctx    = useOutletContext() || {};
  const member = ctx.member || {};
  // ── FIX: dating member.id ang cache key — pero `null` muna 'to sa
  // unang saglit pag-refresh (hinihintay pa ang async profile fetch
  // ng MemberLayout), kaya mali munang key ang tinatamaan, nagpapakita
  // ng blangko/error muna bago lumabas ang tamang datos. Gamit na
  // lang ngayon ang user.id (mula sa AuthContext, available na agad)
  // bilang CACHE key lang — si member.id pa rin ang ginagamit para sa
  // aktwal na API call (kailangan talaga ito ng backend endpoint). ──
  const scopeKey = user?.id ?? user?.username ?? null;

  // ── BAGO: FILTERS ay nasa loob na ng component para magamit ang
  // t() — ang halaga (value) ay nananatiling English (tumutugma sa
  // tx.transaction_type mula sa backend), ang label lang ang naka-
  // translate. ──────────────────────────────────────────────────────
  const FILTERS = [
    { value: "All",        label: t("sv_filter_all") },
    { value: "Deposit",    label: t("sv_filter_deposit") },
    { value: "Withdrawal", label: t("sv_filter_withdrawal") },
  ];

  // ── BAGO: cache-first — instant na ipinapakita ang huling nakitang
  // balance/transactions habang tahimik na nagre-refresh sa likod. ──
  const cached = getPageCache("savings", scopeKey);
  const [loading,      setLoading]     = useState(!cached);
  const [error,        setError]       = useState(false);
  const [balance,      setBalance]     = useState(cached?.balance || 0);
  const [transactions, setTransactions]= useState(cached?.transactions || []);
  const [filter,       setFilter]      = useState("All");

  useEffect(() => {
    const load = async () => {
      // ── FIX: kung `member.id` ay wala pa (hinihintay pa lang ang
      // async profile fetch ng MemberLayout), huwag munang mag-error
      // — basta maghintay lang tahimik, hihintayin na lang ulit
      // tumakbo ang effect na 'to kapag na-populate na ang member.id
      // (nasa dependency array). Dating agad na "error" ang lumalabas
      // dito, kahit hindi pa naman talaga fail — nasa "not yet ready"
      // state lang. ─────────────────────────────────────────────────
      if (!member.id) return;
      // ── Huwag pilitin ang "Loading..." kung may cache na tayong
      // ipinapakita — tahimik na lang mag-refresh sa likod. ─────────
      if (!getPageCache("savings", scopeKey)) setLoading(true);
      setError(false);
      try {
        const data = await getMemberSavingsAPI(member.id);
        const newBalance = parseFloat(data.balance || data.savings_balance || 0);
        const newTx      = data.transactions || [];
        setBalance(newBalance);
        setTransactions(newTx);
        savePageCache("savings", scopeKey, { balance: newBalance, transactions: newTx });
      } catch {
        setError(true);
      } finally {
        setLoading(false);
      }
    };
    load();
  }, [member.id, scopeKey]);

  const totalDeposits    = transactions.filter(t => t.transaction_type === "Deposit").reduce((s, t) => s + parseFloat(t.amount || 0), 0);
  const totalWithdrawals = transactions.filter(t => t.transaction_type === "Withdrawal").reduce((s, t) => s + parseFloat(t.amount || 0), 0);
  const filtered = filter === "All" ? transactions : transactions.filter(tx => tx.transaction_type === filter);

  return (
    <div className="sv-wrapper">
      <div className="sv-page-title">{t("sv_page_title")}</div>
      <div className="sv-page-sub">{t("sv_page_sub")}</div>

      {error ? (
        <div className="sv-error-box">
          {t("sv_error")}
        </div>
      ) : loading ? (
        <div className="sv-loading">{t("sv_loading")}</div>
      ) : (
        <>
          <div className="sv-balance-card">
            <div className="sv-balance-label"><PiggyBank size={16}/> {t("sv_balance_label")}</div>
            <div className="sv-balance-val">₱{balance.toLocaleString()}</div>
          </div>

          <div className="sv-stats-row">
            <div className="sv-stat-box">
              <ArrowDownCircle size={16} color="#2e7d32"/>
              <div className="sv-stat-val green">₱{totalDeposits.toLocaleString()}</div>
              <div className="sv-stat-label">{t("sv_total_deposits")}</div>
            </div>
            <div className="sv-stat-box">
              <ArrowUpCircle size={16} color="#c62828"/>
              <div className="sv-stat-val red">₱{totalWithdrawals.toLocaleString()}</div>
              <div className="sv-stat-label">{t("sv_total_withdrawals")}</div>
            </div>
            <div className="sv-stat-box">
              <Receipt size={16} color="#1565c0"/>
              <div className="sv-stat-val blue">{transactions.length}</div>
              <div className="sv-stat-label">{t("sv_transactions")}</div>
            </div>
          </div>

          <div className="sv-filter-tabs">
            {FILTERS.map(f => (
              <button key={f.value} className={`sv-filter-tab ${filter === f.value ? "active" : ""}`} onClick={() => setFilter(f.value)}>{f.label}</button>
            ))}
          </div>

          <div className="sv-list-card">
            {filtered.length === 0 ? (
              <div className="sv-empty">{t("sv_no_transactions")}</div>
            ) : filtered.map((tx, i) => {
              const isDeposit = tx.transaction_type === "Deposit";
              const typeLabel = isDeposit ? t("sv_filter_deposit") : t("sv_filter_withdrawal");
              return (
                <div key={tx.id || i} className="sv-tx-item">
                  <div className={`sv-tx-icon ${isDeposit ? "deposit" : "withdrawal"}`}>
                    {isDeposit ? <ArrowDownCircle size={16}/> : <ArrowUpCircle size={16}/>}
                  </div>
                  <div className="sv-tx-body">
                    <div className="sv-tx-type">{typeLabel}</div>
                    <div className="sv-tx-date">{(tx.created_at || "").slice(0,10)}</div>
                    {tx.note && <div className="sv-tx-note">{tx.note}</div>}
                  </div>
                  <div className="sv-tx-amounts">
                    <div className={`sv-tx-amount ${isDeposit ? "green" : "red"}`}>
                      {isDeposit ? "+" : "−"}₱{Number(tx.amount).toLocaleString()}
                    </div>
                    <div className="sv-tx-balafter">{t("sv_balance_after")} ₱{Number(tx.balance_after || 0).toLocaleString()}</div>
                  </div>
                </div>
              );
            })}
          </div>
        </>
      )}
    </div>
  );
}