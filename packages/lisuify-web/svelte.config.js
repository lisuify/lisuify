import { vitePreprocess } from "@astrojs/svelte";

export default {
  compilerOptions: { hydratable: true },
  preprocess: vitePreprocess(),
};
