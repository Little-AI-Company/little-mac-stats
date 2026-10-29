# Brand assets

Little Mac Stats is part of the little family with [Little Worker](https://thelittleworker.com) and [Little CI](https://github.com/ParkerRex/little-ci). Its character is the meter: a rounded white head with three meter bars on top (short, tall, medium), wearing the family's black ribbed turtleneck. The bars continue the original Mac Stats mark.

Art was first generated with Codex CLI image generation on October 20, 2026, and redrawn on October 29, 2026 the same way on the M4, with Lou's character sheet and the first version's icon and banner attached as references. Every file with words keeps the first version's wordmark and tagline pixels; a script puts the new character on the same lavender circle (or in the old mark's box), and makes the rounded icons, crops and sizes. Nothing was retouched by hand. No third-party logo is used.

## Style

Redrawn on October 29, 2026 in the style of Little Worker's new character cast (Lou's character sheet), same concept and colours:

- Clean dark line art (about #111), medium-heavy, round ends. Soft flat colour with one gentle shade. No gloss, glow or texture.
- A big head: the meter block is about as tall as the body. Glossy oval eyes with a white highlight, soft blush, a calm smile at rest and an open smile in the full-body poses.
- The family's black ribbed turtleneck, white gloves, white sneakers, and a thin Paper edge round the figure.
- Accent: soft lavender circle, about `#E6E0F3` (deep lavender `#3A3450` on the dark icon). Little CI uses mint, Little Logbook peach, Little Limits butter.
- Background: Paper, about `#FBFAF7`.
- Wordmark: lowercase "little mac stats" in a rounded type, unchanged from the first version.
- Tagline: "Know what is using your Mac."

The first version (October 20, 2026: flat black-and-white ink, dot eyes) is in git history, and `branding/explorations/` keeps its concepts.

## Files

In use by the repository:

| File | Size | Use |
| --- | --- | --- |
| `banner.png` | 1536x768 | README banner |
| `icon-macos.png` | 1024x1024 | Rounded macOS icon on a transparent canvas; source for `Resources/AppIcon.icns` |
| `icon-macos-small.png` | 1024x1024 | Head-only art filling the rounded square, for icon renditions of 32 pixels or fewer |

`branding/masters/` holds the full-quality originals. Start any new size or crop from these.

| File | Size | Content |
| --- | --- | --- |
| `icon.png` | 1024x1024 | Square app icon, edge to edge |
| `icon-small.png` | 1024x1024 | Head-only icon for small sizes |
| `icon-dark.png` | 1024x1024 | Dark icon variant |
| `avatar.png` | 1024x1024 | Profile picture; safe for a circular crop |
| `banner.png` | 1536x768 | Wordmark, tagline, and walking character |
| `social-card.png` | 1536x1024 | Wordmark, tagline, "A free menu bar app for macOS.", and waving character; content sits in the middle 1536x800 band |
| `wordmark.png` | 1536x1024 | Head mark and wordmark |
| `walk.png`, `wave.png` | 1024x1024 | Full-body poses on the lavender circle, used by the banner and social card |
| `mark.png` | 1024x1024 | Head only, no circle, used by the wordmark |
| `icon-small-tight.png` | 1024x1024 | `icon-small.png` cropped so the head fills the square on flat lavender |

`branding/exports/` holds ready-to-upload sizes made from the masters.

| File | Size | Use |
| --- | --- | --- |
| `app-icon/icon-{16,32,64,128,256,512,1024}.png` | as named | Rounded macOS icon; 16 and 32 use the head-only art |
| `app-icon/icon-dark-1024.png` | 1024x1024 | Rounded dark variant |
| `social/github-social-preview-1280x640.png` | 1280x640 | GitHub repository social preview (Settings > General) |
| `social/open-graph-1200x630.png` | 1200x630 | Open Graph and link-sharing card |
| `social/x-header-1500x500.png` | 1500x500 | X profile header |
| `avatar/avatar-{400,800}.png` | as named | Profile pictures |
| `web/favicon-{32,64}.png` | as named | Website favicon, head-only art |
| `web/apple-touch-icon-180.png` | 180x180 | Website home screen icon; iOS rounds the corners |
| `wordmark/wordmark.png` | 1297x300 | Wordmark trimmed with an even cream margin |

`branding/explorations/concepts/` keeps the four characters considered: chip, meter (chosen), fan, and stopwatch.

Regenerate the app icon after changing `icon-macos.png` or `icon-macos-small.png`:

```sh
scripts/create_app_icon.sh
```

## Prompts

### October 29, 2026 redraw

Sent to `codex exec` on stdin with `ref-style-lou.png` (Little Worker's Lou character sheet), `ref-old-icon.png` (`branding/masters/icon.png` before the redraw) and `ref-old-banner.png` (`banner.png` before the redraw) attached with `-i`:

```text
Use the built-in image generation tool (image_gen) to make SIX new images, one tool call per image. Before drawing, open and look at every attached reference with view_image: `ref-style-lou.png`, `ref-old-icon.png`, `ref-old-banner.png`.

## What this is

The Little AI Company has a family of small products. Each has a mascot: a little character whose head is an everyday object, wearing the family's black ribbed turtleneck. Until today they were drawn in flat black-and-white ink (see `ref-old-icon.png` and `ref-old-banner.png`). The company's main cast has just been redrawn in a new illustrated style (see `ref-style-lou.png`, the character sheet for Lou, whose head is a TV). Redraw THIS product's mascot in the new style. Same concept, same object head, same accent colour, same black turtleneck body: only the drawing style changes.

## The new style (match `ref-style-lou.png` exactly)

- Clean, confident dark line art (about #111), medium-heavy, round line ends. Not thick marker ink.
- Soft flat colour fills with at most one gentle soft shade (a light cel shadow on the side of the head and under the chin). No gradients beyond that, no glossy 3D, no texture, no glow.
- Cute proportions with a BIG head: the object head is about as tall as the whole body below it, like Lou. Short body, short legs.
- The face is expressive in the same way as Lou's face: two tall glossy black oval eyes with a small white highlight, small soft blush marks, and a friendly smile (open with a little pink tongue for happy poses, closed calm smile at rest).
- Body: black ribbed turtleneck sweater (#1A1A1A with soft dark grey shading), plain white cartoon gloves (puffy, like Lou's hands), simple white sneakers with a dark outline when the feet show.
- A thin line of cream Paper (#FBFAF7) runs round the whole figure, just outside its dark outline.
- Background: warm cream Paper #FBFAF7. One flat soft accent circle behind the character in this product's colour (below). No other shapes.
- Lots of empty space. No sparkles, no stars, no confetti, no motion lines, no props, no text, no letters, no logos, no Apple logo.

## This product: Little Mac Stats

Little Mac Stats is a menu bar app that shows what is using your Mac. Its mascot (see the old drawings) is the meter:
- Head: a rounded white square block (#FFF9F0, soft cream shade #E9E3D8 on one side), the face on the front.
- On top of the head: three solid dark (#1A1A1A) vertical meter bars standing up like a crown, left bar short, middle bar tall, right bar medium, clearly separated, with rounded tops. Keep the three bars: they are the brand detail.
- Accent circle colour: soft lavender #E6E0F3. Muted deep lavender for the dark icon: #3A3450.

## Outputs (save exactly these file names in the current folder, PNG)

Draw the same character in all six, on model with each other. After generating each one, copy it from ~/.codex/generated_images/ into this folder with the exact name.

1. `icon.png`, square 1024x1024: the app icon. Head and shoulders (the object head plus the turtleneck collar and shoulders, cut by the bottom edge) centered on the accent circle, calm closed smile, facing the viewer. Same framing as `ref-old-icon.png`: the head fills about 60 percent of the width. Edge-to-edge square, no rounded corners, no text. The head's brand details (listed above) must stay readable at 64x64.
2. `icon-small.png`, square 1024x1024: for 16 to 32 pixels. Only the head (no body), filling about 70 percent of the square, on the accent circle over Paper. Thicker lines, bigger eyes, fewer details; keep only the brand details listed above.
3. `icon-dark.png`, square 1024x1024: the same drawing as `icon.png` on a warm dark field #2B2A28 with a muted deep version of the accent circle (given above). The head keeps its light colours. The black turtleneck keeps its thin Paper edge so it separates from the dark field.
4. `walk.png`, square 1024x1024: full body, walking cheerfully to the right in three-quarter view, one arm swinging forward, happy open smile, on the accent circle (the circle about 80 percent of the square, the figure inside it with its feet near the circle's bottom). Whole figure visible with margin all round. Paper background.
5. `wave.png`, square 1024x1024: full body, standing facing the viewer, waving hello with the right hand raised, happy open smile, on the accent circle. Whole figure visible with margin all round. Paper background.
6. `mark.png`, square 1024x1024: only the head (no body, no circle) facing the viewer, calm smile, centered on plain Paper #FBFAF7, filling about 75 percent of the square. This is the small logo mark that sits beside the product name.

After saving all six, view each file to check it exists, has no text or stray shapes, and matches the others. Reply with the six paths and their pixel sizes.
```

### First version, October 20, 2026

Shared style and character description given to Codex for every final asset:

```text
## The chosen design (match it exactly)

The first two attached images are the approved concept: the "meter" character. Keep the same character in every output:
- Head: a rounded white square block with a friendly face (two dot eyes, a small smile).
- On top of the head: three black vertical meter bars standing up like a crown. Left bar short, middle bar tall, right bar medium. The bars are the brand mark; keep them bold and clearly separated.
- Body: black turtleneck sweater with a ribbed collar. White simple sneakers in full-body poses.
- Accent: one soft lavender pastel circle (#E6E0F3 range) behind the character.
- Background: warm cream (#F9F7F2).
- Thick confident black outlines, flat fills, no gradients, no shading, no glow, no 3D, no extra colors.
- No Apple logo, no real product shapes, no third-party logos.

The other attached images are sibling products, for family style only.

Text, where requested, uses the same rounded friendly lowercase font as the approved banner. Spell all text exactly.
```

Final icon outputs:

```text
## Outputs (save exactly these paths, PNG, each square 1024x1024)

1. `icon.png`: the final app icon. Head-and-shoulders portrait centered on the lavender circle over cream, same framing as the approved icon. Edge-to-edge square, no rounded corners, no text. Clean up any wobbly lines; the bars and face must stay readable at 32x32.
2. `icon-dark.png`: dark exploration of the same icon. Near-black background (#1C1B1A), a muted deep lavender circle (#3A3450 range), the head still white with black outlines, and the turtleneck outlined in white so it separates from the background. No text.
3. `icon-small.png`: small-size exploration for 16x16 to 64x64. Only the head and bars, no body, filling about 70 percent of the square, on the lavender circle over cream. Thicker outlines, bigger eyes, fewer details. No text.
4. `avatar.png`: social profile picture. Head and turtleneck collar centered inside a full-bleed lavender circle that touches all four edges of the square; corners cream. Designed to survive a circular crop. No text.

After saving, view each file to confirm it exists and matches the chosen design, then reply with the four paths and their pixel sizes.
```

Final banner and social outputs:

```text
## Outputs (save exactly these paths, PNG)

1. `banner.png`: final README banner, landscape 1536x768. Cream background. Right side: the full-body character walking cheerfully, arms swinging, on the lavender circle. Left side: the wordmark "little mac stats" with the tagline below it: "Know what is using your Mac." Generous empty space, nothing else. Same layout as the approved banner, with cleaner lines.
2. `social-card.png`: social sharing card, landscape 1536x1024 (it will be cropped to 1200x630 and 1280x640 around the center, so keep all text and the character inside the middle 1536x800 band). Cream background. Left: the wordmark "little mac stats", then the tagline "Know what is using your Mac.", then a smaller third line "A free menu bar app for macOS." Right: the full-body character waving, on the lavender circle.
3. `wordmark.png`: the wordmark "little mac stats" alone, black on cream, landscape 1536x1024, centered with even margins. Then a small version of the head with bars placed just left of the text, the same height as the lowercase letters plus the bars. Nothing else.

After saving, view each file to confirm the text spelling and that it exists, then reply with the three paths and their pixel sizes.
```
