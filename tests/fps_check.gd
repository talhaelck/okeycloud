extends SceneTree
## Runs the real game scene for a few seconds with vsync off and reports the average frame rate and the slowest
## frames, so each atmosphere addition can be weighed. Needs a window (GPU), not --headless.
##   godot --path . --script tests/fps_check.gd

const WARMUP := 3.0
const SECONDS := 8.0


func _init() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	if "--no-demo" in OS.get_cmdline_user_args():
		RiggedDayi.demo = false
	root.add_child(load("res://scenes/main.tscn").instantiate())
	var start := Time.get_ticks_usec()
	while Time.get_ticks_usec() - start < WARMUP * 1e6:
		await process_frame
	var times: Array[float] = []
	var spikes: Array[String] = []
	var last := Time.get_ticks_usec()
	start = last
	while last - start < SECONDS * 1e6:
		await process_frame
		var now := Time.get_ticks_usec()
		times.append((now - last) / 1000.0)
		if times[-1] > 50.0:
			spikes.append("%.1fs: %.0f ms" % [WARMUP + (now - start) / 1e6, times[-1]])
		last = now
	times.sort()
	var total := 0.0
	for t in times:
		total += t
	var worst := times.slice(int(times.size() * 0.99))
	var worst_avg := 0.0
	for t in worst:
		worst_avg += t / worst.size()
	print("FPS_CHECK avg %.0f fps (%.2f ms), slowest 1%% %.2f ms (%.0f fps), %d frames" % [
		1000.0 * times.size() / total, total / times.size(), worst_avg, 1000.0 / worst_avg, times.size()])
	if not spikes.is_empty():
		print("  hitches over 50 ms: ", ", ".join(spikes))
	quit()
