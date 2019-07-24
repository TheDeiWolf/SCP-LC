AddCSLuaFile()

ENT.Type = "anim"
ENT.DieTime = 0
ENT.HP = 100
ENT.Used = false

function ENT:Initialize()
	self:DrawShadow( false )
	self:SetModel( "models/hunter/plates/plate05x05.mdl" )

	if SERVER then
		self:SetMoveType( MOVETYPE_NONE )
		self:PhysicsInit( SOLID_NONE )

		self:SetTrigger( true )
	end

	if CLIENT then
		local tr = util.TraceLine{
			start = self:GetPos() + Vector( 0, 0, 10 ),
			endpos = self:GetPos() - Vector( 0, 0, 10 ),
			mask = MASK_SOLID_BRUSHONLY,
		}

		self.RenderPos = tr.HitPos
		self.RenderAng = tr.HitNormal:Angle()
	end

	self:SetCollisionBounds( Vector( -16, -16, 0 ), Vector( 16, 16, 32 ) )
	self:UseTriggerBounds( true, 16 )
end

function ENT:Think()
	if SERVER then
		if self.DieTime != -1 and self.DieTime <= CurTime() then
			self:Remove()
		end
	end
end

function ENT:StartTouch( ent )
	if ent:IsPlayer() then
		local t = ent:SCPTeam()
		if t == TEAM_SPEC or t == TEAM_SCP then return end

		self:TriggerIgnite()
	end
end

function ENT:OnTakeDamage( dmg )
	self.HP = self.HP - dmg:GetDamage()

	if self.HP <= 0 then
		self:TriggerIgnite()
	end
end

function ENT:TriggerIgnite()
	if self.Used then return end
	self.Used = true

	local fire = ents.Create( "slc_entity_fire" )
	fire:SetPos( self:GetPos() )

	local owner = self:GetOwner()
	if IsValid( owner ) and owner:IsPlayer() and owner:SCPClass() == CLASSES.SCP457 then
		fire:SetOwner( owner )
	end
	
	fire:SetBurnTime( 1.5 )
	fire:SetFireRadius( 100 )
	fire:SetFireDamage( 5 )
	fire:Spawn()

	self:EmitSound( "FireTrap.Ignite" )
	self:Remove()
end

local mat = Material( "slc/457trap" )
function ENT:Draw()
	--self:DrawModel()

	cam.Start3D2D( self.RenderPos, self.RenderAng + Angle( 90, 0, 0 ), 0.4 )
		surface.SetDrawColor( Color( 255, 255, 255, 255 ) )
		surface.SetMaterial( mat )
		surface.DrawTexturedRect( -64, -64, 128, 128 )
	cam.End3D2D()
end

function ENT:SetLifeTime( time )
	if time < 0 then
		self.DieTime = -1
	else
		self.DieTime = CurTime() + time
	end
end

sound.Add{
	name = "FireTrap.Ignite",
	sound = "ambient/fire/ignite.wav",
	volume = 1,
	level = 85,
	pitch = 90,
	channel = CHAN_STATIC,
}