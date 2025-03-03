#define GIBBER_ANIMATION_DELAY 16
/obj/machinery/gibber
	name = "Gibber"
	desc = "The name isn't descriptive enough?"
	icon = 'icons/obj/kitchen.dmi'
	icon_state = "grinder"
	density = TRUE
	anchored = TRUE
	var/operating = FALSE //Is it on?
	var/dirty = FALSE // Does it need cleaning?
	var/mob/living/occupant // Mob who has been put inside
	var/locked = FALSE //Used to prevent mobs from breaking the feedin anim

	var/gib_throw_dir = WEST // Direction to spit meat and gibs in. Defaults to west.

	var/gibtime = 40 // Time from starting until meat appears
	var/animation_delay = GIBBER_ANIMATION_DELAY

	// For hiding gibs, making an even more devious trap (invisible autogibbers)
	var/stealthmode = FALSE
	var/list/victims = list()

	idle_power_consumption = 2
	active_power_consumption = 500

/obj/machinery/gibber/Initialize(mapload)
	. = ..()
	add_overlay("grinder_jam")
	component_parts = list()
	component_parts += new /obj/item/circuitboard/gibber(null)
	component_parts += new /obj/item/stock_parts/matter_bin(null)
	component_parts += new /obj/item/stock_parts/manipulator(null)
	RefreshParts()

/obj/machinery/gibber/Destroy()
	for(var/atom/movable/A in contents)
		A.forceMove(get_turf(src))
	occupant = null
	return ..()

/obj/machinery/gibber/suicide_act(mob/living/user)
	if(occupant || locked)
		return FALSE
	user.visible_message("<span class='danger'>[user] climbs into [src] and turns it on!</b></span>")
	user.Stun(20 SECONDS)
	user.forceMove(src)
	occupant = user
	update_icon(UPDATE_OVERLAYS | UPDATE_ICON_STATE)
	feedinTopanim()
	addtimer(CALLBACK(src, PROC_REF(startgibbing), user), 33)
	return OBLITERATION

/obj/machinery/gibber/update_icon_state()
	if(operating && !(stat & (NOPOWER|BROKEN)))
		icon_state = "grinder_on"
		return
	icon_state = initial(icon_state)

/obj/machinery/gibber/update_overlays()
	. = ..()
	if(dirty)
		. += "grinder_bloody"
	if(stat & (NOPOWER|BROKEN))
		return
	if(!occupant)
		. += "grinder_jam"
	else if(operating)
		. += "grinder_use"
	else
		. += "grinder_idle"

/obj/machinery/gibber/relaymove(mob/user)
	if(locked)
		return

	go_out()

/obj/machinery/gibber/attack_hand(mob/user)
	if(stat & (NOPOWER|BROKEN))
		return

	if(operating)
		to_chat(user, "<span class='danger'>The gibber is locked and running, wait for it to finish.</span>")
		return

	if(locked)
		to_chat(user, "<span class='warning'>Wait for [occupant.name] to finish being loaded!</span>")
		return

	startgibbing(user)

/obj/machinery/gibber/attackby(obj/item/P, mob/user, params)
	if(istype(P, /obj/item/grab))
		var/obj/item/grab/G = P
		if(G.state < 2)
			to_chat(user, "<span class='danger'>You need a better grip to do that!</span>")
			return
		move_into_gibber(user,G.affecting)
		qdel(G)
		return

	if(default_deconstruction_screwdriver(user, "grinder_open", "grinder", P))
		return

	if(exchange_parts(user, P))
		return

	if(default_unfasten_wrench(user, P, time = 4 SECONDS))
		return

	if(default_deconstruction_crowbar(user, P))
		return
	return ..()

/obj/machinery/gibber/MouseDrop_T(mob/target, mob/user)
	if(user.incapacitated() || !ishuman(user))
		return

	if(!isliving(target))
		return

	var/mob/living/targetl = target

	if(targetl.buckled)
		return

	INVOKE_ASYNC(src, TYPE_PROC_REF(/obj/machinery/gibber, move_into_gibber), user, target)
	return TRUE

/obj/machinery/gibber/proc/move_into_gibber(mob/user, mob/living/victim)
	if(occupant)
		to_chat(user, "<span class='danger'>[src] is full, empty it first!</span>")
		return

	if(operating)
		to_chat(user, "<span class='danger'>[src] is locked and running, wait for it to finish.</span>")
		return

	if(!ishuman(victim))
		to_chat(user, "<span class='danger'>This is not suitable for [src]!</span>")
		return

	user.visible_message("<span class='danger'>[user] starts to put [victim] into [src]!</span>")
	add_fingerprint(user)

	if(victim.abiotic(TRUE))
		to_chat(user, "<span class='danger'>Clothing detected. Please speak to an engineer if any clothing jams up the internal grinders!</span>")
		if(do_after(user, 15 SECONDS, target = victim) && user.Adjacent(src) && victim.Adjacent(user) && !occupant) //15 seconds if they are not fully stripped, 12 more than normal. Similarly, takes about that long to strip a person in a ert hardsuit of all gear.
			user.visible_message("<span class='danger'>[user] stuffs [victim] into [src]!</span>")
		else
			return
	else if(do_after(user, 3 SECONDS, target = victim) && user.Adjacent(src) && victim.Adjacent(user) && !occupant)
		user.visible_message("<span class='danger'>[user] stuffs [victim] into [src]!</span>")
	else
		return
	victim.forceMove(src)
	occupant = victim

	update_icon(UPDATE_OVERLAYS | UPDATE_ICON_STATE)
	INVOKE_ASYNC(src, PROC_REF(feedinTopanim))


/obj/machinery/gibber/verb/eject()
	set category = "Object"
	set name = "Empty Gibber"
	set src in oview(1)

	if(usr.incapacitated())
		return

	go_out()
	add_fingerprint(usr)

/obj/machinery/gibber/proc/go_out()
	if(operating || !occupant) //no going out if operating, just in case they manage to trigger go_out before being dead
		return

	if(locked)
		return

	for(var/obj/O in src)
		O.loc = loc

	occupant.forceMove(get_turf(src))
	occupant = null

	update_icon(UPDATE_OVERLAYS | UPDATE_ICON_STATE)

	return

/obj/machinery/gibber/proc/feedinTopanim()
	if(!occupant)
		return

	locked = TRUE //lock gibber

	var/image/gibberoverlay = new //used to simulate 3D effects
	gibberoverlay.icon = icon
	gibberoverlay.icon_state = "grinder_overlay"
	gibberoverlay.overlays += image('icons/obj/kitchen.dmi', "grinder_idle")
	icon_state = "grinder_on"

	var/image/feedee = new
	occupant.dir = 2
	feedee.icon = getFlatIcon(occupant, 2) //makes the image a copy of the occupant

	var/atom/movable/holder = new //holder for occupant image
	holder.name = null //make unclickable
	holder.overlays += feedee //add occupant to holder overlays
	holder.pixel_y = 25 //above the gibber
	holder.loc = get_turf(src)
	holder.layer = MOB_LAYER //simulate mob-like layering
	holder.anchored = TRUE

	var/atom/movable/holder2 = new //holder for gibber overlay, used to simulate 3D effect
	holder2.name = null
	holder2.overlays += gibberoverlay
	holder2.loc = get_turf(src)
	holder2.layer = MOB_LAYER + 0.1 //3D, it's above the mob, rest of the gibber is behind
	holder2.anchored = TRUE

	animate(holder, pixel_y = 16, time = animation_delay) //animate going down

	sleep(animation_delay)

	holder.overlays -= feedee //reset static icon
	feedee.icon += icon('icons/obj/kitchen.dmi', "footicon") //this is some byond magic; += to the icon var with a black and white image will mask it
	holder.overlays += feedee
	animate(holder, pixel_y = -3, time = animation_delay) //animate going down further

	sleep(animation_delay) //time everything right, animate doesn't prevent proc from continuing

	qdel(holder) //get rid of holder object
	qdel(holder2) //get rid of holder object
	locked = FALSE //unlock
	dirty = TRUE //dirty gibber

/obj/machinery/gibber/proc/startgibbing(mob/user, UserOverride=0)
	if(!istype(user) && !UserOverride)
		log_debug("Some shit just went down with the gibber at X[x], Y[y], Z[z] with an invalid user. (<A HREF='?_src_=holder;adminplayerobservecoodjump=1;X=[x];Y=[y];Z=[z]'>JMP</a>)")
		return

	if(UserOverride)
		add_attack_logs(user, occupant, "gibbed by an autogibber ([src])")
		log_game("[key_name(occupant)] was gibbed by an autogibber ([src]) (X:[x] Y:[y] Z:[z])")

	if(operating)
		return

	if(!occupant)
		visible_message("<span class='danger'>You hear a loud metallic grinding sound.</span>")
		return

	use_power(1000)
	visible_message("<span class='danger'>You hear a loud squelchy grinding sound.</span>")

	operating = TRUE
	update_icon(UPDATE_OVERLAYS | UPDATE_ICON_STATE)
	var/offset = prob(50) ? -2 : 2
	animate(src, pixel_x = pixel_x + offset, time = 0.2, loop = gibtime * 5) //start shaking

	var/slab_name = occupant.name
	var/slab_count = 3
	var/slab_type = /obj/item/reagent_containers/food/snacks/meat/human //gibber can only gib humans on paracode, no need to check meat type
	var/slab_nutrition = occupant.nutrition / 15

	slab_nutrition /= slab_count

	for(var/i=1 to slab_count)
		var/obj/item/reagent_containers/food/snacks/meat/new_meat = new slab_type(src)
		new_meat.name = "[slab_name] [new_meat.name]"
		new_meat.reagents.add_reagent("nutriment", slab_nutrition)


		if(occupant.reagents)
			occupant.reagents.trans_to(new_meat, round(occupant.reagents.total_volume/slab_count, 1))

	if(ishuman(occupant))
		var/mob/living/carbon/human/H = occupant
		var/skinned = H.dna.species.skinned_type
		if(skinned)
			new skinned(src)
	new /obj/effect/decal/cleanable/blood/gibs(src)

	if(!UserOverride)
		add_attack_logs(user, occupant, "Gibbed in [src]", !!occupant.ckey ? ATKLOG_FEW : ATKLOG_ALL)

	else //this looks ugly but it's better than a copy-pasted startgibbing proc override
		occupant.create_attack_log("Was gibbed by <b>an autogibber (\the [src])</b>")
		add_attack_logs(src, occupant, "gibbed")

	occupant.emote("scream")
	playsound(get_turf(src), 'sound/goonstation/effects/gib.ogg', 50, 1)
	victims += "\[[all_timestamps()]\] [key_name(occupant)] killed by [UserOverride ? "Autogibbing" : "[key_name(user)]"]" //have to do this before ghostizing
	if(!stealthmode && ishuman(occupant))
		var/mob/living/carbon/human/H = occupant
		for(var/obj/item/I in H.get_contents())
			if(I.resistance_flags & INDESTRUCTIBLE)
				I.forceMove(get_turf(src))
		if(H.get_item_by_slot(slot_s_store))
			var/obj/item/ws = H.get_item_by_slot(slot_s_store)
			if(ws.resistance_flags & INDESTRUCTIBLE)
				ws.forceMove(get_turf(src))
				H.s_store = null
		if(H.get_item_by_slot(slot_l_store))
			var/obj/item/ls = H.get_item_by_slot(slot_l_store)
			if(ls.resistance_flags & INDESTRUCTIBLE)
				ls.forceMove(get_turf(src))
				H.l_store = null
		if(H.get_item_by_slot(slot_r_store))
			var/obj/item/rs = H.get_item_by_slot(slot_r_store)
			if(rs.resistance_flags & INDESTRUCTIBLE)
				rs.forceMove(get_turf(src))
				H.r_store = null
	occupant.death(1)
	occupant.ghostize()

	QDEL_NULL(occupant)

	spawn(gibtime)
		playsound(get_turf(src), 'sound/effects/splat.ogg', 50, 1)

		if(stealthmode)
			for(var/atom/movable/AM in contents)
				qdel(AM)
				sleep(1)
		else
			for(var/obj/item/thing in contents) //Meat is spawned inside the gibber and thrown out afterwards.
				thing.loc = get_turf(thing) // Drop it onto the turf for throwing.
				thing.throw_at(get_edge_target_turf(src, gib_throw_dir), rand(1, 5), 15) // Being pelted with bits of meat and bone would hurt.
				sleep(1)

			for(var/obj/effect/gibs in contents) //throw out the gibs too
				gibs.loc = get_turf(gibs) //drop onto turf for throwing
				gibs.throw_at(get_edge_target_turf(src, gib_throw_dir), rand(1, 5), 15)
				sleep(1)

		pixel_x = initial(pixel_x) //return to it's spot after shaking
		operating = FALSE
		update_icon(UPDATE_OVERLAYS | UPDATE_ICON_STATE)



/* AUTOGIBBER */


//gibs anything that stands on it's input

/obj/machinery/gibber/autogibber
	var/acceptdir = NORTH
	var/lastacceptdir = NORTH
	var/turf/lturf
	var/consumption_delay = 3 SECONDS
	var/list/victim_targets = list()

/obj/machinery/gibber/autogibber/Initialize(mapload)
	. = ..()

	var/turf/T = get_step(src, acceptdir)
	if(istype(T))
		lturf = T

	component_parts = list()
	component_parts += new /obj/item/circuitboard/gibber(null)
	component_parts += new /obj/item/stock_parts/matter_bin(null)
	component_parts += new /obj/item/stock_parts/manipulator(null)
	RefreshParts()

/obj/machinery/gibber/autogibber/process()
	if(!lturf || occupant || locked || operating || victim_targets.len)
		return

	if(acceptdir != lastacceptdir)
		lturf = null
		lastacceptdir = acceptdir
		var/turf/T = get_step(src, acceptdir)
		if(istype(T))
			lturf = T

	for(var/mob/living/carbon/human/H in lturf)
		victim_targets += H

	if(victim_targets.len)
		visible_message({"<span class='danger'>\The [src] states, "Food detected!"</span>"})
		sleep(consumption_delay)
		for(var/mob/living/carbon/H in victim_targets)
			if(H.loc == lturf) //still standing there
				if(force_move_into_gibber(H))
					locked = TRUE // no escape
					ejectclothes(occupant)
					cleanbay()
					startgibbing(null, 1)
					locked = FALSE
			break
	victim_targets.Cut()

/obj/machinery/gibber/autogibber/proc/force_move_into_gibber(mob/living/carbon/human/victim)
	if(!istype(victim))	return 0
	visible_message("<span class='danger'>\The [victim.name] gets sucked into \the [src]!</span>")

	victim.forceMove(src)
	occupant = victim

	update_icon(UPDATE_OVERLAYS | UPDATE_ICON_STATE)
	feedinTopanim()
	return 1

/obj/machinery/gibber/autogibber/proc/ejectclothes(mob/living/carbon/human/H)
	if(!istype(H))	return 0
	if(H != occupant)	return 0 //only using H as a shortcut to typecast
	for(var/obj/O in H)
		if(isclothing(O)) //clothing gets skipped to avoid cleaning out shit
			continue
		if(istype(O,/obj/item/implant))
			var/obj/item/implant/I = O
			if(I.implanted)
				continue
		if(O.flags & NODROP || stealthmode)
			qdel(O) //they are already dead by now
		H.unEquip(O)
		O.loc = loc
		O.throw_at(get_edge_target_turf(src, gib_throw_dir), rand(1, 5), 15)
		sleep(1)

	for(var/obj/item/clothing/C in H)
		if(C.flags & NODROP || stealthmode)
			qdel(C)
		H.unEquip(C)
		C.loc = loc
		C.throw_at(get_edge_target_turf(src, gib_throw_dir), rand(1, 5), 15)
		sleep(1)

	visible_message("<span class='warning'>\The [src] spits out \the [H.name]'s possessions!")

/obj/machinery/gibber/autogibber/proc/cleanbay()
	var/spats = 0 //keeps track of how many items get spit out. Don't show a message if none are found.
	for(var/obj/O in src)
		if(stealthmode)
			qdel(O)
		else if(istype(O))
			O.loc = loc
			O.throw_at(get_edge_target_turf(src, gib_throw_dir), rand(1, 5), 15)
			spats++
			sleep(1)
	if(spats)
		visible_message("<span class='warning'>\The [src] spits out more possessions!</span>")
