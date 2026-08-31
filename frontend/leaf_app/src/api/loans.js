import api from "./axiosInstance";

export const getLoansAPI         = async (params={})                     => (await api.get("/loans/", { params })).data;
export const getLoanAPI          = async (id)                            => (await api.get(`/loans/${id}/`)).data;
export const createLoanAPI       = async (data)                          => (await api.post("/loans/", data)).data;
export const updateLoanStatusAPI = async (id, status, declineReason="") => (await api.patch(`/loans/${id}/`, { status, decline_reason: declineReason })).data;

// ── BAGO: generic patch — para sa MEMBER-side edit/cancel ng sariling
// "For Review" na loan application. Hindi tulad ng updateLoanStatusAPI
// (na laging may `status` + `decline_reason`), dito ipinapasa ang buong
// data object as-is — puwedeng {status:"Cancelled"} para sa cancel, o
// {loan_type, amount, term_months, purpose, collateral} para sa edit.
export const updateLoanAPI = async (id, data) => (await api.patch(`/loans/${id}/`, data)).data;

// ─── Collection Calendar ──────────────────────────────────────────────────────
export const getDueDatesAPI = async (month="") => (await api.get(`/loans/due-dates/${month ? `?month=${month}` : ""}`)).data;

// ─── GCash Payment Requests ───────────────────────────────────────────────────
export const submitGCashRequestAPI = async (data)      => (await api.post('/loans/gcash-requests/', data)).data;
export const getGCashRequestsAPI   = async (params)    => (await api.get('/loans/gcash-requests/', { params })).data;
export const getGCashRequestAPI    = async (id)        => (await api.get(`/loans/gcash-requests/${id}/`)).data;
export const verifyGCashRequestAPI = async (id, data)  => (await api.post(`/loans/gcash-requests/${id}/verify/`, data)).data;