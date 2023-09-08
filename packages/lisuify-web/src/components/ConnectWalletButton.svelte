<script lang="ts">
  import { connectWallet } from "../stores/walletStore";
</script>

<button
  class="btn btn-primary rounded-full"
  on:click={async () => {
    await connectWallet();
  }}
>
  Connect Wallet
</button>
