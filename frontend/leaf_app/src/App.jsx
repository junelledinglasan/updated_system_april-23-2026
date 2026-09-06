import { BrowserRouter, Routes, Route, Navigate } from "react-router-dom";
import { AuthProvider }    from "./context/AuthContext";
import ProtectedRoute      from "./components/ProtectedRoute";

// Layouts
import AdminLayout         from "./layouts/AdminLayout";
import StaffLayout         from "./layouts/StaffLayout";
import MemberLayout        from "./layouts/MemberLayout";

// Auth pages
import Login               from "./pages/Login";
import MemberRegister      from "./components/member/MemberRegister";

// Admin components
import Dashboard           from "./components/admin/Dashboard";
import ManageMember        from "./components/admin/ManageMember";
import ManageStaff         from "./components/admin/ManageStaff";
import OnlineApplications  from "./components/admin/OnlineApplications";
import LoanApproval        from "./components/admin/LoanApproval";
import LoanPayment         from "./components/admin/LoanPayment";
import Announcement        from "./components/admin/Announcement";
import Reports             from "./components/admin/Reports";
import GCashVerification   from "./components/admin/GCashVerification";
// ── BAGO: dating overlay modals lang ito (state-toggled sa loob ng
// AdminLayout.jsx) — ngayon sarili nang FILES/ROUTES, dahil nasa
// sidebar na sila bilang tunay na nav items. ─────────────────────────
import SavingsDeposit      from "./components/admin/SavingsDeposit";
import ShareCapitalDeposit from "./components/admin/ShareCapitalDeposit";

// Staff components
import StaffHome           from "./components/staff/StaffHome";

// Member components
import MemberDashboard     from "./components/member/MemberDashboard";
import MyLoans             from "./components/member/MyLoans";
import MySavings           from "./components/member/MySavings";
import Notifications       from "./components/member/Notifications";
import MemberAnnouncements from "./components/member/MemberAnnouncements";
import LoanApplication     from "./components/member/LoanApplication";
import MemberProfile       from "./components/member/MemberProfile";
import ApplyMembership     from "./components/member/ApplyMembership";

export default function App() {
  return (
    <AuthProvider>
      <BrowserRouter>
        <Routes>

          {/* Default → single login */}
          <Route path="/"         element={<Navigate to="/login" replace />} />
          <Route path="/login"    element={<Login />}          />
          <Route path="/register" element={<MemberRegister />} />

          {/* ── Admin Routes ── */}
          <Route
            path="/admin"
            element={
              <ProtectedRoute allowedRoles={["admin"]} loginPath="/login">
                <AdminLayout />
              </ProtectedRoute>
            }
          >
            <Route index element={<Navigate to="dashboard" replace />} />
            <Route path="dashboard"          element={<Dashboard />}          />
            <Route path="members"            element={<ManageMember />}       />
            <Route path="staff"              element={<ManageStaff />}        />
            <Route path="applications"       element={<OnlineApplications />} />
            <Route path="loan-approval"      element={<LoanApproval />}       />
            <Route path="loan-payment"       element={<LoanPayment />}        />
            <Route path="gcash-verification" element={<GCashVerification />}  />
            <Route path="announcement"       element={<Announcement />}       />
            <Route path="reports"            element={<Reports />}            />
            {/* ── BAGO: dating modals, ngayon sariling routes na. ──── */}
            <Route path="savings-deposit"       element={<SavingsDeposit />}       />
            <Route path="share-capital-deposit" element={<ShareCapitalDeposit />}  />
          </Route>

          {/* ── Staff Routes ── */}
          <Route
            path="/staff"
            element={
              <ProtectedRoute allowedRoles={["staff"]} loginPath="/login">
                <StaffLayout />
              </ProtectedRoute>
            }
          >
            <Route index                element={<StaffHome />}          />
            <Route path="members"       element={<ManageMember />}       />
            <Route path="applications"  element={<OnlineApplications />} />
            <Route path="loan-approval" element={<LoanApproval />}       />
            <Route path="loan-payment"  element={<LoanPayment />}        />
            <Route path="announcement"  element={<Announcement />}       />
            <Route path="reports"       element={<Reports />}            />
          </Route>

          {/* ── Member Routes ── */}
          <Route
            path="/member"
            element={
              <ProtectedRoute allowedRoles={["member", "user"]} loginPath="/login">
                <MemberLayout />
              </ProtectedRoute>
            }
          >
            <Route index element={<Navigate to="dashboard" replace />} />
            <Route path="dashboard"        element={<MemberDashboard />}     />
            <Route path="my-loans"         element={<MyLoans />}             />
            <Route path="savings"          element={<MySavings />}           />
            <Route path="notifications"    element={<Notifications />}       />
            <Route path="announcements"    element={<MemberAnnouncements />} />
            <Route path="apply"            element={<LoanApplication />}     />
            <Route path="profile"          element={<MemberProfile />}       />
            <Route path="apply-membership" element={<ApplyMembership />}     />
          </Route>

          {/* Catch all */}
          <Route path="*" element={<Navigate to="/login" replace />} />

        </Routes>
      </BrowserRouter>
    </AuthProvider>
  );
}