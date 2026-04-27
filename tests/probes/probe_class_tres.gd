extends SceneTree
func _init() -> void:
	for hero_id in ["warrior", "mage", "rogue"]:
		var path := "res://assets/data/classes/%s.tres" % hero_id
		var r: Resource = ResourceLoader.load(path)
		if r == null:
			print("[FAIL] ", path, " — null load")
			quit(1); return
		print("[OK] ", path, " — id=", r.id, " tier=", r.tier, " role=", r.role,
			" archetype=", r.counter_archetype, " L15_attack=", r.base_attack + r.attack_per_level * 14,
			" L15_hp=", r.base_hp + r.hp_per_level * 14, " L15_speed=", r.base_speed + r.speed_per_level * 14)
	print("[PASS] All 3 MVP class .tres files loadable")
	quit(0)
