GLOBAL_DATUM_INIT(interviews, /datum/interview_manager, new)

/datum/interview_manager
	var/list/open_interviews = list()
	var/list/interview_queue = list()
	var/list/closed_interviews = list()

/datum/interview_manager/Destroy(force, ...)
	QDEL_LIST(open_interviews)
	QDEL_LIST(interview_queue)
	QDEL_LIST(closed_interviews)
	return ..()

/datum/interview_manager/proc/interview_for_ckey(ckey)
	var/list/combined = open_interviews | closed_interviews
	if (combined[ckey])
		return combined[ckey]
	else
		open_interviews[ckey] = new /datum/interview(ckey)
		return open_interviews[ckey]

/datum/interview_manager/proc/get_interview_by_id(id)
	if (id < 0)
		return
	for (var/datum/interview/i in (open_interviews | closed_interviews))
		if (i.id == id)
			return i

/datum/interview_manager/proc/enqueue(datum/interview/to_queue)
	if (!to_queue || (to_queue in interview_queue))
		return
	to_queue.pos_in_queue = interview_queue.len
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
