extends Node
## Persistencia en JSON (user:// se guarda como IndexedDB en web).

const SAVE_PATH := "user://costa3d_save.json"


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_data(data: Dictionary) -> bool:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("No se pudo abrir el archivo de guardado para escritura")
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	return true


func load_data() -> Dictionary:
	if not has_save():
		return {}
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return {}
	var txt := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(txt)
	if typeof(parsed) == TYPE_DICTIONARY:
		return parsed
	push_warning("Guardado corrupto: se ignora")
	return {}


func clear() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
