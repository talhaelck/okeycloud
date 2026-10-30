class_name Solver
extends RefCounted
## Finds the best way to lay a hand out: the pers and seris with the highest total (jokers score as the tile they
## replace), plus the tiles left over. Works on a 4 x 13 count grid with memoised backtracking: the lowest tile left
## is either kept, put in a per with other colours of its number, or starts a seri (jokers may fill gaps or sit
## below it). Also counts pairs for a çift opening.

var _memo := {}
var _wrap := false


## {points, groups: Array of id arrays, left: ids in no group}.
static func best(ids: Array[int], okey: Vector2i, wrap := false) -> Dictionary:
	return Solver.new()._solve(ids, okey, wrap)


## {count, groups: Array of id pairs, left}. Jokers pair with the highest single tiles first, then with each other.
static func pairs(ids: Array[int], okey: Vector2i) -> Dictionary:
	var by_value := {}
	var jokers: Array[int] = []
	for id in ids:
		if OkeyTiles.is_joker(id, okey):
			jokers.append(id)
		else:
			by_value.get_or_add(OkeyTiles.plays_as(id, okey), []).append(id)
	var groups: Array = []
	var singles: Array[int] = []
	for list: Array in by_value.values():
		while list.size() >= 2:
			groups.append([list.pop_back(), list.pop_back()])
		singles.append_array(list)
	singles.sort_custom(func(a: int, b: int) -> bool: return OkeyTiles.plays_as(a, okey).y > OkeyTiles.plays_as(b, okey).y)
	while not jokers.is_empty() and not singles.is_empty():
		groups.append([singles.pop_front(), jokers.pop_back()])
	while jokers.size() >= 2:
		groups.append([jokers.pop_back(), jokers.pop_back()])
	singles.append_array(jokers)
	return {"count": groups.size(), "groups": groups, "left": singles}


func _solve(ids: Array[int], okey: Vector2i, wrap: bool) -> Dictionary:
	_wrap = wrap
	var counts := PackedByteArray()
	counts.resize(52)
	var pool := {}
	var jokers: Array[int] = []
	for id in ids:
		if OkeyTiles.is_joker(id, okey):
			jokers.append(id)
			continue
		var v := OkeyTiles.plays_as(id, okey)
		var cell := _cell(v.x, v.y)
		counts[cell] += 1
		pool.get_or_add(cell, []).append(id)
	var points := _best(counts, jokers.size())
	var groups: Array = []
	var left: Array[int] = []
	var free := jokers.size()
	while _first(counts) >= 0:
		var choice: Dictionary = _memo[_key(counts, free)][1]
		if choice.has("leave"):
			left.append(pool[choice.leave].pop_back())
			counts[choice.leave] -= 1
			continue
		var group: Array[int] = []
		for cell: int in choice.cells:
			group.append(pool[cell].pop_back())
			counts[cell] -= 1
		for k in choice.jokers:
			group.append(jokers.pop_back())
		free -= choice.jokers
		groups.append(group)
	left.append_array(jokers)
	return {"points": points, "groups": groups, "left": left}


func _best(counts: PackedByteArray, jokers: int) -> int:
	var start := _first(counts)
	if start < 0:
		return 0
	var key := _key(counts, jokers)
	var known: Variant = _memo.get(key)
	if known != null:
		return known[0]
	var n := start / 4 + 1
	var c := start % 4

	counts[start] -= 1
	var best := _best(counts, jokers)
	var choice := {"leave": start}
	counts[start] += 1

	# Per: this tile plus other colours of the same number (lower colours are already decided) and jokers.
	var others: Array[int] = []
	for other in range(c + 1, 4):
		if counts[_cell(other, n)] > 0:
			others.append(_cell(other, n))
	for mask in 1 << others.size():
		var cells: Array[int] = [start]
		for b in others.size():
			if mask & (1 << b):
				cells.append(others[b])
		for k in jokers + 1:
			var size := cells.size() + k
			if size < 3 or size > 4:
				continue
			for cell in cells:
				counts[cell] -= 1
			var value := n * size + _best(counts, jokers - k)
			for cell in cells:
				counts[cell] += 1
			if value > best:
				best = value
				choice = {"cells": cells, "jokers": k}

	# Seri from n upward, with `below` jokers in front of it. A real ace here is always low: a high ace is handled
	# when the ace itself is the lowest tile (below).
	for below in jokers + 1:
		var s := n - below
		if s < 1:
			break
		var used := below
		var points := 0
		for m in range(s, n):
			points += m
		var cells: Array[int] = []
		for m in range(n, 15):
			if m == 14:
				if not _wrap or used >= jokers:
					break
				used += 1
				points += Meld.ACE_HIGH
			elif counts[_cell(c, m)] > 0:
				counts[_cell(c, m)] -= 1
				cells.append(_cell(c, m))
				points += m
			elif used < jokers:
				used += 1
				points += m
			else:
				break
			if m - s + 1 >= 3:
				var value := points + _best(counts, jokers - used)
				if value > best:
					best = value
					choice = {"cells": cells.duplicate(), "jokers": used}
		for cell in cells:
			counts[cell] += 1

	# Seri ending in this ace as 14 (..12-13-1), built downward from 13.
	if _wrap and n == 1:
		var used := 0
		var points := Meld.ACE_HIGH
		var cells: Array[int] = [start]
		counts[start] -= 1
		for m in range(13, 1, -1):
			if counts[_cell(c, m)] > 0:
				counts[_cell(c, m)] -= 1
				cells.append(_cell(c, m))
				points += m
			elif used < jokers:
				used += 1
				points += m
			else:
				break
			if 15 - m >= 3:
				var value := points + _best(counts, jokers - used)
				if value > best:
					best = value
					choice = {"cells": cells.duplicate(), "jokers": used}
		for cell in cells:
			counts[cell] += 1

	_memo[key] = [best, choice]
	return best


static func _cell(colour: int, number: int) -> int:
	return (number - 1) * 4 + colour


static func _first(counts: PackedByteArray) -> int:
	for i in counts.size():
		if counts[i] > 0:
			return i
	return -1


static func _key(counts: PackedByteArray, jokers: int) -> String:
	return counts.hex_encode() + str(jokers)
