extends SceneTree
## Finds props in the room that float above, or sink into, whatever they stand on. Every mesh in the room gets a
## trimesh collider; each small prop (a direct child model of the room or a background table, raised off the floor)
## casts rays down from under its footprint and must land on something within MAX_GAP. Exit code 1 on failure.
##   godot --path . --headless --script tests/floating_props_test.gd

const MAX_GAP := 0.012
const MAX_SINK := 0.015


func _init() -> void:
	RiggedDayi.demo = false
	var game: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	for i in 5:
		await process_frame
	var room: Node3D = game.get_node("Room")
	var props: Array[Node3D] = []
	for holder: Node in [room] + room.get_children().filter(func(n: Node) -> bool: return n.get_child_count() > 0):
		for child in holder.get_children():
			if child is Node3D and child.get_class() == "Node3D" and child.get_script() == null and not _hung(child):
				var box := _bounds(child)
				if box.size != Vector3.ZERO and box.size.y < 0.8 and box.position.y > 0.1:
					props.append(child)
	# Colliders for everything with a mesh (furniture, walls, tables...).
	var bodies := {}
	for mesh: MeshInstance3D in room.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null or not mesh.is_visible_in_tree():
			continue
		mesh.create_trimesh_collision()
		for body in mesh.get_children():
			if body is StaticBody3D:
				bodies[body] = mesh
	await physics_frame
	await physics_frame
	var space := room.get_world_3d().direct_space_state
	var failures: Array[String] = []
	for prop in props:
		var box := _bounds(prop)
		var own: Array[RID] = []
		for mesh: MeshInstance3D in prop.find_children("*", "MeshInstance3D", true, false):
			for body in mesh.get_children():
				if body is StaticBody3D:
					own.append(body.get_rid())
		var bottom := box.position.y
		var best := -INF
		var centre := box.get_center()
		# Middle and near the corners: a hollow crate on another stands on its rim.
		for offset in [Vector2.ZERO, Vector2(0.3, 0.3), Vector2(-0.3, 0.3), Vector2(0.3, -0.3), Vector2(-0.3, -0.3), Vector2(0.45, 0.45), Vector2(-0.45, -0.45), Vector2(0.45, -0.45), Vector2(-0.45, 0.45)]:
			var at := Vector3(centre.x + offset.x * box.size.x, bottom + 0.05, centre.z + offset.y * box.size.z)
			var query := PhysicsRayQueryParameters3D.create(at, at + Vector3.DOWN * 2.0)
			query.exclude = own
			var hit := space.intersect_ray(query)
			if hit:
				best = maxf(best, hit.position.y)
		var gap := bottom - best
		var name := "%s/%s at %s" % [prop.get_parent().name, prop.name, centre.snapped(Vector3.ONE * 0.01)]
		if best == -INF:
			failures.append("%s: nothing under it" % name)
		elif gap > MAX_GAP:
			failures.append("%s: floats %.1f cm above the surface" % [name, gap * 100.0])
		elif gap < -MAX_SINK:
			failures.append("%s: sunk %.1f cm into the surface" % [name, -gap * 100.0])
	print("FLOATING_PROPS %s (%d props checked)" % ["PASS" if failures.is_empty() else "FAIL", props.size()])
	for failure in failures:
		print("  ", failure)
	quit(0 if failures.is_empty() else 1)


# Hung on a wall or the ceiling (Decor and room.gd mark these), or carried by someone walking about.
func _hung(node: Node) -> bool:
	while node:
		if node.has_meta("hung") or node.has_meta("rests_on_rim") or node is Visitors:
			return true
		node = node.get_parent()
	return false


func _bounds(node: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for mesh: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null:
			continue
		var box := mesh.global_transform * mesh.get_aabb()
		out = box if first else out.merge(box)
		first = false
	return out
