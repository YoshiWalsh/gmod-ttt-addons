
if SERVER then
   AddCSLuaFile( "shared.lua" )
   
end

SWEP.HoldType = "grenade"


if CLIENT then
   SWEP.PrintName = "Finger Butterer"
   SWEP.Slot = 3
   SWEP.SlotPos	= 0

   SWEP.Icon = "VGUI/ttt/icon_nades"
end

SWEP.Base				= "weapon_tttbasegrenade"

SWEP.Kind = WEAPON_NADE

SWEP.CanBuy = { ROLE_TRAITOR }

SWEP.LimitedStock = false

SWEP.EquipMenuData = {
   type = "Grenade",
   desc = "The bigger brother of the discombobulator.\nSo powerful that it will blast the weapons right out of the hands of your foes, and yet delicate enough to not inflict any damage.\nUseful for causing mass panic and mayhem.\nDeveloped by Joshua Walsh (YM_Industries)."
};

SWEP.Spawnable = false
SWEP.AdminSpawnable = true


SWEP.AutoSpawnable      = false

SWEP.ViewModel			= "models/weapons/v_eq_fraggrenade.mdl"
SWEP.WorldModel			= "models/weapons/w_eq_fraggrenade.mdl"
SWEP.Weight			= 5

-- really the only difference between grenade weapons: the model and the thrown
-- ent.

function SWEP:GetGrenadeName()
   return "ttt_dropgrenade_proj"
end

