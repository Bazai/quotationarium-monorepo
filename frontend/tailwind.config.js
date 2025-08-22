/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    "./app/**/*.{js,ts,jsx,tsx,mdx}",
    "./pages/**/*.{js,ts,jsx,tsx,mdx}",
    "./components/**/*.{js,ts,jsx,tsx,mdx}",
  ],
  theme: {
    fontSize: {
      DEFAULT: "16px",
    },
    screens: {
      sm: { max: "768px" },
    },
    container: {
      center: true,
      padding: "1rem",
      screens: {
        default: "100%",
        md: "1440px",
      },
    },
    colors: {
      transparent: "transparent",
      current: "currentColor",
      primary: "var(--primary)",
      secondary: "var(--secondary)",
      background: "var(--background)",
      "secondary-background": "var(--secondary-background)",
      "primary-dim": "var(--primary-dim)",
      dotted: "var(--dotted)",
      "primary-bright": "var(--primary-bright)",
      "primary-dark": "var(--primary-dark)",
      "secondary-bright": "var(--secondary-bright)",
    },

    extend: {},
  },
  plugins: [],
};
