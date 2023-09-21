import { defineConfig } from "astro/config";
import tailwind from "@astrojs/tailwind";
import svelte from "@astrojs/svelte";
import robotsTxt from "astro-robots-txt";
import serviceWorker from "astrojs-service-worker";
import mdx from "@astrojs/mdx";
import remarkMath from "remark-math";
import rehypeKatex from "rehype-katex";
import cloudflare from "@astrojs/cloudflare";

// https://astro.build/config
export default defineConfig({
  site: "https://lisuify.com",
  output: "hybrid",
  adapter: cloudflare({
    mode: "directory",
    functionPerRoute: true,
  }),
  compressHTML: false,
  integrations: [mdx(), tailwind(), svelte(), serviceWorker(), robotsTxt()],
  markdown: {
    remarkPlugins: [remarkMath],
    rehypePlugins: [[rehypeKatex, { output: "mathml" }]],
  },
  vite: {
    plugins: [],
  },
});
