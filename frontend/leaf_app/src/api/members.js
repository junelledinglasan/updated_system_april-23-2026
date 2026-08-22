import api from "./axiosInstance";

export const getMembersAPI              = async (params) => (await api.get("/members/", { params })).data;
export const getMemberStatsAPI          = async ()       => (await api.get("/members/stats/")).data;
export const getMemberAPI               = async (id)     => (await api.get(`/members/${id}/`)).data;
export const registerMemberAPI          = async (data)   => (await api.post("/members/", data)).data;
export const updateMemberAPI            = async (id, data) => (await api.put(`/members/${id}/`, data)).data;
// BAGO: kailangan na ngayon ng password ng currently-logged-in na
// admin — double security para hindi basta-basta makapag-delete.
// Axios DELETE requests ay kailangang gamitin ang `data` key sa loob
// ng config object para makapagpadala ng request body.
export const deleteMemberAPI            = async (id, password) => (await api.delete(`/members/${id}/`, { data: { password } })).data;
export const updateMemberStatusAPI      = async (id, data) => (await api.patch(`/members/${id}/status/`, data)).data;
export const getApplicationsAPI         = async (params) => (await api.get("/members/applications/", { params })).data;
export const getApplicationAPI          = async (id)     => (await api.get(`/members/applications/${id}/`)).data;
export const updateApplicationStatusAPI = async (id, data) => (await api.patch(`/members/applications/${id}/`, data)).data;
export const convertToMemberAPI         = async (id)     => (await api.post(`/members/applications/${id}/convert/`)).data;
export const getMyApplicationAPI        = async ()       => (await api.get("/members/my-application/")).data;
export const getMyProfileAPI            = async ()       => (await api.get("/members/my-profile/")).data;
export const submitApplicationAPI       = async (data)   => (await api.post("/members/online-applications/", data)).data;

// ── Online Applications (separate table) ──────────────────────────────────────
export const getOnlineApplicationsAPI   = async (params) => (await api.get("/members/online-applications/", { params })).data;
export const getOnlineApplicationAPI    = async (id)     => (await api.get(`/members/online-applications/${id}/`)).data;
export const updateOnlineAppStatusAPI   = async (id, data) => (await api.patch(`/members/online-applications/${id}/`, data)).data;
export const convertOnlineAppAPI        = async (id, data) => (await api.post(`/members/online-applications/${id}/convert/`, data)).data;
export const getMyOnlineAppAPI          = async ()       => (await api.get("/members/my-online-application/")).data;

// Savings
export const getSavingsAPI              = async (memberId) => (await api.get(`/members/savings/?member=${memberId}`)).data;
export const recordSavingsAPI           = async (data)     => (await api.post('/members/savings/', data)).data;
export const getMemberSavingsAPI        = async (memberId) => (await api.get(`/members/${memberId}/savings-summary/`)).data;

// ── Share Capital (member-facing history) ──────────────────────────────────
export const getMemberShareCapitalAPI   = async (memberId) => (await api.get(`/members/${memberId}/share-capital-deposit/`)).data;