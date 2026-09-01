---
title: "Call Recording Splitter"
date: 2026-09-02T00:20:00+03:00
draft: false
tags: ["python", "cli", "ffmpeg", "docker"]
---

I built a terminal tool that cuts `.m4a` recordings into consecutive fixed-length parts,
fifteen minutes each by default. It has exactly one real user, and she does not use a
terminal. That constraint decided almost everything about it.

[**inc00ming/call-recording-splitter**](https://github.com/inc00ming/call-recording-splitter)

## Why it exists

My wife does academic research. Part of that work is recording interviews with nurses and
midwives and then listening back to transcribe them, which is slow and unrewarding in the
way that transcription always is.

There are free audio-to-text services that will do it for you. I looked at
[any2text.com](https://any2text.com) and [turboscribe.ai](https://turboscribe.ai). But
their free plans cap how long a single upload can be, and her recordings run longer than
the cap. That leaves three options: pay per file, open each recording in an audio editor
and trim it by hand, or cut the recordings into pieces the free tier will accept and feed
them through one at a time.

The third is the only one that scales, and it is the one a computer should be doing.

```
lecture.m4a  (40:00)  →  lecture-part-1.m4a  (15:00)
                         lecture-part-2.m4a  (15:00)
                         lecture-part-3.m4a  (10:00)
```

Fifteen minutes is only the default. Whatever length the service you are uploading to
accepts, that is the number you give it.

## The user does not use a terminal

This is where the project stops resembling the ones I write for myself.

I am not the user. She is, and she has no reason to know what a shell is, what uv does, or
why ffmpeg would have to be on a PATH. Everything that is a reasonable ask of a developer
is, for her, a reason to give up and go back to trimming files by hand. So the question
behind each decision stopped being "what is the clean way to build this" and became "what
does she have to know before it works".

The install problem came first. The honest local setup is Python 3.11 or newer, uv, and
both `ffmpeg` and `ffprobe` on the PATH, and there is no version of that sentence I wanted
to say out loud to her. So there is a Docker image. It carries Python, uv and ffmpeg, and
nothing lands on her machine except Docker itself. It is not there as a deployment option
for people who happen to like containers. It is there because it collapses an afternoon of
installing things into one command:

```bash
docker run -it --rm \
  -v /path/to/calls:/data/input \
  -v /path/to/parts:/data/output \
  call-recording-splitter
```

The image sets `RUNNING_IN_DOCKER=1`, and the CLI reads that as "do not ask anything": it
takes the two mount points and starts working. One command, nothing to get in the wrong
order, nothing to remember.

Outside the container, with no arguments, it asks instead. It wants the source folder
holding the recordings and then the output folder for the parts, each named in the prompt,
and it re-asks rather than exiting when it gets something it cannot use. That is not a mode
I added for completeness. It is there so nobody has to remember which folder goes first.

Whichever way it gets them, the output folder is not allowed to equal the source folder.
Left alone, the parts would land next to their originals, and the next run would find them
and split the parts into parts. That is not a hypothetical failure. It is exactly the
mistake a tired person makes at the end of a long day, and the cheapest place to stop it is
before it can happen.

And a recording already shorter than one part still comes out as `name-part-1.m4a` instead
of being copied through under its own name. That looks like a quirk until you picture the
output folder: every file in it has the same shape, so she never has to work out which one
escaped being split, or whether that means something went wrong.

## The one option that is for me

There is a single option in the tool that has nothing to do with her.

If parts from an earlier run are already sitting in the output folder, it stops and asks
what to do about them. In front of a person that is the right behaviour. In a script it is
the wrong one, because there is nobody there to answer, and a job that hangs on a prompt at
three in the morning is worse than one that fails. So `--on-existing` answers the question
before it gets asked:

```bash
uv run split-recordings ~/calls ~/calls-split --on-existing skip
```

I keep it because I am the one who runs it that way. It is a useful reminder that "the
user" is not always the same person, and that the two of them want opposite things from
the same prompt.

## Moving frames instead of decoding them

This is the one place in the project where there was an interesting call to make.

Splitting audio is usually done by decoding the source, cutting it, and encoding the pieces
back out. That works, it lands the cut exactly where you asked for it, and it costs you
both quality and time. You are re-encoding lossy audio into lossy audio, and a folder of
hour-long interviews takes minutes to get through.

The tool does not do that. Every part is written with `ffmpeg -c copy`, a stream copy: the
encoded audio frames are moved from the source file into the new one without ever being
decoded. Nothing is re-encoded, so nothing degrades, and the run costs roughly what it
costs to move the bytes. A folder of recordings is done in seconds.

The trade-off is precision. A stream copy cannot cut in the middle of a frame, so each
boundary lands on the nearest AAC frame rather than on the exact millisecond you asked for.
A part can run up to about 23 ms long, and two consecutive parts can overlap by at most
that much. Nothing is ever lost. No audio falls into a gap between parts; you just get a
couple of hundredths of a second at each seam that appears twice.

Which is the whole argument for doing it this way. Twenty-three milliseconds is inaudible,
and in a transcript it is invisible. Precision nobody can perceive is precision you can
afford to trade, and trading it buys losslessness and a run that finishes while you are
still looking at it.

## Building for one person

Writing software for someone you live with is a different problem from writing it for other
developers, and mostly a better one. There is no analytics, no issue tracker and no
guessing. The feedback arrives at the kitchen table, in plain language, on the same day.
When something is confusing she says it is confusing, and she is right, because confusing
is not a property of the code. It is a property of what happened when she used it.

It also removes the excuses. I cannot tell her to read the README, or that it works on my
machine, or that the flag is documented. Whatever she has to know before the tool is any
use to her is a cost I put there, and the only acceptable size for that cost is as close to
zero as I can get it. Every decision above is me paying that number down.

As specifications go, it is a lot clearer than most of the ones I am handed.

## Source

The README covers what I have left out here: the flags, the exit codes, the Windows
invocation, and what a run looks like while it is going.

The source is on GitHub at
[inc00ming/call-recording-splitter](https://github.com/inc00ming/call-recording-splitter).

---

Why are midwifery professors so strict about assignment deadlines?

Because they take their due dates very seriously!
