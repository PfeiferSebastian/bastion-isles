class_name HpDrain
extends RefCounted
## Calm HP or energy bar: the shown share lags the real one and catches up in steps of STEP
## seconds. A step drains (or fills) from where the bar stands to the share at the step's start;
## whatever changes during a step adds up into the next one. Bars draw solid() in colour and
## the gap up to ghost() white: a loss shrinks from the old value, a gain fills toward the new.
## Destruction isn't drained: the owner simply stops drawing the bar.

const STEP := 1.0
const GHOST_COLOR := Color(1, 1, 1, 0.9)

var _from := 0.0
var _to := 0.0
## Seconds into the current step (STEP or more: idle).
var _time := STEP
var _started := false
## Owner bookkeeping: the process frame this bar was last advanced in.
var seen_frame := -1


## Moves on by `delta` seconds toward `real` (a share, 0..1).
func advance(real: float, delta: float) -> void:
	if not _started:
		_started = true
		_from = real
		_to = real
		return
	_time += delta
	if _time >= STEP:
		_from = _to
		if not is_equal_approx(real, _to):
			_to = real
			_time = 0.0


## Forgets the old value and stands at `real` right away (a new object took the place).
func restart(real: float) -> void:
	_started = false
	_time = STEP
	advance(real, 0.0)


## Where the drain currently stands, between the old and the new share.
func shown() -> float:
	return lerpf(_from, _to, clampf(_time / STEP, 0.0, 1.0))


## The coloured part: the new share on a loss, the filling bar on a gain.
func solid() -> float:
	return minf(shown(), _to)


## End of the white part: the draining old share on a loss, the new share on a gain.
func ghost() -> float:
	return maxf(shown(), _to)


## Whether a step is still running.
func busy() -> bool:
	return _time < STEP and not is_equal_approx(_from, _to)
