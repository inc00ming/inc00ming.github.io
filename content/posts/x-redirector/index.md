---
title: "X Redirector"
date: 2026-09-01T02:07:21+03:00
draft: false
tags: ["browser-extensions", "javascript", "privacy"]
---

I built a small browser extension that redirects **x.com** to a Nitter-compatible frontend
of your choice. It is Manifest V3, has no build step, and is about 200 lines of plain
HTML and JavaScript.

[**inc00ming/first-extension**](https://github.com/inc00ming/first-extension)

## Why Nitter

[Nitter](https://github.com/zedeus/nitter) is an alternative Twitter frontend, and the
reasons I wanted it are simple:

- **No JavaScript, no ads.** Pages are rendered server-side and arrive as HTML.
- **No account.** For a read-only user there is nothing to sign into and nothing to dismiss.
- **The client never talks to X.** Every request goes through the Nitter backend, so there
  is no IP address or JavaScript fingerprint to collect on the other end.
- **It is genuinely light.** The project's own README measures a profile page at 60KB
  against 784KB from twitter.com.

It is AGPLv3, which is how a frontend like this stays a frontend and not somebody's
proprietary proxy.

## Why it picks an instance instead of hardcoding one

The first version I ran pointed at a single instance, and that turned out to be the wrong
shape for the problem. Public instances go down. The ones that stay up often serve HTML
fine but fail on images and video, which is a worse failure than being offline — the page
loads, so you assume it works, and then half of it is missing.

So the popup became a list instead of a constant. Before switching I would check
[status.d420.de](https://status.d420.de/), an uptime tracker for Nitter instances, and pick
one that was actually healthy. The custom-host field exists for the same reason: whatever
list I ship will be stale eventually, so you need to be able to type in your own.

## What it does

- Pick a target from `xcancel.com`, `nitter.net`, or `lightbrd.com`
- Add any custom instance from the popup, and remove it later
- Toggle redirection off entirely, with an `off` badge on the toolbar icon

## How it works

There is no content script. The extension registers a single
[`declarativeNetRequest`](https://developer.chrome.com/docs/extensions/reference/api/declarativeNetRequest)
dynamic rule that rewrites the host on `main_frame` navigations to `x.com` — the redirect
happens before the request leaves the browser.

The selected host and the on/off state live in `chrome.storage.sync`, which is the only
source of truth. The service worker listens for storage changes and re-applies the rule;
when redirection is off it removes the rule outright rather than leaving a disabled one
behind. That is the whole design, and it keeps the permissions to just
`declarativeNetRequest`, `storage`, and `*://x.com/*`.

## Where this stands now

Shortly after I published this, the ground moved:

> On 24 August 2026 cease and desist letters have been sent by X Corp. demanding a
> permanent takedown of Nitter instances and the project's repository.
>
> nitter.net is offline and development has stopped for the time being.

`nitter.net` now serves that notice instead of a frontend, and the
[GitHub repository is archived](https://github.com/zedeus/nitter).

Which makes the instance picker less of a convenience than I intended it to be. I added it
because instances were unreliable; it now matters because the list of instances is not
something anyone can promise. Treat the three built-in options as a starting position
rather than a guarantee, and expect the custom-host field to be the part you actually use.

## Install

There is no build step — load the folder as-is.

**Chrome / Edge / Brave**

1. Open `chrome://extensions` (or `edge://extensions` / `brave://extensions`).
2. Enable **Developer mode** in the top-right corner.
3. Click **Load unpacked** and select the project folder.
4. Click the extension icon in the toolbar and pick your redirect target.

**Firefox** — open `about:debugging#/runtime/this-firefox`, click **Load Temporary Add-on…**,
and select `manifest.json`. Note that temporary add-ons are removed when Firefox restarts;
for a permanent install you would need a signed package or
[web-ext](https://github.com/mozilla/web-ext).

The source is on GitHub at
[inc00ming/first-extension](https://github.com/inc00ming/first-extension).
