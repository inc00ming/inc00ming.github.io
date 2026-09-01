---
name: add-song
description: Add a song to the Music page of this Hugo site (data/music.yaml plus a cover image in assets/music/). Use when the user shares a YouTube link, a Spotify/Apple Music link, or a "song by artist" and asks to add it to the music page, music list, or favourite songs.
---

# Add a song to the Music page

## Input

Either a link (YouTube, Spotify, Apple Music) or plain text like `Migrants by Federico Albanese`.
Everything else (artist, year, album cover) is resolved for you.

## Quick start

```bash
.claude/skills/add-song/scripts/resolve-song.sh "https://www.youtube.com/watch?v=Izq-gDqiA-o"
```

It prints the title, artist, album, release year, a 500x500 cover URL, and a suggested
slug. Read it, sanity-check it, then apply the two changes below.

## Workflow

1. **Resolve metadata.** Run the script above. It reads YouTube oEmbed for the title and
   channel, then queries the iTunes Search API for the album and release year.
   Check the result before trusting it:
   - Auto-generated YouTube channels are named `Artist - Topic`; the script strips the
     suffix, but confirm the artist is a person or band, not a label or uploader.
   - Use the **original** release year of the recording, not a reissue or a "Topic"
     upload date. If iTunes returns several albums, prefer the earliest studio release.
   - If the script cannot resolve something, look it up and pass the pieces by hand:
     `resolve-song.sh "Migrants" "Federico Albanese"`.

2. **Add the cover.** Save a 500x500 PNG at `assets/music/<slug>.png`.

   ```bash
   curl -sL "<cover-url>" -o /tmp/cover.jpg
   sips -s format png /tmp/cover.jpg --out assets/music/<slug>.png
   file assets/music/<slug>.png   # must say: PNG image data, 500 x 500
   ```

   Never just rename a `.jpg` to `.png`. The layout resolves covers through Hugo's asset
   pipeline and a mislabelled file breaks the build.

3. **Add the entry.** Append to the end of `items:` in `data/music.yaml`, matching the
   existing entries exactly:

   ```yaml
     - cover: <slug>.png
       title: "Migrants"
       artist: "Federico Albanese"
       year: 2016
       note: ""
       links:
         - { label: "YouTube", url: "https://www.youtube.com/watch?v=Izq-gDqiA-o" }
   ```

   Leave `note` empty unless the user gives one. It is a short personal line about the
   song, not a description of it, so never invent it.

4. **Verify.**

   ```bash
   hugo --gc
   ```

   `layouts/_default/music.html` emits
   `music: missing cover asset: assets/music/<file>` when a cover does not resolve, so a
   build with no such warning is what proves step 2 worked. The pre-existing
   `languageCode was deprecated` warnings are unrelated and expected. Then confirm the
   new song appears in `public/music/index.html` with its cover and link.

   The theme lives in the `themes/hugo-paper` git submodule. In a fresh clone or
   worktree, run `git submodule update --init` first, or the page builds empty and the
   verification proves nothing.

## House rules

- Never use em-dashes anywhere on this site, including PR descriptions.
- The default branch is `master`, not `main`.
- Changes land through a pull request the site owner reads and merges.
- Keep the change surgical: `data/music.yaml` and the one new cover file, nothing else.

## Adding several songs

Repeat steps 1 to 3 for each song, then build once at the end. Keep them in one commit
and one PR.
