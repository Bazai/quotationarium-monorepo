import React, { useState, useEffect } from "react";
import Script from "next/script";
import css from "./theme-toggle.module.css";
import { Theme } from "../lib/types";

export default function SetTheme() {
  const [theme, setTheme] = useState<Theme | undefined>();

  const toggleTheme = () => {
    if (theme === "light") {
      setTheme("dark");
    } else {
      setTheme("light");
    }
  };

  const buttonIcon = () => {
    switch (theme) {
      case "dark":
        return (
          <svg
            width="27"
            height="27"
            viewBox="0 0 27 27"
            fill="none"
            xmlns="http://www.w3.org/2000/svg"
          >
            <path
              fillRule="evenodd"
              clipRule="evenodd"
              d="M15 1.5C15 0.671573 14.3284 0 13.5 0C12.6716 0 12 0.671573 12 1.5V5.6404C10.9058 5.84796 9.89045 6.27837 9.00299 6.88264L6.07447 3.95413C5.48869 3.36834 4.53894 3.36834 3.95315 3.95413C3.36737 4.53991 3.36737 5.48966 3.95315 6.07545L6.88185 9.00415C6.278 9.89133 5.84787 10.9063 5.6404 12H1.5C0.671574 12 0 12.6716 0 13.5C0 14.3284 0.671574 15 1.5 15H5.6404C5.84787 16.0937 6.278 17.1087 6.88185 17.9958L3.95315 20.9246C3.36737 21.5103 3.36737 22.4601 3.95315 23.0459C4.53894 23.6317 5.48869 23.6317 6.07447 23.0459L9.00299 20.1174C9.89045 20.7216 10.9058 21.152 12 21.3596V25.5C12 26.3284 12.6716 27 13.5 27C14.3284 27 15 26.3284 15 25.5V21.3596C16.0937 21.1521 17.1087 20.722 17.9959 20.1181L20.9237 23.046C21.5095 23.6318 22.4592 23.6318 23.045 23.046C23.6308 22.4602 23.6308 21.5105 23.045 20.9247L20.1174 17.997C20.7216 17.1096 21.152 16.0942 21.3596 15H25.5C26.3284 15 27 14.3284 27 13.5C27 12.6716 26.3284 12 25.5 12H21.3596C21.152 10.9058 20.7216 9.89045 20.1174 9.00299L23.045 6.07531C23.6308 5.48952 23.6308 4.53977 23.045 3.95399C22.4592 3.3682 21.5095 3.3682 20.9237 3.95399L17.9958 6.88185C17.1087 6.278 16.0937 5.84787 15 5.6404V1.5ZM15 8.7289C14.5265 8.58018 14.0226 8.5 13.5 8.5C12.9774 8.5 12.4735 8.58018 12 8.7289C11.7172 8.81772 11.4452 8.93099 11.1866 9.06623C10.2811 9.53964 9.53871 10.2823 9.06556 11.1879C8.93062 11.4461 8.81757 11.7177 8.7289 12C8.58018 12.4735 8.5 12.9774 8.5 13.5C8.5 14.0226 8.58018 14.5265 8.7289 15C8.81757 15.2823 8.93062 15.5539 9.06556 15.8121C9.53871 16.7177 10.2811 17.4604 11.1866 17.9338C11.4452 18.069 11.7172 18.1823 12 18.2711C12.4735 18.4198 12.9774 18.5 13.5 18.5C14.0226 18.5 14.5265 18.4198 15 18.2711C15.2823 18.1824 15.5539 18.0694 15.8121 17.9344C16.7177 17.4613 17.4604 16.7189 17.9338 15.8134C18.069 15.5548 18.1823 15.2828 18.2711 15C18.4198 14.5265 18.5 14.0226 18.5 13.5C18.5 12.9774 18.4198 12.4735 18.2711 12C18.1823 11.7172 18.069 11.4452 17.9338 11.1866C17.4604 10.2811 16.7177 9.53871 15.8121 9.06556C15.5539 8.93062 15.2823 8.81757 15 8.7289Z"
              fill="#232740"
            />
          </svg>
        );

      case "light":
        return (
          <svg
            width="24"
            height="24"
            viewBox="0 0 24 24"
            fill="none"
            xmlns="http://www.w3.org/2000/svg"
          >
            <path
              fillRule="evenodd"
              clipRule="evenodd"
              d="M5.02116 17.6834C11.051 17.0485 15.75 11.948 15.75 5.74992C15.75 5.06549 15.6927 4.39444 15.5826 3.74132C14.4848 3.26441 13.2733 3 12 3C7.02944 3 3 7.02944 3 12C3 14.1554 3.75765 16.1338 5.02116 17.6834ZM1.33538 17.5069C0.482012 15.8576 0 13.9851 0 12C0 5.37258 5.37258 0 12 0C16.9706 0 21.2353 3.02208 23.057 7.32906C23.4887 8.34972 23.7832 9.44253 23.9174 10.5844C23.9719 11.0487 24 11.5211 24 12.0001C24 18.6275 18.6274 24.0001 12 24.0001C7.35766 24.0001 3.33101 21.3639 1.33536 17.5069C1.33536 17.5069 1.33537 17.5069 1.33538 17.5069Z"
              fill="#232740"
            />
          </svg>
        );
      default:
        return null;
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
        className={css.toggle}
      >
        {buttonIcon()}
      </button>
    </>
  );
}