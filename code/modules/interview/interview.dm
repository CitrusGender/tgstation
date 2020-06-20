#define INTERVIEW_APPROVED	"interview_approved"
#define INTERVIEW_DENIED 	"interview_denied"
#define INTERVIEW_PENDING	"interview_pending"

/datum/interview
	var/id
	var/static/atomic_id = 0
	var/client/owner
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
	var/status = INTERVIEW_PENDING
	var/obj/effect/statclick/interview/statclick

/datum/interview/New(client/interviewee)
	if(!interviewee)
		qdel(src)
		return
	id = ++atomic_id
	owner = interviewee
	owner_ckey = owner.ckey
	responses.len = questions.len
	statclick = new(null, src)

/datum/interview/proc/approve(client/approved_by)
	status = INTERVIEW_APPROVED
	GLOB.interviews.approved_ckeys |= owner_ckey
	GLOB.interviews.close_interview(src)
	log_admin_private("[key_name(approved_by)] has approved interview #[id] for [owner_ckey][!owner ? "(DC)": ""].")
	message_admins("<span class='adminnotice'>[key_name(approved_by)] has approved interview #[id] for [owner_ckey][!owner ? "(DC)": ""].</span>")
	if (owner)
		SEND_SOUND(owner, sound('sound/effects/adminhelp.ogg'))
		to_chat(owner, "<font color='red' size='4'><b>-- Interview Update --</b></font>" \
			+ "\n<span class='adminsay'>Your interview was approved, you will now be reconnected in 5 seconds.</span>", confidential = TRUE)
		addtimer(CALLBACK(src, .proc/reconnect_owner), 50)

/datum/interview/proc/deny(client/denied_by)
	status = INTERVIEW_DENIED
	GLOB.interviews.close_interview(src)
	GLOB.interviews.cooldown_ckeys |= owner_ckey
	log_admin_private("[key_name(denied_by)] has denied interview #[id] for [owner_ckey][!owner ? "(DC)": ""].")
	message_admins("<span class='adminnotice'>[key_name(denied_by)] has denied interview #[id] for [owner_ckey][!owner ? "(DC)": ""].</span>")
	addtimer(CALLBACK(GLOB.interviews, /datum/interview_manager.proc/release_from_cooldown, owner_ckey), 180)
	if (owner)
		SEND_SOUND(owner, sound('sound/effects/adminhelp.ogg'))
		to_chat(owner, "<font color='red' size='4'><b>-- Interview Update --</b></font>" \
			+ "\n<span class='adminsay'>Unfortunately your interview was denied. Please try submitting another questionnaire." \
			+ " You may do this in three minutes.</span>", confidential = TRUE)

/datum/interview/proc/reconnect_owner()
	if (!owner)
		return
	winset(owner, null, "command=.reconnect")

/mob/dead/new_player/proc/open_interview()
	set name = "Open Interview"
	set category = "Interview"
	var/mob/dead/new_player/M = usr
	if (M?.client?.interviewee)
		var/datum/interview/I = GLOB.interviews.interview_for_client(M.client)
		if (I) // we can be returned nothing if the user is on cooldown
			I.ui_interact(M)
		else
			to_chat(usr, "<span class='adminsay'>You are on cooldown for interviews. Please" \
				+ " wait at least 3 minutes before starting a new questionnaire.</span>", confidential = TRUE)

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
		if ("approve")
			if (usr.client?.holder && status == INTERVIEW_PENDING)
				src.approve(usr)
				. = TRUE
		if ("deny")
			if (usr.client?.holder && status == INTERVIEW_PENDING)
				src.deny(usr)
				. = TRUE
		if ("adminpm")
			if (usr.client?.holder && owner)
				usr.client.cmd_admin_pm(owner, null)

/datum/interview/ui_status(mob/user, datum/ui_state/state)
	return (user?.client) ? UI_INTERACTIVE : UI_CLOSE

/datum/interview/ui_data(mob/user)
	. = list(
		"questions" = list(),
		"read_only" = read_only,
		"queue_pos" = pos_in_queue,
		"is_admin" = user?.client && user.client.holder,
		"status" = status,
		"connected" = !!owner)
	for (var/i in 1 to questions.len)
		var/list/data = list(
			"qidx" = i,
			"question" = questions[i],
			"response" = responses.len < i ? null : responses[i]
		)
		.["questions"] += list(data)

/obj/effect/statclick/interview
	var/datum/interview/interview_datum

/obj/effect/statclick/interview/Initialize(mapload, datum/interview/I)
	interview_datum = I
	. = ..()

/obj/effect/statclick/interview/update()
	var/datum/interview/I = interview_datum
	return ..("[I.owner_ckey][!I.owner ? " (DC)": ""] \[INT-[I.id]\]")

/obj/effect/statclick/interview/Click()
	interview_datum.ui_interact(usr)

/obj/effect/statclick/interview/Destroy(force)
	interview_datum = null
	. = ..()
