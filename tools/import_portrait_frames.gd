extends SceneTree
## Normalize selected, finished imagegen outputs to the game's portrait canvas.
## No cropping, masks, recoloring, facial overlays or compositing.
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	assert(args.size() == 1,"Pass a JSON array of {source,destination} paths")
	var entries: Array = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var pending: Array[Dictionary] = []
	for entry in entries:
		var source := Image.load_from_file(str(entry.source))
		assert(source and not source.is_empty(),"Cannot read source portrait")
		assert(source.get_width() == source.get_height(),"Preserve the original square framing")
		assert(source.get_format() == Image.FORMAT_RGBA8,"A portrait must have an alpha channel")
		assert(source.get_pixel(0,0).a < .01,"A portrait must have a transparent backdrop")
		assert(str(entry.destination).begins_with("res://assets/factions/portraits/"),"Destination must be a project portrait")
		source.resize(512,512,Image.INTERPOLATE_LANCZOS)
		pending.append({"image":source,"destination":str(entry.destination)})
	for entry in pending:
		assert(entry.image.save_png(entry.destination) == OK,"Cannot save finished portrait")
	print("Imported %d finished 512px RGBA portrait frames without compositing" % pending.size())
	quit()
