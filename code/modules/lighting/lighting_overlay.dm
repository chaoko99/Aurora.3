/atom/movable/lighting
	name          = ""
	anchored      = TRUE
	icon          = LIGHTING_ICON
	icon_state    = LIGHTING_BASE_ICON_STATE
	color         = LIGHTING_BASE_MATRIX
	mouse_opacity = 0
	layer         = LIGHTING_LAYER
	invisibility  = INVISIBILITY_LIGHTING
	simulated     = 0

	var/needs_update = FALSE

	#if WORLD_ICON_SIZE != 32
	transform = matrix(WORLD_ICON_SIZE / 32, 0, (WORLD_ICON_SIZE - 32) / 2, 0, WORLD_ICON_SIZE / 32, (WORLD_ICON_SIZE - 32) / 2)
	#endif

/atom/movable/lighting/multiplier
	blend_mode = BLEND_MULTIPLY

/atom/movable/lighting/New()
	SSlighting.total_lighting_overlays++


	var/turf/T         = loc // If this runtimes atleast we'll know what's creating overlays in things that aren't turfs.
	T.lighting_overlay = src
	T.luminosity       = 0

	needs_update = TRUE
	SSlighting.overlay_queue += src

/atom/movable/lighting/Destroy()
	SSlighting.lighting_overlays -= src
	
	return ..()

/atom/movable/lighting/multiplier/Destroy(force = FALSE)
	if (!force)
		return QDEL_HINT_LETMELIVE	// STOP DELETING ME

	//L_PROF(loc, "overlay_destroy")
	SSlighting.total_lighting_overlays--

	var/turf/T = loc
	if (istype(T))
		T.lighting_overlay = null
		T.luminosity = 1

	return ..()

/atom/movable/lighting/proc/update_overlay()

// This is a macro PURELY so that the if below is actually readable.
#define ALL_EQUAL ((rr == gr && gr == br && br == ar) && (rg == gg && gg == bg && bg == ag) && (rb == gb && gb == bb && bb == ab))

/atom/movable/lighting/multiplier/update_overlay()
	var/turf/T = loc
	if (!istype(T)) // Erm...
		if (loc)
			warning("A lighting overlay realised its loc was NOT a turf (actual loc: [loc], [loc.type]) in update_overlay() and got deleted!")

		else
			warning("A lighting overlay realised it was in nullspace in update_overlay() and got deleted!")

		qdel(src, TRUE)
		return

	// See LIGHTING_CORNER_DIAGONAL in lighting_corner.dm for why these values are what they are.
	var/list/corners = T.corners
	var/datum/lighting_corner/cr = dummy_lighting_corner
	var/datum/lighting_corner/cg = dummy_lighting_corner
	var/datum/lighting_corner/cb = dummy_lighting_corner
	var/datum/lighting_corner/ca = dummy_lighting_corner
	if (corners)
		cr = corners[3] || dummy_lighting_corner
		cg = corners[2] || dummy_lighting_corner
		cb = corners[4] || dummy_lighting_corner
		ca = corners[1] || dummy_lighting_corner

	if (!T.lighting_adder && (cr.needs_add || cg.needs_add || cb.needs_add || ca.needs_add))
		new /atom/movable/lighting/adder(loc)
	else if (T.lighting_adder)
		T.lighting_adder.update_overlay()

	var/max = max(cr.cache_mx, cg.cache_mx, cb.cache_mx, ca.cache_mx)
	luminosity = max > LIGHTING_SOFT_THRESHOLD

	var/rr = cr.cache_r
	var/rg = cr.cache_g
	var/rb = cr.cache_b

	var/gr = cg.cache_r
	var/gg = cg.cache_g
	var/gb = cg.cache_b

	var/br = cb.cache_r
	var/bg = cb.cache_g
	var/bb = cb.cache_b

	var/ar = ca.cache_r
	var/ag = ca.cache_g
	var/ab = ca.cache_b

	if ((rr & gr & br & ar) && (rg + gg + bg + ag + rb + gb + bb + ab == 8))
		icon_state = LIGHTING_TRANSPARENT_ICON_STATE
		color = null
	else if (!luminosity)
		icon_state = LIGHTING_DARKNESS_ICON_STATE
		color = null
	else if (ALL_EQUAL && rr == LIGHTING_DEFAULT_TUBE_R && rg == LIGHTING_DEFAULT_TUBE_G && rb == LIGHTING_DEFAULT_TUBE_B)
		icon_state = LIGHTING_STATION_ICON_STATE
		color = null
	else
		icon_state = LIGHTING_BASE_ICON_STATE
		if (islist(color))
			var/list/c_list = color
			c_list[CL_MATRIX_RR] = rr
			c_list[CL_MATRIX_RG] = rg
			c_list[CL_MATRIX_RB] = rb
			c_list[CL_MATRIX_GR] = gr
			c_list[CL_MATRIX_GG] = gg
			c_list[CL_MATRIX_GB] = gb
			c_list[CL_MATRIX_BR] = br
			c_list[CL_MATRIX_BG] = bg
			c_list[CL_MATRIX_BB] = bb
			c_list[CL_MATRIX_AR] = ar
			c_list[CL_MATRIX_AG] = ag
			c_list[CL_MATRIX_AB] = ab
			color = c_list
		else
			color = list(
				rr, rg, rb, 0,
				gr, gg, gb, 0,
				br, bg, bb, 0,
				ar, ag, ab, 0,
				0, 0, 0, 1
			)

	// If we're on an openturf, update the shadower object too.
	var/turf/simulated/open/OT = loc:above
	if (OT)
		OT.update_icon()

// Variety of overrides so the overlays don't get affected by weird things.

/atom/movable/lighting/ex_act(severity)
	return 0

/atom/movable/lighting/singularity_act()
	return

/atom/movable/lighting/singularity_pull()
	return

/atom/movable/lighting/singuloCanEat()
	return FALSE

/atom/movable/lighting/can_fall()
	return FALSE

// Override here to prevent things accidentally moving around overlays.
/atom/movable/lighting/forceMove(atom/destination, no_tp = FALSE, harderforce = FALSE)
	if(harderforce)
		//L_PROF(loc, "overlay_forcemove")
		. = ..()

/atom/movable/lighting/shuttle_move(turf/loc)
	return

/atom/movable/lighting/conveyor_act()
	return

/atom/movable/lighting/adder
	blend_mode = BLEND_ADD

/atom/movable/lighting/adder/New()
	needs_update = TRUE
	SSlighting.overlay_queue += src

	var/turf/T = loc
	T.lighting_adder = src

/atom/movable/lighting/adder/Destroy(force)
	if (!force)
		return QDEL_HINT_LETMELIVE	// feck off

	if (isturf(loc))
		var/turf/T = loc
		T.lighting_adder = null

	return ..()

// min(max((RL_LumR - 1) * 0.5, 0), 0.3)

/atom/movable/lighting/adder/update_overlay()
	var/turf/T = loc
	if (!istype(T)) // Erm...
		if (loc)
			warning("A lighting overlay realised its loc was NOT a turf (actual loc: [loc], [loc.type]) in update_overlay() and got deleted!")

		else
			warning("A lighting overlay realised it was in nullspace in update_overlay() and got deleted!")

		qdel(src, TRUE)
		return

	// See LIGHTING_CORNER_DIAGONAL in lighting_corner.dm for why these values are what they are.
	var/list/corners = T.corners
	var/datum/lighting_corner/cr = dummy_lighting_corner
	var/datum/lighting_corner/cg = dummy_lighting_corner
	var/datum/lighting_corner/cb = dummy_lighting_corner
	var/datum/lighting_corner/ca = dummy_lighting_corner
	if (corners)
		cr = corners[3] || dummy_lighting_corner
		cg = corners[2] || dummy_lighting_corner
		cb = corners[4] || dummy_lighting_corner
		ca = corners[1] || dummy_lighting_corner

	var/visible = cr.needs_add || cg.needs_add || cb.needs_add || ca.needs_add

	if (visible)
		invisibility = INVISIBILITY_LIGHTING
		var/rr = cr.add_r
		var/rg = cr.add_g
		var/rb = cr.add_b

		var/gr = cg.add_r
		var/gg = cg.add_g
		var/gb = cg.add_b

		var/br = cb.add_r
		var/bg = cb.add_g
		var/bb = cb.add_b

		var/ar = ca.add_r
		var/ag = ca.add_g
		var/ab = ca.add_b

		if (islist(color))
			var/list/c_list = color
			c_list[CL_MATRIX_RR] = rr
			c_list[CL_MATRIX_RG] = rg
			c_list[CL_MATRIX_RB] = rb
			c_list[CL_MATRIX_GR] = gr
			c_list[CL_MATRIX_GG] = gg
			c_list[CL_MATRIX_GB] = gb
			c_list[CL_MATRIX_BR] = br
			c_list[CL_MATRIX_BG] = bg
			c_list[CL_MATRIX_BB] = bb
			c_list[CL_MATRIX_AR] = ar
			c_list[CL_MATRIX_AG] = ag
			c_list[CL_MATRIX_AB] = ab
			color = c_list
		else
			color = list(
				rr, rg, rb, 0,
				gr, gg, gb, 0,
				br, bg, bb, 0,
				ar, ag, ab, 0,
				0, 0, 0, 1
			)
	else
		qdel(src, TRUE)

#undef ALL_EQUAL
