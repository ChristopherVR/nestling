---
title: Install and set up
description: Install Nestling on Android from Google Play or as an APK, or on a Windows PC, and get through first-time setup in a minute.
---

# Install and set up

Nestling runs on **Android** phones and tablets and on **Windows** PCs. It is free, and you do not need an account. Setting it up takes about a minute.

## Download {#download}

<DownloadOptions />

::: tip Which Android version should I choose?
Choose **Google Play** unless you have a reason not to. The Play and GitHub versions are separate apps, so pick one per phone. [See the differences](#play-or-apk).
:::

## Android: Google Play

<div class="steps">

1. Open the [Nestling page on Google Play](https://play.google.com/store/apps/details?id=io.github.christophervr.nestling) on your phone.
2. Tap **Install**, then **Open**.
3. Allow notifications when Nestling asks, so reminders can reach you.

</div>

Google Play keeps Nestling up to date for you.

## Android: APK from GitHub {#apk}

<div class="steps">

1. On your phone, open the [latest release on GitHub](https://github.com/ChristopherVR/nestling/releases/latest).
2. Under **Assets**, tap `BabyLog-<version>.apk` to download it. (The file name is from before the app was called Nestling.)
3. Open the downloaded file. If Android asks, allow your browser or file manager to **install unknown apps**, then go back and tap **Install**.
4. Open Nestling.

</div>

To update later, go to **Settings → This device → App version**. Nestling checks GitHub for a new release and offers **Update**. The first time, Android may ask you to allow installs from Nestling; allow it, come back and tap **Update** again. Your log is kept.

::: warning Updating an APK you already have
Install the new APK over the old one. **Do not uninstall first**, or you lose the log on that phone.
:::

## Windows

<div class="steps">

1. Download `BabyLog-<version>-windows-x64.zip` from the [latest release](https://github.com/ChristopherVR/nestling/releases/latest).
2. Right-click the ZIP and choose **Extract All…**. Extract the **whole** ZIP into a folder you will keep, such as `Documents\Nestling`.
3. Open that folder and run `baby_app.exe`.
4. When Windows Firewall asks, allow access on **private networks**, so your phone can sync with the PC.

</div>

Keep `baby_app.exe` together with the DLL files and the `data` folder next to it. Everything Nestling needs is in the ZIP; you do not need to install anything else.

**Updating on Windows:** close Nestling, extract the new ZIP into a new folder and run it from there. Your log is stored separately and carries over. Windows has no in‑app updater.

::: tip Make the window your own
Resize the window as you like. Wide windows get side navigation with today's controls next to the activity log; narrow windows look like the phone app.
:::

## First-time setup

When you open Nestling for the first time, it asks a few short questions, one per screen. You can skip any of them.

<div class="steps">

1. **Welcome.** Choose **English** or **Afrikaans** and tap **Get started**. Already using Nestling on your partner's phone? Tap **Joining a partner? Connect their phone** instead, and [connect the two](/guides/sharing).
2. **Your baby's name.** A first name or a nickname is fine. Twins? Tap **Add another baby**.
3. **Birthday.** Used to show their age in weeks and months.
4. **A photo** for the Today screen, if you like. Photos stay on your own devices.
5. **How is your baby fed?** Breastfeeding, bottle, or a bit of both. This only decides where a new feed starts; you can always log any kind.

</div>

After that, Nestling walks you through logging your first feed and your first nappy. Reminders, sharing with a partner and the theme are in **Settings** whenever you want them.

## Next steps

<QuickLinks />

## Google Play or APK? {#play-or-apk}

Both versions keep the same log and sync with each other, and with Windows.

| | Google Play | APK from GitHub |
| --- | --- | --- |
| Updates | Automatic, through Google Play | In the app: **Settings → This device → App version** |
| Reminders | Notifications that use the alarm volume, with Stop and Snooze | Choose a notification or a full‑screen alarm |
| Pills tab | Called **Habits** | Called **Pills** |

They are separate apps, so Android installs them side by side instead of replacing one with the other. If you are moving from the APK to Google Play:

1. Install the Play version and add it to your [family hub](/guides/sharing), or move your log with a [backup file](/guides/backups).
2. Check that everything is there, then uninstall the GitHub copy.

Only keep one copy open on a phone at a time: both use the same sync connection.

## Something not working?

- **Reminders arrive late.** On Android, allow **Alarms & reminders** for Nestling. Settings → Reminders asks for it. See [Reminders](/guides/reminders).
- **Phones do not sync.** Both must be on the same Wi‑Fi, without a "guest" network. See [Share with a partner](/guides/sharing#troubleshooting).
- **Anything else?** [Open an issue on GitHub](https://github.com/ChristopherVR/nestling/issues).
