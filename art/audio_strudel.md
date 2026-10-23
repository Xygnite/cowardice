# Audio — Strudel patterns

Paste one block at a time into https://strudel.cc and press Ctrl+Enter (Ctrl+. stops).
Every pattern loops, so for a one-shot SFX record a single cycle (each SFX fires once per cycle with silence after).
Render with the REPL's **export** tab (WAV), or record desktop audio in Audacity; trim and save `.ogg` into `assets/audio/`.

## Sound effects

### Dice rolling and clacking
```js
setcps(0.6)
// rattle in the cup, then the dice tumble and settle on the table
$: s("[rim*14]@2 rim ~ [rim rim] ~ rim ~ ~ ~").bank("RolandTR909")
  .speed(rand.range(1.6, 2.6)).gain(rand.range(.3, .8))
  .hpf(900).pan(rand).room(.15)
$: s("~@2 lt ~ [lt lt] ~ lt ~ ~ ~").bank("RolandTR909")
  .speed(3.5).decay(.05).sustain(0).gain(.4)
```

### Chains
```js
setcps(0.5)
$: note("[c7 f#7 a#6 d7 g7 c#7]*3 ~@2").s("square")
  .fm(6).fmh(1.414).decay(.04).sustain(0)
  .degradeBy(.3).gain(rand.range(.08, .25))
  .hpf(3000).pan(rand).room(.3)
```

### Hit
```js
setcps(0.5)
$: s("bd ~ ~ ~").bank("RolandTR909").shape(.6).lpf(900)
$: s("white ~ ~ ~").decay(.08).sustain(0).lpf(2500).gain(.5)
```

### Block (blow stopped by a wooden shield with a bronze rim)
```js
setcps(0.5)
// dull wooden thunk
$: s("bd ~ ~ ~").bank("RolandTR909").speed(1.4).lpf(1200).shape(.3).gain(.8)
$: s("lt ~ ~ ~").bank("RolandTR808").speed(1.8).decay(.12).sustain(0).gain(.7)
// short bronze rim ring
$: note("[e5,b5] ~ ~ ~").s("triangle").fm(3).fmh(2.7).decay(.15).sustain(0).gain(.2).room(.2)
// the blade glancing off
$: s("pink ~ ~ ~").bpf(1800).decay(.06).sustain(0).gain(.4)
```

### Clicks (UI)
```js
setcps(0.5)
// hover, click, confirm — record each one by muting the other two with _$:
$: note("b5 ~ ~ ~").s("triangle").decay(.02).sustain(0).gain(.3)
$: note("~ e6 ~ ~").s("triangle").decay(.03).sustain(0).gain(.5)
$: note("~ ~ [e6 b6] ~").s("triangle").decay(.05).sustain(0).gain(.5)
```

## Music

### Menu — slow, mournful, D harmonic minor
```js
setcps(70/60/4)
$: note("<[d3,a3,f4] [bb2,f3,d4] [g2,d3,bb3] [a2,e3,c#4]>")
  .s("sawtooth").lpf(sine.range(400, 900).slow(16))
  .attack(1.5).release(2).gain(.25).room(.8).size(.9)
$: n("0 [~ 4] 7 [5 ~] 4 ~ 2 ~").scale("D4:harmonic:minor")
  .s("triangle").decay(.4).sustain(0).gain(.3)
  .delay(.5).delaytime(.375).delayfeedback(.4).room(.6)
```

### Dungeon — tense, sparse, D phrygian
```js
setcps(90/60/4)
$: note("d2").s("sawtooth").lpf(sine.range(150, 400).slow(8)).gain(.35)
$: s("bd ~ ~ bd ~ ~ [~ bd] ~, ~ ~ ~ ~ rim ~ ~ ~").bank("RolandTR909").gain(.6).room(.3)
$: s("hh*8").bank("RolandTR909").gain(perlin.range(.05, .2)).hpf(6000)
$: n("<0 ~ 3 ~> [~ 1] <5 4> ~").scale("D3:phrygian")
  .s("square").lpf(1200).decay(.25).sustain(0).gain(.2)
  .delay(.4).delaytime(.33).room(.5)
// distant chain clank
$: s("~ ~ ~ cb").bank("RolandTR808").speed(.5).degradeBy(.6).gain(.2).room(.7)
```

### Boss — gothic crypt dread: war drums, organ, choir, funeral bell, D harmonic minor
```js
setcps(96/60/4)
// war drums
$: note("[d2 ~ ~ d2] [~ ~ d2 ~] [d2 ~ d2 ~] [~ d2 d2 d2]").s("gm_timpani").gain(.9).room(.5)
// cello ostinato following Dm, Bb, Gm, A
$: n("0 0 1 0 0 1 0 -1".add("<0 -2 -4 -3>")).scale("D2:harmonic:minor")
  .s("gm_cello").gain(.6).room(.4)
$: note("<[d3,f3,a3,d4] [bb2,d3,f3,bb3] [g2,bb2,d3,g3] [a2,c#3,e3,a3]>")
  .s("gm_church_organ").gain(.3).room(.6)
$: n("<[7 ~ 6 5] [4 ~ 5 ~] [2 ~ 3 4] [6@3 ~]>").scale("D4:harmonic:minor")
  .s("gm_choir_aahs").gain(.45).room(.8)
// funeral bell every two bars
$: note("<d3 ~>").s("gm_tubular_bells").gain(.5).room(.9)
```
