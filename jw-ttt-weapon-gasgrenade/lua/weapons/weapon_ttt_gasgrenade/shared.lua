
if SERVER then
   AddCSLuaFile( "shared.lua" )
end
   
SWEP.HoldType			= "grenade"

if CLIENT then
   SWEP.PrintName = "Gas Grenade"
   SWEP.Slot = 3

   SWEP.Icon = "VGUI/ttt/icon_nades"
end

SWEP.Base				= "weapon_tttbasegrenade"
SWEP.EquipMenuData = {
   type = "Weapon",
   desc = "Chemical weapons might be outlawed by the Geneva Convention, but that only applies to wars. Designed for use by riot squads to break up unlawful gatherings, this law-enforcement-favourite also happens to be very useful for traitors who wish to perform their own crowd control.\nIdea by Stooge, developed by Joshua Walsh (YM_Industries)."
};
SWEP.Spawnable = false
SWEP.CanBuy = { ROLE_TRAITOR }
SWEP.LimitedStock = false
SWEP.AdminSpawnable = true

SWEP.Kind = WEAPON_NADE

SWEP.ViewModel			= "models/weapons/v_eq_smokegrenade.mdl"
SWEP.WorldModel			= "models/weapons/w_eq_smokegrenade.mdl"
SWEP.Weight			= 5
SWEP.AutoSpawnable      = false
-- really the only difference between grenade weapons: the model and the thrown
-- ent.

function SWEP:GetGrenadeName()
   return "ttt_gasgrenade_proj"
end
