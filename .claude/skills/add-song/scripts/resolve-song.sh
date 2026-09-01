#!/usr/bin/env bash
# Resolve a song into the fields data/music.yaml needs.
#
# Usage:
#   resolve-song.sh <youtube-or-music-url>
#   resolve-song.sh "<title>" "<artist>"
#
# Prints title, artist, album, year, a 500x500 cover URL, and a suggested slug.
# Everything it prints is a suggestion: confirm the artist and the ORIGINAL release
# year before writing them into data/music.yaml.
set -euo pipefail

die() { printf 'resolve-song: %s\n' "$1" >&2; exit 1; }
command -v curl >/dev/null || die "curl not found"
command -v python3 >/dev/null || die "python3 not found"

title=""; artist=""; link=""

if [ $# -eq 0 ]; then
  die "usage: resolve-song.sh <url> | resolve-song.sh \"<title>\" \"<artist>\""
elif [ $# -ge 2 ]; then
  title="$1"; artist="$2"
elif case "$1" in http*://*) true;; *) false;; esac; then
  link="$1"
  case "$link" in
    *youtube.com/*|*youtu.be/*)
      oembed=$(curl -sS --max-time 15 \
        "https://www.youtube.com/oembed?url=$(python3 -c 'import sys,urllib.parse;print(urllib.parse.quote(sys.argv[1],safe=""))' "$link")&format=json") \
        || die "YouTube oEmbed request failed"
      [ -n "$oembed" ] || die "YouTube returned nothing; the video may be private or removed"
      eval "$(printf '%s' "$oembed" | python3 -c '
import sys, json, shlex
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit("resolve-song: could not parse YouTube oEmbed response")
a = d.get("author_name", "")
for suffix in (" - Topic", " - Tema", "VEVO"):
    if a.endswith(suffix):
        a = a[: -len(suffix)].rstrip()
print("title=" + shlex.quote(d.get("title", "")))
print("artist=" + shlex.quote(a))
')"
      ;;
    *)
      die "only YouTube links are resolved automatically; pass \"<title>\" \"<artist>\" instead"
      ;;
  esac
else
  die "not a URL; pass \"<title>\" \"<artist>\" for a plain-text lookup"
fi

[ -n "$title" ] || die "could not determine a title"

term="$title${artist:+ $artist}"
itunes=$(curl -sS --max-time 15 -G "https://itunes.apple.com/search" \
  --data-urlencode "term=$term" --data-urlencode "entity=song" --data-urlencode "limit=10") \
  || die "iTunes Search API request failed"

printf '%s' "$itunes" | ARTIST="$artist" TITLE="$title" LINK="$link" python3 -c '
import sys, json, os, re, unicodedata

title = os.environ["TITLE"]
artist = os.environ["ARTIST"]
link = os.environ["LINK"]

try:
    results = json.load(sys.stdin).get("results", [])
except Exception:
    results = []

def norm(s):
    return re.sub(r"[^a-z0-9]+", "", (s or "").lower())

match = None
for r in results:
    if artist and norm(artist) not in norm(r.get("artistName")):
        continue
    if norm(title) and norm(title) not in norm(r.get("trackName")):
        continue
    match = r
    break

# Prefer the EARLIEST release: later rows are usually reissues and compilations.
if match:
    same = [
        r for r in results
        if norm(r.get("trackName")) == norm(match.get("trackName"))
        and norm(r.get("artistName")) == norm(match.get("artistName"))
        and r.get("releaseDate")
    ]
    if same:
        match = min(same, key=lambda r: r["releaseDate"])

if match:
    title = match.get("trackName") or title
    artist = match.get("artistName") or artist
    album = match.get("collectionName") or ""
    year = (match.get("releaseDate") or "")[:4]
    art = (match.get("artworkUrl100") or "").replace("100x100bb", "500x500bb")
else:
    album = year = art = ""

slug = unicodedata.normalize("NFKD", title).encode("ascii", "ignore").decode()
slug = re.sub(r"[^a-z0-9]+", "-", slug.lower()).strip("-") or "song"

print("title:  " + title)
print("artist: " + (artist or "UNRESOLVED - look it up"))
print("album:  " + (album or "UNRESOLVED"))
print("year:   " + (year or "UNRESOLVED - look up the original release year"))
print("cover:  " + (art or "UNRESOLVED - find 500x500 album art yourself"))
print("slug:   " + slug + ".png")
if link:
    print("link:   " + link)
if not match:
    print()
    print("NOTE: no iTunes match. Fill album, year, and cover art by hand.")
elif len(results) > 1:
    print()
    print("NOTE: several releases matched; the earliest was used. Confirm the year is the")
    print("      original release, not a reissue.")
'
