import api from "./axiosInstance";

export const getAnnouncementsAPI = async (params={}) =>
  (await api.get("/announcements/", { params })).data;

export const getAnnouncementAPI = async (id) =>
  (await api.get(`/announcements/${id}/`)).data;

// ─── Don't set Content-Type manually for FormData ─────────────────────────
// Axios auto-sets multipart/form-data with the correct boundary when data is FormData
export const createAnnouncementAPI = async (data) =>
  (await api.post("/announcements/", data)).data;

export const updateAnnouncementAPI = async (id, data) =>
  (await api.put(`/announcements/${id}/`, data)).data;

export const deleteAnnouncementAPI = async (id) =>
  (await api.delete(`/announcements/${id}/`)).data;

export const addCommentAPI = async (annId, body) =>
  (await api.post(`/announcements/${annId}/comments/`, { body })).data;

export const deleteCommentAPI = async (annId, cId) =>
  (await api.delete(`/announcements/${annId}/comments/${cId}/`)).data;

export const reactToAnnouncementAPI = (postId, reactionType) =>
  api.post(`/announcements/${postId}/react/`, { reaction_type: reactionType }).then(r => r.data);