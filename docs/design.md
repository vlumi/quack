# Design

Why Quack Express is the way it is, with the alternatives that were rejected
and the reasons. Distilled from the planning notes of 2026-09-12. What is
*built* is [ARCHITECTURE.md](../ARCHITECTURE.md); *when* is
[ROADMAP.md](../ROADMAP.md).

## The seed

Sopwith (1984): a side-scrolling biplane, two keys for the elevators, a half
loop and release to turn round, bombs on buildings, a landing to rearm. The
handling was the whole game and the levels were a terrain silhouette. That is
the property to keep: **few inputs, endless technique, nothing to author.**

## Rules that filter everything

- **Easy to learn, hard to master.** Two inputs at most, each doing one thing,
  never a third simultaneous input. Difficulty lives in the generated world
  (shorter fields, wind, more guns), never in the controls.
- **No content authoring.** Terrain, fields, contracts, weather and enemy
  placement are generated from a seed. Graphics are line art, silhouettes,
  particles and gradients. Campaigns are lists of ranked seeds.
- **Tilt is out.** Tilt suits games with momentum, where its 30–50 ms latency
  hides behind physics. This game turns on a half loop and needs the input to
  be where the thumb is. Two thumbs also map to two keys, which puts the Mac
  back in.
- **Don't take it seriously.** A duck flies the plane. Modes are called
  Duckfight and Daily Drop.

## Controls

- **Left thumb, vertical drag = elevators.** Distance from where the thumb
  landed sets the pitch rate; the thumb defines its own centre each time.
  A small drag is a gentle climb, a full drag pulls a loop. Aircraft
  convention: pull the thumb toward you (down) and the nose comes up, and ↓
  on the Mac does the same. Some players will want it the other way, so an
  invert option is planned; the flag already exists in the controls.
- **Release = auto-upright.** The plane rolls to the nearer way up, so
  half-loop-and-release is the turn.
- **Right thumb: the gun.** Hold to fire the Vickers on the hump; rounds
  leave along the heading. The throttle is open for the whole flight. The first flights of milestone 1 (2026-09-12) showed a hold-to-fly
  button muddied the one question being asked, and a courier at full chat is
  the era's default anyway.
- **Energy model underneath**: constant thrust against drag that grows with
  the square of speed, balancing at cruise. Diving gains speed, a shallow
  climb holds it, a steep one bleeds to a stall. Speed is managed with the
  elevators, which is what makes the approach a skill.
- **Rejected:** a two-axis virtual stick (vertical pitch, horizontal throttle)
  — closest to Sopwith's keys, but a third thing for the thumb to get right,
  and the easy-to-learn rule wins. **Hold-for-power, release-to-glide** —
  period-authentic and it gave the approach a throttle, but it was a second
  thing to hold during the feel test, and every lifted thumb made the plane
  feel engineless; the sim keeps `power` in its input so the landing assist
  and AI pilots can still cut the engine. **Guns and bombs**, when they come,
  ride on the free thumb. If that ever feels wrong, the war era is its own
  game, not a mode.

## The balloon run

The first thing to do with a gun, and the milestone-1 feel test with a score:
a dozen balloons scattered ahead of the start, pop them all as fast as you
can, by gun or by flying into them. The clock starts at the first input and
stops at the last pop, and the next pull of the trigger deals a new field.
Every field comes from a seed, so a run can be replayed and compared. It is a
practice mode first and, with a shared seed, a Daily Drop later.

## Landing

The approach is the test, the touchdown is automatic. Align the plane on the
field's approach angle, descending, and cross the threshold: the assist takes
over, throttles back, flares and rolls out. With the throttle always open the
window has no speed dimension, only angle and descent, which keeps it an
elevator skill. Outside the window: bounce, broken undercarriage or crash, by
how far off. The window is the difficulty dial (wide early, narrow later; wind
and slope make a good approach harder). A landing flown inside the window
without needing the assist earns a small bonus: mastery rewarded, not
required.

## The world

- **A horizontal torus.** Fly east long enough and you return from the west.
  The strip fits in memory; the shortest way to a contract is sometimes the
  other way round.
- **Noise terrain**, fields placed on flat ground, bridges over gaps, AA guns
  by rules. Parallax silhouettes, a sky gradient for the hour.
- **Wind is the cloud layer's speed.** No gauge. On a wraparound strip that
  makes the two directions genuinely different: headwind one way, tailwind the
  other; later, gusts push the approach and drift bombs.

## The courier economy (single player)

- Contracts appear at fields: pick up here, deliver there, pay falls with
  time. Distance, terrain and wind decide how tempting each is.
- **Mailbags don't care how you fly; passengers do.** Aerobatics with a
  passenger cut the fare. Two contract types, two ways to fly.
- **Fuel is a range clock**: it drains as long as the engine runs, which is
  always. Refuelling costs money and a stop.
- Fares buy a bigger tank, a stronger engine, a second seat.
- **Hazards as economics, not activity.** AA guns threaten routes; dodging
  costs time, shooting them costs ammunition bought at the field. The courier
  stays a courier; shooting is occasional and instrumental.

## Duckfight (nearby multiplayer)

Two to four planes over MultipeerConnectivity, one strip, each device its own
viewport, deterministic lockstep (Skid Jam's networking is the model). Guns
are the point here. Single-screen shared play on one iPad was considered and
dropped: the original split the screen because both players sat at one
keyboard, and that does not survive a hand-held device.

## Daily Drop

The same seed for everyone, one attempt, fares as score, shared nearby the way
Donpa Squad shares its daily. "Drop" is both the delivery and the bomb.

## Generation and ranking

Every strip is a seed and a difficulty. Fields need flat ground, bridges need
gaps, gun count and placement scale with difficulty. An AI pilot flies every
generated strip before it ships, which both proves it can be completed and
scores it (fuel margin, closest call, time). Campaigns are ranked seed lists
played once by hand, shipped as data; endless and daily modes draw from the
same generator.

## Graphics

Layered terrain silhouettes with parallax, stacked-rectangle buildings, smoke
and explosion particles, a sky gradient for the hour. Fully procedural, and it
looks intentional because the original looked like that too. The one drawn
asset is the icon: a duck in a flying cap.

The plane is a cartoon Camel, chosen over line art, a silhouette and an 8-bit
sprite (2026-09-12) for being recognisable at a glance rather than correct for
the era: a fat fuselage, a rounded cowl, wide staggered airfoil wings with
leaning struts and cross wires, a swept fin, and the duck in a fleece-rimmed
flying helmet behind a windscreen. It is drawn from a **livery**, three colours
and an emblem on the fin, so every company, rival and Duckfight opponent is a
data change; the player's own livery and emblem become a picker later. The
finish has enamel gloss that catches the sun by attitude, so it sweeps through
a loop and vanishes inverted. When the plane rights itself the drawing rolls,
top toward the camera, drawn part by part with each surface at its real height
and a mild perspective, so the far wing tucks behind the body and the near one
crosses in front. A flat squash was tried first and looked like paper. A
flapping scarf is a later detail.

## Name

**Quack Express** (App Store name) with the subtitle **Duck and Deliver**;
the combined form is 31 characters, over the 30-character name limit, so it is
split across the two ASC fields, which is how the store displays it anyway.
The name is the company and stays fixed; the subtitle names the campaign, so
a war era could ship as "Quack Express: Duckfight" without a rename.
Runners-up: Fragile Flyer, Air Mail Circus, Camel Express. Rejected: Crate
Escape (taken), Flying Circus (Python estate; IL-2 Flying Circus in the same
genre), Tailspin Express (homophone of Disney's TaleSpin, same plot), Wing It
(taken), Speedmail (didn't sound like a game).

## Milestone 1, the only question

Fly a ground line, one plane, a loop and a half-loop turn, on a real iPhone
and on a Mac. If drag-pitch plus hold-for-power is not a pleasure, stop before
building anything on it.
