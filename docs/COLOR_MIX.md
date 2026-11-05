# Mixing colors across the app (research and proposal)

Written 2026-11-04. Sources are design-system pages and blogs, many unofficial. Nothing here is built. Mock: `docs/design/colors-ideas.png` (source `colors-ideas.html`).

## What the research says
- **Keep the base calm, use color on purpose.** Design systems (for example Windmill) keep the interface mostly one tone and use accent colors for clear jobs. Neon accents that fight the content are a common mistake.
- **Headspace uses separate palettes for separate moods** (warm oranges, calm blues and sages, deep navy for sleep), per one unofficial design study. So one app can hold several accent families if each has a job.
- **Calm keeps accents restrained** and uses them for small details, per unofficial references.
- **Proportion rule of thumb:** about 60% base, 30% secondary, 10% accent (some say 80/15/5). A blog rule, not research.
- **Accessibility:** text and icon colors need about 4.5:1 contrast. Warm light colors like amber often fail on a light background, so each one must be measured. iOS has "Differentiate Without Color", so a color must never be the only clue. Pair it with an icon or a label.
- Gap: I found no evidence about Finch or Apple Fitness, and no peer-reviewed color-psychology result. Do not claim colors "boost focus".

## Proposed mix (keeps the Cream base)
Cream stays the base. Text stays warm brown. Color shows up in the ring, the main button, the selected tab, and small icons.

| Area | Accent | Why |
|---|---|---|
| Focus | Caramel (`#F2C890`, ring `#EFC38A` to `#D98550`) | Our current look. Warm, the main brand color. |
| Progress | Sage (`#C7DDB9`, ring `#B5D3A5` to `#6FA37A`) | Growth and rest. |
| PC | Dusty blue (`#C2D8EA`, ring `#A9CBE3` to `#5E93B8`) | The other device feels different. |
| You | Rose (`#F1CBC7`, ring `#F2BDB9` to `#CF7F86`) | Personal, soft. |
| PLUS tag | Caramel everywhere | One steady marker for paid items. |
| PC connected light | Sage green | Green means on. |

Each tab also tints the background a little (cream to sage, mint, or blush at the bottom).

## Version 2 (Brandon's feedback: v1 was "all totally different")
Lesson: a full different color on every tab looks like four apps. Caramel must lead, and the others must be small touches.
- **Caramel pops most.** All backgrounds stay the same cream. Every ring, main button and selected tab is caramel.
- **Sage pops a little:** check dots for finished days, the "PC connected" light, "Gentle".
- **Dusty blue and rose pop least:** only on small workspace icons (Study blue, Write rose) and the "Locked" dot.
- **Lavender:** rest-day dot only. **Honey:** "Firm" dot.
- Mock: `docs/design/colors-ideas.png` (this is now v2).

## Other ways to mix (pick one or two)
1. **Meaning colors.** Streak honey, rest day lavender, shields-on sage, PC-connected blue, warning terracotta. Same color always means the same thing.
2. **Workspace colors.** Each PC workspace gets its own color (Study blue, Code caramel, Write rose). The user can change it.
3. **Time-of-day tint.** Morning peach, midday cream, evening sand. Very subtle. Check it does not hurt contrast.
4. **Pick your own accent (Plus).** The user chooses one accent for the whole app. Good for the paid themes idea.
5. **Milestone colors.** Each milestone badge uses a different color so the collection looks varied.

## Rules to keep it from turning messy
- Max 4 accent families. Everything else is cream and brown.
- One accent per screen for the big things (ring, main button). Small icons may use meaning colors.
- Every colored cue has an icon or a word too.
- Measure contrast for every button text and every colored label before building. Dark brown text on these pastel fills should pass; thin colored text on cream may not.
- Keep the clock ring a single color per session so the timer stays calm.

## Sources
- https://www.windmill.dev/brand-guidelines/visual_identity/color_system
- https://atlassian.design/foundations/color-new/accents
- https://blakecrosley.com/guides/design/headspace
- https://uxpin.com/studio/blog/color-schemes-for-apps
- https://brandmanual.atlascopco.com/rules-for-digital/app-guidelines/colors
