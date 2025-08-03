# Copyright (c) 2025 Liam Sherwin, All rights reserved.
# This file is part of the Constellation Network Engine, licensed under the GPL v3.

class_name UISessionMasterOrder extends Control
## Manages the master order of sessions


## The tree to show the order
@export var _order_tree: Tree

## The OptionButton to choose the Session
@export var _selection_button: OptionButton

## Button to move the selected item up
@export var _move_order_up: Button

## Button to move the selected item down
@export var _move_order_down: Button


## Columns enu
enum Columns {NAME}


## The selected session
var _session: ConstellationSession

## Sore all sessions shown in the selection button
var _sessions: Array[ConstellationSession] = [null]

## SignalGroup for each session
var _session_connections: SignalGroup = SignalGroup.new([
	_on_session_request_delete,
]).no_bind([
	_on_session_node_joined,
	_on_session_node_left,
]).set_prefix("_on_session_")


## Ready
func _ready() -> void:
	Network.session_created.connect(_on_session_created)
	
	_order_tree.columns = len(Columns)
	_order_tree.hide_root = true


## Sets the session thats shown
func set_session(p_session: ConstellationSession) -> void:
	if p_session == _session:
		return
	
	_session = p_session
	
	if is_instance_valid(p_session):
		_reload_tree(p_session)
	
	else:
		_order_tree.clear()
		
		_move_order_up.set_disabled(true)
		_move_order_down.set_disabled(true)


## Reloads the tree with the given session
func _reload_tree(p_session: ConstellationSession) -> void:
	_order_tree.clear()
	_order_tree.create_item()
	
	for node: ConstellationNode in p_session.get_priority_order():
		var node_item: TreeItem = _order_tree.create_item()
		
		node_item.set_text(Columns.NAME, node.get_node_name())


## Called when a session is created
func _on_session_created(p_session: ConstellationSession) -> void:
	_session_connections.connect_object(p_session, true)
	
	_sessions.append(p_session)
	_selection_button.add_item(p_session.get_name(), _sessions.find(p_session) + 1)


## Called when a session is to be deleted
func _on_session_request_delete(p_session: ConstellationSession) -> void:
	_session_connections.disconnect_object(p_session, true)
	
	_selection_button.remove_item(_sessions.find(p_session) + 1)
	_sessions.erase(p_session)


## Called when a node joins the session
func _on_session_node_joined(p_node: ConstellationNode) -> void:
	_reload_tree(_session)


## Called when a node leaves the session
func _on_session_node_left(p_node: ConstellationNode) -> void:
	_reload_tree(_session)


## Called when an item is selected in the session selection button
func _on_session_selection_item_selected(index: int) -> void:
	if index:
		set_session(_sessions[index])
	else:
		set_session(null)
