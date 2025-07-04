# Copyright (c) 2025 Liam Sherwin, All rights reserved.
# This file is part of the Constellation Network Engine, licensed under the GPL v3.

class_name Constellation extends Node


## Emitted when a node is found
signal node_found(node: ConstellationNode)

## Emitted when the local name is changed
signal node_name_changed(node_name: String)


## TCP bind port
const TCP_PORT: int = 3824

## UDP bind port
const UDP_PORT: int = 3823

## Network broadcast address
const NETWORK_BROADCAST: String = "255.255.255.255"

## Time in seconds for discovery
const DISCO_TIMEOUT: int = 10

## MessageType
const MessageType: ConstaNetHeadder.Type = ConstaNetHeadder.Type


## The primary TCP server to use
var _tcp_socket: TCPServer = TCPServer.new()

## The primary UDP server to use
var _udp_socket: UDPServer = UDPServer.new()

## The PacketPeerUDP to use when sending to broadcast
var _udp_broadcast_socket: PacketPeerUDP = PacketPeerUDP.new()

## IP bind address
var _bind_address: String = "192.168.1.73"

## The name of this node
var _node_name: String = "UnNamedNode"

## The NodeID of this node
var _node_id: String = UUID_Util.v4()

## Timer for node discovery
var _disco_timer: Timer = Timer.new()

## Stores all known devices by thier NodeID
var _known_nodes: Dictionary[String, ConstellationNode] = {}


## Init
func _init() -> void:
	set_process(false)
	Details.print_startup_detils()
	
	var cli_args: PackedStringArray = OS.get_cmdline_args()
	if cli_args.has("--node-name"):
		_node_name = str(cli_args[cli_args.find("--node-name") + 1])
	
	if cli_args.has("--interface"):
		_bind_address = str(cli_args[cli_args.find("--interface") + 1])


## Ready
func _ready() -> void:
	_disco_timer.wait_time = DISCO_TIMEOUT
	_disco_timer.autostart = true
	_disco_timer.timeout.connect(_on_disco_timeout)
	add_child(_disco_timer)
	
	start_node()


## Polls the socket
func _process(delta: float) -> void:
	_udp_socket.poll()
	
	if _udp_socket.is_connection_available():
		var peer: PacketPeerUDP = _udp_socket.take_connection()
		var string: String = peer.get_packet().get_string_from_utf8()
		var message: ConstaNetHeadder = ConstaNetHeadder.phrase_string(string)
		
		print(_node_name, " Got: ", message)
		
		if message.is_valid() and message.origin_id != _node_id:
			handle_message(message, peer)


## Returns a list of all known nodes
func get_known_nodes() -> Array[ConstellationNode]:
	var return_value: Array[ConstellationNode]
	return_value.assign(_known_nodes.values())
	
	return return_value


## Gets this nodes NodeID
func get_node_id() -> String:
	return _node_id


## Starts this node, opens network connection
func start_node() -> void:
	_udp_broadcast_socket.set_broadcast_enabled(true)
	_udp_broadcast_socket.set_dest_address(NETWORK_BROADCAST, UDP_PORT)
	
	var tcp_error: Error = _tcp_socket.listen(TCP_PORT)
	var udp_error: Error = _udp_socket.listen(UDP_PORT)
	
	print("TCP bound with error: ", error_string(tcp_error))
	print("UDP bound with error: ", error_string(udp_error))
	
	set_process(true)
	send_discovery()


## Sends a discovery message to broadcasr
func send_discovery(p_flags = ConstaNetHeadder.Flags.REQUEST) -> Error:
	if not _udp_socket.is_listening():
		return ERR_CONNECTION_ERROR
	
	var packet: ConstaNetDiscovery = ConstaNetDiscovery.new()
	
	packet.origin_id = _node_id
	packet.node_name = _node_name
	packet.node_ip = _bind_address
	packet.flags |= p_flags
	
	_disco_timer.start(DISCO_TIMEOUT)
	return _udp_broadcast_socket.put_packet(packet.get_as_string().to_utf8_buffer())


## Handles an incomming message, p_peer is the PacketPeerUDP, or StreamPeerTCP it orignated from
func handle_message(p_message: ConstaNetHeadder, p_peer: Object = null) -> void:
	if p_message.type == MessageType.DISCOVERY and p_message.flags & ConstaNetHeadder.Flags.REQUEST:
		send_discovery(ConstaNetHeadder.Flags.ACKNOWLEDGMENT)
	
	if p_message.origin_id in _known_nodes:
		_known_nodes[p_message.origin_id].handle_message(p_message)
	
	match p_message.type:
		MessageType.DISCOVERY:
			if p_message.origin_id in _known_nodes:
				return
			
			var node: ConstellationNode = ConstellationNode.create_from_discovery(p_message)
			
			_known_nodes[p_message.origin_id] = node
			node_found.emit(node)
		
		MessageType.SET_ATTRIBUTE:
			handle_set_attribute_message(p_message)


## Handles a set attribute message
func handle_set_attribute_message(p_message: ConstaNetSetAttribute) -> void:
	match p_message.attribute:
		ConstaNetSetAttribute.Attribute.NAME:
			set_node_name(p_message.value)


## Returns the name of the local node
func get_node_name() -> String:
	return _node_name


## Sets the name of this node
func set_node_name(p_name: String) -> void:
	if _set_node_name(p_name):
		send_discovery(ConstaNetHeadder.Flags.ACKNOWLEDGMENT)


## Sets the local nodes name
func _set_node_name(p_name: String) -> bool:
	if p_name == _node_name:
		return false
	
	_node_name = p_name
	node_name_changed.emit(_node_name)
	
	return true


## Called when the discovery timer times out
func _on_disco_timeout() -> void:
	send_discovery()
