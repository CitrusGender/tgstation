/datum/interview
	var/id
	var/static/atomic_id = 0
	var/owner_ckey
	var/list/questions = list(
		"Why have you joined the server today?",
		"Have you played space-station 13 before? If so, on what servers?",
		"Do you know anybody on the server today? If so, who?",
		"Do you have any additional comments?"
	)
	var/list/responses = list()
	var/read_only = FALSE
	var/pos_in_queue

/datum/interview/New(interviewee)
	if(!interviewee)
		qdel(src)
		return
	id = ++atomic_id
	owner_ckey = interviewee
	responses.len = questions.len

/mob/dead/new_player/proc/open_interview()
	set name = "Open Interview"
	set category = "Interview"
	var/mob/dead/new_player/M = usr
	if (M?.client?.interviewee)
		var/datum/interview/I = GLOB.interviews.interview_for_ckey(M.client.ckey)
		I.ui_interact(M)

/datum/interview/ui_interact(mob/user, ui_key = "main", datum/tgui/ui = null, force_open = FALSE, datum/tgui/master_ui = null, datum/ui_state/state = GLOB.new_player_state)
	if (!ui)
		ui = new(user, src, ui_key, "Interview", "New User Interview", 500, 600, master_ui, state)
		ui.open()

/datum/interview/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	if (..())
		return
	switch(action)
		if ("update_answer")
			if (!read_only)
				responses[text2num(params["qidx"])] = params["answer"]
				. = TRUE
		if ("submit")
			if (!read_only)
				read_only = TRUE
				GLOB.interviews.enqueue(src)
				. = TRUE

/datum/interview/ui_data(mob/user)
	. = list("questions" = list(), "read_only" = read_only, "queue_pos" = pos_in_queue)
	for (var/i in 1 to questions.len)
		var/list/data = list(
			"qidx" = i,
			"question" = questions[i],
			"response" = responses.len < i ? null : responses[i]
		)
		.["questions"] += list(data)
