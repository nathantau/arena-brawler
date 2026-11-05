class_name DmgExpect
extends RefCounted
## Test helper: the bounds a `CombatRules.scaled` hit of base `damage` must land in, derived from the constants
## (stochastic rounding lands on floor or ceil of the exact product, so exact hits are asserted as a range).


static func exact(damage: float, rarity: int = 0, ult: bool = false) -> float:
	var x: float = damage * Constants.DAMAGE_MULT * Constants.RARITY_DAMAGE_MULT[rarity]
	return x * Constants.ULT_DAMAGE_MULT if ult else x


static func lo(damage: float, rarity: int = 0, ult: bool = false) -> int:
	return maxi(1, floori(exact(damage, rarity, ult) + 0.0001))


static func hi(damage: float, rarity: int = 0, ult: bool = false) -> int:
	return maxi(1, ceili(exact(damage, rarity, ult) - 0.0001))
