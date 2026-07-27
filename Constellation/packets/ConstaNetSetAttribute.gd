# Copyright (c) 2025 Liam Sherwin, All rights reserved.
# This file is part of the Constellation Network Engine, licensed under the GPL v3.

class_name ConstaNetSetAttribute extends ConstaNetHeadder
## ConstaNET Set Arrtibute packet


## Byte length for attribute
const T_ATTRIBUTE: DataType = DataType.UINT16

## Byte length for the value length
const T_VALUE_LENGTH: DataType = DataType.UINT16

## Byte length for value
const T_VALUE: DataType = DataType.BLOCK


## Byte offset for attribute
const O_ATTRIBUTE: int = 0

## Byte offset for value size
const O_VALUE_LENGTH: int = O_ATTRIBUTE + T_ATTRIBUTE

## Byte offset for value data
const O_VALUE: int = O_VALUE_LENGTH + T_VALUE_LENGTH


## String attribute for attribute
const A_ATTRIBUTE: String = "attribute"

## String attribute for value
const A_VALUE: String = "value"


## Message size, excluding the value
const MESSAGE_SIZE: int = O_VALUE


## Attribute Enum
enum Attribute {
	UNKNOWN,		## Default State
	NAME,			## Sets the name of a device
	IP_ADDR,		## Sets the Ip Address of a supported device
	SESSION,		## Tells the device to join the given session
}


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
		return
	
	var p_attribute: int = p_packet.decode_u16(O_ATTRIBUTE)
	var p_value_length: int = p_packet.decode_u16(O_VALUE_LENGTH)
	
	if p_packet.size() < O_VALUE + p_value_length:
		return
	
	var p_value: String = decode_block(
		O_VALUE,
		p_value_length,
		p_packet
	).get_string_from_ascii()
	
	attribute = p_attribute as Attribute
	value = p_value


## Checks if this ConstaNetDiscovery is valid
func _is_valid() -> bool:
	if attribute:
		return true
	
	return false
