# PROBE — verify DataRegistry reaches READY state end-to-end (TD-006 closure check).
# Run: godot --headless --path . --script tests/probes/probe_data_registry_state.gd
extends SceneTree

func _init() -> void:
	# Wait for DataRegistry autoload to complete its boot scan via _ready.
	# In a SceneTree script, autoloads ARE instantiated; we read their state.
	var registry: Node = root.get_node_or_null("DataRegistry")
	if registry == null:
		print("[FAIL] DataRegistry autoload not found in scene tree")
		quit(1); return

	# Wait one frame to ensure all autoloads' _ready ran
	await process_frame

	print("DataRegistry state: ", registry.state)  # 0=UNLOADED 1=LOADING 2=READY 3=ERROR 4=HOT_RELOAD
	for category: String in registry.ORDERED_CATEGORIES:
		var dict: Dictionary = registry._categories.get(category, {})
		var min_required: int = registry.min_content_count.get(category, 0)
		var status: String = "OK" if dict.size() >= min_required else "UNDER MIN"
		print("  ", category, ": loaded=", dict.size(), " min=", min_required, " [", status, "]")

	if registry.state == 2:  # READY
		print("[PASS] DataRegistry is READY — TD-006 closed")
		quit(0)
	else:
		print("[FAIL] DataRegistry is NOT READY (state=", registry.state, ") — TD-006 not closed")
		quit(1)
