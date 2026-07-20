import { useState, useEffect } from "react";
import { useOutletContext } from "react-router-dom";
import { ArrowDownCircle, ArrowUpCircle, Receipt, PiggyBank } from "lucide-react";
import { getMemberSavingsAPI } from "../../api/members";
import "./MySavings.css";

const FILTERS = ["All", "Deposit", "Withdrawal"];

export default function MySavings() {
  const ctx    = useOutletContext() || {};
  const member = ctx.member || {};

  const [loading,      setLoading]     = useState(true);
  const [error,        setError]       = useState(false);
  const [balance,      setBalance]     = useState(0);
  const [transactions, setTransactions]= useState([]);
  const [filter,       setFilter]      = useState("All");

  useEffect(() => {
    const load = async () => {
      setLoading(true);
      setError(false);
      // NOTE: walang dedikadong "my savings" endpoint (hindi tulad ng
      // getMyProfileAPI/getMyOnlineAppAPI) — kailangan ng totoong
      // member ID mula sa profile, hindi yung literal na "me"
      // (na-confirm 404 ito sa /members/me/savings-summary/).
      if (!member.id) { setLoading(false); setError(true); return; }
      try {
        const data = await getMemberSavingsAPI(member.id);
        setBalance(parseFloat(data.balance || data.savings_balance || 0));
        setTransactions(data.transactions || []);
      } catch {
        setError(true);
      } finally {
        setLoading(false);
      }
    };
    load();
  }, [member.id]);

  const totalDeposits    = transactions.filter(t => t.transaction_type === "Deposit").reduce((s, t) => s + parseFloat(t.amount || 0), 0);
  const totalWithdrawals = transactions.filter(t => t.transaction_type === "Withdrawal").reduce((s, t) => s + parseFloat(t.amount || 0), 0);
  const filtered = filter === "All" ? transactions : transactions.filter(t => t.transaction_type === filter);

  return (
    <div className="sv-wrapper">
      <div className="sv-page-title">My Savings</div>
      <div className="sv-page-sub">Track your savings deposits and withdrawals.</div>

      {error ? (
        <div className="sv-error-box">
          Hindi makuha ang savings data. Maaaring hindi pinapayagan ang member accounts na tumingin dito, o wala pang savings record. Subukan ulit mamaya, o tanungin ang admin.
        </div>
      ) : loading ? (
        <div className="sv-loading">Loading savings...</div>
      ) : (
        <>
          <div className="sv-balance-card">
            <div className="sv-balance-label"><PiggyBank size={16}/> CURRENT SAVINGS BALANCE</div>
            <div className="sv-balance-val">₱{balance.toLocaleString()}</div>
          </div>

          <div className="sv-stats-row">
            <div className="sv-stat-box">
              <ArrowDownCircle size={16} color="#2e7d32"/>
              <div className="sv-stat-val green">₱{totalDeposits.toLocaleString()}</div>
              <div className="sv-stat-label">Total Deposits</div>
            </div>
            <div className="sv-stat-box">
              <ArrowUpCircle size={16} color="#c62828"/>
              <div className="sv-stat-val red">₱{totalWithdrawals.toLocaleString()}</div>
              <div className="sv-stat-label">Total Withdrawals</div>
            </div>
            <div className="sv-stat-box">
              <Receipt size={16} color="#1565c0"/>
              <div className="sv-stat-val blue">{transactions.length}</div>
              <div className="sv-stat-label">Transactions</div>
            </div>
          </div>

          <div className="sv-filter-tabs">
            {FILTERS.map(f => (
              <button key={f} className={`sv-filter-tab ${filter === f ? "active" : ""}`} onClick={() => setFilter(f)}>{f}</button>
            ))}
          </div>

          <div className="sv-list-card">
            {filtered.length === 0 ? (
              <div className="sv-empty">No savings transactions yet.</div>
            ) : filtered.map((tx, i) => {
              const isDeposit = tx.transaction_type === "Deposit";
              return (
                <div key={tx.id || i} className="sv-tx-item">
                  <div className={`sv-tx-icon ${isDeposit ? "deposit" : "withdrawal"}`}>
                    {isDeposit ? <ArrowDownCircle size={16}/> : <ArrowUpCircle size={16}/>}
                  </div>
                  <div className="sv-tx-body">
                    <div className="sv-tx-type">{tx.transaction_type}</div>
                    <div className="sv-tx-date">{(tx.created_at || "").slice(0,10)}</div>
                    {tx.note && <div className="sv-tx-note">{tx.note}</div>}
                  </div>
                  <div className="sv-tx-amounts">
                    <div className={`sv-tx-amount ${isDeposit ? "green" : "red"}`}>
                      {isDeposit ? "+" : "−"}₱{Number(tx.amount).toLocaleString()}
                    </div>
                    <div className="sv-tx-balafter">Bal: ₱{Number(tx.balance_after || 0).toLocaleString()}</div>
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