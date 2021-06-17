/// The subsystem for controlling drastic performance enhancements aimed at reducing server load for a smoother albeit duller gaming expirence.
SUBSYSTEM_DEF(lag_switch)
	name = "Lag Switch"
	flags = SS_NO_FIRE
	init_order = INIT_ORDER_LAG_SWITCH //Just before Input

	/// If the lag switch measures should attempt to trigger automatically, TRUE if a config value exists
	var/auto_switch = FALSE
	/// Amount of connected clients above which the Lag Switch should engage, set via config or VV
	var/trigger_pop = INFINITY - 1337
	/// List of bools which put the "switch" in lag switch, never set these directly
	var/static/list/measures[MEASURES_AMOUNT]
	/// Timer ID for the automatic veto period
	var/veto_timer_id


/datum/controller/subsystem/lag_switch/Initialize(start_timeofday)
	for(var/i = 1, i <= measures.len, i++)
		measures[i] = FALSE
	var/auto_switch_pop = CONFIG_GET(number/auto_lag_switch_pop)
	span_announce()
	if(auto_switch_pop)
		auto_switch = TRUE
		trigger_pop = auto_switch_pop
		RegisterSignal(SSdcs, COMSIG_GLOB_CLIENT_CONNECT, .proc/client_connected)
	return ..()

/datum/controller/subsystem/lag_switch/proc/client_connected(datum/source, client/connected)
	SIGNAL_HANDLER
	if(TGS_CLIENT_COUNT < trigger_pop)
		return
	auto_switch = FALSE
	UnregisterSignal(SSdcs, COMSIG_GLOB_CLIENT_CONNECT)
	veto_timer_id = addtimer(CALLBACK(src, .proc/set_all_switches, TRUE, TRUE), 20 SECONDS, TIMER_STOPPABLE)
	message_admins("Lag Switch population trigger activated. Enabling of drastic lag mitigation measures occuring in 20 seconds. (<a href='?_src_=holder;[HrefToken()];change_lag_switch_option=CANCEL'>CANCEL</a>)")
	log_game("Lag Switch: client threshold reached, automatic enabling of all measures occuring in 20 seconds.")


/// (En/Dis)able automatic triggering of switches based on client count
/datum/controller/subsystem/lag_switch/proc/toggle_auto_switch()
	auto_switch = !auto_switch
	if(auto_switch)
		RegisterSignal(SSdcs, COMSIG_GLOB_CLIENT_CONNECT, .proc/client_connected)
	else
		UnregisterSignal(SSdcs, COMSIG_GLOB_CLIENT_CONNECT)

/// Called from an admin chat link
/datum/controller/subsystem/lag_switch/proc/cancel_auto_switch_in_progress()
	if(!veto_timer_id)
		return FALSE
	deltimer(veto_timer_id)
	veto_timer_id = null
	log_game("Lag Switch: an admin has canceled automatic enabling of all measures.")
	return TRUE

/// Handle the state change for individual switches
/datum/controller/subsystem/lag_switch/proc/set_switch(switch_key, state)
	if(isnull(switch_key) || isnull(state))
		stack_trace("SSlag_switch.set_switch() was called with a null arg")
		return FALSE
	if(isnull(LAZYACCESS(measures, switch_key)))
		stack_trace("SSlag_switch.set_switch() was called with a switch key not in the list of measures")
		return FALSE

	switch(switch_key)
		if(DISABLE_DEAD_KEYLOOP)
			if(state)
				deadchat_broadcast("To increase performance Observer freelook is disabled.\nPlease use Orbit, Teleport, and Jump to look around.", message_type = DEADCHAT_ANNOUNCEMENT)
			else
				deadchat_broadcast("Observer freelook has been re-enabled. Enjoy your wooshing.", message_type = DEADCHAT_ANNOUNCEMENT)
		// if(DISABLE_GHOST_ZOOM_TRAY)
		// 	if(state) // if enabling make sure current ghosts are updated
		// 		for(var/mob/dead/observer/O AS in GLOB.dead_mob_list)
		// 			// do it

	measures[switch_key] = state
	log_game("Lag Switch: measure at index ([switch_key]) has been turned [state ? "ON" : "OFF"].")
	return TRUE

/// Helper to loop over all switches for mass changes
/datum/controller/subsystem/lag_switch/proc/set_all_switches(state, automatic = FALSE)
	if(isnull(state))
		stack_trace("SSlag_switch.set_all_switchs() was called with a null state arg")
		return FALSE
	if(automatic)
		message_admins("Automatically enabling drastic lag mitigation measures now.")
		veto_timer_id = null
	for(var/i = 1, i <= measures.len, i++)
		set_switch(i, state)
	return TRUE
