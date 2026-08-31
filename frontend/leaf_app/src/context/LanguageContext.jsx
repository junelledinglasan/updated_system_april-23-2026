// src/context/LanguageContext.jsx
// ── BAGO: language switcher para sa member portal — English/Filipino.
// Naka-save sa localStorage (hindi sensitive na data, katulad ng
// ibang UI preferences — walang security risk kung persistent). ─────

import { createContext, useContext, useState } from "react";
import { translations } from "../i18n/translations";

const LanguageContext = createContext(null);
const STORAGE_KEY = "leaf_language";

export function LanguageProvider({ children }) {
  const [language, setLanguageState] = useState(() => {
    try {
      const saved = localStorage.getItem(STORAGE_KEY);
      return saved === "fil" ? "fil" : "en";
    } catch {
      return "en";
    }
  });

  const setLanguage = (lang) => {
    setLanguageState(lang);
    try { localStorage.setItem(STORAGE_KEY, lang); } catch {}
  };

  const toggleLanguage = () => setLanguage(language === "en" ? "fil" : "en");

  // ── t(key, vars) — kunin ang translation, palitan ang {placeholders}
  // gamit ang vars object. Kung walang laman sa kasalukuyang wika,
  // babalik sa English; kung wala rin doon, ibabalik na lang ang key
  // mismo (para hindi kailanman blangko ang ipinapakita). ───────────
  const t = (key, vars = {}) => {
    const dict = translations[language] || translations.en;
    let str = dict[key] ?? translations.en[key] ?? key;
    Object.entries(vars).forEach(([k, v]) => {
      str = str.replaceAll(`{${k}}`, v);
    });
    return str;
  };

  return (
    <LanguageContext.Provider value={{ language, setLanguage, toggleLanguage, t }}>
      {children}
    </LanguageContext.Provider>
  );
}

export function useLanguage() {
  return useContext(LanguageContext);
}