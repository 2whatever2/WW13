/obj/item/ammo_casing
	name = "bullet casing"
	desc = "A bullet casing."
	icon = 'icons/obj/ammo.dmi'
	icon_state = "s-casing"
	flags = CONDUCT
	slot_flags = SLOT_BELT | SLOT_EARS
	throwforce = TRUE
	w_class = TRUE

	var/leaves_residue = TRUE
	var/caliber = ""					//Which kind of guns it can be loaded into
	var/projectile_type					//The bullet type to create when New() is called
	var/obj/item/projectile/BB = null	//The loaded bullet - make it so that the projectiles are created only when needed?
	var/spent_icon = null
	var/defective = FALSE

/obj/item/ammo_casing/New()
	..()
	if (ispath(projectile_type))
		BB = new projectile_type(src)
	if (prob(1))
		defective = TRUE
	pixel_x = rand(-10, 10)
	pixel_y = rand(-10, 10)
	bullet_casings += src

/obj/item/ammo_casing/Destroy()
	bullet_casings -= src
	..()

//removes the projectile from the ammo casing
/obj/item/ammo_casing/proc/expend()
	. = BB
	BB = null
	set_dir(pick(cardinal)) //spin spent casings
	update_icon()

/obj/item/ammo_casing/proc/cook()
	var/turf/T = get_turf(src)
	var/list/target_turfs = getcircle(T, 3)
	for (var/turf/TT in target_turfs)
		var/obj/item/projectile/bullet/pellet/fragment/P = new /obj/item/projectile/bullet/pellet/fragment(T)
		P.damage = 8
		P.pellets = 10
		P.range_step = 3
		P.shot_from = name
		P.launch_fragment(TT)
	for (T in getcircle(4, T))
		new/obj/effect/decal/cleanable/dirt(T)

/obj/item/ammo_casing/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/screwdriver))
		if (!BB)
			user << "<span class = 'notice'>There is no bullet in the casing to inscribe anything into.</span>"
			return

		var/tmp_label = ""
		var/label_text = sanitizeSafe(input(user, "Inscribe some text into \the [initial(BB.name)]","Inscription",tmp_label), MAX_NAME_LEN)
		if (length(label_text) > 20)
			user << "<span class = 'red'>The inscription can be at most 20 characters long.</span>"
		else if (!label_text)
			user << "<span class = 'notice'>You scratch the inscription off of [initial(BB)].</span>"
			BB.name = initial(BB.name)
		else
			user << "<span class = 'notice'>You inscribe \"[label_text]\" into \the [initial(BB.name)].</span>"
			BB.name = "[initial(BB.name)] (\"[label_text]\")"

/obj/item/ammo_casing/update_icon()
	if (spent_icon && !BB)
		icon_state = spent_icon

/obj/item/ammo_casing/examine(mob/user)
	..()
	if (!BB)
		user << "This one is spent."

//Gun loading types
#define SINGLE_CASING 	1	//The gun only accepts ammo_casings. ammo_magazines should never have this as their mag_type.
#define SPEEDLOADER 	2	//Transfers casings from the mag to the gun when used.
#define MAGAZINE 		4	//The magazine item itself goes inside the gun

//An item that holds casings and can be used to put them inside guns
/obj/item/ammo_magazine
	name = "magazine"
	desc = "A magazine for some kind of gun."
	icon_state = "357"
	icon = 'icons/obj/ammo.dmi'
	flags = CONDUCT
	slot_flags = SLOT_BELT
	item_state = "syringe_kit"
	matter = list(DEFAULT_WALL_MATERIAL = 500)
	throwforce = 5
	w_class = 2
	throw_speed = 4
	throw_range = 10

	var/list/stored_ammo = list()
	var/mag_type = SPEEDLOADER //ammo_magazines can only be used with compatible guns. This is not a bitflag, the load_method var on guns is.
	var/caliber = "357"
	var/ammo_mag = "default"
	var/max_ammo = 7

	var/ammo_type = /obj/item/ammo_casing //ammo type that is initially loaded
	var/initial_ammo = null

	var/multiple_sprites = FALSE
	//because BYOND doesn't support numbers as keys in associative lists
	var/list/icon_keys = list()		//keys
	var/list/ammo_states = list()	//values

	// are we an ammo box
	var/is_box = FALSE

/obj/item/ammo_magazine/New()
	..()
	if (multiple_sprites)
		initialize_magazine_icondata(src)

	if (isnull(initial_ammo))
		initial_ammo = max_ammo

	if (initial_ammo)
		for (var/i in TRUE to initial_ammo)
			stored_ammo += new ammo_type(src)
	update_icon()

/obj/item/ammo_magazine/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (W == src)
		return
	if (istype(W, /obj/item/ammo_casing))
		var/obj/item/ammo_casing/C = W
		if (C.caliber != caliber)
			user << "<span class='warning'>[C] does not fit into [src].</span>"
			return
		if (stored_ammo.len >= max_ammo)
			user << "<span class='warning'>[src] is full!</span>"
			return
		user.remove_from_mob(C)
		C.loc = src
		stored_ammo.Insert(1, C) //add to the head of the list
		update_icon()
	else if (istype(W, /obj/item/ammo_magazine))
		var/obj/item/ammo_magazine/M = W
		if (M.caliber != caliber)
			user << "<span class='warning'>[M]'s ammo type does not fit into [src].</span>"
			return
		if (stored_ammo.len >= max_ammo)
			user << "<span class='warning'>[src] is full!</span>"
			return
		if (M.stored_ammo.len == FALSE)
			user << "<span class='warning'>[M] is empty!</span>"
			return

		var/filled = FALSE
		for (var/obj/item/ammo_casing/C in M.stored_ammo)
			if (stored_ammo.len >= max_ammo)
				break
			C.loc = src
			stored_ammo.Insert(1, C)
			M.stored_ammo -= C
			filled = TRUE

		if (filled)
			user << "<span class = 'notice'>You fill [src] with [M]'s ammo.</span>"

		update_icon()
		W.update_icon()

// empty the mag
/obj/item/ammo_magazine/attack_self(mob/user)

	var/cont = FALSE
	if (stored_ammo.len > 0 && stored_ammo.len < 30)
		if ((input(user, "Are you sure you want to empty the [src]?", "[src]") in list ("Yes", "No")) == "Yes")
			cont = TRUE

	if (cont)
		var/turf/T = get_turf(src)
		// so people know who to lynch
		T.visible_message("<span class = 'notice'>[user] empties [src].</span>", "<span class='notice'>You empty [src].</span>")
		for (var/obj/item/ammo_casing/C in stored_ammo)
			C.loc = user.loc
			C.set_dir(pick(cardinal))
			playsound(loc, pick("sound/items/drop.ogg", "sound/items/drop2.ogg","sound/items/drop3.ogg","sound/items/drop4.ogg"), 10, TRUE, -5)

		stored_ammo.Cut()
		update_icon()


/obj/item/ammo_magazine/update_icon()
	if (multiple_sprites && icon_keys.len)
		//find the lowest key greater than or equal to stored_ammo.len
		var/new_state = null
		for (var/idx in TRUE to icon_keys.len)
			var/ammo_count = icon_keys[idx]
			if (ammo_count >= stored_ammo.len)
				new_state = ammo_states[idx]
				break
		icon_state = (new_state)? new_state : initial(icon_state)

/obj/item/ammo_magazine/examine(mob/user)
	..()
	user << "There [(stored_ammo.len == TRUE)? "is" : "are"] [stored_ammo.len] round\s left!"

//magazine icon state caching
/var/global/list/magazine_icondata_keys = list()
/var/global/list/magazine_icondata_states = list()

/proc/initialize_magazine_icondata(var/obj/item/ammo_magazine/M)
	var/typestr = "[M.type]"
	if (!(typestr in magazine_icondata_keys) || !(typestr in magazine_icondata_states))
		magazine_icondata_cache_add(M)

	M.icon_keys = magazine_icondata_keys[typestr]
	M.ammo_states = magazine_icondata_states[typestr]

/proc/magazine_icondata_cache_add(var/obj/item/ammo_magazine/M)
	if (!M.icon)
		return
	var/list/icon_keys = list()
	var/list/ammo_states = list()
	var/list/states = icon_states(M.icon)
	for (var/i = FALSE, i <= M.max_ammo, i++)
		var/ammo_state = "[M.icon_state]-[i]"
		if (ammo_state in states)
			icon_keys += i
			ammo_states += ammo_state

	magazine_icondata_keys["[M.type]"] = icon_keys
	magazine_icondata_states["[M.type]"] = ammo_states

//weight stuff
/obj/item/ammo_magazine/get_weight()
	. = ..()
	for (var/obj/item/I in stored_ammo)
		.+= I.get_weight()
	return .
