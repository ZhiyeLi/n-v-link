class_name NinjaPRTSFetcher
extends Node
## Native counterpart of tools/prts_resources.py; no Python required in the game.
signal progress(message: String)
const HOSTS := ["prts.wiki","static.prts.wiki","media.prts.wiki","torappu.prts.wiki"]
var cancelled := false
var transport := Callable() # Isolated fixture transport for deterministic failure tests.
var request_node: HTTPRequest
var report: Dictionary = {}
var output_directory := ""

static func allowed(url: String) -> bool:
	if not url.begins_with("https://"): return false
	return url.trim_prefix("https://").get_slice("/",0) in HOSTS

func cancel() -> void:
	cancelled=true
	if request_node != null: request_node.cancel_request()

func get_bytes(url: String) -> Dictionary:
	if cancelled: return {"ok":false,"error":"已取消 / Cancelled"}
	if not allowed(url): return {"ok":false,"error":"只允许 PRTS 公开 HTTPS 网址 / Only public PRTS HTTPS URLs are supported"}
	if transport.is_valid(): return await transport.call(url)
	request_node=HTTPRequest.new()
	request_node.timeout=25.0
	request_node.body_size_limit=64*1024*1024
	request_node.max_redirects=0
	request_node.use_threads=true
	add_child(request_node)
	var start := request_node.request(url,PackedStringArray(["User-Agent: NVLink-ResourceImporter/0.6.1 (local user requested download)","Referer: https://prts.wiki/"]))
	if start!=OK: request_node.queue_free(); request_node=null; return {"ok":false,"error":"请求未启动 / Request failed: "+str(start)}
	# Poll completion as well as cancellation: cancel_request emits no completed signal.
	var completed: Array=[]
	request_node.request_completed.connect(func(result,code,headers,body): completed.append([result,code,headers,body]))
	while completed.is_empty() and not cancelled: await get_tree().process_frame
	request_node.queue_free(); request_node=null
	if cancelled: return {"ok":false,"error":"已取消 / Cancelled"}
	var response: Array=completed[0]
	if response[0]!=HTTPRequest.RESULT_SUCCESS: return {"ok":false,"error":"网络或 TLS 错误 / Network or TLS error: "+str(response[0])}
	if response[1]>=300 and response[1]<400:
		return {"ok":false,"error":"网址重定向，请使用最终角色页网址 / Redirect: use the final character page URL (HTTP %d)"%response[1]}
	if response[1]!=200: return {"ok":false,"error":"HTTP "+str(response[1])}
	return {"ok":true,"bytes":response[3]}

func download(url: String, relative: String, asset: bool = true) -> Dictionary:
	progress.emit("抓取 / Download: "+relative)
	var result := await get_bytes(url)
	if not result.ok:
		report.errors.append({"url":url,"file":relative,"error":result.error})
		progress.emit("失败 / Failed: "+relative+" — "+result.error)
		return result
	var path := output_directory.path_join(relative)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file==null:
		result={"ok":false,"error":"无法写入 / Cannot write file"}
		report.errors.append({"url":url,"file":relative,"error":result.error}); return result
	file.store_buffer(result.bytes); file.close()
	if asset: report.downloads.append({"url":url,"file":relative,"bytes":result.bytes.size(),"sha256":FileAccess.get_sha256(path)})
	progress.emit("成功 / OK: "+relative)
	return result

func finish() -> Dictionary:
	report.cancelled=cancelled
	report.ok=not cancelled and report.errors.is_empty() and not report.downloads.is_empty()
	report.status="success" if report.ok else ("cancelled" if cancelled else ("partial" if not report.downloads.is_empty() else "failed"))
	var label: String={"success":"抓取成功 / Success","partial":"部分失败 / Partial failure","failed":"抓取失败 / Failed","cancelled":"已取消 / Cancelled"}[report.status]
	report.message="%s · %d 个资源成功 / downloaded · %d 项失败 / errors\n%s" % [label,report.downloads.size(),report.errors.size(),output_directory]
	var file := FileAccess.open(output_directory.path_join("resources.json"),FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(report,"\t")); file.close()
	progress.emit(report.message)
	return report

func fetch_character(value: String, root: String, outfit: String = "默认") -> Dictionary:
	cancelled=false
	var name := value.strip_edges()
	if name.begins_with("https://"):
		if not allowed(name) or not name.begins_with("https://prts.wiki/w/"):
			return {"ok":false,"status":"failed","message":"请输入角色名或 PRTS 角色页网址。 / Enter a character name or PRTS character page URL.","downloads":[],"errors":[{"error":"Invalid URL"}]}
		name=name.get_slice("?",0).get_slice("#",0).trim_suffix("/").get_file().uri_decode()
	if name.is_empty() or name.length()>80 or name in [".",".."] or name.contains("/") or name.contains("\\") or name.contains(":"):
		return {"ok":false,"status":"failed","message":"角色名无效。 / Invalid character name.","downloads":[],"errors":[{"error":"Invalid name"}]}
	var folder := name.validate_filename()
	output_directory=root.path_join(folder)
	DirAccess.make_dir_recursive_absolute(output_directory)
	report={"character":name,"page":"https://prts.wiki/w/"+name.uri_encode(),"downloads":[],"errors":[],"models":[],
		"note":"Raw Spine resources are downloaded for inspection. Export GIF/WebM/MP4 to bind gameplay clips; downloading is not animation conversion."}
	var page := await download(report.page,"page.html",false)
	if not page.ok: return finish()
	var regex := RegEx.new()
	regex.compile("id=[\"']spine-root[\"'][^>]*data-id=[\"'](char_[A-Za-z0-9_]+)")
	var match_result := regex.search(page.bytes.get_string_from_utf8())
	if match_result==null:
		report.errors.append({"error":"角色页未找到模型索引 / No model index on character page"}); return finish()
	var meta_url := "https://torappu.prts.wiki/assets/char_spine/"+match_result.get_string(1)+"/meta.json"
	var fetched := await download(meta_url,"model-index.json",false)
	if not fetched.ok: return finish()
	var meta = JSON.parse_string(fetched.bytes.get_string_from_utf8())
	if not meta is Dictionary or not meta.get("skin") is Dictionary or not allowed(str(meta.get("prefix",""))):
		report.errors.append({"error":"模型索引格式无效 / Invalid model index"}); return finish()
	for skin in meta.skin:
		if outfit!="*" and skin!=outfit: continue
		if not meta.skin[skin] is Dictionary: report.errors.append({"error":"Invalid outfit index"}); continue
		for facing in meta.skin[skin]:
			if cancelled: return finish()
			if not meta.skin[skin][facing] is Dictionary: report.errors.append({"error":"Invalid model entry"}); continue
			var stem: String=meta.skin[skin][facing].get("file","")
			if not NinjaSkinPresets.safe_relative(stem): report.errors.append({"error":"Invalid model path"}); continue
			var url: String=str(meta.prefix)+stem
			var relative: String="raw-models/"+(str(skin)+"-"+str(facing)).validate_filename()+"/"+stem.get_file()
			report.models.append({"name":skin+"-"+facing,"url":url})
			await download(url+".skel",relative+".skel")
			var atlas := await download(url+".atlas",relative+".atlas")
			if not atlas.ok: continue
			var pages := 0
			for line in atlas.bytes.get_string_from_utf8().split("\n"):
				line=line.strip_edges()
				if not line.to_lower().ends_with(".png"): continue
				if line!=line.get_file() or not NinjaSkinPresets.safe_relative(line): report.errors.append({"error":"Invalid atlas texture path"}); continue
				pages+=1
				await download(url.get_base_dir()+"/"+line,relative.get_base_dir()+"/"+line)
				if report.downloads.size()>=200: report.errors.append({"error":"资源数超过 200 / Asset limit exceeded"}); return finish()
			if pages==0: report.errors.append({"error":"图集没有纹理页面 / Atlas has no texture pages"})
	if report.models.is_empty(): report.errors.append({"error":"没有找到指定皮肤 / Requested outfit not found: "+outfit})
	return finish()
