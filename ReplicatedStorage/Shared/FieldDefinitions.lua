--!strict
-- FieldDefinitions.lua

export type FieldDefinition = {
	id: string,
	displayName: string,
	visualTag: string,
	description: string,
}

local FieldDefinitions: {[string]: FieldDefinition} = {
	SUN_WET = {
		id = "SUN_WET",
		displayName = "Sonne + Nass",
		visualTag = "🌞💧",
		description = "Flussnähe / sonnig mit guter Bewässerung",
	},
	SUN_DRY = {
		id = "SUN_DRY",
		displayName = "Sonne + Trocken",
		visualTag = "🌞🪨",
		description = "Dächer / offene Plätze mit wenig Wasser",
	},
	SHADE_WET = {
		id = "SHADE_WET",
		displayName = "Schatten + Nass",
		visualTag = "🌥💧",
		description = "Innenhöfe oder Schatten nahe Wasser",
	},
	SHADE_DRY = {
		id = "SHADE_DRY",
		displayName = "Schatten + Trocken",
		visualTag = "🌥🪨",
		description = "Schatten zwischen Gebäuden, wenig Wasser",
	},
}

return FieldDefinitions
