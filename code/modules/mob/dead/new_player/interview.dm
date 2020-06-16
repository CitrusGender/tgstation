/datum/interview
	var/mob/dead/new_player/owner
	var/list/questions = list(
		"Why have you joined the server today?",
		"Have you played space-station 13 before? If so, on what servers?",
		"Do you know anybody on the server today? If so, who?",
		"Do you have any additional comments?"
	)
	var/list/responses = list()
	var/list/comments = list()

/datum/interview/New(mob/dead/new_player/interviewee)
	if(!istype(interviewee))
		qdel(src)
	owner = interviewee

/datum/interview/ui_interact(mob/user, ui_key = "main", datum/tgui/ui = null, force_open = FALSE, datum/tgui/master_ui = null, datum/ui_state/state = GLOB.new_player_state)
	if (!ui)
		ui = new(user, src, ui_key, "Interview", "New User Interview", 400, 400, master_ui, state)
		ui.open()

/datum/interview/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	if (..())
		return

	if (action == "submit")
		ui.close()

/datum/interview/ui_data(mob/user)
	. = list("questions" = list())
	for (var/i in 1 to questions.len)
		.["questions"] += list(
			"qidx" = i,
			"question" = questions[i],
			"response" = responses.len < i ? null : responses[i],
			"comments" = comments.len < i ? null : comments[i]
		)
