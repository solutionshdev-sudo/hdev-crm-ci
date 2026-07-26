<script setup>
import { computed } from 'vue';
import { useMapGetter } from 'dashboard/composables/store.js';

defineProps({
  headline: {
    type: String,
    default: '',
  },
  subtitle: {
    type: String,
    default: '',
  },
});

const globalConfig = useMapGetter('globalConfig/get');
const year = new Date().getFullYear();
const brandLogo = computed(
  () => globalConfig.value.logoDark || globalConfig.value.logo
);
</script>

<template>
  <main class="flex w-full min-h-screen bg-n-background">
    <!--
      Brand panel. It stays dark in both themes, while the `n-` tokens flip
      with the page theme — so only literal white/alpha values belong in here.
      A `text-n-slate-12` would render near-black on near-black in light mode.
    -->
    <aside
      class="relative flex-col hidden px-12 overflow-hidden auth-brand lg:flex lg:w-[46%] xl:w-1/2 py-14"
    >
      <!-- self-start keeps the flex column from stretching the logo to the
           full panel width, which letterboxes it inside its own viewBox. -->
      <img
        :src="brandLogo"
        :alt="globalConfig.installationName"
        class="relative z-10 self-start w-auto h-9 auth-brand__rise"
      />

      <div
        class="relative z-10 flex flex-col justify-center flex-1 py-16 max-w-[520px] auth-brand__rise"
      >
        <h1
          class="text-4xl font-semibold text-white xl:text-5xl leading-[1.12] tracking-[-0.02em] text-balance"
        >
          {{ headline }}
          <span class="block auth-brand__accent">
            {{ globalConfig.installationName }}
          </span>
        </h1>
        <p v-if="subtitle" class="mt-6 text-base leading-relaxed text-white/65">
          {{ subtitle }}
        </p>
      </div>

      <p class="relative z-10 text-xs auth-brand__rise text-white/35">
        © {{ year }} {{ globalConfig.installationName }}.
        {{ $t('LOGIN.FOOTER.RIGHTS') }}
      </p>
    </aside>

    <section
      class="flex flex-col items-center justify-center flex-1 px-5 py-10 sm:px-8"
    >
      <div class="mb-8 lg:hidden">
        <img
          :src="globalConfig.logo"
          :alt="globalConfig.installationName"
          class="block w-auto h-8 dark:hidden"
        />
        <img
          v-if="globalConfig.logoDark"
          :src="globalConfig.logoDark"
          :alt="globalConfig.installationName"
          class="hidden w-auto h-8 dark:block"
        />
      </div>

      <div class="w-full max-w-[420px]">
        <slot />
      </div>
    </section>
  </main>
</template>

<style scoped>
.auth-brand {
  /* Neutral dark navy from identidade/design-guide.md. Deliberately not a
     brand token: the agency colour comes through the glow below.
     The gradients read as one light source low on the left, a faint bounce
     top-right, and a sheen along the top edge to keep the panel from going
     flat where the logo sits. */
  background-color: #0f172a;
  background-image:
    radial-gradient(
      68% 52% at 6% 76%,
      rgb(var(--blue-9) / 0.6) 0%,
      transparent 62%
    ),
    radial-gradient(
      40% 32% at 92% 2%,
      rgb(var(--blue-9) / 0.16) 0%,
      transparent 66%
    ),
    linear-gradient(168deg, rgb(255 255 255 / 0.05) 0%, transparent 38%),
    linear-gradient(180deg, rgb(0 0 0 / 0.12) 0%, rgb(0 0 0 / 0.45) 100%);
}

.auth-brand__accent {
  /* Raw accent as the fallback. Mixing in oklch rather than srgb keeps the
     chroma up, so the agency colour lightens into a saturated tint instead
     of the washed-out grey srgb interpolation produces — while still
     clearing AA against the #0F172A panel. */
  color: rgb(var(--blue-9));
  color: color-mix(in srgb, rgb(var(--blue-9)) 55%, #fff);
  color: color-mix(in oklch, rgb(var(--blue-9)) 58%, #fff);
}

.auth-brand__rise {
  animation: auth-rise 0.5s cubic-bezier(0.22, 1, 0.36, 1) backwards;
}
.auth-brand__rise:nth-child(2) {
  animation-delay: 0.06s;
}
.auth-brand__rise:nth-child(3) {
  animation-delay: 0.12s;
}

@keyframes auth-rise {
  from {
    opacity: 0;
    transform: translateY(10px);
  }
}

@media (prefers-reduced-motion: reduce) {
  .auth-brand__rise {
    animation: none;
  }
}
</style>
