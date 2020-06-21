
if SERVER then
   AddCSLuaFile( "shared.lua" )
end

SWEP.HoldType = "normal"

if CLIENT then
   SWEP.PrintName			= "Rollermine"
   SWEP.Slot				= 7

   SWEP.ViewModelFOV = 10

   SWEP.EquipMenuData = {
      type = "item_weapon",
      desc = "A traitors best friend; a perfect companion.\nSad? Lonely? Rollermines are loving pets that can help you through a difficult time.\nCAUTION: May cause injuries or death.\nRollermines won't hurt their owners, but they don't understand the concept of teams so they may hurt other traitors.\nDeveloped by Joshua Walsh (YM_Industries)."
   };

   --SWEP.Icon = "VGUI/ttt/icon_beacon"
end

SWEP.Base = "weapon_tttbase"

SWEP.ViewModel          = "models/weapons/v_crowbar.mdl"
SWEP.WorldModel         = "models/props_lab/reciever01b.mdl"

SWEP.DrawCrosshair      = false
SWEP.ViewModelFlip      = false

SWEP.Primary.ClipSize       = -1
SWEP.Primary.DefaultClip    = -1
SWEP.Primary.Automatic      = true
SWEP.Primary.Ammo       = "none"
SWEP.Primary.Delay = 1.0

SWEP.Secondary.ClipSize     = -1
SWEP.Secondary.DefaultClip  = -1
SWEP.Secondary.Automatic    = true
SWEP.Secondary.Ammo     = "none"
SWEP.Secondary.Delay = 1.0

SWEP.Kind = WEAPON_EQUIP2
SWEP.CanBuy = {ROLE_TRAITOR}
SWEP.LimitedStock = false -- only buyable once


SWEP.AllowDrop = false

SWEP.NoSights = true

function SWEP:OnDrop()
   self:Remove()
end

function SWEP:PrimaryAttack()
   self.Weapon:SetNextPrimaryFire( CurTime() + self.Primary.Delay )

   self:DropRollermine()
end
function SWEP:SecondaryAttack()
   self.Weapon:SetNextSecondaryFire( CurTime() + self.Secondary.Delay )

   self:DropRollermine()
end

local throwsound = Sound( "Weapon_SLAM.SatchelThrow" )

function SWEP:DropRollermine()
   if SERVER then
      local ply = self.Owner
      if not IsValid(ply) then return end

      if self.Planted then return end

      local vsrc = ply:GetShootPos()
      local vang = ply:GetAimVector()
      local vvel = ply:GetVelocity()
      
      local vthrow = vvel + vang * 200

      local rollermine = ents.Create("npc_rollermine")
      if IsValid(rollermine) then
         rollermine:SetPos(vsrc + vang * 10)
         rollermine:SetOwner(ply)
         rollermine:Spawn()

         rollermine:PhysWake()
         local phys = rollermine:GetPhysicsObject()
         if IsValid(phys) then
            phys:SetVelocity(vthrow)
         end   

         self:PlacedRollermine(rollermine)
      end
   end

   self.Weapon:EmitSound(throwsound)
end

function SWEP:PlacedRollermine(rollermine)
   self:TakePrimaryAmmo(1)

   if not self:CanPrimaryAttack() then
      self:Remove()

      self.Planted = true
   end
end

function SWEP:Reload()
   return false
end

function SWEP:OnRemove()
   if CLIENT and IsValid(self.Owner) and self.Owner == LocalPlayer() and self.Owner:Alive() then
      RunConsoleCommand("lastinv")
   end
end

if CLIENT then
   function SWEP:Initialize()
      return self.BaseClass.Initialize(self)
   end
end

function SWEP:Deploy()
   self.Owner:DrawViewModel(false)
   return true
end

function SWEP:DrawWorldModel()
   if not IsValid(self.Owner) then
      self:DrawModel()
   end
end

function SWEP:DrawWorldModelTranslucent()
end
