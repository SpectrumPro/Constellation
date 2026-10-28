# Copyright (c) Liam Sherwin. All rights reserved.
# This file is part of the Constellation Network Engine.
# Licensed under the GPL v3.0 or later. See the LICENSE.md file for details.

class_name ConstaNetSessionDiscovery extends ConstaNetHeadder
## ConstaNET Session Discovery message, used for session discovery requests / acknowledgements between nodes


## Byte length for the session ID
const L_SESSION_ID: TypeLength = TypeLength.NODEID

## Byte length for the session master node ID
const L_SESSION_MASTER: TypeLength = TypeLength.NODEID

## Byte length for the session name length
const L_SESSION_NAME_LENGTH: TypeLength = TypeLength.UINT16

## Byte length for the session name
const L_SESSION_NAME: TypeLength = TypeLength.BLOCK

## Byte length for lenght of nodes
const L_NUM_NODES: TypeLength = TypeLength.UINT16

## Byte length for the nodes list
const L_NODES: TypeLength = TypeLength.BLOCK


## Byte offset for the session ID
const O_SESSION_ID: int = 0

## Byte offset for the session master node ID
const O_SESSION_MASTER: int = O_SESSION_ID + L_SESSION_ID

## Byte offset for the session name length
const O_SESSION_NAME_LENGTH: int = O_SESSION_MASTER + L_SESSION_MASTER

## Byte offset for the session name
const O_SESSION_NAME: int = O_SESSION_NAME_LENGTH + L_SESSION_NAME_LENGTH

## Byte offset for length of nodes
const O_NUM_NODES: int = O_SESSION_NAME + L_SESSION_NAME

## Byte offset for nodes
const O_NODES: int = O_NUM_NODES + L_NUM_NODES


## String attribute for the session ID
const A_SESSION_ID: String = "session_id"

## String attribute for the session master node ID
const A_SESSION_MASTER: String = "session_master"

## String attribute for the session name
const A_SESSION_NAME: String = "session_name"

## String attribute for the nodes list
const A_NODES: String = "nodes"


## Length of this message excluding name and nodes
const MESSAGE_LENGTH: int = O_SESSION_NAME 


## The SessionID of this session
var session_id: String

## NodeID of the session master
var session_master: String

## The name of the session
var session_name: String

## All nodes in this sesion, stored as {NodeID: priority}
var nodes: Dictionary[String, int]


## init
func _init() -> void:
	type = Type.SESSION_DISCOVERY


## Gets this ConstaNetSessionDiscovery as a Dictionary
func _get_as_dict() -> Dictionary[String, Variant]:
	return {
		A_SESSION_ID: session_id,
		A_SESSION_MASTER: session_master,
		A_SESSION_NAME: session_name,
		A_NODES: nodes
	}


## Gets this ConstaNetSessionDiscovery as a PackedByteArray
func _get_as_packet() -> PackedByteArray:
	var result: PackedByteArray = PackedByteArray()
	var name_buffer: PackedByteArray = session_name.to_ascii_buffer()
	var offset: int = 0
	
	result.resize(
		MESSAGE_LENGTH + 
		name_buffer.size() + 
		L_NUM_NODES
	)
	
	encode_node_id(O_SESSION_ID, session_id, result)
	encode_node_id(O_SESSION_MASTER, session_master, result)
	
	result.encode_u16(O_SESSION_NAME_LENGTH, name_buffer.size())
	encode_block(O_SESSION_NAME, name_buffer, result)
	offset += name_buffer.size()
	
	result.encode_u16(O_NUM_NODES + offset, nodes.size())
	for node_id: String in nodes:
		var id_buffer: PackedByteArray = get_id_as_buffer(node_id)
		
		id_buffer.resize(NODE_ID_LENGTH + TypeLength.INT16)
		id_buffer.encode_u16(NODE_ID_LENGTH, nodes[node_id])
		
		result.append_array(id_buffer)
	
	return result


## parses a Dictionary
func _parse_dict(p_dict: Dictionary) -> void:
	var p_session_id = type_convert(p_dict.get(A_SESSION_ID, ""), TYPE_STRING)
	var p_session_master = type_convert(p_dict.get(A_SESSION_MASTER, ""), TYPE_STRING)
	var p_session_name = type_convert(p_dict.get(A_SESSION_NAME, ""), TYPE_STRING)
	var p_nodes: Dictionary = type_convert(p_dict.get("nodes", {}), TYPE_DICTIONARY)
	
	session_id = p_session_id
	session_master = p_session_master
	session_name = p_session_name
	
	for node_id: Variant in p_nodes:
		nodes[node_id] = type_convert(p_nodes[node_id], TYPE_INT)


## parses a PackedByteArray
func _parse_packet(p_packet: PackedByteArray) -> void:
	if p_packet.size() < MESSAGE_LENGTH:
		_network._log_warn("Unable to parse ConstaNetSessionAnnounce. Packet too short!")
		return
	
	var p_session_id: String = decode_node_id(O_SESSION_ID, p_packet)
	var p_session_master: String = decode_node_id(O_SESSION_MASTER, p_packet)
	var p_name_length: int = p_packet.decode_u16(O_SESSION_NAME_LENGTH)
	
	if p_packet.size() < O_SESSION_NAME + p_name_length:
		_network._log_warn("Unable to parse ConstaNetSessionAnnounce. (p_packet.size() < O_SESSION_NAME + p_name_length) == true")
		return
	
	var p_session_name: String = decode_block(
		O_SESSION_NAME, 
		p_name_length, 
		p_packet
	).get_string_from_ascii()
	
	var offset: int = p_name_length
	var p_num_nodes: int = p_packet.decode_u16(O_NUM_NODES + offset)
	
	if p_packet.size() < (p_num_nodes * (NODE_ID_LENGTH + TypeLength.INT16)) + offset:
		_network._log_warn("Unable to parse ConstaNetSessionAnnounce. (p_packet.size() < (p_num_nodes * (NODE_ID_LENGTH + TypeLength.INT16)) + offset) == true")
		return
	
	var p_nodes: Dictionary[String, int] = {}
	
	for index: int in range(0, p_num_nodes):
		var node_id: String = decode_node_id(O_NODES + offset, p_packet)
		offset += NODE_ID_LENGTH
		
		p_nodes[node_id] = p_packet.decode_s16(O_NODES + offset)
		offset += TypeLength.INT16
	
	session_id = p_session_id
	session_master = p_session_master
	session_name = p_session_name
	nodes = p_nodes


## Checks if this ConstaNetSessionDiscovery is valid
func _is_valid() -> bool:
	if session_id or is_request():
		return true
	
	return false
