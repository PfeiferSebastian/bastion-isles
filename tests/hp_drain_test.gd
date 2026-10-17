extends SceneTree
## Calm HP bars (HpDrain): a loss shows white and drains within a second, a gain fills into
## white, changes during a step wait for the next one.
## Run: godot --headless --path . -s tests/hp_drain_test.gd

var _failures := 0


func _init() -> void:
	var d := HpDrain.new()
	d.restart(1.0)
	_check(not d.busy() and is_equal_approx(d.solid(), 1.0), "starts settled")
	d.advance(0.6, 0.016)
	_check(d.busy(), "a loss starts a step at once")
	_check(is_equal_approx(d.solid(), 0.6) and d.ghost() > 0.95, "loss: colour at the new value, white above")
	d.advance(0.3, 0.5)
	_check(is_equal_approx(d.solid(), 0.6), "changes during a step wait")
	_check(absf(d.ghost() - 0.8) < 0.01, "white drains halfway after half a step")
	d.advance(0.3, 0.5)
	_check(is_equal_approx(d.solid(), 0.3) and is_equal_approx(d.ghost(), 0.6), "next step takes the summed change")
	d.advance(0.3, 1.0)
	d.advance(0.3, 0.0)
	_check(not d.busy() and is_equal_approx(d.ghost(), 0.3), "settles")
	d.advance(0.8, 0.016)
	_check(is_equal_approx(d.ghost(), 0.8) and d.solid() < 0.31, "gain: white at the new value, colour fills")
	d.advance(0.8, 0.5)
	_check(absf(d.solid() - 0.55) < 0.01, "fills halfway after half a step")
	print("hp_drain_test: %s" % ("OK" if _failures == 0 else "%d FAILED" % _failures))
	quit(_failures)


func _check(ok: bool, what: String) -> void:
	if not ok:
		_failures += 1
		print("FAIL: " + what)
