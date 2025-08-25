import React, { useState, useEffect } from "react";
import Script from "next/script";
import { Theme } from "../lib/types";
import { Icon } from "./icon";

export default function SetTheme() {
  const [theme, setTheme] = useState<Theme | undefined>();

  const toggleTheme = () => {
    if (theme === "light") {
      setTheme("dark");
    } else {
      setTheme("light");
    }
  };

  const maybeTheme = (): Theme => {
    const themeLocalStorage = localStorage.getItem("theme") as Theme | null;
    const themeSystem: Theme = window.matchMedia("(prefers-color-scheme: dark)")
      .matches
      ? "dark"
      : "light";

    return themeLocalStorage ?? themeSystem;
  };

  useEffect(() => {
    const currentTheme = theme ?? maybeTheme();
    const rootElement = document.querySelector(":root") as HTMLElement;
    if (rootElement) {
      rootElement.dataset.theme = currentTheme;
    }
    localStorage.setItem("theme", currentTheme);
    setTheme(currentTheme);

    const useSetTheme = (e: MediaQueryListEvent) => {
      setTheme(e.matches ? "dark" : "light");
    };
    const watchSysTheme = window.matchMedia("(prefers-color-scheme: dark)");

    watchSysTheme.addEventListener("change", useSetTheme);
    return () => {
      watchSysTheme.removeEventListener("change", useSetTheme);
    };
  }, [theme]);

  if (!theme) return null;

  return (
    <>
      <Script id="theme.util.jsx" strategy="beforeInteractive">
        {`
                var themeLocalStorage   = localStorage.getItem('theme')
                var themeSystem         = window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light'

                document.querySelector(':root').dataset.theme = themeLocalStorage ?? themeSystem
                `}
      </Script>
      <button
        key="themeToggle"
        onClick={toggleTheme}
        data-theme={theme}
        className="flex justify-center items-center w-10 h-10 rounded-2xl bg-secondary sm:bg-transparent"
      >
        {theme === "light" ? (
          <Icon name="moon" size={40} />
        ) : (
          <Icon name="sun" size={40} />
        )}
      </button>
    </>
  );
}
