# Copyright (c) 2025 Liam Sherwin, All rights reserved.
# This file is part of the Constellation Network Engine, licensed under the GPL v3.

class_name ConstaNetSessionSetAttribute extends ConstaNetHeadder
## ConstaNET Session Set Arrtibute packet


## Attribute Enum
enum Attribute {
	UNKNOWN,		## Default State
	NAME,			## Sets the name of a device
	MASTER,			## Sets the Ip Address of a supported device
}


## Byte length for session_id
const T_SESSION_ID: DataType = DataType.NODEID

## Byte length for attribute
const T_ATTRIBUTE: DataType = DataType.UINT16

const T_VALUE_LENGTH: DataType = DataType.UINT16

## Byte length for value
const T_VALUE: DataType = DataType.BLOCK


## Byte offset for session_id
const O_SESSION_ID: int = 0

## Byte offset for attribute
const O_ATTRIBUTE: int = O_SESSION_ID + T_SESSION_ID

## Byte offset for value size
const O_VALUE_LENGTH: int = O_ATTRIBUTE + T_ATTRIBUTE

## Byte offset for value data
const O_VALUE: int = O_VALUE_LENGTH + T_VALUE_LENGTH


## String attribute for session_id
const A_SESSION_ID: String = "session_id"

## String attribute for attribute
const A_ATTRIBUTE: String = "attribute"

## String attribute for value
const A_VALUE: String = "value"


## Message length, excluding value data
const MESSAGE_LENGTH: int = O_VALUE


## SessionID of the target session
var session_id: String = ""

## Type of attribute
var attribute: Attribute

## The value
var value: String = ""


## Init
func _init() -> void:
	type = Type.SESSION_SET_ATTRIBUTE


## Gets this ConstaNetSessionSetAttribute as a Dictionary
func _get_as_dict() -> Dictionary[String, Variant]:
	return {
		A_SESSION_ID: session_id,
		A_ATTRIBUTE: attribute,
		A_VALUE: value,
	}


## Gets this ConstaNetSessionSetAttribute as a PackedByteArray
func _get_as_packet() -> PackedByteArray:
	var result: PackedByteArray = PackedByteArray()
	result.resize(MESSAGE_LENGTH)
	
	encode_node_id(O_SESSION_ID, session_id, result)
	result.encode_u16(O_ATTRIBUTE, attribute)
	
	var value_buffer: PackedByteArray = value.to_ascii_buffer()
	result.encode_u16(O_VALUE_LENGTH, value_buffer.size())
	result.append_array(value_buffer)
	
	return result


## Phrases a Dictionary
func _phrase_dict(p_dict: Dictionary) -> void:
	var p_session_id = type_convert(p_dict.get(A_SESSION_ID, ""), TYPE_STRING)
	var p_attribute = type_convert(p_dict.get(A_ATTRIBUTE, 0), TYPE_INT)
	var p_value = type_convert(p_dict.get(A_VALUE, ""), TYPE_STRING)
	
	session_id = p_session_id
	attribute = p_attribute
	value = p_value


## Phrases a PackedByteArray
func _phrase_packet(p_packet: PackedByteArray) -> void:
	if p_packet.size() < MESSAGE_LENGTH:
		return
	
	var p_session_id: String = decode_node_id(O_SESSION_ID, p_packet)
	var p_attribute: int = p_packet.decode_u16(O_ATTRIBUTE)
	var p_value_length: int = p_packet.decode_u16(O_VALUE_LENGTH)
	
	if p_packet.size() < O_VALUE + p_value_length:
		return
	
	var p_value: String = decode_block(
		O_VALUE,
		p_value_length,
		p_packet
	).get_string_from_ascii()
	
	session_id = p_session_id
	attribute = p_attribute as Attribute
	value = p_value


## Checks if this ConstaNetSessionSetAttribute is valid
func _is_valid() -> bool:
	if attribute:
		return true
	
	return false
