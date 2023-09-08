/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ["./src/**/*.{astro,html,js,svelte,ts,svx,md}"],
  safelist: ["alert-info", "alert-success", "alert-error"],
  theme: {
    extend: {},
  },
  plugins: [require("@tailwindcss/typography"), require("daisyui")],
  darkMode: ["media"],
  daisyui: {
    styled: true,
    base: true,
    utils: true,
    logs: false,
    rtl: false,
    prefix: "",
    themes: [
      {
        light: {
          ...require("daisyui-ntsd").light,
          "--rounded-box": "0.5rem",
          "--rounded-btn": "0.5rem",
          "--rounded-badge": "0.5rem",
          "--tab-radius": "0.5rem",
        },
      },
      {
        dark: {
          ...require("daisyui-ntsd").dark,
          "--rounded-box": "0.5rem",
          "--rounded-btn": "0.5rem",
          "--rounded-badge": "0.5rem",
          "--tab-radius": "0.5rem",
        },
      },
    ],
  },
};
