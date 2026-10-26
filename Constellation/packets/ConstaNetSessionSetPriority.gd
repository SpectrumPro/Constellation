# Copyright (c) 2025 Liam Sherwin, All rights reserved.
# This file is part of the Constellation Network Engine, licensed under the GPL v3.

class_name ConstaNetSessionSetPriority extends ConstaNetHeadder
## ConstaNET Session Set Priority message


## Byte length for the session ID
const L_SESSION_ID: TypeLength = TypeLength.NODEID

## Byte length for the node ID
const L_NODE_ID: TypeLength = TypeLength.NODEID

## Byte length for the position
const L_POSITION: TypeLength = TypeLength.INT16


## Byte offset for the session ID
const O_SESSION_ID: int = 0

## Byte offset for the node ID
const O_NODE_ID: int = O_SESSION_ID + L_SESSION_ID

## Byte offset for the position
const O_POSITION: int = O_NODE_ID + L_NODE_ID


## String attribute for the session ID
const A_SESSION_ID: String = "session_id"

## String attribute for the node ID
const A_NODE_ID: String = "node_id"

## String attribute for the position
const A_POSITION: String = "position"


## Message size, fixed
const MESSAGE_SIZE: int = O_POSITION + L_POSITION


## The UUID of this session
var session_id: String

## The NodeId of the node to move
var node_id: String

## The position in the order to move it to
var position: int = -1


## Init
func _init() -> void:
	type = Type.SESSION_SET_PRIORITY


## Gets this ConstaNetSessionSetPriority as a Dictionary
func _get_as_dict() -> Dictionary[String, Variant]:
	return {
		A_SESSION_ID: session_id,
		A_NODE_ID: node_id,
		A_POSITION: position
	}


## Gets this ConstaNetSessionSetMaster as a PackedByteArray
func _get_as_packet() -> PackedByteArray:
	var result: PackedByteArray = PackedByteArray()
	result.resize(MESSAGE_SIZE)
	
	encode_node_id(O_SESSION_ID, session_id, result)
	encode_node_id(O_NODE_ID, node_id, result)
	result.encode_s16(O_POSITION, position)
	
	return result


## parses a Dictionary
func _parse_dict(p_dict: Dictionary) -> void:
	var p_session_id = type_convert(p_dict.get(A_SESSION_ID, ""), TYPE_STRING)
	var p_node_id = type_convert(p_dict.get(A_NODE_ID, ""), TYPE_STRING)
	var p_position = type_convert(p_dict.get(A_POSITION, -1), TYPE_INT)
	
	session_id = p_session_id
	node_id = p_node_id
	position = p_position


## parses a PackedByteArray
func _parse_packet(p_packet: PackedByteArray) -> void:
	if p_packet.size() < MESSAGE_SIZE:
		_network._log_warn("Unable to parse ConstaNetSessionSetPriority. Packet too short!")
		return
	
	var p_session_id: String = decode_node_id(O_SESSION_ID, p_packet)
	var p_node_id: String = decode_node_id(O_NODE_ID, p_packet)
	var p_position: int = p_packet.decode_s16(O_POSITION)
	
	session_id = p_session_id
	node_id = p_node_id
	position = p_position


## Checks if this ConstaNetSessionSetPriority is valid
func _is_valid() -> bool:
	if session_id and node_id and position >= -1:
		return true
	
	return false
