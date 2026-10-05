<script setup lang="ts">
// Thumbnail tones for the fake film strip.
const frames = [
  ['#1e3a5f', '#3b6e8f'],
  ['#25476b', '#4f86a6'],
  ['#2f5b5b', '#5f9c8a'],
  ['#3f5e3a', '#86a65f'],
  ['#6b4e2a', '#c79a4f'],
  ['#6b3a2f', '#c06f53'],
  ['#4a2f5b', '#8a5fa6'],
  ['#2f3a6b', '#5f73b8'],
];
</script>

<template>
  <svg
    class="hero-art"
    viewBox="0 0 400 300"
    role="img"
    aria-label="The trimmer: a yellow frame with handles selecting part of a video timeline"
  >
    <defs>
      <linearGradient
        v-for="([from, to], i) in frames"
        :id="`rnvt-frame-${i}`"
        :key="i"
        x1="0"
        y1="0"
        x2="0"
        y2="1"
      >
        <stop offset="0" :stop-color="from" />
        <stop offset="1" :stop-color="to" />
      </linearGradient>
      <clipPath id="rnvt-strip">
        <rect x="20" y="124" width="360" height="72" rx="6" />
      </clipPath>
    </defs>

    <!-- preview -->
    <rect class="screen" x="110" y="14" width="180" height="92" rx="10" />
    <circle class="sun" cx="250" cy="40" r="10" />
    <path class="hill" d="M110 92 160 58l30 22 26-16 74 34v8a10 10 0 0 1-10 10H120a10 10 0 0 1-10-10z" />
    <path class="play" d="M193 47v26l22-13z" />

    <!-- film strip -->
    <g clip-path="url(#rnvt-strip)">
      <rect
        v-for="(_, i) in frames"
        :key="i"
        :x="20 + i * 45"
        y="124"
        width="45"
        height="72"
        :fill="`url(#rnvt-frame-${i})`"
      />
      <path
        v-for="(_, i) in frames"
        :key="`h${i}`"
        class="frame-hill"
        :d="`M${20 + i * 45} 196l14-22 10 9 9-6 12 19z`"
      />
      <rect class="dim dim-left" x="20" y="124" width="76" height="72" />
      <rect class="dim dim-right" x="284" y="124" width="96" height="72" />
    </g>

    <!-- trimmer frame -->
    <rect class="bar" x="34" y="118" width="332" height="6" />
    <rect class="bar" x="34" y="196" width="332" height="6" />
    <g class="handle handle-left">
      <rect x="20" y="118" width="16" height="84" rx="6" />
      <path d="m31 152-5 8 5 8" />
    </g>
    <g class="handle handle-right">
      <rect x="364" y="118" width="16" height="84" rx="6" />
      <path d="m369 152 5 8-5 8" />
    </g>
    <rect class="playhead" x="118" y="114" width="3" height="92" rx="1.5" />

    <!-- time labels -->
    <text class="time" x="20" y="232">00:01.200</text>
    <text class="time end" x="380" y="232">00:07.450</text>
    <rect class="pill" x="160" y="250" width="80" height="26" rx="13" />
    <text class="pill-text" x="200" y="267">Save</text>
  </svg>
</template>

<style scoped>
.hero-art {
  position: absolute;
  top: 50%;
  left: 50%;
  width: 300px;
  transform: translate(-50%, -50%);
}

@media (min-width: 640px) {
  .hero-art {
    width: 360px;
  }
}

@media (min-width: 960px) {
  .hero-art {
    width: 400px;
  }
}

.screen {
  fill: #111;
  stroke: var(--vp-c-divider);
}

.sun {
  fill: #f1d247;
  opacity: 0.8;
}

.hill {
  fill: #2f5b5b;
}

.play {
  fill: #fff;
  opacity: 0.9;
}

.frame-hill {
  fill: rgba(0, 0, 0, 0.25);
}

.dim {
  fill: rgba(0, 0, 0, 0.6);
  transform-box: fill-box;
}

.dim-left {
  transform-origin: left;
  transform: scaleX(0);
  animation: dim-left 6s ease-in-out infinite;
}

.dim-right {
  transform-origin: right;
  transform: scaleX(0);
  animation: dim-right 6s ease-in-out infinite;
}

.bar {
  fill: #f1d247;
  transform-box: fill-box;
  transform-origin: left;
  animation: bar 6s ease-in-out infinite;
}

.handle rect {
  fill: #f1d247;
}

.handle path {
  fill: none;
  stroke: #1b1b1f;
  stroke-width: 2.5;
  stroke-linecap: round;
  stroke-linejoin: round;
}

.handle-left {
  animation: handle-left 6s ease-in-out infinite;
}

.handle-right {
  animation: handle-right 6s ease-in-out infinite;
}

.playhead {
  fill: #fff;
  filter: drop-shadow(0 0 2px rgba(0, 0, 0, 0.6));
  animation: playhead 3s linear infinite alternate;
}

.time {
  fill: var(--vp-c-text-2);
  font: 500 13px var(--vp-font-family-mono);
}

.time.end {
  text-anchor: end;
}

.pill {
  fill: #f2b233;
}

.pill-text {
  fill: #1b1b1f;
  font: 600 13px var(--vp-font-family-base);
  text-anchor: middle;
}

/* Left handle moves in by 60, right handle by 80; the bars follow both. */
@keyframes handle-left {
  0%,
  10%,
  100% {
    transform: translateX(0);
  }
  30%,
  80% {
    transform: translateX(60px);
  }
}

@keyframes handle-right {
  0%,
  45%,
  100% {
    transform: translateX(0);
  }
  65%,
  80% {
    transform: translateX(-80px);
  }
}

@keyframes bar {
  0%,
  10%,
  100% {
    transform: translateX(0) scaleX(1);
  }
  30%,
  45% {
    transform: translateX(60px) scaleX(0.8193);
  }
  65%,
  80% {
    transform: translateX(60px) scaleX(0.5783);
  }
}

@keyframes dim-left {
  0%,
  10%,
  100% {
    transform: scaleX(0);
  }
  30%,
  80% {
    transform: scaleX(1);
  }
}

@keyframes dim-right {
  0%,
  45%,
  100% {
    transform: scaleX(0);
  }
  65%,
  80% {
    transform: scaleX(1);
  }
}

@keyframes playhead {
  from {
    transform: translateX(0);
  }
  to {
    transform: translateX(160px);
  }
}

@media (prefers-reduced-motion: reduce) {
  .dim,
  .bar,
  .handle,
  .playhead {
    animation: none;
  }
}
</style>
