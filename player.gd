
extends CharacterBody2D

@export_group("Dash")

@export var dash_unlocked: bool = false
@export var dash_speed: float = 800.0
@export var dash_duration: float = 0.2
@export var dash_cooldown: float = 0.35

@export var dash_air_allowed: bool = true
@export var dash_direction_lock: bool = true
@export var dash_ends_on_collision: bool = true
@export var dash_diagonal_normalized: bool = true

@export var dash_block_directions: bool = false
@export var dash_block_up: bool = false
@export var dash_block_down_left: bool = false
@export var dash_block_down_right: bool = false

var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var dash_direction: Vector2 = Vector2.RIGHT
var last_facing_direction: float = 1.0

var dash_elapsed: float = 0.0
var dash_start_position: Vector2 = Vector2.ZERO
var dash_curve_active: bool = false

@export_subgroup("Dash Curve")

## Active la trajectoire courbée pour les dashs horizontaux au sol.
@export var dash_curve_enabled: bool = false

## Vitesse verticale initiale du dash : négative = vers le haut.
@export var dash_curve_initial_velocity: float = -180.0

## Hauteur maximale de la trajectoire en pixels.
@export var dash_curve_height: float = 100.0

## Contrôle la forme de la trajectoire.
@export_range(1.0, 5.0, 0.1)
var dash_curve_shape: float = 2.5


# ============================================================
# 1. DEPLACEMENT HORIZONTAL
# ============================================================

@export_group("Horizontal Movement")

@export var max_speed: float = 300.0
@export var ground_acceleration: float = 1800.0
@export var air_acceleration: float = 900.0
@export var ground_friction: float = 2200.0
@export var air_friction: float = 250.0

## 1.0 = contrôle normal en l'air ; 0.0 = aucun contrôle.
@export_range(0.0, 1.0, 0.05)
var air_control: float = 1.0

@export var turn_acceleration: float = 2400.0
@export var stop_threshold: float = 2.0


# ============================================================
# 2. SAUT
# ============================================================

@export_group("Jump")

@export var jump_height: float = 120.0

@export_range(0.05, 2.0, 0.05)
var jump_apex_time: float = 0.35

@export_range(0.05, 3.0, 0.05)
var jump_descent_time: float = 0.30

@export var variable_jump: bool = true

@export_range(0.1, 1.0, 0.05)
var jump_hold_gravity_multiplier: float = 0.5

@export var jump_hold_max_time: float = 0.20

@export_range(0.0, 1.0, 0.05)
var jump_cut_multiplier: float = 0.5

@export_range(1, 5, 1)
var max_jumps: int = 1

@export var coyote_time: float = 0.12
@export var jump_buffer_time: float = 0.12


@export_subgroup("Double Jump")

@export var double_jump_unlocked: bool = false
@export var double_jump_height: float = 100.0

@export_range(0.05, 2.0, 0.05)
var double_jump_apex_time: float = 0.30

@export var double_jump_hold_max_time: float = 0.20


# ============================================================
# 2B. PLANÉ
# ============================================================

@export_group("Glide")

@export var glide_unlocked: bool = false
@export var glide_gravity: float = 120.0
@export var glide_max_fall_speed: float = 80.0
@export var glide_activation_time: float = 0.15
@export var glide_deactivation_time: float = 0.15

## Temps d'attente avant de pouvoir réactiver le plané.
@export var glide_cooldown: float = 0.15

var glide_cooldown_timer: float = 0.0

## Vrai si le cooldown vient de se terminer.
var glide_was_on_cooldown: bool = false


# ============================================================
# 3. GRAVITÉ ET CHUTE
# ============================================================

@export_group("Gravity")

@export var base_gravity: float = 980.0

@export_range(0.1, 3.0, 0.05)
var rising_gravity_multiplier: float = 1.0

@export_range(0.1, 3.0, 0.05)
var falling_gravity_multiplier: float = 1.0

@export var use_apex_gravity: bool = true

@export_range(0.1, 1.0, 0.05)
var apex_gravity_multiplier: float = 0.5

@export var apex_velocity_threshold: float = 50.0
@export var max_fall_speed: float = 900.0
@export var use_custom_jump_gravity: bool = true


# ============================================================
# 4. OPTIONS PHYSIQUES
# ============================================================

@export_group("Physics")

@export var falling_velocity_threshold: float = 5.0
@export var allow_air_movement: bool = true
@export var preserve_horizontal_momentum: bool = true


# ============================================================
# 5. DÉPLACEMENT MURAL
# ============================================================

@export_group("Wall Movement")

@export var wall_abilities_unlocked: bool = false

@export_subgroup("Wall Cling")

@export var wall_stick_duration: float = 1.0
@export var wall_stick_duration_unlocked: float = 3.0
@export var wall_slide_gravity_multiplier: float = 0.25
@export var wall_max_slide_speed: float = 100.0

@export_subgroup("Wall Jump")

@export var wall_jump_horizontal_force: float = 350.0
@export var wall_jump_vertical_force: float = 250.0
@export var wall_jump_horizontal_force_unlocked: float = 250.0
@export var wall_jump_vertical_force_unlocked: float = 450.0

@export_subgroup("Wall Ability Resets")

@export var wall_touch_resets_dash: bool = false
@export var wall_touch_resets_double_jump: bool = false


# ============================================================
# 6. ÉTAT INTERNE
# ============================================================

var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var jump_hold_timer: float = 0.0
var jumps_remaining: int = 1

var was_on_floor: bool = false

var is_wall_attached: bool = false
var wall_stick_timer: float = 0.0
var wall_normal: Vector2 = Vector2.ZERO
var wall_was_touching: bool = false

var is_gliding: bool = false
var glide_transition: float = 0.0
var glide_direction: float = 1.0


# ============================================================
# 7. INITIALISATION
# ============================================================

func _ready() -> void:
	jumps_remaining = max_jumps
	was_on_floor = is_on_floor()


# ============================================================
# 8. BOUCLE PHYSIQUE
# ============================================================

func _physics_process(delta: float) -> void:
	update_timers(delta)
	update_jump_buffer()

	# Détecte la fin du cooldown du plané.
	var glide_cooldown_was_active: bool = glide_cooldown_timer > 0.0
	glide_cooldown_timer = maxf(glide_cooldown_timer - delta, 0.0)

	if glide_cooldown_was_active and glide_cooldown_timer <= 0.0:
		glide_was_on_cooldown = true

	dash_cooldown_timer = maxf(dash_cooldown_timer - delta, 0.0)

	# Le dash reste prioritaire et peut interrompre le plané.
	if is_dashing:
		update_dash(delta)
		return

	if Input.is_action_just_pressed("dash"):
		if try_start_dash():
			update_dash(delta)
			return

	# Plané déjà actif.
	if is_gliding:
		if not Input.is_action_pressed("jump"):
			cancel_glide()
		else:
			update_glide(delta)
			update_horizontal_movement(delta)
			move_and_slide()
			update_floor_state()
			return

	# Activation par nouvel appui ou si la touche est maintenue
	# au moment où le cooldown se termine.
	var glide_requested: bool = (
		Input.is_action_just_pressed("jump")
		or (
			glide_was_on_cooldown
			and Input.is_action_pressed("jump")
		)
	)

	if glide_requested \
			and glide_unlocked \
			and not double_jump_unlocked \
			and glide_cooldown_timer <= 0.0 \
			and not is_on_floor():
		start_glide()
		update_glide(delta)
		update_horizontal_movement(delta)
		move_and_slide()
		update_floor_state()
		return

	if update_wall_movement(delta):
		move_and_slide()
		update_floor_state()
		return

	update_horizontal_movement(delta)
	update_gravity(delta)
	update_jump()
	move_and_slide()
	update_floor_state()


# ============================================================
# 9. MINUTERIES
# ============================================================

func update_timers(delta: float) -> void:
	if is_on_floor():
		coyote_timer = coyote_time
		jumps_remaining = max_jumps
	else:
		coyote_timer = maxf(coyote_timer - delta, 0.0)

	jump_buffer_timer = maxf(jump_buffer_timer - delta, 0.0)


func update_jump_buffer() -> void:
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = jump_buffer_time


# ============================================================
# 10. DÉPLACEMENT HORIZONTAL
# ============================================================

func update_horizontal_movement(delta: float) -> void:
	var direction: float = Input.get_axis("left", "right")

	if direction != 0.0:
		last_facing_direction = signf(direction)

	var on_ground: bool = is_on_floor()
	var can_control_air: bool = allow_air_movement

	if not on_ground and not can_control_air:
		return

	var target_speed: float = direction * max_speed

	if on_ground:
		if direction == 0.0:
			velocity.x = move_toward(
				velocity.x,
				0.0,
				ground_friction * delta
			)
		else:
			var acceleration: float = ground_acceleration

			if signf(velocity.x) != signf(direction) \
					and absf(velocity.x) > stop_threshold:
				acceleration = turn_acceleration

			velocity.x = move_toward(
				velocity.x,
				target_speed,
				acceleration * delta
			)
	else:
		if direction == 0.0:
			velocity.x = move_toward(
				velocity.x,
				0.0,
				air_friction * air_control * delta
			)
		else:
			var air_accel: float = air_acceleration * air_control

			if signf(velocity.x) != signf(direction) \
					and absf(velocity.x) > stop_threshold:
				air_accel = turn_acceleration * air_control

			velocity.x = move_toward(
				velocity.x,
				target_speed,
				air_accel * delta
			)


# ============================================================
# 11. GRAVITÉ
# ============================================================

func update_gravity(delta: float) -> void:
	if is_on_floor() and velocity.y >= 0.0:
		velocity.y = 0.0
		return

	var gravity: float = base_gravity

	if use_custom_jump_gravity:
		var calculated_rising_gravity: float = (
			2.0 * jump_height / pow(jump_apex_time, 2.0)
		)

		var calculated_falling_gravity: float = (
			2.0 * jump_height / pow(jump_descent_time, 2.0)
		)

		if velocity.y < 0.0:
			gravity = calculated_rising_gravity \
				* rising_gravity_multiplier
		else:
			gravity = calculated_falling_gravity \
				* falling_gravity_multiplier
	else:
		gravity = base_gravity

	# Saut plus flottant lorsque le bouton reste maintenu.
	if variable_jump \
			and Input.is_action_pressed("jump") \
			and velocity.y < 0.0 \
			and jump_hold_timer > 0.0:
		gravity *= jump_hold_gravity_multiplier

	# Gravité réduite au sommet de la trajectoire.
	elif use_apex_gravity \
			and absf(velocity.y) < apex_velocity_threshold:
		gravity *= apex_gravity_multiplier

	velocity.y += gravity * delta
	velocity.y = minf(velocity.y, max_fall_speed)


# ============================================================
# 12. SAUT ET DOUBLE SAUT
# ============================================================

func update_jump() -> void:
	if jump_buffer_timer <= 0.0 or is_gliding:
		return

	if is_on_floor() or coyote_timer > 0.0:
		perform_jump()
		return

	if jumps_remaining > 0:
		# Le double saut est désactivé si le plané est débloqué.
		if not double_jump_unlocked or glide_unlocked:
			return

		perform_jump()


func perform_jump() -> void:
	var is_double_jump: bool = (
		not is_on_floor()
		and coyote_timer <= 0.0
	)

	var height: float = jump_height
	var apex_time: float = jump_apex_time

	if is_double_jump:
		if not double_jump_unlocked or glide_unlocked or is_gliding:
			return

		height = double_jump_height
		apex_time = double_jump_apex_time

	var jump_velocity: float = -2.0 * height / apex_time
	velocity.y = jump_velocity

	jumps_remaining -= 1
	coyote_timer = 0.0
	jump_buffer_timer = 0.0

	if is_double_jump:
		jump_hold_timer = double_jump_hold_max_time
	else:
		jump_hold_timer = jump_hold_max_time


# ============================================================
# 13. DÉTECTION DU RELÂCHEMENT DU SAUT
# ============================================================

func _input(event: InputEvent) -> void:
	if event.is_action_released("jump"):
		jump_hold_timer = 0.0

		if velocity.y < 0.0:
			velocity.y *= jump_cut_multiplier


# ============================================================
# 14. ÉTAT DU SOL
# ============================================================

func update_floor_state() -> void:
	var on_floor_now: bool = is_on_floor()

	if on_floor_now:
		jumps_remaining = max_jumps
		coyote_timer = coyote_time
		cancel_glide()

	was_on_floor = on_floor_now


# ============================================================
# 15. DASH
# ============================================================

func try_start_dash() -> bool:
	if not dash_unlocked:
		return false

	if dash_cooldown_timer > 0.0:
		return false

	if not dash_air_allowed and not is_on_floor():
		return false

	cancel_glide()

	var input_direction := Input.get_vector(
		"left", "right", "up", "down"
	)

	if input_direction == Vector2.ZERO:
		input_direction = Vector2(last_facing_direction, 0.0)

	if dash_diagonal_normalized:
		input_direction = input_direction.normalized()

	if dash_block_directions:
		if dash_block_up and input_direction.is_equal_approx(Vector2.UP):
			return false

		if dash_block_down_left and input_direction.is_equal_approx(
			Vector2(-1.0, 1.0).normalized()
		):
			return false

		if dash_block_down_right and input_direction.is_equal_approx(
			Vector2(1.0, 1.0).normalized()
		):
			return false

	dash_direction = input_direction
	dash_start_position = global_position
	dash_elapsed = 0.0
	dash_timer = dash_duration

	dash_curve_active = (
		dash_curve_enabled
		and absf(dash_direction.y) < 0.01
	)

	is_dashing = true
	dash_cooldown_timer = dash_cooldown

	return true


func update_dash(delta: float) -> void:
	dash_elapsed += delta
	dash_timer = maxf(dash_duration - dash_elapsed, 0.0)

	var progress: float = clampf(
		dash_elapsed / dash_duration,
		0.0,
		1.0
	)

	var target_position: Vector2 = (
		dash_start_position
		+ dash_direction * dash_speed * dash_duration * progress
	)

	if dash_curve_active:
		var curve_progress: float = (
			1.0 - pow(1.0 - progress, dash_curve_shape)
		)

		var curve_offset: float = (
			-dash_curve_height
			* 4.0
			* progress
			* pow(1.0 - progress, 2.0)
		)

		target_position.y += curve_offset

	var movement: Vector2 = target_position - global_position
	velocity = movement / delta

	move_and_slide()

	if dash_ends_on_collision and is_on_wall():
		end_dash()
		return

	if dash_timer <= 0.0:
		end_dash()

func end_dash() -> void:
	is_dashing = false
	dash_curve_active = false
	# Conserver une partie de l'élan final.
	velocity *= 0.40


# ============================================================
# 16. DÉPLACEMENT MURAL
# ============================================================

func update_wall_movement(delta: float) -> bool:
	var touching_wall: bool = (
		is_on_wall()
		and not is_on_floor()
		and velocity.y >= 0.0
	)

	if not touching_wall:
		is_wall_attached = false
		wall_stick_timer = 0.0
		wall_was_touching = false
		return false

	wall_normal = get_wall_normal()

	if not wall_was_touching:
		wall_stick_timer = (
			wall_stick_duration_unlocked
			if wall_abilities_unlocked
			else wall_stick_duration
		)

		if wall_touch_resets_dash:
			dash_cooldown_timer = 0.0

		if wall_touch_resets_double_jump:
			jumps_remaining = maxi(jumps_remaining, 1)

		is_wall_attached = true

	wall_was_touching = true

	var horizontal_input: float = Input.get_axis("left", "right")

	# Appuyer à l'opposé du mur permet de se décrocher.
	if horizontal_input * wall_normal.x > 0.0:
		is_wall_attached = false
		wall_stick_timer = 0.0
		velocity.x = wall_normal.x * 80.0
		return false

	# Wall jump.
	if jump_buffer_timer > 0.0:
		perform_wall_jump()
		return false

	# Accroche temporaire.
	if wall_stick_timer > 0.0:
		wall_stick_timer = maxf(wall_stick_timer - delta, 0.0)

		if wall_stick_timer > 0.0:
			velocity.x = 0.0
			velocity.y = 0.0
			return true

	# Glissade murale après expiration du temps d'accroche.
	is_wall_attached = false

	var gravity: float = base_gravity

	if use_custom_jump_gravity:
		gravity = (
			2.0 * jump_height / pow(jump_descent_time, 2.0)
		)

	velocity.y += gravity * wall_slide_gravity_multiplier * delta
	velocity.y = minf(velocity.y, wall_max_slide_speed)

	return true


func perform_wall_jump() -> void:
	cancel_glide()

	var horizontal_force: float = wall_jump_horizontal_force
	var vertical_force: float = wall_jump_vertical_force

	if wall_abilities_unlocked:
		horizontal_force = wall_jump_horizontal_force_unlocked
		vertical_force = wall_jump_vertical_force_unlocked

	velocity.x = wall_normal.x * horizontal_force
	velocity.y = -vertical_force

	is_wall_attached = false
	wall_stick_timer = 0.0
	wall_was_touching = false
	jump_buffer_timer = 0.0
	jump_hold_timer = (
		double_jump_hold_max_time
		if wall_abilities_unlocked
		else 0.0
	)
	coyote_timer = 0.0


# ============================================================
# 17. PLANÉ
# ============================================================

func start_glide() -> void:
	if not glide_unlocked or double_jump_unlocked:
		return

	is_gliding = true
	glide_transition = 0.0
	glide_direction = last_facing_direction
	glide_was_on_cooldown = false
	jump_hold_timer = 0.0

	# Empêche le personnage de continuer à monter pendant le plané.
	velocity.y = maxf(velocity.y, 0.0)


func cancel_glide() -> void:
	if not is_gliding:
		return

	is_gliding = false
	glide_transition = 0.0
	glide_cooldown_timer = glide_cooldown
	glide_was_on_cooldown = false


func update_glide(delta: float) -> void:
	if not Input.is_action_pressed("jump"):
		cancel_glide()
		return

	glide_transition = minf(
		glide_transition + delta,
		glide_activation_time
	)

	var activation_ratio: float = 1.0

	if glide_activation_time > 0.0:
		activation_ratio = clampf(
			glide_transition / glide_activation_time,
			0.0,
			1.0
		)

	var target_gravity: float = lerpf(
		base_gravity,
		glide_gravity,
		activation_ratio
	)

	velocity.y += target_gravity * delta
	velocity.y = minf(velocity.y, glide_max_fall_speed)
