/obj/machinery/computer/blackjack
    name = "BlackJack Robot"
    icon = 'icons/mob/robots.dmi'
    icon_state = "tophat"
    obj_integrity = 999999
    var/minimum_bet = 10
    var/maximum_bet = 100
    var/list/players = list() // list of players, input is the table and output is the mob.
    var/current_hands[0] // Input is the mob, output is the card hand.
    var/current_player // Current hand playing right now
    var/list/current_tables = list() // List of tables, returns the mob associated with it. Might be able to get rid of this one.
    var/obj/item/toy/cards/deck/linked_deck = null
    var/mob/living/carbon/human/dealer/linked_dealer = null
    var/current_split = 1 // Which split hand are we on? Default 1
    var/can_split = 0 // Used as a variable to store various information about the ability to split.
    var/in_progress = FALSE // Is the game currently ongoing?

/obj/machinery/computer/blackjack/Initialize(mapload, obj/item/circuitboard/C)
    . = ..()
    linked_dealer = new/mob/living/carbon/human/dealer(src.loc) //what have i done
    linked_deck = new/obj/item/toy/cards/deck(src.loc)
    linked_dealer.put_in_active_hand(linked_deck)
    linked_dealer.status_flags ^= GODMODE
    linked_dealer.swap_hand()
    linked_dealer.name = "BlackJack Robot"
    var/i = 1
    for(var/obj/structure/table/T in oview(1,linked_dealer))
        current_tables[T] = null
        T.name = "Table [i]"
        i++
    var/obj/structure/table/dealer_table = current_tables[current_tables.len]
    dealer_table.maptext = "<b>Dealer's Table</b>"
    dealer_table.name = "Dealer's Table"
    dealer_table.maptext_y = 32
    dealer_table.maptext_width = 40
    linked_deck.attack_self(linked_dealer) //shuffle the deck
    idle_mode()

/obj/machinery/computer/blackjack/Adjacent(atom/neighbor)
    return (get_dist(src, neighbor) <= 2)

/obj/machinery/computer/blackjack/proc/add_player(mob/user,key)
    listclearnulls(players)
    if(!key)
        return
    if(in_progress)
        to_chat(user, "A game is currently in process. Please wait until it is finished.")
        updateUsrDialog()
        return
    // Need to add check to see if player has insufficient funds.
    var/P = LAZYLEN(players)
    P++
    if(P >= current_tables.len)
        to_chat(user, "There's already [current_tables.len] players signed up! You'll have to wait for one to leave.")
        updateUsrDialog()
        return
    for(var/obj/structure/table/T in current_tables)
        if(!ismob(current_tables[T]) || T.name != "<b>Dealer's Table</b>")
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
    if(hand)
        hand.anchored = FALSE
    linked_deck.attack_hand(linked_dealer)
    var/obj/item/toy/cards/singlecard/card = linked_dealer.get_active_held_item()
    if(can_split == copytext(card.cardname,1,3)) // copies the card name, compares it to determine if we can split
        can_split = 1
    if(TRUE)// going to need to add something so that one of the dealer's cards is flipped, and if flipped: it doesn't add to total.
        card.Flip()
    if(!hand) // First card going out
        card.forceMove(T.loc)
        current_hands[current_tables[T]] = card
        can_split = copytext(card.cardname,1,3) // Stores first card name to compare.
        return card.value
    else // Second or later card.
        hand.attackby(card,linked_dealer)
        var/obj/item/toy/cards/cardhand/new_hand = hand
        if(linked_dealer.get_active_held_item()) // Interaction is wonky depending on how many cards you have. This is the second card then.
            new_hand = linked_dealer.get_active_held_item()
            new_hand.forceMove(T.loc)
            if(!islist(current_hands[current_tables[T]]))
                current_hands[current_tables[T]] = new_hand
            else // We're hitting a split hand, we need to do it again.
                can_split = 0
                if(current_split < 2) // REALLY NEED TO REDO THIS, THIS JUST AUTOMATICALLY HITS AND CYCLES IT BACK
                    current_hands[current_tables[T]][current_split] = new_hand
                    new_hand.pixel_x = 0
                    current_split++
                    hit(current_tables[T])
                    new_hand.anchored = TRUE
                    return new_hand.value
                current_hands[current_tables[T]][current_split] = new_hand
                new_hand.pixel_x = 16
                current_split--
        new_hand.anchored = TRUE
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
    can_split = 0
    next_turn(user)
    return

/obj/machinery/computer/blackjack/proc/split(mob/user)
    var/obj/item/toy/cards/cardhand/hand = current_hands[user]
    current_hands[user] = hand.split() // from the base of cards/cardhand
    hit(user)

/obj/machinery/computer/blackjack/proc/double(mob/user)
    hit(user)

/obj/machinery/computer/blackjack/proc/lose(mob/user, busted=TRUE)
    remove_bet(user, 0)
    if(busted && user != linked_dealer)
        src.say("You've busted! You lose!")
        next_turn(user)

/obj/machinery/computer/blackjack/proc/win(mob/user)
    remove_bet(user, 2)

/obj/machinery/computer/blackjack/proc/push(mob/user)
    remove_bet(user, 1)


/obj/machinery/computer/blackjack/proc/start_game(user)
    in_progress = TRUE
    players += linked_dealer
    var/obj/structure/table/T = current_tables[current_tables.len]
    players[linked_dealer] = T
    current_tables[T] = linked_dealer
    for(var/mob/M in players)
        hit(M)
        hit(M) // two cards
    var/P = players[1]
    current_player = players[P]
    updateUsrDialog()


/obj/machinery/computer/blackjack/proc/next_turn(user)
    if(islist(current_hands[user]) && current_split == 1)
        ++current_split
        return
    var/mob/M = next_list_item(user, players)
    current_player = players[M]
    if(linked_dealer == M)// End of the list, dealer goes
        dealer_draw()
    updateUsrDialog()
    
    // need callback for 15 second timer.

/obj/machinery/computer/blackjack/proc/dealer_draw()
    var/obj/item/toy/cards/cardhand/dealer_hand = current_hands[linked_dealer]
    while(dealer_hand.value < 17)
        hit(linked_dealer)
    end_game(dealer_hand)

/obj/machinery/computer/blackjack/proc/end_game(obj/item/toy/cards/cardhand/dealer_hand)
    var/dealer_busted
    if(dealer_hand.value > 21)
        dealer_busted = TRUE
    src.say("The dealer has [dealer_hand.value].[dealer_busted ? " The dealer has busted." : ""]")
    sleep(2 SECONDS)
    for(var/mob/M in players)
        if(M == linked_dealer)
            continue
        updateUsrDialog()
        var/obj/item/toy/cards/cardhand/hand = current_hands[M]
        if((hand.value > dealer_hand.value && hand.value <= 21) || (dealer_busted && hand.value <= 21)) // Dealer busted or we have more
            win(M) // could probably wrap all these as a handle_win
            src.say("[M.name] has won")
            sleep(2 SECONDS)
            break
        if(hand.value == dealer_hand.value && hand.value <= 21) // Our hand is the same but we haven't busted.
            push(M)
            src.say("[M.name] has pushed")
            sleep(2 SECONDS)
        else
            lose(M, FALSE)
            src.say("[M.name] has lost")
            sleep(2 SECONDS)
    for(var/obj/item/toy/cards/C in view(1,linked_dealer))
        qdel(C)
    players -= linked_dealer
    linked_dealer.swap_hand()
    linked_deck = new/obj/item/toy/cards/deck(src.loc)
    linked_dealer.put_in_active_hand(linked_deck)
    linked_dealer.swap_hand()
    linked_deck.attack_self(linked_dealer)
    in_progress = FALSE
    current_player = null
    updateUsrDialog()
    idle_mode()

/obj/machinery/computer/blackjack/proc/idle_mode()
    src.say("Place your bets!")
    sleep(10 SECONDS)
    if(players.len) // should probably check for bets
        start_game()
    else
        idle_mode()

/obj/machinery/computer/blackjack/proc/set_bet(mob/user)
    var/selection = input(usr, "Set your current bet.", null) as num
    var/range_check = clamp(selection, minimum_bet, maximum_bet)
    if(selection != range_check)
        to_chat(user, "Your selection is out of range! Your amount was clamped to the range.")
        selection = range_check
    if(ishuman(user))
        var/mob/living/carbon/human/H = user
        var/obj/item/card/id/C = H.get_idcard(TRUE)
        if(C)
            if(C.registered_account.account_balance < selection)
                to_chat(user, "You do not have enough funds to bet this much. Lower your bet and try again.")
                return
        else
            to_chat(user, "Account unknown. You are unable to bet.")
            return
        C.registered_account.account_balance = C.registered_account.account_balance - selection
    var/obj/structure/table/T = players[user]
    var/x = 16
    var/y = 0
    playsound(src, 'sound/items/chips.ogg', 50, TRUE)
    while(selection > 0)
        var/obj/item/chip
        switch(selection)
            if(100 to INFINITY)
                chip = new/obj/item/casino_chip/hundred(T.loc)
                selection = selection - 100
            if(50 to 99)
                chip = new/obj/item/casino_chip/fifty(T.loc)
                selection = selection - 50
            if(10 to 49)
                chip = new/obj/item/casino_chip/ten(T.loc)
                selection = selection - 10
            if(1 to 9)
                chip = new/obj/item/casino_chip/one(T.loc)
                selection = selection - 1
        chip.anchored = TRUE
        chip.pixel_x = x
        chip.pixel_y = y
        y = y + 2
        if(y > 16)
            y = 0
            x = x - 2
        

/obj/machinery/computer/blackjack/proc/remove_bet(mob/user, multiplier=1)
    var/obj/structure/table/T = players[user]
    var/total = 0
    for(var/obj/item/casino_chip/chip in T.loc) // dummy chip
        total = total + chip.value
        qdel(chip)
    total = multiplier * total
    if(ishuman(user))
        var/mob/living/carbon/human/H = user
        var/obj/item/card/id/C = H.get_idcard(TRUE)
        if(C.registered_account)
            var/datum/bank_account/B = C.registered_account
            B.account_balance = B.account_balance + total
            B.bank_card_talk("Gambling transaction processed, account now holds [B.account_balance] cr.") // ensure that this works.

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
        remove_bet(user, 1)
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
        if(!in_progress)
            dat += "<div><a href='?src=[REF(src)];set_bet=1'>Add bet to Table</a></div>"
            dat += "<div><a href='?src=[REF(src)];remove_bet=1'>Return bet to hand</a></div>"
        if(current_player == players[user])//need to check if it's our turn
            dat += "<div><a href='?src=[REF(src)];hit=1'>Hit</a></div>"
            dat += "<div><a href='?src=[REF(src)];stand=1'>Stay</a></div>"
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

/obj/machinery/computer/blackjack/handle_atom_del(atom/A)
    qdel(linked_dealer)

/obj/machinery/computer/blackjack/updateUsrDialog() // lol i didn't code this orginally i promise
    if((obj_flags & IN_USE) && !(obj_flags & USES_TGUI))
        var/is_in_use = FALSE
        var/list/nearby = viewers(2, src) // main difference here. Need to update when 2 away.
        for(var/mob/M in nearby)
            if((M.client && M.machine == src))
                is_in_use = TRUE
                ui_interact(M)
        if(issilicon(usr) || IsAdminGhost(usr))
            if(!(usr in nearby))
                if(usr.client && usr.machine== src)
                    is_in_use = TRUE
                    ui_interact(usr)
        if(is_in_use)
            obj_flags |= IN_USE
        else
            obj_flags &= ~IN_USE

/mob/living/carbon/human/dealer //card code requires a human to work.
    alpha = 0
    mouse_opacity = 0
    density = 0

/obj/item/casino_chip
    icon = 'icons/obj/chips.dmi'
    name = "Casino Chip"
    icon_state = "chip_1"
    flags_1 = CONDUCT_1
    force = 1
    throwforce = 2
    w_class = WEIGHT_CLASS_TINY
    var/value = 0

/obj/item/casino_chip/one
    value = 1

/obj/item/casino_chip/ten
    icon_state = "chip_2"
    value = 10

/obj/item/casino_chip/fifty
    icon_state = "chip_3"
    value = 50

/obj/item/casino_chip/hundred
    icon_state = "chip_4"
    value = 100
