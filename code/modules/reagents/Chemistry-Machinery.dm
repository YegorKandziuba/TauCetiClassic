#define MAX_PILL_SPRITE 24
#define MAX_BOTTLE_SPRITE 3

/*-------Если что, стукать @KandJX'a-------*/

/obj/machinery/chem_dispenser
	name = "chem dispenser"
	density = TRUE
	anchored = TRUE
	icon = 'icons/obj/chemical.dmi'
	icon_state = "dispenser"
	use_power = NO_POWER_USE
	idle_power_usage = 40
	var/ui_title = "Chem Dispenser 5000"
	var/energy = 100
	var/max_energy = 100
	var/amount = 30
	var/accept_glass = 0
	var/obj/item/weapon/reagent_containers/beaker = null
	var/recharged = 0
	var/recharge_delay = 15
	var/msg_hack_enable = ""
	var/msg_hack_disable = ""
	var/list/dispensable_reagents = list()
	var/list/dispensable_reagent_tiers = list(
		list(
		"aluminum","carbon","chlorine","copper","ethanol","fluorine","hydrogen","iron","lithium","mercury",
		"nitrogen","oxygen","phosphorus","potassium","radium","sacid","silicon","sodium","sugar","sulfur",
		"tungsten","water"),
		list("anti_toxin","inaprovaline"),
		list("ammonia","diethylamine"),
		list("bicaridine","kelotane","spaceacillin", "tricordrazine")

	),
	var/list/premium_reagents = list()
	var/list/premium_reagents_tiers = list(
	list("toxin"),
	list("fuel"),
	list("orangejuice", "limejuice", "tomatojuice", "cream"),
	list("mindbreaker")

	)
	var/list/standart_reagents_list = list()
	var/list/full_reagents_list = list()
	var/hacked = FALSE
	var/disabled = FALSE
	var/shocked = FALSE
	var/datum/wires/chem_dispenser/wires = null

/obj/machinery/chem_dispenser/atom_init()
	. = ..()
	component_parts = list()
	component_parts += new /obj/item/weapon/circuitboard/chem_dispenser_5000(null)
	component_parts += new /obj/item/weapon/stock_parts/matter_bin(null)
	component_parts += new /obj/item/weapon/stock_parts/matter_bin(null)
	component_parts += new /obj/item/weapon/stock_parts/manipulator(null)
	component_parts += new /obj/item/weapon/stock_parts/scanning_module(null)
	component_parts += new /obj/item/weapon/stock_parts/capacitor(null)
	component_parts += new /obj/item/weapon/stock_parts/console_screen(null)
	wires = new(src)
	RefreshParts()
	recharge()
//	dispensable_reagents = sortList(dispensable_reagents)

/obj/machinery/chem_dispenser/RefreshParts()
	var/time = 0
	var/temp_energy = 0
	var/i
	for(var/obj/item/weapon/stock_parts/matter_bin/M in component_parts)
		temp_energy += M.rating
	temp_energy -= 2
	max_energy = 100 + temp_energy * 25  //max energy = (bin1.rating + bin2.rating - 1) * 5, 5 on lowest 25 on highest
	for(var/obj/item/weapon/stock_parts/capacitor/C in component_parts)
		time += C.rating
	recharge_delay -= time   //delay between recharges, double the usual time on lowest 50% less than usual on highest
	for(var/obj/item/weapon/stock_parts/scanning_module/M in component_parts)
		for(i=1, i<=M.rating, i++)
			dispensable_reagents |= dispensable_reagent_tiers[i]
//	dispensable_reagents = sortList(dispensable_reagents)
	standart_reagents_list = dispensable_reagents
	for(var/obj/item/weapon/stock_parts/manipulator/M in component_parts)
		for(i=1, i<=M.rating, i++) premium_reagents |= premium_reagents_tiers[i]
			premium_reagents = sortList(premium_reagents)
	full_reagents_list = dispensable_reagents + premium_reagents


/obj/machinery/chem_dispenser/Destroy()
	QDEL_NULL(beaker)
	return ..()


/obj/machinery/chem_dispenser/proc/recharge()
	if(stat & (BROKEN|NOPOWER)) return
	var/addenergy = 1
	var/oldenergy = energy
	energy = min(energy + addenergy, max_energy)
	if(energy != oldenergy)
		use_power(2500) // This thing uses up alot of power (this is still low as shit for creating reagents from thin air)
		nanomanager.update_uis(src) // update all UIs attached to src

/obj/machinery/chem_dispenser/power_change()
	if(anchored && powered())
		stat &= ~NOPOWER
	else
		spawn(rand(0, 15))
			stat |= NOPOWER
			update_power_use()
	update_power_use()

/obj/machinery/chem_dispenser/process()
	if(recharged <= 0)
		recharge()
		recharged = recharge_delay
	else
		recharged -= 1

/obj/machinery/chem_dispenser/ex_act(severity)
	switch(severity)
		if(EXPLODE_HEAVY)
			if(prob(50))
				return
		if(EXPLODE_LIGHT)
			return
	qdel(src)

/obj/machinery/chem_dispenser/blob_act()
	if (prob(50))
		qdel(src)

/obj/machinery/chem_dispenser/ui_interact(mob/user)
	tgui_interact(user)

/obj/machinery/chem_dispenser/proc/shock(mob/user, prb)
	if(stat & (BROKEN|NOPOWER))		// unpowered, no shock
		return 0
	if(!prob(prb))
		return 0
	var/datum/effect/effect/system/spark_spread/s = new /datum/effect/effect/system/spark_spread
	s.set_up(5, 1, src)
	s.start()
	if(electrocute_mob(user, get_area(src), src, 0.7))
		return 1
	else
		return 0

/obj/machinery/chem_dispenser/tgui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "ChemDispenser", ui_title)
		ui.open()

/obj/machinery/chem_dispenser/tgui_status(mob/user)
	if(disabled)
		return STATUS_CLOSE
	return ..()

/obj/machinery/chem_dispenser/interact(mob/user)
	if(shocked && !issilicon(user) && !isobserver(user))
		shock(user,50)
	if(disabled)
		to_chat(user, "<span class='warning'>You press the button, but nothing happens.</span>")
		return
	..()

/obj/machinery/chem_dispenser/tgui_data(mob/user)
	var/list/data = list()
	data["amount"] = amount
	data["energy"] = energy
	data["maxEnergy"] = max_energy
	data["isBeakerLoaded"] = beaker ? 1 : 0
	data["glass"] = accept_glass
	var/list/beakerContents = list()
	var/beakerCurrentVolume = 0
	if(beaker?.reagents?.reagent_list.len)
		for(var/datum/reagent/R in beaker.reagents.reagent_list)
			beakerContents.Add(list(list("name" = R.name, "volume" = R.volume))) // list in a list because Byond merges the first list...
			beakerCurrentVolume += R.volume
	data["beakerContents"] = beakerContents

	if (beaker)
		data["beakerCurrentVolume"] = beakerCurrentVolume
		data["beakerMaxVolume"] = beaker.volume
	else
		data["beakerCurrentVolume"] = null
		data["beakerMaxVolume"] = null

	var/list/chemicals = list()
	for (var/re in dispensable_reagents)
		var/datum/reagent/temp = chemical_reagents_list[re]
		if(temp)
			chemicals.Add(list(list("title" = temp.name, "id" = temp.id))) // list in a list because Byond merges the first list...
	data["chemicals"] = chemicals
	return data

/obj/machinery/chem_dispenser/tgui_act(action, list/params, datum/tgui/ui, datum/tgui_state/state)
	if(..())
		return
	switch(action)
		if("change_amount")
			. = TRUE
			var/new_amount = clamp(round(text2num(params["new_amount"])), 0, 100)
			if(amount == new_amount)
				return

			amount = new_amount

			if(iscarbon(usr))
				playsound(src, 'sound/items/buttonswitch.ogg', VOL_EFFECTS_MISC, 20)

		if("dispense")
			. = TRUE
			if (!beaker || !dispensable_reagents.Find(params["chemical"]))
				return

			var/datum/reagents/R = beaker.reagents
			var/space = R.maximum_volume - R.total_volume

			if(iscarbon(usr))
				playsound(src, 'sound/items/buttonswitch.ogg', VOL_EFFECTS_MISC, 20)

			if ((space > 0) && (energy * 10 >= min(amount, space)))
				playsound(src, 'sound/effects/Liquid_transfer_mono.ogg', VOL_EFFECTS_MASTER, 40) // 15 isn't enough

			R.add_reagent(params["chemical"], min(amount, energy * 10, space))
			energy = max(energy - min(amount, energy * 10, space) / 10, 0)

		if("eject_beaker")
			. = TRUE
			if(!beaker)
				return

			beaker.forceMove(loc)
			beaker = null

			if(iscarbon(usr))
				playsound(src, 'sound/items/buttonswitch.ogg', VOL_EFFECTS_MISC, 20)

			playsound(src, 'sound/items/insert_key.ogg', VOL_EFFECTS_MASTER, 25)

/obj/machinery/chem_dispenser/attackby(obj/item/weapon/B, mob/user)
//	if(isrobot(user))
//		return
	if(default_unfasten_wrench(user, B))
		power_change()
		return

	if(src.beaker)
		to_chat(user, "Something is already loaded into the machine.")
		return
	if(istype(B, /obj/item/weapon/reagent_containers/glass) || istype(B, /obj/item/weapon/reagent_containers/food))
		if(!accept_glass && istype(B,/obj/item/weapon/reagent_containers/food))
			to_chat(user, "<span class='notice'>This machine only accepts beakers</span>")
			return
		if(istype(B, /obj/item/weapon/reagent_containers/food/drinks/cans))
			var/obj/item/weapon/reagent_containers/food/drinks/cans/C = B
			if(!C.canopened)
				to_chat(user, "<span class='notice'>You need to open the drink!</span>")
				return
		src.beaker =  B
		user.drop_from_inventory(B, src)
		to_chat(user, "You set [B] on the machine.")
		playsound(src, 'sound/items/insert_key.ogg', VOL_EFFECTS_MASTER, 25)
		return
	if(default_deconstruction_screwdriver(user, "dispenser-o", "dispenser", B))
		if(hacked) dispensable_reagents = full_reagents_list
		else dispensable_reagents = standart_reagents_list
		updateUsrDialog()
		return
	if(exchange_parts(user, B))
		return
	if(panel_open)
		if(is_wire_tool(B))
			wires.interact(user)
			return
		if(iscrowbar(B))
			if(beaker)
				var/obj/item/weapon/reagent_containers/glass/Beak = beaker
				Beak.loc = loc
				beaker = null
			default_deconstruction_crowbar(B)
			return 1


/obj/machinery/chem_dispenser/old/atom_init()
	. = ..()
	make_old()

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/obj/machinery/chem_dispenser/constructable
	name = "portable chem dispenser"
	icon = 'icons/obj/chemical.dmi'
	icon_state = "minidispenser"
	energy = 10
	max_energy = 10
	amount = 5
	recharge_delay = 30
	dispensable_reagents = list()
	dispensable_reagent_tiers = list(
		list(
				"hydrogen",
				"oxygen",
				"silicon",
				"phosphorus",
				"sulfur",
				"carbon",
				"nitrogen",
				"water"
		),
		list(
				"lithium",
				"sugar",
				"sacid",
				"copper",
				"mercury",
				"sodium"
		),
		list(
				"ethanol",
				"chlorine",
				"potassium",
				"aluminium",
				"radium",
				"fluorine",
				"iron",
				"fuel",
				"silver"
		),
		list(
				"ammonia",
				"diethylamine"
		)
	)

/obj/machinery/chem_dispenser/constructable/atom_init()
	component_parts = list()
	component_parts += new /obj/item/weapon/circuitboard/chem_dispenser(null)
	component_parts += new /obj/item/weapon/stock_parts/matter_bin(null)
	component_parts += new /obj/item/weapon/stock_parts/matter_bin(null)
	component_parts += new /obj/item/weapon/stock_parts/manipulator(null)
	component_parts += new /obj/item/weapon/stock_parts/capacitor(null)
	component_parts += new /obj/item/weapon/stock_parts/console_screen(null)
	component_parts += new /obj/item/weapon/stock_parts/cell/high(null)
	RefreshParts()

/obj/machinery/chem_dispenser/constructable/RefreshParts()
	var/time = 0
	var/temp_energy = 0
	var/i
	for(var/obj/item/weapon/stock_parts/matter_bin/M in component_parts)
		temp_energy += M.rating
	temp_energy--
	max_energy = temp_energy * 5  //max energy = (bin1.rating + bin2.rating - 1) * 5, 5 on lowest 25 on highest
	for(var/obj/item/weapon/stock_parts/capacitor/C in component_parts)
		time += C.rating
	for(var/obj/item/weapon/stock_parts/cell/P in component_parts)
		time += round(P.maxcharge, 10000) / 10000
	recharge_delay /= time/2         //delay between recharges, double the usual time on lowest 50% less than usual on highest
	for(var/obj/item/weapon/stock_parts/manipulator/M in component_parts)
		for(i=1, i<=M.rating, i++)
			dispensable_reagents |= dispensable_reagent_tiers[i]
	dispensable_reagents = sortList(dispensable_reagents)
	standart_reagents_list = dispensable_reagents

/obj/machinery/chem_dispenser/constructable/attackby(obj/item/I, mob/user)
	if(default_deconstruction_screwdriver(user, "minidispenser-o", "minidispenser", I))
		if(hacked) dispensable_reagents = full_reagents_list
		else dispensable_reagents = standart_reagents_list
		updateUsrDialog()
		return

	if(exchange_parts(user, I))
		return

	if(panel_open)
		if(is_wire_tool(I))
			wires.interact(user)
			return
		if(iscrowbar(I))
			if(beaker)
				var/obj/item/weapon/reagent_containers/glass/B = beaker
				B.loc = loc
				beaker = null
			default_deconstruction_crowbar(I)
			return 1

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/obj/machinery/chem_dispenser/soda
	icon_state = "soda_dispenser"
	name = "soda fountain"
	desc = "A drink fabricating machine, capable of producing many sugary drinks with just one touch."
	ui_title = "Soda Dispens-o-matic"
	energy = 100
	accept_glass = 1
	max_energy = 100
	dispensable_reagents = list("water","ice","coffee","cream","tea","icetea","cola","spacemountainwind","dr_gibb","space_up","tonic","sodawater","lemon_lime","sugar","orangejuice","limejuice","watermelonjuice")
	premium_reagents = list()
	premium_reagents_tiers = list(
		list("thirteenloko"),
		list("grapesoda"),
		list("tomatojuice"),
		list("milk")
	)
	msg_hack_enable = "You change the mode from 'McNano' to 'Pizza King'."
	msg_hack_disable = "You change the mode from 'Pizza King' to 'McNano'."

/obj/machinery/chem_dispenser/soda/atom_init()
	. = ..()
	component_parts = list()
	component_parts += new /obj/item/weapon/circuitboard/soda_dispenser(null)
	component_parts += new /obj/item/weapon/stock_parts/matter_bin(null)
	component_parts += new /obj/item/weapon/stock_parts/matter_bin(null)
	component_parts += new /obj/item/weapon/stock_parts/manipulator(null)
	component_parts += new /obj/item/weapon/stock_parts/capacitor(null)
	wires = new(src)
	RefreshParts()

/obj/machinery/chem_dispenser/soda/RefreshParts()
	. = ..()
	dispensable_reagents = list("water","ice","coffee","cream","tea","icetea","cola","spacemountainwind","dr_gibb","space_up","tonic","sodawater","lemon_lime","sugar","orangejuice","limejuice","watermelonjuice")
	standart_reagents_list = dispensable_reagents
	full_reagents_list = dispensable_reagents + premium_reagents

/obj/machinery/chem_dispenser/soda/attackby(obj/item/B, mob/user)
	if(default_unfasten_wrench(user, B))
		power_change()
		return
	if(src.beaker)
		to_chat(user, "Something is already loaded into the machine.")
		return
	if(istype(B, /obj/item/weapon/reagent_containers/glass) || istype(B, /obj/item/weapon/reagent_containers/food))
		if(!accept_glass && istype(B,/obj/item/weapon/reagent_containers/food))
			to_chat(user, "<span class='notice'>This machine only accepts beakers</span>")
			return
		if(istype(B, /obj/item/weapon/reagent_containers/food/drinks/cans))
			var/obj/item/weapon/reagent_containers/food/drinks/cans/C = B
			if(!C.canopened)
				to_chat(user, "<span class='notice'>You need to open the drink!</span>")
				return
		src.beaker =  B
		user.drop_from_inventory(B, src)
		to_chat(user, "You set [B] on the machine.")
		playsound(src, 'sound/items/insert_key.ogg', VOL_EFFECTS_MASTER, 25)
		return
	if(default_deconstruction_screwdriver(user, "soda_dispenser-o", "soda_dispenser", B))
		if(hacked) dispensable_reagents = full_reagents_list
		else dispensable_reagents = standart_reagents_list
		updateUsrDialog()
		return

	if(exchange_parts(user, B))
		return

	if(panel_open)
		if(is_wire_tool(B))
			wires.interact(user)
			return
		if(iscrowbar(B))
			if(beaker)
				var/obj/item/weapon/reagent_containers/glass/Beak = beaker
				Beak.loc = loc
				beaker = null
			default_deconstruction_crowbar(B)
			return 1


/obj/machinery/chem_dispenser/beer
	icon_state = "booze_dispenser"
	name = "booze dispenser"
	ui_title = "Booze Portal 9001"
	energy = 100
	accept_glass = 1
	max_energy = 100
	desc = "A technological marvel, supposedly able to mix just the mixture you'd like to drink the moment you ask for one."
	dispensable_reagents = list("lemon_lime","sugar","orangejuice","limejuice","sodawater","tonic","beer","kahlua","whiskey","wine","vodka","gin","rum","tequilla","vermouth","cognac","ale","mead")
	premium_reagents = list()
	premium_reagents_tiers = list(
		list("goldschlager"),
		list("patron"),
		list("watermelonjuice"),
		list("berryjuice")
	)
	msg_hack_enable = "You disable the 'nanotrasen-are-cheap-bastards' lock, enabling hidden and very expensive boozes."
	msg_hack_disable = "You re-enable the 'nanotrasen-are-cheap-bastards' lock, disabling hidden and very expensive boozes."

/obj/machinery/chem_dispenser/beer/atom_init()
	. = ..()
	component_parts = list()
	component_parts += new /obj/item/weapon/circuitboard/booze_dispenser(null)
	component_parts += new /obj/item/weapon/stock_parts/matter_bin(null)
	component_parts += new /obj/item/weapon/stock_parts/matter_bin(null)
	component_parts += new /obj/item/weapon/stock_parts/manipulator(null)
	component_parts += new /obj/item/weapon/stock_parts/capacitor(null)
	wires = new(src)
	RefreshParts()

/obj/machinery/chem_dispenser/beer/RefreshParts()
	. = ..()
	dispensable_reagents = list("lemon_lime","sugar","orangejuice","limejuice","sodawater","tonic","beer","kahlua","whiskey","wine","vodka","gin","rum","tequilla","vermouth","cognac","ale","mead")
	standart_reagents_list = dispensable_reagents
	full_reagents_list = dispensable_reagents + premium_reagents

/obj/machinery/chem_dispenser/beer/attackby(obj/item/B, mob/user)
	if(default_unfasten_wrench(user, B))
		power_change()
		return

	if(src.beaker)
		to_chat(user, "Something is already loaded into the machine.")
		return
	if(istype(B, /obj/item/weapon/reagent_containers/glass) || istype(B, /obj/item/weapon/reagent_containers/food))
		if(!accept_glass && istype(B,/obj/item/weapon/reagent_containers/food))
			to_chat(user, "<span class='notice'>This machine only accepts beakers</span>")
			return
		if(istype(B, /obj/item/weapon/reagent_containers/food/drinks/cans))
			var/obj/item/weapon/reagent_containers/food/drinks/cans/C = B
			if(!C.canopened)
				to_chat(user, "<span class='notice'>You need to open the drink!</span>")
				return
		src.beaker =  B
		user.drop_from_inventory(B, src)
		to_chat(user, "You set [B] on the machine.")
		playsound(src, 'sound/items/insert_key.ogg', VOL_EFFECTS_MASTER, 25)
		return
	if(default_deconstruction_screwdriver(user, "booze_dispenser-o", "booze_dispenser", B))
		if(hacked) dispensable_reagents = full_reagents_list
		else dispensable_reagents = standart_reagents_list
		updateUsrDialog()
		return

	if(exchange_parts(user, B))
		return

	if(panel_open)
		if(is_wire_tool(B))
			wires.interact(user)
			return
		if(iscrowbar(B))
			if(beaker)
				var/obj/item/weapon/reagent_containers/glass/Beak = beaker
				Beak.loc = loc
				beaker = null
			default_deconstruction_crowbar(B)
			return 1


//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/obj/machinery/chem_master
	name = "ChemMaster 3000"
	density = TRUE
	anchored = TRUE
	icon = 'icons/obj/chemical.dmi'
	icon_state = "mixer0"
	use_power = IDLE_POWER_USE
	idle_power_usage = 20
	var/obj/item/weapon/reagent_containers/glass/beaker = null
	var/obj/item/weapon/storage/pill_bottle/loaded_pill_bottle = null
	var/mode = 1
	var/condi = 0
	var/useramount = 30 // Last used amount
	var/pillamount = 10
	var/bottlesprite = 1
	var/pillsprite = 1
	var/client/has_sprites = list()
	var/max_pill_count = 24


/obj/machinery/chem_master/atom_init()
	. = ..()
	var/datum/reagents/R = new/datum/reagents(100)
	reagents = R
	R.my_atom = src

/obj/machinery/chem_master/ex_act(severity)
	switch(severity)
		if(EXPLODE_HEAVY)
			if(prob(50))
				return
		if(EXPLODE_LIGHT)
			return
	qdel(src)

/obj/machinery/chem_master/blob_act()
	if (prob(50))
		qdel(src)

/obj/machinery/chem_master/power_change()
	if(anchored && powered())
		stat &= ~NOPOWER
	else
		spawn(rand(0, 15))
			stat |= NOPOWER
			update_power_use()
	update_power_use()

/obj/machinery/chem_master/attackby(obj/item/B, mob/user)

	if(default_unfasten_wrench(user, B))
		power_change()
		return

	if(istype(B, /obj/item/weapon/reagent_containers/glass))
		if(src.beaker)
			to_chat(user, "<span class='alert'>A beaker is already loaded into the machine.</span>")
			return
		src.beaker = B
		user.drop_from_inventory(B, src)
		to_chat(user, "You add the beaker to the machine!")
		updateUsrDialog()
		icon_state = "mixer1"

	else if(!condi && istype(B, /obj/item/weapon/storage/pill_bottle))
		if(src.loaded_pill_bottle)
			to_chat(user, "<span class='alert'>A pill bottle is already loaded into the machine.</span>")
			return

		src.loaded_pill_bottle = B
		user.drop_from_inventory(B, src)
		to_chat(user, "You add the pill bottle into the dispenser slot!")
		updateUsrDialog()

	return

/obj/machinery/chem_master/Topic(href, href_list)
	. = ..()
	if(!.)
		return
	if(href_list["ejectp"])
		if(loaded_pill_bottle)
			loaded_pill_bottle.loc = src.loc
			loaded_pill_bottle = null

	else if(href_list["toggle"])
		mode = !mode

	else if(href_list["createbottle"])
		if(!condi)
			var/name = sanitize_safe(input(usr, "Name:","Name your bottle!", (reagents.total_volume ? reagents.get_master_reagent_name() : " ")) as text|null, MAX_NAME_LEN)
			if(!name)
				return FALSE
			var/obj/item/weapon/reagent_containers/glass/bottle/P = new/obj/item/weapon/reagent_containers/glass/bottle(src.loc)
			P.name = "[name] bottle"
			P.icon_state = "bottle[bottlesprite]"
			P.pixel_x = rand(-7, 7) //random position
			P.pixel_y = rand(-7, 7)
			reagents.trans_to(P, 30)
		else
			var/obj/item/weapon/reagent_containers/food/condiment/P = new/obj/item/weapon/reagent_containers/food/condiment(src.loc)
			reagents.trans_to(P, 50)

	else if(href_list["changepill"])
		var/dat = "<B>Choose pill colour</B><BR>"

		dat += "<TABLE><TR>"
		for(var/i = 1 to MAX_PILL_SPRITE)
			if(!((i-1)%9)) //New row every 9 icons
				dat +="</TR><TR>"
			dat += "<TD><A href='?src=\ref[src];set=1;value=[i] '><IMG src=pill[i].png></A></TD>"
		dat += "</TR></TABLE>"

		dat += "<BR><A href='?src=\ref[src];main=1'>Back</A>"

		var/datum/browser/popup = new(usr, "chem_master", name)
		popup.set_content(dat)
		popup.open()
		return

	else if(href_list["changebottle"])
		var/dat = "<B>Choose bottle</B><BR>"

		dat += "<TABLE><TR>"
		for(var/i = 1 to MAX_BOTTLE_SPRITE)
			if(!((i-1)%9)) //New row every 9 icons
				dat += "</TR><TR>"
			dat += "<TD><A href='?src=\ref[src];set=2;value=[i] '><IMG src=bottle[i].png></A></TD>"

		dat += "</TR></TABLE>"

		dat += "<BR><A href='?src=\ref[src];main=1'>Back</A>"

		var/datum/browser/popup = new(usr, "chem_master", name)
		popup.set_content(dat)
		popup.open()
		return

	else if(href_list["set"])
		if(href_list["value"])
			if(href_list["set"] == "1")
				src.pillsprite = text2num(href_list["value"])
			else
				src.bottlesprite = text2num(href_list["value"])
		attack_hand(usr)
		return

	else if(href_list["main"]) // Used to exit the analyze screen.
		attack_hand(usr)
		return

	if(beaker)
		if(href_list["analyze"])
			if(locate(href_list["reagent"]))
				var/datum/reagent/R = locate(href_list["reagent"])
				if(R)
					var/dat = ""
					dat += "<H1>[condi ? "Condiment" : "Chemical"] information:</H1>"
					dat += "<B>Name:</B> [initial(R.name)]<BR><BR>"
					dat += "<B>State:</B> "
					if(initial(R.reagent_state) == 1)
						dat += "Solid"
					else if(initial(R.reagent_state) == 2)
						dat += "Liquid"
					else if(initial(R.reagent_state) == 3)
						dat += "Gas"
					else
						dat += "Unknown"
					dat += "<BR>"
					dat += "<B>Color:</B> <span style='color:[initial(R.color)];background-color:[initial(R.color)];font:Lucida Console'>[initial(R.color)]</span><BR><BR>"
					dat += "<B>Description:</B> [initial(R.description)]<BR><BR>"
					if(initial(R.name) == "Blood")
						var/datum/reagent/blood/G = R
						var/A = G.data["blood_type"]
						var/B = G.data["blood_DNA"]
						dat += "<B>Blood Type:</B> [A]<br>"
						dat += "<B>DNA:</B> [B]<BR><BR><BR>"
					var/const/P = 3 //The number of seconds between life ticks
					var/T = initial(R.custom_metabolism) * (60 / P)
					dat += "<B>Metabolization Rate:</B> [T]u/minute<BR>"
					dat += "<B>Overdose Threshold:</B> [initial(R.overdose) ? "[initial(R.overdose)]u" : "none"]<BR>"
					//dat += "<B>Addiction Threshold:</B> [initial(R.addiction_threshold) ? "[initial(R.addiction_threshold)]u" : "none"]<BR><BR>"
					dat += "<BR><A href='?src=\ref[src];main=1'>Back</A>"
					var/datum/browser/popup = new(usr, "chem_master", name)
					popup.set_content(dat)
					popup.open()
					return


		else if(href_list["add"])
			if(href_list["amount"])
				var/id = href_list["add"]
				var/amount = text2num(href_list["amount"])
				if (amount > 0)
					beaker.reagents.trans_id_to(src, id, amount)

		else if(href_list["addcustom"])
			var/id = href_list["addcustom"]
			var/amt_temp = isgoodnumber(input(usr, "Select the amount to transfer.", "Transfer how much?", useramount) as num|null)
			if(!amt_temp)
				return FALSE
			useramount = amt_temp
			if(useramount < 0)
				message_admins("[key_name_admin(usr)] tried to exploit a chemistry by entering a negative value: [useramount]</a>! [ADMIN_JMP(src)]")
				log_admin("EXPLOIT : [key_name(usr)] tried to exploit a chemistry by entering a negative value: [useramount] !")
				return FALSE
			if(useramount > 300)
				return FALSE
			Topic(null, list("amount" = "[useramount]", "add" = "[id]"))

		else if(href_list["remove"])
			if(href_list["amount"])
				var/id = href_list["remove"]
				var/amount = text2num(href_list["amount"])
				if (amount > 0)
					if(mode)
						reagents.trans_id_to(beaker, id, amount)
					else
						reagents.remove_reagent(id, amount)

		else if(href_list["removecustom"])
			var/id = href_list["removecustom"]
			var/amt_temp = isgoodnumber(input(usr, "Select the amount to transfer.", "Transfer how much?", useramount) as num|null)
			if(!amt_temp)
				return FALSE
			useramount = amt_temp
			if(useramount < 0)
				message_admins("[key_name_admin(usr)] tried to exploit a chemistry by entering a negative value: [useramount]</a>! [ADMIN_JMP(src)]")
				log_admin("EXPLOIT : [key_name(usr)] tried to exploit a chemistry by entering a negative value: [useramount] !")
				return FALSE
			if(useramount > 300)
				return FALSE
			Topic(null, list("amount" = "[useramount]", "remove" = "[id]"))

		else if(href_list["eject"])
			if(beaker)
				beaker.loc = src.loc
				beaker = null
				reagents.clear_reagents()
				icon_state = "mixer0"

		else if(href_list["createpill"]) //Also used for condiment packs.
			if(reagents.total_volume == 0)
				return FALSE
			if(!condi)
				var/amount = 1
				var/vol_each = min(reagents.total_volume, 50)
				if(text2num(href_list["many"]))
					amount = min(max(round(input(usr, "Max 10. Buffer content will be split evenly.", "How many pills?", amount) as num|null), 0), 10)
					if(!amount)
						return FALSE
					vol_each = min(reagents.total_volume / amount, 50)
				var/name = sanitize_safe(input(usr,"Name:","Name your pill!", "[reagents.get_master_reagent_name()] ([vol_each]u)") as text|null, MAX_NAME_LEN)
				if(!name || !reagents.total_volume)
					return FALSE
				var/obj/item/weapon/reagent_containers/pill/P

				for(var/i = 0; i < amount; i++)
					if(loaded_pill_bottle && loaded_pill_bottle.contents.len < loaded_pill_bottle.storage_slots)
						P = new/obj/item/weapon/reagent_containers/pill(loaded_pill_bottle)
					else
						P = new/obj/item/weapon/reagent_containers/pill(src.loc)
					P.name = "[name] pill"
					P.icon_state = "pill[pillsprite]"
					P.pixel_x = rand(-7, 7) //random position
					P.pixel_y = rand(-7, 7)
					reagents.trans_to(P,vol_each)

	updateUsrDialog()

/obj/machinery/chem_master/ui_interact(mob/user)
	if(!(user.client in has_sprites))
		spawn()
			has_sprites += user.client
			for(var/i = 1 to MAX_PILL_SPRITE)
				usr << browse_rsc(icon('icons/obj/chemical.dmi', "pill[i]"), "pill[i].png")
			for(var/i = 1 to MAX_BOTTLE_SPRITE)
				usr << browse_rsc(icon('icons/obj/chemical.dmi', "bottle[i]"), "bottle[i].png")
			updateUsrDialog()

	var/dat = ""
	if(beaker)
		dat += "Beaker \[[beaker.reagents.total_volume]/[beaker.volume]\] <A href='?src=\ref[src];eject=1'>Eject and Clear Buffer</A><BR>"
	else
		dat = "Please insert beaker.<BR>"

	dat += "<HR><B>Add to buffer:</B><UL>"
	if(beaker)
		if(beaker.reagents.total_volume)
			for(var/datum/reagent/G in beaker.reagents.reagent_list)
				dat += "<LI>[G.name], [G.volume] Units - "
				dat += "<A href='?src=\ref[src];analyze=1;reagent=\ref[G]'>Analyze</A> "
				dat += "<A href='?src=\ref[src];add=[G.id];amount=1'>1</A> "
				dat += "<A href='?src=\ref[src];add=[G.id];amount=5'>5</A> "
				dat += "<A href='?src=\ref[src];add=[G.id];amount=10'>10</A> "
				dat += "<A href='?src=\ref[src];add=[G.id];amount=[G.volume]'>All</A> "
				dat += "<A href='?src=\ref[src];addcustom=[G.id]'>Custom</A>"
		else
			dat += "<LI>Beaker is empty."
	else
		dat += "<LI>No beaker."

	dat += "</UL><HR><B>Transfer to <A href='?src=\ref[src];toggle=1'>[(!mode ? "disposal" : "beaker")]</A>:</B><UL>"
	if(reagents.total_volume)
		for(var/datum/reagent/N in reagents.reagent_list)
			dat += "<LI>[N.name], [N.volume] Units - "
			dat += "<A href='?src=\ref[src];analyze=1;reagent=\ref[N]'>Analyze</A> "
			dat += "<A href='?src=\ref[src];remove=[N.id];amount=1'>1</A> "
			dat += "<A href='?src=\ref[src];remove=[N.id];amount=5'>5</A> "
			dat += "<A href='?src=\ref[src];remove=[N.id];amount=10'>10</A> "
			dat += "<A href='?src=\ref[src];remove=[N.id];amount=[N.volume]'>All</A> "
			dat += "<A href='?src=\ref[src];removecustom=[N.id]'>Custom</A>"
	else
		dat += "<LI>Buffer is empty."
	dat += "</UL><HR>"


	dat += "<A href='?src=\ref[src];changepill=1'><img src='pill[src.pillsprite].png'></A>"
	dat += "<A href='?src=\ref[src];changebottle=1'><img src='bottle[src.bottlesprite].png'></A>"


	dat += "<HR>"
	if(!condi)
		if(src.loaded_pill_bottle)
			dat += "Pill Bottle \[[loaded_pill_bottle.contents.len]/[loaded_pill_bottle.storage_slots]\] <A href='?src=\ref[src];ejectp=1'>Eject</A>"
		else
			dat += "No pill bottle inserted."
	else
		dat += "<BR>"

	dat += "<UL>"
	if(!condi)
		if(beaker && reagents.total_volume)
			dat += "<LI><A href='?src=\ref[src];createpill=1;many=0'>Create pill</A> (50 units max)"
			dat += "<LI><A href='?src=\ref[src];createpill=1;many=1'>Create multiple pills</A><BR>"
		else
			dat += "<LI><span class='disabled'>Create pill</span> (50 units max)"
			dat += "<LI><span class='disabled'>Create multiple pills</span><BR>"
	else
		if(beaker && reagents.total_volume)
			dat += "<LI><A href='?src=\ref[src];createpill=1'>Create pack</A> (10 units max)<BR>"
		else
			dat += "<LI><span class='disabled'>Create pack</span> (10 units max)<BR>"
	dat += "<LI><A href='?src=\ref[src];createbottle=1'>Create bottle</A> ([condi ? "50" : "30"] units max)"
	dat += "</UL>"

	var/datum/browser/popup = new(user, "chem_master", name, 470, 500)
	popup.set_content(dat)
	popup.open()

/obj/machinery/chem_master/proc/isgoodnumber(num)
	if(isnum(num))
		return clamp(round(num), 0, 200)
	else
		return 0


/obj/machinery/chem_master/condimaster
	name = "CondiMaster 3000"
	condi = 1

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/obj/machinery/chem_master/constructable
	name = "ChemMaster 2999"
	desc = "Used to seperate chemicals and distribute them in a variety of forms."

/obj/machinery/chem_master/constructable/atom_init()
	. = ..()
	component_parts = list()
	component_parts += new /obj/item/weapon/circuitboard/chem_master(null)
	component_parts += new /obj/item/weapon/stock_parts/manipulator(null)
	component_parts += new /obj/item/weapon/stock_parts/console_screen(null)
	component_parts += new /obj/item/weapon/reagent_containers/glass/beaker(null)
	component_parts += new /obj/item/weapon/reagent_containers/glass/beaker(null)

/obj/machinery/chem_master/constructable/attackby(obj/item/B, mob/user, params)

	if(default_deconstruction_screwdriver(user, "mixer0_nopower", "mixer0_", B))
		if(beaker)
			beaker.loc = src.loc
			beaker = null
			reagents.clear_reagents()
		if(loaded_pill_bottle)
			loaded_pill_bottle.loc = src.loc
			loaded_pill_bottle = null
		return

	if(exchange_parts(user, B))
		return

	if(panel_open)
		if(iscrowbar(B))
			default_deconstruction_crowbar(B)
			return 1
		else
			to_chat(user, "<span class='warning'>You can't use the [src.name] while it's panel is opened.</span>")
			return 1

	if(istype(B, /obj/item/weapon/reagent_containers/glass))
		if(src.beaker)
			to_chat(user, "<span class='alert'>A beaker is already loaded into the machine.</span>")
			return
		src.beaker = B
		user.drop_from_inventory(B, src)
		to_chat(user, "You add the beaker to the machine!")
		updateUsrDialog()
		icon_state = "mixer1"

	else if(!condi && istype(B, /obj/item/weapon/storage/pill_bottle))
		if(src.loaded_pill_bottle)
			to_chat(user, "<span class='alert'>A pill bottle is already loaded into the machine.</span>")
			return
		src.loaded_pill_bottle = B
		user.drop_from_inventory(B, src)
		to_chat(user, "You add the pill bottle into the dispenser slot!")
		updateUsrDialog()

	return

////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////

/obj/machinery/computer/pandemic
	name = "PanD.E.M.I.C 2200"
	density = TRUE
	anchored = TRUE
	icon = 'icons/obj/chemical.dmi'
	icon_state = "mixer0"
	circuit = /obj/item/weapon/circuitboard/pandemic
	//use_power = IDLE_POWER_USE
	//idle_power_usage = 20		//defaults make more sense.
	var/temphtml = ""
	var/wait = null
	var/obj/item/weapon/reagent_containers/glass/beaker = null


/obj/machinery/computer/pandemic/set_broken()
	icon_state = (src.beaker?"mixer1_b":"mixer0_b")
	stat |= BROKEN


/obj/machinery/computer/pandemic/power_change()

	if(stat & BROKEN)
		icon_state = (src.beaker?"mixer1_b":"mixer0_b")

	else if(powered())
		icon_state = (src.beaker?"mixer1":"mixer0")
		stat &= ~NOPOWER

	else
		spawn(rand(0, 15))
			src.icon_state = (src.beaker?"mixer1_nopower":"mixer0_nopower")
			stat |= NOPOWER
			update_power_use()
	update_power_use()


/obj/machinery/computer/pandemic/Topic(href, href_list)
	. = ..()
	if(!.)
		return

	if(!beaker)
		return FALSE

	if (href_list["create_vaccine"])
		if(!src.wait)
			var/obj/item/weapon/reagent_containers/glass/bottle/B = new/obj/item/weapon/reagent_containers/glass/bottle(src.loc)
			if(B)
				var/path = href_list["create_vaccine"]
				var/vaccine_type = text2path(path)
				var/datum/disease/D = null

				if(!vaccine_type)
					D = archive_diseases[path]
					vaccine_type = path
				else
					if(vaccine_type in diseases)
						D = new vaccine_type(0, null)

				if(D)
					B.name = "[D.name] vaccine bottle"
					B.reagents.add_reagent("vaccine", 15, vaccine_type)
					wait = 1
					var/datum/reagents/R = beaker.reagents
					var/datum/reagent/blood/Blood = null
					for(var/datum/reagent/blood/L in R.reagent_list)
						if(L)
							Blood = L
							break
					var/list/res = Blood.data["resistances"]
					if(res)
						VARSET_IN(src, wait, null, res.len * 200)
					else
						wait = null
		else
			src.temphtml = "The replicator is not ready yet."
	else if (href_list["create_virus_culture"])
		if(!wait)
			var/obj/item/weapon/reagent_containers/glass/bottle/B = new/obj/item/weapon/reagent_containers/glass/bottle(src.loc)
			B.icon_state = "bottle3"
			var/type = text2path(href_list["create_virus_culture"])//the path is received as string - converting
			var/datum/disease/D = null
			if(!type)
				var/datum/disease/advance/A = archive_diseases[href_list["create_virus_culture"]]
				if(A)
					D = new A.type(0, A)
			else
				if(type in diseases) // Make sure this is a disease
					D = new type(0, null)
			var/list/data = list("viruses"=list(D))
			var/name = sanitize_safe(input(usr,"Name:","Name the culture",input_default(D.name)) as text|null, MAX_NAME_LEN)
			if(!name || name == " ") name = D.name
			B.name = "[name] culture bottle"
			B.desc = "A small bottle. Contains [D.agent] culture in synthblood medium."
			B.reagents.add_reagent("blood", 20, data)
			updateUsrDialog()
			wait = 1
			VARSET_IN(src, wait, null, 1000)
		else
			src.temphtml = "The replicator is not ready yet."
	else if (href_list["empty_beaker"])
		beaker.reagents.clear_reagents()
	else if (href_list["eject"])
		beaker.loc = src.loc
		beaker = null
		icon_state = "mixer0"
	else if(href_list["clear"])
		src.temphtml = ""
	else if(href_list["name_disease"])
		if(stat & (NOPOWER|BROKEN))
			return
		var/new_name = sanitize_safe(input(usr, "Name the Disease", "New Name") as text|null, MAX_NAME_LEN)
		if(!new_name)
			return
		if(usr.incapacitated())
			return
		if(!Adjacent(usr))
			return
		var/id = href_list["name_disease"]
		if(archive_diseases[id])
			var/datum/disease/advance/A = archive_diseases[id]
			A.AssignName(new_name)
			for(var/datum/disease/advance/AD in SSdiseases.processing)
				AD.Refresh()
	else
		usr << browse(null, "window=pandemic")
		return FALSE

	updateUsrDialog()


/obj/machinery/computer/pandemic/ui_interact(mob/user)
	var/dat = ""
	if(src.temphtml)
		dat = "[src.temphtml]<BR><BR><A href='?src=\ref[src];clear=1'>Main Menu</A>"
	else if(!beaker)
		dat += "Please insert beaker.<BR>"
	else
		var/datum/reagents/R = beaker.reagents
		var/datum/reagent/blood/Blood = null
		for(var/datum/reagent/blood/B in R.reagent_list)
			if(B)
				Blood = B
				break
		if(!R.total_volume||!R.reagent_list.len)
			dat += "The beaker is empty<BR>"
		else if(!Blood)
			dat += "No blood sample found in beaker"
		else if(!Blood.data)
			dat += "No blood data found in beaker."
		else
			dat += "<h3>Blood sample data:</h3>"
			dat += "<b>Blood DNA:</b> [(Blood.data["blood_DNA"]||"none")]<BR>"
			dat += "<b>Blood Type:</b> [(Blood.data["blood_type"]||"none")]<BR>"


			if(Blood.data["viruses"])
				var/list/vir = Blood.data["viruses"]
				if(vir.len)
					for(var/datum/disease/D in vir)
						if(!D.hidden[PANDEMIC])


							var/disease_creation = D.type
							if(istype(D, /datum/disease/advance))

								var/datum/disease/advance/A = D
								D = archive_diseases[A.GetDiseaseID()]
								disease_creation = A.GetDiseaseID()
								if(D.name == "Unknown")
									dat += "<b><a href='?src=\ref[src];name_disease=[A.GetDiseaseID()]'>Name Disease</a></b><BR>"

							if(!D)
								CRASH("We weren't able to get the advance disease from the archive.")

							dat += "<b>Disease Agent:</b> [D?"[D.agent] - <A href='?src=\ref[src];create_virus_culture=[disease_creation]'>Create virus culture bottle</A>":"none"]<BR>"
							dat += "<b>Common name:</b> [(D.name||"none")]<BR>"
							dat += "<b>Description: </b> [(D.desc||"none")]<BR>"
							dat += "<b>Spread:</b> [(D.spread||"none")]<BR>"
							dat += "<b>Possible cure:</b> [(D.cure||"none")]<BR><BR>"

							if(istype(D, /datum/disease/advance))
								var/datum/disease/advance/A = D
								dat += "<b>Symptoms:</b> "
								var/english_symptoms = list()
								for(var/datum/symptom/S in A.symptoms)
									english_symptoms += S.name
								dat += get_english_list(english_symptoms)


			dat += "<BR><b>Contains antibodies to:</b> "
			if(Blood.data["resistances"])
				var/list/res = Blood.data["resistances"]
				if(res.len)
					dat += "<ul>"
					for(var/type in Blood.data["resistances"])
						var/disease_name = "Unknown"

						if(!ispath(type))
							var/datum/disease/advance/A = archive_diseases[type]
							if(A)
								disease_name = A.name
						else
							var/datum/disease/D = new type(0, null)
							disease_name = D.name

						dat += "<li>[disease_name] - <A href='?src=\ref[src];create_vaccine=[type]'>Create vaccine bottle</A></li>"
					dat += "</ul><BR>"
				else
					dat += "nothing<BR>"
			else
				dat += "nothing<BR>"
		dat += "<BR><A href='?src=\ref[src];eject=1'>Eject beaker</A>[((R.total_volume&&R.reagent_list.len) ? "-- <A href='?src=\ref[src];empty_beaker=1'>Empty beaker</A>":"")]<BR>"

	var/datum/browser/popup = new(user, "pandemic", src.name, 575, 400)
	popup.set_content(dat)
	popup.open()


/obj/machinery/computer/pandemic/attackby(obj/I, mob/user)
	if(istype(I, /obj/item/weapon/reagent_containers/glass))
		if(stat & (NOPOWER|BROKEN)) return
		if(src.beaker)
			to_chat(user, "A beaker is already loaded into the machine.")
			return

		src.beaker =  I
		user.drop_from_inventory(I, src)
		to_chat(user, "You add the beaker to the machine!")
		updateUsrDialog()
		icon_state = "mixer1"

	else if(isscrewdriver(I))
		if(src.beaker)
			beaker.loc = get_turf(src)
		..()
		return

	else
		..()
	return
////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////
/obj/machinery/reagentgrinder

	name = "All-In-One Grinder"
	icon = 'icons/obj/kitchen.dmi'
	icon_state = "juicer1"
	layer = 2.9
	density = TRUE
	anchored = TRUE
	use_power = IDLE_POWER_USE
	idle_power_usage = 5
	active_power_usage = 100
	pass_flags = PASSTABLE
	var/inuse = 0
	var/obj/item/weapon/reagent_containers/beaker = null
	var/limit = 10
	var/list/blend_items = list (
		//Sheets,
		/obj/item/stack/sheet/mineral/phoron = list("phoron" = 20),
		/obj/item/stack/sheet/mineral/uranium = list("uranium" = 20),
		/obj/item/stack/sheet/mineral/clown = list("banana" = 20),
		/obj/item/stack/sheet/mineral/silver = list("silver" = 20),
		/obj/item/stack/sheet/mineral/gold = list("gold" = 20),
		/obj/item/weapon/grown/nettle = list("sacid" = 0),
		/obj/item/weapon/grown/deathnettle = list("pacid" = 0),

		//Blender Stuff,
		/obj/item/weapon/reagent_containers/food/snacks/grown/soybeans = list("soymilk" = 0),
		/obj/item/weapon/reagent_containers/food/snacks/grown/tomato = list("ketchup" = 0),
		/obj/item/weapon/reagent_containers/food/snacks/grown/corn = list("cornoil" = 0),
		///obj/item/weapon/reagent_containers/food/snacks/grown/wheat = list("flour" = -5),
		/obj/item/weapon/reagent_containers/food/snacks/grown/ricestalk = list("rice" = -5),
		/obj/item/weapon/reagent_containers/food/snacks/grown/cherries = list("cherryjelly" = 0),
		/obj/item/weapon/reagent_containers/food/snacks/grown/plastellium = list("plasticide" = 5),
		/obj/item/weapon/reagent_containers/food/snacks/egg = list("egg" = -5),


		//archaeology,
		/obj/item/weapon/rocksliver = list("ground_rock" = 50),



		//All types that you can put into the grinder to transfer the reagents to the beaker. !Put all recipes above this!,
		/obj/item/weapon/reagent_containers/pill = list(),
		/obj/item/weapon/reagent_containers/food = list(),
		/obj/item/weapon/coin = list()
	)

	var/list/juice_items = list (

		//Juicer Stuff,
		/obj/item/weapon/reagent_containers/food/snacks/grown/tomato = list("tomatojuice" = 0),
		/obj/item/weapon/reagent_containers/food/snacks/grown/carrot = list("carrotjuice" = 0),
		/obj/item/weapon/reagent_containers/food/snacks/grown/berries = list("berryjuice" = 0),
		/obj/item/weapon/reagent_containers/food/snacks/grown/banana = list("banana" = 0),
		/obj/item/weapon/reagent_containers/food/snacks/grown/potato = list("potato" = 0),
		/obj/item/weapon/reagent_containers/food/snacks/grown/lemon = list("lemonjuice" = 0),
		/obj/item/weapon/reagent_containers/food/snacks/grown/orange = list("orangejuice" = 0),
		/obj/item/weapon/reagent_containers/food/snacks/grown/lime = list("limejuice" = 0),
		/obj/item/weapon/reagent_containers/food/snacks/watermelonslice = list("watermelonjuice" = 0),
		/obj/item/weapon/reagent_containers/food/snacks/grown/poisonberries = list("poisonberryjuice" = 0),
		/obj/item/weapon/reagent_containers/food/snacks/grown/greengrapes = list("grapejuice" = 0),
		/obj/item/weapon/reagent_containers/food/snacks/grown/grapes = list("grapejuice" = 0),
	)


	var/list/holdingitems = list()

/obj/machinery/reagentgrinder/atom_init()
	. = ..()
	beaker = new /obj/item/weapon/reagent_containers/glass/beaker/large(src)

/obj/machinery/reagentgrinder/update_icon()
	icon_state = "juicer"+num2text(!isnull(beaker))
	return


/obj/machinery/reagentgrinder/attackby(obj/item/O, mob/user)

	if(iswrench(O))
		default_unfasten_wrench(user, O)
		return

	if (istype(O,/obj/item/weapon/reagent_containers/glass) || \
		istype(O,/obj/item/weapon/reagent_containers/food/drinks/drinkingglass) || \
		istype(O,/obj/item/weapon/reagent_containers/food/drinks/shaker))

		if (beaker)
			return 1
		else
			src.beaker =  O
			user.drop_from_inventory(O, src)
			update_icon()
			updateUsrDialog()
			return 0

	if(holdingitems && holdingitems.len >= limit)
		to_chat(usr, "The machine cannot hold anymore items.")
		return 1

	//Fill machine with the plantbag!
	if(istype(O, /obj/item/weapon/storage/bag/plants))

		var/obj/item/weapon/storage/bag/plants/P = O
		for (var/obj/item/weapon/reagent_containers/food/snacks/grown/G in O.contents)
			P.remove_from_storage(G, src)
			holdingitems += G
			if(holdingitems && holdingitems.len >= limit) //Sanity checking so the blender doesn't overfill
				to_chat(user, "You fill the All-In-One grinder to the brim.")
				break

		if(!O.contents.len)
			to_chat(user, "You empty the plant bag into the All-In-One grinder.")

		updateUsrDialog()
		return 0

	if (!is_type_in_list(O, blend_items) && !is_type_in_list(O, juice_items))
		to_chat(user, "Cannot refine into a reagent.")
		return 1

	user.drop_from_inventory(O, src)
	holdingitems += O
	updateUsrDialog()
	return 0

/obj/machinery/reagentgrinder/attack_ai(mob/user)
	if(IsAdminGhost(user))
		return ..()
	return 0

/obj/machinery/reagentgrinder/ui_interact(mob/user) // The microwave Menu
	var/is_chamber_empty = 0
	var/is_beaker_ready = 0
	var/processing_chamber = ""
	var/beaker_contents = ""
	var/dat = ""

	if(!inuse)
		for (var/obj/item/O in holdingitems)
			processing_chamber += "\A [O.name]<BR>"

		if (!processing_chamber)
			is_chamber_empty = 1
			processing_chamber = "Nothing."
		if (!beaker)
			beaker_contents = "<B>No beaker attached.</B><br>"
		else
			is_beaker_ready = 1
			beaker_contents = "<B>The beaker contains:</B><br>"
			var/anything = 0
			for(var/datum/reagent/R in beaker.reagents.reagent_list)
				anything = 1
				beaker_contents += "[R.volume] - [R.name]<br>"
			if(!anything)
				beaker_contents += "Nothing<br>"


		dat = {"
			<b>Processing chamber contains:</b><br>
			[processing_chamber]<br>
			[beaker_contents]<hr>
			"}
		if (is_beaker_ready && !is_chamber_empty && !(stat & (NOPOWER|BROKEN)))
			dat += "<A href='?src=\ref[src];action=grind'>Grind the reagents</a><BR>"
			dat += "<A href='?src=\ref[src];action=juice'>Juice the reagents</a><BR><BR>"
		if(holdingitems && holdingitems.len > 0)
			dat += "<A href='?src=\ref[src];action=eject'>Eject the reagents</a><BR>"
		if (beaker)
			dat += "<A href='?src=\ref[src];action=detach'>Detach the beaker</a><BR>"
	else
		dat += "Please wait..."

	var/datum/browser/popup = new(user, "reagentgrinder", "All-In-One Grinder")
	popup.set_content("<TT>[dat]</TT>")
	popup.open()


/obj/machinery/reagentgrinder/Topic(href, href_list)
	. = ..()
	if(!.)
		return

	switch(href_list["action"])
		if ("grind")
			grind()
		if("juice")
			juice()
		if("eject")
			eject()
		if ("detach")
			detach()

	updateUsrDialog()

/obj/machinery/reagentgrinder/proc/detach()

	if(usr.incapacitated())
		return
	if (!beaker)
		return
	beaker.loc = src.loc
	beaker = null
	update_icon()

/obj/machinery/reagentgrinder/proc/eject()

	if(usr.incapacitated())
		return
	if (holdingitems && holdingitems.len == 0)
		return

	for(var/obj/item/O in holdingitems)
		O.loc = src.loc
		holdingitems -= O
	holdingitems = list()

/obj/machinery/reagentgrinder/proc/is_allowed(obj/item/weapon/reagent_containers/O)
	for (var/i in blend_items)
		if(istype(O, i))
			return 1
	return 0

/obj/machinery/reagentgrinder/proc/get_allowed_by_id(obj/item/weapon/grown/O)
	for (var/i in blend_items)
		if (istype(O, i))
			return blend_items[i]

/obj/machinery/reagentgrinder/proc/get_allowed_snack_by_id(obj/item/weapon/reagent_containers/food/snacks/O)
	for(var/i in blend_items)
		if(istype(O, i))
			return blend_items[i]

/obj/machinery/reagentgrinder/proc/get_allowed_juice_by_id(obj/item/weapon/reagent_containers/food/snacks/O)
	for(var/i in juice_items)
		if(istype(O, i))
			return juice_items[i]

/obj/machinery/reagentgrinder/proc/get_grownweapon_amount(obj/item/weapon/grown/O)
	if (!istype(O))
		return 5
	else if (O.potency == -1)
		return 5
	else
		return round(O.potency)

/obj/machinery/reagentgrinder/proc/get_juice_amount(obj/item/weapon/reagent_containers/food/snacks/grown/O)
	if (!istype(O))
		return 5
	else if (O.potency == -1)
		return 5
	else
		return round(5*sqrt(O.potency))

/obj/machinery/reagentgrinder/proc/remove_object(obj/item/O)
	holdingitems -= O
	qdel(O)

/obj/machinery/reagentgrinder/proc/juice()
	power_change()
	if(stat & (NOPOWER|BROKEN))
		return
	if (!beaker || (beaker && beaker.reagents.total_volume >= beaker.reagents.maximum_volume))
		return
	playsound(src, 'sound/machines/juicer.ogg', VOL_EFFECTS_MASTER, 20)
	var/offset = prob(50) ? -2 : 2
	animate(src, pixel_x = pixel_x + offset, time = 0.2, loop = 200) //start shaking
	inuse = 1
	spawn(50)
		pixel_x = initial(pixel_x) //return to its spot after shaking
		inuse = 0
		updateUsrDialog()
	//Snacks
	for (var/obj/item/weapon/reagent_containers/food/snacks/O in holdingitems)
		if (beaker.reagents.total_volume >= beaker.reagents.maximum_volume)
			break

		var/allowed = get_allowed_juice_by_id(O)
		if(isnull(allowed))
			break

		for (var/r_id in allowed)

			var/space = beaker.reagents.maximum_volume - beaker.reagents.total_volume
			var/amount = get_juice_amount(O)

			beaker.reagents.add_reagent(r_id, min(amount, space))

			if (beaker.reagents.total_volume >= beaker.reagents.maximum_volume)
				break

		remove_object(O)

/obj/machinery/reagentgrinder/proc/grind()

	power_change()
	if(stat & (NOPOWER|BROKEN))
		return
	if (!beaker || (beaker && beaker.reagents.total_volume >= beaker.reagents.maximum_volume))
		return
	playsound(src, 'sound/machines/blender.ogg', VOL_EFFECTS_MASTER, 35)
	var/offset = prob(50) ? -2 : 2
	animate(src, pixel_x = pixel_x + offset, time = 0.2, loop = 200) //start shaking
	inuse = 1
	spawn(60)
		pixel_x = initial(pixel_x) //return to its spot after shaking
		inuse = 0
		updateUsrDialog()
	//Snacks and Plants
	for (var/obj/item/weapon/reagent_containers/food/snacks/O in holdingitems)
		if (beaker.reagents.total_volume >= beaker.reagents.maximum_volume)
			break

		var/allowed = get_allowed_snack_by_id(O)
		if(isnull(allowed))
			break

		for (var/r_id in allowed)

			var/space = beaker.reagents.maximum_volume - beaker.reagents.total_volume
			var/amount = allowed[r_id]
			if(amount <= 0)
				if(amount == 0)
					if (O.reagents != null && O.reagents.has_reagent("nutriment"))
						beaker.reagents.add_reagent(r_id, min(O.reagents.get_reagent_amount("nutriment"), space))
						O.reagents.remove_reagent("nutriment", min(O.reagents.get_reagent_amount("nutriment"), space))
				else
					if (O.reagents != null && O.reagents.has_reagent("nutriment"))
						beaker.reagents.add_reagent(r_id, min(round(O.reagents.get_reagent_amount("nutriment")*abs(amount)), space))
						O.reagents.remove_reagent("nutriment", min(O.reagents.get_reagent_amount("nutriment"), space))

			else
				O.reagents.trans_id_to(beaker, r_id, min(amount, space))

			if (beaker.reagents.total_volume >= beaker.reagents.maximum_volume)
				break

		if(O.reagents.reagent_list.len == 0)
			remove_object(O)

	//Sheets
	for (var/obj/item/stack/sheet/O in holdingitems)
		var/allowed = get_allowed_by_id(O)
		if (beaker.reagents.total_volume >= beaker.reagents.maximum_volume)
			break
		for(var/i = 1; i <= round(O.get_amount(), 1); i++)
			for (var/r_id in allowed)
				var/space = beaker.reagents.maximum_volume - beaker.reagents.total_volume
				var/amount = allowed[r_id]
				beaker.reagents.add_reagent(r_id,min(amount, space))
				if (space < amount)
					break
			if (i == round(O.get_amount(), 1))
				remove_object(O)
				break
	//Plants
	for (var/obj/item/weapon/grown/O in holdingitems)
		if (beaker.reagents.total_volume >= beaker.reagents.maximum_volume)
			break
		var/allowed = get_allowed_by_id(O)
		for (var/r_id in allowed)
			var/space = beaker.reagents.maximum_volume - beaker.reagents.total_volume
			var/amount = allowed[r_id]
			if (amount == 0)
				if (O.reagents != null && O.reagents.has_reagent(r_id))
					beaker.reagents.add_reagent(r_id,min(O.reagents.get_reagent_amount(r_id), space))
			else
				beaker.reagents.add_reagent(r_id,min(amount, space))

			if (beaker.reagents.total_volume >= beaker.reagents.maximum_volume)
				break
		remove_object(O)

	//xenoarch
	for(var/obj/item/weapon/rocksliver/O in holdingitems)
		if (beaker.reagents.total_volume >= beaker.reagents.maximum_volume)
			break
		var/allowed = get_allowed_by_id(O)
		for (var/r_id in allowed)
			var/space = beaker.reagents.maximum_volume - beaker.reagents.total_volume
			var/amount = allowed[r_id]
			beaker.reagents.add_reagent(r_id,min(amount, space), O.geological_data)

			if (beaker.reagents.total_volume >= beaker.reagents.maximum_volume)
				break
		remove_object(O)

	//Everything else - Transfers reagents from it into beaker
	for (var/obj/item/weapon/reagent_containers/O in holdingitems)
		if (beaker.reagents.total_volume >= beaker.reagents.maximum_volume)
			break
		var/amount = O.reagents.total_volume
		O.reagents.trans_to(beaker, amount)
		if(!O.reagents.total_volume)
			remove_object(O)

//Coin
	for (var/obj/item/weapon/coin/O in holdingitems)
		if (beaker.reagents.total_volume >= beaker.reagents.maximum_volume)
			break
		var/amount = O.reagents.total_volume
		O.reagents.trans_to(beaker, amount)
		if(!O.reagents.total_volume)
			remove_object(O)
