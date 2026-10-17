# Full-frame faction portraits

Each faction has five complete 512×512 RGBA images in
`assets/factions/portraits/<faction>/`: `idle.png`, `speak_a.png`, `speak_b.png`,
`blink.png`, and `smile.png`. Native `PortraitSequence` resources reference every
texture for game exports. Playback draws one complete image at a time, with no facial
layers, masks or anatomical assembly.

Final prompts, selected source paths and asset mappings are in
[PORTRAIT_PROMPTS.json](PORTRAIT_PROMPTS.json). Normalize replacement artwork with
`tools/import_portrait_frames.gd -- <manifest.json>`: uniform Lanczos resizing only,
with no crop, mask, facial replacement or compositing. The manifest is an array of
`{ "source": "/absolute/image.png", "destination": "res://assets/factions/portraits/<faction>/<state>.png" }`.

## Replacement guidance

Complete repaints are not pixel-identical outside the face, so tests measure silhouette
overlap and centroid drift instead of requiring old pixels to survive. Keep the same
square canvas, head size, eye line, pose, costume, lighting and transparent silhouette
when replacing an image, and do not independently crop frames to their contents.
Inspect the eyes, lips, facial hair, cheek markings and silhouette at full resolution,
in dialogue/roster sizes and during playback. Update the native sequence resource if
filenames change.

## Review tools

- `tests/visual/test_portrait_frames.gd`: complete frames, transparent corners, common dimensions, silhouette overlap ≥98%, centroid drift <2px, body color continuity, rendered playback at two UI sizes, blink and reduced motion.
- `tools/previews/capture_portrait_review.gd`: labeled close-ups of all 20 frames on a lit background; `-- --motion` renders six seconds of speech, blinking and smiles at 24fps.
- `tools/previews/preview_character.gd -- <0..3>`: all five full portraits at 279px.

Generated output lives under `artifacts/` and is untracked. SVG faction emblems remain
in `assets/factions/emblems/`.
