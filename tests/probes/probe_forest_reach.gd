# PROBE — verify Forest Reach biome + dungeon + 5 floors load with correct schema invariants.
# Run: godot --headless --path . --script tests/probes/probe_forest_reach.gd
extends SceneTree

func _init() -> void:
	var biome: Resource = ResourceLoader.load("res://assets/data/biomes/forest_reach.tres")
	if biome == null: print("[FAIL] biome load null"); quit(1); return
	if biome.id != "forest_reach": print("[FAIL] biome id"); quit(1); return
	if biome.status != "active": print("[FAIL] biome status"); quit(1); return
	if biome.dungeons.size() != 1: print("[FAIL] biome.dungeons.size != 1"); quit(1); return
	print("[OK] biome forest_reach status=active dungeons=", biome.dungeons.size())

	var dungeon: Resource = biome.dungeons[0]
	if dungeon == null: print("[FAIL] dungeon null"); quit(1); return
	if dungeon.id != "forest_reach_dungeon_01": print("[FAIL] dungeon id"); quit(1); return
	if dungeon.biome_id != "forest_reach": print("[FAIL] dungeon back-ref"); quit(1); return
	if dungeon.floors.size() != 5: print("[FAIL] dungeon.floors.size != 5"); quit(1); return
	print("[OK] dungeon ", dungeon.id, " floors=", dungeon.floors.size())

	var expected_floors: Array = [
		{"id":"forest_reach_f1","floor_index":1,"is_boss_floor":false,"enemy_count":2,"first_enemy":"hollow_brute"},
		{"id":"forest_reach_f2","floor_index":2,"is_boss_floor":false,"enemy_count":3,"first_enemy":"hollow_brute"},
		{"id":"forest_reach_f3","floor_index":3,"is_boss_floor":false,"enemy_count":3,"first_enemy":"elder_boar"},
		{"id":"forest_reach_f4","floor_index":4,"is_boss_floor":false,"enemy_count":1,"first_enemy":"thorn_guardian"},
		{"id":"forest_reach_f5","floor_index":5,"is_boss_floor":true,"enemy_count":1,"first_enemy":"ancient_rootking"},
	]
	var boss_count: int = 0
	for i in range(5):
		var f: Resource = dungeon.floors[i]
		var spec: Dictionary = expected_floors[i]
		if f.id != spec.id or f.floor_index != spec.floor_index or f.is_boss_floor != spec.is_boss_floor or f.enemy_list.size() != spec.enemy_count or f.enemy_list[0]["enemy_id"] != spec.first_enemy:
			print("[FAIL] floor ", spec.id, " mismatch — got id=", f.id, " idx=", f.floor_index, " boss=", f.is_boss_floor, " elist=", f.enemy_list)
			quit(1); return
		if f.is_boss_floor: boss_count += 1
		print("[OK] ", f.id, " idx=", f.floor_index, " boss=", f.is_boss_floor, " enemies=", f.enemy_list.size())
	if boss_count != 1: print("[FAIL] boss_count=", boss_count, " (must be 1)"); quit(1); return

	# Cross-resource: every enemy_id must resolve via .tres on disk
	var all_enemy_ids: Array[String] = []
	for f in dungeon.floors:
		for e in f.enemy_list:
			if not all_enemy_ids.has(e.enemy_id):
				all_enemy_ids.append(e.enemy_id)
	for eid in all_enemy_ids:
		var enemy: Resource = ResourceLoader.load("res://assets/data/enemies/%s.tres" % eid)
		if enemy == null:
			print("[FAIL] cross-resource enemy_id ", eid, " did not resolve"); quit(1); return
	print("[OK] cross-resource: all ", all_enemy_ids.size(), " enemy_ids resolve")
	print("[PASS] Forest Reach: 1 biome × 1 dungeon × 5 floors gap-free; F5 boss=ancient_rootking; all enemy_ids resolve")
	quit(0)
