# Brand assets

Little Mac Stats is part of the little family with [Little Worker](https://thelittleworker.com) and [Little Limits](https://github.com/Little-AI-Company/little-limits). Its character is **Chip**, the Stats Keeper: a golden-apricot hamster in the family's black hoodie, with a lavender badge of three meter bars (short, tall, medium) on his chest. The bars carry on the original Mac Stats mark. Chip is watchful, tidy, quick and cheerful; he keeps an eye on what is spinning your Mac's wheels.

On November 2, 2026 Chip replaced the meter-head character so the app's art matches Little Worker's illustrated cast ([thelittleworker.com/brand](https://thelittleworker.com/brand)). Parker picked him from three concepts, kept in `branding/explorations/cast-style/`: Chip, the meter head redrawn in the cast style, and a gauge head. The art was generated with Codex CLI image generation on the M4, with Lou's and Milo's character sheets, Little Worker's Mac icon and the chosen concept attached as references. The words, the rounded icon tiles, the crops and every size were then made by a script with Pillow; nothing was retouched by hand. No third-party logo is used.

## Style

Little Worker's cast style ([Brand: How to draw them](https://thelittleworker.com/brand)):

- Clean dark line art (about #111), medium-heavy, round ends. Soft colour with a gentle painterly shade, as in Little Worker's Mac icon. No gloss, glow or texture.
- A big head. Glossy oval eyes with a white highlight, soft blush, a calm closed smile at rest and an open smile when waving.
- The family's black hoodie with drawstrings, white gloves, white sneakers, and a thin Paper edge round the figure.
- Chip's colours: fur `#E9A15A`, cream `#FBEBD3`, hoodie `#1A1A1A`, badge `#C9BDF0`.
- Accent: soft lavender circle, `#E6E0F3` (deep lavender `#3A3450` on the dark icon). Little Logbook uses peach, Little Limits butter.
- Background: Paper, `#FBFAF7`. Ink `#0B0B0B` and Ink gray `#373737` for words.
- Wordmark: "little" over "mac stats" in Single Day, set tight, as Little Worker's own wordmark.
- Words in pictures: SF Pro, semibold for the tagline "Know what is using your Mac.", regular Ink gray for "A free menu bar app for macOS."

`branding/masters/chip-character-sheet.png` is the model for Chip: his turnaround, colours, expressions and poses. Draw anything new of him from it, never from memory.

## Files

In use by the repository:

| File | Size | Use |
| --- | --- | --- |
| `banner.png` | 1536x768 | README banner |
| `icon-macos.png` | 1024x1024 | Rounded macOS icon on a transparent canvas; source for `Resources/AppIcon.icns` |
| `icon-macos-small.png` | 1024x1024 | Head-only rounded icon, for icon renditions of 32 pixels or fewer |
| `../Resources/LoadingIllustration.png` | 480x480 | Chip running in his wheel on a transparent ground; the process list shows it while the first app sample is measured |

`branding/masters/` holds the full-quality originals. Start any new size or crop from these.

| File | Size | Content |
| --- | --- | --- |
| `chip-character-sheet.png` | 1536x1024 | Chip's character sheet |
| `icon.png` | 1024x1024 | Square app icon, edge to edge; also the avatar |
| `icon-small.png` | 1024x1024 | Head-only icon for small sizes |
| `icon-dark.png` | 1024x1024 | Dark icon variant on warm charcoal `#33302B` |
| `wave.png` | 1024x1024 | Full-body wave on the lavender circle, used by the banner and social cards |
| `loading.png` | 1024x1024 | Chip running in his wheel, transparent ground |

`branding/exports/` holds ready-to-upload sizes made from the masters.

| File | Size | Use |
| --- | --- | --- |
| `app-icon/icon-{16,32,64,128,256,512,1024}.png` | as named | Rounded macOS icon; 16 and 32 use the head-only art |
| `app-icon/icon-dark-1024.png` | 1024x1024 | Rounded dark variant |
| `social/github-social-preview-1280x640.png` | 1280x640 | GitHub repository social preview (Settings > General > Social preview) |
| `social/open-graph-1200x630.png` | 1200x630 | Open Graph and link-sharing card |
| `social/x-header-1500x500.png` | 1500x500 | X profile header |
| `avatar/avatar-{400,800}.png` | as named | Profile pictures; safe for a circular crop |
| `web/favicon-{32,64}.png` | as named | Website favicon, head-only art |
| `web/apple-touch-icon-180.png` | 180x180 | Website home screen icon; iOS rounds the corners |
| `wordmark/wordmark.png` | as made | Wordmark on Paper with an even margin |

`branding/explorations/` keeps earlier work: `cast-style/` holds the November 2026 concepts, `concepts/` the first version's four characters (chip, meter, fan and stopwatch), and `icon-dark.png` the first dark icon. The meter-head art of October 2026 is in git history.

Regenerate the app icon after changing `icon-macos.png` or `icon-macos-small.png`:

```sh
scripts/create_app_icon.sh
```

## Prompts

### November 2, 2026: Chip

Concepts, sent to `codex exec` on stdin with Lou's character sheet, Milo's character sheet, Little Worker's Mac icon and the old meter icon attached with `-i`:

```text
Use the built-in image generation tool (image_gen) to make THREE new images, one tool call per image. Before drawing, open and look at every attached reference with view_image: `refs/ref-style-lou-sheet.png`, `refs/ref-style-milo-sheet.png`, `refs/ref-lw-mac-icon.png`, `refs/ref-old-macstats-icon.png`.

## What this is

The Little AI Company makes small products. Its main product, Little Worker, has an illustrated cast (Lou the TV, Milo the puppy, and friends: see the two character sheets and the Mac app icon). A sibling product, Little Mac Stats, is a tiny macOS menu bar app that shows which apps are using your Mac's CPU. Its old mascot (`ref-old-macstats-icon.png`) is a flat white block with three black meter bars on top, in a black turtleneck. It does not look like it belongs to the Little Worker cast. We want a NEW mascot for Little Mac Stats that could stand in the Little Worker cast photo next to Lou and Milo.

## The style (match the Little Worker references exactly)

- Clean, confident dark line art (about #111), medium-heavy, round line ends.
- Soft colour fills with the gentle soft painterly shading of `ref-lw-mac-icon.png` (light warm shade on the side of the head and under the chin). No gloss, no glow, no 3D render look, no hard texture.
- Cute proportions with a BIG head, like Lou and Milo.
- Faces like the cast: tall glossy black oval eyes with a small white highlight, small soft blush, a calm friendly closed smile.
- The family outfit: a black hoodie with drawstrings (like Lou in `ref-lw-mac-icon.png`), white puffy cartoon gloves when hands show.
- A thin line of cream Paper (#FBFAF7) runs round the whole figure, just outside its dark outline.
- Product accent colour: soft lavender, about #E6E0F3.

## The three concepts

Each image: square 1024x1024, a head-and-shoulders bust like `ref-lw-mac-icon.png` (head turned a little, chest cut by the bottom edge), on a flat soft lavender #E6E0F3 circle over warm cream Paper #FBFAF7. No text, letters, numbers, logos or Apple logo anywhere. No sparkles or extra props.

1. `concepts/concept-a-hamster.png`: **Chip, a hamster.** A round golden-apricot and cream hamster (big round cheeks, small round ears with pink insides, tiny pink nose, cream muzzle and chest) in the black hoodie. On the hoodie's chest, a small lavender patch embroidered with three little vertical meter bars (short, tall, medium) in dark ink: the old mascot's brand mark. The idea: the little hamster that keeps an eye on what is spinning your Mac's wheels.
2. `concepts/concept-b-meter.png`: **The meter, redrawn.** The old mascot's rounded cream block head (#FFF9F0 with a soft warm shade) and its three dark meter bars on top like a crown (left short, middle tall, right medium, rounded tops), but now truly in the cast style: the soft shaded rendering, the head turned a little, the black hoodie with drawstrings instead of the turtleneck.
3. `concepts/concept-c-gauge.png`: **Dial, a little gauge.** The head is a round cream analogue gauge in a dark rounded bezel, the face drawn on the dial, with a short dark needle pointing up and to the right above the eyes like a single antenna-like tuft, three tiny tick marks along the top of the rim. Black hoodie.

After generating each one, copy it from ~/.codex/generated_images/ into the exact path above. Then view each saved file to check it exists, has no text, and matches the style. Reply with the three paths and pixel sizes.
```

Final art, sent the same way with the chosen concept, Lou's and Milo's sheets and Little Worker's Mac icon attached:

```text
Use the built-in image generation tool (image_gen) to make SIX new images, one tool call per image. Before drawing, open and look at every attached reference with view_image: `concepts/concept-a-hamster.png` (THE APPROVED CHARACTER), `refs/ref-style-lou-sheet.png`, `refs/ref-style-milo-sheet.png`, `refs/ref-lw-mac-icon.png`.

## What this is

Little Mac Stats is a tiny macOS menu bar app that shows which apps are using your Mac's CPU. Its new mascot is **Chip**, the hamster in `concepts/concept-a-hamster.png`. Chip joins the Little Worker cast (Lou the TV, Milo the puppy: see the two character sheets), so every drawing must look like it came from the same illustrator as those sheets and `ref-lw-mac-icon.png`.

## Chip (stay exactly on model with `concepts/concept-a-hamster.png`)

- A round golden-apricot (#E9A15A) and cream (#FBEBD3) hamster with a big round head, chubby cheeks, small round ears with pink insides, a tiny pink nose, a cream muzzle and a tuft of fur on top.
- Tall glossy black oval eyes with a small white highlight, soft pink blush, calm closed smile at rest, small open smile with a little pink tongue when happy.
- Black hoodie with drawstrings (#1A1A1A with soft dark grey shading). On the left chest, a small rounded lavender (#C9BDF0) patch with three little dark vertical bars (short, tall, medium): Chip's badge. White puffy cartoon gloves for hands, like Lou's. Simple white sneakers with a dark outline when the feet show. A short stubby pink-cream tail is not visible from the front.
- Personality: watchful, tidy, quick, cheerful. Chip keeps an eye on what is spinning your Mac's wheels.

## The style (match the references exactly)

- Clean, confident dark line art (about #111), medium-heavy, round line ends.
- Soft colour fills with the gentle soft painterly shading of `ref-lw-mac-icon.png`. No gloss, no glow, no 3D render look, no hard texture.
- A thin line of cream Paper (#FBFAF7) runs round the whole figure, just outside its dark outline.
- Product accent colour: soft lavender #E6E0F3 (muted deep lavender #3A3450 on dark).
- Lots of empty space. No sparkles, no stars, no confetti, no motion lines unless asked, no text, no letters, no numbers, no logos, no Apple logo (except the character sheet, below).

## Outputs (save exactly these file names in the folder `final/`, PNG)

1. `final/chip-character-sheet.png`, landscape 1536x1024: a character sheet laid out like `ref-style-lou-sheet.png`, on cream Paper. Top left: the name "Chip" large, under it "The Stats Keeper", then two short lines: "Watchful, tidy and quick. Chip keeps an eye on what is spinning your Mac's wheels." and four small rounded tags: "Watchful", "Tidy", "Quick", "Cheerful". A hero image of Chip waving on a soft lavender circle. A "Model Sheet" row: front, 3/4, side, back full-body turnaround. A "Colors & Details" block with swatches labelled Fur #E9A15A, Cream #FBEBD3, Hoodie #1A1A1A, Outline #111111, Badge #C9BDF0, Accent #E6E0F3, and close-ups of the badge, a glove and an ear. An "Expressions" row: Neutral, Happy, Curious, Focused, Surprised, Sleepy. A "Pose Library" row: Idle, Watching a chart, Running in a wheel, Waving, Celebrating, Napping. Spell every word exactly as given; keep the text short and in a clean rounded sans-serif like the reference.
2. `final/icon.png`, square 1024x1024: the app icon. Chip from the chest up, head turned a little, exactly like `concepts/concept-a-hamster.png`, calm closed smile, on a flat soft lavender #E6E0F3 circle over a flat warm cream Paper #FBFAF7 field. Same framing as `ref-lw-mac-icon.png`: the head is about 60 percent of the width, ears near the top, the hoodie cut by the bottom edge, badge visible. Edge-to-edge square, no rounded corners, no border, no text. Ears, eyes and cheeks must stay readable at 64x64.
3. `final/icon-dark.png`, square 1024x1024: the same drawing as `icon.png` on a flat warm charcoal field #33302B with a muted deep lavender #3A3450 circle. Chip keeps his light colours; the black hoodie keeps its thin Paper edge so it stands apart from the dark field.
4. `final/icon-small.png`, square 1024x1024: for 16 to 32 pixels. Only Chip's head (ears, face, cheeks; no body), facing the viewer, filling about 78 percent of the square, on the lavender circle over Paper. Thicker lines, bigger eyes, fewer fur details.
5. `final/wave.png`, square 1024x1024: full body, standing facing the viewer, waving hello with his right glove raised, happy open smile, on the lavender circle (circle about 80 percent of the square, feet near its bottom). Whole figure visible with margin all round. Paper background outside the circle.
6. `final/loading.png`, square 1024x1024, TRANSPARENT background (ask image_gen for a genuinely transparent background and keep the alpha): Chip running happily inside a small hamster wheel, side three-quarter view, mid-stride, focused happy face. The wheel is a simple round wheel with dark ink rim, cream spokes and a small stand, in the same line style. No circle behind, no ground, no shadow blob, just the figure and wheel with the thin Paper edge round the outside, centered with margin all round.

After generating each one, copy it from ~/.codex/generated_images/ into the exact path above. Then view each saved file to check it exists, matches the approved Chip, and has no stray text (only the character sheet has text, spelled as given). If an image is off model or misspelled, generate it again. Reply with the six paths and their pixel sizes, and say whether `loading.png` kept a transparent background.
```

### October 29, 2026: meter head redraw (replaced)

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

### First version, October 20, 2026 (replaced)

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
