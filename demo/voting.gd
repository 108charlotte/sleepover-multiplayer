extends Node

# Who was voted out (accessible globally)
var voted_out_id: int = -1

@onready var button_container = $VBoxContainer/ButtonContainer
@onready var status_label = $VBoxContainer/StatusLabel
@onready var title_label = $VBoxContainer/TitleLabel

var candidates: Array = []       # 3 random peer IDs shown to everyone
var votes: Dictionary = {}       # { voter_id: voted_for_id }
var my_vote: int = -1
var voting_done: bool = false

func _ready():
	title_label.text = "Vote someone out!"
	status_label.text = ""
	# Server picks the 3 candidates and tells everyone
	if multiplayer.is_server():
		_pick_candidates()

func _pick_candidates():
	var all_peers = Array(multiplayer.get_peers()) # convert to regular Array
	all_peers.append(1)
	all_peers.shuffle()
	var picked = all_peers.slice(0, 3)
	receive_candidates.rpc(picked)

@rpc("authority", "call_local", "reliable")
func receive_candidates(picked: Array):
	candidates = picked
	_show_buttons()

func _show_buttons():
	# Clear old buttons
	for child in button_container.get_children():
		child.queue_free()
	# Make a button for each candidate
	for peer_id in candidates:
		var btn = Button.new()
		btn.text = "Player %d" % peer_id
		btn.pressed.connect(_on_vote.bind(peer_id))
		button_container.add_child(btn)

func _on_vote(peer_id: int):
	if my_vote != -1:
		return # already voted
	my_vote = peer_id
	status_label.text = "You voted for Player %d" % peer_id
	# Disable all buttons
	for btn in button_container.get_children():
		btn.disabled = true
	# Send vote to server
	submit_vote.rpc_id(1, multiplayer.get_unique_id(), peer_id)

@rpc("any_peer", "call_local", "reliable")
func submit_vote(voter_id: int, voted_for: int):
	if not multiplayer.is_server():
		return
	votes[voter_id] = voted_for
	print("Vote received: %d -> %d" % [voter_id, voted_for])
	# Check if everyone has voted
	var all_peers = multiplayer.get_peers()
	all_peers.append(1)
	var expected = min(len(all_peers), len(candidates)) # only voters in game
	if votes.size() >= all_peers.size():
		_tally_votes()

func _tally_votes():
	var tally = {}
	for voted_for in votes.values():
		if not tally.has(voted_for):
			tally[voted_for] = 0
		tally[voted_for] += 1
	# Find highest votes
	var winner = -1
	var highest = 0
	for peer_id in tally:
		if tally[peer_id] > highest:
			highest = tally[peer_id]
			winner = peer_id
	# Tell everyone the result
	announce_result.rpc(winner)

@rpc("authority", "call_local", "reliable")
func announce_result(loser_id: int):
	voted_out_id = loser_id
	voting_done = true
	status_label.text = "Player %d has been voted out!" % loser_id
	# Hide buttons
	for btn in button_container.get_children():
		btn.hide()
	# Wait a moment then continue game
	await get_tree().create_timer(3.0).timeout
	_on_voting_complete()

func _on_voting_complete():
	# voted_out_id is now set globally on all clients
	# Change to your next scene here:
	get_tree().change_scene_to_file("res://scenes/your_next_scene.tscn")
