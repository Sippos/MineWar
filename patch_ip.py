import re

with open("online_lobby.gd", "r") as f:
    code = f.read()

inject_ready = """	host_btn.pressed.connect(_on_host_pressed)
	join_btn.pressed.connect(_on_join_pressed)
	
	var http = HTTPRequest.new()
	http.name = "IPRequest"
	add_child(http)
	http.request_completed.connect(_on_ip_fetched)
	http.request("https://api.ipify.org")"""

code = code.replace('	host_btn.pressed.connect(_on_host_pressed)\n	join_btn.pressed.connect(_on_join_pressed)', inject_ready)

inject_methods = """
var public_ip = ""

func _on_ip_fetched(result, response_code, headers, body):
	if response_code == 200:
		public_ip = body.get_string_from_utf8()

func _on_host_pressed():
"""

code = code.replace('func _on_host_pressed():\n', inject_methods)

inject_host = """		var local_ip = "127.0.0.1"
		for interface_data in IP.get_local_interfaces():
			if interface_data.has("addresses"):
				for addr in interface_data["addresses"]:
					if addr.begins_with("192.") or addr.begins_with("10.") or addr.begins_with("172."):
						local_ip = addr
		
		var msg = "Hosting on port %d.\\n" % PORT
		if public_ip != "":
			msg += "Public IP (Internet): %s\\n" % public_ip
		msg += "Local IP (LAN): %s\\n" % local_ip
		msg += "Waiting for player to join..."
		
		status_label.text = msg
"""

code = re.sub(r'status_label\.text = "Hosting on port %d\. Waiting for player\.\.\." % PORT\n', inject_host, code)

with open("online_lobby.gd", "w") as f:
    f.write(code)
print("Updated online_lobby.gd")
