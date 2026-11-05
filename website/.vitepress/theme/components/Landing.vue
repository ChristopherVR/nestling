<script setup lang="ts">
import { withBase } from 'vitepress'
import {
  BellRing,
  Bluetooth,
  CalendarClock,
  FileDown,
  Languages,
  Moon,
  MoonStar,
  Pill,
  Video,
} from '@lucide/vue'
import { Button } from './ui/button'
import { Accordion, AccordionContent, AccordionItem, AccordionTrigger } from './ui/accordion'
import DeviceFrame from './DeviceFrame.vue'
import PlayIcon from './PlayIcon.vue'
import QuickLinks from './QuickLinks.vue'
import { site } from '../site'

const rows = [
  {
    id: 'logging',
    title: 'Log it in one tap',
    body: [
      'Tap Feed, Nappy or Start nap on the Today screen. The feed timer pauses while you burp, and Nestling suggests which side is next.',
      'Everything lands in History, where you can search, filter by day or hour, and correct a time you got wrong at 3 am.',
    ],
    link: { href: '/guides/logging', text: 'Logging basics' },
    shot: { src: '/screenshots/02-history.webp', alt: 'History: today’s nappies, sleep, feeds and routines, each with who logged it.' },
  },
  {
    id: 'sharing',
    title: 'Everyone sees the same log',
    body: [
      'Add your partner’s phone, a PC or a grandparent’s tablet once by scanning a QR code. From then on, the devices sync directly over your home Wi‑Fi. There is no account and no server in between.',
      'Away from home? Sync by scanning QR codes from one screen to the other.',
    ],
    link: { href: '/guides/sharing', text: 'Connect a second phone' },
    shot: { src: '/screenshots/06-family.webp', alt: 'Family hub: Mum’s phone, Dad’s phone and Gran’s tablet sharing one log.' },
  },
  {
    id: 'charts',
    title: 'The day in numbers',
    body: [
      'Charts show daily totals and hourly patterns for feeds, wees, poos and sleep, with averages and the busiest day. Handy when the clinic asks how often they are feeding.',
      'Export what History shows to a spreadsheet whenever you need it.',
    ],
    shot: { src: '/screenshots/03-charts.webp', alt: 'Charts: feeds per day as a bar chart, with the total, average and highest day.' },
  },
  {
    id: 'growth',
    title: 'A growth journal',
    body: [
      'Add a weight, height, photo or a short memory whenever you like, for example after each clinic visit. Nestling charts weight and height by date and keeps the photos month by month.',
    ],
    shot: { src: '/screenshots/04-growth.webp', alt: 'Growth: weight and height charted over time.' },
  },
]

const extras = [
  { icon: Moon, title: 'Sleep', text: 'Start nap and End nap, with times you can adjust.', href: '/guides/logging#sleep' },
  { icon: CalendarClock, title: 'Routines', text: 'Bath, bedtime or tummy time on set days, and who did it.', href: '/guides/logging#routines' },
  { icon: Pill, title: 'Pills', text: 'Your own doses worked out across the day, with reminders. Called Habits on Google Play.', href: '/guides/reminders#pills' },
  { icon: BellRing, title: 'Reminders', text: 'When the next feed is due. Each phone chooses its own.', href: '/guides/reminders' },
  { icon: Bluetooth, title: 'Momcozy pumps', text: 'Control supported pumps from Android and save each session.', href: '/guides/pump' },
  { icon: Video, title: 'Nanit camera', text: 'Watch and listen on your home network, no Nanit account needed.', href: '/guides/camera' },
  { icon: MoonStar, title: 'Dark at night', text: 'From 6 pm to 6 am the whole app switches to dark colours.', href: '/guides/logging#history-and-charts' },
  { icon: Languages, title: 'English and Afrikaans', text: 'Pick a language when you first open the app.', href: '/get-started#first-time-setup' },
  { icon: FileDown, title: 'Backups', text: 'Export your whole log to a file and import it on a new phone.', href: '/guides/backups' },
]

const faqs = [
  {
    q: 'Is Nestling free?',
    a: 'Yes. There is no account to create, no advertising and nothing to unlock.',
  },
  {
    q: 'Does it work on iPhone or Mac?',
    a: 'Not at the moment. Nestling runs on Android phones and tablets, and on Windows PCs.',
  },
  {
    q: 'Does it need the internet?',
    a: 'No. Logging works offline, and devices sync over your home Wi‑Fi or by QR code. The internet is only needed to download the app, to check for updates when you ask, and for the optional Nanit account sign-in.',
  },
  {
    q: 'What is the difference between Google Play and the APK?',
    a: 'Google Play installs and updates the app for you; its reminders are notifications, and the Pills tab is called Habits. The APK updates itself from inside the app and can ring a full‑screen alarm. They are separate apps, so keep only one of them on a phone.',
  },
  {
    q: 'What happens to my log if I lose my phone?',
    a: 'If the phone was in a family hub, the other devices still have the whole log. You can also export a backup file at any time and import it on a new phone. Uninstalling the app deletes its data from that phone.',
  },
  {
    q: 'Which pumps and cameras work?',
    a: 'On Android, the Momcozy M5 Pro (BP380), M9, M9 Pro, M10 and Air 1 pumps; testing so far has been on the M5 Pro. For cameras, the Nanit Pro on firmware 6.58.615 has been tested. Both are unofficial integrations, not made or endorsed by Momcozy or Nanit.',
  },
  {
    q: 'Is Nestling a medical device?',
    a: 'No. It is a log to help you remember. It does not replace advice from your midwife, nurse or doctor, or checking on your baby yourself.',
  },
]
</script>

<template>
  <div class="landing vp-raw font-sans text-foreground">
    <!-- Same max width and gutters as the VitePress nav, so the page lines up with the logo -->
    <div class="mx-auto max-w-[1312px] px-6 sm:px-8">
      <!-- Introduction -->
      <section class="grid gap-12 pb-10 pt-8 sm:pb-14 sm:pt-16 lg:grid-cols-[minmax(0,1fr)_280px] lg:gap-24 lg:pb-20 lg:pt-16 xl:mr-24">
        <div class="max-w-[620px]">
          <h1 class="m-0 text-[2rem] font-bold leading-[1.1] tracking-[-0.03em] sm:text-[3.5rem] sm:leading-[1.06]">
            A baby log you share with everyone who helps.
          </h1>
          <p class="m-0 mt-4 max-w-[54ch] text-[16.5px] leading-[1.6] text-ink-2 sm:mt-6 sm:text-[18px]">
            Nestling keeps track of feeds, nappies, sleep and growth on your Android phone or
            Windows PC. Every device in your home shows the same log, synced over your own
            Wi‑Fi. It’s free, there is no account, and the log never leaves your devices.
          </p>
          <div class="mt-6 flex flex-col items-start gap-4 sm:mt-8 sm:flex-row sm:items-center sm:gap-6">
            <Button as="a" :href="site.play" target="_blank" rel="noopener" size="lg">
              <PlayIcon />
              Get it on Google Play
              <span class="sr-only">(opens in a new tab)</span>
            </Button>
            <a
              :href="withBase('/get-started#download')"
              class="text-[15px] font-semibold text-primary underline decoration-1 underline-offset-4 hover:decoration-2"
            >APK and Windows downloads</a>
          </div>
        </div>
        <div class="hidden lg:block">
          <DeviceFrame
            eager
            src="/screenshots/01-today.webp"
            alt="Today screen: 2 hours 24 minutes since the last feed, with Feed, Nappy and Habit buttons below."
          />
        </div>
      </section>

      <!-- Start here -->
      <section class="grid gap-4 pb-20 lg:grid-cols-[220px_minmax(0,1fr)] lg:gap-16 lg:pb-28" aria-labelledby="start-title">
        <h2 id="start-title" class="m-0 text-xl font-bold tracking-[-0.01em] lg:pt-5">Start here</h2>
        <QuickLinks />
      </section>

      <!-- What it does, with real screens -->
      <section aria-labelledby="tour-title" class="border-t border-border pt-16 lg:pt-24">
        <h2 id="tour-title" class="m-0 max-w-[22ch] text-[1.875rem] font-bold leading-tight tracking-[-0.02em] sm:text-[2.25rem]">
          Made for the night shift
        </h2>
        <p class="m-0 mt-4 max-w-[60ch] text-[17px] leading-[1.6] text-ink-2">
          Big buttons, one tap per entry, and the time since the last feed at the top of the
          screen. Screens below are from the Google Play version.
        </p>

        <div class="mt-12 flex flex-col gap-16 lg:mt-16 lg:gap-20">
          <article
            v-for="(row, i) in rows"
            :id="row.id"
            :key="row.id"
            class="grid items-center gap-8 lg:grid-cols-12 lg:gap-12"
          >
            <div :class="['lg:col-span-5', i % 2 ? 'lg:order-2 lg:col-start-7' : 'lg:col-start-1']">
              <h3 class="m-0 text-[1.375rem] font-bold leading-snug tracking-[-0.015em]">{{ row.title }}</h3>
              <p
                v-for="(p, j) in row.body"
                :key="j"
                class="m-0 mt-3 max-w-[58ch] text-[16.5px] leading-[1.65] text-ink-2"
              >{{ p }}</p>
              <a
                v-if="row.link"
                :href="withBase(row.link.href)"
                class="mt-4 inline-block text-[15px] font-semibold text-primary underline decoration-1 underline-offset-4 hover:decoration-2"
              >{{ row.link.text }}</a>
            </div>
            <div
              :class="[
                'w-[68%] max-w-[260px] sm:w-[240px] lg:w-[260px] lg:justify-self-center',
                i % 2 ? 'lg:order-1 lg:col-span-4 lg:col-start-2' : 'lg:col-span-4 lg:col-start-8',
              ]"
            >
              <DeviceFrame :src="row.shot.src" :alt="row.shot.alt" />
            </div>
          </article>
        </div>
      </section>

      <!-- Everything else -->
      <section class="grid gap-8 pt-24 lg:grid-cols-[220px_minmax(0,1fr)] lg:gap-16 lg:pt-32" aria-labelledby="more-title">
        <h2 id="more-title" class="m-0 text-xl font-bold tracking-[-0.01em]">Also in Nestling</h2>
        <ul class="m-0 grid list-none gap-x-12 border-t border-border p-0 sm:grid-cols-2" role="list">
          <li v-for="e in extras" :key="e.title" class="m-0 border-b border-border">
            <a :href="withBase(e.href)" class="group flex gap-3 py-4 no-underline">
              <component :is="e.icon" class="mt-[3px] size-[18px] shrink-0 text-muted-foreground" aria-hidden="true" />
              <span>
                <span class="block text-[15.5px] font-semibold text-foreground group-hover:text-primary group-hover:underline group-hover:underline-offset-4">{{ e.title }}</span>
                <span class="mt-0.5 block text-[15px] leading-normal text-ink-2">{{ e.text }}</span>
              </span>
            </a>
          </li>
        </ul>
      </section>

      <!-- Privacy -->
      <section class="grid gap-6 pt-24 lg:grid-cols-[220px_minmax(0,1fr)] lg:gap-16 lg:pt-32" aria-labelledby="privacy-title">
        <h2 id="privacy-title" class="m-0 text-xl font-bold tracking-[-0.01em]">Privacy</h2>
        <div class="max-w-[62ch]">
          <p class="m-0 text-[1.375rem] font-semibold leading-snug tracking-[-0.01em] text-foreground">
            Your log stays on your own phones and computers. The developer never receives it.
          </p>
          <p class="m-0 mt-5 text-[16.5px] leading-[1.65] text-ink-2">
            Nestling has no server, no account, no advertising and no analytics. Devices in your
            family hub talk to each other directly on your Wi‑Fi, protected by a six‑digit code,
            or by scanning QR codes. Camera video and sound are shown, never recorded or uploaded.
          </p>
          <a
            :href="withBase('/privacy')"
            class="mt-4 inline-block text-[15px] font-semibold text-primary underline decoration-1 underline-offset-4 hover:decoration-2"
          >Read the privacy policy</a>
        </div>
      </section>

      <!-- FAQ -->
      <section class="grid gap-6 pb-24 pt-24 lg:grid-cols-[220px_minmax(0,1fr)] lg:gap-16 lg:pb-32 lg:pt-32" aria-labelledby="faq-title">
        <h2 id="faq-title" class="m-0 text-xl font-bold tracking-[-0.01em] lg:pt-4">Questions</h2>
        <div class="max-w-[760px]">
          <Accordion type="single" collapsible class="border-t border-border">
            <AccordionItem v-for="(f, i) in faqs" :key="f.q" :value="`faq-${i}`" class="last:border-b">
              <AccordionTrigger>{{ f.q }}</AccordionTrigger>
              <AccordionContent>{{ f.a }}</AccordionContent>
            </AccordionItem>
          </Accordion>
          <p class="m-0 mt-6 text-[15px] leading-relaxed text-ink-2">
            Not answered here? Read the
            <a :href="withBase('/get-started')" class="font-semibold text-primary underline decoration-1 underline-offset-4">install guide</a>
            or
            <a :href="site.issues" target="_blank" rel="noopener" class="font-semibold text-primary underline decoration-1 underline-offset-4">ask on GitHub</a>.
          </p>
        </div>
      </section>
    </div>
  </div>
</template>
