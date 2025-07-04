# Copyright (c) 2024 Liam Sherwin, All rights reserved.
# This file is part of the Spectrum Lighting Engine, licensed under the GPL v3.

class_name UIControl extends Control
## Shows all ConstellationNodes in a tree


## The Tree for all ConstellationNode
@export var _node_tree: Tree

## The LineEdit to change the name of the local node
@export var _name_edit: LineEdit


## How many seconds to wait before displaying the last seen time in seconds
const TIMEOUT_BUFFER: int = 3

## All columns in the tree
enum Columns {NAME, IP_ADDR, LAST_SEEN, CONNECTION_STATUS}


## RefMap for TreeItem: ConstellationNode
var _node_items: RefMap = RefMap.new()

## Signals to connect to the ConstellationNode
var _node_connections: Dictionary[String, Callable] = {
	"node_name_changed": _on_node_name_changed,
	"node_ip_changed": _on_node_ip_changed,
	"last_seen_changed": _on_node_last_seen_changed,
	"connection_state_changed": _on_node_connection_state_changed
}


## Ready
func _ready() -> void:
	_node_tree.columns = len(Columns)
	_node_tree.create_item()
	
	for column_name: String in Columns:
		_node_tree.set_column_title(Columns[column_name], column_name.capitalize())
	
	for node: ConstellationNode in Network.get_known_nodes():
		_add_node(node)
	
	_name_edit.set_text(Network.get_node_name())
	
	Network.node_found.connect(_add_node)
	Network.node_name_changed.connect(func (p_name: String):
		_name_edit.set_text(p_name)
	)


## Adds a node into the tree
func _add_node(p_node: ConstellationNode) -> bool:
	if _node_items.has_right(p_node):
		return false
	
	Utils.connect_signals_with_bind(_node_connections, p_node)
	var tree_item: TreeItem = _node_tree.create_item()
	
	tree_item.set_text(Columns.NAME, p_node.get_node_name())
	tree_item.set_text(Columns.IP_ADDR, p_node.get_node_ip())
	tree_item.set_text(Columns.LAST_SEEN, "Now")
	tree_item.set_text(Columns.CONNECTION_STATUS, p_node.get_connection_state_human())
	
	tree_item.set_editable(Columns.NAME, true)
	
	_node_items.map(tree_item, p_node)
	return true


## Called when a Node's name is changed
func _on_node_name_changed(p_name: String, p_node: ConstellationNode) -> void:
	_node_items.right(p_node).set_text(Columns.NAME, p_name)


## Called when a Node's IP address is changed
func _on_node_ip_changed(p_ip: String, p_node: ConstellationNode) -> void:
	_node_items.right(p_node).set_text(Columns.IP_ADDR, p_ip)


## Called when a Node's last seen time is updated
func _on_node_last_seen_changed(p_last_seen: float, p_node: ConstellationNode) -> void:
	_node_items.right(p_node).set_text(Columns.LAST_SEEN, "Now")


## Called when the Node's connection state is changed
func _on_node_connection_state_changed(p_connection_state: int, p_node: ConstellationNode) -> void:
	_node_items.right(p_node).set_text(Columns.CONNECTION_STATUS, p_node.get_connection_state_human())


## Called when the LastSeen timer times out
func _on_last_seen_timeout() -> void:
	for node: ConstellationNode in _node_items.get_right():
		var tree_item: TreeItem = _node_items.right(node)
		var last_seen_seconds: int = int(Time.get_unix_time_from_system() - node.get_last_seen_time())
		
		if last_seen_seconds > Network.DISCO_TIMEOUT + TIMEOUT_BUFFER:
			tree_item.set_text(Columns.LAST_SEEN, str(last_seen_seconds) + "s")


## Called when an item is edited in the tree
func _on_tree_item_edited() -> void:
	var tree_item: TreeItem = _node_tree.get_edited()
	var value: String = tree_item.get_text(_node_tree.get_edited_column())
	var node: ConstellationNode = _node_items.left(tree_item)
	
	match _node_tree.get_edited_column():
		Columns.NAME:
			node.set_node_name(value)


## Called when the text is changed in the name edit
func _on_name_text_submitted(new_text: String) -> void:
	Network.set_node_name(new_text)
