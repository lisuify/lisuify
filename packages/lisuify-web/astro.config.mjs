import { defineConfig } from "astro/config";
import tailwind from "@astrojs/tailwind";
import svelte from "@astrojs/svelte";
import serviceWorker from "astrojs-service-worker";

// https://astro.build/config
export default defineConfig({
  output: "static",
  compressHTML: false,
  integrations: [tailwind(), svelte(), serviceWorker()],
  vite: {
    plugins: [],
  },
});
