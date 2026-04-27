## Test fixture: a Screen subclass that records timestamps for each lifecycle hook.
## Used by AC H-02 spy tests to verify the strict on_exit → tween → on_enter ordering
## with direct hook-fire timestamps (story-005 line 119 specifies this).
##
## NOT loaded by the production scene tree — instantiated only inside test bodies and
## attached to a fresh scene tree via swap-in. Lives under tests/ so the CI grep
## (check_screen_hooks.sh) excludes it from production-screen scanning.
class_name SpyScreen extends "res://src/core/scene_manager/screen.gd"

## Records (in order) every lifecycle hook invocation as a Dictionary
## {"hook": "on_enter|on_exit|on_pause|on_resume", "ts_msec": int}.
var hook_log: Array[Dictionary] = []


func on_enter() -> void:
	hook_log.append({"hook": "on_enter", "ts_msec": Time.get_ticks_msec()})


func on_exit() -> void:
	hook_log.append({"hook": "on_exit", "ts_msec": Time.get_ticks_msec()})


func on_pause() -> void:
	hook_log.append({"hook": "on_pause", "ts_msec": Time.get_ticks_msec()})


func on_resume() -> void:
	hook_log.append({"hook": "on_resume", "ts_msec": Time.get_ticks_msec()})
