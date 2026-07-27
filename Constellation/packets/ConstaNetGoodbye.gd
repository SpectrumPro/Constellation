# Copyright (c) 2025 Liam Sherwin, All rights reserved.
# This file is part of the Constellation Network Engine, licensed under the GPL v3.

class_name ConstaNetGoodbye extends ConstaNetHeadder
## ConstaNET Goodbye packet


## Byte length for the length of reason string
const T_REASON_LENGTH: DataType = DataType.UINT16

## Byte length for the reason string
const T_REASON_STRING: DataType = DataType.BLOCK


## Byte offset for reason length
const O_REASON_LENGTH: int = 0

## Byte offset for reason string
const O_REASON_STRING: int = O_REASON_LENGTH + T_REASON_LENGTH


## String attribute for reason
const A_REASON: String = "reason"


## Message length with out the varibal reason
const MESSAGE_LENGTH_NO_REASON: int = O_REASON_STRING


## Reason for this node going offlin
var reason: String = "Unknown"


## Init
func _init() -> void:
	type = Type.GOODBYE


## Gets this ConstaNetGoodbye as a Dictionary
func _get_as_dict() -> Dictionary[String, Variant]:
	return {
		A_REASON: reason,
	}


## Gets this ConstaNetGoodbye as a PackedByteArray
func _get_as_packet() -> PackedByteArray:
	var result: PackedByteArray = PackedByteArray()
	result.resize(MESSAGE_LENGTH_NO_REASON)
	
	var reason_buffer: PackedByteArray = reason.to_ascii_buffer()
	result.encode_u16(O_REASON_LENGTH, reason_buffer.size())
	result.append_array(reason_buffer)
	
	return result


## Phrases a Dictionary
func _phrase_dict(p_dict: Dictionary) -> void:
	reason = type_convert(p_dict.get(A_REASON, ""), TYPE_STRING)


## Phrases a PackedByteArray
func _phrase_packet(p_packet: PackedByteArray) -> void:
	if p_packet.size() < MESSAGE_LENGTH_NO_REASON:
		return
	
	var p_reason_length: int = p_packet.decode_u16(O_REASON_LENGTH)
	
	if p_packet.size() < O_REASON_STRING + p_reason_length:
		return
	
	var p_reason_string: String = decode_block(
		O_REASON_STRING, 
		p_reason_length, 
		p_packet
	).get_string_from_ascii()
	
	reason = p_reason_string


## Checks if this ConstaNetGoodbye is valid
func _is_valid() -> bool:
	return true
