## Interactive drop zone system with sensor partitioning and visual debugging.
##
## Provides hit detection with configurable sensor areas and vertical/horizontal
## partitioning for precise card placement and reordering.
class_name DropZone
extends Control

var sensor_size: Vector2:
	set(value):
		sensor.size = value
		sensor_outline.size = value

var sensor_position: Vector2:
	set(value):
		sensor.position = value
		sensor_outline.position = value

## @deprecated Use sensor_outline_visible instead.
var sensor_texture: Texture:
	set(value):
		sensor.texture = value

## @deprecated Use sensor_outline_visible instead.
var sensor_visible := true:
	set(value):
		sensor.visible = value

var sensor_outline_visible := false:
	set(value):
		sensor_outline.visible = value
		for outline: ReferenceRect in sensor_partition_outlines:
			outline.visible = value

var accept_types: Array[String] = []
var stored_sensor_size: Vector2
var stored_sensor_position: Vector2
var parent: Node

var sensor: Control
var sensor_outline: ReferenceRect
var sensor_partition_outlines: Array[ReferenceRect] = []

var vertical_partition: Array[float] = []
var horizontal_partition: Array[float] = []


func init(_parent: Node, p_accept_types: Array[String] = []) -> void:
	parent = _parent
	accept_types = p_accept_types

	if sensor == null:
		sensor = TextureRect.new()
		sensor.name = "Sensor"
		sensor.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sensor.z_index = CardFrameworkSettings.VISUAL_SENSOR_Z_INDEX
		add_child(sensor)

	if sensor_outline == null:
		sensor_outline = ReferenceRect.new()
		sensor_outline.editor_only = false
		sensor_outline.name = "SensorOutline"
		sensor_outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sensor_outline.border_color = CardFrameworkSettings.DEBUG_OUTLINE_COLOR
		sensor_outline.z_index = CardFrameworkSettings.VISUAL_OUTLINE_Z_INDEX
		add_child(sensor_outline)

	stored_sensor_size = Vector2.ZERO
	stored_sensor_position = Vector2.ZERO
	vertical_partition = []
	horizontal_partition = []


func check_mouse_is_in_drop_zone() -> bool:
	return sensor.get_global_rect().has_point(get_global_mouse_position())


func set_sensor(_size: Vector2, _position: Vector2, _texture: Texture, _visible: bool) -> void:
	sensor_size = _size
	sensor_position = _position
	stored_sensor_size = _size
	stored_sensor_position = _position
	sensor_texture = _texture
	sensor_visible = _visible


func set_sensor_size_flexibly(_size: Vector2, _position: Vector2) -> void:
	sensor_size = _size
	sensor_position = _position


func return_sensor_size() -> void:
	sensor_size = stored_sensor_size
	sensor_position = stored_sensor_position


func change_sensor_position_with_offset(offset: Vector2) -> void:
	sensor_position = stored_sensor_position + offset


func set_vertical_partitions(positions: Array[float]) -> void:
	vertical_partition = positions

	for outline: ReferenceRect in sensor_partition_outlines:
		outline.queue_free()
	sensor_partition_outlines.clear()

	for i: int in range(vertical_partition.size()):
		var outline := ReferenceRect.new()
		outline.editor_only = false
		outline.name = "VerticalPartition" + str(i)
		outline.z_index = CardFrameworkSettings.VISUAL_OUTLINE_Z_INDEX
		outline.border_color = CardFrameworkSettings.DEBUG_OUTLINE_COLOR
		outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
		outline.size = Vector2(1, sensor.size.y)
		outline.position = Vector2(vertical_partition[i] - global_position.x, sensor.position.y)
		outline.visible = sensor_outline.visible
		add_child(outline)
		sensor_partition_outlines.append(outline)


func set_horizontal_partitions(positions: Array[float]) -> void:
	horizontal_partition = positions

	for outline: ReferenceRect in sensor_partition_outlines:
		outline.queue_free()
	sensor_partition_outlines.clear()

	for i: int in range(horizontal_partition.size()):
		var outline := ReferenceRect.new()
		outline.editor_only = false
		outline.name = "HorizontalPartition" + str(i)
		outline.z_index = CardFrameworkSettings.VISUAL_OUTLINE_Z_INDEX
		outline.border_color = CardFrameworkSettings.DEBUG_OUTLINE_COLOR
		outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
		outline.size = Vector2(sensor.size.x, 1)
		outline.position = Vector2(sensor.position.x, horizontal_partition[i] - global_position.y)
		outline.visible = sensor_outline.visible
		add_child(outline)
		sensor_partition_outlines.append(outline)


func get_vertical_layers() -> int:
	if not check_mouse_is_in_drop_zone():
		return -1
	if vertical_partition.is_empty():
		return -1

	var mouse_x: float = get_global_mouse_position().x
	var current_index: int = 0
	for i: int in range(vertical_partition.size()):
		if mouse_x >= vertical_partition[i]:
			current_index += 1
		else:
			break
	return current_index


func get_horizontal_layers() -> int:
	if not check_mouse_is_in_drop_zone():
		return -1
	if horizontal_partition.is_empty():
		return -1

	var mouse_y: float = get_global_mouse_position().y
	var current_index: int = 0
	for i: int in range(horizontal_partition.size()):
		if mouse_y >= horizontal_partition[i]:
			current_index += 1
		else:
			break
	return current_index
