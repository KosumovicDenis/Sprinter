extends Node2D

onready var timer = $Dash_Timer

func start(duration) -> void:
	timer.wait_time = duration
	timer.start()

func is_dashing():
	return not timer.is_stopped()
