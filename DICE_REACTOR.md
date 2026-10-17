# Physics dice reactor

`ReactorCube.gd` is a `RigidBody3D` with a convex collider matching its beveled shell
and continuous collision detection. Each face has a permanent numbered pip panel;
opposite faces sum to seven and numbers never change. Normal throws settle physically;
Skip chooses two random values and aligns the stopped cubes to them.

`DiceThrow.play(accent, fast, launch_seed)` returns the two actual upward face values
after physical settlement, or immediately chosen random values when skipped.
`GameController.gd` supplies a random launch seed and passes the returned values
unchanged to `ParquesRules.roll()`. Launch positions, orientations, linear velocities
and angular velocities vary independently for each die.

The 8.9 × 6.2 landing assembly has a physical floor and containment walls. Dice
restitution is .52, surface restitution .12, die/surface friction .5/.55, and gravity
scale 1.35. Low initial damping allows rebounds and tumbles, then increases after 2.8
seconds to shorten the settling tail. There are no bounce keyframes or face-alignment
torques. A lateral force dislodges stacked dice; a die still cocked after six seconds
receives a small physical toss, its number unchanged. Physical resolution requires
both dice flat, close to the floor, and slow for .2 seconds. A timeout never freezes
an airborne die or declares a transient face.

Quick mode begins braking earlier and shortens the result hold. Skip dismisses the
overlay, selects two independent uniform random values from 1–6, stops physics and
aligns the dice to those results; skipping the result hold preserves the revealed
values, and repeated or out-of-turn skips are ignored.

The camera follows the actual pair. Strong solver contact impulses drive light pulses
and impact sounds; cooldowns merge contact chatter and impulse strength controls mixer
gain. Aquamarine/navy light flows through twelve edge channels and the inlaid face
frames and pips; local lights and HDR bloom supply spill. Faction colors remain on
chamber fixtures. Procedural meshes and shaders require no external bitmap assets.

## Review

- `tests/integration/test_dice_reactor.gd`: face numbers, opposite pairs, rebounds, varied launches, tray/camera containment, real contacts and sound gain, quick mode.
- `tests/integration/test_dice_skip.gd`: real Skip clicks, immediate dismissal, independent values, exactly one rules commit, repeated clicks and skipping a revealed result.
- Game-flow tests verify the controller passes physical values to the rules unchanged.
- `tools/previews/capture_dice.gd` records a seeded physical throw and replays it for review PNGs; `-- --motion` renders replay frames at 30fps. Gameplay uses live physics. Generated output (including `artifacts/dice-physics-recording.json`) is untracked.
