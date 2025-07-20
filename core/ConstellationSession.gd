# Copyright (c) 2025 Liam Sherwin, All rights reserved.
# This file is part of the Constellation Network Engine, licensed under the GPL v3.

class_name ConstellationSession extends RefCounted
## Class to repersent a session


## Emitted when a node joins the session
signal node_joined(node: ConstellationNode)

## Emitted when a node leaves the session
signal node_left(node: ConstellationNode)

## Emitted when the SessionName is changed
signal name_changed(name: String)

## Emited when this session is to be deleted after all nodes disconnect
signal request_delete()


## All nodes in this session
var _nodes: Array[ConstellationNode]

## The SessionID of this session
var _session_id: String = UUID_Util.v4()

## The current SessionMaster
var _session_master: ConstellationNode

## Priority order
var _priority_order: Dictionary[int, ConstellationNode]

## The name of this session
var _name: String = "UnNamed ConstellationSession"


## Creates a new session from a ConstaNetSessionAnnounce message
static func create_from_session_announce(p_message: ConstaNetSessionAnnounce) -> ConstellationSession:
	var session: ConstellationSession = ConstellationSession.new()
	
	session._session_id = p_message.session_id
	session._name = p_message.session_name
	session._session_master = Network.get_node_from_id(p_message.session_master)
	
	for node_id: String in p_message.nodes:
		var node: ConstellationNode = Network.get_node_from_id(node_id)
		if node:
			session._nodes.append(node)
	
	return session


## Updates the details of this node with a ConstaNetSessionAnnounce message
func update_with(p_message: ConstaNetSessionAnnounce) -> bool:
	if _session_id != p_message.session_id:
		return false
	
	_set_session_master(Network.get_node_from_id(p_message.session_master))
	_set_name(p_message.session_name)
	_set_node_array(Network.get_node_array(p_message))
	
	return true


## Gets all nodes in this session
func get_nodes() -> Array[ConstellationNode]:
	return _nodes.duplicate()


## Shorthand to get the number of nodes in this session
func get_number_of_nodes() -> int:
	return len(_nodes)


## Gets the SessionID
func get_session_id() -> String:
	return _session_id


## Returns the current SessionMaster
func get_session_master() -> ConstellationNode:
	return _session_master


## Returns the priority order
func get_priority_order() -> Dictionary[int, ConstellationNode]:
	return _priority_order.duplicate()


## Gets the session name
func get_name() -> String:
	return _name


## Sets the SessionID
func _set_session_id(p_session_id: String) -> bool:
	if p_session_id == _session_id:
		return false
	
	_session_id = p_session_id
	return true


## Sets the session master node
func _set_session_master(p_session_master: ConstellationNode) -> bool:
	if p_session_master == _session_master:
		return false
	
	_session_master = p_session_master
	return true


## Sets the SessionName
func _set_name(p_name: String) -> bool:
	if p_name == _name:
		return false
	
	_name = p_name
	return true


## Sets the node array, and emits signals
func _set_node_array(p_node_array: Array[ConstellationNode]) -> void:
	var new_nodes: Array[ConstellationNode] = p_node_array.duplicate()
	
	for current_node: ConstellationNode in _nodes.duplicate():
		if current_node in new_nodes:
			new_nodes.erase(current_node)
		
		else:
			_remove_node(current_node)
	
	for new_node: ConstellationNode in new_nodes:
		_add_node(new_node)


## Adds a node into this session
func _add_node(p_node: ConstellationNode) -> bool:
	if p_node in _nodes:
		return false
	
	_nodes.append(p_node)
	node_joined.emit(p_node)
	
	return true


## Removes a node from this session
func _remove_node(p_node: ConstellationNode) -> bool:
	if p_node not in _nodes:
		return false
	
	_nodes.erase(p_node)
	node_left.emit(p_node)
	
	if not get_number_of_nodes():
		request_delete.emit()
	
	return true
