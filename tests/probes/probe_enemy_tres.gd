# PROBE — verify all 8 MVP enemy .tres files load + tier-archetype distribution.
# Run: godot --headless --path . --script tests/probes/probe_enemy_tres.gd
extends SceneTree

const EXPECTED: Array = [
	{"id": "hollow_brute",     "tier": 1, "archetype": "bruiser", "is_boss": false, "base_hp": 52},
	{"id": "glowmoth",         "tier": 1, "archetype": "caster",  "is_boss": false, "base_hp": 60},
	{"id": "shellback",        "tier": 1, "archetype": "armored", "is_boss": false, "base_hp": 72},
	{"id": "elder_boar",       "tier": 2, "archetype": "bruiser", "is_boss": false, "base_hp": 195},
	{"id": "moss_druid",       "tier": 2, "archetype": "caster",  "is_boss": false, "base_hp": 185},
	{"id": "vined_knight",     "tier": 2, "archetype": "armored", "is_boss": false, "base_hp": 225},
	{"id": "thorn_guardian",   "tier": 3, "archetype": "bruiser", "is_boss": false, "base_hp": 680},
	{"id": "ancient_rootking", "tier": 3, "archetype": "bruiser", "is_boss": true,  "base_hp": 4818},
]

func _init() -> void:
	var ok: int = 0
	var fail: int = 0
	var boss_count: int = 0
	for spec: Dictionary in EXPECTED:
		var path: String = "res://assets/data/enemies/%s.tres" % spec.id
		var r: Resource = ResourceLoader.load(path)
		if r == null:
			print("[FAIL] ", path, " — null load"); fail += 1; continue
		var pass_row: bool = (
			r.id == spec.id and r.tier == spec.tier and r.archetype == spec.archetype
			and r.is_boss == spec.is_boss and r.base_hp == spec.base_hp
		)
		if pass_row:
			print("[OK] ", spec.id, " tier=", r.tier, " arch=", r.archetype, " hp=", r.base_hp, " boss=", r.is_boss)
			ok += 1
			if r.is_boss:
				boss_count += 1
		else:
			print("[FAIL] ", spec.id, " expected ", spec, " got tier=", r.tier, " arch=", r.archetype, " hp=", r.base_hp, " boss=", r.is_boss)
			fail += 1
	print("---")
	print("OK: ", ok, " / 8 — FAIL: ", fail, " — Boss count: ", boss_count, " (must be 1)")
	if fail == 0 and boss_count == 1:
		print("[PASS] All 8 MVP enemy .tres validated against entities.yaml canonical values; exactly one boss (Ancient Rootking)")
		quit(0)
	else:
		quit(1)
