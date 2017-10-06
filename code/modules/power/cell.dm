// the power cell
// charge from 0 to 100%
// fits in APC to provide backup power

/obj/item/weapon/cell/Initialize()
	. = ..()
	charge = maxcharge
	update_icon()
	if(self_recharge)
		processing_objects |= src

/obj/item/weapon/cell/Destroy()
	if(self_recharge)
		processing_objects -= src
	return ..()

/obj/item/weapon/cell/process()
	if(self_recharge)
		give(charge_amount / CELLRATE)
	else
		return PROCESS_KILL

/obj/item/weapon/cell/Created()
	//Newly built cells spawn with no charge to prevent power exploits
	charge = 0
	update_icon()

/obj/item/weapon/cell/drain_power(var/drain_check, var/surge, var/power = 0)

	if(drain_check)
		return 1

	if(charge <= 0)
		return 0

	var/cell_amt = power * CELLRATE

	return use(cell_amt) / CELLRATE

/obj/item/weapon/cell/update_icon()
	cut_overlays()

	if(charge < 0.01)
		return
	else if(charge/maxcharge >=0.995)
		add_overlay("cell-o2")
	else
		add_overlay("cell-o1")

/obj/item/weapon/cell/proc/percent()		// return % charge of cell
	return 100.0*charge/maxcharge

/obj/item/weapon/cell/proc/fully_charged()
	return (charge == maxcharge)

// checks if the power cell is able to provide the specified amount of charge
/obj/item/weapon/cell/proc/check_charge(var/amount)
	return (charge >= amount)

// use power from a cell, returns the amount actually used
/obj/item/weapon/cell/proc/use(var/amount)
	if (QDELING(src))
		return 0

	if(rigged && amount > 0)
		explode()
		return 0
	var/used = min(charge, amount)
	charge -= used
	return used

// Checks if the specified amount can be provided. If it can, it removes the amount
// from the cell and returns 1. Otherwise does nothing and returns 0.
/obj/item/weapon/cell/proc/checked_use(var/amount)
	if(!check_charge(amount))
		return 0
	use(amount)
	return 1

// recharge the cell
/obj/item/weapon/cell/proc/give(var/amount)
	if (QDELING(src))
		return 0

	if(rigged && amount > 0)
		explode()
		return 0

	if(maxcharge < amount)	return 0
	var/amount_used = min(maxcharge-charge,amount)
	charge += amount_used
	return amount_used


/obj/item/weapon/cell/examine(mob/user)
	if(get_dist(src, user) > 1)
		return

	if(maxcharge <= 2500)
		user << "[desc]\nThe manufacturer's label states this cell has a power rating of [maxcharge], and that you should not swallow it.\nThe charge meter reads [round(src.percent() )]%."
	else
		user << "This power cell has an exciting chrome finish, as it is an uber-capacity cell type! It has a power rating of [maxcharge]!\nThe charge meter reads [round(src.percent() )]%."

/obj/item/weapon/cell/attackby(obj/item/W, mob/user)
	..()
	if(istype(W, /obj/item/weapon/reagent_containers/syringe))
		var/obj/item/weapon/reagent_containers/syringe/S = W

		user << "You inject the solution into the power cell."

		if(S.reagents.has_reagent("phoron", 5))

			rigged = 1

			log_admin("LOG: [user.name] ([user.ckey]) injected a power cell with phoron, rigging it to explode.",ckey=key_name(user))
			message_admins("[key_name_admin(user)] injected a power cell with phoron, rigging it to explode.")

		S.reagents.clear_reagents()
	else if(istype(W, /obj/item/device/assembly_holder))
		var/obj/item/device/assembly_holder/assembly = W
		if (istype(assembly.a_left, /obj/item/device/assembly/signaler) && istype(assembly.a_right, /obj/item/device/assembly/signaler))
			user.drop_item()
			user.drop_from_inventory(src)

			new /obj/item/device/radiojammer/improvised(assembly, src, user)
		else
			user << "<span class='notice'>You'd need both devices to be signallers for this to work.</span>"

/obj/item/weapon/cell/proc/explode()
	var/turf/T = get_turf(src.loc)
/*
 * 1000-cell	explosion(T, -1, 0, 1, 1)
 * 2500-cell	explosion(T, -1, 0, 1, 1)
 * 10000-cell	explosion(T, -1, 1, 3, 3)
 * 15000-cell	explosion(T, -1, 2, 4, 4)
 * */
	if (charge==0)
		return
	var/devastation_range = -1 //round(charge/11000)
	var/heavy_impact_range = round(sqrt(charge)/60)
	var/light_impact_range = round(sqrt(charge)/30)
	var/flash_range = light_impact_range
	if (light_impact_range==0)
		rigged = 0
		corrupt()
		return
	//explosion(T, 0, 1, 2, 2)

	log_admin("LOG: Rigged power cell explosion, last touched by [fingerprintslast]")
	message_admins("LOG: Rigged power cell explosion, last touched by [fingerprintslast]")

	explosion(T, devastation_range, heavy_impact_range, light_impact_range, flash_range)

	qdel(src)

/obj/item/weapon/cell/proc/corrupt()
	charge /= 2
	maxcharge /= 2
	if (prob(10))
		rigged = 1 //broken batterys are dangerous

/obj/item/weapon/cell/emp_act(severity)
	//remove this once emp changes on dev are merged in
	if(isrobot(loc))
		var/mob/living/silicon/robot/R = loc
		severity *= R.cell_emp_mult

	charge -= maxcharge / severity
	if (charge < 0)
		charge = 0
	..()

/obj/item/weapon/cell/ex_act(severity)

	switch(severity)
		if(1.0)
			qdel(src)
			return
		if(2.0)
			if (prob(50))
				qdel(src)
				return
			if (prob(50))
				corrupt()
		if(3.0)
			if (prob(25))
				qdel(src)
				return
			if (prob(25))
				corrupt()
	return

/obj/item/weapon/cell/proc/get_electrocute_damage()
	switch (charge)
/*		if (9000 to INFINITY)
			return min(rand(90,150),rand(90,150))
		if (2500 to 9000-1)
			return min(rand(70,145),rand(70,145))
		if (1750 to 2500-1)
			return min(rand(35,110),rand(35,110))
		if (1500 to 1750-1)
			return min(rand(30,100),rand(30,100))
		if (750 to 1500-1)
			return min(rand(25,90),rand(25,90))
		if (250 to 750-1)
			return min(rand(20,80),rand(20,80))
		if (100 to 250-1)
			return min(rand(20,65),rand(20,65))*/
		if (1000000 to INFINITY)
			return min(rand(50,160),rand(50,160))
		if (200000 to 1000000-1)
			return min(rand(25,80),rand(25,80))
		if (100000 to 200000-1)//Ave powernet
			return min(rand(20,60),rand(20,60))
		if (50000 to 100000-1)
			return min(rand(15,40),rand(15,40))
		if (1000 to 50000-1)
			return min(rand(10,20),rand(10,20))
		else
			return 0
