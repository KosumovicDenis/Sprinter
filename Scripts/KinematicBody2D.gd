extends KinematicBody2D

# Velocità di movimento nell'asse x
export var move_speed = 200.0

# Velocità in entrambi gli assi (inizialmente viene settata a ZERO(0,O))
var velocity := Vector2.ZERO

# Variabli necessarie per il salto
export var jump_height : float
export var jump_time_to_peak : float
export var jump_time_to_descent : float
# Velocià e gravità derivate dai valori sopra
onready var jump_velocity : float = ((2.0 * jump_height) / jump_time_to_peak) * -1.0
onready var jump_gravity : float = ((-2.0 * jump_height) / (jump_time_to_peak * jump_time_to_peak)) * -1.0
onready var fall_gravity : float = ((-2.0 * jump_height) / (jump_time_to_descent * jump_time_to_descent)) * -1.0

# Attrito mmuro, (per diminuire la velocità del personaggio nel caso sbatta su un muro) -> Da Sistemare
var wall_friction := 5.0

# Direzione per il RayCast WallDetector
var direction = 1 # 1 Perché inizialmente il player punterà a destra

# Stati del personaggio
enum States {AIR = 1, FLOOR, WALL}
var state = States.AIR

# Funzione richimata ogni frame
func _physics_process(delta):
	match state:
		States.AIR:
			if is_on_floor(): # Ritorna true se il player collide col pavimento (ultima chimata di move_And_slide())
				state = States.FLOOR # Cambio statp -> floor
				continue # passa subito al prossimo stato
			elif is_near_wall():
				if velocity.y >= 0.0:
					state = States.WALL # Cambio statp -> wall
					continue # passa subito al prossimo stato
				else:
					velocity.y += wall_friction * 1.2 # Rallenta va velocià nel salto -> TODO: rivalutare il valore
					print(velocity.y)
			$AnimatedSprite.play("air")  # Cambio animazione/sprite -> air
			move(delta, false) # Funzione che fa muovere e saltare il player
		States.FLOOR:
			if not is_on_floor():
				state = States.AIR # Cambio statp -> air
				continue # passa subito al prossimo stato
			$AnimatedSprite.play("floor")  # Cambio animazione/sprite -> floor
			move(delta, false) # Funzione che fa muovere e saltare il player
		States.WALL:
			if is_on_floor():
				state = States.FLOOR # Cambio statp -> floor
				continue # passa subito al prossimo stato
			elif not is_near_wall():
				state = States.AIR # Cambio statp -> air
				continue # passa subito al prossimo stato
			$AnimatedSprite.play("wall")  # Cambio animazione/sprite -> wall
			move(delta, true)

func move(delta: float, slow_falling: bool) -> void:
	# Assegnazione della velocità
	if slow_falling:
		# velocity.y += direction # Funziona con questo
		velocity.y = clamp(velocity.y, jump_height*0.2, 10)
		if Input.is_action_pressed("jump") and ((Input.is_action_pressed("left") and direction == 1) or (Input.is_action_pressed("right") and direction == -1)):
			velocity.x = 10 * -direction # da capire che valore mettere
			jump()
			state = States.AIR
		velocity = move_and_slide(velocity, Vector2.UP)
	else:
		velocity.y += get_gravity() * delta
		velocity.x = get_input_velocity() * move_speed
		# Controllo se ho azionato il salto, se si allora richiamo la funzione che farà partire il salto
		if Input.is_action_just_pressed("jump") and is_on_floor():
			jump()
		set_direction()
	velocity = move_and_slide(velocity, Vector2.UP)

# Se sale darà jump se scende fall (i valori sono opposti)
func get_gravity() -> float:
	return jump_gravity if velocity.y < 0.0 else fall_gravity

# Cambio la velocità nell'asse y
func jump():
	velocity.y = jump_velocity

# Cambio la velocità nell'asse x
func get_input_velocity() -> float:
	var horizontal := 0.0
	if Input.is_action_pressed("left"):
		$AnimatedSprite.flip_h = true
		horizontal -= 1.0
	if Input.is_action_pressed("right"):
		$AnimatedSprite.flip_h = false
		horizontal += 1.0
	return horizontal

# Ritorna true se il personaggi si trova nelle vicinanze di un muro
func is_near_wall() -> bool:
	return $WallChecker.is_colliding()

# Assegno la direzoine del pesonaggio per direzionare correttamente il RayCast
func set_direction():
	direction = 1 if not $AnimatedSprite.flip_h else -1
	$WallChecker.rotation_degrees = 90 * -direction # L'angolo di rotazione del RayCast 2D ha 90 a sinistra e -90 a destra(quindi l'opposto)
