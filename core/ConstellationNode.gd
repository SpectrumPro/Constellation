# Copyright (c) 2025 Liam Sherwin, All rights reserved.
# This file is part of the Constellation Network Engine, licensed under the GPL v3.

class_name ConstellationNode extends RefCounted
## Class to repersent a node in the session


## Emitted when the connection state is changed
signal connection_state_changed(connection_state: ConnectionState)

## Emitted when the name of the node is changed
signal node_name_changed(node_name: String)

## Emitted when the IP address of the remote node is changed
signal node_ip_changed(ip: String)

## Emitted when the last seen time is changed, IE the node was just seen
signal last_seen_changed(last_seen: float)


## MessageType
const MessageType: ConstaNetHeadder.Type = ConstaNetHeadder.Type

## Flags
const Flags: ConstaNetHeadder.Flags = ConstaNetHeadder.Flags


## State Enum for remote node
enum ConnectionState {
	UNKNOWN,			## No state assigned yet
	DISCOVERED,			## Node was found via discovery
	CONNECTING,			## Attempting to establish connection
	CONNECTED,			## Successfully connected and active
	LOST_CONNECTION		## Node timed out or disconnected unexpectedly
}


## Current state of the remote node local connection
var _connection_state: ConnectionState = ConnectionState.UNKNOWN

## The NodeID of the remote node
var _node_id: String = ""

## The Name of the remote node
var _node_name: String = ""

## The IP address of the remote node
var _node_ip: String = ""

## UNIX timestamp of the last time this node was seen on the network
var _last_seen: float = 0

## UDP peer to send data to this node
var _udp_socket: PacketPeerUDP = PacketPeerUDP.new()


## Creates a new ConstellationNode from a ConstaNetDiscovery message
static func create_from_discovery(p_disco: ConstaNetDiscovery) -> ConstellationNode:
	var node: ConstellationNode = ConstellationNode.new()
	
	node._connection_state = ConnectionState.DISCOVERED
	node._node_id = p_disco.origin_id
	node._node_name = p_disco.node_name
	node._node_ip = p_disco.node_ip
	node._last_seen = Time.get_unix_time_from_system()
	node._udp_socket.connect_to_host(p_disco.node_ip, Network.UDP_PORT)
	
	return node


## Autofills a ConstaNetHeadder with the infomation to comunicate to this remote node
func auto_fill_headder(p_headder: ConstaNetHeadder, p_flags: int) -> ConstaNetHeadder:
	p_headder.origin_id = Network.get_node_id()
	p_headder.target_id = _node_id
	p_headder.flags |= p_flags
	
	return p_headder


## Handles a message
func handle_message(p_message: ConstaNetHeadder) -> void:
	match p_message.type:
		MessageType.DISCOVERY:
			_set_node_name(p_message.node_name)
			_set_node_ip(p_message.node_ip)
			_udp_socket.connect_to_host(p_message.node_ip, Network.UDP_PORT)
			
			_last_seen = Time.get_unix_time_from_system()
			last_seen_changed.emit(_last_seen)


## Sends a message via UDP to the remote node
func send_message_udp(p_message: ConstaNetHeadder) -> void:
	if _udp_socket.is_socket_connected():
		_udp_socket.put_packet(p_message.get_as_string().to_utf8_buffer())


## Gets the connection state
func get_connection_state() -> ConnectionState:
	return _connection_state


## Gets the human readable connection state
func get_connection_state_human() -> String:
	return ConnectionState.keys()[_connection_state].capitalize()


## Gets the Node's NodeID
func get_node_id() -> String:
	return _node_id


## Gets the Node's name
func get_node_name() -> String:
	return _node_name


## Gets the Node's IP Address
func get_node_ip() -> String:
	return _node_ip


## Returns the last time this node was seen on the network
func get_last_seen_time() -> float:
	return _last_seen


## Sends a message to set the name of this node on the network
func set_node_name(p_name: String) -> void:
	var set_attribute: ConstaNetSetAttribute = auto_fill_headder(ConstaNetSetAttribute.new(), Flags.REQUEST)
	
	set_attribute.attribute = ConstaNetSetAttribute.Attribute.NAME
	set_attribute.value = p_name
	
	send_message_udp(set_attribute)


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
