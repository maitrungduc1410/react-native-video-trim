<script setup lang="ts">
import { useData } from 'vitepress';
import { computed, ref } from 'vue';

const DEFAULT_TRIMMER = '#f1d247';
const DEFAULT_WAVEFORM = '#ffffff';
const DEFAULT_WAVEFORM_BG = '#3478f6';

const strings = {
  en: {
    theme: 'Theme',
    media: 'Media type',
    video: 'Video',
    audio: 'Audio',
    trimmerColor: 'Trimmer color',
    handleIconColor: 'Handle icon color',
    headerText: 'Header text',
    headerTextColor: 'Header text color',
    waveformColor: 'Waveform color',
    waveformBackgroundColor: 'Waveform background color',
    reset: 'Reset',
    auto: 'theme default',
    contrast: 'Chevron contrast on the handle',
    lowContrast: 'low, hard to see',
    copy: 'Copy',
    copied: 'Copied',
    preview:
      'Approximate preview of the editor. The real editor is native and also shows the edit toolbar.',
    placeholder: 'Trim your video',
    cancel: 'Cancel',
    save: 'Save',
  },
  vi: {
    theme: 'Giao diện',
    media: 'Loại tệp',
    video: 'Video',
    audio: 'Âm thanh',
    trimmerColor: 'Màu thanh cắt',
    handleIconColor: 'Màu biểu tượng tay cầm',
    headerText: 'Tiêu đề',
    headerTextColor: 'Màu tiêu đề',
    waveformColor: 'Màu sóng âm',
    waveformBackgroundColor: 'Nền sóng âm',
    reset: 'Đặt lại',
    auto: 'mặc định theo giao diện',
    contrast: 'Độ tương phản của mũi tên trên tay cầm',
    lowContrast: 'thấp, khó nhìn',
    copy: 'Sao chép',
    copied: 'Đã chép',
    preview:
      'Bản xem trước gần đúng của trình chỉnh sửa. Trình chỉnh sửa thật là giao diện gốc và có thêm thanh công cụ chỉnh sửa.',
    placeholder: 'Cắt video của bạn',
    cancel: 'Hủy',
    save: 'Lưu',
  },
  zh: {
    theme: '主题',
    media: '媒体类型',
    video: '视频',
    audio: '音频',
    trimmerColor: '裁剪框颜色',
    handleIconColor: '手柄图标颜色',
    headerText: '标题文字',
    headerTextColor: '标题文字颜色',
    waveformColor: '波形颜色',
    waveformBackgroundColor: '波形背景',
    reset: '重置',
    auto: '跟随主题',
    contrast: '手柄上箭头的对比度',
    lowContrast: '偏低，不易看清',
    copy: '复制',
    copied: '已复制',
    preview: '编辑器的近似预览。真实编辑器是原生界面，还会显示编辑工具栏。',
    placeholder: '裁剪你的视频',
    cancel: '取消',
    save: '保存',
  },
};

const { lang } = useData();
const t = computed(() => {
  const key = lang.value.slice(0, 2) as keyof typeof strings;
  return strings[key] ?? strings.en;
});

const theme = ref<'dark' | 'light'>('dark');
const type = ref<'video' | 'audio'>('video');
const trimmerColor = ref(DEFAULT_TRIMMER);
const handleIconColor = ref<string | null>(null);
const headerText = ref('');
const headerTextColor = ref<string | null>(null);
const waveformColor = ref(DEFAULT_WAVEFORM);
const waveformBackgroundColor = ref(DEFAULT_WAVEFORM_BG);

const isLight = computed(() => theme.value === 'light');
// Same fallbacks as showEditor() in src/index.tsx.
const effectiveHandleIcon = computed(
  () => handleIconColor.value ?? (isLight.value ? '#ffffff' : '#000000')
);
const effectiveHeaderColor = computed(
  () => headerTextColor.value ?? (isLight.value ? '#000000' : '#ffffff')
);

function luminance(hex: string): number {
  const n = parseInt(hex.slice(1), 16);
  const channels = [(n >> 16) & 255, (n >> 8) & 255, n & 255].map((c) => {
    const s = c / 255;
    return s <= 0.03928 ? s / 12.92 : ((s + 0.055) / 1.055) ** 2.4;
  });
  return 0.2126 * channels[0]! + 0.7152 * channels[1]! + 0.0722 * channels[2]!;
}

const contrast = computed(() => {
  const a = luminance(trimmerColor.value);
  const b = luminance(effectiveHandleIcon.value);
  return (Math.max(a, b) + 0.05) / (Math.min(a, b) + 0.05);
});

const bars = Array.from({ length: 40 }, (_, i) =>
  Math.round(25 + 70 * Math.abs(Math.sin(i * 1.7) * Math.cos(i * 0.45)))
);

const snippet = computed(() => {
  const lines: string[] = [];
  if (type.value === 'audio') lines.push(`type: 'audio',`);
  if (isLight.value) lines.push(`theme: 'light',`);
  if (headerText.value) {
    lines.push(`headerText: ${JSON.stringify(headerText.value)},`);
  }
  if (headerTextColor.value) {
    lines.push(`headerTextColor: '${headerTextColor.value}',`);
  }
  if (trimmerColor.value !== DEFAULT_TRIMMER) {
    lines.push(`trimmerColor: '${trimmerColor.value}',`);
  }
  if (handleIconColor.value) {
    lines.push(`handleIconColor: '${handleIconColor.value}',`);
  }
  if (type.value === 'audio') {
    if (waveformColor.value !== DEFAULT_WAVEFORM) {
      lines.push(`waveformColor: '${waveformColor.value}',`);
    }
    if (waveformBackgroundColor.value !== DEFAULT_WAVEFORM_BG) {
      lines.push(`waveformBackgroundColor: '${waveformBackgroundColor.value}',`);
    }
  }
  const uri = type.value === 'audio' ? 'audioUri' : 'videoUri';
  if (!lines.length) return `showEditor(${uri}, {});`;
  return `showEditor(${uri}, {\n${lines.map((l) => `  ${l}`).join('\n')}\n});`;
});

const copied = ref(false);
async function copy() {
  await navigator.clipboard.writeText(snippet.value);
  copied.value = true;
  setTimeout(() => (copied.value = false), 1500);
}

function reset() {
  theme.value = 'dark';
  type.value = 'video';
  trimmerColor.value = DEFAULT_TRIMMER;
  handleIconColor.value = null;
  headerText.value = '';
  headerTextColor.value = null;
  waveformColor.value = DEFAULT_WAVEFORM;
  waveformBackgroundColor.value = DEFAULT_WAVEFORM_BG;
}
</script>

<template>
  <div class="playground">
    <form class="controls" @submit.prevent>
      <fieldset>
        <legend>{{ t.theme }}</legend>
        <label><input v-model="theme" type="radio" value="dark" /> dark</label>
        <label><input v-model="theme" type="radio" value="light" /> light</label>
      </fieldset>
      <fieldset>
        <legend>{{ t.media }}</legend>
        <label><input v-model="type" type="radio" value="video" /> {{ t.video }}</label>
        <label><input v-model="type" type="radio" value="audio" /> {{ t.audio }}</label>
      </fieldset>

      <label class="row">
        <span>{{ t.trimmerColor }} <code>trimmerColor</code></span>
        <input v-model="trimmerColor" type="color" />
      </label>
      <label class="row">
        <span>
          {{ t.handleIconColor }} <code>handleIconColor</code>
          <small v-if="!handleIconColor">({{ t.auto }})</small>
        </span>
        <input
          type="color"
          :value="effectiveHandleIcon"
          @input="handleIconColor = ($event.target as HTMLInputElement).value"
        />
      </label>
      <label class="row">
        <span>{{ t.headerText }} <code>headerText</code></span>
        <input v-model="headerText" type="text" :placeholder="t.placeholder" maxlength="40" />
      </label>
      <label class="row">
        <span>
          {{ t.headerTextColor }} <code>headerTextColor</code>
          <small v-if="!headerTextColor">({{ t.auto }})</small>
        </span>
        <input
          type="color"
          :value="effectiveHeaderColor"
          @input="headerTextColor = ($event.target as HTMLInputElement).value"
        />
      </label>
      <template v-if="type === 'audio'">
        <label class="row">
          <span>{{ t.waveformColor }} <code>waveformColor</code></span>
          <input v-model="waveformColor" type="color" />
        </label>
        <label class="row">
          <span>{{ t.waveformBackgroundColor }} <code>waveformBackgroundColor</code></span>
          <input v-model="waveformBackgroundColor" type="color" />
        </label>
      </template>

      <p class="contrast" :class="{ low: contrast < 3 }">
        {{ t.contrast }}: <strong>{{ contrast.toFixed(1) }}:1</strong>
        <span v-if="contrast < 3"> ({{ t.lowContrast }})</span>
      </p>
      <button type="button" class="reset" @click="reset">{{ t.reset }}</button>
    </form>

    <div class="preview-col">
      <div
        class="device"
        :class="theme"
        role="img"
        :aria-label="t.preview"
      >
        <div class="header" :style="{ color: effectiveHeaderColor }">{{ headerText || '\u00a0' }}</div>
        <div class="screen" :class="type">
          <svg v-if="type === 'video'" viewBox="0 0 160 90" aria-hidden="true">
            <circle cx="125" cy="22" r="9" fill="#f1d247" opacity="0.8" />
            <path d="M0 90 45 45l28 22 24-14 63 37z" fill="#2f5b5b" />
          </svg>
          <svg v-else viewBox="0 0 24 24" class="note" aria-hidden="true">
            <path d="M9 18V5l12-2v13" />
            <circle cx="6" cy="18" r="3" />
            <circle cx="18" cy="16" r="3" />
          </svg>
        </div>
        <div class="trimmer" :style="{ '--trimmer': trimmerColor, '--chevron': effectiveHandleIcon }">
          <div
            class="track"
            :style="type === 'audio' ? { background: waveformBackgroundColor } : undefined"
          >
            <template v-if="type === 'video'">
              <span v-for="i in 8" :key="i" class="thumb" :style="{ filter: `hue-rotate(${i * 40}deg)` }" />
            </template>
            <div v-else class="wave">
              <span
                v-for="(h, i) in bars"
                :key="i"
                :style="{ height: `${h}%`, background: waveformColor }"
              />
            </div>
          </div>
          <div class="frame">
            <span class="handle left">‹</span>
            <span class="handle right">›</span>
          </div>
        </div>
        <div class="times"><span>00:01.200</span><span>00:07.450</span></div>
        <div class="actions">
          <span>{{ t.cancel }}</span>
          <span class="play">▶</span>
          <span>{{ t.save }}</span>
        </div>
      </div>

      <div class="snippet">
        <button type="button" class="copy" @click="copy">{{ copied ? t.copied : t.copy }}</button>
        <pre><code>{{ snippet }}</code></pre>
      </div>
    </div>
  </div>
</template>

<style scoped>
.playground {
  display: grid;
  gap: 24px;
  margin: 24px 0;
  padding: 20px;
  border: 1px solid var(--vp-c-divider);
  border-radius: 12px;
  background: var(--vp-c-bg-soft);
}

@media (min-width: 768px) {
  .playground {
    grid-template-columns: minmax(0, 1fr) minmax(0, 1fr);
  }
}

.controls {
  display: flex;
  flex-direction: column;
  gap: 12px;
  font-size: 14px;
}

fieldset {
  display: flex;
  flex-wrap: wrap;
  gap: 16px;
  margin: 0;
  padding: 0;
  border: 0;
}

legend {
  width: 100%;
  margin-bottom: 4px;
  font-weight: 600;
}

.row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
}

.row code {
  font-size: 12px;
}

.row small {
  color: var(--vp-c-text-2);
}

input[type='color'] {
  flex: none;
  width: 44px;
  height: 32px;
  padding: 2px;
  border: 1px solid var(--vp-c-divider);
  border-radius: 6px;
  background: var(--vp-c-bg);
  cursor: pointer;
}

input[type='text'] {
  width: 50%;
  padding: 4px 8px;
  border: 1px solid var(--vp-c-divider);
  border-radius: 6px;
  background: var(--vp-c-bg);
}

input:focus-visible,
button:focus-visible {
  outline: 2px solid var(--vp-c-brand-1);
  outline-offset: 2px;
}

.contrast {
  margin: 0;
  color: var(--vp-c-text-2);
}

.contrast.low strong,
.contrast.low span {
  color: var(--vp-c-danger-1);
}

.reset {
  align-self: flex-start;
  padding: 4px 14px;
  border: 1px solid var(--vp-c-divider);
  border-radius: 20px;
  font-size: 13px;
  font-weight: 500;
}

.reset:hover {
  border-color: var(--vp-c-brand-1);
}

.preview-col {
  display: flex;
  flex-direction: column;
  gap: 16px;
  min-width: 0;
}

.device {
  --fg: #fff;
  padding: 14px 14px 10px;
  border-radius: 20px;
  background: #000;
  color: var(--fg);
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
  box-shadow: 0 0 0 1px var(--vp-c-divider);
}

.device.light {
  --fg: #000;
  background: #fff;
}

.header {
  min-height: 22px;
  font-size: 16px;
  font-weight: 600;
  text-align: center;
}

.screen {
  display: grid;
  place-items: center;
  aspect-ratio: 16 / 9;
  margin: 10px 0 14px;
  overflow: hidden;
  border-radius: 6px;
  background: linear-gradient(#1e3a5f, #4f86a6);
}

.screen svg {
  width: 100%;
  height: 100%;
}

.screen.audio {
  background: transparent;
}

.screen .note {
  width: 56px;
  height: 56px;
  fill: none;
  stroke: var(--fg);
  stroke-width: 1.5;
}

.trimmer {
  position: relative;
  height: 52px;
}

.track {
  position: absolute;
  inset: 4px 12px;
  display: flex;
  overflow: hidden;
  border-radius: 4px;
}

.thumb {
  flex: 1;
  background: linear-gradient(#25476b, #c79a4f);
}

.wave {
  display: flex;
  flex: 1;
  align-items: center;
  gap: 2px;
  padding: 0 4px;
}

.wave span {
  flex: 1;
  border-radius: 1.5px;
}

.frame {
  position: absolute;
  inset: 0 0 0 0;
  border-top: 4px solid var(--trimmer);
  border-bottom: 4px solid var(--trimmer);
  border-radius: 6px;
  margin: 0 8px;
}

.handle {
  position: absolute;
  top: -4px;
  bottom: -4px;
  display: grid;
  place-items: center;
  width: 16px;
  background: var(--trimmer);
  color: var(--chevron);
  font-size: 22px;
  font-weight: 700;
  line-height: 1;
}

.handle.left {
  left: -8px;
  border-radius: 6px 0 0 6px;
}

.handle.right {
  right: -8px;
  border-radius: 0 6px 6px 0;
}

.times {
  display: flex;
  justify-content: space-between;
  margin-top: 6px;
  font: 12px var(--vp-font-family-mono);
  opacity: 0.8;
}

.actions {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-top: 10px;
  font-size: 15px;
}

.play {
  font-size: 18px;
}

.snippet {
  position: relative;
}

.snippet pre {
  margin: 0;
  padding: 16px;
  overflow-x: auto;
  border-radius: 8px;
  background: var(--vp-code-block-bg);
  font: 13px/1.6 var(--vp-font-family-mono);
}

.copy {
  position: absolute;
  top: 8px;
  right: 8px;
  padding: 2px 10px;
  border: 1px solid var(--vp-c-divider);
  border-radius: 6px;
  background: var(--vp-c-bg);
  font-size: 12px;
}
</style>
