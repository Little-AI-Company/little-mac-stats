# Brand assets

Little Mac Stats is part of the little family with [Little Worker](https://thelittleworker.com) and [Little CI](https://github.com/ParkerRex/little-ci). Its character is the meter: a rounded white head with three meter bars on top (short, tall, medium), wearing the family's black ribbed turtleneck. The bars continue the original Mac Stats mark.

Art was generated with Codex CLI image generation on October 20, 2026, using Little Worker and Little CI artwork as style references, then resized, cropped, and masked with ImageMagick. No third-party logo is used.

## Style

- Thick black outlines, flat fills, black and white character. No gradients, shading, or glow.
- Accent: soft lavender circle, about `#E6E0F3`. Little CI uses mint and Little Worker uses peach.
- Background: warm cream, about `#F9F7F2`.
- Wordmark: lowercase "little mac stats" in a rounded type, matching the Little CI wordmark.
- Tagline: "Know what is using your Mac."

## Files

| File | Size | Use |
| --- | --- | --- |
| `icon.png` | 1024x1024 | Square icon source, edge to edge |
| `icon-macos.png` | 1024x1024 | Rounded macOS icon shape on a transparent canvas; source for `Resources/AppIcon.icns` |
| `icon-macos-small.png` | 1024x1024 | Simplified head-only art used for icon renditions of 32 pixels or fewer |
| `banner.png` | 1536x768 | README banner |
| `social-preview.png` | 1280x640 | GitHub repository social preview |
| `og-image.png` | 1200x630 | Open Graph and link-sharing card |
| `avatar.png` | 1024x1024 | Profile picture; safe for a circular crop |
| `wordmark.png` | 1536x1024 | Wordmark with the head mark |
| `branding/explorations/icon-dark.png` | 1024x1024 | Dark icon exploration, not in use |
| `branding/explorations/icon-small.png` | 1024x1024 | Square source for `icon-macos-small.png` |
| `branding/explorations/concepts/` | | The four characters considered: chip, meter (chosen), fan, and stopwatch |

Regenerate the app icon after changing `icon-macos.png` or `icon-macos-small.png`:

```sh
scripts/create_app_icon.sh
```

## Prompts

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
