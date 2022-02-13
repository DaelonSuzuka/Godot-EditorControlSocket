tool
extends EditorPlugin

# ******************************************************************************

var debug = true
func set_debug(state):
	debug = state

var prefix = '[EditorControlSocket]'
func Log(s1='', s2='', s3='', s4='', s5=''):
	if debug:
		prints(prefix, str(s1), str(s2), str(s3), str(s4), str(s5))

# ******************************************************************************

var port = 7000

var websocket = null
func _process(delta):
	if websocket:
		websocket.poll()

func get_plugin_name():
	return 'EditorControlSocket'

func _enter_tree():
	name = 'EditorControlSocket'

	var socket = WebSocketServer.new()
	var result = socket.listen(port, PoolStringArray())
	if result != OK:
		return
	Log('websocket server started successfully on port', port)
	websocket = socket
 
	websocket.connect('client_connected', self, '_on_client_connected')
	websocket.connect('client_disconnected', self, '_on_client_disconnected')
	websocket.connect('data_received', self, '_respond')

func _on_client_connected(id, protocol):
	Log('client connected', id)
	websocket.get_peer(id).set_write_mode(WebSocketPeer.WRITE_MODE_TEXT)

func _on_client_disconnected(id, was_clean_close):
	Log('client disconnected', id)

func _exit_tree():
	if websocket:
		websocket.stop()

# ******************************************************************************

func _respond(id):
	var text = websocket.get_peer(id).get_packet().get_string_from_utf8()
	var message = JSON.parse(text).result

	var request_type = message.get('request-type')
	var message_id = message.get('message-id')

	var response = {}

	if message_id:
		response['message-id'] = message_id

	match request_type:
		'GetAuthRequired':
			Log('handshake received')
			response['authRequired'] = false
		'Eval':
			var eval = message['eval-string']
			var result = _evaluate(eval, self)
			Log('evaluating:', eval, '|', result)
			response['result'] = result
		'SetDebug':
			debug = message['debug']
			response['status'] = 'ok'

	websocket.get_peer(id).put_packet(JSON.print(response).to_utf8())

# ******************************************************************************

static func _evaluate(input:String, global:Object=null, locals:Dictionary={}, _show_error:bool=true):
	var _evaluated_value = null
	var _expression = Expression.new()
	
	var _err = _expression.parse(input, PoolStringArray(locals.keys()))
	
	if _err != OK:
		return _expression.get_error_text()
	else:
		_evaluated_value = _expression.execute(locals.values(), global, _show_error)
		
		if _expression.has_execute_failed():
			return input
		
	return _evaluated_value