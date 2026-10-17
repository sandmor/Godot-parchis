extends "res://tests/support/test_case.gd"
## Full frames must retain the idle canvas and closely aligned silhouettes.
## Facial anatomy quality is reviewed visually, not inferred from pixel equality.
const Portrait := preload("res://AnimatedPortrait.gd")
func _run() -> void:
	var viewport := SubViewport.new()
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var portrait := Portrait.new()
	viewport.add_child(portrait)
	portrait.set_process(false)
	for team in range(4):
		portrait.set_character(team)
		check(portrait.definition.frames.size() == 5,"Five finished frames for each faction")
		var idle := _source(portrait.definition.frames.idle)
		check(idle.get_size() == Vector2i(512,512) and idle.get_pixel(0,0).a < .01,"Full RGBA canvas and genuine transparency")
		for key in portrait.definition.frames:
			if key == "idle": continue
			var frame := _source(portrait.definition.frames[key])
			check(frame.get_size() == idle.get_size(),"Identical canvas sizes")
			var intersection := 0
			var union_count := 0
			var count_a := 0
			var count_b := 0
			var center_a := Vector2.ZERO
			var center_b := Vector2.ZERO
			var body_delta := 0.0
			var changed := 0
			for y in range(512):
				for x in range(512):
					var a := idle.get_pixel(x,y)
					var b := frame.get_pixel(x,y)
					var opaque_a := a.a > .5
					var opaque_b := b.a > .5
					if opaque_a and opaque_b: intersection += 1
					if opaque_a or opaque_b: union_count += 1
					if opaque_a:
						center_a += Vector2(x,y)
						count_a += 1
					if opaque_b:
						center_b += Vector2(x,y)
						count_b += 1
					if a != b: changed += 1
					if y >= 280:
						body_delta += (absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b))/3
			check(count_a > 10000 and count_b > 10000,"Frames contain a complete visible portrait")
			var overlap := float(intersection)/maxi(union_count,1)
			var shift := (center_a/maxi(count_a,1)).distance_to(center_b/maxi(count_b,1))
			check(overlap >= .98 and shift < 2.0,"Whole-frame silhouette overlap >=98%% and centroid drift <2px: %s/%s (%.4f, %.2fpx)" % [team,key,overlap,shift])
			check(body_delta/(512*232) < .06,"Body color continuity prevents a large exposure flash")
			for corner in [Vector2i(0,0),Vector2i(511,0)]:
				check(frame.get_pixelv(corner).a < .01,"Frames retain transparent top corners")
			check(changed > 0,"Each expression has visible facial changes")
		for dimensions in [Vector2i(384,384),Vector2i(88,100)]:
			viewport.size = dimensions
			portrait.size = dimensions
			portrait.speaking = false
			portrait._clock = 0
			portrait._update_frame()
			var before := await _capture(viewport)
			for time in [.16,.55]:
				portrait.speaking = true
				portrait._clock = time
				portrait._update_frame()
				check(portrait.frame_state in ["speak_a","speak_b"] and portrait.texture == portrait.definition.frames[portrait.frame_state],"Playback selects one finished speech frame")
				var after := await _capture(viewport)
				check(before.get_data() != after.get_data(),"Speech is visible at dialogue and HUD sizes")
			portrait.speaking = false
			portrait._clock = 4.6-team*.47
			portrait._update_frame()
			check(portrait.frame_state == "blink","Timed blink selects its full frame")
			portrait.motion_enabled = false
			portrait._update_frame()
			check(portrait.frame_state == "idle","Reduced motion freezes animation")
			portrait.motion_enabled = true
	await finish("full-frame portrait checks: transparent frames, whole-frame alignment, exposure continuity and rendered playback")
func _source(texture: Texture2D) -> Image:
	var result := Image.new()
	result.load_png_from_buffer(FileAccess.get_file_as_bytes(texture.resource_path))
	return result
func _capture(viewport: SubViewport) -> Image:
	for frame in range(3): await process_frame
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()
