class_name NinjaSkinStates
extends RefCounted
const LABELS := {"base":"静态 / 后备贴图","idle":"待机","move":"移动","dash":"冲刺 / 追击","charge":"瞄准 / 前摇",
	"fire":"射击","cooldown":"冷却","return":"回位","fly":"飞行","active":"触发","run":"跑动",
	"rise":"上升","fall":"下落","wall_climb":"贴墙上升","wall_slide":"滑墙","wall_jump":"蹬墙","death":"死亡"}
const SLOTS := {
	"drone_patrol":["move"],"drone_scout":["move","dash"],
	"drone_laser":["move","charge","fire","cooldown"],"drone_chain":["move","charge","fire","cooldown"],
	"guard":["idle","dash"],"thwump":["idle","dash","return"],"turret":["idle","charge","fire","cooldown"],
	"rocket_base":["idle","fire"],"rocket":["fly"],"mine":["idle"],"bounce":["idle","active"],"pad":["idle","active"],
	"gold":["idle"],"background":["idle"],
	"player_actor":["idle","run","rise","fall","wall_climb","wall_slide","wall_jump","death"]}

static func state(e: Dictionary) -> String:
	match int(e.type):
		6:
			if int(e.p[4]) == 0: return "dash" if e.chasing else "move"
			return {0:"move",2:"charge",3:"fire",4:"cooldown"}.get(int(e.state),"move")
		4: return "dash" if e.state == 1 else "idle"
		8: return ["idle","dash","return"][clampi(e.state,0,2)]
		3:
			if e.flash > 0: return "fire"
			return ["idle","charge","cooldown"][clampi(e.state,0,2)]
		10: return "fly" if e.state == 1 else "idle"
		1: return "active" if e.pos.distance_to(e.home)>1 else "idle"
		2: return "active" if e.cooldown>0 else "idle"
	return "idle"

static func player(body: NinjaBody) -> String:
	if not body.alive: return "death"
	var pose := body.pose_name()
	if pose == "takeoff": return "rise"
	if pose == "run": return "run"
	return pose if SLOTS.player_actor.has(pose) else "idle"
