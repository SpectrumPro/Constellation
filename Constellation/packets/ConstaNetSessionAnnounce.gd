# Copyright (c) 2025 Liam Sherwin, All rights reserved.
# This file is part of the Constellation Network Engine, licensed under the GPL v3.

class_name ConstaNetSessionAnnounce extends ConstaNetHeadder
## ConstaNET Session Announce message


## Byte length for the session ID
const T_SESSION_ID: DataType = DataType.NODEID

## Byte length for the session master node ID
const T_SESSION_MASTER: DataType = DataType.NODEID

## Byte length for the session name length
const T_SESSION_NAME_LENGTH: DataType = DataType.UINT16

## Byte length for the session name
const T_SESSION_NAME: DataType = DataType.BLOCK

## Byte length for lenght of nodes
const T_NUM_NODES: DataType = DataType.UINT16

## Byte length for the nodes list
const T_NODES: DataType = DataType.BLOCK


## Byte offset for the session ID
const O_SESSION_ID: int = 0

## Byte offset for the session master node ID
const O_SESSION_MASTER: int = O_SESSION_ID + T_SESSION_ID

## Byte offset for the session name length
const O_SESSION_NAME_LENGTH: int = O_SESSION_MASTER + T_SESSION_MASTER

## Byte offset for the session name
const O_SESSION_NAME: int = O_SESSION_NAME_LENGTH + T_SESSION_NAME_LENGTH

## Byte offset for length of nodes
const O_NUM_NODES: int = O_SESSION_NAME + T_SESSION_NAME

## Byte offset for nodes
const O_NODES: int = O_NUM_NODES + T_NUM_NODES


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

## All NodeIDs in this session
var nodes: Array[String]


## Init
func _init() -> void:
	type = Type.SESSION_ANNOUNCE


## Gets this ConstaNetSessionJoin as a Dictionary
func _get_as_dict() -> Dictionary[String, Variant]:
	return {
		A_SESSION_ID: session_id,
		A_SESSION_MASTER: session_master,
		A_SESSION_NAME: session_name,
		A_NODES: nodes
	}


## Gets this ConstaNetSessionJoin as a PackedByteArray
func _get_as_packet() -> PackedByteArray:
	var result: PackedByteArray = PackedByteArray()
	var name_buffer: PackedByteArray = session_name.to_ascii_buffer()
	var offset: int = 0
	
	result.resize(
		MESSAGE_LENGTH + 
		name_buffer.size() + 
		T_NUM_NODES
	)
	
	encode_node_id(O_SESSION_ID, session_id, result)
	encode_node_id(O_SESSION_MASTER, session_master, result)
	
	result.encode_u16(O_SESSION_NAME_LENGTH, name_buffer.size())
	encode_block(O_SESSION_NAME, name_buffer, result)
	offset += name_buffer.size()
	
	result.encode_u16(O_NUM_NODES + offset, nodes.size())
	for node_id: String in nodes:
		result.append_array(get_id_as_buffer(node_id))
	
	return result


## parses a Dictionary
func _parse_dict(p_dict: Dictionary) -> void:
	var p_session_id = type_convert(p_dict.get(A_SESSION_ID, ""), TYPE_STRING)
	var p_session_master = type_convert(p_dict.get(A_SESSION_MASTER, ""), TYPE_STRING)
	var p_session_name = type_convert(p_dict.get(A_SESSION_NAME, ""), TYPE_STRING)
	var p_nodes: Array = type_convert(p_dict.get("nodes", []), TYPE_ARRAY)
	
	session_id = p_session_id
	session_master = p_session_master
	session_name = p_session_name
	
	for node: Variant in p_nodes:
		nodes.append(str(node))


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
	
	if p_packet.size() < (p_num_nodes * NODE_ID_LENGTH) + offset:
		_network._log_warn("Unable to parse ConstaNetSessionAnnounce. (p_packet.size() < (p_num_nodes * NODE_ID_LENGTH) + offset) == true")
		return
	
	var p_nodes: Array[String] = []
	p_nodes.resize(p_num_nodes)
	
	for index: int in range(0, p_num_nodes):
		p_nodes[index] = decode_node_id(O_NODES + offset, p_packet)
		offset += NODE_ID_LENGTH
	
	session_id = p_session_id
	session_master = p_session_master
	session_name = p_session_name
	nodes = p_nodes


## Checks if this ConstaNetSessionJoin is valid
func _is_valid() -> bool:
	if session_id:
		return true
	
	return false
