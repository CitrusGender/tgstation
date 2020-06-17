#define PROPHUNT_HIDER_SPAWN "hider_spawn"
#define PROPHUNT_SEARCHER_SPAWN "searcher_spawn"
#define COMSIG_SIGNUP_SIGNUPS_CHANGED "signup_changed"

GLOBAL_DATUM_INIT(minigame_signups,/datum/minigame_signups,new)

/datum/minigame_signups
	var/list/signed_up = list()
	var/debug_mode = FALSE

/datum/minigame_signups/proc/SignUpFor(mob/user,game_id)
	if(!user.ckey || !game_id)
		return
	if(!signed_up[game_id])
		signed_up[game_id] = list()
	var/list/game_q = signed_up[game_id]
	if(game_q[user.ckey])
		game_q -= user.ckey
		to_chat(user,"You unregister from [game_id] game.")
	else
		game_q[user.ckey] = user
		to_chat(user,"You register for [game_id] game. There's now [length(game_q)] players signed up.")
	SEND_SIGNAL(src,COMSIG_SIGNUP_SIGNUPS_CHANGED,game_id)

/datum/minigame_signups/proc/GetCurrentPlayerCount(game_id)
	var/list/game_q = signed_up[game_id]
	. = 0
	if(debug_mode)
		return length(game_q)
	for(var/key in game_q)
		if(GLOB.directory[key] && GLOB.directory[key].mob == game_q[key])
			. += 1

//flush to remove from signups
/datum/minigame_signups/proc/GetPlayers(game_id,count,flush=TRUE)
	var/result = list()
	var/list/game_q = signed_up[game_id]
	var/list/possible_keys = list()
	for(var/key in game_q)
		if(GLOB.directory[key] && GLOB.directory[key].mob == game_q[key])
			possible_keys += key
	if(debug_mode)
		possible_keys = game_q.Copy()
	if(length(possible_keys) < count)
		return
	for(var/i in 1 to count)
		var/chosen_key = pick_n_take(possible_keys)
		result[chosen_key] = game_q[chosen_key]
		if(flush)
			for(var/key in signed_up)
				var/list/tbr = signed_up[key]
				tbr -= chosen_key
	return result

#define PROPHUNT_SIGNUPS 1
#define PROPHUNT_SETUP 2
#define PROPHUNT_HIDING 3
#define PROPHUNT_GAME 4

/obj/prophunt_signup_board
	name = "Prophunt Game Signup"
	desc = "Sign up here."
	icon = 'icons/obj/mafia.dmi'
	icon_state = "joinme"
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
	GLOB.minigame_signups.SignUpFor(user,"prophunt")
	if(linked_arena && linked_arena.game_state != PROPHUNT_SIGNUPS)
		var/left = 0
		switch(linked_arena.game_state)
			if(PROPHUNT_SETUP)
				left = linked_arena.hiding_time + linked_arena.search_time
			if(PROPHUNT_HIDING)
				left = timeleft(linked_arena.next_stage_timer) + linked_arena.search_time
			if(PROPHUNT_GAME)
				left = timeleft(linked_arena.next_stage_timer)
		to_chat(user,"<span class='notice'>Game in progress. Next will start in [DisplayTimeText(left)]</span>")
	else
		to_chat(user,"<span class='notice'>Next game will start as soon as there's [linked_arena.hider_count + linked_arena.searcher_count] players signed up.</span>")

// snowflake subtype for prophunt
/obj/machinery/computer/arena/prophunt
	name = "Prophunt Control"
	arena_id = "prophunt_arena"
	var/auto = FALSE //Toggle to start autogame
	var/game_state = PROPHUNT_SIGNUPS
	var/list/projectors = list()
	var/list/hiders = list()
	var/list/searchers = list()

	var/hider_count = 5
	var/searcher_count = 1

	teams = list() //We'll handle it here
	objects_delete_on_leaving_arena = TRUE
	safe_reset = TRUE
	var/hiding_time = 1 MINUTES
	var/search_time = 3 MINUTES
	var/next_stage_timer
	var/debug = FALSE

	custom_specials = list("End round"="end_prophunt_round")

/obj/machinery/computer/arena/prophunt/Initialize(mapload, obj/item/circuitboard/C)
	. = ..()
	RegisterSignal(GLOB.minigame_signups,COMSIG_SIGNUP_SIGNUPS_CHANGED,.proc/check_autostart)

/obj/machinery/computer/arena/prophunt/proc/check_autostart(datum/source,game_id)
	if(game_id != "prophunt")
		return
	try_autostart()

/obj/machinery/computer/arena/prophunt/proc/try_autostart()
	if(auto && game_state == PROPHUNT_SIGNUPS && GLOB.minigame_signups.GetCurrentPlayerCount("prophunt") > hider_count + searcher_count)
		start_game()

/obj/machinery/computer/arena/prophunt/proc/debug_signups()
	debug = TRUE
	GLOB.minigame_signups.debug_mode = TRUE
	var/list/prophunt_list = list()
	for(var/i in 1 to hider_count+searcher_count-1)
		var/mob/living/carbon/human/H = new(get_turf(usr))
		prophunt_list["[pick(GLOB.first_names_male)]"] = H
	if(!GLOB.minigame_signups.signed_up["prophunt"])
		GLOB.minigame_signups.signed_up["prophunt"] = prophunt_list
	else
		GLOB.minigame_signups.signed_up["prophunt"] |= prophunt_list


/obj/machinery/computer/arena/prophunt/special_handler(special_value)
	switch(special_value)
		if("end_prophunt_round")
			auto = FALSE
			conclude_round()
			return TRUE
		else
			return FALSE

/obj/machinery/computer/arena/prophunt/proc/start_game()
	var/req_players = hider_count + searcher_count
	var/list/filtered_keys = GLOB.minigame_signups.GetPlayers("prophunt",req_players,!debug)
	if(!filtered_keys)
		return
	game_state = PROPHUNT_SETUP
	hiders = list()
	for(var/i in 1 to hider_count)
		var/chosen_key = pick(filtered_keys)
		var/chosen_mob = filtered_keys[chosen_key]
		filtered_keys -= chosen_key
		hiders += chosen_mob
	searchers = list()
	for(var/i in 1 to searcher_count)
		var/chosen_key = pick(filtered_keys)
		var/chosen_mob = filtered_keys[chosen_key]
		filtered_keys -= chosen_key
		searchers += chosen_mob
	load_random_arena()
	send_hiders_in()

/obj/machinery/computer/arena/prophunt/proc/send_hiders_in()
	for(var/mob/living/L in hiders)
		var/obj/item/chameleon/projector = new()
		projectors += projector
		L.forceMove(get_landmark_turf(PROPHUNT_HIDER_SPAWN))
		L.put_in_hands(projector)
	to_chat(hiders,"<span class='danger'>Use the chameleon projector to hide! You got 1 minute!</span>")
	to_chat(searchers,"<span class='danger'>Hider is now hiding! Wait 1 minute.</span>")
	game_state = PROPHUNT_HIDING
	next_stage_timer = addtimer(CALLBACK(src,.proc/send_searchers_in),hiding_time, TIMER_STOPPABLE)

/obj/machinery/computer/arena/prophunt/proc/send_searchers_in()
	for(var/mob/living/L in searchers)
		L.forceMove(get_landmark_turf(PROPHUNT_SEARCHER_SPAWN))
	to_chat(searchers,"<span class='danger'>Search! You got 3 minutes!</span>")
	to_chat(hiders,"<span class='userdanger'>Search started! Try to stay hidden for 3 minutes!</span>")
	game_state = PROPHUNT_GAME
	next_stage_timer = addtimer(CALLBACK(src,.proc/conclude_round),search_time, TIMER_STOPPABLE)

/obj/machinery/computer/arena/prophunt/proc/conclude_round()
	QDEL_LIST(projectors)
	kick_players_out()
	if(next_stage_timer)
		deltimer(next_stage_timer)
	game_state = PROPHUNT_SIGNUPS
	try_autostart()

/obj/machinery/computer/arena/prophunt/kick_players_out()
	for(var/mob/M in hiders+searchers)
		M.forceMove(get_landmark_turf(ARENA_EXIT))
	. = ..()


/obj/effect/landmark/arena/prophunt
	arena_id = "prophunt_arena"

/obj/effect/landmark/arena/prophunt/hider_spawn
	name = "hider spawn"
	landmark_tag = PROPHUNT_HIDER_SPAWN

/obj/effect/landmark/arena/prophunt/searcher_spawn
	name = "searcher spawn"
	landmark_tag = PROPHUNT_SEARCHER_SPAWN
