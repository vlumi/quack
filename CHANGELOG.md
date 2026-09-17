# Changelog

All notable changes to Quack Express are documented here.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Grouped by **marketing version** (a roadmap milestone), then by **build number**
within it — the version stays steady while the build climbs each TestFlight
upload (see [RELEASING.md](RELEASING.md)). Newest first.

Each version's top section, **Unreleased (next build)**, collects entries merged
to `main` but not yet in a TestFlight build; cutting a release renames it to that
build's heading and opens a fresh empty one. Keep that heading immediately
followed by its list items (no prose between), so the release script can promote
it with a one-line edit — and keep it UNIQUE in the file (the script promotes
the first match).

## [0.5.0]

**Milestone 5 — hazards.** Guns on the strip, and something that shoots back.

### Unreleased (next build)

- Anti-aircraft guns: three per courier run, dug in beside the strip from the seed and clear of every field. A gun in range fires a shell every two seconds, leading the plane; a burst on the plane is a hit. Each hit adds four seconds of repair to the next stop, and three hits stop the engine until then. A gun is knocked out by two rounds. A shell bursting on the plane frightens a passenger, a quarter of the fare's worth. The balloon run has no guns. Range, rate, shell speed, scatter and repair per hit are on the tuning panel.

## [0.4.0]

**Milestone 4 — courier.** Contracts between fields, fuel, a company with a
till and a hangar.

### build 7 — 2026-09-16

- Parked, the plane has buttons: a panel at the bottom with the field's jobs as cards to pick from and two take-off buttons, left and right. The stick and the trigger do nothing on the ground any more, and the roll lifts off by itself at rotate speed. On the Mac, the arrow keys take off and 1 and 2 pick.
- Readouts: the balloons left are a row of balloons and the belt a row of rounds, instead of counts. The three gauges carry icons, and the altimeter's band is amber where the air thins and red only past the ceiling. The minimap is bigger, opaque and higher in contrast, and it lights the destination of the job being picked as well as the one aboard, as does the chevron. The hangar keeps its width on a wide window, and the menu buttons take a tap anywhere on the capsule.
- The company: money earned as a courier is kept on the device between runs, and a new courier run starts with it. Rounds now cost a quarter of a franc each at the field, on credit when broke; the balloon run pays nothing.
- The hangar, from the title screen: buy a bigger tank (three levels, 50 s of engine each), a stronger engine (three levels), or a second seat, which carries two passengers a job for two fares. Upgrades apply to every run after.
- Fuel: a third gauge shows the tank, 150 seconds of engine, which burns whenever the engine runs and fills while parked at a field, ten seconds of fuel a second, for a tenth of a franc each. Empty, the engine stops and the plane glides: reach a field or crash. A broke courier is filled on credit, and the balloon run pays nothing. Tank, refuel rate and price are on the tuning panel.
- Passengers: every board now offers one mail job and one passenger, who pays 1.6 times the mail fare for the same trip but minds the flying. Inverted flight, hard turns, stalls, bounces and a broken undercarriage cost comfort, down to a quarter of the fare, and the passenger complains at each quarter lost. The pay readout shows the cut as it happens. A crash sends the passenger walking home. The costs are on the tuning panel's Courier section.
- The approach guides are soft amber glows now, fading out toward their far end with no hard edge, in a colour that reads at every hour, and they fade away while the plane is on the ground.
- A title screen over the running world: Courier or Balloon run, and the invert-pitch switch, which is kept between launches. A pause button at the bottom of the screen (Escape on the Mac) freezes a run, with resume and quit to title.
- The courier's day: every field has a name and posts two mail jobs to other fields. Parked, the trigger picks one and pulling up takes it aboard; land at its field and it pays what is left of the fare, which falls with time to a quarter. Landing elsewhere keeps the bag; a crash loses it. The readouts show your money and the job's pay, the minimap lights the destination red, and the white chevron points at it. The balloon run is the title screen's other choice.

## [0.3.0]

**Milestone 3 — the strip.** A generated world that wraps around, with hills,
fields and wind.

### build 6 — 2026-09-15

- The world wraps: fly off one end of a 2.4 km strip and you come back from the other. Four fields are spread round it, generated from the run's seed.
- The balloon run spreads its balloons round the whole strip and finishes when you land at any field, not only at home.
- A tiny minimap under the status line shows the whole world shrunk into a box, squeezed more side to side than up and down: the ground with its fields, the balloons still up at their heights, and your plane at its height, pointing the way it flies.
- The edge chevrons point the shorter way round, and keep clear of the readouts, the status line and the gauges.
- Hills: the strip rolls up to about 75 m, generated from the seed. Each field sits on a flat shelf cut into them, so some are in valleys and some on ridges. Flying into a hillside is a crash, rounds stop in the ground, and balloons float above the hills. The minimap shows the hills too.
- Wind: each run has a steady wind one way or the other, in one of five steps from calm to a 16 m/s gale, so flying round the strip is quicker one way. Up in the air your plane moves with the air. Near the ground the wind is weaker, so climbing into it gains airspeed and climbing out downwind loses it. On the ground the wind counts as airspeed: take off into it and the roll is short, take off downwind and it is long, and a landing into it rolls out slow. The landing assist glides through the wind and still stops on the field. There is no gauge: the windsock has one shape per step, the clouds drift with the wind, and the balloons drift slowly, rising over hills. Strongest wind, how it fades near the ground, and balloon drift are on the tuning panel.
- Clouds in front of the plane, a little see-through, so you can hide in them.
- A new look: hills lit along their tops, villages with churches and windmills on three layers that slide past at different speeds, and a smooth sky with a sun, or a moon and stars, for the hour. The hour comes from the run's seed: dawn, noon, evening or night.
- Houses and trees stand on the strip. They are solid: flying into one is a crash and rounds stop in them. None stands near a field's approach. Each field has a hangar behind it.
- The readouts turn pale at night. The tuning panel can force an hour.
- The air thins as you climb: above 120 m the engine pulls less and the plane stalls at a higher speed, until at about 250 m full power only just holds it up. The altimeter reads height above sea level and marks the thin air in red. Where the air starts to thin and the ceiling are on the tuning panel.

## [0.2.0]

**Milestone 2 — landing.** One field on the ground line: take off from it, and
land back on it by flying the approach angle.

### build 5 — 2026-09-14

- A belt of 40 rounds: an empty belt fires nothing. Parked on the field it refills a round at a time, and you can take off before it is full to save time. The rounds left show under the clock. Belt size and rearm rate are on the tuning panel.
- The field: the balloon run now starts parked on a 60 m strip, short enough to see end to end. Pull up to roll and take off; the run ends when you land again after the last pop.
- Landing: fly into the cone drawn over the end of the field, the right way up, heading for it, not climbing and not diving steeply, and the assist takes over: it glides down, flares, touches down just past the threshold and brakes hard to a stop. Level flight into the cone is enough. Pull hard to take it back; it then leaves you alone until you are out of the cone.
- Choose which way to take off: parked, pull up to go the way you face, or push to swing round. If there is no room that way, the plane taxis to where there is first. It stays on the ground the whole time, so turning around costs a few seconds.
- Reaching the ground without the assist is graded by how steep: a touchdown, a bounce, a broken undercarriage that keeps you down for a repair, or a crash that puts you back at the start of the field. Touching the ground off the field is a crash.
- Twice the engine: thrust 16 instead of 8, so the plane can hold a 35° climb instead of 17° and gets height off the field. Straight up it still stalls and flips within about 27 m.
- A Landing section on the tuning panel: cone angle, width and length, steepest entry, bounce margin, braking, takeoff push, taxi speed, turn time, field length and repair time. A white chevron points to the field when it is off screen.

## [0.1.0]

**Milestone 1 — feel.** A plane, a ground line, two thumbs. Does drag-pitch
with the throttle open feel as good as Sopwith's two keys?

### build 4 — 2026-09-14

- The tuning panel: shake the phone, or Debug › Tuning Panel (⌥⌘T) on the Mac. Sliders for the flight, the stall, the controls, the gun and the roll apply at once and stay on the device; Copy puts every value on the clipboard. The flight pauses while it is open.

### build 3 — 2026-09-14

- Both thumbs work at once: holding the trigger no longer locks out the elevator, or the other way round.

### build 2 — 2026-09-14

- Two cockpit gauges top right: airspeed in km/h with the stall range in red, and altitude in metres.
- Thumb pads drawn over the game: a pitch track and a trigger ring that float to where the thumbs land and stay, dimmed, where they left them; the bar and knob show how much elevator is in. Near a screen edge the throw shrinks to the room there, so full elevator is always reachable.
- A placeholder app icon: the plane climbing over the strip, drawn by the game's own rig. The duck in a flying cap comes with 1.0.

### build 1 — 2026-09-13

- Repo scaffold: XcodeGen project with iOS and macOS targets under one bundle id, the QuackCore package with a placeholder flight model and tests, QuackKit with a SpriteKit scene, the Makefile and release lane from the sibling games, CI.
- The plane: a cartoon biplane with the duck at the stick, drawn from a livery (three colours and a fin emblem) so companies and rivals are data. It rolls through edge-on when it rights itself, and its gloss catches the sun by attitude.
- Flight model: constant thrust against drag, balancing at cruise. Dives gain speed, shallow climbs hold, steep ones stall.
- The gun: a Vickers on the hump, hold the right thumb (space on the Mac) to fire; rounds fly straight along the heading and expire.
- Rounds are drawn as dark slugs with a warm tracer trail, so they read against the sky.
- Everyone sees the same world: a fixed 16:9 box 70 m tall, letterboxed on other screen shapes; the Mac window keeps the box inside a dark frame at any size.
- Balloons outside the box show as chevrons on its edge, bolder and bigger the nearer they are.
- The balloon run: a dozen seeded balloons ahead of the start, pop them all by gun or by ramming, clock from first input to last pop, fire again for a new field.
- The roll: when the plane rights itself the drawing now rolls in fake 3-D, top toward the camera, each surface at its real height with a mild perspective, instead of a flat squash.
- A real stall: gravity in the speed exchange is much stronger, so a plane pointed straight up runs out of speed within a screen height, breaks decisively and noses over forward. A stalled plane sinks before the nose goes and keeps sinking until airspeed returns. A loop from cruise still makes it round.
- Throttle open for the whole flight; the right thumb is free for the gun. The camera now follows climbs. On the Mac, ↓ pulls the nose up and ↑ pushes it down, the same sense as the thumb drag; an invert option is prepared.
