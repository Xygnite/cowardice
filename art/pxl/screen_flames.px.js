// The painted flames BackdropLife plays over (scripts/backdrop_life.gd LIFE.menu, LIFE.camp): bg_screens.px.js
// paints each one into its backdrop, life.px.js loops it (every frame keeps the whole mask opaque, so the still
// never shows through). Keys are kit.px.js's fire: R o y w, coolest to hottest.

// A menu brazier's flame, standing on the bowl's rim.
const TORCH_MASK = `
  .....o......
  ....oyo.....
  ....oyoR....
  ...Ryyyo.o..
  ..oyywyoRo..
  ..oywwyyoo..
  .Roywwwyyo..
  .oyywwwwyoR.
  RoywwwwwyyoR
  oyywwwwwwyyo
  .oywwwwwwyo.`

// The camp's fire, over its logs.
const CAMPFIRE_MASK = `
  ......o.......
  .....oyo......
  .....oyo..o...
  ..o..oyyo.oR..
  ..oR.oyyo.oo..
  ..oo.Ryyyooo..
  .oyooyywyyoo..
  .oyyoywwwyoR..
  Royyywwwwyyo..
  oyywwwwwwwyyoR
  oyywwwwwwwwyyo
  RoyywwwwwwyyoR
  .Royywwwwyyoo.`
