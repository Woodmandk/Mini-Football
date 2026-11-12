extends RefCounted
# Thin wrapper around web/net.js (PeerJS in the browser). Does nothing outside the web build.

var web := OS.has_feature("web")
var role := "" # "", "host", "guest"
var connected := false

func _js(code: String):
	if not web:
		return null
	return JavaScriptBridge.eval(code, true)

func host(code: String) -> void:
	role = "host"
	connected = false
	_js("bbNet.host('%s')" % code)

func join(code: String) -> void:
	role = "guest"
	connected = false
	_js("bbNet.join('%s')" % code)

func stop() -> void:
	role = ""
	connected = false
	_js("bbNet.stop()")

func send(d) -> void:
	if not connected:
		return
	_js("bbNet.send(%s)" % JSON.stringify(JSON.stringify(d)))

func poll() -> Array:
	if role == "":
		return []
	var s = _js("bbNet.poll()")
	if s == null or str(s) == "":
		return []
	var r = JSON.parse_string(str(s))
	return r if r is Array else []

func share(code: String) -> String:
	var r = _js("bbNet.share('%s')" % code)
	return str(r) if r != null else ""

func join_code() -> String:
	var r = _js("bbNet.joinCode()")
	return str(r) if r != null else ""

func say(t: String) -> void:
	_js("bbNet.say(%s)" % JSON.stringify(t))
