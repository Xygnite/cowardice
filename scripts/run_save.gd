class_name RunSave
extends RefCounted
## The run in progress, saved at a campfire, apart from Meta's between-runs save. One at a time:
## game.gd deletes it when a run ends or a new one starts, so a loss can't be undone by reloading.

const PATH := "user://run.json"
const VERSION := 1


## Writes `data` with the version, through a temp file, so a crash mid-write can't leave half a save.
## JSON.from_native keeps ints as ints and dice's int-keyed dictionaries as they are.
static func write(data: Dictionary, path := PATH) -> bool:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("Could not save the run to %s" % tmp)
		return false
	var ok := f.store_string(JSON.stringify(JSON.from_native(data.merged({"version": VERSION}))))
	f.close()
	if not ok or f.get_error() != OK:  # a part-written temp file must not replace the good save
		DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))
		push_error("Could not save the run to %s" % tmp)
		return false
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(path)) != OK:
		push_error("Could not save the run to %s" % path)
		return false
	return true


## The saved run, or {} if there is none, it is unreadable, or it is from another version.
static func read(path := PATH) -> Dictionary:
	if not FileAccess.file_exists(path) and FileAccess.file_exists(path + ".tmp"):
		path += ".tmp"  # Windows' rename removes the old save before moving the new one in; a crash between leaves only this
	if not FileAccess.file_exists(path):
		return {}
	var json := JSON.new()  # parse() on an instance fails quietly, where JSON.parse_string logs an error
	if json.parse(FileAccess.get_file_as_string(path)) != OK or not json.data is Dictionary:
		return {}
	var data = JSON.to_native(json.data)
	return data if data is Dictionary and data.get("version") == VERSION else {}


static func exists(path := PATH) -> bool:
	return not read(path).is_empty()


static func erase(path := PATH) -> void:
	for p in [path, path + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
