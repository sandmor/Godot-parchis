extends "res://tests/support/test_case.gd"
## Board geometry can be validated without loading the game UI or dice.
func _run() -> void:
	var board := preload("res://CyberBoard.gd").new()
	root.add_child(board)
	check(board.main_path_positions.size() == 96, "Circuit must contain 96 cells")
	check(board.safe_indices.size() == 12, "Circuit must contain 12 seguro cells")
	check(board.launch_indices.size() == 4, "Circuit must contain 4 salidas")
	for index in board.launch_indices:
		check(index not in board.safe_indices, "Salidas and seguros must be distinct")
		check(board.is_protected_cell(index), "Salidas are protected")
	var occupied := {}
	for index in range(96):
		var cell: Vector3 = board.main_path_positions[index]
		check(not occupied.has(cell), "Duplicate circuit cell")
		occupied[cell] = true
		var next: Vector3 = board.main_path_positions[(index + 1) % 96]
		check(cell.distance_to(next) <= board.tile_spacing + 0.001, "Disconnected circuit")
	for team in range(4):
		check(board.home_path_positions[team].size() == 10, "Each team has ten home spaces")
		check(board.jail_positions[team].size() == 4, "Each team has four jail spaces")
		check(board.pawn_nodes[team].size() == 4, "Each team has four pawns")
		for cell in board.home_path_positions[team]:
			check(not occupied.has(cell), "Home lane overlaps another lane")
			occupied[cell] = true
		for index in range(1, 10):
			check(board.home_path_positions[team][index].length() < board.home_path_positions[team][index - 1].length(), "Home lane must lead inward")
	var preserved_children: int = board.get_child_count()
	var authored := Node3D.new()
	authored.name = "AuthoredChild"
	board.add_child(authored)
	board.generate_board()
	board.generate_board()
	await process_frame
	check(board.get_node_or_null("AuthoredChild") == authored, "Rebuild deleted authored geometry")
	check(board.get_child_count() == preserved_children + 1, "Rebuild duplicated generated geometry")
	check(board.main_path_positions.size() == 96, "Rebuild preserves circuit size")
	await finish("board checks: connected circuit, protected cells, home lanes and safe rebuilds")
