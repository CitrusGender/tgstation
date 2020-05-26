/obj/machinery/computer/blackjack
    name = "BlackJack Robot"
    icon = 'icons/mob/robots.dmi'
    icon_state = "tophat"
    var/minimum_bet = 10
    var/maximum_bet = 100
    var/list/players = list() // list of players
    var/current_hands[0]
    var/list/current_tables = list()
    var/obj/item/toy/cards/deck/linked_deck = null
    var/mob/living/carbon/human/dealer/linked_dealer = null
    var/current_split = 1 // Which split hand are we on? Default 1
    var/can_split = 0 // Used as a variable to store various information about the ability to split.

/obj/machinery/computer/blackjack/Initialize(mapload, obj/item/circuitboard/C)
    . = ..()
    linked_dealer = new/mob/living/carbon/human/dealer(src.loc) //what have i done
    linked_deck = new/obj/item/toy/cards/deck(src.loc)
    linked_dealer.put_in_active_hand(linked_deck)
    linked_dealer.status_flags ^= GODMODE
    linked_dealer.swap_hand()
    var/i = 1
    for(var/obj/structure/table/T in oview(1,linked_dealer))
        current_tables[T] = null
        T.name = "Table [i]"
        i++
    linked_deck.attack_self(linked_dealer) //shuffle the deck

/obj/machinery/computer/blackjack/Adjacent(atom/neighbor)
    return (get_dist(src, neighbor) <= 2)

/obj/machinery/computer/blackjack/proc/add_player(mob/user,key)
    if(!key)
        return
    // Need to add check to see if player has insufficient funds.
    if(LAZYLEN(players) > 4)
        to_chat(user, "There's already 5 players signed up! You'll have to wait for one to leave.")
        updateUsrDialog()
        return
    for(var/obj/structure/table/T in current_tables)
        if(!ismob(current_tables[T]))
            current_tables[T] = user
            players[user] = T
            break
    updateUsrDialog()

/obj/machinery/computer/blackjack/proc/remove_player(mob/user,key) //need to check to see if a hand is currently going on
    for(var/mob/M in players)
        if(user == M)
            players -= M
            for(var/obj/structure/table/T in current_tables)
                if(user == current_tables[T])
                    current_tables[T] = null
    updateUsrDialog()


/obj/machinery/computer/blackjack/proc/add_card(obj/item/toy/cards/hand,obj/structure/table/T)
    //should probably ensure that the hand is empty, just in case.
    linked_deck.attack_hand(linked_dealer)
    var/obj/item/toy/cards/singlecard/card = linked_dealer.get_active_held_item()
    if(can_split == copytext(card.cardname,1,3))
        can_split = 1
    if(TRUE) // going to need to add something so that one of the dealer's cards is flipped, and if flipped: it doesn't add to total.
        card.Flip()
    if(!hand)
        card.forceMove(T.loc)
        current_hands[current_tables[T]] = card
        can_split = copytext(card.cardname,1,3)
        return card.value
    else
        hand.attackby(card,linked_dealer)
        var/obj/item/toy/cards/cardhand/new_hand = hand
        if(linked_dealer.get_active_held_item()) // Interaction is wonky depending on how many cards you have.
            new_hand = linked_dealer.get_active_held_item()
            new_hand.forceMove(T.loc)
            if(!islist(current_hands[current_tables[T]]))
                current_hands[current_tables[T]] = new_hand
            else // We're hitting a split hand, we need to do it again.
                can_split = 0
                if(current_split < 2) // REALLY NEED TO REDO THIS
                    current_hands[current_tables[T]][current_split] = new_hand
                    new_hand.pixel_x = 0
                    current_split++
                    hit(current_tables[T])
                    return new_hand.value
                current_hands[current_tables[T]][current_split] = new_hand
                new_hand.pixel_x = 16
                current_split--

                
        return new_hand.value

/obj/machinery/computer/blackjack/proc/hit(mob/user)
    var/H = current_hands[user]
    var/current_value
    if(!islist(H))
        var/obj/item/toy/cards/C = current_hands[user]
        current_value = add_card(C, players[user])
    else // The hand was split
        var/list/hands = current_hands[user]
        current_value = add_card(hands[current_split], players[user])
    if(current_value > 21)
        lose(user)
    
    //should probably make way to throw chips to dealer if the player busts

/obj/machinery/computer/blackjack/proc/stand(mob/user) // need to cycle to next hand if split
    var/H = current_hands[user]
    can_split = 0
    if(islist(H) && current_split == 1)
        ++current_split
    else
        return

/obj/machinery/computer/blackjack/proc/split(mob/user)
    var/obj/item/toy/cards/cardhand/hand = current_hands[user]
    current_hands[user] = hand.split()
    hit(user)

/obj/machinery/computer/blackjack/proc/double(mob/user)
    hit(user)

/obj/machinery/computer/blackjack/proc/lose(mob/user)
    remove_bet(user, FALSE)
    src.say("You've busted! You lose!")

/obj/machinery/computer/blackjack/proc/set_bet(mob/user)
    var/selection = input(usr, "Set your current bet.", null) as num
    var/range_check = clamp(selection, minimum_bet, maximum_bet)
    if(selection != range_check)
        to_chat(user, "Your selection is out of range!")
    var/obj/structure/table/T = players[user]
    var/obj/chip = new/obj/item/reagent_containers/food/snacks/donkpocket(T.loc) // dummy chip, need to set it so that it's linked to the account.
    chip.pixel_y = 0
    chip.pixel_x = 16

/obj/machinery/computer/blackjack/proc/remove_bet(mob/user, return_chips=TRUE)
    var/obj/structure/table/T = players[user]
    for(var/obj/item/reagent_containers/food/snacks/donkpocket/chip in T.loc) // dummy chip
        qdel(chip)
        if(return_chips)
            return
    

/obj/machinery/computer/blackjack/Topic(href, href_list)
    if(..())
        return
    var/mob/user = usr
    if(!user.client.holder)
        return
    if(href_list["add_player"])
        add_player(user, user.key)
    if(href_list["remove_player"])
        remove_player(user)
    if(href_list["set_bet"])
        set_bet(user)
    if(href_list["remove_bet"])
        remove_bet(user)
    if(href_list["hit"])
        hit(user)
    if(href_list["stand"])
        stand(user)
    if(href_list["split"])
        split(user)
    if(href_list["double"])
        double(user)
    updateUsrDialog()

/obj/machinery/computer/blackjack/ui_interact(mob/user, ui_key, datum/tgui/ui, force_open, datum/tgui/master_ui, datum/ui_state/state)
    . = ..()
    var/list/dat = list()
    dat += "<h1>Blackjack</h1>"
    dat += "<div>Test your luck! Minimum bet is [minimum_bet] credits and the maximum bet is [maximum_bet] credits.</div>"
    dat += "<h2>Rules:<h2>"
    dat += "<ol>"
    dat += "<li>Dealer will stand at 17</li>"
    dat += "<li></li>"
    dat += "</ol>"
    if(user in players)
        dat += "<div><a href='?src=[REF(src)];remove_player=1'>Leave Game</a></div>"
        if(TRUE)// need to check if game is in process, need to clamp number
            dat += "<div><a href='?src=[REF(src)];set_bet=1'>Add bet to Table</a></div>"
            dat += "<div><a href='?src=[REF(src)];remove_bet=1'>Return bet to hand</a></div>"
        if(TRUE)//need to check if it's our turn
            dat += "<div><a href='?src=[REF(src)];hit=1'>Hit</a></div>"
            dat += "<div><a href='?src=[REF(src)];stay=1'>Stay</a></div>"
            if(can_split == 1)
                dat += "<div><a href='?src=[REF(src)];split=1'>Split</a></div>"
            if(TRUE)
                dat += "<div><a href='?src=[REF(src)];double=1'>Doubledown</a></div>"
    else
        dat += "<div><a href='?src=[REF(src)];add_player=1'>Join Game</a></div>"
    dat += "<h2>Current players:</h2><ul>"
    for(var/mob/M in players)
        if(M.name)
            dat += "<li>[M.name]</li>"
    dat += "</ul>"
    var/datum/browser/popup = new(user, "blackjack", "Blackjack Table", 500, 600)
    popup.set_content(dat.Join())
    popup.open()


/mob/living/carbon/human/dealer //card code requires a human to work.
    alpha = 0
    mouse_opacity = 0
    density = 0
