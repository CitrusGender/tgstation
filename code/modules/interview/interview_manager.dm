GLOBAL_DATUM_INIT(interviews, /datum/interview_manager, new)

/**
  * # Interview Manager
  *
  * Handles all interviews in the duration of a round, includes the primary functionality for
  * handling the interview queue.
  */
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

/**
  * Produces the content of the stat panel entry for administrators who are viewing the interview
  * system
  */
/datum/interview_manager/proc/stat_entry()
	stat("Active Interviews:", "[open_interviews.len] [active_interview_count()]")
	stat("Queued Interviews:", "[interview_queue.len]")
	stat("Closed Interviews:", "[closed_interviews.len]")
	if (interview_queue.len)
		stat("Interview Queue:", null)
		for(var/datum/interview/I in interview_queue)
			stat("\[[I.pos_in_queue]\]:", I.statclick.update())

/**
  * Produces a string reprsenting the number of active tickets specifically by online and disconnected
  * players, used for stat panel
  */
/datum/interview_manager/proc/active_interview_count()
	var/dc = 0
	for(var/ckey in open_interviews)
		var/datum/interview/I = open_interviews[ckey]
		if (I && !I.owner)
			dc++
	return "([open_interviews.len - dc] online / [dc] disconnected)"

/**
  * Used in the new client pipeline to catch when clients are reconnecting and need to have their
  * reference re-assigned to the 'owner' variable of an interview
  *
  * Arguments:
  * * C - The client who is logging in
  */
/datum/interview_manager/proc/client_login(client/C)
	for(var/ckey in open_interviews)
		var/datum/interview/I = open_interviews[ckey]
		if (I && !I.owner && C.ckey == I.owner_ckey)
			I.owner = C

/**
  * Used in the destroy client pipeline to catch when clients are disconnecting and need to have their
  * reference nulled on the 'owner' variable of an interview
  *
  * Arguments:
  * * C - The client who is logging out
  */
/datum/interview_manager/proc/client_logout(client/C)
	for(var/ckey in open_interviews)
		var/datum/interview/I = open_interviews[ckey]
		if (I?.owner && C.ckey == I.owner_ckey)
			I.owner = null

/**
  * Attempts to return an interview for a given client, using an existing interview if found, otherwise
  * a new interview is created; if the user is on cooldown then it will return null.
  *
  * Arguments:
  * * C - The client to get the interview for
  */
/datum/interview_manager/proc/interview_for_client(client/C)
	if (!C)
		return
	if (open_interviews[C.ckey])
		return open_interviews[C.ckey]
	else if (!(C.ckey in cooldown_ckeys))
		log_admin_private("New interview created for [key_name(C)].")
		open_interviews[C.ckey] = new /datum/interview(C)
		return open_interviews[C.ckey]

/**
  * Enqueues an interview in the interview queue, and notifies admins of the new interview to be
  * reviewed.
  *
  * Arguments:
  * * to_queue - The interview to enqueue
  */
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

/**
  * Removes a ckey from the cooldown list, used for enforcing cooldown after an interview is denied.
  *
  * Arguments:
  * * ckey - The ckey to remove from the cooldown list
  */
/datum/interview_manager/proc/release_from_cooldown(ckey)
	cooldown_ckeys -= ckey

/**
  * Dequeues the first interview from the interview queue, and updates the queue positions of any relevant
  * interviews that follow it.
  */
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

/**
  * Dequeues an interview from the interview queue if present, and updates the queue positions of
  * any relevant interviews that follow it.
  *
  * Arguments:
  * * to_dequeue - The interview to dequeue
  */
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

/**
  * Closes an interview, removing it from the queued interviews as well as adding it to the closed
  * interviews list.
  *
  * Arguments:
  * * to_close - The interview to dequeue
  */
/datum/interview_manager/proc/close_interview(datum/interview/to_close)
	if (!to_close)
		return
	dequeue_specific(to_close)
	if (open_interviews[to_close.owner_ckey])
		open_interviews -= to_close.owner_ckey
		closed_interviews += to_close
