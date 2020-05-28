#define MAFIA_TEAM_TOWN 1
#define MAFIA_TEAM_MAFIA 2
#define MAFIA_TEAM_SOLO 3

#define MAFIA_PHASE_SETUP 1
#define MAFIA_PHASE_DAY 2
#define MAFIA_PHASE_VOTING 3
#define MAFIA_PHASE_NIGHT 4
#define MAFIA_PHASE_VICTORY_LAP 5

#define MAFIA_ALIVE 1
#define MAFIA_DEAD 2

#define COMSIG_MAFIA_ON_KILL "mafia_onkill"
#define MAFIA_PREVENT_KILL 1

#define COMSIG_MAFIA_CAN_PERFORM_ACTION "mafia_can_perform_action"
#define MAFIA_PREVENT_ACTION 1

#define COMSIG_MAFIA_NIGHT_END "night_end"
#define COMSIG_MAFIA_NIGHT_START "night_start"
#define COMSIG_MAFIA_NIGHT_ACTION_PHASE "night_actions"
#define COMSIG_MAFIA_NIGHT_KILL_PHASE "night_kill"


/datum/mafia_setup
	var/name = "Make subtypes with the list and a name, more readable than list(list(),list()) etc"
	var/list/roles

/datum/mafia_setup/example_one
	name = "4 Player Debug Setup (KILL THIS LIVE)"
	roles = list(/datum/mafia_role/clown=1,/datum/mafia_role/security=1,/datum/mafia_role/detective=1,/datum/mafia_role/mafia=1)

/datum/mafia_setup/example_two
	name = "13 Player Example setup (same thing)"
	roles = list(/datum/mafia_role=9,/datum/mafia_role/detective=1,/datum/mafia_role/mafia=3)
