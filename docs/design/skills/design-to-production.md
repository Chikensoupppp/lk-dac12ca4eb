---
name: design-to-production
description: Use when building, editing, redesigning, or polishing an app or website interface on web or mobile (React, HTML/CSS, SwiftUI, Android, Flutter, React Native). Covers new apps and sites, new screens, UI components, navigation, layout, typography, color, animation and interaction, and making an interface look or feel more professional. Sets the design identity, routes to fitting design skills (taste, hallmark, impeccable, ui-ux-pro-max, motion, SwiftUI), renders and inspects the result, then refines it. Skip for backend, data, scripts, or non-visual work.
---

# Design to production

Default workflow for interface work. Scale it to the task: a one-line tweak gets the Light path,
a new app or redesign gets the Full path.

## Light path (small UI change)
1. Read the surrounding code and any `DESIGN.md`/theme tokens. Match them.
2. Make the change with the project's existing type, color, spacing, and components.
3. Render or preview it if that is quick. Check states and text scaling.
4. Report in two lines: what changed, what you checked.

## Full path (new app, new screen set, redesign, "make it look professional")
1. **Product.** Who uses it, what the screen is for, what the main action is. State assumptions
   rather than interrogating. Check `DESIGN.md`, existing screens, and brand assets.
2. **Identity.** Existing project: keep its identity; extend it. New project: choose one clear
   idea drawn from the product's subject and mood. Pick type, a tokenized palette, density, shape
   language, and motion character. Write it to `DESIGN.md` (short: intent, type, color tokens,
   layout rules, motion, do/don't). Do not copy another app's look.
3. **Skills.** Pick the smallest set that fits, only if listed in this session. One direction
   skill, one refiner, plus specialists as needed. Never load them all.
   - Direction (pick ONE): `frontend-design` (default for web), `taste-skill` (public
     marketing pages, "looks generic/AI-made"), `hallmark` (brand-new site from a prompt; or when
     named), `design-engineering` (existing codebase, SwiftUI, React Native, desktop, TV).
   - Personality and tokens: `ckw-design-thinking` / `ckw-design` (web), `ckw-design-system`.
   - Research: `ui-ux-pro-max` (palettes, font pairs, product-type systems, stack tips).
   - Refine: `impeccable` (critique, polish, typeset, layout, harden, audit).
   - Independent audit: `hallmark` audit, `ckw-deterministic-design`, `design:design-critique`,
     `design:accessibility-review`.
   - Motion: `animate` (web), `animate-expo` (React Native), `review-animations`,
     `animation-performance` (jank), `apple-design`, `emil-design-eng`, `find-animation-opportunities`.
   - Native and phone: `write-swift`, `figma:figma-swiftui`, `mobile-native` (web on phones).
   - Stress and variants: `break-ui` (worst-case data), `prototype` (side-by-side options).
   - Other: `design:design-system`, `design:ux-copy`, `artifact-design`, `figma:*`, `dataviz`,
     `anthropic-skills:canvas-design`, `anthropic-skills:web-artifacts-builder`.
   Re-pick when the phase changes (design -> build -> test). Skip any not listed.
4. **Build.** Working, accessible UI. Tokens for color, scale for type, real content not lorem.
   Cover empty, loading, error, focus, pressed, disabled. Honor reduced motion and text scaling.
   Touch targets at least 44pt on mobile.
5. **Render and look.** Run it: browser pane or Chrome tools for web, simulator or CI
   screenshots for iOS, emulator for Android. Check a narrow and a wide size, and light/dark if
   supported. For Brandon, send the key screenshots as files (his desktop app does not show
   images from tool results).
6. **Critique.** Judge the render, not the code. Hierarchy, rhythm, contrast, alignment,
   density, consistency, polish, tone. Write the 2-4 weakest points.
7. **Refine.** Fix them. Render again. Stop when remaining flaws are minor or taste calls.
8. **Verify behavior.** Click or tap through the real flows. Run the project's tests/build.
9. **Report.** Short: what you made, the design idea, what you verified, and exactly what you
   could not test (device, screen reader, other browsers, etc.).

## Guardrails
- Existing design system wins over your taste. Redesign only when asked.
- Don't rewrite unrelated screens or rebrand a project on your own.
- No generic AI look: default fonts only, purple-blue gradients, identical card grids, decorative
  clutter, emoji as icons, low-contrast gray text.
- Design feedback from Brandon: follow `~/.claude/rules/design-feedback.md`.
