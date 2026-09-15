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
- **Everyone sees the same world.** A fixed 16:9 box, 70 m tall, the iPhone
  SE's shape because it is the narrowest phone; every other screen and the
  Mac window letterbox it in a dark frame. Seeing further sideways would be
  an advantage in a Daily Drop or a Duckfight, so nobody gets to. What lies
  outside the box is pointed at from its edge: a chevron for each balloon
  (later, each threat), bolder and bigger the nearer it is, because a pilot
  sees further than the screen, just not as clearly.
- **Don't take it seriously.** A duck flies the plane. Modes are called
  Duckfight and Daily Drop.

## Controls

- **Left thumb, vertical drag = elevators.** Distance from where the thumb
  landed sets the pitch rate; the thumb defines its own centre each time.
  A small drag is a gentle climb, a full drag pulls a loop. Aircraft
  convention: pull the thumb toward you (down) and the nose comes up, and ↓
  on the Mac does the same. Some players will want it the other way, so an
  invert option is planned; the flag already exists in the controls.
- **The pads are drawn, translucent, over the game.** Skid Jam's precedent:
  a pad floats to where the thumb lands and stays, dimmed, where it left it,
  so a new player sees where to press before pressing, and a playing one can
  read how much elevator is in (a bar from the centre to the knob, the
  nose-up chevron lit). Not dedicated areas with nothing in them: the world
  shows through, and the pads sit over the letterbox bars too. Near the
  screen's edge the throw in that direction shrinks to the room there, so
  full elevator is always reachable from wherever the thumb landed; the
  track shows the real range. The first phone flights (2026-09-13) had
  trouble pulling up reliably with no visual clue why.
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
- **The air thins with height**, so there is a ceiling without a wall. Above
  120 m the engine's push and the wing's grip fade together (thrust scales with
  the air's density, stall speed with one over its square root), until at the
  250 m ceiling full power just holds level at stall speed. A climb flattens out
  on its own below it; above it the plane cannot stay up. It reads as altitude
  above sea level, so a hill does not raise the ceiling.
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

**The gun has a belt.** 40 rounds, and an empty belt fires nothing. Parked on
the field it refills a round at a time (20 a second), and a plane that takes
off part way keeps what was loaded: a pilot who needs only a few rounds can
save the time. Running dry mid-run is a choice between ramming the rest and
landing to rearm, and both cost time, which gives landing a job inside the run.
Belt size and rearm rate are on the tuning panel. Paying for rounds comes with
the courier's money.

**Fuel waits for distance.** On a 600 m balloon course a tank either never runs
out, which is pointless, or runs out on a schedule the course was tuned to
force, which is artificial. It becomes a decision on the wraparound strip and
with contracts, where the way round and a stop to refuel are real trade-offs,
and it needs other fields to glide to. The flight model already glides with
the engine off.

## Landing

The approach is the test, the touchdown is automatic. Fly into the **cone**
over the end of the field, the right way up, heading for the field, not
climbing and not diving steeply, and the assist takes over: it glides down,
flares, touches down and brakes to a stop. Level flight into the cone is
enough. The skill is getting there low and pointed the right way, with the
elevator, and the throttle always open.

Pulling hard hands the landing back, and the assist then leaves the plane
alone until it has left the cone, so a go-around or a balloon near the field
is still the pilot's. A first version asked for the plane's path to be within
a few degrees of the approach angle when it arrived; flying it, that was too
fussy for a moment the assist is about to take over anyway.

The cone is drawn, exactly: a short wedge rising from each end of the field at
the approach angle ± its width, 50 m out, with a low throat just over the
threshold and the angle itself dashed. Its floor rises near the field to what
a flare can carry onto it, so a plane skimming the grass short of the field is
not grabbed only to be put down on the grass. The cone is the difficulty dial
(wide early, narrow later; wind and slope make a good approach harder).

Reaching the ground without the assist is graded by how steep: shallow enough
is a hand-flown touchdown; a little steeper bounces back into the air; steeper
still breaks the undercarriage, which rolls out and then keeps the plane on
the ground for a repair; steeper than that, upside down, or off the field is a
crash, and the plane is back at the start of the field after a moment. The
clock does not stop for any of it.

Taking off is the other half: parked, pull up and the plane rolls with the
throttle open the way it is facing, and lifts off once it is fast enough and
the stick is back. Running off the end is a crash.

**Choosing the direction is a taxi, never a warp.** Parked, a push swings the
plane round on the spot; if there would not be room to take off the other
way, it first taxis out to where there is. A pull toward a short end taxis
back, swings round and rolls. The plane stays on the ground the whole time
and it costs seconds, so once anything can shoot at parked planes, turning
around is not a free dodge. A warp to the other end was considered and
rejected for exactly that, and because it reads as a glitch. A parked plane
keeps facing the way it rolled out; the push is how that changes. With a
wraparound strip and wind to come, the direction will decide the shorter way
to a contract and a headwind or tailwind takeoff.

**The field fits on the screen.** A real strip for a Camel would run off both
sides of the view, and a field you cannot see is a field you cannot aim at. So
it is short (60 m, about half the view), and braking and the takeoff roll are
exaggerated to fit it, the same way the stall is. The assist aims just past
the threshold, or at the nearest point it can reach without diving steeper than
the cone, pulls out of any dive quickly, and only takes over if that still
leaves room to stop.

A landing flown inside the window without the assist earns a small bonus:
mastery rewarded, not required. Not built yet.

In the balloon run the field is the start and the finish: take off, pop them
all, land again. The clock stops when the plane is parked after the last pop,
so the turn back and the approach are part of the time.

## The world

- **A horizontal torus.** Fly east long enough and you return from the west.
  The strip fits in memory; the shortest way to a contract is sometimes the
  other way round. It is 2.4 km, with four fields spread round it from the seed
  (each nudged by up to a quarter of the gap), the first of them home.
- **A minimap of the whole world**, very small, under the status line: the
  strip shrunk into a box, squeezed more side to side than up and down so
  height still reads, with the ground and its fields along the bottom, a dot per
  balloon at its height, and the plane at its height, the hills filling the
  bottom and the box as tall as the ceiling. The view shows 124 m of a
  2.4 km world, so the edge chevrons alone cannot say where you are overall.
- **The balloon run on the strip**: start at home, balloons spread round the
  whole strip (clear of the fields' approaches), and finish by landing at *any*
  field, so which way round and where to come down are part of the time.
- **Noise terrain**: rolling hills from a few octaves of seamless value noise,
  up to about 75 m, each field on a flat shelf cut into them (70 m of apron each
  end, blended smoothly into the hill over 80 m more), so a field can sit in a
  valley or on a ridge and its approach is clear. Flying into a hillside is a
  crash; rounds stop in it; balloons float 18 to 118 m above the ground under
  them, out of the thin air unless the hill itself is high. Bridges over gaps
  and AA guns by rules come later.
- **Houses and trees on the strip are solid.** Scenery a plane flies through
  reads as a glitch, solid scenery makes low flying a skill, and houses become
  targets once there are bombs, as in Sopwith. To stay fair, none stands on a
  field's shelf or above the approach line beyond it, all stand well under the
  lowest balloon, the solid box is smaller than the drawing so brushing leaves
  is forgiven, and rounds stop in them as in the ground. A field's hangar and
  windsock are part of the field and not solid.
- **Wind is the cloud layer's speed.** No gauge. On a wraparound strip that
  makes the two directions genuinely different: headwind one way, tailwind the
  other; later, gusts push the approach and drift bombs. Balloons drift with it
  slowly, which shows the wind before anything else in the sky does.
- **Clouds in front of the plane as well as behind**, a little translucent, so
  a plane can hide in them. Only a look until something can see it; a real
  tactic once there are gunners and Duckfight.
- **The hour is part of the seed**, not the device's clock, so a seed always
  gives the same world: the Daily Drop needs that. Dawn, noon, evening or
  night, evenly. At night the windows are lit and the readouts turn pale.
- **Weather later**: rain, thunder, snow, from the seed, once wind and the look
  exist to carry them.

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

The world's look was chosen in mockup rounds (2026-09-15) from Cutout (flat
silhouettes fading into the sky), Ink (the plane's ink line carried into the
world) and Poster (a 1930s travel poster). **Poster shapes over Cutout's quiet
sky** won: hills lit along their tops, lozenge trees and poplars, villages
with a church or a windmill, no outlines, the far layers fading into the haze,
under a smooth gradient. Ink put too much weight behind the plane; the
poster's banded sky was too strong at dawn and evening, and faint bands
looked like a rendering glitch. The moon is drawn in its phase, not as a disc
with another laid over it.

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
