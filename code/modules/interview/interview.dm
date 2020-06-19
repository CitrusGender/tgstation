/datum/interview
	var/mob/dead/new_player/owner
	var/list/questions = list(
		"Why have you joined the server today?",
		"Have you played space-station 13 before? If so, on what servers?",
		"Do you know anybody on the server today? If so, who?",
		"Do you have any additional comments?"
	)
	var/list/responses = list()
	var/read_only = FALSE

/datum/interview/New(mob/dead/new_player/interviewee)
	if(!istype(interviewee))
		qdel(src)
	owner = interviewee
	responses.len = questions.len

/mob/dead/new_player/proc/open_interview()
	set name = "Open Interview"
	set category = "Interview"
	var/mob/dead/new_player/M = usr
	if (M?.client?.interviewee && M.interview_form)
		M.interview_form.ui_interact(M)

/datum/interview/ui_interact(mob/user, ui_key = "main", datum/tgui/ui = null, force_open = FALSE, datum/tgui/master_ui = null, datum/ui_state/state = GLOB.new_player_state)
	if (!ui)
		ui = new(user, src, ui_key, "Interview", "New User Interview", 500, 600, master_ui, state)
		ui.open()

/datum/interview/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	if (..())
		return
	if (action == "update_answer")
		responses[text2num(params["qidx"])] = params["answer"]
	if (action == "submit")
		read_only = TRUE

/datum/interview/ui_data(mob/user)
	. = list("questions" = list(), "read_only" = read_only)
	for (var/i in 1 to questions.len)
		var/list/data = list(
			"qidx" = i,
			"question" = questions[i],
			"response" = responses.len < i ? null : responses[i]
		)
		.["questions"] += list(data)
