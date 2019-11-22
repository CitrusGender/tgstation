//time for beyblades

/obj/item/gun/beyblade_launcher
    name = "Beyblade Launcher"
    desc = "Let it rip!"
    icon = 'icons/obj/toy.dmi'
    icon_state = "launcher"
    fire_sound = 'sound/weapons/beyblade_launcher.ogg'
    force = 5

/obj/effect/beyblade
	name = "Beyblade"
	desc = "Let's Beyblade!"
	icon = 'icons/obj/objects.dmi'
	icon_state = "immrod"
	throwforce = 5
	move_force = INFINITY
	move_resist = INFINITY
	pull_force = INFINITY
	density = TRUE
	anchored = TRUE

/obj/effect/beyblade/New(atom/start, var/user, endpoint)// need to figure out how to get the furthest intersect of a line with the edge of the map
	..()
	var/atom/destination = endpoint
	smooth_walk_towards(src, destination, 0)
	//var/max_x = world.maxx
	//var/max_y = world.maxy
	//var/i = 0
	//for(i=destination.x,(i<=1 || i>=max_x),i++)
		//destination.x = CLAMP(((destination.x - start.x) * INFINITY), 1, max_x)
		//destination.y = CLAMP(((destination.y - start.y) * INFINITY), 1, max_y)
	//if(destination)
	//	for(var/turf/T in getline(start, endpoint))
	//		if(T.density == 1)
	//			break

/obj/item/gun/beyblade_launcher/afterattack(atom/target, mob/living/user, flag, params)
	var/turf/start = get_turf(user)
	var/atom/beyblade = new /obj/effect/beyblade(start, user, target)
	playsound(user, fire_sound, 50, TRUE)
	

/obj/effect/beyblade/Bump(atom/clong)
	audible_message("<span class='danger'>You hear a shredding noise.</span>")
	playsound(src, 'sound/weapons/beyblade.ogg', 50, TRUE)
	var/datum/effect_system/spark_spread/sparks = new
	sparks.set_up(2, 1, src)
	sparks.start()
	if(isturf(clong) || isobj(clong))
		if(clong.density)
			clong.ex_act(EXPLODE_HEAVY)
	else if(isliving(clong))
		slash(clong)
	else if(istype(clong, type))
		var/obj/effect/beyblade/other = clong
		visible_message("<span class='danger'>[src] collides with [other]!\
			</span>")
		var/datum/effect_system/smoke_spread/smoke = new
		smoke.set_up(2, get_turf(src))
		smoke.start()
		qdel(src)
		qdel(other)

/obj/effect/beyblade/proc/slash(mob/living/L)
	L.visible_message("<span class='danger'>[L] is penetrated by a beyblade!</span>" , "<span class='userdanger'>The beyblade penetrates you!</span>" , "<span class='danger'>You hear a CLANG!</span>")
	if(ishuman(L))
		var/mob/living/carbon/human/H = L
		H.adjustBruteLoss(5)
	if(L && (L.density || prob(10)))
		L.ex_act(EXPLODE_HEAVY)

/obj/effect/beyblade/proc/smooth_walk_towards(atom/Ref, atom/Trg, Lag=0, Speed=0)
	var/realpos_x = src.x
	var/realpos_y = src.y
	var/angle = ATAN2((Trg.x - src.x), (Trg.y - src.y))
	var/cos = cos(angle)
	var/sin = sin(angle)
	var/xsign = SIGN(cos)
	var/ysign = SIGN(sin)
	log_world("[realpos_x], [realpos_y], [angle], [cos], [sin], [xsign], [ysign]")
	//while(get_turf(Ref) != get_turf(Trg)) // essentially, while in motio
	var/i = 0
	while(i <= 10)
		if(sin >= cos)
			sin = sin - ysign
			realpos_y = realpos_y + ysign
			animate(src, pixel_y = (sin * 32), time = 10, flags = ANIMATION_PARALLEL)
			animate(src, pixel_x = (cos * 32), time = 10, flags = ANIMATION_PARALLEL)
			walk_towards(src, locate(realpos_x, realpos_y, src.z), Lag, Speed)
			log_world("[realpos_x], [realpos_y], [angle], [cos], [sin], [xsign], [ysign]")
		else // move horizontal
			cos = cos - xsign
			realpos_x = realpos_x + xsign
			animate(src, pixel_y = (sin * 32), time = 10, flags = ANIMATION_PARALLEL)
			animate(src, pixel_x = (cos * 32), time = 10, flags = ANIMATION_PARALLEL)
			walk_towards(src, locate(realpos_x, realpos_y, src.z), Lag, Speed)
			log_world("[realpos_x], [realpos_y], [angle], [cos], [sin], [xsign], [ysign]")
		i++