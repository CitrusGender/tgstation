// Wait for 6 people to sign up
// Roll seeker
// Load random arena
// Move all to prep areas
// Send seeker after their prep time
// Send searchers after delay
// Wait round time
// GOTO START
#define PROPHUNT_HIDER_SPAWN "hider_spawn"
#define PROPHUNT_SEARCHER_SPAWN "searcher_spawn"

/obj/prophunt_signup_board
	name = "Prophunt Game Signup"
	desc = "Sign up here."
	icon = 'icons/obj/mafia.dmi'
	icon_state = "signup"
	var/arena_id = "prophunt_arena"
	var/obj/machinery/computer/arena/prophunt/linked_arena

/obj/prophunt_signup_board/Initialize()
	. = ..()
	return INITIALIZE_HINT_LATELOAD

/obj/prophunt_signup_board/LateInitialize()
	. = ..()
	for(var/obj/machinery/computer/arena/prophunt/P in GLOB.machines)
		if(P.arena_id == arena_id)
			linked_arena = P

/obj/prophunt_signup_board/attack_hand(mob/living/user)
	. = ..()
	if(linked_arena)
		linked_arena.try_to_signup(user)
	else
		to_chat(user,"UNLINKED SIGNUP")

#define PROPHUNT_SIGNUPS 1
#define PROPHUNT_SETUP 2
#define PROPHUNT_HIDING 3
#define PROPHUNT_GAME 4

// snowflake subtype for prophunt
/obj/machinery/computer/arena/prophunt
	name = "Prophunt Control"
	arena_id = "prophunt_arena"
	var/auto = FALSE //Toggle to start autogame
	var/game_state = PROPHUNT_SIGNUPS
	var/list/signed_up = list()
	var/list/projectors = list()
	var/list/hiders = list()
	var/list/searchers = list()

	var/hider_count = 1
	var/searcher_count = 5

	teams = list() //We'll handle it here
	objects_delete_on_leaving_arena = TRUE
	safe_reset = TRUE
	var/hiding_time = 2 MINUTES
	var/search_time = 3 MINUTES
	var/next_stage_timer
	var/debug = FALSE

	custom_specials = list("End round"="end_prophunt_round")

/obj/machinery/computer/arena/prophunt/proc/try_to_signup(mob/living/user)
	if(user in signed_up)
		signed_up -= user.ckey
		to_chat(user,"<span class='notice'>You remove your name from next prophunt game.</span>")
	else
		signed_up[user.ckey] = user
		to_chat(user,"<span class='notice'>You sign up for next prophunt game.</span>")
	if(auto && game_state == PROPHUNT_SIGNUPS && length(hider_count + searcher_count) >= 6)
		start_game()

/obj/machinery/computer/arena/prophunt/proc/debug_signups()
	debug = TRUE
	for(var/i in 1 to hider_count+searcher_count)
		var/mob/living/carbon/human/H = new(get_turf(usr))
		signed_up["[pick(GLOB.first_names_male)]"] = H

/obj/machinery/computer/arena/prophunt/special_handler(special_value)
	switch(special_value)
		if("end_prophunt_round")
			conclude_round()
			return TRUE
		else
			return FALSE

/obj/machinery/computer/arena/prophunt/proc/start_game()
	var/list/filtered_keys = list()
	for(var/key in signed_up)
		if(GLOB.directory[key] == signed_up[key])//Same mob as we signed in with
			filtered_keys += key
	if(debug)
		filtered_keys = signed_up.Copy() //DEBUG ONLY
	var/req_players = hider_count + searcher_count
	if(length(filtered_keys) < req_players)
		return
	game_state = PROPHUNT_SETUP
	while(length(filtered_keys) > req_players)
		pick_n_take(filtered_keys)
	signed_up -= filtered_keys
	hiders = list()
	for(var/i in 1 to hider_count)
		var/chosen_key = pick_n_take(filtered_keys)
		var/chosen_mob = GLOB.directory[chosen_key]
		hiders += chosen_mob
	searchers = list()
	for(var/i in 1 to searcher_count)
		var/chosen_key = pick_n_take(filtered_keys)
		var/chosen_mob = GLOB.directory[chosen_key]
		searchers += chosen_mob
	load_random_arena()
	send_hiders_in()

/obj/machinery/computer/arena/prophunt/proc/send_hiders_in()
	for(var/mob/living/L in hiders)
		var/obj/item/chameleon/projector = new()
		projectors += projector
		L.forceMove(get_landmark_turf(PROPHUNT_HIDER_SPAWN))
		L.put_in_hands(projector)
	to_chat(hiders,"<span class='danger'>Use the chameleon projector to hide! You got 2 minutes!</span>")
	to_chat(searchers,"<span class='danger'>Hider is now hiding! Wait 2 minutes.</span>")
	game_state = PROPHUNT_HIDING
	next_stage_timer = addtimer(CALLBACK(src,.proc/send_searchers_in),hiding_time, TIMER_STOPPABLE)

/obj/machinery/computer/arena/prophunt/proc/send_searchers_in()
	for(var/mob/living/L in searchers)
		L.forceMove(get_landmark_turf(PROPHUNT_SEARCHER_SPAWN))
	to_chat(searchers,"<span class='danger'>Search! You got 3 minutes!</span>")
	game_state = PROPHUNT_GAME
	next_stage_timer = addtimer(CALLBACK(src,.proc/conclude_round),search_time, TIMER_STOPPABLE)

/obj/machinery/computer/arena/prophunt/proc/conclude_round()
	QDEL_LIST(projectors)
	kick_players_out()
	if(next_stage_timer)
		deltimer(next_stage_timer)
	game_state = PROPHUNT_SIGNUPS

/obj/effect/landmark/arena/prophunt
	arena_id = "prophunt_arena"

/obj/effect/landmark/arena/prophunt/hider_spawn
	name = "hider spawn"
	landmark_tag = PROPHUNT_HIDER_SPAWN

/obj/effect/landmark/arena/prophunt/searcher_spawn
	name = "searcher spawn"
	landmark_tag = PROPHUNT_SEARCHER_SPAWN
