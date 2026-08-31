// src/api/settings.js
import api from "./axiosInstance";

export const getSystemLogoAPI = () =>
  api.get("/settings/logo/").then(r => r.data);

export const uploadSystemLogoAPI = (file) => {
  const formData = new FormData();
  formData.append("logo", file);
  return api.post("/settings/logo/upload/", formData, {
    headers: { "Content-Type": "multipart/form-data" },
  }).then(r => r.data);
};

export const resetSystemLogoAPI = () =>
  api.delete("/settings/logo/reset/").then(r => r.data);

// ── BAGO: GCash payment number/account name — dating hardcoded sa
// GCashPayment.jsx, ngayon nasa database na. ────────────────────────
export const getGCashSettingsAPI = () =>
  api.get("/settings/gcash/").then(r => r.data);

export const updateGCashSettingsAPI = (data) =>
  api.patch("/settings/gcash/", data).then(r => r.data);

// ── Staff Feature Permissions ──────────────────────────────────────
export const getAvailableFeaturesAPI = () =>
  api.get("/settings/features/").then(r => r.data);

export const getStaffPermissionsListAPI = () =>
  api.get("/settings/staff-permissions/").then(r => r.data);

export const getStaffPermissionsAPI = (staffId) =>
  api.get(`/settings/staff-permissions/${staffId}/`).then(r => r.data);

export const updateStaffPermissionsAPI = (staffId, features) =>
  api.post(`/settings/staff-permissions/${staffId}/`, { features }).then(r => r.data);