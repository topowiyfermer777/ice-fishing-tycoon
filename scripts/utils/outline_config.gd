extends RefCounted
class_name OutlineConfig

enum Category {
	NONE,
	CHARACTER,
	TOOL,
	FISH,
	STEAK,
	FOOD,
	STATION,
	CASH,
	FENCE,
	ENVIRONMENT,
	ENV_PROP,
}

const OUTLINE_COLOR := Color(0.08, 0.08, 0.11, 1.0)
const FENCE_OUTLINE_COLOR := Color(0.13, 0.09, 0.07, 1.0)

const WIDTHS := {
	Category.NONE: 0.0,
	Category.CHARACTER: 0.015,
	Category.TOOL: 0.009,
	Category.FISH: 0.019,
	Category.STEAK: 0.020,
	Category.FOOD: 0.018,
	Category.STATION: 0.009,
	Category.CASH: 0.006,
	Category.FENCE: 0.009,
	Category.ENVIRONMENT: 0.020,
	Category.ENV_PROP: 0.015,
}

const SKIP_SUBSTRINGS := [
	"eye",
	"eyebrow",
	"mouth",
	"nose",
	"ear",
	"zipper",
	"button",
	"pricetext",
	"snow_groove",
	"snow_frontchamfer",
	"sparkles",
]

static func get_width(category: int) -> float:
	return float(WIDTHS.get(category, 0.01))

static func get_color(category: int) -> Color:
	if category == Category.FENCE:
		return FENCE_OUTLINE_COLOR
	return OUTLINE_COLOR

static func should_skip_mesh(mesh_name: String) -> bool:
	var lower := mesh_name.to_lower()
	for sub in SKIP_SUBSTRINGS:
		if lower.contains(sub):
			return true
	return false
