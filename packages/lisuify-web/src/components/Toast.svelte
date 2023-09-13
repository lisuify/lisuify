<script lang="ts">
  import { fade, fly } from "svelte/transition";
  import { onDestroy } from "svelte";
  import { toastAtom } from "../stores/toastStore";

  interface Toast {
    text: string;
    visible: boolean;
    status: "info" | "success" | "error";
    link?: string;
  }

  const duration = 10000; // 10 sec
  let toasts: Toast[] = [];

  function addToast(
    text: string,
    status: "info" | "success" | "error",
    link?: string
  ): void {
    const toast = { text, visible: true, status, link };
    toasts = [toast, ...toasts];

    setTimeout(() => {
      toast.visible = false;
      toasts = toasts.filter((t) => t !== toast);
    }, duration);
  }

  const unsubscribe = toastAtom.subscribe((t) => {
    if (t) addToast(t.message, t.status, t.link);
  });

  onDestroy(() => {
    unsubscribe();
  });
</script>

<div class="fixed bottom-4 right-4 space-y-2">
  {#each toasts as toast}
    <div
      class="alert alert-{toast.status} flex justify-between gap-2"
      in:fade|global={{ duration: 100 }}
      out:fly|global={{ duration: 1000, x: 500, opacity: 0 }}
      style={toast.visible ? "" : "display: none;"}
    >
      <span>{toast.text}</span>
      {#if toast.link}
        <a href={toast.link} target="_blank">
          <svg
            xmlns="http://www.w3.org/2000/svg"
            fill="none"
            viewBox="0 0 24 24"
            stroke-width="1.5"
            stroke="currentColor"
            class="w-6 h-6"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              d="M15.75 9V5.25A2.25 2.25 0 0013.5 3h-6a2.25 2.25 0 00-2.25 2.25v13.5A2.25 2.25 0 007.5 21h6a2.25 2.25 0 002.25-2.25V15m3 0l3-3m0 0l-3-3m3 3H9"
            />
          </svg>
        </a>
      {/if}
    </div>
  {/each}
</div>
