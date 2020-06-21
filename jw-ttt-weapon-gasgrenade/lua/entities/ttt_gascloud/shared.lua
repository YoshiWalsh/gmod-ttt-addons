
if SERVER then
   AddCSLuaFile("shared.lua")
end

ENT.Type = "point"
--ENT.Base = "ttt_basegrenade_proj"
--ENT.Model = Model("models/weapons/w_eq_smokegrenade_thrown.mdl")

AccessorFunc( ENT, "radius", "Radius", FORCE_NUMBER )

function ENT:Initialize()
   if not self:GetRadius() then self:SetRadius(20) end
	self.lifeleft = 45
   return self.BaseClass.Initialize(self)
end

if CLIENT then

   local smokeparticles = {
      Model("particle/particle_smokegrenade"),
      Model("particle/particle_noisesphere")
   };

   function ENT:CreateSmoke(center)
      local em = ParticleEmitter(center)

      local r = self:GetRadius()
      for i=1, 20 do
         local prpos = VectorRand() * r
         prpos.z = prpos.z + 32
         local p = em:Add(table.Random(smokeparticles), center + prpos)
         if p then
            local gray = math.random(90, 230)
            p:SetColor(gray*0.9, gray, gray*0.4)
            p:SetStartAlpha(255)
            p:SetEndAlpha(50)
            p:SetVelocity(VectorRand() * math.Rand(900, 1300))
            p:SetLifeTime(0)
            
            p:SetDieTime(math.Rand(40, 50))

            p:SetStartSize(math.random(140, 150))
            p:SetEndSize(math.random(1, 40))
            p:SetRoll(math.random(-180, 180))
            p:SetRollDelta(math.Rand(-0.1, 0.1))
            p:SetAirResistance(600)

            p:SetCollide(true)
            p:SetBounce(0.4)

            p:SetLighting(false)
         end
      end

      em:Finish()
   end
end

function ENT:Think()
	if self.next_hurt~=nil then
		if self.next_hurt < CurTime() then
			-- deal damage

			local dmg = DamageInfo()
			dmg:SetDamageType(DMG_NERVEGAS)
			dmg:SetDamage(math.random(25,45))
			dmg:SetAttacker(self)
			dmg:SetInflictor(self)
	 
			RadiusDamageCloud(dmg, self:GetPos(), 240, self)

			self.next_hurt = CurTime() + 1
			self.lifeleft = self.lifeleft-1
			if self.lifeleft <= 0 then
				self:Remove()
			end
		end
	else
		self.next_hurt = CurTime()+1.5
		if CLIENT then
			self:CreateSmoke(self:GetPos())
		end
	end
	return self.BaseClass.Think(self)
end

function RadiusDamageCloud(dmginfo, pos, radius, inflictor)
	if SERVER then
	   local victims = ents.FindInSphere(pos, radius)

	   local tr = nil
	   for k, vic in pairs(victims) do
		  if IsValid(vic) then
			 if vic:IsPlayer() and vic:Alive() and vic:Team() == TEAM_TERROR then
				--print(vic:Nick())
				pos2 = vic:GetPos()
				local dmgScale = pos:Distance(pos2)
				dmgScale = dmgScale/(radius)
				dmgScale = 1 - dmgScale
				dmgScale2 = inflictor.lifeleft/48
				local thisdmg = dmginfo
				thisdmg:SetDamage(thisdmg:GetDamage()*dmgScale*dmgScale2)
				vic:TakeDamageInfo(dmginfo)
			 end
		  end
	   end
   end
end
