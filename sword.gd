
extends Node2D

@export_group("Attack")
@export_range(4, 8, 4) var attack_directions: int = 8
@export_range(1, 3, 1) var max_combo: int = 3
@export var attack_duration: float = 0.30
@export var hitbox_start: float = 0.06
@export var hitbox_duration: float = 0.10

@export_group("Combo")
@export var combo_window_start: float = 0.12
@export var combo_window_end: float = 0.27
@export var input_buffer_duration: float = 0.18

@export_group("Pogo")
@export var pogo_enabled: bool = true
@export var pogo_force: float = 450.0
@export_range(0.0, 1.0, 0.05)
var pogo_horizontal_momentum: float = 1.0

@export_group("References")
@export var hitbox: Area2D	

var player: CharacterBody2D

var is_attacking: bool = false
var current_combo: int = 0
var attack_timer: float = 0.0
var buffer_timer: float = 0.0
var attack_direction: Vector2 = Vector2.RIGHT
var last_direction: Vector2 = Vector2.RIGHT

var hitbox_active: bool = false
var hit_targets: Array[Node] = []


func _ready() -> void:
	player = get_parent() as CharacterBody2D
	$AnimatedSprite2D.animation_finished.connect(_on_animation_finished)

	if hitbox == null:
		hitbox = $Hitbox

	hitbox.monitoring = false
	hitbox.body_entered.connect(_on_hitbox_body_entered)
	hitbox.area_entered.connect(_on_hitbox_area_entered)

	if $AnimatedSprite2D:
		$AnimatedSprite2D.visible = false


func _physics_process(delta: float) -> void:
	update_input_buffer(delta)

	if Input.is_action_just_pressed("attack"):
		buffer_timer = input_buffer_duration

	if not is_attacking:
		if buffer_timer > 0.0:
			start_attack(1)
		return

	update_attack(delta)


func update_input_buffer(delta: float) -> void:
	buffer_timer = maxf(buffer_timer - delta, 0.0)


func update_attack(delta: float) -> void:
	attack_timer += delta

	var active := (
		attack_timer >= hitbox_start
		and attack_timer < hitbox_start + hitbox_duration
	)

	set_hitbox_active(active)
	check_hitbox_targets()
	
	if (
		buffer_timer > 0.0
		and current_combo < max_combo
		and attack_timer >= combo_window_start
		and attack_timer <= combo_window_end
	):
		buffer_timer = 0.0
		start_attack(current_combo + 1)
		return

	if attack_timer >= attack_duration:
		end_attack()


func start_attack(combo_index: int) -> void:
	current_combo = combo_index
	is_attacking = true
	attack_timer = 0.0
	hit_targets.clear()

	attack_direction = get_attack_direction()
	update_attack_orientation()
	
	if player.has_method("cancel_glide"):
		player.cancel_glide()
	if $AnimatedSprite2D:
		$AnimatedSprite2D.visible = true
		$AnimatedSprite2D.play("slash")


func end_attack() -> void:
	is_attacking = false
	set_hitbox_active(false)

	if $AnimatedSprite2D:
		$AnimatedSprite2D.stop()
		$AnimatedSprite2D.frame = 0
		$AnimatedSprite2D.visible = false

	if current_combo >= max_combo or buffer_timer <= 0.0:
		current_combo = 0


func get_attack_direction() -> Vector2:
	var input := Input.get_vector("left", "right", "up", "down")

	if input.length() > 0.2:
		last_direction = input.normalized()

	if attack_directions == 4:
		if absf(last_direction.x) > absf(last_direction.y):
			return Vector2(signf(last_direction.x), 0.0)
		return Vector2(0.0, signf(last_direction.y))

	var angle := last_direction.angle()
	var step := PI / 4.0
	var snapped_angle := roundf(angle / step) * step

	return Vector2.RIGHT.rotated(snapped_angle)


func update_attack_orientation() -> void:
	rotation = attack_direction.angle()


func set_hitbox_active(active: bool) -> void:
	if hitbox_active == active:
		return

	hitbox_active = active
	hitbox.set_deferred("monitoring", active)
	
func check_hitbox_targets() -> void:
	if not hitbox_active:
		return

	for body in hitbox.get_overlapping_bodies():
		register_hit(body)


func _on_hitbox_body_entered(body: Node2D) -> void:
	register_hit(body)


func _on_hitbox_area_entered(area: Area2D) -> void:
	register_hit(area)


func register_hit(target: Node) -> void:
	if target in hit_targets:
		return

	hit_targets.append(target)

	var is_pogoable := target.is_in_group("pogoable")

	if not is_pogoable:
		var parent := target.get_parent()
		if parent != null:
			is_pogoable = parent.is_in_group("pogoable")

	if (
		pogo_enabled
		and attack_direction.y > 0.5
		and is_pogoable
	):
		apply_pogo()

func apply_pogo() -> void:
	if player == null:
		return
		
	print("POGO !")

	player.velocity.y = -pogo_force
	player.velocity.x *= pogo_horizontal_momentum


func _on_animation_finished() -> void:
	if buffer_timer > 0.0 and current_combo < max_combo:
		buffer_timer = 0.0
		start_attack(current_combo + 1)
	else:
		end_attack()
