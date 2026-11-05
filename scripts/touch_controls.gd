class_name LineaTouchControls
extends Control
signal camera_dragged(delta: Vector2)
var active := false
var movement := Vector2.ZERO
var joystick_finger := -1
var camera_finger := -1
var origin := Vector2.ZERO
var knob := Vector2.ZERO
var radius := 66.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func reset() -> void:
	movement = Vector2.ZERO
	joystick_finger = -1
	camera_finger = -1
	queue_redraw()

func _input(event: InputEvent) -> void:
	if not active:
		return
	var viewport_size := get_viewport_rect().size
	if event is InputEventScreenTouch:
		if event.pressed and event.position.x < viewport_size.x * 0.42 and event.position.y > viewport_size.y * 0.46 and joystick_finger == -1:
			joystick_finger = event.index
			origin = event.position
			knob = origin
			get_viewport().set_input_as_handled()
		elif not event.pressed and event.index == joystick_finger:
			joystick_finger = -1
			movement = Vector2.ZERO
			get_viewport().set_input_as_handled()
		if not event.pressed and event.index == camera_finger:
			camera_finger = -1
	elif event is InputEventScreenDrag:
		if event.index == joystick_finger:
			var offset: Vector2 = (event.position - origin).limit_length(radius * float(State.settings.touch_scale))
			knob = origin + offset
			movement = offset / (radius * float(State.settings.touch_scale))
			if movement.length() < 0.12:
				movement = Vector2.ZERO
			get_viewport().set_input_as_handled()
		elif event.index == camera_finger:
			camera_dragged.emit(event.relative)
			get_viewport().set_input_as_handled()
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventScreenTouch and event.pressed and camera_finger == -1:
		var screen := get_viewport_rect().size
		if event.position.x > screen.x * 0.43 and event.position.y < screen.y * 0.72 and event.position.y > screen.y * 0.16:
			camera_finger = event.index
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		camera_dragged.emit(event.relative)

func _draw() -> void:
	if not active:
		return
	var scale_value := float(State.settings.touch_scale)
	var center := origin if joystick_finger >= 0 else Vector2(128 * scale_value, size.y - 124 * scale_value)
	var r := radius * scale_value
	draw_circle(center,r,Color(0.07,0.12,0.13,0.38))
	draw_arc(center,r,0,TAU,48,Color(0.75,0.80,0.70,0.35),2.0,true)
	draw_arc(center,r*0.52,0,TAU,32,Color(0.75,0.80,0.70,0.12),1.0,true)
	draw_line(center-Vector2(9,0),center+Vector2(9,0),Color(0.75,0.80,0.70,0.28),1.0)
	draw_line(center-Vector2(0,9),center+Vector2(0,9),Color(0.75,0.80,0.70,0.28),1.0)
	draw_circle(knob if joystick_finger >= 0 else center,24*scale_value,Color(0.68,0.75,0.66,0.40))
