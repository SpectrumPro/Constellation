# Copyright (c) 2025 Liam Sherwin, All rights reserved.
# This file is part of the Constellation Network Engine, licensed under the GPL v3.

class_name ConstaNetSessionJoin extends ConstaNetHeadder
## ConstaNET Session Join message


## Byte length for session_id
const T_SESSION_ID: DataType = DataType.NODEID

## Byte offset for session_id
const O_SESSION_ID: int = 0

## String attribute for session_id
const A_SESSION_ID: String = "session_id"

## Message length
const MESSAGE_LENGTH: int = O_SESSION_ID + T_SESSION_ID


## The UUID of this session
var session_id: String


## Init
func _init() -> void:
	type = Type.SESSION_JOIN


## Gets this ConstaNetSessionJoin as a Dictionary
func _get_as_dict() -> Dictionary[String, Variant]:
	return {
		A_SESSION_ID: session_id,
	}


## Gets this ConstaNetSessionJoin as a PackedByteArray
func _get_as_packet() -> PackedByteArray:
	var result: PackedByteArray = PackedByteArray()
	result.resize(MESSAGE_LENGTH)
	
	encode_node_id(O_SESSION_ID, session_id, result)
	return result


## Phrases a Dictionary
func _phrase_dict(p_dict: Dictionary) -> void:
	var p_session_id = type_convert(p_dict.get(A_SESSION_ID, ""), TYPE_STRING)
	session_id = p_session_id


## Phrases a PackedByteArray
func _phrase_packet(p_packet: PackedByteArray) -> void:
	if p_packet.size() < MESSAGE_LENGTH:
		return
	
	var p_session_id = decode_node_id(O_SESSION_ID, p_packet)
	session_id = p_session_id


## Checks if this ConstaNetSessionJoin is valid
func _is_valid() -> bool:
	if session_id:
		return true
	
	return false
