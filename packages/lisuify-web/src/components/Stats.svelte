<script lang="ts">
  import { statsAtom } from "../stores/statsStore";
</script>

<div
  class="w-full max-w-lg stats stats-vertical lg:stats-horizontal bg-base-200 rounded-lg"
>
  <div class="stat">
    <div class="stat-title">SUI Staking</div>
    <div class="stat-value">31K</div>
    <div class="stat-desc">= ~30K LiSui</div>
  </div>

  <div class="stat">
    <div class="stat-title">LiSui / SUI</div>
    <div class="stat-value">{$statsAtom.liSuiRatio}</div>
    <!-- <div class="stat-desc">↗︎ 0.01 (1%)</div> -->
  </div>

  <div class="stat">
    <div class="stat-title">APY</div>
    <div class="stat-value">5.5%</div>
    <!-- <div class="stat-desc">↘︎ 0.01 (1%)</div> -->
  </div>
</div>
