# Copyright (c) 2025 Liam Sherwin, All rights reserved.
# This file is part of the Constellation Network Engine, licensed under the GPL v3.

class_name ConstellationSession extends NetworkSession
## Class to repersent a session


## The Constellation NetworkHandler
static var _network: Constellation = null


## Max number of nodes allowed in a session
const MAX_NODES: int = 65535


## All nodes in this session
var _nodes: Array[ConstellationNode]

## The SessionID of this session
var _session_id: String = UUID.v4()

## Refmap for storing a nodes priority as {priority: ConstellationNode}
var _node_priorities: RefMap = RefMap.new()

## Stores a sorted list of node prioritys
var _priority_order: Array[int]

## SignalGroup for all nodes
var _node_connections: SignalGroup = SignalGroup.new([
	_on_node_connection_state_changed,
	_on_node_no_longer_unknown
]).set_prefix("_on_node_")


## Creates a new session from a ConstaNetSessionDiscovery message
static func create_from_session_discovery(p_message: ConstaNetSessionDiscovery) -> ConstellationSession:
	var session: ConstellationSession = ConstellationSession.new()
	var nodes: Dictionary[String, int] = p_message.nodes
	
	session._set_session_id(p_message.session_id)
	session._set_name(p_message.session_name)
	
	var add_node: Callable = (func(node_id: String) -> void:
		var node: ConstellationNode = _network.get_node_from_id(node_id, true)
		var priority: int = nodes[node_id]
		if node.is_local():
			_network.join_session(session, false, priority)
		else:
			session._add_node(node, false, priority)
	)
	
	if p_message.session_master:
		add_node.call(p_message.session_master)
		nodes.erase(p_message.session_master)
	
	for node_id: String in nodes:
		add_node.call(node_id)
	
	return session


## Creates a new unknown session
static func create_unknown_session(p_session_id: String) -> ConstellationSession:
	var session: ConstellationSession = ConstellationSession.new()
	
	session._set_session_id(p_session_id)
	session._mark_as_unknown(true)
	session._set_name("UnknownSession")
	
	return session


## init
func _init(p_uuid: String = UUID.v4(), ...p_args: Array[Variant]) -> void:
	super._init(p_uuid, p_args)
	_set_class_name("ConstellationSession")
	
	_settings.register_setting("Master", Data.Type.OBJECT, set_master, get_session_master, [master_changed]).set_class_filter(NetworkItem, ConstellationNode)
	_settings.register_status("MemberCount", Data.Type.INT, get_number_of_nodes, [node_joined, node_left])


## Sends a command to the session, using p_node_filter as the NodeFilter
func send_command(p_command: Variant, p_node_filter: NodeFilter = NodeFilter.AUTO, p_nodes: Array[NetworkNode] = []) -> Error:
	var message: ConstaNetCommand = ConstaNetCommand.new()
	
	message.command = p_command
	message.data_type = typeof(p_command)
	
	return send_pre_existing_command(message, p_node_filter, p_nodes)


## Sends a pre-existing ConstaNetCommand message to the session
func send_pre_existing_command(p_command: ConstaNetCommand, p_node_filter: NodeFilter = NodeFilter.AUTO, p_nodes: Array[NetworkNode] = []) -> Error:
	var local_node: ConstellationNode = _network.get_local_node()
	p_command.in_session = _session_id
	p_command.origin_id = local_node.get_node_id()
	
	if p_node_filter == NodeFilter.AUTO:
		if _session_master == local_node:
			p_node_filter = NodeFilter.ALL_OTHER_NODES
		else:
			p_node_filter = NodeFilter.MASTER
	
	match p_node_filter:
		NodeFilter.MASTER:
			if _session_master == local_node:
				local_node.handle_message(p_command)
				return OK
			
			elif has_session_master():
				p_command.target_id = _session_master.get_node_id()
				return _session_master.send_message(p_command)
			
			else:
				return ERR_DOES_NOT_EXIST
		
		NodeFilter.ALL_NODES:
			for node: ConstellationNode in _nodes:
				p_command.target_id = node.get_node_id()
				node.send_message(p_command)
			
			return OK
		
		NodeFilter.ALL_OTHER_NODES:
			for node: ConstellationNode in _nodes:
				if node == local_node:
					continue
				
				p_command.target_id = node.get_node_id()
				node.send_message(p_command)
				
			return OK
		
		NodeFilter.MANUAL:
			for node: ConstellationNode in p_nodes:
				p_command.target_id = node.get_node_id()
				node.send_message(p_command)
			
			return OK
		
		_:
			return ERR_INVALID_PARAMETER


## Sets a nodes priority index, pass -1 to remove the node from the priority order
func set_node_priority(p_node: NetworkNode, p_position: int) -> bool:
	if not _nodes.has(p_node):
		return false
	
	var new_position: int = _set_node_priority(p_node, p_position)
	var message: ConstaNetSessionSetPriority = ConstaNetSessionSetPriority.new()
	
	message.session_id = _session_id
	message.node_id = p_node.get_node_id()
	message.position = new_position
	message.origin_id = _network.get_node_id()
	message.set_announcement(true)
	
	_network._send_message_mcast(message)
	return true


## Sets the session master
func set_master(p_node: NetworkNode) -> bool:
	if not _set_session_master(p_node):
		return false
	
	var message: ConstaNetSessionSetAttribute = ConstaNetSessionSetAttribute.new()
	
	message.session_id = _session_id
	message.attribute = ConstaNetSessionSetAttribute.Attribute.MASTER
	message.value = p_node.get_node_id()
	message.origin_id = _network.get_node_id()
	message.set_announcement(true)
	
	_network._send_message_mcast(message)
	return true


## Sets the session name
func set_session_name(p_name: String) -> bool:
	if not _set_session_name(p_name):
		return false
	
	var message: ConstaNetSessionSetAttribute = ConstaNetSessionSetAttribute.new()
	
	message.session_id = _session_id
	message.attribute = ConstaNetSessionSetAttribute.Attribute.NAME
	message.value = p_name
	message.origin_id = _network.get_node_id()
	message.set_announcement(true)
	
	_network._send_message_mcast(message)
	return true


## Gets all nodes in this session
func get_nodes() -> Array[NetworkNode]:
	var return_value: Array[NetworkNode]
	return_value.assign(_nodes)
	
	return return_value


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
func get_priority_order() -> Dictionary[int, NetworkNode]:
	var return_value: Dictionary[int, NetworkNode]
	return_value.assign(_node_priorities.get_as_dict())
	
	return return_value


## Returns the priority order
func get_priority_of(p_node: NetworkNode) -> int:
	return _node_priorities.right(p_node, -1)


## Gets the session flags
func get_session_flags() -> int:
	return _session_flags


## Returns true if this session has a master
func has_session_master() -> bool:
	return _session_master != null


## Returns true if the given node is a member of this session
func has_node_in_session(p_node: ConstellationNode) -> bool:
	return _nodes.has(p_node)


## Closes this sessions local object
func delete() -> void:
	super.delete()
	_set_session_master(null)
	
	for node: ConstellationNode in _nodes.duplicate():
		_remove_node(node)


## Sets the SessionID, WARNING: this will change the NetworkItem's uuid
func _set_session_id(p_session_id: String) -> bool:
	if p_session_id == _session_id:
		return false
	
	_session_id = p_session_id
	_uuid = _session_id
	return true


## Sets the session master node
func _set_session_master(p_session_master: ConstellationNode) -> bool:
	if p_session_master == _session_master:
		return false
	
	if is_instance_valid(_session_master):
		_session_master._remove_session_master_mark()
	
	if not _nodes.has(p_session_master):
		return false
	
	_session_master = p_session_master
	_session_master._mark_as_session_master()
	
	master_changed.emit(_session_master)
	return true


## Sets the name of this session
func _set_session_name(p_name: String) -> bool:
	if p_name == _name:
		return false
	
	_name = p_name
	session_name_changed.emit(_name)
	
	return true


## Sets the priority index of a node, pass -1 to remove the node from the priority order, returns the new priority
func _set_node_priority(p_node: ConstellationNode, p_position: int) -> int:
	var requested_position: int = clampi(p_position, -1, MAX_NODES)
	
	if not _nodes.has(p_node):
		push_error("Given node does not exist in this session")
		return -1
	
	if _node_priorities.right(p_node) == requested_position:
		return requested_position
	
	if requested_position == -1:
		_node_priorities.erase_right(p_node)
	
	elif _node_priorities.has_left(requested_position):
		_node_priorities.erase_right(p_node)
		_shift_order(requested_position + 1)
		_node_priorities.map(requested_position, p_node)
	
	else:
		_node_priorities.erase_right(p_node)
		_node_priorities.map(requested_position, p_node)
	
	_priority_order.clear()
	_priority_order.assign(_node_priorities.get_left())
	_priority_order.sort()
	
	p_node.priority_changed.emit(requested_position)
	priority_changed.emit(p_node, requested_position)
	
	return requested_position


## Checks and shifts the given element
func _shift_order(p_current_index: int) -> void:
	if _node_priorities.left(p_current_index):
		_shift_order(p_current_index + 1)
	
	var previous_index: int = p_current_index - 1
	var node: ConstellationNode = _node_priorities.left(previous_index)
	
	_node_priorities.erase_left(previous_index)
	_node_priorities.map(p_current_index, node)
	
	node.priority_changed.emit(p_current_index)


## Returns the next free priority index
func _get_next_priority_index() -> int:
	if not _priority_order:
		return 0
	
	for index: int in range(_priority_order.size()):
		if _priority_order[index] != index:
			return index
	
	return _priority_order[-1] + 1


## Adds a node into this session
func _add_node(p_node: ConstellationNode, p_auto_priority: bool = true, p_priority: int = -1) -> bool:
	if _nodes.has(p_node):
		push_error("_add_node: Given node already exists in this session")
		return false
	
	if _nodes.size() > MAX_NODES:
		push_error("_add_node: Max number of nodes has been reached in this session")
		return false
	
	_nodes.append(p_node)
	_node_connections.connect_object(p_node, true)
	_set_node_priority(p_node, _get_next_priority_index() if p_auto_priority else p_priority)
	
	if not p_node.is_local() and _network.get_local_node().get_session() == self and not p_node.is_in_connection_state():
		_network._logv("A new ConstellationNode: \"", p_node.get_node_name(), "\" has joined the current session. Initalizing auto-connect")
		p_node.connect_node_and_add_lock(self)
	
	node_joined.emit(p_node)
	
	if p_node.get_session() != self:
		p_node._set_session(self)
	
	_elect_new_master()
	return true


## Removes a node from this session
func _remove_node(p_node: ConstellationNode, p_no_delete: bool = false) -> bool:
	if not _nodes.has(p_node):
		return false
	
	_set_node_priority(p_node, -1)
	_nodes.erase(p_node)
	_node_connections.disconnect_object(p_node, true)
	
	if p_node == _session_master:
		_elect_new_master()
	
	if not p_node.is_local() and _network.get_local_node().get_session() == self:
		p_node.remove_connection_lock(self)
	
	node_left.emit(p_node)
	
	if not get_number_of_nodes() and not p_no_delete:
		delete()
	
	return true


## Elects a new session master from the proirity order
func _elect_new_master() -> ConstellationNode:
	if _nodes.has(_session_master) and _session_master.get_connection_state() == NetworkNode.ConnectionState.CONNECTED:
		return _session_master
	
	var candidate: ConstellationNode = _node_priorities.left(_priority_order.get(0))
	
	if _set_session_master(candidate):
		return candidate
	else:
		return null


## Updates the details of this node with a ConstaNetSessionAnnounce message
func _update_with(p_message: ConstaNetSessionDiscovery) -> bool:
	if _session_id != p_message.session_id:
		return false
	
	_set_session_master(_network.get_node_from_id(p_message.session_master, true))
	_set_name(p_message.session_name)
	
	var new_nodes: Dictionary[String, int] = p_message.nodes.duplicate()
	
	for current_node: ConstellationNode in _nodes.duplicate():
		var node_id: String = current_node.get_node_id()
		
		if new_nodes.has(node_id):
			_set_node_priority(current_node, new_nodes[node_id])
			new_nodes.erase(node_id)
		
		else:
			_remove_node(current_node, true)
	
	for node_id: String in new_nodes:
		_add_node(_network.get_node_from_id(node_id, true), false, new_nodes[node_id])
	
	#TODO, this feels jankey, maybe add check to only allow this method to run when the session is unknown???
	
	return true


## Called when the ConnectionState changes on any node in this session
func _on_node_connection_state_changed(p_connection_state: ConstellationNode.ConnectionState, p_node: ConstellationNode) -> void:
	if _network.get_local_node() not in _nodes:
		return
	
	_network._logv("ConnectionState of: ", p_node.get_node_name(), ", changed to: ", ConstellationNode.ConnectionState.keys()[p_connection_state], ", in session: ", get_session_name())
	
	match p_connection_state:
		ConstellationNode.ConnectionState.UNKNOWN, ConstellationNode.ConnectionState.DISCOVERED, ConstellationNode.ConnectionState.LOST_CONNECTION:
			if p_node == _session_master:
				_elect_new_master()
		
		ConstellationNode.ConnectionState.CONNECTED:
			if p_node.is_sesion_master():
				_network.get_local_node().connected_to_session_master.emit()


## Called when any node in this session is found on the network, when previousley unknown
func _on_node_no_longer_unknown(p_node: ConstellationNode) -> void:
	node_joined.emit(p_node)
