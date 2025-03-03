// Recruiting observers to play as pAIs

GLOBAL_DATUM_INIT(paiController, /datum/paiController, new) // Global handler for pAI candidates

/datum/paiController
	var/list/pai_candidates = list()
	var/list/asked = list()

	var/askDelay = 10 * 60 * 1	// One minute [ms * sec * min]

/datum/paiController/Topic(href, href_list[])

	var/datum/pai_save/candidate = locateUID(href_list["candidate"])

	if(candidate)
		if(!istype(candidate))
			message_admins("Warning: possible href exploit by [key_name_admin(usr)] (paiController/Topic, candidate is not a pAI)")
			log_debug("Warning: possible href exploit by [key_name(usr)] (paiController/Topic, candidate is not a pAI)")
			return

	if(href_list["download"])
		var/obj/item/paicard/card = locate(href_list["device"])
		if(card.pai)
			return
		if(!isobserver(candidate.owner.mob)) //This stops pais from being downloaded twice.
			to_chat(usr, "<span class='warning'>Error downloading pAI from NT_NET. Please check if the pAI listing is still available.</span>")
			return
		if(usr.incapacitated() || isobserver(usr) || !card.Adjacent(usr))
			return
		if(istype(card, /obj/item/paicard) && istype(candidate, /datum/pai_save))
			var/mob/living/silicon/pai/pai = new(card)
			if(!candidate.pai_name)
				pai.name = pick(GLOB.ninja_names)
			else
				pai.name = candidate.pai_name
			pai.real_name = pai.name
			pai.key = candidate.owner.ckey

			card.setPersonality(pai)
			card.looking_for_personality = 0

			SSticker.mode.update_cult_icons_removed(card.pai.mind)

			pai_candidates -= candidate
			usr << browse(null, "window=findPai")
		return

	if("signup" in href_list)
		var/mob/dead/observer/O = locate(href_list["signup"])
		if(!O)
			return
		if(!(O in GLOB.respawnable_list))
			to_chat(O, "You've given up your ability to respawn!")
			return
		if(!check_recruit(O))
			return
		recruitWindow(O)
		return

	if(candidate)
		if(candidate.owner.ckey && usr.ckey && candidate.owner.ckey != usr.ckey)
			message_admins("Warning: possible href exploit by [key_name_admin(usr)] (paiController/Topic, candidate and usr have different keys)")
			log_debug("Warning: possible href exploit by [key_name(usr)] (paiController/Topic, candidate and usr have different keys)")
			return

	if(href_list["new"])
		var/option = href_list["option"]
		var/t = ""

		switch(option)
			if("name")
				t = input("Enter a name for your pAI", "pAI Name", candidate.pai_name) as text
				if(t)
					candidate.pai_name = sanitize(copytext(t,1,MAX_NAME_LEN))
			if("desc")
				t = input("Enter a description for your pAI", "pAI Description", candidate.description) as message
				if(t)
					candidate.description = sanitize(copytext(t,1,MAX_MESSAGE_LEN))
			if("role")
				t = input("Enter a role for your pAI", "pAI Role", candidate.role) as text
				if(t)
					candidate.role = sanitize(copytext(t,1,MAX_MESSAGE_LEN))
			if("ooc")
				t = input("Enter any OOC comments", "pAI OOC Comments", candidate.ooc_comments) as message
				if(t)
					candidate.ooc_comments = sanitize(copytext(t,1,MAX_MESSAGE_LEN))
			if("save")
				candidate.save_to_db(usr)
			if("reload")
				candidate.reload_save(usr)
				//In case people have saved unsanitized stuff.
				if(candidate.pai_name)
					candidate.pai_name = sanitize(copytext(candidate.pai_name, 1, MAX_NAME_LEN))
				if(candidate.description)
					candidate.description = sanitize(copytext(candidate.description, 1, MAX_MESSAGE_LEN))
				if(candidate.role)
					candidate.role = sanitize(copytext(candidate.role, 1, MAX_MESSAGE_LEN))
				if(candidate.ooc_comments)
					candidate.ooc_comments = sanitize(copytext(candidate.ooc_comments, 1, MAX_MESSAGE_LEN))

			if("submit")
				if(candidate)
					GLOB.paiController.pai_candidates |= candidate
					for(var/obj/item/paicard/p in world)
						if(p.looking_for_personality == 1)
							p.alertUpdate()
				usr << browse(null, "window=paiRecruit")
				return
		recruitWindow(usr)

/datum/paiController/proc/recruitWindow(mob/M)
	var/datum/pai_save/candidate = M.client.pai_save

	var/dat = ""
	dat += {"
			<style type="text/css">
				body {
					margin-top:5px;
					font-family:Verdana;
					color:white;
					font-size:13px;
					background-image:url('uiBackground.png');
					background-repeat:repeat-x;
					background-color:#272727;
					background-position:center top;
				}
				table {
					border-collapse:collapse;
					font-size:13px;
				}
				th, td {
					border: 1px solid #333333;
				}
				p.top {
					background-color: none;
					color: white;
				}
				tr.d0 td {
					background-color: #c0c0c0;
					color: black;
					border:0px;
					border: 1px solid #333333;
				}
				tr.d0 th {
					background-color: none;
					color: #4477E0;
					text-align:right;
					vertical-align:top;
					width:120px;
					border:0px;
				}
				tr.d1 td {
					background-color: #555555;
					color: white;
				}
				td.button {
					border: 1px solid #161616;
					background-color: #40628a;
				}
				td.desc {
					font-weight:bold;
				}
				a {
					color:#4477E0;
				}
				a.button {
					color:white;
					text-decoration: none;
				}
			</style>
			"}

	dat += {"
	<body>
		<b><font size="3px">pAI Personality Configuration</font></b>
		<p class="top">Please configure your pAI personality's options. Remember, what you enter here could determine whether or not the user requesting a personality chooses you!</p>

		<table>
			<tr class="d0">
				<th rowspan="2"><a href='byond://?src=[UID()];option=name;new=1;candidate=[candidate.UID()]'>Name</a>:</th>
				<td class="desc">[candidate.pai_name]&nbsp;</td>
			</tr>
			<tr class="d1">
				<td>What you plan to call yourself. Suggestions: Any character name you would choose for a station character OR an AI.</td>
			</tr>
			<tr class="d0">
				<th rowspan="2"><a href='byond://?src=[UID()];option=desc;new=1;candidate=[candidate.UID()]'>Description</a>:</th>
				<td class="desc">[candidate.description]&nbsp;</td>
			</tr>
			<tr class="d1">
				<td>What sort of pAI you typically play; your mannerisms, your quirks, etc. This can be as sparse or as detailed as you like.</td>
			</tr>
			<tr class="d0">
				<th rowspan="2"><a href='byond://?src=[UID()];option=role;new=1;candidate=[candidate.UID()]'>Preferred Role</a>:</th>
				<td class="desc">[candidate.role]&nbsp;</td>
			</tr>
			<tr class="d1">
				<td>Do you like to partner with sneaky social ninjas? Like to help security hunt down thugs? Enjoy watching an engineer's back while he saves the station yet again? This doesn't have to be limited to just station jobs. Pretty much any general descriptor for what you'd like to be doing works here.</td>
			</tr>
			<tr class="d0">
				<th rowspan="2"><a href='byond://?src=[UID()];option=ooc;new=1;candidate=[candidate.UID()]'>OOC Comments</a>:</th>
				<td class="desc">[candidate.ooc_comments]&nbsp;</td>
			</tr>
			<tr class="d1">
				<td>Anything you'd like to address specifically to the player reading this in an OOC manner. \"I prefer more serious RP.\", \"I'm still learning the interface!\", etc. Feel free to leave this blank if you want.</td>
			</tr>
		</table>
		<br>
		<table>
			<tr>
				<td class="button">
					<a href='byond://?src=[UID()];option=save;new=1;candidate=[candidate.UID()]' class="button">Save Personality</a>
				</td>
			</tr>
			<tr>
				<td class="button">
					<a href='byond://?src=[UID()];option=reload;new=1;candidate=[candidate.UID()]' class="button">Reload Personality</a>
				</td>
			</tr>
		</table><br>
		<table>
			<td class="button"><a href='byond://?src=[UID()];option=submit;new=1;candidate=[candidate.UID()]' class="button"><b><font size="4px">Submit Personality</font></b></a></td>
		</table><br>

	</body>
	"}

	M << browse(dat, "window=paiRecruit;size=580x580;")

/datum/paiController/proc/findPAI(obj/item/paicard/p, mob/user)
	requestRecruits(p, user)
	var/list/available = list()
	for(var/datum/pai_save/c in GLOB.paiController.pai_candidates)
		var/found = 0
		for(var/mob/o in GLOB.respawnable_list)
			if(o.ckey == c.owner.ckey)
				found = 1
		if(found)
			available.Add(c)
	var/dat = ""

	dat += {"
		<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\" \"http://www.w3.org/TR/html4/loose.dtd\">
		<html>
			<head>
				<style>
					body {
						margin-top:5px;
						font-family:Verdana;
						color:white;
						font-size:13px;
						background-image:url('uiBackground.png');
						background-repeat:repeat-x;
						background-color:#272727;
						background-position:center top;
					}
					table {
						font-size:13px;
					}
					table.desc {
						border-collapse:collapse;
						font-size:13px;
						border: 1px solid #161616;
						width:100%;
					}
					table.download {
						border-collapse:collapse;
						font-size:13px;
						border: 1px solid #161616;
						width:100%;
					}
					tr.d0 td, tr.d0 th {
						background-color: #506070;
						color: white;
					}
					tr.d1 td, tr.d1 th {
						background-color: #708090;
						color: white;
					}
					tr.d2 td {
						background-color: #00FF00;
						color: white;
						text-align:center;
					}
					td.button {
						border: 1px solid #161616;
						background-color: #40628a;
						text-align: center;
					}
					td.download {
						border: 1px solid #161616;
						background-color: #40628a;
						text-align: center;
					}
					th {
						text-align:left;
						width:125px;
						vertical-align:top;
					}
					a.button {
						color:white;
						text-decoration: none;
					}
				</style>
			</head>
			<body>
				<b><font size='3px'>pAI Availability List</font></b><br><br>
	"}
	dat += "<p>Displaying available AI personalities from central database... If there are no entries, or if a suitable entry is not listed, check again later as more personalities may be added.</p>"

	for(var/datum/pai_save/c in available)
		dat += {"
				<table class="desc">
					<tr class="d0">
						<th>Name:</th>
						<td>[c.pai_name]</td>
					</tr>
					<tr class="d1">
						<th>Description:</th>
						<td>[c.description]</td>
					</tr>
					<tr class="d0">
						<th>Preferred Role:</th>
						<td>[c.role]</td>
					</tr>
					<tr class="d1">
						<th>OOC Comments:</th>
						<td>[c.ooc_comments]</td>
					</tr>
				</table>
				<table class="download">
					<td class="download"><a href='byond://?src=[UID()];download=1;candidate=[c.UID()];device=\ref[p]' class="button"><b>Download [c.pai_name]</b></a>
					</td>
				</table>
				<br>
		"}

	dat += {"
			</body>
		</html>
	"}

	user << browse(dat, "window=findPai")

/datum/paiController/proc/requestRecruits(obj/item/paicard/P, mob/user)
	for(var/mob/dead/observer/O in GLOB.player_list)
		if(O.client && (ROLE_PAI in O.client.prefs.be_special))
			if(player_old_enough_antag(O.client,ROLE_PAI))
				if(check_recruit(O))
					to_chat(O, "<span class='boldnotice'>A pAI card activated by [user.real_name] is looking for personalities. (<a href='?src=[O.UID()];jump=\ref[P]'>Teleport</a> | <a href='?src=[UID()];signup=\ref[O]'>Sign Up</a>)</span>")
					//question(O.client)

/datum/paiController/proc/check_recruit(mob/dead/observer/O)
	if(jobban_isbanned(O, ROLE_PAI) || jobban_isbanned(O, "nonhumandept"))
		return 0
	if(!player_old_enough_antag(O.client,ROLE_PAI))
		return 0
	if(cannotPossess(O))
		return 0
	if(!(O in GLOB.respawnable_list))
		return 0
	if(O.client)
		return 1
	return 0

/datum/paiController/proc/question(client/C)
	spawn(0)
		if(!C)	return
		asked.Add(C.key)
		asked[C.key] = world.time
		var/response = alert(C, "Someone is requesting a pAI personality. Would you like to play as a personal AI?", "pAI Request", "Yes", "No", "Never for this round")
		if(!C)	return		//handle logouts that happen whilst the alert is waiting for a response.
		if(response == "Yes")
			recruitWindow(C.mob)
		else if(response == "Never for this round")
			var/warning = alert(C, "Are you sure? This action will be undoable and you will need to wait until next round.", "You sure?", "Yes", "No")
			if(warning == "Yes")
				asked[C.key] = INFINITY
			else
				question(C)
