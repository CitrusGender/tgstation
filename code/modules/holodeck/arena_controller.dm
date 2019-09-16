#define HOLODECK_CD 25
#define HOLODECK_DMG_CD 500

//stolen from holodeck code,it is horrid,thank you

/obj/machinery/computer/arena_controller
	name = "arena control console"
	desc = "A computer used to control a nearby arena."
	icon_screen = "holocontrol"
	idle_power_usage = 0
	active_power_usage = 0
	ui_x = 400
	ui_y = 500

	var/area/holodeck/arena/linked
	var/area/holodeck/arena/program
	var/area/holodeck/arena/last_program
	var/area/offline_program = /area/holodeck/arena/small/offline

	var/list/program_cache
	var/list/emag_programs

	// Splitting this up allows two holodecks of the same size
	// to use the same source patterns.  Y'know, if you want to.
	var/holodeck_type = /area/holodeck/arena/small	// locate(this) to get the target holodeck
	var/program_type = /area/holodeck/arena/small	// subtypes of this (but not this itself) are loadable programs

	var/active = FALSE
	var/damaged = FALSE
	var/list/spawned = list()
	var/list/effects = list()
	var/current_cd = 0

/obj/machinery/computer/arena_controller/Initialize(mapload)
	..()
	return INITIALIZE_HINT_LATELOAD

/obj/machinery/computer/arena_controller/LateInitialize()
	if(ispath(holodeck_type, /area))
		linked = pop(get_areas(holodeck_type, FALSE))
	if(ispath(offline_program, /area))
		offline_program = pop(get_areas(offline_program), FALSE)
	// the following is necessary for power reasons
	if(!linked || !offline_program)
		log_world("No matching arena area found")
		qdel(src)
		return
	var/area/AS = get_area(src)
	if(istype(AS, /area/holodeck/arena))
		log_mapping("Arena computer cannot be in a arena, This would cause circular power dependency.")
		qdel(src)
		return
	else
		linked.linked = src

	generate_program_list()
	load_program(offline_program, FALSE, FALSE)

/obj/machinery/computer/arena_controller/Destroy()
	emergency_shutdown()
	if(linked)
		linked.linked = null
	return ..()

/obj/machinery/computer/arena_controller/power_change()
	. = ..()
	toggle_power(!stat)

/obj/machinery/computer/arena_controller/ui_interact(mob/user, ui_key = "main", datum/tgui/ui = null, force_open = FALSE, datum/tgui/master_ui = null, datum/ui_state/state = GLOB.default_state)
	ui = SStgui.try_update_ui(user, src, ui_key, ui, force_open)
	if(!ui)
		ui = new(user, src, ui_key, "holodeck", name, ui_x, ui_y, master_ui, state)
		ui.open()

/obj/machinery/computer/arena_controller/ui_data(mob/user)
	var/list/data = list()

	data["default_programs"] = program_cache
	data["program"] = program
	data["can_toggle_safety"] = FALSE

	return data

/obj/machinery/computer/arena_controller/ui_act(action, params)
	if(..())
		return
	. = TRUE
	switch(action)
		if("load_program")
			var/program_to_load = text2path(params["type"])
			if(!ispath(program_to_load))
				return FALSE
			var/valid = FALSE
			for(var/prog in program_cache)
				var/list/P = prog
				if(P["type"] == program_to_load)
					valid = TRUE
					break
			if(!valid)
				return FALSE

			var/area/A = locate(program_to_load) in GLOB.sortedAreas
			if(A)
				load_program(A)

/obj/machinery/computer/arena_controller/process()
	if(!..() || !active)
		return

	for(var/item in spawned)
		if(!(get_turf(item) in linked))
			derez(item)

	for(var/e in effects)
		var/obj/effect/holodeck_effect/HE = e
		HE.tick()


/obj/machinery/computer/arena_controller/proc/generate_program_list()
	for(var/typekey in subtypesof(program_type))
		var/area/holodeck/arena/A = GLOB.areas_by_type[typekey]
		if(!A || !A.contents.len)
			continue
		var/list/info_this = list()
		info_this["name"] = A.name
		info_this["type"] = A.type
		if(A.restricted)
			LAZYADD(emag_programs, list(info_this))
		else
			LAZYADD(program_cache, list(info_this))

/obj/machinery/computer/arena_controller/proc/toggle_power(toggleOn = FALSE)
	if(active == toggleOn)
		return

	if(toggleOn)
		if(last_program && last_program != offline_program)
			addtimer(CALLBACK(src, .proc/load_program, last_program, TRUE), 25)
		active = TRUE
	else
		last_program = program
		load_program(offline_program, TRUE)
		active = FALSE

/obj/machinery/computer/arena_controller/proc/emergency_shutdown()
	last_program = program
	load_program(offline_program, TRUE)
	active = FALSE


/obj/machinery/computer/arena_controller/proc/nerf(active)
	for(var/obj/item/I in spawned)
		I.damtype = active ? STAMINA : initial(I.damtype)
	for(var/e in effects)
		var/obj/effect/holodeck_effect/HE = e
		HE.safety(active)

/obj/machinery/computer/arena_controller/proc/load_program(area/A, force = FALSE, add_delay = TRUE)
	if(!is_operational())
		A = offline_program
		force = TRUE

	if(program == A)
		return
	if(current_cd > world.time && !force)
		say("Cooldown,please wait before changing arena type.")
		return
	if(add_delay)
		current_cd = world.time + HOLODECK_CD
		if(damaged)
			current_cd += HOLODECK_DMG_CD

	for(var/e in effects)
		var/obj/effect/holodeck_effect/HE = e
		HE.deactivate(src)

	for(var/item in spawned)
		derez(item)

	program = A
	// note nerfing does not yet work on guns, should
	// should also remove/limit/filter reagents?
	// this is an exercise left to others I'm afraid.  -Sayu
	spawned = A.copy_contents_to(linked)
	for(var/obj/machinery/M in spawned)
		M.flags_1 |= NODECONSTRUCT_1
	for(var/obj/structure/S in spawned)
		S.flags_1 |= NODECONSTRUCT_1
	effects = list()

	addtimer(CALLBACK(src, .proc/finish_spawn), 30)

/obj/machinery/computer/arena_controller/proc/finish_spawn()
	var/list/added = list()
	for(var/obj/effect/holodeck_effect/HE in spawned)
		effects += HE
		spawned -= HE
		var/atom/x = HE.activate(src)
		HE.safety(FALSE)
		if(istype(x) || islist(x))
			spawned += x // holocarp are not forever
			added += x
	for(var/obj/machinery/M in added)
		M.flags_1 |= NODECONSTRUCT_1
	for(var/obj/structure/S in added)
		S.flags_1 |= NODECONSTRUCT_1

/obj/machinery/computer/arena_controller/proc/derez(obj/O, silent = TRUE, forced = FALSE)
	spawned -= O
	if(!O)
		return
	var/turf/T = get_turf(O)
	for(var/atom/movable/AM in O) // these should be derezed if they were generated
		AM.forceMove(T)
	qdel(O)

#undef HOLODECK_CD
#undef HOLODECK_DMG_CD


/obj/machinery/computer/arena_controller/arena/small
	offline_program = /area/holodeck/arena/arena/small/offline
	holodeck_type = /area/holodeck/arena/arena/small
	program_type = /area/holodeck/arena/arena/small

/obj/machinery/computer/arena_controller/arena/medium
	offline_program = /area/holodeck/arena/arena/medium/offline
	holodeck_type = /area/holodeck/arena/arena/medium
	program_type = /area/holodeck/arena/arena/medium

/obj/machinery/computer/arena_controller/arena/large
	offline_program = /area/holodeck/arena/arena/large/offline
	holodeck_type = /area/holodeck/arena/arena/large
	program_type = /area/holodeck/arena/arena/large