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

## RefMap for TreeItem: ConstellationNode
var _items: RefMap = RefMap.new()

## SignalGroup for each session
var _session_connections: SignalGroup = SignalGroup.new([
	_on_session_request_delete,
	_on_session_node_joined,
	_on_session_node_left,
	_on_session_priority_changed
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
	_reload_tree(_session)


## Reloads the tree with the given session
func _reload_tree(p_session: ConstellationSession) -> void:
	_order_tree.clear()
	_order_tree.create_item()
	_items.clear()
	
	_move_order_up.set_disabled(true)
	_move_order_down.set_disabled(true)
	
	if p_session:
	
		for node: ConstellationNode in p_session.get_priority_order():
			var node_item: TreeItem = _order_tree.create_item()
			_items.map(node_item, node)
			
			node_item.set_text(Columns.NAME, node.get_node_name())


## Called when a session is created
func _on_session_created(p_session: ConstellationSession) -> void:
	_session_connections.connect_object(p_session, true)
	
	var index: int = _selection_button.selected
	
	_sessions.append(p_session)
	_selection_button.add_item(p_session.get_name(), _sessions.find(p_session))
	
	_selection_button.select(index)


## Called when a session is to be deleted
func _on_session_request_delete(p_session: ConstellationSession) -> void:
	_session_connections.disconnect_object(p_session, true)
	
	_selection_button.remove_item(_sessions.find(p_session))
	_selection_button.select(0)
	_sessions.erase(p_session)
	
	if p_session == _session:
		set_session(null)


## Called when a node joins the session
func _on_session_node_joined(p_node: ConstellationNode, p_session: ConstellationSession) -> void:
	prints(p_node.get_node_name(),  "Joined:",  p_session.get_name())
	if p_session == _session:
		_reload_tree(_session)


## Called when a node leaves the session
func _on_session_node_left(p_node: ConstellationNode, p_session: ConstellationSession) -> void:
	if p_session == _session:
		_reload_tree(_session)


## Called when the position is changed on any node in the sesion
func _on_session_priority_changed(p_node: ConstellationNode, p_position: int, p_session: ConstellationSession) -> void:
	if p_session == _session:
		_reload_tree(p_session)


## Called when an item is selected in the session selection button
func _on_session_selection_item_selected(index: int) -> void:
	if index:
		set_session(_sessions[index])
	else:
		set_session(null)


## Called when nothing is selected in the tree
func _on_order_tree_nothing_selected() -> void:
	_move_order_up.set_disabled(true)
	_move_order_down.set_disabled(true)
	
	_order_tree.deselect_all()


## Called when an item is selected in the tree
func _on_order_tree_item_selected() -> void:
	_move_order_up.set_disabled(false)
	_move_order_down.set_disabled(false)


## Called when the move up button is pressed
func _on_move_order_up_pressed() -> void:
	var node: ConstellationNode = _items.left(_order_tree.get_selected())
	
	_session.set_priority_order(node, _session.get_priority_of(node) - 1)


## Called when the move down button is pressed
func _on_move_order_down_pressed() -> void:
	var node: ConstellationNode = _items.left(_order_tree.get_selected())
	
	_session.set_priority_order(node, _session.get_priority_of(node) + 1)


## Called when the make master button is pressed
func _on_make_master_pressed() -> void:
	pass # Replace with function body.
