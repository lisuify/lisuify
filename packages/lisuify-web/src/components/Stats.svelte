<script lang="ts">
  import { statsAtom } from "../stores/statsStore";
  import { floor, round, suiToNumber, suiToString } from "../utils";
</script>

<div
  class="w-full max-w-lg stats stats-vertical lg:stats-horizontal bg-base-200 rounded-lg"
>
  <div class="stat">
    <div class="stat-title text-sm">Total SUI Staking</div>
    <div class="stat-value text-xl">
      {suiToString($statsAtom.totalSuiStaking)}
    </div>
    <div class="stat-desc">
      = ~{round(
        suiToNumber($statsAtom.totalSuiStaking) / $statsAtom.liSuiRatio
      )} LiSui
    </div>
  </div>

  <div class="stat">
    <div class="stat-title text-sm">SUI / LiSui</div>
    <div class="stat-value text-xl">
      {round($statsAtom.liSuiRatio)} SUI
    </div>
    <div class="stat-desc">= 1 liSUI</div>
  </div>

  <div class="stat">
    <div class="stat-title text-sm">APY</div>
    <div class="stat-value text-xl">5.5%</div>
    <div class="stat-desc">↗︎ 0.01 (1%)</div>
  </div>
</div>
