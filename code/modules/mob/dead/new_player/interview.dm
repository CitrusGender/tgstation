/datum/interview
	var/mob/dead/new_player/owner

/datum/interview/New(mob/dead/new_player/interviewee)
	if(!istype(interviewee))
		qdel(src)
	owner = interviewee

/datum/interview/ui_interact(mob/user, ui_key = "main", datum/tgui/ui = null, force_open = FALSE, datum/tgui/master_ui = null, datum/ui_state/state = GLOB.new_player_state)
	if (!ui)
		ui = new(user, src, ui_key, "Interview", "Interview", 350, 700, master_ui, state)
		ui.open()

/datum/interview/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	if (..())
		return

	if (action == "submit")
		ui.close()

/datum/interview/ui_data(mob/user)
	return
