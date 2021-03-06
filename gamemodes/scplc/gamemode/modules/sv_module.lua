--[[-------------------------------------------------------------------------
Gamemode hooks
---------------------------------------------------------------------------]]
function GM:PlayerSpray( ply )
	return true

	/*if ply:GTeam() == TEAM_SPEC then
		return true
	end

	if ply:GetPos():WithinAABox( POCKETD_MINS, POCKETD_MAXS ) then
		ply:PrintMessage( HUD_PRINTCENTER, "You can't use spray in Pocket Dimension" )
		return true
	end*/
end

function GM:ShutDown()
	--
end

function GM:SCPDamage( ply, ent, dmg )
	if IsValid( ply ) and IsValid( ent ) then
		if ent:GetClass() == "func_breakable" then
			ent:TakeDamage( dmg, ply, ply )
			return true
		end
	end
end

function GM:OnEntityCreated( ent )
	ent:SetShouldPlayPickupSound( false )
end

function GM:GetFallDamage( ply, speed )
	//print( speed )

	return 1
end

/*function OnUseEyedrops(ply) --TODO
	if ply.usedeyedrops == true then
		ply:PrintMessage(HUD_PRINTTALK, "Don't use them that fast!")
		return
	end
	ply.usedeyedrops = true
	ply:StripWeapon("item_eyedrops")
	ply:PrintMessage(HUD_PRINTTALK, "Used eyedrops, you will not be blinking for 10 seconds")
	timer.Create("Unuseeyedrops" .. ply:SteamID64(), 10, 1, function()
		ply.usedeyedrops = false
		ply:PrintMessage(HUD_PRINTTALK, "You will be blinking now")
	end)
end*/

local doorBlockers = {}
function AddDoorBlocker( class )
	table.insert( doorBlockers, class )
end

function GM:SLCOnDoorClosed()
	local activator, caller = ACTIVATOR, CALLER

	if CVAR.doorunblocker:GetBool() then
		local name = activator:GetName()
		if name and string.match( name, "_door_1_" ) then
			local dpos = activator:GetPos() - Vector( 0, 0, 55.5 )
			local forward = activator:GetKeyValues().movedir

			dpos = dpos + forward * -32
			local radius = forward * -55

			local mins = dpos * 1
			local maxs = mins + radius
			OrderVectors( mins, maxs )

			mins = mins - Vector( 0, 0, 0 ) 
			maxs = maxs + Vector( 0, 0, 32 )

			local found = ents.FindInBox( mins, maxs )
			if #found > 0 then
				local rdot = radius:Dot( radius )
				local up = Vector( 0, 0, 16 )

				for k, v in pairs( found ) do
					local pos = v:GetPos()
					pos.z = dpos.z --hack?

					for k, bl in pairs( doorBlockers ) do
						if string.find( v:GetClass(), bl ) then

							local frac = 0
							if rdot != 0 then
								frac = (pos - dpos):Dot( radius ) / rdot --fraction
							end
							local pline = (dpos + radius * frac) --point on line
							local vec = pos - pline --vector pointing from pline to item
							vec:Normalize() --normalize it so we can multiply it

							v:SetPos( pline + vec * 64 + up ) --set object pos 64 units away from door, perpendicularly to door
							v:PhysWake()
							//print( frac, vec, dpos + radius * frac, pos + norm * 32 )
						end
					end
				end
			end
		end
	end
end

AddDoorBlocker( "^item_slc_" )
AddDoorBlocker( "^weapon_" )
AddDoorBlocker( "^cw_" )

hook.Add( "PlayerPostThink", "WeaponHolsterThink", function( ply )
	local active = ply:GetActiveWeapon()
	for k, v in pairs( ply:GetWeapons() ) do
		if IsValid( v ) and v != active then
			if v.EnableHolsterThink and v.HolsterThink then
				v:HolsterThink()
			end
		end
	end
end )

--[[-------------------------------------------------------------------------
Misc functions
---------------------------------------------------------------------------]]
function GetActivePlayers()
	local tab = {}

	for i, v in ipairs( player.GetAll() ) do
		if v:IsActive() then
			table.insert( tab, v )
		end
	end

	return tab
end

function GetAlivePlayers()
	return SCPTeams.getPlayersByInfo( SCPTeams.INFO_ALIVE )
end

function PlayerMessage( msg, ply, center )
	if !msg or msg == "" then return end
	if ply and !IsValid( ply ) then return end

	net.Start( "PlayerMessage" )
	net.WriteString( msg )
	net.WriteBool( center or false )

	if ply then
		net.Send( ply )
	else
		net.Broadcast()
	end
end

function CenterMessage( msg, ply )
	if !msg or msg == "" then return end
	if ply and !IsValid( ply ) then return end

	net.Start( "CenterMessage" )
	net.WriteString( msg )

	if ply then
		net.Send( ply )
	else
		net.Broadcast()
	end
end

function InfoScreen( ply, t, duration, data, ovteam, ovclass )
	if type( ply ) == "Player" then
		net.SendTable( "SLCInfoScreen", {
			type = t,
			time = duration,
			data = data,
			team = ovteam or ply:SCPTeam(),
			class = ovclass or ply:SCPClass(),
		}, ply )
	end
end

local blinkdelay = CVAR.blink:GetInt()
Timer( "PlayerBlink", blinkdelay, 0, function( self, n )
	local ntime = CVAR.blink:GetInt()
	if blinkdelay != ntime then
		blinkdelay = ntime
		self:Change( ntime )
	end

	local plys = {}

	for k, v in pairs( SCPTeams.getPlayersByInfo( SCPTeams.INFO_HUMAN ) ) do
		if !v:GetBlink() then
			v:SetBlink( true )
			table.insert( plys, v )
		end
	end

	net.Start( "PlayerBlink" )
		net.WriteFloat( 0.25 )
		net.WriteUInt( blinkdelay, 6 )
	net.Send( plys )

	timer.Create( "PlayerUnBlink", 0.4, 1, function()
		for k, v in pairs( plys ) do
			if IsValid( v ) then
				v:SetBlink( false )
			end
		end
	end )

	hook.Run( "SLCBlink", 0.25, blinkdelay )
end )

Timer( "PlayXP", 300, 0, function()
	local pspec, pplay, pplus = string.match( CVAR.roundxp:GetString(), "(%d+),(%d+),(%d+)" )

	pspec = tonumber( pspec )
	pplay = tonumber( pplay )
	pplus = tonumber( pplus )

	local rt = GetTimer( "SLCRound" )
	if IsValid( rt ) then
		local plus = rt:GetRemainingTime() <= rt:GetTime() * 0.5

		for k, v in pairs( player.GetAll() ) do
			if SCPTeams.hasInfo( v:SCPTeam(), SCPTeams.INFO_ALIVE ) then
				if plus then
					v:AddXP( pplus )
					PlayerMessage( "rxpplus$"..pplus, v )
				else
					v:AddXP( pplay )
					PlayerMessage( "rxpplay$"..pplay, v )
				end
			else
				v:AddXP( pspec )
				PlayerMessage( "rxpspec$"..pspec, v )
			end
		end
	else
		for k, v in pairs( player.GetAll() ) do
			v:AddXP( pspec )
			PlayerMessage( "rxpspec$"..pspec, v )
		end
	end
end )

--TransmitSound( snd, status, player, volume )
--TransmitSound( snd, status, vector, radius )
--TransmitSound( snd, status, volume )
function TransmitSound( snd, status, arg1, arg2 )
	if isvector( arg1 ) then
		for k, v in pairs( player.GetAll() ) do
			if IsValid( v ) then
				local dist = v:GetPos():Distance( arg1 )

				if dist <= arg2 then
					net.Start( "PlaySound" )
						net.WriteBool( status )
						net.WriteFloat( 1 - dist / arg2 )
						net.WriteString( snd )
					net.Send( v )
				end
			end
		end
	elseif isentity( arg1 ) and IsValid( arg1 ) and arg1:IsPlayer() or istable( arg1 ) then
		net.Start( "PlaySound" )
			net.WriteBool( status )
			net.WriteFloat( arg2 or 1 )
			net.WriteString( snd )
		net.Send( arg1 )
	else
		net.Start( "PlaySound" )
			net.WriteBool( status or false )
			net.WriteFloat( arg1 or 1 )
			net.WriteString( snd )
		net.Broadcast()
	end
end

function BroadcastDetection( ply, tab )
	local transmit = { ply }
	local radio = ply:GetWeapon( "item_slc_radio" )

	if IsValid( radio ) and radio:GetEnabled() then
		local ch = radio:GetChannel()

		for k, v in pairs( player.GetAll() ) do
			if v:SCPTeam() != TEAM_SCP and v:SCPTeam() != TEAM_SPEC and v != ply then
				local r = v:GetWeapon( "item_slc_radio" )
				if IsValid( r ) and r:GetEnabled() and r:GetChannel() == ch then
					table.insert( transmit, v )
				end
			end
		end
	end

	local info = {}

	for k, v in pairs( tab ) do
		table.insert( info, {
			name = v:SCPClass(),
			pos = v:GetPos() + v:OBBCenter()
		} )
	end

	net.Start( "CameraDetect" )
		net.WriteTable( info )
	net.Send( transmit )
end

function ServerSound( file, ent, filter )
	ent = ent or game.GetWorld()
	if !filter then
		filter = RecipientFilter()
		filter:AddAllPlayers()
	end

	local sound = CreateSound( ent, file, filter )

	return sound
end

hook.Add( "PostGamemodeLoaded", "SCPLCLightStyle", function()
	timer.Simple( 0, function()
		engine.LightStyle( 0, "g" )
	end )
end )

concommand.Add( "slc_debuginfo", function( ply, cmd, args )
	if !IsValid( ply ) or ply:IsListenServerHost() then
		print( "=== DEBUG INFO ===" )
		print( "Round:" )
		PrintTable( ROUND, 1 )
		print( "\nPlayers" )
		for k, v in pairs( player.GetAll() ) do
			print( "->", v, v:Nick(), v:SteamID() )
			print( "\tGeneral info -> ", v:SCPTeam(), v:SCPClass(), v:Alive(), v:GetModel(), v:GetObserverMode(), v:GetObserverTarget() )
			print( "\tSpeed -> ", v:GetWalkSpeed(), v:GetRunSpeed(), v:GetCrouchedWalkSpeed() )
			if v.SpeedStack then PrintTable( v.SpeedStack, 2 ) end
			print( "\tInventory ->" )
			PrintTable( v:GetWeapons(), 2 )
			print( "\tPData ->" )
			PrintTable( v.PlayerData.Status, 2 )
			print( "\tSCPVars ->" )
			PrintTable( v.scp_var_table, 2 )
			print( "\tMisc -> ", v:IsBurning(), v:GetVest() )
			print( "--------------------" )
		end
		print( "==================" )
	end
end )

concommand.Add( "slc_lightstyle", function( ply, cmd, args )
	if !IsValid( ply ) or ply:IsListenServerHost() then
		--for i = 0, 31 do
			engine.LightStyle( 0, args[1] )
		--end

		BroadcastLua( "render.RedownloadAllLightmaps( true )" )
	end
end )