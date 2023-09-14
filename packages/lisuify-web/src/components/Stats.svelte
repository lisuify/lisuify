<script lang="ts">
  import { statsAtom } from "../stores/statsStore";
  import { round, suiToNumber, suiToString } from "../utils";
  import Info from "./icons/Info.svelte";
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
    <div class="stat-title text-sm flex gap-1 items-center">
      <div>APY</div>
      <div class="h-1/2 tooltip tooltip-left" data-tip="Mean validators APY">
        <Info />
      </div>
    </div>
    <div class="stat-value text-xl">{round($statsAtom.validatorApy, 2)}%</div>
    <div class="stat-desc">&nbsp;</div>
  </div>
</div>
