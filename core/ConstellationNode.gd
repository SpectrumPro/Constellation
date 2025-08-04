# Copyright (c) 2025 Liam Sherwin, All rights reserved.
# This file is part of the Constellation Network Engine, licensed under the GPL v3.

class_name ConstellationNode extends Node
## Class to repersent a node in the session


## Emitted when the connection state is changed
signal connection_state_changed(connection_state: ConnectionState)

## Emitted when the name of the node is changed
signal node_name_changed(node_name: String)

## Emitted when the IP address of the remote node is changed
signal node_ip_changed(ip: String)

## Emitted when the Node joins a session
signal session_joined(session: ConstellationSession)

## Emitted when the node leaves the current session
signal session_left()

## Emitted when the last seen time is changed, IE the node was just seen
signal last_seen_changed(last_seen: float)

## Emitted if this node becomes the master of its session
signal is_now_session_master


## MessageType
const MessageType: ConstaNetHeadder.Type = ConstaNetHeadder.Type

## Flags
const Flags: ConstaNetHeadder.Flags = ConstaNetHeadder.Flags

## NetworkRole
const RoleFlags: ConstaNetHeadder.RoleFlags = ConstaNetHeadder.RoleFlags


## State Enum for remote node
enum ConnectionState {
	UNKNOWN,			## No state assigned yet
	DISCOVERED,			## Node was found via discovery
	CONNECTING,			## Attempting to establish connection
	CONNECTED,			## Successfully connected and active
	LOST_CONNECTION,	## Node timed out or disconnected unexpectedly
}

## Enum for node flags
enum NodeFlags {
	NONE				= 0,		## Default state
	LOCAL_NODE			= 1 << 0,	## This node is a Local node
}


## Current state of the remote node local connection
var _connection_state: ConnectionState = ConnectionState.UNKNOWN

## Node Flags
var _node_flags: int = NodeFlags.NONE

## Current Network role
var _role_flags: int = RoleFlags.EXECUTOR

## The NodeID of the remote node
var _node_id: String = UUID_Util.v4()

## The Name of the remote node
var _node_name: String = "UnNamed ConstellationNode"

## The IP address of the remote node
var _node_ip: String = ""

## Local node state
var _is_local: bool = false

## Session master state
var _is_session_master: bool = false

## The TCP port that the node is using
var _node_tcp_port: int = 0

## The UDP port that the node is using
var _node_udp_port: int = 0

## The Session
var _session: ConstellationSession

## UNIX timestamp of the last time this node was seen on the network
var _last_seen: float = 0

## UDP peer to send data to this node
var _udp_socket: PacketPeerUDP = PacketPeerUDP.new()

## TCP peer to connect to the node
var _tcp_socket: StreamPeerTCP = StreamPeerTCP.new()

## Previous TCP Peer status
var _tcp_previous_status: StreamPeerTCP.Status = StreamPeerTCP.Status.STATUS_NONE


## Creates a new ConstellationNode from a ConstaNetDiscovery message
static func create_from_discovery(p_disco: ConstaNetDiscovery) -> ConstellationNode:
	var node: ConstellationNode = ConstellationNode.new()
	
	node._connection_state = ConnectionState.DISCOVERED
	node._node_id = p_disco.origin_id
	node._role_flags = p_disco.role_flags
	node._node_name = p_disco.node_name
	node._node_ip = p_disco.node_ip
	node._node_udp_port = p_disco.udp_port
	node._node_tcp_port = p_disco.tcp_port
	node._last_seen = Time.get_unix_time_from_system()
	node._udp_socket.connect_to_host(p_disco.node_ip, p_disco.udp_port)
	
	return node


## Creates a new ConstellationNode in LocalNode mode
static func create_local_node() -> ConstellationNode:
	var node: ConstellationNode = ConstellationNode.new()
	
	node._is_local = true
	node._connection_state = ConnectionState.CONNECTED
	node._node_flags = NodeFlags.LOCAL_NODE
	
	return node


## Called each frame
func _process(delta: float) -> void:
	_tcp_socket.poll()
	
	var status: StreamPeerTCP.Status = _tcp_socket.get_status()
	if status != _tcp_previous_status:
		_tcp_previous_status = status
		
		match status:
			StreamPeerTCP.Status.STATUS_NONE:
				_set_connection_status(ConnectionState.LOST_CONNECTION)
			
			StreamPeerTCP.Status.STATUS_CONNECTING:
				_set_connection_status(ConnectionState.CONNECTING)
			
			StreamPeerTCP.Status.STATUS_CONNECTED:
				_set_connection_status(ConnectionState.CONNECTED)
			
			StreamPeerTCP.Status.STATUS_ERROR:
				_set_connection_status(ConnectionState.LOST_CONNECTION)
	
	if status == StreamPeerTCP.STATUS_CONNECTED and _tcp_socket.get_available_bytes():
		var data: Array = _tcp_socket.get_partial_data(_tcp_socket.get_available_bytes())
		var packet: PackedByteArray = data[1]
		
		Network.handle_packet(packet)


## Autofills a ConstaNetHeadder with the infomation to comunicate to this remote node
func auto_fill_headder(p_headder: ConstaNetHeadder, p_flags: int) -> ConstaNetHeadder:
	p_headder.origin_id = Network.get_node_id()
	p_headder.flags |= p_flags
	
	if not is_local():
		p_headder.target_id = _node_id
	
	return p_headder


## Handles a message
func handle_message(p_message: ConstaNetHeadder) -> void:
	match p_message.type:
		MessageType.DISCOVERY:
			_set_node_name(p_message.node_name)
			
			_last_seen = Time.get_unix_time_from_system()
			last_seen_changed.emit(_last_seen)
			
			if _connection_state == ConnectionState.LOST_CONNECTION:
				_set_connection_status(ConnectionState.DISCOVERED)
		
		MessageType.SESSION_ANNOUNCE:
			if p_message.is_announcement() and p_message.nodes.has(_node_id):
				_set_session(Network.get_session_from_id(p_message.session_id))
		
		MessageType.SESSION_JOIN:
			var session: ConstellationSession = Network.get_session_from_id(p_message.session_id)
			if session == Network.get_local_node().get_session():
				connect_tcp()
			
			_set_session(Network.get_session_from_id(p_message.session_id))
		
		MessageType.SESSION_LEAVE:
			var session: ConstellationSession = Network.get_session_from_id(p_message.session_id)
			if session == Network.get_local_node().get_session():
				disconnect_tcp()
			
			_leave_session()
		
		MessageType.SET_ATTRIBUTE:
			p_message = p_message as ConstaNetSetAttribute
			
			match p_message.attribute:
				ConstaNetSetAttribute.Attribute.NAME:
					_set_node_name(p_message.value)


## Sends a message via UDP to the remote node
func send_message_udp(p_message: ConstaNetHeadder) -> void:
	if _udp_socket.is_socket_connected():
		_udp_socket.put_packet(p_message.get_as_string().to_utf8_buffer())


## Connectes TCP to this node
func connect_tcp() -> Error:
	if is_local():
		return ERR_UNAVAILABLE
	
	disconnect_tcp()
	return _tcp_socket.connect_to_host(_node_ip, _node_tcp_port)


## Disconnects TCP from this node
func disconnect_tcp() -> void:
	_tcp_socket.disconnect_from_host()


## Gets the network role
func get_role_flags() -> int:
	return _role_flags


## Gets the connection state
func get_connection_state() -> ConnectionState:
	return _connection_state


## Gets the human readable connection state
func get_connection_state_human() -> String:
	return ConnectionState.keys()[_connection_state].capitalize()


## Gets the NodeFlags
func get_node_flags() -> int:
	return _node_flags


## Gets the Node's NodeID
func get_node_id() -> String:
	return _node_id


## Gets the Node's name
func get_node_name() -> String:
	return _node_name


## Gets the Node's IP Address
func get_node_ip() -> String:
	return _node_ip


## Gets the Node's Session
func get_session() -> ConstellationSession:
	return _session


## Gets the current session ID, or ""
func get_session_id() -> String:
	if _session:
		return _session.get_session_id()
	
	return ""


## Returns the last time this node was seen on the network
func get_last_seen_time() -> float:
	return _last_seen


## Returns True if this node is local
func is_local() -> bool:
	return _node_flags & NodeFlags.LOCAL_NODE
 

## Returns true if this RoleFlag includes the EXECUTOR role
func is_executor() -> bool:
	return (_role_flags & RoleFlags.EXECUTOR) != 0


## Returns true if this RoleFlag includes the CONTROLLER role
func is_controller(p_flags: int) -> bool:
	return (_role_flags & RoleFlags.CONTROLLER) != 0


## Returns true if this node is the master of its session
func is_sesion_master() -> bool:
	return _is_session_master


## Sends a message to set the name of this node on the network
func set_node_name(p_name: String) -> void:
	var set_attribute: ConstaNetSetAttribute = auto_fill_headder(ConstaNetSetAttribute.new(), Flags.REQUEST)
	
	set_attribute.attribute = ConstaNetSetAttribute.Attribute.NAME
	set_attribute.value = p_name
	
	if is_local() and _set_node_name(p_name):
		Network.send_message_broadcast(set_attribute)
	else:
		send_message_udp(set_attribute)


## Sets the network role
func _set_role_flags(p_role_flags: int) -> bool:
	if p_role_flags == _role_flags:
		return false
	
	_role_flags = p_role_flags
	return true


## Sets the connection status
func _set_connection_status(p_status: ConnectionState) -> bool:
	if p_status == _connection_state:
		return false
	
	_connection_state = p_status
	connection_state_changed.emit(_connection_state)
	
	return true


## Sets the nodes ID
func _set_node_id(p_node_id: String) -> bool:
	if p_node_id == _node_id:
		return false
	
	_node_id = p_node_id
	return true


## Sets the nodes name
func _set_node_name(p_node_name: String) -> bool:
	if p_node_name == _node_name:
		return false
	
	_node_name = p_node_name
	node_name_changed.emit(_node_name)
	
	return true


## Sets the nodes IP
func _set_node_ip(p_node_ip: String) -> bool:
	if p_node_ip == _node_ip:
		return false
	
	_node_ip = p_node_ip
	node_ip_changed.emit(_node_ip)
	
	return true


## Sets the nodes session
func _set_session(p_session: ConstellationSession) -> bool:
	if _session or not is_instance_valid(p_session):
		return false
	
	_session = p_session
	session_joined.emit(_session)
	
	_remove_session_master_mark()
	_session._add_node(self)
	
	return true


## Leaves the current session
func _leave_session() -> bool:
	if not _session:
		return false
	
	_session._remove_node(self)
	_session = null
	session_left.emit()
	
	return true


## Marks this node as the session master
func _mark_as_session_master() -> void:
	_is_session_master = true
	is_now_session_master.emit()


## Marks this node as not being the session master
func _remove_session_master_mark() -> void:
	_is_session_master = false
