import { BrowserRouter, Routes, Route, Navigate } from "react-router-dom";
import { useEffect } from "react";
import LandingPage from "./pages/LandingPage";

function LandingWrapper() {
  useEffect(() => {
    const root = document.getElementById("root");
    if (root) {
      root.style.width = "100%";
      root.style.maxWidth = "100%";
      root.style.margin = "0";
      root.style.border = "none";
      root.style.textAlign = "left";
    }
    return () => {
      // Restore when leaving landing page
      const root = document.getElementById("root");
      if (root) {
        root.style.width = "";
        root.style.maxWidth = "";
        root.style.margin = "";
        root.style.border = "";
        root.style.textAlign = "";
      }
    };
  }, []);
  return <LandingPage />;
}

export default function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/" element={<LandingWrapper />} />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </BrowserRouter>
  );
}