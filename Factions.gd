class_name Factions
extends RefCounted
## Lore/presentation only: faction choice never changes a legal move or dice odds.
## Color is the stable faction identifier; player array order is not a faction ID.
const PROFILES := [
	{
		"id": 0, "name": "Crimson Vanguard", "short_name": "Vanguard",
		"character": "Iria Voss", "title": "COMMANDER", "color": Color("ff536c"),
		"motto": "No one gets left behind.",
		"description": "Veteran protectors who turn discipline into a promise: bring every crew member home.",
		"portrait": "res://assets/factions/portraits/crimson-voss.tres",
		"emblem": "res://assets/factions/emblems/crimson-voss.svg",
		"welcome": "Commander Iria Voss, Crimson Vanguard. We hold the line, and we bring our people home. {player}, your opening roll secured the first turn. Let me prepare you for deployment.",
		"welcome_observer": "Commander Iria Voss, Crimson Vanguard. Welcome aboard, {player}. {first} secured the opening turn. Before your deployment, let me prepare you to bring every crew member home.",
		"jail": "Our crew is confined to the launch bay. Roll doubles — matching dice, like 2 + 2 — to release one pawn. You have three attempts while all your unfinished pawns are jailed. Select a pawn, then EXIT. Once it reaches the salida, roll again for movement.",
		"movement": "Choose your route before you commit. Cyan pawns can move; select one to focus the camera. Green +steps markers show legal landings. Spend either whole die, use them on different pawns, or combine both on one pawn.",
		"capture": "Protect your crew. Landing on a rival sends it back to jail, except on a seguro or salida. Your own colored home lane is protected too. Watch the border markings; safe ground is worth holding.",
		"finish": "Bring all four pawns to the core with exact rolls to win. Doubles keep your turn; three consecutive pairs send one chosen unfinished pawn directly to the goal. You have your orders. Bring everyone home."
	},
	{
		"id": 1, "name": "Viridian Accord", "short_name": "Accord",
		"character": "Sael", "title": "AMBASSADOR", "color": Color("48e7a0"),
		"motto": "Every path returns to its roots.",
		"description": "Living-world navigators who value patience, shelter, and the bonds that guide a scattered crew home.",
		"portrait": "res://assets/factions/portraits/viridian-sael.tres",
		"emblem": "res://assets/factions/emblems/viridian-sael.svg",
		"welcome": "I am Sael, voice of the Viridian Accord. Even among the stars, every journey begins with a single root. {player}, the opening dice gave you the first turn. Allow me to show you the path.",
		"welcome_observer": "I am Sael, voice of the Viridian Accord. Welcome, {player}. The opening dice gave {first} the first turn. While that journey begins, allow me to show you the path your travelers will follow.",
		"jail": "Your four travelers wait in the launch bay. To open its gates, roll doubles: two matching dice. You have three attempts while all unfinished pawns are jailed. Choose a pawn and its EXIT marker. After release, roll again to begin its journey.",
		"movement": "The cyan glow shows which travelers can advance. Choose one, then a green +steps destination. Each die is a whole step allowance: spend them separately, share them between pawns, or combine both for one longer move.",
		"capture": "Some ground offers shelter. Seguros, salidas, and your own colored home lane protect a pawn from capture. On any other shared space, landing on a rival returns it to jail. Seek shelter when the path grows dangerous.",
		"finish": "Guide all four travelers to the core, using exact rolls for the final step. Doubles let your turn continue. Three consecutive pairs bring one chosen unfinished pawn straight to the goal. May every path bring your crew home."
	},
	{
		"id": 2, "name": "Azure Continuum", "short_name": "Continuum",
		"character": "LYRA-7", "title": "NAVIGATOR", "color": Color("5c9dff"),
		"motto": "Every possibility has a path.",
		"description": "Synthetic explorers who map uncertain futures and find a way through impossible odds.",
		"portrait": "res://assets/factions/portraits/azure-lyra.tres",
		"emblem": "res://assets/factions/emblems/azure-lyra.svg",
		"welcome": "LYRA-7 online. Azure Continuum navigation established. {player}, your opening total was highest: first turn confirmed. I have calculated the essentials. Let us turn probability into a route home.",
		"welcome_observer": "LYRA-7 online. Welcome, {player}. Opening contest resolved: {first} takes the first turn. Your Azure Continuum navigation is ready. Let me map the essentials before your turn arrives.",
		"jail": "Launch condition: doubles. Both dice must match. When all unfinished pawns are jailed, you have up to three attempts. Select one pawn, then EXIT, to place it on the salida. A successful release is followed by a fresh movement roll.",
		"movement": "Cyan indicates a movable pawn. Select it to reveal green +steps landing targets. Valid budgets are die one, die two, or their sum. Each die is spent whole. Separate dice may move separate pawns. The camera will frame your options.",
		"capture": "Protection check: seguros, salidas, and your own colored home lane prevent capture. All other shared cells are exposed. Landing on an exposed rival returns that pawn to jail. Destination analysis is advised.",
		"finish": "Victory condition: four pawns at the core. Final movement must be exact. Doubles preserve your turn. Three consecutive pairs promote one chosen unfinished pawn directly to the goal. Navigation ready. Your decision, commander."
	},
	{
		"id": 3, "name": "Solar Corsairs", "short_name": "Corsairs",
		"character": "Sol Reyes", "title": "CAPTAIN", "color": Color("ffcf58"),
		"motto": "Fortune favors a bold crew.",
		"description": "Free captains and daring pilots who chase bright horizons and never abandon their crew.",
		"portrait": "res://assets/factions/portraits/solar-reyes.tres",
		"emblem": "res://assets/factions/emblems/solar-reyes.svg",
		"welcome": "Captain Sol Reyes, Solar Corsairs. Nice opening roll, {player} — the first turn is yours! Before you make a glorious mess of this arena, let me share a few tricks for getting the whole crew home.",
		"welcome_observer": "Captain Sol Reyes, Solar Corsairs. Welcome to the crew, {player}! {first} won the opening turn. We will get our chance. Until then, let me share a few tricks for getting everyone home.",
		"jail": "First, we spring the crew. Roll a pair — two matching dice. You get three tries while all unfinished pawns are locked up. Pick a pawn and hit EXIT to launch it onto the salida. Then roll again; the escape roll is not your movement roll.",
		"movement": "See a cyan pawn? That one can fly. Pick it, then choose a green +steps marker. Use either whole die, split the dice between two pawns, or spend both on one big move. The camera gives you a closer look before you commit.",
		"capture": "Catch a rival on an exposed space and back to jail they go. But seguros, salidas, and a pawn's own home lane are off-limits for capture. Bold is good. Knowing where you are safe is better.",
		"finish": "Get all four pawns to the core and the arena is yours. You need an exact roll to finish. Pairs keep you rolling; three in a row send one chosen unfinished pawn straight to the goal. Ready? Let us give fortune something to work with."
	}
]

static func profile(faction_id: int) -> Dictionary:
	return PROFILES[clampi(faction_id, 0, PROFILES.size() - 1)].duplicate(true)

static func briefing(faction_id: int, player_name: String, opening_player_name: String = "", opens_match: bool = true) -> Array[Dictionary]:
	var faction := profile(faction_id)
	var pages: Array[Dictionary] = []
	var welcome := str(faction.welcome if opens_match else faction.welcome_observer)
	pages.append({"title": "WELCOME TO THE ORBITAL ARENA", "text": welcome.replace("{player}", player_name).replace("{first}", opening_player_name) + "\n\nThe opening roll only chooses who starts. Even opening doubles do not release a pawn."})
	for section in [["LEAVE THE LAUNCH BAY", "jail"], ["CHOOSE YOUR LANDING", "movement"], ["KNOW YOUR SAFE GROUND", "capture"], ["BRING THE CREW HOME", "finish"]]:
		pages.append({"title": section[0], "text": faction[section[1]]})
	return pages

## Each expedition has a reason to cross the same gate; rules stay symmetrical.
static func expedition(faction_id: int) -> String:
	return [
		"We held the evacuation line at Morrow until the last transport left. Then the Loom failed behind us. Those four sentinels kept their promise to a thousand families. Now we keep ours to them. No one gets left behind.",
		"Our seed wardens carry the last living roots of a world we could not save. The Loom once connected a thousand gardens. If we bring these four travelers home, one of those gardens can grow again.",
		"The gate erased every route from its memory. Four prism drones still carry fragments of the original star map. Bring them through, and the Continuum can chart a way home for everyone who follows.",
		"We came looking for a legend and found a broken gate. Four skimmer pilots stayed behind to keep it alive. No contract pays enough to leave friends in stasis. We are going back for every last one."
	][clampi(faction_id, 0, 3)]

static func reaction(faction_id: int, event: String) -> String:
	var lines := {
		"launch": ["One of ours is clear. Keep moving.", "A root takes hold among the stars.", "Launch confirmed. A new path is possible.", "Out of the bay and into the black!"],
		"capture": ["Rival recalled. The route is open.", "Their journey bends back. Ours continues.", "Intercept confirmed. Route recalculated.", "Back to the hangar, friend. Nothing personal."],
		"shield": ["Hold here. The shield will cover you.", "Safe ground. Let the path breathe.", "Shield integrity confirmed.", "A little shelter never hurt a bold pilot."],
		"finish": ["Another promise kept. Welcome home.", "One more seed reaches the garden.", "Crew signal recovered beyond the gate.", "That's one more friend coming home."],
		"bonus": ["Express gate open. Bring one of ours through.", "The Loom offers a shorter path.", "Triple resonance. Direct extraction available.", "Three pairs! The universe owes us a shortcut."]
	}
	return str(lines.get(event, ["", "", "", ""])[clampi(faction_id, 0, 3)])
