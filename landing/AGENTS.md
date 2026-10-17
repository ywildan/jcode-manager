# Project conventions

- Standalone Next.js project: the landing page for Jcode Manager. Keep the brand
  distinct from the other landing pages: black ground, white and light-white
  type, no hue anywhere. Emphasis comes from contrast, weight and geometry.
- Rounded is the house style. Use the radius scale in `app/globals.css`
  (`--r-xs`…`--r-xl`, `--r-pill`) instead of ad-hoc values. Buttons, chips and the
  header are pills; cards and panels use `--r-lg`; fields use `--r-sm`.
- Every palette value comes from a token. If a new grey is needed, add a token
  rather than a literal, and keep it neutral (equal or near-equal RGB channels).
- Prefer gapped, rounded grids over shared hairline borders. Section rules fade
  at the edges (`.plate::before`) so the scroll rhythm stays smooth.
- The projection nav (`.plate-nav`) is anchored to the rail with
  `calc(50vw - var(--rail) / 2 - …)` and only renders above 1180px width and
  680px height, so it can never collide with the hero copy. Keep that anchoring
  if you touch it.
- UI primitives live in `components/ui/`: shadcn/ui `base-maia` with Base UI and Tailwind CSS 4. Style these primitives for the brand; do not replace their controls with raw interactive HTML in feature components.
- Preserve semantic headings, landmarks and links. Use Button render composition for call-to-action links.
- Reusable, list-shaped copy (menu, safety, CLI, FAQ, templates) lives in
  `lib/content.ts` so it stays honest against the project README; section titles
  and ledes live inline with their section in `components/plates.tsx`.
- Keep fonts local and preserve their licences in `app/fonts/`. Do not introduce remote fonts, models or textures.
- This is an explicit demonstration of a plain-file CLI tool. Do not imply live provider availability, API keys, bookings, transactions or testimonials.
- No tracking, persistence or external submission without an explicitly requested backend.
- Support keyboard navigation, visible focus, live reduced-motion preferences and accessible names. Buttons, fields, nav stops and copy controls are at least 44 pixels; inline links inside paragraphs are exempt.
- Treat Three.js as progressive enhancement. Preserve the CSS fallback, no-JavaScript content access, resource disposal and loading/error recovery.
- Before delivery, run `pnpm typecheck`, `pnpm build`, and verify the changed interactions in the browser.

<!-- BEGIN:nextjs-agent-rules -->

## This is NOT the Next.js you know

This version has breaking changes — APIs, conventions, and file structure may all differ from your training data. Read the relevant guide in `node_modules/next/dist/docs/` (resolved from this file's directory; in monorepos the `next` package may not be visible from the repo root) before writing any code. Heed deprecation notices.

This block is written and re-added by `next dev` — verify at `node_modules/next/dist/server/lib/generate-agent-files.js`. Removing it from a diff only re-creates the uncommitted change; committing it with your work keeps the tree clean.

<!-- END:nextjs-agent-rules -->
