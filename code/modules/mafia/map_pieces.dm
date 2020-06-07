/obj/effect/landmark/mafia
	name = "Mafia Player Spawn"
	var/game_id = "mafia"

/obj/mafia_game_signup
	name = "Mafia Game Signup"
	desc = "Sign up here."
	icon = 'icons/obj/mafia.dmi'
	icon_state = "signup"
	var/game_id = "mafia"
	var/autostart = FALSE //Will try to start immidiately
	var/autostart_delay = 1 MINUTES
	var/autostart_timer

/obj/mafia_game_signup/attack_hand(mob/user)
	. = ..()
	var/datum/mafia_controller/MF = GLOB.mafia_games[game_id]
	if(!MF)
		MF = create_mafia_game(game_id)
	MF.sign_up(user)

/obj/mafia_game_signup/vv_edit_var(vname, vval)
	. = ..()
	switch(vname)
		if("autostart")
			toggle_autostart()

/obj/mafia_game_signup/proc/toggle_autostart()
	if(autostart)
		autostart_timer = addtimer(CALLBACK(src, .proc/try_starting), autostart_delay, TIMER_STOPPABLE)
	else
		if(autostart_timer)
			deltimer(autostart_timer)

/obj/mafia_game_signup/proc/try_starting()
	var/datum/mafia_controller/MF = GLOB.mafia_games[game_id]
	if(MF)
		MF.try_autostart()
	autostart_timer = addtimer(CALLBACK(src, .proc/try_starting), autostart_delay, TIMER_STOPPABLE)

//for ghosts/admins
/obj/mafia_game_board
	name = "Mafia Game Board"
	icon = 'icons/obj/mafia.dmi'
	icon_state = "board"
	var/game_id = "mafia"

/obj/mafia_game_board/attack_ghost(mob/user)
	. = ..()
	var/datum/mafia_controller/MF = GLOB.mafia_games[game_id]
	if(!MF)
		MF = create_mafia_game(game_id)
	MF.ui_interact(user)

/obj/mafia_game_signup/debug
	var/datum/mafia_controller/MF
	var/list/debug_setup = list(/datum/mafia_role/md=1,/datum/mafia_role/clown=1,/datum/mafia_role/detective=1,/datum/mafia_role/mafia=1)

/obj/mafia_game_signup/debug/Initialize()
	. = ..()
	new /obj/effect/landmark/mafia(get_step(get_turf(src),EAST))
	new /obj/effect/landmark/mafia(get_step(get_turf(src),WEST))
	new /obj/effect/landmark/mafia(get_step(get_turf(src),NORTH))
	new /obj/effect/landmark/mafia(get_step(get_turf(src),SOUTH))
	MF = create_mafia_game("mafia")
	MF.debug = TRUE
	MF.signed_up |= list("debug_guy_key","the_other_guy","third_loser")
	GLOB.mafia_setups = list(debug_setup)

