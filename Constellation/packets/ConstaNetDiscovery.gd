# Copyright (c) 2025 Liam Sherwin, All rights reserved.
# This file is part of the Constellation Network Engine, licensed under the GPL v3.

class_name ConstaNetDiscovery extends ConstaNetHeadder
## ConstaNET Discovery packet


## Byte length for the node IP address
const T_NODE_IP: DataType = DataType.IPV4

## Byte length for the RoleFlags
const T_ROLE_FLAGS: DataType = DataType.UINT16

## Byte length for the TCP port
const T_TCP_PORT: DataType = DataType.UINT16

## Byte length for the UDP port
const T_UDP_PORT: DataType = DataType.UINT16

## Byte length for the name length
const T_NAME_LENGTH: DataType = DataType.UINT16

## Byte length for the node name
const T_NODE_NAME: DataType = DataType.BLOCK


## Byte offset for the node IP address
const O_NODE_IP: int = 0

## Byte offset for the RoleFlags
const O_ROLE_FLAGS: int = O_NODE_IP + T_NODE_IP

## Byte offset for the TCP port
const O_TCP_PORT: int = O_ROLE_FLAGS + T_ROLE_FLAGS

## Byte offset for the UDP port
const O_UDP_PORT: int = O_TCP_PORT + T_TCP_PORT

## Byte offset for the name length
const O_NAME_LENGTH: int = O_UDP_PORT + T_UDP_PORT

## Byte offset for the node name
const O_NODE_NAME: int = O_NAME_LENGTH + T_NAME_LENGTH


## String attribute for node IP address
const A_NODE_IP: String = "node_ip"

## String attribute for RoleFlags
const A_ROLE_FLAGS: String = "role_flags"

## String attribute for the TCP port
const A_TCP_PORT: String = "tcp_port"

## String attribute for the UDP port
const A_UDP_PORT: String = "udp_port"

## String attribute for the node name
const A_NODE_NAME: String = "node_name"


## Byte length of this message with out the node name
const MESAGE_LENGTH_NO_NAME: int = O_NODE_NAME


## The IP address of the origin node
var node_ip: String = ""

## The NetworkRole of this node
var role_flags: int = RoleFlags.EXECUTOR

## The TCP port used by this node
var tcp_port: int = 0

## The UDP port used by this node
var udp_port: int = 0

## The name of the origin node
var node_name: String = "UnNamedNode"


## Init
func _init() -> void:
	type = Type.DISCOVERY


## Gets this ConstaNetDiscovery as a Dictionary
func _get_as_dict() -> Dictionary[String, Variant]:
	return {
		A_NODE_IP: node_ip,
		A_ROLE_FLAGS: role_flags,
		A_TCP_PORT: tcp_port,
		A_UDP_PORT: udp_port,
		A_NODE_NAME: node_name,
	}


## Gets this ConstaNetDiscovery as a PackedByteArray
func _get_as_packet() -> PackedByteArray:
	var result: PackedByteArray = PackedByteArray()
	result.resize(MESAGE_LENGTH_NO_NAME)
	
	encode_ipv4(O_NODE_IP, node_ip, result)
	result.encode_u16(O_ROLE_FLAGS, role_flags)
	
	result.encode_u16(O_TCP_PORT, tcp_port)
	result.encode_u16(O_UDP_PORT, udp_port)
	
	var name_buffer: PackedByteArray = node_name.to_ascii_buffer()
	
	result.encode_u16(O_NAME_LENGTH, name_buffer.size())
	result.append_array(name_buffer)
	
	return result


## Phrases a Dictionary
func _phrase_dict(p_dict: Dictionary) -> void:
	var p_node_ip = type_convert(p_dict.get(A_NODE_IP, ""), TYPE_STRING)
	var p_role_flags = type_convert(p_dict.get(A_ROLE_FLAGS, 0), TYPE_INT)
	var p_tcp_port = type_convert(p_dict.get(A_TCP_PORT, 0), TYPE_INT)
	var p_udp_port = type_convert(p_dict.get(A_UDP_PORT, 0), TYPE_INT)
	var p_node_name = type_convert(p_dict.get(A_NODE_NAME, ""), TYPE_STRING)
	
	node_ip = p_node_ip
	role_flags = p_role_flags
	tcp_port = p_tcp_port
	udp_port = p_udp_port
	node_name = p_node_name


## Phrases a PackedByteArray
func _phrase_packet(p_packet: PackedByteArray) -> void:
	if p_packet.size() < MESAGE_LENGTH_NO_NAME:
		return
	
	var p_node_ip: String = decode_ipv4(O_NODE_IP, p_packet)
	var p_role_flags: int = p_packet.decode_u16(O_ROLE_FLAGS)
	var p_tcp_port: int = p_packet.decode_u16(O_TCP_PORT)
	var p_udp_port: int = p_packet.decode_u16(O_UDP_PORT)
	
	var p_name_length: int = p_packet.decode_u16(O_NAME_LENGTH)
	
	if p_packet.size() < O_NODE_NAME + p_name_length:
		return
	
	var p_node_name: String = decode_block(
		O_NODE_NAME, 
		p_name_length, 
		p_packet
	).get_string_from_ascii()
	
	node_ip = p_node_ip
	role_flags = p_role_flags
	tcp_port = p_tcp_port
	udp_port = p_udp_port
	node_name = p_node_name


## Checks if this ConstaNetDiscovery is valid
func _is_valid() -> bool:
	if node_name and node_ip and tcp_port and udp_port:
		return true
	
	return false
