# Copyright (c) 2025 Liam Sherwin, All rights reserved.
# This file is part of the Constellation Network Engine, licensed under the GPL v3.

class_name ConstaNetSetAttribute extends ConstaNetHeadder
## ConstaNET Set Attribute packet, used to set an attribute of a node


## Attribute Enum
enum Attribute {
	UNKNOWN,		## Default State
	NAME,			## Sets the name of a node
	IP_ADDR,		## Sets the IpAddress of a node
	ROLE_FLAGS,		## Sets the RoleFlags of a node
	SESSION,		## Sets the session of a node
} 


## Byte length for attribute
const L_ATTRIBUTE: TypeLength = TypeLength.UINT16

## Byte length for the value length
const L_VALUE_LENGTH: TypeLength = TypeLength.UINT16

## Byte length for value
const L_VALUE: TypeLength = TypeLength.BLOCK


## Byte offset for attribute
const O_ATTRIBUTE: int = 0

## Byte offset for value size
const O_VALUE_LENGTH: int = O_ATTRIBUTE + L_ATTRIBUTE

## Byte offset for value data
const O_VALUE: int = O_VALUE_LENGTH + L_VALUE_LENGTH


## String attribute for attribute
const A_ATTRIBUTE: String = "attribute"

## String attribute for value
const A_VALUE: String = "value"


## Message size, excluding the value
const MESSAGE_SIZE: int = O_VALUE


## Type of attribute
var attribute: Attribute

## The value
var value: String = ""


## Init
func _init() -> void:
	type = Type.SET_ATTRIBUTE


## Gets this ConstaNetSetAttribute as a Dictionary
func _get_as_dict() -> Dictionary[String, Variant]:
	return {
		A_ATTRIBUTE: attribute,
		A_VALUE: value
	}


## Gets this ConstaNetSetAttribute as a PackedByteArray
func _get_as_packet() -> PackedByteArray:
	var result: PackedByteArray = PackedByteArray()
	result.resize(MESSAGE_SIZE)
	
	result.encode_u16(O_ATTRIBUTE, attribute)
	
	var value_bytes: PackedByteArray = value.to_ascii_buffer()
	result.encode_u16(O_VALUE_LENGTH, value_bytes.size())
	result.append_array(value_bytes)
	
	return result


## parses a Dictionary
func _parse_dict(p_dict: Dictionary) -> void:
	var p_attribute = type_convert(p_dict.get(A_ATTRIBUTE, 0), TYPE_INT)
	var p_value = type_convert(p_dict.get(A_VALUE, ""), TYPE_STRING)
	
	attribute = p_attribute
	value = p_value


## parses a PackedByteArray
func _parse_packet(p_packet: PackedByteArray) -> void:
	if p_packet.size() < MESSAGE_SIZE:
		_network._log_warn("Unable to parse ConstaNetSetAttribute. Packet too short!")
		return
	
	var p_attribute: int = p_packet.decode_u16(O_ATTRIBUTE)
	var p_value_length: int = p_packet.decode_u16(O_VALUE_LENGTH)
	
	if p_packet.size() < O_VALUE + p_value_length:
		_network._log_warn("Unable to parse ConstaNetSetAttribute. (p_packet.size() < O_VALUE + p_value_length) == true")
		return
	
	var p_value: String = decode_block(
		O_VALUE,
		p_value_length,
		p_packet
	).get_string_from_ascii()
	
	attribute = p_attribute as Attribute
	value = p_value


## Checks if this ConstaNetSetAttribute is valid
func _is_valid() -> bool:
	if attribute:
		return true
	
	return false
