GLOBAL_DATUM_INIT(interviews, /datum/interview_manager, new)

/datum/interview_manager
	var/list/open_interviews = list()
	var/list/interview_queue = list()
	var/list/closed_interviews = list()
	var/list/approved_ckeys = list()
	var/list/cooldown_ckeys = list()

/datum/interview_manager/Destroy(force, ...)
	QDEL_LIST(open_interviews)
	QDEL_LIST(interview_queue)
	QDEL_LIST(closed_interviews)
	QDEL_LIST(approved_ckeys)
	return ..()

/datum/interview_manager/proc/stat_entry()
	stat("Active Interviews:", "[open_interviews.len] [active_interview_count()]")
	stat("Queued Interviews:", "[interview_queue.len]")
	stat("Closed Interviews:", "[closed_interviews.len]")
	if (interview_queue.len)
		stat("Interview Queue:", null)
		for(var/datum/interview/I in interview_queue)
			stat("\[[I.pos_in_queue]\]:", I.statclick.update())

/datum/interview_manager/proc/active_interview_count()
	var/dc = 0
	for(var/datum/interview/I in open_interviews)
		if (!I.owner)
			dc++
	return "([open_interviews.len - dc] online / [dc] disconnected)"

/datum/interview_manager/proc/client_login(client/C)
	for (var/datum/interview/I in open_interviews)
		if (!I.owner && C.ckey == I.owner_ckey)
			I.owner = C

/datum/interview_manager/proc/client_logout(client/C)
	for (var/datum/interview/I in open_interviews)
		if (I.owner && C.ckey == I.owner_ckey)
			I.owner = null

/datum/interview_manager/proc/interview_for_client(client/C)
	if (!C)
		return
	if (open_interviews[C.ckey])
		return open_interviews[C.ckey]
	else if (!(C.ckey in cooldown_ckeys))
		log_admin_private("New interview created for [key_name(C)].")
		open_interviews[C.ckey] = new /datum/interview(C)
		return open_interviews[C.ckey]

/datum/interview_manager/proc/get_interview_by_id(id)
	if (id < 0)
		return
	for (var/datum/interview/i in (open_interviews | closed_interviews))
		if (i.id == id)
			return i

/datum/interview_manager/proc/enqueue(datum/interview/to_queue)
	if (!to_queue || (to_queue in interview_queue))
		return
	to_queue.pos_in_queue = interview_queue.len + 1
	interview_queue |= to_queue

	// Notify admins
	var/ckey = to_queue.owner_ckey
	log_admin_private("Interview for [ckey] has been enqueued for review.")
	for(var/client/X in GLOB.admins)
		if(X.prefs.toggles & SOUND_ADMINHELP)
			SEND_SOUND(X, sound('sound/effects/adminhelp.ogg'))
		window_flash(X, ignorepref = TRUE)
		to_chat(X, "<span class='adminhelp'>Interview for [ckey] enqueued for review. Current position in queue: [to_queue.pos_in_queue]</span>", confidential = TRUE)

/datum/interview_manager/proc/release_from_cooldown(ckey)
	cooldown_ckeys -= ckey

/datum/interview_manager/proc/dequeue()
	if (interview_queue.len == 0)
		return

	// Get the first interview off the front of the queue
	var/datum/interview/to_return = interview_queue[1]
	interview_queue -= to_return

	// Decrement any remaining interview queue positions
	for(var/datum/interview/i in interview_queue)
		i.pos_in_queue--

	return to_return

/datum/interview_manager/proc/dequeue_specific(datum/interview/to_dequeue)
	if (!to_dequeue)
		return

	// Decrement all interviews in queue past the interview being removed
	var/found = FALSE
	for (var/datum/interview/i in interview_queue)
		if (found)
			i.pos_in_queue--
		if (i == to_dequeue)
			found = TRUE

	interview_queue -= to_dequeue

/datum/interview_manager/proc/close_interview(datum/interview/to_close)
	if (!to_close)
		return
	dequeue_specific(to_close)
	if (open_interviews[to_close.owner_ckey])
		open_interviews -= to_close.owner_ckey
		closed_interviews += to_close
