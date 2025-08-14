class_name DataStreamDemo extends Control


## The Color Rect
@export var color_rect: ColorRect


## Current color
var _color: Color = Color.RED

## Step value
var _step: float = 5

## The network local node
var _local_node: ConstellationNode = Network.get_local_node()

## The command to send
var _command: ConstaNetCommand = _local_node.auto_fill_headder(ConstaNetCommand.new(), ConstaNetHeadder.Flags.REQUEST)


func _ready() -> void:
	_local_node.is_now_session_master.connect(_on_local_node_is_session_master)
	_local_node.is_now_longer_session_master.connect(_on_local_node_is_no_longer_session_master)
	_local_node.session_left.connect(_local_node_session_left)
	_local_node.command_recieved.connect(_on_local_node_command_recieved)
	
	_command.command = Color.WHITE
	_command.data_type = TYPE_FLOAT
	
	set_process(false)


## Process
func _process_step() -> void:
	#_color.h += _step * delta
	#color_rect.color = _color
	#
	#_command.command = _color
	
	color_rect.position.x = wrap(color_rect.position.x + (_step / 4), 0, size.x)
	_command.command = color_rect.position.x
	
	#print(_local_node.get_node_name(), " Is Sending: ", _command.command)
	_local_node.get_session().send_pre_existing_command(_command, ConstellationSession.NodeFilter.ALL_OTHER_NODES)


## Called when the local node becomes the session master
func _on_local_node_is_session_master() -> void:
	$Timer.start()


## Called when the local node is no longer the session master
func _on_local_node_is_no_longer_session_master() -> void:
	$Timer.stop()


## Called when the local node leaves a session
func _local_node_session_left() -> void:
	$Timer.stop()
	color_rect.position.x = 0


## Called when the local nodes recieves a command
func _on_local_node_command_recieved(p_command: ConstaNetCommand) -> void:
	if p_command.data_type == TYPE_FLOAT:
		color_rect.position.x = p_command.command
		#_color = p_command.command
		#color_rect.color = _color
