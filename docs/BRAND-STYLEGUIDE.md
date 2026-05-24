# Personal Brand Style Guide
*For AI tools, designers, and collaborators*

---

## About This Brand

This style guide defines the complete visual and communication identity for **[Your Name]**, an IT professional active as a conference speaker, teacher, consultant, and online content creator. The primary domain is Microsoft Azure, GitHub, DevOps, and developer tooling.

**Core audience:** The tech community — developers, architects, DevOps engineers — and potential clients looking to book speaking, teaching, or consulting engagements.

**Brand personality:** Professional but warm. Simple but distinctive. Technically credible without being cold.

---

## Brand Voice

| Trait | What it means in practice |
|---|---|
| **Expert, not arrogant** | Share knowledge confidently without talking down. Assume your audience is smart. |
| **Warm and direct** | Be human first. Skip the corporate formality. Contractions are fine. |
| **Concrete over abstract** | Always anchor with examples, code, or real-world scenarios. |
| **Opinionated but fair** | Have a point of view. Acknowledge trade-offs. Don't hedge everything. |
| **Slightly dry humor** | Light wit is welcome. Forced enthusiasm is not. |

### Writing Dos and Don'ts

✅ DO: "Here's what actually works in production."
❌ DON'T: "In this comprehensive guide, we will explore..."

✅ DO: "Most teams overcomplicate this."
❌ DON'T: "There are many approaches to consider."

✅ DO: "Use managed identity — stop putting secrets in config."
❌ DON'T: "Managed identity can be a good option to potentially consider."

---

## Color System

### Accent Colors (constant across light and dark mode)

| Token | Hex | Usage |
|---|---|---|
| `--iris` | `#7C63A8` | **Primary brand color.** CTAs, headings, keywords in code, primary buttons. |
| `--iris-soft` | `#A688D4` | Hover states, highlights, code: constants/numbers. |
| `--iris-deep` | `#5C4888` | Pressed states, active elements. |
| `--teal` | `#3AAFA9` | **Secondary accent.** Secondary CTAs, functions in code, tags, icons. |
| `--teal-soft` | `#60CECA` | Teal highlights, decorators in code. |
| `--teal-deep` | `#2A8A85` | Active teal states. |
| `--amber` | `#C47F55` | **Warmth accent. Use sparingly.** Strings in code, warning states, third-level tags. |

### Light Mode Surfaces

| Token | Hex | Usage |
|---|---|---|
| `--bg` | `#F5EFE6` | Page / slide background. Warm parchment, never cold white. |
| `--surface` | `#EDE6D9` | Cards, panels, elevated surfaces. |
| `--surface-2` | `#E3DACB` | Secondary surfaces, code block headers. |
| `--border` | `#CEC6B8` | All borders and dividers. |
| `--text-1` | `#2A2420` | Primary text. Warm near-black. |
| `--text-2` | `#6E6560` | Body text, descriptions. |
| `--text-3` | `#A8A098` | Captions, metadata, placeholders. |
| `--code-bg` | `#EDE8DF` | Inline code background (light mode). |

### Dark Mode Surfaces

| Token | Hex | Usage |
|---|---|---|
| `--bg` | `#1A1714` | Page / slide / editor background. Warm obsidian, never cold grey. |
| `--surface` | `#231F1B` | Cards, panels, elevated surfaces. |
| `--surface-2` | `#2D2924` | Secondary surfaces, code block headers. |
| `--border` | `#3D3830` | All borders and dividers. |
| `--text-1` | `#F0E8DC` | Primary text. Warm cream. |
| `--text-2` | `#9A9088` | Body text, descriptions. |
| `--text-3` | `#6A6258` | Captions, metadata, placeholders. |

### Dark/Light Mode Strategy

- **Accent colors never change.** `--iris`, `--teal`, and `--amber` are the same hex in both modes.
- **Only the surface neutrals shift.** Parchment (`#F5EFE6`) becomes obsidian (`#1A1714`). The neutrals invert; the accents don't.
- **This is what creates recognition.** Someone sees the same purple-teal-amber combination whether they're on your light website or your dark VSCode theme.
- **The warm-dark rule:** Dark backgrounds must use warm browns (`#1A1714`), not cool greys (`#1E1E1E`). This is what makes the brand feel warm even in dark mode.

---

## Typography

### Font Stack

| Font | Weight(s) | Role |
|---|---|---|
| **Sora** | 700, 800 | Display headings, slide titles, hero text, social post titles |
| **DM Sans** | 300, 400, 500, 600 | Body text, UI labels, descriptions, captions |
| **JetBrains Mono** | 400, 500 | Code, eyebrow labels, tags, metadata, version numbers |

**Google Fonts import:**
```
https://fonts.googleapis.com/css2?family=Sora:wght@300;400;500;600;700;800&family=DM+Sans:ital,opsz,wght@0,9..40,300;0,9..40,400;0,9..40,500;0,9..40,600;1,9..40,400&family=JetBrains+Mono:ital,wght@0,400;0,500;1,400&display=swap
```

**System fallbacks:** `'Sora', system-ui, sans-serif` / `'JetBrains Mono', 'Courier New', monospace`

### Type Scale

| Level | Font | Size | Weight | Usage |
|---|---|---|---|---|
| Display XL | Sora | 3.5rem / 56pt | 800 | Hero text, opening slide title |
| Display LG | Sora | 2rem / 32pt | 700 | Section headers, slide titles |
| Display MD | Sora | 1.4rem / 22pt | 600 | Subheadings, card titles |
| Body LG | DM Sans | 1.05rem / 17pt | 400 | Lead paragraphs, talk descriptions |
| Body MD | DM Sans | 0.95rem / 15pt | 400 | Standard body copy |
| Body SM | DM Sans | 0.82rem / 13pt | 400 | Captions, metadata |
| Label | JetBrains Mono | 0.72rem / 11pt | 400 | Eyebrows, tags, ALL CAPS + tracking |
| Code | JetBrains Mono | 0.82–0.9rem | 400 | All code snippets |

### Typography Rules

- **Headings:** Sentence case only. Not Title Case. Not ALL CAPS (except eyebrow labels).
- **Eyebrow labels:** JetBrains Mono, uppercase, letter-spacing 0.12–0.18em, iris or teal color.
- **Letter spacing:** Headings use `−0.02em` to `−0.025em`. Labels use `+0.12em` to `+0.18em`. Body text: 0.
- **Line height:** Headings 1.05–1.15. Body 1.65–1.7. Code 1.6–1.7.
- **Max content width:** 65ch for body text. Prevents lines from becoming too long.

---

## Code Syntax Highlighting

Use these color mappings for any syntax highlighting — VSCode themes, blog posts, social media, slide code blocks. Dark mode and light mode use different values to ensure readability in both contexts.

| Scope | Dark mode | Light mode |
|---|---|---|
| Keywords (`var`, `class`, `await`, `if`) | `#9F84C7` | `#5C4888` |
| Types and class names (italic) | `#A688D4` | `#6B5497` |
| Functions and methods | `#3AAFA9` | `#1C7570` |
| Function parameters (italic) | `#3AAFA9` | `#1C7570` |
| Strings | `#C47F55` | `#8F5522` |
| Numbers and constants | `#A688D4` | `#6B5497` |
| Comments (italic) | `#7A7268` | `#80786F` |
| Operators and punctuation | `#9A9088` | `#A8A098` |
| Regular variables | `#F0E8DC` | `#2A2420` |
| Decorators / annotations | `#60CECA` | `#1C7570` |
| Error / invalid | `#E06C75` | `#B03A48` |

**The rule behind this:** The hue stays the same in both modes — purple for keywords, teal for functions, amber for strings. Only the lightness shifts, because the same hex that reads clearly on obsidian becomes too faint on parchment.

**Terminal colors follow the same logic:** green = teal, blue = iris, yellow = amber.

---

## Component Rules

### Buttons

| Variant | Background | Text | Use when |
|---|---|---|---|
| Primary | `--iris` | white | Main CTA: book, contact, watch |
| Secondary | transparent + iris border | iris | Secondary action |
| Teal | `--teal` | white | Social / content link |
| Ghost | `--surface` + border | text-2 | Tertiary, low-emphasis |

- Border radius: `8px`
- Font: DM Sans 500
- Size: `0.85rem` to `0.9rem`
- Padding: `0.55rem 1.3rem`
- Hover: primary darkens to `--iris-deep`, secondary fills to solid iris

### Tags and Badges

- Font: JetBrains Mono, `0.7–0.75rem`
- Border radius: `999px` (always pill shape)
- Style: 15% opacity background of the accent color + matching border + matching text
- Three tag colors: iris, teal, amber
- Letter spacing: `0.05em`

**When to use each tag color:**
- **Iris:** Technology topics (Azure, .NET, C#, Infrastructure)
- **Teal:** Tools and platforms (GitHub, DevOps, Docker, Kubernetes)
- **Amber:** Content format or context (Workshop, Keynote, Tutorial, Tip)

### Cards

- Background: `--surface`
- Border: `1px solid --border`
- Border radius: `16px`
- Padding: `1.5–1.75rem`
- Shadow (subtle): `0 4px 20px rgba(0,0,0,0.06)`
- Hover: border shifts to `--iris` + `box-shadow: 0 0 0 3px rgba(124,99,168,0.12)`
- Card eyebrow: JetBrains Mono, `0.68rem`, teal, uppercase, spaced

### Code Blocks

- Background: `--code-bg` (light) / `--coal` (dark)
- Border: `1px solid --border`
- Border radius: `12px`
- Font: JetBrains Mono 400, `0.82rem`, line-height `1.7`
- Header bar: `--surface-2`, with window dots (red `#E06C75`, yellow `#C47F55`, green `#3AAFA9`) and right-aligned filename in text-3

### Spacing Scale

| Name | Value | Use for |
|---|---|---|
| xs | 4px | Gaps between tags, icon+text |
| sm | 8px | Within components |
| md | 16px | Between related elements |
| lg | 24px | Between sections within a card |
| xl | 40px | Between major sections |
| 2xl | 64px | Page-level vertical rhythm |

### Border Radius Scale

| Name | Value | Use for |
|---|---|---|
| sm | `4px` | Tags (minimum), inline elements |
| md | `8px` | Buttons, inputs, small chips |
| lg | `12px` | Code blocks |
| xl | `16px` | Cards, panels |
| pill | `999px` | Tags, badges, toggles |

---

## Presentation Rules (PowerPoint / Keynote)

### Slide Layouts

**Slide types in the template:**
1. **Title slide** — Dark (obsidian) background. Large Sora headline. Iris left accent bar.
2. **Section divider** — Dark. Iris left slab with section number. Title on dark right.
3. **Content slide** — Light (parchment). Iris top bar 4px. Two-column: bullets left, stat card right.
4. **Code slide** — Dark. Large code block left with syntax highlighting. Annotation panel right.
5. **Quote slide** — Light. Georgia italic quote. Teal attribution line. Iris left bar.
6. **Agenda** — Light. Numbered card grid. Iris/teal/amber colors cycle through items.
7. **Thank you / End** — Dark. Obsidian. Contact details. Iris bottom strip.

### Slide Design Rules

- **Dark slides:** Title, section dividers, code demos, closing slide. The "sandwich" structure (dark open, light content, dark close) gives rhythm to any deck.
- **Light slides:** Content, agenda, quotes, frameworks. Use `#F5EFE6` parchment — never pure white.
- **Accent line per slide:** One iris OR one teal highlight per slide. Never both competing.
- **Code on slides:** Always use a dark card (`#231F1B`) even on a light slide. This makes code immediately identifiable and prevents contrast issues.
- **Font sizes:** Title 36–44pt, Section header 24–28pt, Body 14–16pt, Captions/metadata 10–12pt.
- **Margins:** Minimum 0.5 inches on all sides.
- **Never use underline accent lines under titles.** Use whitespace or background color difference instead.

### Speaker Notes Convention

Begin every slide's speaker notes with:
- **[TIME]** — approximate speaking time for this slide (e.g., `[2 min]`)
- **[KEY POINT]** — the one thing the audience must leave with
- **[TRANSITION]** — how to connect to the next slide

---

## Social Media Rules

### Instagram

**Three post types:**

1. **Code Tip (dark):** Dark obsidian background. Code block with brand syntax highlighting. Title + tags in bottom strip. Use for technical tips.
2. **Insight Card (light):** Parchment background. Iris left bar 5px. Sora bold headline. Short body in DM Sans. Handle bottom right.
3. **Quote Card:** Coal background. Large Georgia italic quote. Teal attribution line. Gradient top stripe.

**Always include:**
- At least 2 tags (one iris, one teal minimum)
- Your handle
- A clear single message — one insight, one tip, one quote

**Caption structure:**
```
[Hook — first line visible before "more"] 

[2–3 lines expanding the idea]

[Concrete example or result]

[CTA: "Save this", "What's your approach?", "Link in bio"]

#AzureDeveloper #DotNet #DevOps #GitHub #CloudNative #CSharp
```

### YouTube Thumbnails

**Two thumbnail types:**
1. **Tutorial (dark):** Dark background. Iris left slab. Large bold Sora title. Code snippet chip. Channel info bottom strip.
2. **Split/Opinion:** Light left / dark right split. Iris vertical divider. Title on light side. Code on dark side.

**Thumbnail rules:**
- Title must be legible at 120px width (thumbnail size on mobile)
- Max 6 words in the main headline — ideally 4–5
- Always include a code element (chip, snippet, or reference)
- Duration bottom right in JetBrains Mono

### LinkedIn

**Two assets:**
1. **Profile Banner (1584×396):** Dark obsidian. Iris+teal gradient left bar. Name in Sora 800 on left. Code snippet block on right half. Tag pills bottom left.
2. **Post/Article Card (1200×628):** Parchment. Iris 5px top bar. Large numbered headline. Short body text. Profile info + tags in bottom strip.

**LinkedIn content voice:** Slightly more professional than Instagram, but still direct and concrete. Lead with the result or insight, then explain. Use numbered lists in post text (e.g., "5 things that changed how I use Azure").

---

## VSCode Theme Reference

The VSCode theme file (`your-brand-dark-theme.json`) covers:

- Editor, gutter, line numbers
- Sidebar, activity bar, status bar
- Tabs, panels, terminal
- All syntax token colors (matching the table in the Code section above)
- Semantic token overrides for TypeScript/C#
- Git decoration colors
- Full terminal ANSI color set

**To install:** Copy to `~/.vscode/extensions/your-brand-theme/themes/` and add a `package.json` manifest, or use the VSCode extension generator (`yo code`).

---

## Prompting AI Tools with This Guide

When asking AI tools to generate content in this brand, include the relevant sections. Below are ready-to-use prompt prefixes.

### For visual design tasks:

```
Apply the following brand system to this design task:

COLORS:
- Primary: #7C63A8 (iris purple) — use for main CTAs, headings
- Secondary: #3AAFA9 (teal) — use for secondary elements, function highlights
- Accent: #C47F55 (amber) — use sparingly for warmth
- Light bg: #F5EFE6 (parchment) — warm cream, never pure white
- Dark bg: #1A1714 (obsidian) — warm dark, never cold grey
- Light text: #2A2420 | Dark text: #F0E8DC

FONTS:
- Headlines: Sora, weight 700–800, tight letter-spacing (−0.02em)
- Body: DM Sans, weight 400
- Code/labels: JetBrains Mono, uppercase labels with 0.14em letter-spacing

STYLE: Professional but warm. Clean, minimal, lots of whitespace. Not corporate.
```

### For copywriting tasks:

```
Write in this brand voice:
- Audience: developers, DevOps engineers, cloud architects
- Tone: expert but warm, direct, slightly dry humor OK
- Style: concrete over abstract, always anchor with examples
- Avoid: corporate jargon, excessive hedging, generic openers like "In this post..."
- Perspective: first person, confident opinions
- Topic domain: Microsoft Azure, GitHub, DevOps, .NET, developer tools
```

### For social media posts:

```
Create a [Instagram caption / LinkedIn post / YouTube description] in this voice:

Brand: IT professional — Azure speaker, teacher, consultant, content creator.
Tone: Expert and warm. Direct. Concrete. Light wit welcome.
Format: Hook in first line. 2–3 lines of value. Concrete example. CTA question or save prompt.
Tags to include (choose relevant): #AzureDeveloper #DotNet #DevOps #GitHub #CloudNative #CSharp #MicrosoftAzure #SoftwareEngineering

Topic: [your topic here]
```

### For slide content:

```
Create slide content for a conference talk. Format: [slide title] + 3–4 bullet points (not sentences, punchy fragments) + 1 speaker note.

Brand voice: Technical expert. Warm and direct. Concrete examples over abstract concepts.
Audience: Developers and architects familiar with cloud basics.
Topic: [your topic here]
```

---

## File Assets Reference

| File | Format | Use for |
|---|---|---|
| `brand-template.pptx` | PowerPoint | Conference talks, workshops, client presentations |
| `your-brand-dark-theme.json` | VSCode Theme JSON | Code editor, code screenshots |
| `social-templates.html` | HTML | Screenshot to export Instagram, YouTube, LinkedIn images |
| `brand-styleguide.html` | HTML | Interactive visual reference |
| `BRAND-STYLEGUIDE.md` | Markdown | AI tool prompting, designer handoff, this file |

---

## Quick Reference Card

```
BRAND ACCENT COLORS (constant in all contexts)
IRIS PURPLE    #7C63A8   Primary brand, CTAs, buttons, UI
IRIS SOFT      #A688D4   Hover states, highlights
TEAL           #3AAFA9   Secondary accent, tags, icons
AMBER          #C47F55   Warmth, use sparingly

SURFACES
PARCHMENT      #F5EFE6   Light background
OBSIDIAN       #1A1714   Dark background
INK            #2A2420   Light mode text
CREAM          #F0E8DC   Dark mode text

SYNTAX HIGHLIGHT COLORS (shift per mode for readability)
               Dark mode   Light mode
Keywords       #9F84C7  →  #5C4888
Types          #A688D4  →  #6B5497
Functions      #3AAFA9  →  #1C7570
Strings        #C47F55  →  #8F5522
Numbers        #A688D4  →  #6B5497
Comments       #7A7268  →  #80786F

FONTS
Sora           → Headings (700–800 weight)
DM Sans        → Body (400 weight)
JetBrains Mono → Code + labels

Radius: 4 / 8 / 12 / 16 / 999px
Spacing: 4 / 8 / 16 / 24 / 40 / 64px
```

---

*Last updated: 2026 · Brand v1.0*
