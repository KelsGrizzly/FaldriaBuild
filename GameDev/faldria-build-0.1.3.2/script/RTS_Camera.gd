extends Node3D

#camera_move
@export_range(0,100,1) var camera_move_speed : float = 10

#camera_pan (0,x,x) = how you can control the how far the camera pans 32/4
@export_range(0,32,4) var camera_automatic_pan_margin:int = 16
@export_range(0,20,0.5) var camera_automatic_pan_speed:float = 15

#camera_rotate
var camera_rotation_direction:int = 0
@export_range(0,10,0.1) var camera_rotation_speed:float = 1
@export_range(0,20,1) var camera_base_rotation_speed:float = 50
@export_range(0,10,1) var camera_socket_rotation_x_min:float = -1.35
@export_range(0,10,1) var camera_socket_rotation_x_max:float = 0.65
#Need to add func that saves/hold mouse current pos and lets you rotate.
#When released, will restore/can resume mouse pos
#Add func that when middle mouse button click, transforms mouse into a rotate to let player know you can rotate. 
#Add a collision for camera so you can go under the ground

#camera_zoom
var camera_zoom_direction:float = 0
@export_range(0,100,1) var camera_zoom_speed = 37.0
@export_range(0,100,1) var camera_zoom_in = 1.0
@export_range(0,100,1) var camera_zoom_max = 45.0
@export_range(0,2,0.1) var camera_zoom_speed_damp:float = 0.89
#Nodes
@onready var camera_socket : Node3D = $camera_socket
@onready var camera : Camera3D = $camera_socket/Camera3D

#Flags
var camera_can_move_base:bool = true
var camera_can_process:bool = true
var camera_can_zoom:bool = true
#turned off pan for developing, true to turn back on
var camera_can_automatic_pan:bool = false
var camera_can_rotate_base:bool = true
var camera_can_rotate_socket_x:bool = true
var camera_can_rotate_by_mouse_offset:bool = true

#Internal Flag
var camera_is_rotating_base:bool = false
var camera_is_rotating_mouse:bool = false
var mouse_last_position:Vector2 = Vector2.ZERO



# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if !camera_can_process:return
	#calling camera move and zoom
	camera_base_move(delta)
	camera_zoom_update(delta)
	#calling camera pan func
	camera_automatic_pan(delta)
	#calling camera rotate func
	camera_base_rotate(delta)
	camera_rotate_to_mouse_offsets(delta)

func _unhandled_input(event: InputEvent) -> void:
	
	#Camera Zoom
	if event.is_action("camera_zoom_in"):
		camera_zoom_direction = -1
	elif event.is_action("camera_zoom_out"):
		camera_zoom_direction = 1
	#Camera rotations
	if event.is_action_pressed("camera_rotate_right"):
		camera_rotation_direction = -1
		camera_is_rotating_base = true
	elif event.is_action_pressed("camera_rotate_left"):
		camera_rotation_direction = 1
		camera_is_rotating_base = true
	elif event.is_action_released("camera_rotate_left") or event.is_action_released("camera_rotate_right"):
		camera_is_rotating_base = false
	#camera rotate
	if event.is_action_pressed("camera_rotate"):
		mouse_last_position = get_viewport().get_mouse_position()
		camera_is_rotating_mouse = true
		#print("middle mouse working")
	elif event.is_action_released("camera_rotate"):
		camera_is_rotating_mouse = false

#CameraBase movement w/ WASD keys
func camera_base_move(delta:float) -> void: 
	if !camera_can_move_base:return
	var velocity_direction:Vector3 = Vector3.ZERO
	
	if Input.is_action_pressed("camera_forward"): velocity_direction -= transform.basis.z
	if Input.is_action_pressed("camera_backward"): velocity_direction += transform.basis.z
	if Input.is_action_pressed("camera_right"): velocity_direction += transform.basis.x
	if Input.is_action_pressed("camera_left"): velocity_direction -= transform.basis.x

	position += velocity_direction.normalized() * delta * camera_move_speed

#controls zoom of camera
func camera_zoom_update(delta:float) -> void:
	if !camera_can_zoom:return
	#sets min/max camera zoom
	var new_zoom:float = clamp(camera.position.z + camera_zoom_speed * camera_zoom_direction * delta, camera_zoom_in, camera_zoom_max)
	camera.position.z = new_zoom
	camera_zoom_direction *= camera_zoom_speed_damp
#Rotates the CameraSocket based mouse offsets(left&right)
func camera_rotate_to_mouse_offsets(delta:float) -> void:
	if !camera_rotate_to_mouse_offsets or !camera_is_rotating_mouse:return
	var mouse_offset:Vector2 = get_viewport().get_mouse_position()
	mouse_offset = mouse_offset - mouse_last_position
	mouse_last_position = get_viewport().get_mouse_position()
	
	camera_base_rotate_left_right(delta,mouse_offset.x * 0.5)
	camera_socket_rotate_x(delta,mouse_offset.y * 0.5)
	
	
	
	#rotates the camera base
func camera_base_rotate(delta:float) -> void:
	if !camera_can_rotate_base or !camera_is_rotating_base:return
	
	#To rotate
	camera_base_rotate_left_right(delta,camera_rotation_direction * camera_rotation_speed)
	
#Rotates the CameraSocket
func camera_socket_rotate_x(delta:float, dir:float) -> void:
	if !camera_can_rotate_socket_x:return
	
	var new_rotation_x:float = camera_socket.rotation.x
	new_rotation_x -= dir * delta * camera_rotation_speed
	
	#new_rotation_x -= dir * camera_rotation_speed
	
	#camera max rotation: currently no limit
	new_rotation_x = clamp(new_rotation_x,camera_socket_rotation_x_min,camera_socket_rotation_x_max)
	#new_rotation_x = new_rotation_x 
	camera_socket.rotation.x = new_rotation_x
#roates camera left or right
func camera_base_rotate_left_right(delta:float, dir:float) -> void:
	rotation.y += dir * camera_rotation_speed * delta
	
	
#This is how you define a function; still need to code to call
#pans the camera automatically based on screen margins
func camera_automatic_pan(delta:float) -> void:
	if !camera_can_automatic_pan:return
	
	var viewport_current:Viewport = get_viewport()
	var pan_direction:Vector2 = Vector2(-1,-1) #starts negative
	var viewport_visible_rectangle:Rect2i = Rect2i( viewport_current.get_visible_rect() )
	var viewport_size:Vector2i = viewport_visible_rectangle.size
	var current_mouse_position:Vector2 = viewport_current.get_mouse_position()
	var margin:float = camera_automatic_pan_margin #shortcut var
	
	var zoom_factor:float = camera.position.z * 0.1
	# X Pan. Detects if mouse is in upper screen
	if ( (current_mouse_position.x < margin) or (current_mouse_position.x > viewport_size.x - margin) ):
		@warning_ignore("integer_division")
		if current_mouse_position.x > viewport_size.x/2:
			pan_direction.x = 1
		translate(Vector3(pan_direction.x * delta * camera_automatic_pan_speed,0,0))
			
		# Y Pan. 
	if ( (current_mouse_position.y < margin) or (current_mouse_position.y > viewport_size.y - margin) ):
		@warning_ignore("integer_division")
		if current_mouse_position.y > viewport_size.y/2:
			pan_direction.y = 1
		translate(Vector3(0,0,pan_direction.y * delta * camera_automatic_pan_speed * zoom_factor) )

# Unprooject Vector3 to Vector2
func get_Vector2_from_Vector3(unproject_from_vec3:Vector3) -> Vector2:
	return camera.unproject_position(unproject_from_vec3)
