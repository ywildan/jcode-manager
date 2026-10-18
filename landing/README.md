# Jcode Manager

The landing page for [Jcode Manager](../README.md), an interactive manager for
jcode CLI providers. A black control deck in black, white and light white:
monumental Space Grotesk type, rounded instruments, hairline rules and a
continuous Three.js constellation of nine provider nodes.

Part of [LN's landing-page collection](https://github.com/ln-dev7/landing-pages);
the structure began from that kit and has been re-themed for this project.

## Run

Node.js 20.9+ and pnpm. From this project directory:

```sh
pnpm install
pnpm dev
pnpm typecheck
pnpm build
```

Deploy with the Next.js preset and `landing` as the root directory. Set
`NEXT_PUBLIC_SITE_URL` to the deployment origin; it defaults to
`https://jcode-manager.vercel.app`.

## Experience and accessibility

Native scrolling carries the deck. Semantic HTML keeps the story readable
independently of the WebGL canvas; the scene is a progressive enhancement with a
CSS fallback when a GPU is unavailable. The loading curtain also leaves the
content accessible with JavaScript disabled. Keyboard controls, visible focus and
reduced-motion support are part of the experience, and buttons, fields, nav stops
and copy controls are at least 44 pixels tall (inline links inside paragraphs are
exempt). The projection nav appears above 1424 x 680 so it never crowds the copy.

The provider studio previews a `[providers.<name>]` section and the matching
launch command as you type. It writes nothing, stores nothing and never asks for
an API key. Nothing on the page is submitted anywhere.

## Verification

Checked against the production build served over HTTP, with real input rather
than synthetic events:

- `pnpm typecheck` and `pnpm build` pass. The built page is exercised at 1920,
  1600, 1440, 1425, 1401, 1300, 1180, 834, 390, 360 and 320 wide: no horizontal
  overflow, no control under 44 pixels, and the projection nav appears only where
  it has a measured gutter.
- Mouse clicks drive the plate map, the plate stops, the FAQ and the copy
  controls, and the clipboard is read back and matches the command on screen.
  Keyboard-only operation works end to end (Tab, Enter, Escape, focus stays
  inside the open plate map and returns to its button). Touch taps and swipes
  work on an emulated 390x844 phone. A full scroll-through produces no console
  errors, no exceptions and no failed requests.
- Rendered contrast is at least 4.5:1 on every text surface, and the page stays
  inside a channel spread of 7: neutral, apart from the deliberate warmth of the
  light whites.
- `NEXT_PUBLIC_SITE_URL` reaches the canonical link, `og:url`, `og:image`,
  `robots.txt` and `sitemap.xml` in the built output.

Not verified here, and worth knowing before you rely on it:

- The WebGL deck ran on software rendering (SwiftShader), because the build
  environment has no GPU. Frame rate on real hardware is unmeasured.
- No live deployment: `vercel.json` and the Vercel preset are untested against a
  real deploy, and no CDN or caching behaviour has been observed.
- Touch is emulated through Chromium, not a real device, and no screen reader or
  other assistive technology has been run against the page.

This is a creative demonstration. It reflects the project README, and it makes
no claim about live provider availability, pricing or bookings.

## Design system

| Token | Value | Use |
| ----- | ----- | --- |
| `--ink` | `#000000` | Page ground |
| `--ink-raised` | `#080808` | Cards and slabs |
| `--ink-panel` | `#0d0d0d` | Bars and wells |
| `--ink-lift` | `#121212` | Hover surface |
| `--paper` | `#f7f7f4` | Primary text and the one accent |
| `--paper-soft` | `#e9e9e4` | Pressed and hovered fills |
| `--paper-dim` | `#cfcfc8` | Quiet emphasis (strings, flags) |
| `--ash` | `#a6a6a0` | Secondary text |
| `--ash-dim` | `#7a7a74` | Tertiary text |
| `--ink-deep` | `#030303` | Terminal and code wells |
| `--wash` / `--wash-strong` | white at 3.5% / 6% | Surface tints and hover fills |
| `--edge` | white at 14% | Fading section rules, focus rings |

Radii come from one scale: `--r-xs` 8, `--r-sm` 12, `--r-md` 18, `--r-lg` 24,
`--r-xl` 32 and `--r-pill`. Buttons, chips, pills and the header use the pill;
cards use `--r-lg`. No hue is used anywhere: emphasis is contrast, not colour.
Text colours clear 4.5:1 against every surface they are used on.

## Stack and assets

Next.js 16.4, React 19.3, Three.js 0.185, Tailwind CSS 4 and shadcn/ui
`base-maia` using Base UI. The visual world uses original procedural geometry;
it requires no downloaded models, remote textures or external image services.
Space Grotesk and Geist Mono are hosted locally with their SIL Open Font License
files in `app/fonts/`.

Developed by [LN](https://lndev.me). [MIT license](../LICENSE).
