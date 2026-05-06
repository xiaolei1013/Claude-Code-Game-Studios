# Sprint 12 S12-N3 — Save persist + load latency benchmarks.
#
# Closes Story 016 AC-7 (persist p95 ≤ 10 ms PC ADVISORY) + AC-8 (load p95
# ≤ 50 ms PC ADVISORY) deferred from Sprint 11 S11-M4. Per ADR-0004
# §Performance Budget. Sprint 13+ Story 015 owns the mobile-min-spec
# verification (BLOCKING AC-SL-11) — this CI suite is PC-only.
#
# Methodology (per Story 016 §Performance verification approach):
#   - 100 successive request_full_persist + request_full_load cycles using
#     the live /root/* autoload chain (post-S11-M4 consumer ecosystem).
#   - Time.get_ticks_usec() deltas around each call; compute p50/p95/p99.
#   - Hard-ceiling at 5× spec budget per the existing perf-test pattern
#     (matchup_resolver_perf_test, combat_resolver_perf_test) to absorb
#     CI variance + warm-up jitter without flapping.
#   - Soft-warn at 1× spec budget (early regression signal).
#
# Test groups:
#   A — Persist latency p50/p95/p99 + hard-ceiling assertion.
#   B — Load latency p50/p95/p99 + hard-ceiling assertion.
#   C — Envelope size sanity (44-byte overhead + reasonable payload).
#
# DEFERRED to Sprint 13+ Story 015 / mobile certification:
#   - Mobile min-spec p95 measurement (BLOCKING AC-SL-11 ≤ 50 ms persist).
#     Cannot run headlessly; needs platform certification harness.
#   - I/O hot-cache vs cold-cache differential (CI baseline is hot-cache;
#     real player launch is cold-cache).
extends GdUnitTestSuite

const SaveLoadScript = preload("res://src/core/save_load_system/save_load_system.gd")

const FIXTURE_SAVE_PATH: String = "user://test_fixture_s12_n3_perf.dat"

# Spec budgets per ADR-0004 §Performance Budget + Story 016 AC-7/AC-8.
const PERSIST_SPEC_BUDGET_USEC: int = 10_000     # 10 ms PC ADVISORY
const LOAD_SPEC_BUDGET_USEC: int = 50_000        # 50 ms PC ADVISORY

# Hard ceiling (5× spec) absorbs CI variance + warm-up jitter per the
# matchup_resolver_perf_test convention.
const PERSIST_HARD_CEILING_USEC: int = PERSIST_SPEC_BUDGET_USEC * 5
const LOAD_HARD_CEILING_USEC: int = LOAD_SPEC_BUDGET_USEC * 5

const SAMPLE_COUNT: int = 100


# ---------------------------------------------------------------------------
# Hygiene barrier — reset state + clean fixture file
# ---------------------------------------------------------------------------

func _reset_state() -> void:
	var sl: Node = get_tree().root.get_node_or_null("SaveLoadSystem")
	if sl == null:
		return
	sl._state = SaveLoadScript.State.UNLOADED
	sl.save_file_path = FIXTURE_SAVE_PATH
	sl._needs_rekey_persist = false


func _delete_fixture_files() -> void:
	for suffix: String in ["", ".tmp", ".bak"]:
		var path: String = FIXTURE_SAVE_PATH + suffix
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func before_test() -> void:
	_reset_state()
	_delete_fixture_files()


func after_test() -> void:
	_reset_state()
	_delete_fixture_files()
	var sl: Node = get_tree().root.get_node_or_null("SaveLoadSystem")
	if sl != null:
		sl.save_file_path = "user://save_slot_1.dat"


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _percentile(samples: Array[int], p: float) -> int:
	# samples must be sorted ascending. p in [0.0, 1.0]; e.g., 0.95 = p95.
	if samples.is_empty():
		return 0
	var idx: int = int(floor(float(samples.size()) * p))
	if idx >= samples.size():
		idx = samples.size() - 1
	return samples[idx]


# ===========================================================================
# Group A — Persist latency benchmark (AC-7)
# ===========================================================================

func test_persist_latency_p95_within_hard_ceiling_over_100_calls() -> void:
	var sl: Node = get_tree().root.get_node_or_null("SaveLoadSystem")
	# Pin to READY for the persist loop (the round-trip test uses the same
	# manual pin since the live autoload boot starts in UNLOADED).
	sl._state = SaveLoadScript.State.READY

	# Warm-up: 5 calls to absorb JIT / cache / first-write costs out of the
	# measured sample. Per the matchup_resolver_perf_test convention.
	for _w: int in range(5):
		sl.request_full_persist("perf_warmup")

	# Act — 100 timed calls.
	var samples: Array[int] = []
	for _i: int in range(SAMPLE_COUNT):
		var t0: int = Time.get_ticks_usec()
		sl.request_full_persist("perf_sample")
		var t1: int = Time.get_ticks_usec()
		samples.append(t1 - t0)

	samples.sort()

	# Compute percentiles.
	var p50: int = _percentile(samples, 0.50)
	var p95: int = _percentile(samples, 0.95)
	var p99: int = _percentile(samples, 0.99)

	# Soft-warn at 1× spec budget (early regression signal). Logged only;
	# does not fail the test. Use push_warning so CI captures it.
	if p95 > PERSIST_SPEC_BUDGET_USEC:
		push_warning(
			"Persist p95 = %d µs exceeds spec budget %d µs (10 ms PC ADVISORY) — p50=%d p99=%d. Hard ceiling = %d µs."
			% [p95, PERSIST_SPEC_BUDGET_USEC, p50, p99, PERSIST_HARD_CEILING_USEC]
		)

	# Hard-fail at 5× spec budget. Absorbs CI variance + warm-up jitter
	# without flapping on slow CI runners.
	assert_int(p95).is_less(PERSIST_HARD_CEILING_USEC)


# ===========================================================================
# Group B — Load latency benchmark (AC-8)
# ===========================================================================

func test_load_latency_p95_within_hard_ceiling_over_100_calls() -> void:
	var sl: Node = get_tree().root.get_node_or_null("SaveLoadSystem")
	# Establish a valid envelope on disk for the load benchmark to read.
	sl._state = SaveLoadScript.State.READY
	sl.request_full_persist("perf_load_setup")

	# Warm-up: 5 load cycles. Reset state UNLOADED before each (load only
	# legal from UNLOADED per the state guard).
	for _w: int in range(5):
		sl._state = SaveLoadScript.State.UNLOADED
		sl.request_full_load("perf_warmup")

	# Act — 100 timed load calls. Reset state between each.
	var samples: Array[int] = []
	for _i: int in range(SAMPLE_COUNT):
		sl._state = SaveLoadScript.State.UNLOADED
		var t0: int = Time.get_ticks_usec()
		sl.request_full_load("perf_sample")
		var t1: int = Time.get_ticks_usec()
		samples.append(t1 - t0)

	samples.sort()

	var p50: int = _percentile(samples, 0.50)
	var p95: int = _percentile(samples, 0.95)
	var p99: int = _percentile(samples, 0.99)

	if p95 > LOAD_SPEC_BUDGET_USEC:
		push_warning(
			"Load p95 = %d µs exceeds spec budget %d µs (50 ms PC ADVISORY) — p50=%d p99=%d. Hard ceiling = %d µs."
			% [p95, LOAD_SPEC_BUDGET_USEC, p50, p99, LOAD_HARD_CEILING_USEC]
		)

	assert_int(p95).is_less(LOAD_HARD_CEILING_USEC)


# ===========================================================================
# Group C — Envelope size sanity
# ===========================================================================

func test_persist_envelope_size_at_mvp_scale_is_under_50_kb() -> void:
	# The Save/Load GDD AC-SL-12 references a 50 KB target for the MVP
	# envelope. This sanity check asserts the live persist at session-
	# initial-state stays well under that ceiling. Sprint 12+ pre-perf
	# testing — flags any regressive payload bloat (e.g., accidentally
	# persisting unbounded telemetry data).
	var sl: Node = get_tree().root.get_node_or_null("SaveLoadSystem")
	sl._state = SaveLoadScript.State.READY

	sl.request_full_persist("envelope_size_check")

	var f: FileAccess = FileAccess.open(FIXTURE_SAVE_PATH, FileAccess.READ)
	var size: int = f.get_length()
	f.close()

	# Must be > 44 (header + HMAC overhead) and well under 50 KB.
	assert_int(size).is_greater(44)
	assert_int(size).is_less(50_000)
