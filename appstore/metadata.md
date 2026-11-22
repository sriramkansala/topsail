# Mac App Store listing

Everything App Store Connect asks for, ready to paste. Screenshots (2880 × 1800) are in
`screenshots/`. Keep "Dynamic Island" (Apple's trademark) out of the name, subtitle, keywords
and description.

## App information

| Field | Value |
|---|---|
| Name | Clove |
| Subtitle (30) | Your notch, put to work |
| Bundle ID | `app.clove.Clove` |
| Primary category | Utilities |
| Secondary category | Productivity |
| Price | Free |
| Privacy policy URL | https://sriramkansala.github.io/clove/privacy.html |
| Support URL | https://github.com/sriramkansala/clove/issues |
| Marketing URL | https://sriramkansala.github.io/clove/ |
| Copyright | 2026 *your legal name* |
| Version | 1.0.0 |

## Promotional text (170)

Hover over your MacBook's notch to see what's playing, what's next and what's due. Free, open
source, and private: no account, no analytics.

## Description

Clove turns the notch on your MacBook into a small black island that shows what matters right
now, and grows when you move the pointer to it.

NOW PLAYING
See the track playing in Music or Spotify, with artwork and controls. Click it to jump to the app.

CALENDAR
Your next events today and tomorrow. Before a call with a Zoom, Meet, Teams, Webex or FaceTime
link, a countdown appears beside the notch. As the call starts, a card asks: Join, Ignore, or
Remind me in 5 min.

TASKS
Connect Linear with your own API key to see this cycle's issues, grouped by status. Press
Option-Space to dictate a voice note: it's transcribed and understood on your Mac, and you
review every change before it's sent.

SYSTEM
Battery and charger, power draw, per-core CPU, memory, GPU, network and free disk space,
sampled only while you look.

CLIPBOARD
The last 50 things you copied, text, links, images and files, newest first. Click one to copy it
again, or pin it to keep it for good. Recent copies stay in memory; only pinned ones are saved,
on your Mac. Items that password managers mark as secret are skipped.

LIVE ACTIVITIES
When something happens, the island shows it for a moment: plugging in, low battery (with a
shortcut to Low Power Mode), headphones connecting, "Copied to clipboard", a meeting about to
start, a task coming due, and, if you like, the volume in place of the macOS indicator.

PRIVATE BY DESIGN
No account, no ads, no analytics and no server of its own. Your calendar and music never leave
your Mac. Your Linear key stays in your keychain.

Clove is free and open source: github.com/sriramkansala/clove

## Keywords (100)

Other apps' names don't belong here (guideline 2.3.7), so no Spotify or Linear.

notch,menu bar,now playing,music,player,calendar,meeting,tasks,battery,island,widget,productivity

## Age rating

Answer None / No to every question: 4+.

## App Privacy ("nutrition label")

**Do you or your third-party partners collect data from this app?** No.

Clove has no server, analytics or SDKs. The only network requests are to `api.linear.app` with
the user's own key (only if they connect Linear; the developer never sees that data) and to
Spotify's image servers for album artwork. Calendar data, audio and transcripts never leave the
Mac. This matches `Clove/Resources/PrivacyInfo.xcprivacy`, which declares no collected data.

## App Review notes

> Clove is a menu-bar utility with no Dock icon. It shows information in the area around the
> MacBook notch. Settings opens on first launch, and afterwards from the capsule icon in the menu
> bar. Hover over the notch (on Macs without one, the top centre of the screen) to open it.
>
> Every permission is optional and asked for in context:
> - Calendars: asked from Settings › Upcoming events (or the calendar page), to show events.
> - Automation for Music / Spotify: asked while one of them is running, to show and control the
>   current track.
> - Microphone: for voice notes, transcribed on device with SpeechAnalyzer and understood by the
>   on-device Foundation Models (needs Apple Intelligence).
> - Input Monitoring and Accessibility: asked only if the user turns on "Hide macOS volume
>   indicator" (off by default). Clove then receives only the volume and mute keys, changes the
>   volume itself and shows its own indicator. It reads no other keystrokes.
>
> The low-battery notice opens Battery settings, where the user can turn on Low Power Mode.
>
> To try the tasks page and voice notes: Settings › Linear, paste the test key below, then press
> Option-Space and speak (for example "add a task to write the release notes").
>
> Linear test key: *create a throwaway Linear workspace and paste its personal API key here*
>
> There are no accounts, ads or analytics.

## Before submitting

1. Join the Apple Developer Program and register `app.clove.Clove` in App Store Connect.
2. `TEAM_ID=<your team id> scripts/release.sh`, then upload `build/AppStore/Clove.pkg` with
   Transporter.
3. Fill in the fields above, upload the screenshots, and add the Linear test key to the review
   notes.
