# Copyright (c) 2025 Liam Sherwin, All rights reserved.
# This file is part of the Constellation Network Engine, licensed under the GPL v3.

class_name ConstellationNode extends NetworkNode
## Class to repersent a node in the session


## Emitted when the role flags change
signal role_flags_changed(node_flags: int)

## Emitted when a command is recieved, only emitted on the local node
signal command_recieved(command: ConstaNetCommand)

## Emitted when the IP address of the remote node is changed
signal node_ip_changed(ip: String)


## The MTU for udp payloads, if this is exceeded the command will be sent as a multipart message
const UDP_MTP: int = 1000


## MessageType
const MessageType: ConstaNetHeadder.Type = ConstaNetHeadder.Type

## Flags
const Flags: ConstaNetHeadder.Flags = ConstaNetHeadder.Flags

## NetworkRole
const RoleFlags: ConstaNetHeadder.RoleFlags = ConstaNetHeadder.RoleFlags


## Enum for TransportModes
enum TransportMode {
	TCP,			## Use TCP for sending data
	UDP,			## Use UDP for sending data
	AUTO			## Use TCP if connected, else UDP
}


## The Constellation NetworkHandler
static var _network: Constellation = null

## Current Network role
var _role_flags: int = RoleFlags.EXECUTOR

## The NodeID of the remote node
var _node_id: String = UUID.v4()

## The IP address of the remote node
var _node_ip: String = ""

## The TCP port that the node is using
var _node_tcp_port: int = 0

## The UDP port that the node is using
var _node_udp_port: int = 0

## UDP peer to send data to this node
var _udp_socket: PacketPeerUDP = PacketPeerUDP.new()

## TCP peer to connect to the node
var _tcp_socket: StreamPeerTCP = StreamPeerTCP.new()

## Previous TCP Peer status
var _tcp_previous_status: int = StreamPeerTCP.Status.STATUS_NONE

## UNIX timestamp of when the last heartbeat was sent
var _last_heart_beat_at: float

## True when a heartbeat ACK message has been received since last refresh
var _has_received_heartbeat_ack: bool = false


## Creates a new ConstellationNode from a ConstaNetDiscovery message
static func create_from_discovery(p_disco: ConstaNetDiscovery) -> ConstellationNode:
	var node: ConstellationNode = ConstellationNode.new()
	
	node._connection_state = ConnectionState.DISCOVERED
	node._node_id = p_disco.origin_id
	node._role_flags = p_disco.role_flags
	node._name = p_disco.node_name
	node._node_ip = p_disco.node_ip
	node._node_udp_port = p_disco.udp_port
	node._node_tcp_port = p_disco.tcp_port
	node._udp_socket.connect_to_host(p_disco.node_ip, p_disco.udp_port)
	
	return node


## Creates a new ConstellationNode in LocalNode mode
static func create_local_node() -> ConstellationNode:
	var node: ConstellationNode = ConstellationNode.new()
	
	node._connection_state = ConnectionState.CONNECTED
	node._node_flags = NodeFlags.LOCAL_NODE
	
	return node


## Creates an unknown node
static func create_unknown_node(p_node_id: String) -> ConstellationNode:
	var node: ConstellationNode = ConstellationNode.new()
	
	node._set_node_id(p_node_id)
	node._mark_as_unknown(true)
	node._set_node_name("UnknownNode")
	
	return node


## init
func _init(p_uuid: String = UUID.v4(), ...p_args: Array[Variant]) -> void:
	super._init(p_uuid, p_args)
	_set_class_name("ConstellationNode")
	
	_settings.register_status("ConnectionState", Data.Type.ENUM, get_connection_state, [connection_state_changed], ConnectionState)\
	.display("NetworkNode", 1)
	
	_settings.register_setting("Session", Data.Type.OBJECT, set_session, get_session, [session_changed])\
	.display("NetworkNode", 2).set_class_filter(NetworkItem, ConstellationSession)
	
	_settings.register_setting("Priority", Data.Type.INT, set_priority, get_priority, [priority_changed])\
	.display("NetworkNode", 3)
	
	_settings.register_status("Ping", Data.Type.FLOAT, get_ping_time, [ping_changed])\
	.display("NetworkNode", 4)
	
	_settings.register_setting("RoleFlags", Data.Type.BITFLAGS, set_role_flags, get_role_flags, [role_flags_changed])\
	.display("ConstellationNode", 0).set_edit_condition(is_local).set_enum_dict(ConstaNetHeadder.RoleFlags)
	
	_settings.register_setting("BindAddress", Data.Type.IP, _network.set_ip_and_interface, _network.get_ip_and_interface, [_network.ip_and_interface_changed])\
	.display("ConstellationNode", 1).set_display_condition(is_local)
	
	_settings.register_status("IpAddress", Data.Type.STRING, get_node_ip, [node_ip_changed])\
	.display("ConstellationNode", 2)


## Called each frame
func _process(delta: float) -> void:
	_tcp_socket.poll()
	var status: StreamPeerTCP.Status = _tcp_socket.get_status()
	
	if status != _tcp_previous_status:
		_tcp_previous_status = status
		
		_handle_tcp_status_update(status)
	
	if status == StreamPeerTCP.STATUS_CONNECTED:
		while _tcp_socket.get_available_bytes() > 0:
			_network._handle_packet_frame(_tcp_socket)


## Connectes TCP to this node
func connect_node() -> Error:
	if is_local():
		return ERR_UNAVAILABLE
	
	if _connection_state == ConnectionState.CONNECTED:
		disconnect_node()
	
	_network._logv("Connecting TCP to ", _node_ip, ":", _node_tcp_port)
	
	var err_code: Error = _tcp_socket.connect_to_host(_node_ip, _node_tcp_port)
	_tcp_socket.set_no_delay(true)
	
	_network._logv("TCP connection began with errcode: ", error_string(err_code))
	
	if err_code:
		_set_connection_status(ConnectionState.CONNECTION_ERROR)
	else:
		_set_connection_status(ConnectionState.CONNECTING)
	
	return err_code


## Disconnects TCP from this node
func disconnect_node() -> void:
	_tcp_socket.disconnect_from_host()
	_tcp_previous_status = -1


## Sends a message to the remote node
func send_message(p_message: ConstaNetHeadder, p_transport_mode: TransportMode = TransportMode.AUTO) -> Error:
	match p_transport_mode:
		TransportMode.TCP:
			return send_message_tcp(p_message)
		
		TransportMode.UDP:
			return send_message_udp(p_message)
		
		TransportMode.AUTO:
			if _tcp_socket.get_status() == StreamPeerTCP.STATUS_CONNECTED:
				return send_message_tcp(p_message)
			
			else:
				return send_message_udp(p_message)
		_:
			return ERR_INVALID_PARAMETER


## Sends a message via UDP to the remote node
func send_message_udp(p_message: ConstaNetHeadder) -> Error:
	if not _udp_socket.is_socket_connected():
		return ERR_CONNECTION_ERROR
	
	var buffer: PackedByteArray = p_message.get_as_packet()
	
	if buffer.size() > UDP_MTP:
		_network._logv(ConstaNetHeadder.Type.keys()[p_message.type], " is too large to send as a single frame (", buffer.size(), ") Sending as multipart")
		
		var multi_part: ConstaNetMultiPart = _auto_fill_headder(ConstaNetMultiPart.new(), Flags.NONE)
		var offset: int = 0
		var chunk_id: int = 0
		
		multi_part.multi_part_id = UUID.v4()
		multi_part.num_of_chunks = int(ceil(buffer.size() / float(UDP_MTP)))
		
		while offset < buffer.size():
			var current_size: int = min(UDP_MTP, buffer.size() - offset)
			var payload: PackedByteArray = buffer.slice(offset, offset + current_size)
			
			multi_part.chunk_id = chunk_id
			multi_part.data = payload
			
			var error: Error = _udp_socket.put_packet(multi_part.get_as_packet())
			
			if error:
				return error
			
			offset += current_size
			chunk_id += 1
		
		return OK
		
	else:
		var errcode: Error = _udp_socket.put_packet(buffer)
		return errcode


## Sends a message over TCP to the remote node
func send_message_tcp(p_message: ConstaNetHeadder) -> Error:
	if _tcp_socket.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		return _tcp_socket.put_data(p_message.get_as_packet())
	
	return ERR_CONNECTION_ERROR


## Joins the given session
func join_session(p_session: NetworkSession) -> bool:
	if not p_session or p_session == _session:
		return false
	
	if is_local():
		return _network.join_session(p_session)
	
	var set_attribute: ConstaNetSetAttribute = _auto_fill_headder(ConstaNetSetAttribute.new(), Flags.REQUEST)
	
	set_attribute.attribute = ConstaNetSetAttribute.Attribute.SESSION
	set_attribute.value = p_session.get_session_id()
	
	send_message_udp(set_attribute)
	return true


## Leavs the current session
func leave_session() -> bool:
	if not get_session():
		return false
	
	if is_local():
		return _network.leave_session()
	
	var set_attribute: ConstaNetSetAttribute = _auto_fill_headder(ConstaNetSetAttribute.new(), Flags.REQUEST)
	
	set_attribute.attribute = ConstaNetSetAttribute.Attribute.SESSION
	set_attribute.value = ""
	
	send_message_udp(set_attribute)
	return true


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


## Gets the Node's IP Address
func get_node_ip() -> String:
	return _node_ip


## Gets the current session ID, or ""
func get_session_id() -> String:
	if _session:
		return _session.get_session_id()
	
	return ""


## Sends a message to set the name of this node on the network
func set_node_name(p_name: String) -> void:
	var set_attribute: ConstaNetSetAttribute = _auto_fill_headder(ConstaNetSetAttribute.new(), Flags.REQUEST)
	
	set_attribute.attribute = ConstaNetSetAttribute.Attribute.NAME
	set_attribute.value = p_name
	
	if is_local() and _set_node_name(p_name):
		_network._send_message_mcast(set_attribute)
	else:
		send_message_udp(set_attribute)


## Sets the role flags
func set_role_flags(p_role_flags: int) -> bool:
	if not is_local():
		return false
	
	return _set_role_flags(p_role_flags)


## Returns True if this node is local
func is_local() -> bool:
	return _node_flags & NodeFlags.LOCAL_NODE


## Returns true if this node is unknown
func is_unknown() -> bool:
	return _node_flags & NodeFlags.UNKNOWN


## Returns true if this RoleFlag includes the EXECUTOR role
func is_executor() -> bool:
	return (_role_flags & RoleFlags.EXECUTOR) != 0


## Returns true if this RoleFlag includes the CONTROLLER role
func is_controller() -> bool:
	return (_role_flags & RoleFlags.CONTROLLER) != 0


## Returns true if this node is the master of its session
func is_sesion_master() -> bool:
	return _is_session_master


## Returns true if the TCP socket is connected
func is_tcp_connected() -> bool:
	var status = _tcp_socket.get_status()
	return status == StreamPeerTCP.STATUS_CONNECTED


## Closes this nodes local object
func delete() -> void:
	super.delete()
	
	disconnect_node()
	_udp_socket.close()
	
	_connection_state = ConnectionState.UNKNOWN


## Sets the network role
func _set_role_flags(p_role_flags: int) -> bool:
	if p_role_flags == _role_flags:
		return false
	
	_role_flags = p_role_flags
	role_flags_changed.emit(_role_flags)
	
	return true


## Sets the connection status
func _set_connection_status(p_status: ConnectionState) -> bool:
	if _connection_state == p_status:
		return false
	
	_network._logv("Setting ConnectionState to remote node: ", get_uname(), ", to: ", ConnectionState.keys()[p_status])
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
	if p_node_name == _name:
		return false
	
	_network._logv("Changing name from: \"", get_uname(), "\", to: \"", p_node_name, "\"")
	_name = p_node_name
	name_changed.emit(_name)
	
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
	_session._add_node(self)
	
	return true


## Sets the nodes session, with out joining the session unlike _set_session
func _set_session_no_join(p_session: ConstellationSession) -> void:
	_session = p_session
	
	if p_session and p_session.get_session_master() == self:
		_mark_as_session_master()
	else:
		_remove_session_master_mark()
	
	session_changed.emit(p_session)
	
	if p_session:
		session_joined.emit(p_session)
	else:
		session_left.emit()


## Leaves the current session
func _leave_session() -> bool:
	if not _session:
		return false
	
	_session._remove_node(self)
	_session = null
	session_left.emit()
	session_changed.emit(null)
	
	return true


## Marks this node as the session master
func _mark_as_session_master() -> void:
	_is_session_master = true
	is_now_session_master.emit()


## Marks this node as not being the session master
func _remove_session_master_mark() -> void:
	_is_session_master = false
	is_no_longer_session_master.emit()


## Marks or unmarks this node as unknown
func _mark_as_unknown(p_unknown: bool) -> void:
	if p_unknown:
		_node_flags |= NodeFlags.UNKNOWN
	else:
		_node_flags &= ~NodeFlags.UNKNOWN
		no_longer_unknown.emit()


## Sends a Discovery Flags.REQUEST to the remote node over TCP
func _send_discovery_request(p_transport_mode: TransportMode = TransportMode.AUTO) -> void:
	var message: ConstaNetDiscovery = _auto_fill_headder(_network._create_discovery(), Flags.REQUEST)
	var errcode: Error = send_message(message, p_transport_mode)
	
	_network._logv("Sending Discovery REQ, via: ", TransportMode.keys()[p_transport_mode], ", to: ", get_uname(), ", errcode: ", error_string(errcode))


## Sends a Discovery Flags.ACKNOWLEDGMENT to the remote node over TCP
func _send_discovery_acknowledment(p_transport_mode: TransportMode = TransportMode.AUTO) -> void:
	var message: ConstaNetDiscovery = _auto_fill_headder(_network._create_discovery(), Flags.ACKNOWLEDGMENT)
	var errcode: Error = send_message(message, p_transport_mode)
	
	_network._logv("Sending Discovery ACK, via: ", TransportMode.keys()[p_transport_mode], ", to: ", get_uname(), ", errcode: ", error_string(errcode))


## Sends a Heartbeat message with Flags.REQUEST to the remote node
func _send_heartbeat_request(p_mode: ConstaNetHeartBeat.Mode = ConstaNetHeartBeat.Mode.HEARTBEAT, p_transport_mode: TransportMode = TransportMode.AUTO):
	var message: ConstaNetHeartBeat = _auto_fill_headder(ConstaNetHeartBeat.new(), Flags.REQUEST)
	message.mode = p_mode
	
	var errcode: Error = send_message(message, p_transport_mode)
	_network._logv("Sending HeartBeat REQ: ", ConstaNetHeartBeat.Mode.keys()[p_mode], ", via: ", TransportMode.keys()[p_transport_mode], ", to: ", get_uname(), ", errcode: ", error_string(errcode))
	
	_last_heart_beat_at = Time.get_unix_time_from_system()


## Sends a Heartbeat message with Flags.ACKNOWLEDGMENT to the remote node
func _send_heartbeat_acknowledment(p_mode: ConstaNetHeartBeat.Mode = ConstaNetHeartBeat.Mode.HEARTBEAT, p_transport_mode: TransportMode = TransportMode.AUTO):
	var message: ConstaNetHeartBeat = _auto_fill_headder(ConstaNetHeartBeat.new(), Flags.ACKNOWLEDGMENT)
	message.mode = p_mode
	
	var errcode: Error = send_message(message, p_transport_mode)
	_network._logv("Sending HeartBeat ACK: ", ConstaNetHeartBeat.Mode.keys()[p_mode], ", via: ", TransportMode.keys()[p_transport_mode], ", to: ", get_uname(), ", errcode: ", error_string(errcode))


## Handles a ConstaNetHeadder
func _handle_message(p_message: ConstaNetHeadder, p_source: StreamPeerTCP = null) -> void:
	match p_message.type:
		MessageType.DISCOVERY:
			_handle_discovery(p_message)
		
		MessageType.GOODBYE when not is_local():
			_handle_goodbye(p_message)
		
		MessageType.SESSION_ANNOUNCE when not is_local():
			_handle_session_announce(p_message)
		
		MessageType.SESSION_JOIN when not is_local():
			_handle_session_join(p_message)
		
		MessageType.SESSION_LEAVE when not is_local():
			_handle_session_leave(p_message)
		
		MessageType.SET_ATTRIBUTE:
			_handle_set_attribute(p_message)
		
		MessageType.HEARTBEAT when not is_local():
			_handle_heartbeat(p_message, p_source)
		
		MessageType.COMMAND when is_local():
			_handle_command(p_message)


## Handles a ConstaNetDiscovery
func _handle_discovery(p_discovery: ConstaNetDiscovery) -> void:
	if not is_local():
		_update_from_discovery(p_discovery)
		
		if p_discovery.is_request():
			_send_discovery_acknowledment()
		
		if [ConnectionState.UNKNOWN, ConnectionState.OFFLINE, ConnectionState.LOST_CONNECTION].has(_connection_state):
			_set_connection_status(ConnectionState.DISCOVERED)
	
	else:
		if p_discovery.is_request():
			_send_discovery_acknowledment()


## Handles a ConstaNetGoodbye
func _handle_goodbye(p_goodbye: ConstaNetGoodbye) -> void:
	_leave_session()
	disconnect_node()
	_udp_socket.close()
	_set_connection_status(ConnectionState.OFFLINE)


## Handles a ConstaNetSessionAnnounce
func _handle_session_announce(p_session_announce: ConstaNetSessionAnnounce) -> void:
	if p_session_announce.is_announcement() and p_session_announce.nodes.has(_node_id):
		_set_session(_network.get_session_from_id(p_session_announce.session_id, true))


## Handles a ConstaNetSessionJoin
func _handle_session_join(p_session_join: ConstaNetSessionJoin) -> void:
	_set_session(_network.get_session_from_id(p_session_join.session_id, true))


## Handles a ConstaNetSessionLeave
func _handle_session_leave(p_session_leave: ConstaNetSessionLeave) -> void:
	_leave_session()


## Handles a ConstaNetSetAttribute
func _handle_set_attribute(p_set_attribute: ConstaNetSetAttribute) -> void:
	match p_set_attribute.attribute:
		ConstaNetSetAttribute.Attribute.NAME:
			if is_local():
				set_node_name(p_set_attribute.value)
			else:
				_set_node_name(p_set_attribute.value)
		
		ConstaNetSetAttribute.Attribute.SESSION when is_local():
			var session: ConstellationSession = _network.get_session_from_id(p_set_attribute.value)
			
			if is_instance_valid(session):
				_network.join_session(session)
			else:
				_network.leave_session()


## Handles a ConstaNetHeartBeat
func _handle_heartbeat(p_heart_beat: ConstaNetHeartBeat, p_source: StreamPeerTCP = null) -> void:
	match _connection_state:
		ConnectionState.AWAITING_CONNECTION_ACK when p_heart_beat.mode == ConstaNetHeartBeat.Mode.CONNECTION and p_heart_beat.is_acknowledgment():
			_set_connection_status(NetworkNode.ConnectionState.CONNECTED)
			_send_heartbeat_request()
		
		_ when _connection_state > ConnectionState.OFFLINE and p_heart_beat.mode == ConstaNetHeartBeat.Mode.CONNECTION and p_heart_beat.is_request() and is_instance_valid(p_source):
			_use_stream(p_source)
			_send_heartbeat_acknowledment(ConstaNetHeartBeat.Mode.CONNECTION, TransportMode.TCP)
			
			_set_connection_status(NetworkNode.ConnectionState.CONNECTED)
			_send_heartbeat_request()
		
		ConnectionState.CONNECTED when p_heart_beat.mode == ConstaNetHeartBeat.Mode.HEARTBEAT and p_heart_beat.is_request():
			_send_heartbeat_acknowledment()
		
		ConnectionState.CONNECTED when p_heart_beat.mode == ConstaNetHeartBeat.Mode.HEARTBEAT and p_heart_beat.is_acknowledgment():
			_ping = Time.get_unix_time_from_system() - _last_heart_beat_at
			_has_received_heartbeat_ack = true
			ping_changed.emit(snappedf(_ping, 0.001))


## Handles a ConstaNetCommand
func _handle_command(p_command: ConstaNetCommand) -> void:
	if p_command.in_session and p_command.in_session != get_session_id():
		return
	
	command_recieved.emit(p_command)
	_network.command_recieved.emit(_network.get_node_from_id(p_command.origin_id), p_command.data_type, p_command.command)


## Updates this nodes info from a discovery packet
func _update_from_discovery(p_discovery: ConstaNetDiscovery) -> void:
	if p_discovery.target_id or is_local():
		return
	
	_set_node_name(p_discovery.node_name)
	_set_role_flags(p_discovery.role_flags)
	
	var reconnect: bool = _node_ip != p_discovery.node_ip or _node_udp_port != p_discovery.udp_port
	
	_node_ip = p_discovery.node_ip
	_node_udp_port = p_discovery.udp_port
	_node_tcp_port = p_discovery.tcp_port
	
	if reconnect:
		_udp_socket.close()
		_udp_socket.connect_to_host(_node_ip, _node_udp_port)


## Autofills a ConstaNetHeadder with the infomation to comunicate to this remote node
func _auto_fill_headder(p_headder: ConstaNetHeadder, p_flags: int = Flags.NONE) -> ConstaNetHeadder:
	p_headder.origin_id = _network.get_node_id()
	p_headder.flags |= p_flags
	
	if not is_local():
		p_headder.target_id = _node_id
	
	return p_headder


## Changed the TCP stream that is used to comunicate to the remote node
func _use_stream(p_stream: StreamPeerTCP) -> void:
	if _tcp_socket == p_stream or is_local():
		return
	
	_network._logv("Changing StreamPeerTCP object for: ", get_uname())
	
	_tcp_socket.disconnect_from_host()
	_tcp_socket = p_stream


## Handles a change of the TCP connection status
func _handle_tcp_status_update(p_status: StreamPeerTCP.Status) -> void:
	match p_status:
		StreamPeerTCP.Status.STATUS_CONNECTED:
			_handle_tcp_status_connected()
			
		StreamPeerTCP.Status.STATUS_ERROR, StreamPeerTCP.Status.STATUS_NONE:
			_handle_tcp_status_error()


## Handles StreamPeerTCP.Status.STATUS_CONNECTED
func _handle_tcp_status_connected() -> void:
	match _connection_state:
		ConnectionState.CONNECTING:
			_set_connection_status(ConnectionState.AWAITING_CONNECTION_ACK)
			_send_heartbeat_request(ConstaNetHeartBeat.Mode.CONNECTION, TransportMode.TCP)


## Handles StreamPeerTCP.Status.STATUS_ERROR
func _handle_tcp_status_error() -> void:
	match _connection_state:
		ConnectionState.CONNECTING:
			_set_connection_status(ConnectionState.CONNECTION_ERROR)


## Runs a refresh step
func _refresh() -> void:
	_network._logv("Last seen delta to: ", get_node_name(), " is: ", _ping)
	
	if not _has_received_heartbeat_ack:
		_network._log(get_node_name(), "took too long to respond")
		_set_connection_status(ConnectionState.LOST_CONNECTION)
	
	_has_received_heartbeat_ack = false
	_send_heartbeat_request()
