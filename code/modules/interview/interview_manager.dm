GLOBAL_DATUM_INIT(interviews, /datum/interview_manager, new)

/datum/interview_manager
	var/list/open_interviews = list()
	var/list/interview_queue = list()
	var/list/closed_interviews = list()
	var/list/approved_ckeys = list()

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

/datum/interview_manager/proc/interview_for_client(client/C, include_closed = TRUE)
	if (!C)
		return
	var/list/combined = include_closed ? (open_interviews | closed_interviews) : open_interviews
	if (combined[C.ckey])
		return combined[C.ckey]
	else
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
	if (to_close in open_interviews)
		open_interviews -= to_close
		closed_interviews |= to_close
