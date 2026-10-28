# Copyright (c) 2025 Liam Sherwin, All rights reserved.
# This file is part of the Constellation Network Engine, licensed under the GPL v3.

class_name Constellation extends NetworkHandler
## NetworkHandler for the Constellation Network Engine


## Emited when the IP or interface name is changed
signal ip_and_interface_changed(ipaddr: IPAddr)


## The Multicast group
const MCAST_GROUP: String = "239.38.23.1"

## UDP bind port
const UDP_MCAST_PORT: int = 3823

## Interval in second in which to send discovery messages to the network
const NODE_DISCO_INTERVAL: int = 10

## Time in seconds for a responce from a node or session before its deemed offline
const NODE_DISCO_TIMEOUT: int = 2

## Interval in seconds in which to send session discovery messages to the network
const SESSION_DISCO_INTERVAL: int = 10

## Interval in seconds to check that the network link is up, link will be auto checked if any socker error is recieved
const LINK_CHECK_INTERVAL: float = 5

## Interval in seconds to check for network link when it is currently down
const LINK_CHECK_ERROR_INTERVAL: float = 0.5

## Time in seconds to delay the node restart after network link is back up
## Allows time for the system to re-asign IP addressd and firewall rules
const LINK_CHECK_RESTART_DELAY: float = 2

## Max time to wait in second for the next chunk of a multipart message to be recieved
## If the next chunk is not recieved within this time, the whole buffer will be discarded
const MULTI_PART_MAX_WAIT: int = 10



## ConstaNetGoodbye reason for going offline
const GOODBYE_REASON_GOING_OFFLINE: String = "Node Going Offline"


## TCPServer to handle incomming connection from other nodes
var _tcp_socket: TCPServer = TCPServer.new()

## UDP server to handle incomming UDP messages from other nodes
var _udp_socket: PacketPeerUDP = PacketPeerUDP.new()

## The current TCP port
var _tcp_port: int = 0

## The current UDP port
var _udp_port: int = 0

## PacketPeerUDP to transmit to multicast
var _mcast_tx: PacketPeerUDP = PacketPeerUDP.new()

## PacketPeerUDP to recive from multicast
var _mcast_rx: PacketPeerUDP = PacketPeerUDP.new()

## Array containing each connected StreamPeerTCP
var _connected_tcp_peers: Array[StreamPeerTCP]

## Stores RX data buffers for each connected StreamPeerTCP
var _tcp_buffers: Dictionary[StreamPeerTCP, PackedByteArray]

## True when the network interface and address have network link
var _ip_link_up: bool = false

## Network Role
var _role_flags: int = ConstaNetHeadder.RoleFlags.EXECUTOR

## The ConstellationNode for the local node
var _local_node: ConstellationNode

## Stores all known devices by thier NodeID
var _known_nodes: Dictionary[String, ConstellationNode] = {}

## Stores all unknown nodes yet to be found on the network
var _unknown_nodes: Dictionary[String, ConstellationNode]

## All known network session
var _known_sessions: Dictionary[String, ConstellationSession]

## All Unknown sessions
var _unknown_sessions: Dictionary[String, ConstellationSession]

## Timer for node discovery
var _disco_timer: Timer = Timer.new()

## Timer for session auto create
var _session_auto_create_timer: Timer = Timer.new()

## Timer used for the network link check
var _link_check_timer: Timer = Timer.new()

## Timer used to delay the auto restart when network link returns
var _link_up_restart_delay: Timer = Timer.new()

## Stores all multi-part buffers still awaiting new data
var _active_multi_parts: Dictionary[String, IncommingMultiPart]


## init
func _init(p_uuid: String = UUID.v4(), ...p_args: Array[Variant]) -> void:
	super._init(p_uuid, p_args)
	
	_set_class_name("Constellation")
	set_uname("Constellaton", true)
	
	ConstellationNode._network = self
	ConstellationSession._network = self
	ConstaNetHeadder._network = self
	
	_local_node = ConstellationNode.create_local_node()
	_local_node.name_changed.connect(_on_local_node_name_changed)
	_local_node.session_changed.connect(_on_local_node_session_changed)
	
	settings_manager.register_setting(
		"Session", 
		Data.Type.OBJECT, 
		_local_node.set_session, 
		_local_node.get_session, 
		[_local_node.session_changed]
	).set_class_filter(NetworkItem, ConstellationSession)
	
	set_process(false)


## ready
func _ready() -> void:
	ConstellationConfig.load_config("res://ConstellaitionConfig.gd")
	ConstellationConfig.load_user_config()
	
	_local_node._set_node_ip(ConstellationConfig.bind_address)
	_local_node._set_node_name(ConstellationConfig.node_name)
	_local_node._set_node_id(ConstellationConfig.node_id)
	
	_disco_timer.set_autostart(false)
	_disco_timer.set_one_shot(false)
	_disco_timer.set_wait_time(NODE_DISCO_INTERVAL)
	_disco_timer.timeout.connect(_on_node_disco_timeout)
	
	_session_auto_create_timer.set_autostart(false)
	_session_auto_create_timer.set_one_shot(true)
	_session_auto_create_timer.set_wait_time(NODE_DISCO_TIMEOUT)
	_session_auto_create_timer.timeout.connect(_on_session_timer_timeout)
	
	_link_check_timer.set_autostart(false)
	_link_check_timer.set_one_shot(false)
	_link_check_timer.set_wait_time(LINK_CHECK_INTERVAL)
	_link_check_timer.timeout.connect(_on_link_check_timeout)
	
	_link_up_restart_delay.set_autostart(false)
	_link_up_restart_delay.set_one_shot(true)
	_link_up_restart_delay.set_wait_time(LINK_CHECK_RESTART_DELAY)
	_link_up_restart_delay.timeout.connect(restart_node)
	
	add_child(_local_node)
	add_child(_disco_timer)
	add_child(_session_auto_create_timer)
	add_child(_link_check_timer)
	add_child(_link_up_restart_delay)
	
	var cli_args: PackedStringArray = OS.get_cmdline_args()
	if cli_args.has("--ctl-node-name"):
		_local_node._set_node_name(str(cli_args[cli_args.find("--ctl-node-name") + 1]))
	
	if cli_args.has("--ctl-address"):
		ConstellationConfig.bind_address = str(cli_args[cli_args.find("--ctl-address") + 1])
	
	if cli_args.has("--ctl-interface"):
		ConstellationConfig.bind_interface = str(cli_args[cli_args.find("--ctl-interface") + 1])
	
	if cli_args.has("--ctl-controler"):
		_role_flags = ConstaNetHeadder.RoleFlags.CONTROLLER
		_local_node._set_role_flags(_role_flags)
	
	if cli_args.has("--ctl-executor"):
		_role_flags = ConstaNetHeadder.RoleFlags.EXECUTOR
		_local_node._set_role_flags(_role_flags)
	
	if cli_args.has("--ctl-random-id"):
		_local_node._set_node_id(UUID.v4())
	
	(func ():
		node_found.emit(_local_node)
	).call_deferred()


## process
func _process(delta: float) -> void:
	while _udp_socket.get_available_packet_count() > 0:
		_handle_packet(_udp_socket.get_packet())
	
	while _mcast_rx.get_available_packet_count() > 0:
		_handle_packet(_mcast_rx.get_packet())
	
	while _tcp_socket.is_connection_available():
		_handle_incoming_tcp_connection()
	
	for peer: StreamPeerTCP in _connected_tcp_peers.duplicate():
		_process_stream_peer(peer)
	
	for multi_part: IncommingMultiPart in _active_multi_parts.values():
		_process_multi_part(multi_part)


## notification
func _notification(p_what: int) -> void:
	if p_what == NOTIFICATION_WM_CLOSE_REQUEST:
		ConstellationConfig.save_user_config()


## Starts this node, binding all network sockets and starting the discovery process
func start_node() -> Error:
	if _network_state != NetworkState.OFFLINE:
		return ERR_ALREADY_EXISTS
	
	_log("Starting Node")
	stop_node(true)
	_set_network_state(NetworkState.INITIALIZING)
	
	_known_nodes[get_node_id()] = _local_node
	_local_node._set_node_ip(ConstellationConfig.bind_address)
	_bind_network()
	
	if _network_state != NetworkState.BOUND:
		_log_error("Error staring network")
		return FAILED
	
	_set_network_state(NetworkState.READY)
	_begin_discovery()
	
	return OK


## Stops this node, sends a ConstaNetGoodBye message and closes all network sockets and 
func stop_node(p_internal_only: bool = false) -> Error:
	if not p_internal_only:
		_log("Stopping Node")
		_send_goodbye(GOODBYE_REASON_GOING_OFFLINE)
	
	_set_network_state(NetworkState.SHUTTING_DOWN)
	_close_network()
	
	for node: ConstellationNode in _known_nodes.values():
		if node == _local_node:
			continue
		
		node.delete()
		remove_child(node)
	
	for session: ConstellationSession in _known_sessions.values():
		session.delete()
		remove_child(session)
	
	_local_node._set_session(null)
	
	_known_nodes.clear()
	_known_sessions.clear()
	_unknown_nodes.clear()
	_unknown_sessions.clear()
	
	_disco_timer.stop()
	_session_auto_create_timer.stop()
	
	_set_network_state(NetworkState.OFFLINE)
	return OK


## Restarts this node, without notifying the rest of the network
func restart_node() -> void:
	_log("Restarting node")
	stop_node(true)
	start_node()


## Sends a command to the current session, returning ERR_UNAVAILABLE if one does not exist
## p_node_filter defines what nodes the command should be sent to
func send_command(
	p_command: Variant, 
	p_node_filter: NetworkSession.NodeFilter = NetworkSession.NodeFilter.MASTER, 
	p_nodes: Array[NetworkNode] = []
) -> Error:
	if not _local_node.get_session():
		return ERR_UNAVAILABLE
	
	return _local_node.get_session().send_command(p_command, p_node_filter, p_nodes)


## Sends a manual request for nodes and session to re-announce them self on the network
func send_discovery() -> void:
	_send_discovery(ConstaNetHeadder.Flags.REQUEST)
	_send_session_discovery(ConstaNetHeadder.Flags.REQUEST)


## Creates and joines a new session, returns the new session object
func create_session(p_name: String) -> NetworkSession:
	if not p_name or _network_state != NetworkState.READY:
		return null
	
	_logv("Creating new ConstellationSession with name: \"", p_name, "\"")
	var session: ConstellationSession = ConstellationSession.new()
	add_child(session)
	
	session._set_name(p_name)
	session._set_session_master(_local_node)
	session._add_node(_local_node)
	
	_known_sessions[session.get_session_id()] = session
	session.delete_requested.connect(_on_session_delete_request)
	session_created.emit(session)
	
	_send_session_discovery(ConstaNetHeadder.Flags.ANNOUNCEMENT, session)
	return session


## Joins a pre-existing session on the network, returns true if the session was joined successfully
func join_session(p_session: NetworkSession, p_auto_priority: bool = true, p_priority: int = -1) -> bool:
	return _local_node.join_session(p_session, p_auto_priority, p_priority)


## Leaves the current session, returns true if the session was left successfully
func leave_session() -> bool:
	return _local_node.leave_session()


## Sets the IP and interface name from an IPAddr object
func set_ip_and_interface(p_ipaddr: IPAddr) -> bool:
	if not p_ipaddr.is_valid():
		return false
	
	if not p_ipaddr.get_type() == IP.Type.TYPE_IPV4:
		_log_error("IPV6 Addresses are not supported")
		return false 
	
	if _network_state != NetworkState.OFFLINE:
		_log_error("IP and Interface can not be changed while node is not NetworkState.OFFLINE")
		return false
	
	ConstellationConfig.bind_address = p_ipaddr.get_address()
	ConstellationConfig.bind_interface = p_ipaddr.get_interface()
	
	ip_and_interface_changed.emit(get_ip_and_interface())
	ConstellationConfig.save_user_config()
	return true


## Returns the IP and interface name as a IPAddr object
func get_ip_and_interface() -> IPAddr:
	return IPAddr.new(IP.Type.TYPE_ANY, ConstellationConfig.bind_address, ConstellationConfig.bind_interface)


## Returns a list of all known nodes
func get_known_nodes() -> Array[NetworkNode]:
	var return_value: Array[NetworkNode]
	return_value.assign(_known_nodes.values())
	
	return return_value


## Returns a list of all unknown nodes
func get_unknown_nodes() -> Array[NetworkNode]:
	var return_value: Array[NetworkNode]
	return_value.assign(_unknown_nodes.values())
	
	return return_value


## Returns a list of all known session
func get_known_sessions() -> Array[NetworkSession]:
	var return_value: Array[NetworkSession]
	return_value.assign(_known_sessions.values())
	
	return return_value


## Returns a list of all unknown sessions
func get_unknown_sessions() -> Array[NetworkSession]:
	var return_value: Array[NetworkSession]
	return_value.assign(_unknown_sessions.values())
	
	return return_value


## Returns the local node
func get_local_node() -> ConstellationNode:
	return _local_node


## Returns the name of the local node
func get_node_name() -> String:
	return _local_node.get_node_name()


## Returns the node id of the local node
func get_node_id() -> String:
	return _local_node.get_node_id()


## Returns the role flags of the local node
func get_role_flags() -> int:
	return _local_node.get_role_flags()


## Attempts to return a session based on the given session id, return null if no matching session was found
## if p_create_unknown == true, an unknown session will be created if no matching session could be found
func get_session_from_id(p_session_id: String, p_create_unknown: bool = false) -> ConstellationSession:
	if _known_sessions.has(p_session_id):
		return _known_sessions[p_session_id]
	
	elif p_create_unknown:
		if _unknown_sessions.has(p_session_id):
			return _unknown_sessions[p_session_id]
		
		_logv("Unable to find ConstellationSession: \"", p_session_id, "\" localy. Creating unknown session")
		var unknown_session: ConstellationSession = ConstellationSession.create_unknown_session(p_session_id)
		
		_unknown_sessions[p_session_id] = unknown_session
		add_child(unknown_session)
		
		session_created.emit(unknown_session)
		return unknown_session
	
	return _known_sessions.get(p_session_id)


## Attempts to return a node based on the given node id, return null if no matching node was found
## if p_create_unknown == true, an unknown node will be created if no matching node could be found
func get_node_from_id(p_node_id: String, p_create_unknown: bool = false) -> ConstellationNode:
	if _known_nodes.has(p_node_id):
		return _known_nodes[p_node_id]
	
	elif p_create_unknown:
		if _unknown_nodes.has(p_node_id):
			return _unknown_nodes[p_node_id]
		
		_logv("Unable to find ConstellationNode: \"", p_node_id, "\" localy. Creating unknown node")
		var unknown_node: ConstellationNode = ConstellationNode.create_unknown_node(p_node_id)
		
		_unknown_nodes[p_node_id] = unknown_node
		add_child(unknown_node)
		
		node_found.emit(unknown_node)
		return unknown_node
	
	return null


## Sets the NetworkState
func _set_network_state(p_network_state: NetworkState) -> bool:
	if p_network_state == _network_state:
		return false
	
	_logv("NetworkState changed to: ", NetworkState.keys()[p_network_state])
	
	_network_state = p_network_state
	network_state_changed.emit(
		_network_state, 
		_network_state_err_code if _network_state == NetworkState.ERROR else OK
	)
	
	return true


## Gets the custom log prefix with node name
func _get_log_prefix() -> String:
	return str(ConstellationConfig.log_prefix, " (", _local_node.get_node_name(), "): ")


## Logs to the console
func _log(...args) -> void:
	if ConstellationConfig.custom_loging_method.is_valid():
		ConstellationConfig.custom_loging_method.callv([_get_log_prefix()] + args)
	
	else:
		print(_get_log_prefix(), "".join(args))


## Logs a warning to the console
func _log_warn(...args) -> void:
	if ConstellationConfig.custom_loging_method_warn.is_valid():
		ConstellationConfig.custom_loging_method_warn.callv([_get_log_prefix()] + args)
	
	else:
		push_warning(_get_log_prefix(), "".join(args))


## Logs an error to the console
func _log_error(...args) -> void:
	if ConstellationConfig.custom_loging_method_error.is_valid():
		ConstellationConfig.custom_loging_method_error.callv([_get_log_prefix()] + args)
	
	else:
		push_error(_get_log_prefix(), "".join(args))


## Logs to the console's verbose output
func _logv(...args) -> void:
	if ConstellationConfig.custom_loging_method_verbose.is_valid():
		ConstellationConfig.custom_loging_method_verbose.callv([_get_log_prefix()] + args)
	
	else:
		print_verbose(_get_log_prefix(), "".join(args))


## Opens and binds all network ports and sockets
func _bind_network() -> void:
	_mcast_tx.set_reuse_address_enabled(true)
	_mcast_rx.set_reuse_address_enabled(true)
	_mcast_tx.set_reuse_port_enabled(true)
	_mcast_rx.set_reuse_port_enabled(true)
	
	var rx_address: String = ConstellationConfig.bind_address if OS.has_feature("windows") else MCAST_GROUP
	
	var tx_bind_error: Error = _mcast_tx.bind(UDP_MCAST_PORT, ConstellationConfig.bind_address)
	var rx_bind_error: Error = _mcast_rx.bind(UDP_MCAST_PORT, rx_address)
	
	var tx_config_error: Error = _mcast_tx.set_dest_address(MCAST_GROUP, UDP_MCAST_PORT)
	var rx_config_error: Error = _mcast_rx.join_multicast_group(MCAST_GROUP, ConstellationConfig.bind_interface)
	
	var tcp_error: Error = _tcp_socket.listen(0)
	var udp_error: Error = _udp_socket.bind(0)
	
	if tx_bind_error or rx_bind_error or tx_config_error or rx_config_error or tcp_error or udp_error:
		_log_error("TX Bind Error: ", error_string(tx_bind_error))
		_log_error("RX Bind Error: ", error_string(rx_bind_error))
		
		_log_error("TX Config Error: ", error_string(tx_config_error))
		_log_error("RX Config Error: ", error_string(rx_config_error))
		
		_log_error("TCP Bind Error: ", error_string(tcp_error))
		_log_error("UDP Bind Error: ", error_string(udp_error))
		
		_network_state_err_code = ERR_ALREADY_IN_USE
		_set_network_state(NetworkState.ERROR)
	else:
		_tcp_port = _tcp_socket.get_local_port()
		_udp_port = _udp_socket.get_local_port()
		
		_log("TCP bound on port: ", _tcp_port)
		_log("UDP bound on port: ", _udp_port)
		
		_ip_link_up = true
		_link_check_timer.start()
		
		_set_network_state(NetworkState.BOUND)
		set_process(true)


## Closes network sockets
func _close_network() -> void:
	_mcast_tx.close()
	_mcast_rx.close()
	
	_tcp_socket.stop()
	_udp_socket.close()
	
	_ip_link_up = false
	_link_check_timer.stop()
	set_process(false)


## Starts the discovery process
func _begin_discovery() -> void:
	_disco_timer.start()
	
	if ConstellationConfig.auto_create_session and ConstellationConfig.session_id:
		_session_auto_create_timer.start()
	
	elif ConstellationConfig.auto_create_session:
		_auto_create_session()
	
	_send_discovery(ConstaNetHeadder.Flags.REQUEST)
	_send_session_discovery(ConstaNetHeadder.Flags.REQUEST)


## Handles session auto creation
func _auto_create_session() -> void:
	create_session(_local_node.get_node_name() + "'s Session")


## Attempts to connect to the givens session if all autoconnect checks pass
func _attempt_session_auto_connect(p_session: ConstellationSession) -> void:
	if (
		ConstellationConfig.session_auto_rejoin
		and not _local_node.get_session()
		and ConstellationConfig.session_id == p_session.get_session_id() 
	):
		_logv("A ConstellationSession has been discovered on the network. Initializing auto-join")
		join_session(p_session)


## Creates and returns a new ConstaNetDiscovery messages with all field filled in
func _create_discovery(p_flags: int = 0, p_target_id: String = "") -> ConstaNetDiscovery:
	var message: ConstaNetDiscovery = ConstaNetDiscovery.new()
	
	message.origin_id = get_node_id()
	message.target_id = p_target_id
	message.node_name = get_node_name()
	message.node_ip = ConstellationConfig.bind_address
	message.role_flags = get_role_flags()
	message.tcp_port = _tcp_port
	message.udp_port = _udp_port
	message.disco_time = NODE_DISCO_INTERVAL
	message.flags |= p_flags
	
	return message


## Sends the given message to multicast
func _send_message_mcast(p_message: ConstaNetHeadder) -> Error:
	if _network_state == NetworkState.OFFLINE:
		return ERR_UNAVAILABLE
	
	var tx_error: Error = _mcast_tx.put_packet(p_message.get_as_packet())
	_logv(
		"Sent MCast message of type: ", ConstaNetHeadder.Type.keys()[p_message.type], 
		", flags: ", p_message.get_flags_human(),
		", errcode: ", error_string(tx_error)
	)
	
	if tx_error:
		_check_network_link()
	
	return tx_error


## Sends a ConstaNetDiscovery message to multicast
func _send_discovery(p_flags: int = ConstaNetHeadder.Flags.ACKNOWLEDGMENT) -> Error:
	var message: ConstaNetDiscovery = _create_discovery(p_flags)
	
	if _network_state == NetworkState.READY:
		_disco_timer.start(NODE_DISCO_INTERVAL)
	
	return _send_message_mcast(message)


## Sends a ConstaNetSessionDiscovery message to multicast
func _send_session_discovery(p_flags: int = ConstaNetHeadder.Flags.REQUEST, p_session: ConstellationSession = null) -> Error:
	var message: ConstaNetSessionDiscovery = ConstaNetSessionDiscovery.new()
	
	message.origin_id = get_node_id()
	message.flags = p_flags
	
	if p_session:
		var node_ids: Dictionary[String, int] = {}
		
		for node: ConstellationNode in p_session.get_nodes():
			node_ids[node.get_node_id()] = p_session.get_priority_of(node)
		
		message.session_master = get_node_id()
		message.session_id = p_session.get_session_id()
		message.session_name = p_session.get_session_name()
		message.nodes = node_ids
	
	return _send_message_mcast(message)


## Sends a ConstaNetGoodbye message to multicast
func _send_goodbye(p_reason: String, p_flags: int = ConstaNetHeadder.Flags.ANNOUNCEMENT) -> Error:
	var message: ConstaNetGoodbye = ConstaNetGoodbye.new()
	
	message.origin_id = get_node_id()
	message.flags = p_flags
	message.reason = p_reason
	
	return _send_message_mcast(message)


## Handles a frame pulled from a network stream
func _handle_packet_frame(p_peer: StreamPeerTCP) -> void:
	_tcp_buffers.get_or_add(p_peer, PackedByteArray()).append_array(p_peer.get_data(p_peer.get_available_bytes())[1])
	var packet: PackedByteArray = _tcp_buffers[p_peer]
	
	while ConstaNetHeadder.is_packet_valid(packet):
		var length: int = packet.decode_u64(ConstaNetHeadder.O_MSG_SIZE)
		
		if length <= 0 or packet.size() < length:
			break
		
		var sliced_packet: PackedByteArray = packet.slice(0, length)
		_handle_packet(sliced_packet, p_peer)
		packet = packet.slice(length)
	
	if not ConstaNetHeadder.is_packet_valid(packet):
		_tcp_buffers[p_peer].clear() 


## Handles a packet as a PackedByteArray
func _handle_packet(p_packet: PackedByteArray, p_source: StreamPeerTCP = null) -> void:
	var message: ConstaNetHeadder = ConstaNetHeadder.parse_packet(p_packet)
	
	if message.is_valid() and message.origin_id != _local_node.get_node_id():
		_handle_message(message, p_source)


## Handles an incomming message
func _handle_message(p_message: ConstaNetHeadder, p_source: StreamPeerTCP = null) -> void:
	if p_message.target_id and p_message.target_id != get_node_id():
		return
	
	match p_message.type:
		ConstaNetHeadder.Type.DISCOVERY:
			_handle_discovery_message(p_message, p_source)
		
		ConstaNetHeadder.Type.SESSION_DISCOVERY when p_message.is_request():
			_handle_session_discovery_request(p_message)
		
		ConstaNetHeadder.Type.SESSION_DISCOVERY when p_message.is_acknowledgment() or p_message.is_announcement():
			_handle_session_discovery_ack_announce(p_message)
		
		ConstaNetHeadder.Type.SESSION_SET_PRIORITY:
			_handle_session_set_priority(p_message)
		
		ConstaNetHeadder.Type.SESSION_SET_ATTRIBUTE:
			_handle_session_set_attribute(p_message)
		
		ConstaNetHeadder.Type.MULTI_PART:
			_handle_multi_part(p_message)
	
	if p_message.target_id == get_node_id():
		_local_node._handle_message(p_message, p_source)
	
	if p_message.origin_id in _known_nodes:
		_known_nodes[p_message.origin_id]._handle_message(p_message, p_source)


## Handles a ConstaNetDiscovery message
func _handle_discovery_message(p_discovery: ConstaNetDiscovery, p_source: StreamPeerTCP = null) -> void:
	_logv("Got Discovery: ", p_discovery.get_flags_human(), " from: \"", p_discovery.node_name, "\"")
	
	if _known_nodes.has(p_discovery.origin_id):
		return
	
	var node: ConstellationNode
	
	if p_discovery.origin_id in _unknown_nodes:
		node = _unknown_nodes[p_discovery.origin_id]
		node._update_from_discovery(p_discovery)
		node._mark_as_unknown(false)
		
		_unknown_nodes.erase(p_discovery.origin_id)
		_log("Previously unknown Node: \"", node.get_node_id(), "\" has been found on the network")
	
	else:
		node = ConstellationNode.create_from_discovery(p_discovery)
		add_child(node)
		node_found.emit(node)
	
	_logv("New ConstellationNode: \"", node.get_node_name(), "\" has been discovered on the network")
	_known_nodes[p_discovery.origin_id] = node


## Handles a ConstaNetSessionDiscovery REQ message
func _handle_session_discovery_request(p_session_discovery: ConstaNetSessionDiscovery) -> void:
	var current_session: ConstellationSession = _local_node.get_session()
	
	if not current_session:
		return 
	
	var is_first_node: bool = current_session.get_nodes()[0] == _local_node
	
	if _local_node.is_sesion_master() or (not current_session.has_session_master() and is_first_node):
		_send_session_discovery(ConstaNetHeadder.Flags.ACKNOWLEDGMENT, _local_node.get_session())


## Handles a ConstaNetSessionDiscovery ACK or ANNOUNCE message
func _handle_session_discovery_ack_announce(p_session_discovery: ConstaNetSessionDiscovery) -> void:
	if _known_sessions.has(p_session_discovery.session_id):
		_known_sessions[p_session_discovery.session_id]._update_with(p_session_discovery)
		return
	
	var session: ConstellationSession
	
	if _unknown_sessions.has(p_session_discovery.session_id):
		session = _unknown_sessions[p_session_discovery.session_id]
		session._mark_as_unknown(false)
		session._update_with(p_session_discovery)
		
		_unknown_sessions.erase(p_session_discovery.session_id)
		_log("Previously unknown ConstellationSession: ", session.get_session_id(), " has been found on the network")
	
	else:
		session = ConstellationSession.create_from_session_discovery(p_session_discovery)
		add_child(session)
		session_created.emit(session)
	
	_logv("New ConstellationSession: \"", session.get_uname(), "\" has been discovered on the network")
	_known_sessions[session.get_session_id()] = session
	
	session.delete_requested.connect(_on_session_delete_request)
	_attempt_session_auto_connect(session)


## Handles a ConstaNetSessionSetPriority message
func _handle_session_set_priority(p_session_set_priority: ConstaNetSessionSetPriority) -> void:
	var node: ConstellationNode = get_node_from_id(p_session_set_priority.node_id)
	var session: ConstellationSession = get_session_from_id(p_session_set_priority.session_id)
	
	if is_instance_valid(node) and is_instance_valid(session):
		session._set_node_priority(node, p_session_set_priority.position)


## Handles a ConstaNetSessionSetAttribute message
func _handle_session_set_attribute(p_session_set_attribute: ConstaNetSessionSetAttribute) -> void:
	var session: ConstellationSession = get_session_from_id(p_session_set_attribute.session_id)
	
	if not is_instance_valid(session):
		return
	
	match p_session_set_attribute.attribute:
		ConstaNetSessionSetAttribute.Attribute.NAME:
			session._set_session_name(p_session_set_attribute.value)
		
		ConstaNetSessionSetAttribute.Attribute.MASTER:
			session._set_session_master(get_node_from_id(p_session_set_attribute.value))


## Handles a ConstaNetMultiPart message
func _handle_multi_part(p_multi_part: ConstaNetMultiPart) -> void:
	if _active_multi_parts.has(p_multi_part.multi_part_id):
		_active_multi_parts[p_multi_part.multi_part_id].store_multi_part(p_multi_part)
		
	else:
		_active_multi_parts[p_multi_part.multi_part_id] = IncommingMultiPart.new(p_multi_part)


## Handles an incoming TCP connection
func _handle_incoming_tcp_connection() -> bool:
	var peer: StreamPeerTCP = _tcp_socket.take_connection()
	
	if not is_instance_valid(peer):
		return false
	
	_connected_tcp_peers.append(peer)
	_tcp_buffers.erase(peer)
	
	_logv("Accepted new TCP Peer from: ", peer.get_connected_host(), ":", peer.get_connected_port())
	return true


## Processes a StreamPeerTCP for data
func _process_stream_peer(p_peer: StreamPeerTCP) -> void:
	p_peer.poll()
	
	if p_peer.get_status() != StreamPeerTCP.Status.STATUS_CONNECTED:
		_logv(
			"StreamPeerTCP processed by: NetworkHandler from: ", 
			p_peer.get_connected_host(), ":", p_peer.get_connected_port(),
			" has lost connection, removing from process list"
		)
		_remove_peer_from_process(p_peer)
	
	else:
		while p_peer.get_available_bytes() > 0:
			_handle_packet_frame(p_peer)


## Removes the given stream peer from the process list
func _remove_peer_from_process(p_peer: StreamPeerTCP) -> void:
	_connected_tcp_peers.erase(p_peer)
	_tcp_buffers.erase(p_peer)


## Processes a IncommingMultiPart
func _process_multi_part(p_multi_part: IncommingMultiPart) -> void:
	if p_multi_part.is_complete():
		_handle_packet(p_multi_part.get_data())
		_active_multi_parts.erase(p_multi_part.id)
		p_multi_part.free()
	
	elif Time.get_unix_time_from_system() - p_multi_part.last_seen > MULTI_PART_MAX_WAIT:
		_logv("Dropping multipart ", p_multi_part.id, ". Max timeout exceeded")
		_active_multi_parts.erase(p_multi_part.id)
		p_multi_part.free()


## Checks the link status of the network interface being used
func _check_network_link() -> void:
	var new_link_state: bool = false
	
	for interface: Dictionary in IP.get_local_interfaces():
		if interface.name != ConstellationConfig.bind_interface:
			continue
		
		if (interface.addresses as Array).has(ConstellationConfig.bind_address):
			new_link_state = true
			break
	
	if new_link_state == _ip_link_up:
		return
	
	if new_link_state:
		_log("Network link is back UP")
		_link_up_restart_delay.start()
		_link_check_timer.start(LINK_CHECK_INTERVAL)
	
	else:
		_log_error("Network link is DOWN")
		_set_network_state(NetworkState.ERROR)
		
		_link_up_restart_delay.stop()
		_link_check_timer.start(LINK_CHECK_ERROR_INTERVAL)
	
	_ip_link_up = new_link_state


## Called when the node name is changed on the LocalNode
func _on_local_node_name_changed(p_name: String) -> void:
	ConstellationConfig.node_name = p_name
	ConstellationConfig.save_user_config()


## Called when the session of the local node changes
func _on_local_node_session_changed(p_session: ConstellationSession) -> void:
	if _network_state != NetworkState.READY:
		return
	
	ConstellationConfig.session_id = p_session.get_session_id() if p_session else ""
	ConstellationConfig.save_user_config()


## Called when the discovery timer times out
func _on_node_disco_timeout() -> void:
	_send_discovery()
	
	if _local_node.is_sesion_master():
		_send_session_discovery(ConstaNetHeadder.Flags.ACKNOWLEDGMENT, _local_node.get_session())


## Called when the session timer times out
func _on_session_timer_timeout() -> void:
	if not ConstellationConfig.auto_create_session or _local_node.get_session():
		return
	
	_auto_create_session()


## Called when the sessions is to be deleted after all nodes disconnect
func _on_session_delete_request(p_session: ConstellationSession) -> void:
	p_session.delete_requested.disconnect(_on_session_delete_request)
	_known_sessions.erase(p_session.get_session_id())


## Called when the network link timer times out
func _on_link_check_timeout() -> void:
	_check_network_link()


## ConstellationConfig object
class ConstellationConfig extends Object:
	## Class tree to merge with the network CoreClassListDB
	static var class_tree: Dictionary = {
		"NetworkItem": {
			"NetworkHandler": {
				"Constellation": Constellation,
			},
			"NetworkNode": {
				"ConstellationNode": ConstellationNode,
			},
			"NetworkSession": {
				"ConstellationSession": ConstellationSession,
			}
		}
	}
	
	## Defines a custom callable to call when logging infomation
	static var custom_loging_method: Callable = Callable()
	
	## Defines a custom callable to call when logging a warning
	static var custom_loging_method_warn: Callable = Callable()
	
	## Defines a custom callable to call when logging an error
	static var custom_loging_method_error: Callable = Callable()
	
	## Defines a custom callable to call when logging infomation verbosely
	static var custom_loging_method_verbose: Callable = Callable()
	
	## A String prefix to print before all message logs
	static var log_prefix: String = ""
	
	## Default address to bind to. 
	## Due to the use of multicast, binding to loopback does not work, it is here as a default for all platforms
	static var bind_address: String = "127.0.0.1"
	
	## Default port to bind to. 
	## Due to the use of multicast, binding to loopback does not work, it is here as a default for all platforms
	static var bind_interface: String = "lo"
	
	## File location for a user config override
	static var user_config_file_location: String = "user://"
	
	## File name for the user config file
	static var user_config_file_name: String = "constellation.conf"
	
	## NodeID for the local node
	static var node_id: String = UUID.v4()
	
	## Node name for the local node
	static var node_name: String = "ConstellationNode"
	
	## The SessionID of the session the local node was last in
	static var session_id: String = ""
	
	## Auto rejoins the last session if it still exists on the network
	static var session_auto_rejoin: bool = true
	
	## True if this node should auto create a session once online, 
	## asuming previous session is is null and the node is not already in a session
	static var auto_create_session: bool = true
	
	## The CoreClassListDB for storing all NetworkItem classes
	static var network_item_class_db: CoreClassListDB
	
	## The ConfigFile object to access the user config file 
	static var _config_access: ConfigFile
	
	
	## Loads config from a file
	static func load_config(p_path: String) -> bool:
		var script: Variant = load(p_path)
		
		if script is not GDScript or script.get("config") is not Dictionary:
			return false
		
		var config: Dictionary = script.get("config")
		
		custom_loging_method = type_convert(config.get("custom_loging_method", custom_loging_method), TYPE_CALLABLE)
		custom_loging_method_warn = type_convert(config.get("custom_loging_method_warn", custom_loging_method_warn), TYPE_CALLABLE)
		custom_loging_method_error = type_convert(config.get("custom_loging_method_error", custom_loging_method_error), TYPE_CALLABLE)
		
		custom_loging_method_verbose = type_convert(config.get("custom_loging_method_verbose", custom_loging_method_verbose), TYPE_CALLABLE)
		log_prefix = type_convert(config.get("log_prefix", log_prefix), TYPE_STRING)
		
		bind_address = type_convert(config.get("bind_address", bind_address), TYPE_STRING)
		bind_interface = type_convert(config.get("bind_interface", bind_address), TYPE_STRING)
		
		user_config_file_location = type_convert(config.get("user_config_file_location", user_config_file_location), TYPE_STRING)
		user_config_file_name = type_convert(config.get("user_config_file_name", user_config_file_name), TYPE_STRING)
		
		node_id = type_convert(config.get("node_id", node_id), TYPE_STRING)
		node_name = type_convert(config.get("node_name", node_name), TYPE_STRING)
		
		session_id = type_convert(config.get("session_id", session_id), TYPE_STRING)
		session_auto_rejoin = type_convert(config.get("session_auto_rejoin", session_auto_rejoin), TYPE_BOOL)
		auto_create_session = type_convert(config.get("auto_create_session", auto_create_session), TYPE_BOOL)
		
		network_item_class_db = type_convert(config.get("network_item_class_db", network_item_class_db), TYPE_OBJECT)
		if is_instance_valid(network_item_class_db):
			network_item_class_db.merge_class_tree(class_tree)
		
		DirAccess.make_dir_recursive_absolute(user_config_file_location)
		_config_access = ConfigFile.new()
		
		return true
	
	
	## Loads (or creates if not already) the user config override
	static func load_user_config() -> Error:
		_config_access.load(get_user_config_path())
		
		bind_address = type_convert(_config_access.get_value("Network", "bind_address", bind_address), TYPE_STRING)
		bind_interface = type_convert(_config_access.get_value("Network", "bind_interface", bind_interface), TYPE_STRING)
		
		node_id = type_convert(_config_access.get_value("LocalNode", "node_id", node_id), TYPE_STRING)
		node_name = type_convert(_config_access.get_value("LocalNode", "node_name", node_name), TYPE_STRING)
		
		session_id = type_convert(_config_access.get_value("Session", "session_id", session_id), TYPE_STRING)
		session_auto_rejoin = type_convert(_config_access.get_value("Session", "session_auto_rejoin", session_auto_rejoin), TYPE_BOOL)
		auto_create_session = type_convert(_config_access.get_value("Session", "auto_create_session", auto_create_session), TYPE_BOOL)
		
		save_user_config()
		return OK
	
	
	## Saves the user config to a file
	static func save_user_config() -> Error:
		_config_access.set_value("Network", "bind_address", bind_address)
		_config_access.set_value("Network", "bind_interface", bind_interface)
		
		_config_access.set_value("LocalNode", "node_id", node_id)
		_config_access.set_value("LocalNode", "node_name", node_name)
		
		_config_access.set_value("Session", "session_id", session_id)
		_config_access.set_value("Session", "session_auto_rejoin", session_auto_rejoin)
		_config_access.set_value("Session", "auto_create_session", auto_create_session)
		
		return _config_access.save(get_user_config_path())
	
	
	## Returns the full filepath to the user config
	static func get_user_config_path() -> String:
		if user_config_file_location.ends_with("/"):
			return user_config_file_location + user_config_file_name
		else:
			return user_config_file_location + "/" + user_config_file_name
 

## Class to repersent an incomming multipart message
class IncommingMultiPart extends Object:
	## The ID of this multipart message
	var id: String
	
	## Stores all numbered chunks
	var chunks: Dictionary[int, PackedByteArray] = {}
	
	## Number of chunks
	var num_of_chunks: int = 0
	
	## Last seen time
	var last_seen: float = Time.get_unix_time_from_system()
	
	## init
	func _init(p_multi_part: ConstaNetMultiPart) -> void:
		id = p_multi_part.multi_part_id
		num_of_chunks = p_multi_part.num_of_chunks
		
		store_multi_part(p_multi_part)
	
	
	## Stores a chunk of data from a ConstaNetMultiPart
	func store_multi_part(p_multi_part: ConstaNetMultiPart) -> void:
		chunks[p_multi_part.chunk_id] = p_multi_part.data
		last_seen = Time.get_unix_time_from_system()
	
	
	## Gets all data that has been sent
	func get_data() -> PackedByteArray:
		var result: PackedByteArray
		
		for i in range(0, num_of_chunks):
			result.append_array(chunks.get(i, PackedByteArray()))
		
		return result
	
	## Returns true if the number of chunks matches what expected
	func is_complete() -> bool:
		return chunks.size() >= num_of_chunks
