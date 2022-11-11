# KinematicBody2D è l'elemento della scena al quale è stato collegato questo script
# Come dice il nome dell'elemento è il migliore per la realizazzione dei corpi che si devono muovere (diversamente dallo StaticBody2D, che potrebbe essere usato ad esempio per la realizazzione di ostacoli)
extends KinematicBody2D

# Velocità di movimento nell'asse x
export var move_speed = 200.0
# Velocità massima di slide 
export var max_wall_slide_speed = 280
# Variabili per il dash
export var dash_speed = 800.0
const dash_length = 0.2 # Durata dash
onready var dash_timer = $Dash # Scena che gestisce la durata del dash
var can_dash = false
# Dash Effect
# La scena con l'effetto va inserita nelle proprità del KinematicBody2D
export(PackedScene) var dash_effect

var horizontal := 0.0 # Direzione personaggio

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

# La funzione _physics_process viene eseguita ogni processo fisico(frame per secondo)
# Typically, this will be approximately 1/60 or 0.0167 seconds
func _physics_process(delta):
	# Macth è l'equivalente dello switch case
	match state:
		# Stato AIR 
		# Il player è in aria
		# Per passare a questo stato il player non deve collidere nè con il pavimento nè con il muro,
		# per il muro deve avere anche una velocità nell'asse y >= 0, ovvero deve essere in discesa
		States.AIR:
			# Se sono a contatto col pavimento
			if is_on_floor(): # Ritorna true se il player collide col pavimento (ultima chimata di move_And_slide())
				state = States.FLOOR # Cambio stato -> FLOOR
				continue # passa subito al prossimo stato
			# Se mi trovo vicino a un muro faccio due cose:
			# 1) Diminuisco la velocità fino a quando il personaggio non smette di salire (precedente salto)
			# 2) Passo allo stato WALL
			elif is_near_wall():
				if velocity.y >= 0.0:
					# Rallenta di botto la velocity.y in discesa prima di passare allo stato WALL
					# !Attenzione se si mette un valore calcolato su velocity.y, quando il personaggio dasha la velocity.y vale 0, quindi poi nella funzione clamp() avviene una divisione per zero
					# Soluzioni al problema sopra anunciato:
					# 1) Nella funzione clamp divido per velocity.y + 1 (non ci sono problemi con il -1 pk finiamo nel blocco clamp solo se velocity.y >= 0)
					# 2) L'if a riga 47 si imposta > e non >=
					velocity.y = 1 # Brutta, quasi barbarico, ma funziona
					state = States.WALL # Cambio stato -> wall
					continue # passa subito al prossimo stato
				else:
					# Diminuisco la velocità in salita applicando l'attrito col muro
					# Alternative per svolgere questa operazione:
					# 1) Usare la funzione clamp() e eseguire l'opposto di quello che viene fatto per lo slide sul muro
					velocity.y += wall_friction * 3.5
			# Dash
			# Per poter dashare, ci dobbiamo trovare nello stato air e prima dovavamo trovarci nello stato floor e non wall
			# ? -> se volessimo dashare in tutte le circostanze questo blocco si può rendere una funzione e richiamarlo in tutti i stati 
			# Il controllo verifica:
			# 1) Il player clicca da direzione giusta con le frecce direzionali
			#    con direzione giusta intendo che il personaggio si sta dirigendo verso dove clicco di andare
			# 2) Se posso dashare, per poter dashare devo passare dallo stato FLOOR A AIR, e non WALL e poi AIR,
			#    questa condizione e rappresentata dalla variabile can_dash
			# Modifiche da fare per il mobile:
			# 1) Nel controllo rimuore le direzioni (non neccessarie) e controllo se clicco il pulsante dash
			# 2) Aggiungere un timer per poter dashare solo ogni 30s
			if ((Input.is_action_just_pressed("left") and direction == -1) or (Input.is_action_just_pressed("right") and direction == 1)) and can_dash:
				can_dash = false
				# dash_timer è la scena che gestisce la durata del dash
				# dash_timer.start(dash_length) faccio partire il timer che indica per quanto tempo sto dashando, rappresentato da dash_length
				dash_timer.start(dash_length)
				# dash_effect è la scena che contiene le particelle dell'effetto di dash
				# single_dash_effect è il figlio che verra aggiunto a player
				var single_dash_effect = dash_effect.instance()
				# emitting = true permette di rendere visibile le particelle
				# di default è settata a one_shot = true, ovvero viene mostrata una sola volta dopo la sua creazione
				single_dash_effect.get_node("dash_effect").emitting = true
				# La direzione di propagazione delle particelle la imposto opposta a quella del player
				single_dash_effect.get_node("dash_effect").process_material.direction.x = -direction
				# Posizione delle particelle viene impostata ugale a quella del player ma un'pò più in dietro(40 px nella direzione opposta)
				single_dash_effect.get_node("dash_effect").position = Vector2(position.x + (40 * -direction), position.y)
				# Aggiungo il figlio alla scena
				get_parent().add_child(single_dash_effect)
			
			# Se il player è in fase di dashing faccio:
			# 1) Cambio animazione, riproduco l'animazione dash
			# 2) Uso una move_speed diversa, ovvero uso la dash_speed
			# 3) La velocità di salita o discesa viene annulata momentaneamente
			if dash_timer.is_dashing():
				$AnimatedSprite.play("dash")
				velocity.y = 0
				velocity.x = horizontal * dash_speed
			# Se il player non sta dashando faccio:
			# 1) Reimposto l'animazione riprodotta con quella air
			# 2) Riporto la gravità
			# 3) Uso la move_speed di base
			else:
				$AnimatedSprite.play("air")
				velocity.y += get_gravity() * delta
				velocity.x = horizontal * move_speed
			# Faccio muovere il player
			velocity = move_and_slide(velocity, Vector2.UP)
		# Stato FLOOR
		# Il player è a contatto col pavimento
		# Per passare a questo stato la funzione is_on_floor() deve valere true
		States.FLOOR:
			# Se non sono a contatto col pavimento faccio:
			if not is_on_floor(): # is_on_floor() ritorna true solo se il player collide col pavimento  
				state = States.AIR # Cambio stato -> air
				continue # passa subito al prossimo stato
			# Essendo all'interno dello stato FLOOR vuole dire che posso tornare a dashare
			# ps: solo se poi passo direttamente allo stato AIR, pk lo stato WALL rimuove la possibilità di dashare
			can_dash = true
			# Cambio animazione(sprite), e passo a floor
			$AnimatedSprite.play("floor") # Animazione da gestire all'interno del editor integrato di godot
			velocity.y += get_gravity() * delta
			# Muovimento del personaggio
			# Imposto la velocity nella asse x(velocity.x) = alla direzione(get_horizontal_velocity()) * la velocità di movimento(move_speed)
			# Possibili miglioramenti:
			# 1) Implementazione accelerazione
			# 2) Implementazione decelerazione
			velocity.x = get_horizontal_velocity() * move_speed
			# Controllo se ho cliccato il pulsante per saltare
			if (Input.is_action_just_pressed("right") or Input.is_action_just_pressed("left")) and is_on_floor():
				# Funzione che gestisce il salto
				jump()
			# Basandosi sullo sprite, controllando se è flippato orizontalmente o no, setta la direzione
			set_direction()
			# Faccio muovere il player
			velocity = move_and_slide(velocity, Vector2.UP)
		# Stato WALL
		# Il player è attaccato al muro
		# Per passare a questo stato:
		# 1) is_near_wall() = true
		# 2) la velocity.y >= 0.0
		States.WALL:
			# Cambio stato se il player tocca il pavimento
			# Oppure se non è più vicino a un muro
			if is_on_floor():
				state = States.FLOOR # Cambio stato -> floor
				continue # passa subito al prossimo stato
			elif not is_near_wall():
				state = States.AIR # Cambio stato -> air
				continue # passa subito al prossimo stato
			# Se sono attaccato a un muro per poter dashare dovrò tornare nello stato FLOOR
			can_dash = false
			# Cambio animazione(sprite), e passo a wall
			$AnimatedSprite.play("wall")  # Cambio animazione/sprite -> wall
			# Muovimento del personaggio
			# Modifica alla velocity.y -> Se il player ha una velocity.y minore a max_wall_slide_speed la aumento
			# Se salto:
			# 1) Setto la direzione opposta e flippo lo sprite
			# 2) Cambio stato
			if velocity.y < max_wall_slide_speed:
				# clamp(valore, min, max)
				velocity.y += clamp(velocity.y * 2, jump_height*0.02, 350 / (velocity.y * 0.3))
			if ((Input.is_action_pressed("left") and direction == 1) or (Input.is_action_pressed("right") and direction == -1)):
				if direction == 1:
					$AnimatedSprite.flip_h = true
					horizontal = -1.0
				else:
					$AnimatedSprite.flip_h = false
					horizontal = 1.0
				set_direction()
				# Non so pk cambio la velocità nell'asse x, anche comentato il wall jump funziona bene
				# velocity.x = move_speed * direction # da capire che valore mettere
				jump()
				state = States.AIR
			# Faccio muovere il player
			velocity = move_and_slide(velocity, Vector2.UP)

# Gestione della gravità
# Se il payer sale uso jump_gravity, se scendo uso fall_gravity
func get_gravity() -> float:
	return jump_gravity if velocity.y < 0.0 else fall_gravity

# Gestione del salto
# La velocità nell'asse y viene impostata = a jump_velocity
func jump():
	velocity.y = jump_velocity

# Gestione muovimento orrizontale
# Se clicco la freccia sinistra il valore horizontal vale -1, accade l'opposto se clicco destra
func get_horizontal_velocity() -> float:
	# Per avere il salto tenendo premuto togliere _just_
	if Input.is_action_just_pressed("left"):
		$AnimatedSprite.flip_h = true
		horizontal = -1.0
	if Input.is_action_just_pressed("right"):
		$AnimatedSprite.flip_h = false
		horizontal = 1.0
	return horizontal

# Gestione rilevamento muro nelle vicinanze
# Ritorna true se il RayCast2D collide col muro
func is_near_wall() -> bool:
	return $WallChecker.is_colliding()

# Gestione direzione RayCast2D
# Assegno la direzoine del RayCast2D, in base allo sprite(se e flippato sull'asse x)
# Possibile miglioramento:
# Rimozione di questo blocco e uso la variabile Horizontal invece di direction
func set_direction():
	direction = 1 if not $AnimatedSprite.flip_h else -1
	$WallChecker.rotation_degrees = 90 * -direction # L'angolo di rotazione del RayCast 2D ha 90 a sinistra e -90 a destra(quindi l'opposto)
