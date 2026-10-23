class_name NinjaSkinPack
extends RefCounted
## Match exported action names, independent of the operator's name or outfit.
static func scan(folder: String, target: String) -> Dictionary:
	var allowed: Array = NinjaSkinStates.SLOTS.get(target,[])
	var matches := {}
	var unused: Array[String] = []
	var files := DirAccess.get_files_at(folder)
	files.sort()
	var characters := {}
	for name in files:
		if name.count("-")>=2 and name.get_extension().to_lower() in ["png","gif","mp4","webm"]:
			characters[name.get_slice("-",0)]=true
	if characters.size()>1:
		return {"matches":{},"missing":[],"unused":[],"error":"文件夹含多个角色。请将同一角色的动作放入独立子文件夹后导入。"}
	for name in files:
		if not name.get_extension().to_lower() in ["png","jpg","jpeg","webp","gif","mp4","webm"]: continue
		var token := name.get_basename().to_lower()
		var state := ""
		# Prefer specific game states before common PRTS action names.
		for candidate in ["wall_climb","wall_slide","wall_jump","cooldown","charge","death","rise","fall","dash","return","fly","run","fire","move","idle"]:
			if candidate in token: state = candidate; break
		if state.is_empty():
			if "attack" in token or "skill" in token: state = "fire"
			elif "die" in token: state = "death"
			elif "default" in token or "relax" in token: state = "idle"
		if target == "player_actor" and state == "move": state = "run"
		if not state in allowed: unused.append(name); continue
		# Prefer actual animation over a single exported PNG pose of the same state.
		var animated := name.get_extension().to_lower() in ["gif","mp4","webm"]
		if not matches.has(state) or animated and matches[state].get_extension().to_lower() not in ["gif","mp4","webm"]:
			matches[state] = folder.path_join(name)
	var missing: Array[String] = []
	for state in allowed:
		if not matches.has(state): missing.append(NinjaSkinStates.LABELS[state])
	return {"matches":matches,"missing":missing,"unused":unused}
