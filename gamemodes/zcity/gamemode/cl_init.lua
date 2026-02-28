zb = zb or {}
include("shared.lua")
include("loader.lua")
include("cl_anticheat.lua")

if not ConVarExists("hg_newspectate") then
    CreateClientConVar("hg_newspectate", "1", true, false, "Enables smooth spectator camera transitions", 0, 1)
end

function CurrentRound()
	return zb.modes[zb.CROUND]
end

zb.ROUND_STATE = 0
--0 = players can join, 1 = round is active, 2 = endround
local vecZero = Vector(0.2, 0.2, 0.2)
local vecFull = Vector(1, 1, 1)
spect,prevspect,viewmode = nil,nil,1
local hullscale = Vector(0,0,0)
net.Receive("ZB_SpectatePlayer", function(len)
	spect = net.ReadEntity()
	prevspect = net.ReadEntity()
	viewmode = net.ReadInt(4)

	timer.Simple(0.1,function()
		LocalPlayer():BoneScaleChange()
		LocalPlayer():SetHull(-hullscale,hullscale)
		LocalPlayer():SetHullDuck(-hullscale,hullscale)

		if viewmode == 3 then
			LocalPlayer():SetMoveType(MOVETYPE_NOCLIP)
		end
	end)
end)

zb.ROUND_TIME = zb.ROUND_TIME or 400
zb.ROUND_START = zb.ROUND_START or CurTime()
zb.ROUND_BEGIN = zb.ROUND_BEGIN or CurTime() + 5
zb.CURRENT_TIME = zb.CURRENT_TIME or os.date("%H:%M")

net.Receive("updtime",function()
	local time = net.ReadFloat()
	local time2 = net.ReadFloat()
	local time3 = net.ReadFloat()

	zb.ROUND_TIME = time
	zb.ROUND_START = time2
	zb.ROUND_BEGIN = time3
end)

net.Receive("updatetime", function()
	zb.CURRENT_TIME = net.ReadString()
end)

local blur = Material("pp/blurscreen")
local blur2 = Material("effects/shaders/zb_blur" )
local blursettings = {}
local hg_potatopc
hg = hg or {}
function hg.DrawBlur(panel, amount, passes, alpha)
	if is3d2d then return end
	amount = amount or 5
	hg_potatopc = hg_potatopc or hg.ConVars.potatopc

	// old blur
	if(hg_potatopc:GetBool())then
		surface.SetDrawColor(0, 0, 0, alpha or (amount * 20))
		surface.DrawRect(0, 0, panel:GetWide(), panel:GetTall())
	else
		surface.SetMaterial(blur)
		surface.SetDrawColor(0, 0, 0, alpha or 125)
		surface.DrawRect(0, 0, panel:GetWide(), panel:GetTall())
		local x, y = panel:LocalToScreen(0, 0)
		if blursettings and blursettings[1] == amount and blursettings[2] == passes then
			render.UpdateScreenEffectTexture()
			surface.DrawTexturedRect(x * -1, y * -1, ScrW(), ScrH())
			return
		end
		blursettings = {amount, passes}
		for i = -(passes or 0.2), 1, 0.2 do
			blur:SetFloat("$blur", i * amount)
			blur:Recompute()

			render.UpdateScreenEffectTexture()
			surface.DrawTexturedRect(x * -1, y * -1, ScrW(), ScrH())
		end
	end
end

BlurBackground = BlurBackground or hg.DrawBlur

local keydownattack
local keydownattack2
local keydownreload

hook.Add("HUDPaint","FUCKINGSAMENAMEUSEDINHOOKFUCKME",function()
    if LocalPlayer():Alive() then return end
	local spect = LocalPlayer():GetNWEntity("spect")
	if not IsValid(spect) then return end
	if viewmode == 3 then return end
	
	surface.SetFont("HomigradFont")
	surface.SetTextColor(255, 255, 255, 255)
	local txt = "Spectating player: "..spect:Name()
	local w, h = surface.GetTextSize(txt)
	surface.SetTextPos(ScrW() / 2 - w / 2, ScrH() / 8 * 7)
	surface.DrawText(txt)
	local txt = "In-game name: "..spect:GetPlayerName()
	local w, h = surface.GetTextSize(txt)
	surface.SetTextPos(ScrW() / 2 - w / 2, ScrH() / 8 * 7 + h)
	surface.DrawText(txt)
end)

hook.Add("HG_CalcView", "zzzzzzzUwU", function(ply, pos, angles, fov)
	if not lply:Alive() then
		if lply:KeyDown(IN_ATTACK) then
			if not keydownattack then
				keydownattack = true
				net.Start("ZB_ChooseSpecPly")
				net.WriteInt(IN_ATTACK,32)
				net.SendToServer()
			end
		else
			keydownattack = false
		end

		if lply:KeyDown(IN_ATTACK2) then
			if not keydownattack2 then
				keydownattack2 = true
				net.Start("ZB_ChooseSpecPly")
				net.WriteInt(IN_ATTACK2,32)
				net.SendToServer()
			end
		else
			keydownattack2 = false
		end

		if lply:KeyDown(IN_RELOAD) then
			if not keydownreload then
				keydownreload = true
				net.Start("ZB_ChooseSpecPly")
				net.WriteInt(IN_RELOAD,32)
				net.SendToServer()
			end
		else
			keydownreload = false
		end

		local spect = lply:GetNWEntity("spect",spect)
		if not IsValid(spect) then return end

		local viewmode = lply:GetNWInt("viewmode",viewmode)
		
		if viewmode == 3 then
			if lply:GetMoveType()!=MOVETYPE_NOCLIP then
				lply:SetMoveType(MOVETYPE_NOCLIP)
			end
			lply:SetObserverMode(OBS_MODE_ROAMING)
			return
		else
			lply:SetPos(spect:GetPos())
		end
		
		local ent = hg.GetCurrentCharacter(spect)
		if not IsValid(ent) then return end
		
		local headBone = ent:LookupBone("ValveBiped.Bip01_Head1") or ent:LookupBone("ValveBiped.Bip01_Spine1") or 1
		local bon = ent:GetBoneMatrix(headBone)
		
		if not bon then 
			local eyePos = ent:EyePos()
			if eyePos and eyePos ~= vector_origin then
				pos = eyePos
				ang = ent:EyeAngles()
			else
				pos = ent:GetPos() + Vector(0, 0, 64)
				ang = ent:GetAngles()
			end
		else
			pos, ang = bon:GetTranslation(), bon:GetAngles()
		end

		local eyePos, eyeAng = lply:EyePos(), lply:EyeAngles()
		
		local tr = {}
		tr.start = pos
		tr.endpos = pos + eyeAng:Forward() * -120
		tr.filter = {ent, lply, spect}
		tr.mins = Vector(-4, -4, -4)
		tr.maxs = Vector(4, 4, 4)
		tr = util.TraceHull(tr)

		if viewmode == 2 then
			pos = tr.HitPos + eyeAng:Forward() * 8
			ang = eyeAng
		elseif viewmode == 1 then
			if ent ~= spect and IsValid(ent) then
				local eyeAtt = ent:GetAttachment(ent:LookupAttachment("eyes"))
				if eyeAtt then
					ang = eyeAtt.Ang
				else
					ang = spect:EyeAngles()
				end
			else
				ang = spect:EyeAngles()
			end
			pos = pos + spect:EyeAngles():Forward() * 8
		else
			pos = eyePos
			ang = eyeAng
		end
		
		ang[3] = 0
		
		local view
		local hg_newspectate = GetConVar("hg_newspectate")
		if hg_newspectate and hg_newspectate:GetBool() then
			if not lply.spectLastPos then
				lply.spectLastPos = pos
				lply.spectLastAng = ang
			end
			
			local lerpFactor = FrameTime() * 10
			lply.spectLastPos = LerpVector(lerpFactor, lply.spectLastPos, pos)
			lply.spectLastAng = LerpAngle(lerpFactor, lply.spectLastAng, ang)

			view = {
				origin = lply.spectLastPos,
				angles = lply.spectLastAng,
				fov = fov,
			}
		else
			view = {
				origin = pos,
				angles = ang,
				fov = fov,
			}
		end

		return view
	else
		lply.spectLastPos = nil
		lply.spectLastAng = nil
		lply:SetObserverMode(OBS_MODE_NONE)
	end
end)

zb.fade = zb.fade or 0

hook.Add("RenderScreenspaceEffects", "huyhuyUwU", function()
	if zb.fade > 0 then
		zb.fade = math.Approach(zb.fade, 0, FrameTime() * 1)

		surface.SetDrawColor(0, 0, 0, 255 * math.min(zb.fade, 1))
		surface.DrawRect(-1, -1, ScrW() + 1, ScrH() + 1 )
	end
end)

zb.ROUND_STATE = 0
net.Receive("RoundInfo", function()
	local rnd = net.ReadString()
	
	hook.Run("RoundInfoCalled", rnd)

	if zb.CROUND ~= rnd then
		if hg.DynaMusic then
			hg.DynaMusic:Stop()
		end
	end

	zb.CROUND = rnd

	zb.ROUND_STATE = net.ReadInt(4)
	
	if zb.ROUND_STATE == 0 then
		zb.fade = 7
	end

	if zb.CROUND ~= "" then
		if CurrentRound() then
			if zb.ROUND_STATE == 3 then
				if CurrentRound().EndRound then
					CurrentRound():EndRound()
				end
			elseif zb.ROUND_STATE == 1 then
				if CurrentRound().RoundStart then
					CurrentRound():RoundStart()
				end
			end
		end
	end
end)

if IsValid(scoreBoardMenu) then
	scoreBoardMenu:Remove()
	scoreBoardMenu = nil
end

hook.Add("Player Disconnected","retrymenu",function(data)
	if IsValid(scoreBoardMenu) then
		scoreBoardMenu:Remove()
		scoreBoardMenu = nil
	end
end)

local hg_font = ConVarExists("hg_font") and GetConVar("hg_font") or CreateClientConVar("hg_font", "Bahnschrift", true, false, "change every text font to selected because ui customization is cool")
local font = function()
    local usefont = "Bahnschrift"

    if hg_font:GetString() != "" then
        usefont = hg_font:GetString()
    end

    return usefont
end

surface.CreateFont("ZB_InterfaceSmall", {
    font = font(),
    size = ScreenScale(6),
    weight = 400,
    antialias = true
})

surface.CreateFont("ZB_InterfaceMedium", {
    font = font(),
    size = ScreenScale(10),
    weight = 400,
    antialias = true
})

surface.CreateFont("ZB_ScrappersMedium", {
    font = font(),
    size = ScreenScale(10),
    weight = 400,
    antialias = true
})

surface.CreateFont("ZB_InterfaceMediumLarge", {
    font = font(),
    size = 35,
    weight = 400,
    antialias = true
})

surface.CreateFont("ZB_InterfaceLarge", {
    font = font(),
    size = ScreenScale(20),
    weight = 400,
    antialias = true
})

surface.CreateFont("ZB_InterfaceHumongous", {
    font = font(),
    size = 200,
    weight = 400,
    antialias = true
})

hg.playerInfo = hg.playerInfo or {}

local function addToPlayerInfo(ply, muted, volume)
	hg.playerInfo[ply:SteamID()] = {muted and true or false, volume}

	local json = util.TableToJSON(hg.playerInfo)
	file.Write("zcity_muted.txt", json)

	if file.Exists("zcity_muted.txt", "DATA") then
		local json = file.Read("zcity_muted.txt", "DATA")

		if json then
			hg.playerInfo = util.JSONToTable(json)
		end
	end
end

gameevent.Listen("player_connect")
hook.Add("player_connect", "zcityhuy", function(data)
	if hg.playerInfo and hg.playerInfo[data.networkid] then
		Player(data.userid):SetMuted(hg.playerInfo[data.networkid][1])
		Player(data.userid):SetVoiceVolumeScale(hg.playerInfo[data.networkid][2])
	end
end)

hook.Add("InitPostEntity", "higgershuy", function()
	if file.Exists("zcity_muted.txt", "DATA") then
		local json = file.Read("zcity_muted.txt", "DATA")

		if json then
			hg.playerInfo = util.JSONToTable(json)
		end

		local plrs = player.GetAll()

		if hg.playerInfo then
			for i, ply in ipairs(plrs) do
				if not istable(hg.playerInfo[ply:SteamID()]) then
					local muted = hg.playerInfo[ply:SteamID()]
					hg.playerInfo[ply:SteamID()] = {}
					hg.playerInfo[ply:SteamID()][1] = muted
					hg.playerInfo[ply:SteamID()][2] = 1
				end

				if hg.playerInfo[ply:SteamID()] then
					ply:SetMuted(hg.playerInfo[ply:SteamID()][1])
					ply:SetVoiceVolumeScale(hg.playerInfo[ply:SteamID()][2])
				end
			end	
		end
	end
end)

local colGray = Color(122,122,122,255)
local colBlue = Color(130,10,10)
local colBlueUp = Color(160,30,30)
local col = Color(255,255,255,255)

local colSpect1 = Color(75,75,75,255)
local colSpect2 = Color(85,85,85,255)

local colorBG = Color(55,55,55,255)
local colorBGBlacky = Color(40,40,40,255)

hg.muteall = false
hg.mutespect = false

local function OpenPlayerSoundSettings(selfa, ply)
	local Menu = DermaMenu()
	
	if not hg.playerInfo[ply:SteamID()] or not istable(hg.playerInfo[ply:SteamID()]) then addToPlayerInfo(ply, false, 1) end

	local mute = Menu:AddOption( "Mute", function(self)
		if hg.muteall || hg.mutespect then return end
		
		self:SetChecked(not ply:IsMuted())
		ply:SetMuted( not ply:IsMuted() )
		selfa:SetImage(not ply:IsMuted() && "icon16/sound.png" || "icon16/sound_mute.png")
		addToPlayerInfo(ply, ply:IsMuted(), hg.playerInfo[ply:SteamID()][2])
	end )

	mute:SetIsCheckable( true )
	mute:SetChecked( ply:IsMuted() )
	local volumeSlider = vgui.Create("DSlider", Menu)
	volumeSlider:SetLockY( 0.5 )
	volumeSlider:SetTrapInside( true )
	volumeSlider:SetSlideX(hg.playerInfo[ply:SteamID()][2]) 
	volumeSlider.OnValueChanged = function(self, x, y)
		if not IsValid(ply) then return end
		if hg.muteall or (hg.mutespect && !ply:Alive()) then return end
		hg.playerInfo[ply:SteamID()][2] = x
		ply:SetVoiceVolumeScale(hg.playerInfo[ply:SteamID()][2])
		addToPlayerInfo(ply, ply:IsMuted(), hg.playerInfo[ply:SteamID()][2])
	end

	function volumeSlider:Paint(w,h)
		draw.RoundedBox( 0, 0, 0, w, h, Color( 0, 0, 0 ) )
		draw.RoundedBox( 0, 0, 0, w*self:GetSlideX(), h, Color( 255, 0, 0 ) )
		draw.DrawText( ( math.Round( 100*self:GetSlideX(), 0 ) ).."%", "DermaDefault", w/2, h/4, color_white, TEXT_ALIGN_CENTER )
	end
	function volumeSlider.Knob.Paint(self) end

	Menu:AddPanel(volumeSlider)
	Menu:Open()
end

hook.Add("Player Getup", "nomorespect", function(ply)
	if not hg.mutespect then return end

	ply:SetVoiceVolumeScale(!hg.muteall and (hg.playerInfo[ply:SteamID()] and hg.playerInfo[ply:SteamID()][2] or 1) or 0)
end)

hook.Add("Player_Death", "fixSpectatorVoiceMute", function(ply)
	if not hg.mutespect then return end

	ply:SetVoiceVolumeScale(0)
end)

hook.Add("Player_Death", "fixSpectatorVoiceEffect", function(ply)
	if eightbit and eightbit.EnableEffect and ply.UserID then
		eightbit.EnableEffect(ply:UserID(), 0)
	end
end)

-- Переменная для скрытия кармы
ZB_KarmaHidden = ZB_KarmaHidden or false

-- Команда для скрытия кармы
concommand.Remove("zb_hide_karma")
concommand.Add("zb_hide_karma", function()
    ZB_KarmaHidden = not ZB_KarmaHidden

    net.Start("ZB_ToggleKarmaVisibility")
        net.WriteBool(ZB_KarmaHidden)
    net.SendToServer()

    print("[Karma] Sent to server: " .. tostring(ZB_KarmaHidden))

    chat.AddText(ZB_KarmaHidden and Color(255, 200, 100) or Color(100, 255, 100),
        ZB_KarmaHidden and "Your karma is now hidden." or "Your karma is now visible.")
end)

-- Переменная для исчезновения из таба
ZB_Disappearance = ZB_Disappearance or false

-- Команда для исчезновения из таба
concommand.Remove("zb_hide_from_tab")
concommand.Add("zb_hide_from_tab", function()
    ZB_Disappearance = not ZB_Disappearance

    net.Start("ZB_ToggleDisappearance")
        net.WriteBool(ZB_Disappearance)
    net.SendToServer()

    print("[Disappearance] Sent to server: " .. tostring(ZB_Disappearance))

    chat.AddText(ZB_Disappearance and Color(255, 200, 100) or Color(100, 255, 100),
        ZB_Disappearance and "You are now hidden from the scoreboard." or "You are now visible on the scoreboard.")
end)

function GM:ScoreboardShow()
    if IsValid(scoreBoardMenu) then
        scoreBoardMenu:Remove()
        scoreBoardMenu = nil
    end
    Dynamic = 0
    scoreBoardMenu = vgui.Create("ZFrame")

    local sizeX, sizeY = ScrW() / 1.3, ScrH() / 1.2
    local posX, posY = ScrW() / 2 - sizeX / 2, ScrH() / 2 - sizeY / 2

    scoreBoardMenu:SetPos(posX, posY)
    scoreBoardMenu:SetSize(sizeX, sizeY)
    scoreBoardMenu:MakePopup()
    scoreBoardMenu:SetKeyboardInputEnabled(false)
    scoreBoardMenu:ShowCloseButton(false)

    -- Таблицы для хранения панелей игроков
    scoreBoardMenu.PlayerPanels = {}
    scoreBoardMenu.SpectatorPanels = {}
    scoreBoardMenu.LastUpdate = 0
    scoreBoardMenu.UpdateInterval = 0.5

    local butW, butH = ScreenScale(58), ScreenScale(8)
    local totalWidth = butW * 2 + 40
    local startX = (sizeX - totalWidth) / 2

    local muteallbut = vgui.Create("DButton", scoreBoardMenu)
    muteallbut:SetPos(startX, sizeY - butH - 20)
    muteallbut:SetSize(butW, butH)
    muteallbut:SetText("")
    
    muteallbut.Paint = function(self, w, h)
        local isHover = self:IsHovered()
        
        if hg.muteall then
            surface.SetDrawColor(0, 120, 0, isHover and 200 or 160)
        else
            surface.SetDrawColor(120, 0, 0, isHover and 200 or 160)
        end
        surface.DrawRect(0, 0, w, h)
        
        surface.SetDrawColor(255, 255, 255, 80)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        
        surface.SetFont("ZB_InterfaceSmall")
        surface.SetTextColor(255, 255, 255, 255)
        local text = hg.muteall and "Размутить Всех" or "Замутить Всех"
        local textW, textH = surface.GetTextSize(text)
        surface.SetTextPos(w/2 - textW/2, h/2 - textH/2)
        surface.DrawText(text)
    end

    muteallbut.DoClick = function(self)
        hg.muteall = not hg.muteall
        surface.PlaySound("UI/buttonclick.wav")
        
        for i, ply in ipairs(player.GetAll()) do
            if hg.muteall then
                ply:SetVoiceVolumeScale(0)
            else
                ply:SetVoiceVolumeScale((!hg.mutespect or ply:Alive()) and (hg.playerInfo[ply:SteamID()] and hg.playerInfo[ply:SteamID()][2] or 1) or 0)
            end
        end 
    end

    local mutespectbut = vgui.Create("DButton", scoreBoardMenu)
    mutespectbut:SetPos(startX + butW + 40, sizeY - butH - 20)
    mutespectbut:SetSize(butW, butH)
    mutespectbut:SetText("")
    
    mutespectbut.Paint = function(self, w, h)
        local isHover = self:IsHovered()
        
        if hg.mutespect then
            surface.SetDrawColor(0, 120, 0, isHover and 200 or 160)
        else
            surface.SetDrawColor(120, 60, 0, isHover and 200 or 160)
        end
        surface.DrawRect(0, 0, w, h)
        
        surface.SetDrawColor(255, 255, 255, 80)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        
        surface.SetFont("ZB_InterfaceSmall")
        surface.SetTextColor(255, 255, 255, 255)
        local text = hg.mutespect and "Размутить Спектаторов" or "Замутить Спектаторов"
        local textW, textH = surface.GetTextSize(text)
        surface.SetTextPos(w/2 - textW/2, h/2 - textH/2)
        surface.DrawText(text)
    end

    mutespectbut.DoClick = function(self)
        hg.mutespect = not hg.mutespect
        surface.PlaySound("UI/buttonclick.wav")
        
        for i, ply in ipairs(player.GetAll()) do
            if ply:Alive() then continue end

            if hg.mutespect then
                ply:SetVoiceVolumeScale(0)
            else
                ply:SetVoiceVolumeScale(!hg.muteall and (hg.playerInfo[ply:SteamID()] and hg.playerInfo[ply:SteamID()][2] or 1) or 0)
            end
        end 
    end

    local ServerName = GetHostName() or "ZCity | Developer Server | #01"
    local tick
    scoreBoardMenu.PaintOver = function(self, w, h)
        surface.SetDrawColor(0, 0, 0, 200)
        surface.DrawOutlinedRect(0, 0, w, h, 2.5)

        surface.SetFont("ZB_InterfaceLarge")
        local hue = (CurTime() * 100) % 360
        local rainbowColor = HSVToColor(hue, 1, 1)
        surface.SetTextColor(rainbowColor.r, rainbowColor.g, rainbowColor.b, 255)
        local lengthX, lengthY = surface.GetTextSize(ServerName)
        surface.SetTextPos(w / 2 - lengthX/2, 10)
        surface.DrawText(ServerName)

        surface.SetFont("ZB_InterfaceSmall")
        local hue = (CurTime() * 100) % 360
        local rainbowColor = HSVToColor(hue, 1, 1)
        surface.SetTextColor(rainbowColor.r, rainbowColor.g, rainbowColor.b, 255)
        local txt = "Z-TEAM 1.3.0"
        local lengthX, lengthY = surface.GetTextSize(txt)
        surface.SetTextPos(w * 0.01, h - lengthY - h * 0.01)
        surface.DrawText(txt)

        surface.SetFont("ZB_InterfaceMediumLarge")
        surface.SetTextColor(col.r, col.g, col.b, col.a)
        local lengthX, lengthY = surface.GetTextSize("Players:")
        surface.SetTextPos(w * 0.22 - lengthX/2, ScreenScale(25))
        surface.DrawText("Players:")

        surface.SetFont("ZB_InterfaceMediumLarge")
        surface.SetTextColor(col.r, col.g, col.b, col.a)
        local lengthX, lengthY = surface.GetTextSize("Spectators:")
        surface.SetTextPos(w * 0.82 - lengthX/2, ScreenScale(25))
        surface.DrawText("Spectators:")

        tick = math.Round(LerpFT(0.1, tick or 0, 1 / engine.ServerFrameTime()))
        local txt = "SV Tick: " .. tick
        local lengthX, lengthY = surface.GetTextSize(txt)
        surface.SetTextPos(w * 0.5 - lengthX/2, ScreenScale(25))
        surface.DrawText(txt)

        local currentTime = os.date("%H:%M")
        local txt2 = "Time: " .. currentTime
        local lengthX2, lengthY2 = surface.GetTextSize(txt2)
        surface.SetTextPos(w * 0.7 - lengthX2/2, ScreenScale(25))
        surface.DrawText(txt2)


    end

    if LocalPlayer():Team() ~= TEAM_SPECTATOR then
        local SPECTATE = vgui.Create("DButton", scoreBoardMenu)
        SPECTATE:SetPos(sizeX * 0.925, sizeY * 0.095)
        SPECTATE:SetSize(ScrW() / 20, ScrH() / 30)
        SPECTATE:SetText("")
        
        SPECTATE.DoClick = function()
            net.Start("ZB_SpecMode")
                net.WriteBool(true)
            net.SendToServer()
            scoreBoardMenu:Remove()
            scoreBoardMenu = nil
        end

        SPECTATE.Paint = function(self, w, h)
            surface.SetDrawColor(0, 0, 0, 180)
            surface.DrawRect(0, 0, w, h)
            surface.SetDrawColor(255, 255, 255, 80)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
            surface.SetFont("ZB_InterfaceMedium")
            surface.SetTextColor(col.r, col.g, col.b, col.a)
            local lengthX, lengthY = surface.GetTextSize("Join")
            surface.SetTextPos(w/2 - lengthX/2, h/2 - lengthY/2)
            surface.DrawText("Join")
        end
    end

    if LocalPlayer():Team() == TEAM_SPECTATOR then
        local PLAYING = vgui.Create("DButton", scoreBoardMenu)
        PLAYING:SetPos(sizeX * 0.010, sizeY * 0.095)
        PLAYING:SetSize(ScrW() / 20, ScrH() / 30)
        PLAYING:SetText("")
        
        PLAYING.DoClick = function()
            net.Start("ZB_SpecMode")
                net.WriteBool(false)
            net.SendToServer()
            scoreBoardMenu:Remove()
            scoreBoardMenu = nil
        end

        PLAYING.Paint = function(self, w, h)
            surface.SetDrawColor(0, 0, 0, 180)
            surface.DrawRect(0, 0, w, h)
            surface.SetDrawColor(255, 255, 255, 80)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
            surface.SetFont("ZB_InterfaceMedium")
            surface.SetTextColor(col.r, col.g, col.b, col.a)
            local lengthX, lengthY = surface.GetTextSize("Join")
            surface.SetTextPos(w/2 - lengthX/2, h/2 - lengthY/2)
            surface.DrawText("Join")
        end
    end

    local playersWidth = sizeX * 0.62
    local spectatorsWidth = sizeX * 0.35
    local headerHeight = ScreenScale(10)
    local panelStartY = ScreenScaleH(58) + headerHeight + 5
    local panelHeight = sizeY - ScreenScaleH(72) - butH - 40 - headerHeight

    -- ИСПРАВЛЕНО: правильные отступы
    local function FormatPlaytime(minutes)
        if not minutes then minutes = 0 end
        local hours = math.floor(minutes / 60)
        local mins = math.floor(minutes % 60)
        return string.format("%02d:%02d", hours, mins)
    end

    local function GetRankColor(rank)
        local rankColors = {
            ["superadmin"] = Color(255, 50, 50),
            ["admin"] = Color(255, 100, 100),
            ["moderator"] = Color(100, 150, 255),
            ["vip"] = Color(255, 215, 0),
        }
        return rankColors[rank] or nil
    end

    local function ShouldShowRank(rank)
        local showRanks = {
            ["superadmin"] = true,
            ["admin"] = true,
            ["moderator"] = true,
            ["vip"] = true,
        }
        return showRanks[rank] or false
    end

    local disappearance = lply:GetNetVar("disappearance", nil)

    local playersHeader = vgui.Create("DPanel", scoreBoardMenu)
    playersHeader:SetPos(10, ScreenScaleH(58))
    playersHeader:SetSize(playersWidth, headerHeight)
    playersHeader.Paint = function(self, w, h)
        surface.SetDrawColor(0, 0, 0, 200)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(255, 255, 255, 50)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        
        surface.SetFont("ZB_InterfaceSmall")
        surface.SetTextColor(200, 200, 200, 255)
        
        local _, textH = surface.GetTextSize("Name")
        local textY = h/2 - textH/2
        
        surface.SetTextPos(10, textY)
        surface.DrawText("Name")
        
        surface.SetTextPos(w * 0.38, textY)
        surface.DrawText("Rank")
        
    surface.SetTextPos(w * 0.52, textY)
    surface.DrawText("Karma")

    surface.SetTextPos(w * 0.66, textY)
    surface.DrawText("Ping")
    end

    local DScrollPanelPlayers = vgui.Create("DScrollPanel", scoreBoardMenu)
    DScrollPanelPlayers:SetPos(10, panelStartY)
    DScrollPanelPlayers:SetSize(playersWidth, panelHeight)
    
    function DScrollPanelPlayers:Paint(w, h)
        surface.SetDrawColor(0, 0, 0, 150)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(255, 255, 255, 50)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    -- Функция создания панели игрока
    local function CreatePlayerPanel(ply, parent, isSpectator)
        local but = vgui.Create("DButton", parent)
        but:SetSize(100, ScreenScaleH(26))
        but:Dock(TOP)
        but:DockMargin(8, 4, 8, 0)
        but:SetText("")

        local avatarSize = ScreenScaleH(24)
        local avatar = vgui.Create("AvatarImage", but)
        avatar:SetPos(2, 1)
        avatar:SetSize(avatarSize, avatarSize)
        avatar:SetPlayer(ply, 64)
        avatar:SetMouseInputEnabled(false)
        
        local avatarBorder = vgui.Create("DPanel", but)
        avatarBorder:SetPos(2, 1)
        avatarBorder:SetSize(avatarSize, avatarSize)
        avatarBorder:SetMouseInputEnabled(false)
        avatarBorder.Paint = function(self, w, h)
            local borderColor
            if ply:GetUserGroup() == "superadmin" then
                borderColor = HSVToColor((CurTime() * 100) % 360, 1, 1)
            else
                borderColor = isSpectator and Color(128, 128, 128, 100) or Color(255, 255, 255, 100)
            end
            surface.SetDrawColor(borderColor.r, borderColor.g, borderColor.b, borderColor.a)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
        end
        
        local iconSize = 16
        local soundButton = vgui.Create("DImageButton", but)
        soundButton:SetSize(iconSize, iconSize)
        soundButton:SetImage(not ply:IsMuted() and "icon16/sound.png" or "icon16/sound_mute.png")
        soundButton.DoClick = function(self)
            OpenPlayerSoundSettings(self, ply)
        end
        
        but.PerformLayout = function(self, w, h)
            soundButton:SetPos(w - iconSize - (isSpectator and 8 or 10), h/2 - iconSize/2)
        end
        
        but.PlayerData = {
            ply = ply,
            avatar = avatar,
            soundButton = soundButton,
            lastNick = ply:Nick(),
            lastPing = ply:Ping(),
            lastKarma = ply:GetNetVar("Karma", 100),
            lastPlaytime = ply:GetNWInt("Playtime", 0),
            lastKarmaHidden = ply:GetNetVar("KarmaHidden", false),
            lastRank = ply:GetUserGroup(),
            isSpectator = isSpectator
        }
        
        ply.soundButton = soundButton
    
        but.Paint = function(self, w, h)
            if not IsValid(ply) then return end
            
            surface.SetDrawColor(0, 0, 0, isSpectator and 160 or 180)
            surface.DrawRect(0, 0, w, h)

            local textStartX = avatarSize + 8

            surface.SetFont("ZB_InterfaceSmall")
            surface.SetTextColor(col.r, col.g, col.b, col.a)
            local name = ply:Nick() or "He quited..."
            local _, nameH = surface.GetTextSize(name)
            surface.SetTextPos(textStartX, h / 2 - nameH / 2)
            surface.DrawText(name)

            if not isSpectator then
                local rank = ply:GetUserGroup() or "user"
                if ShouldShowRank(rank) then
                    local rankColor
                    if rank == "superadmin" then
                        rankColor = HSVToColor((CurTime() * 100) % 360, 1, 1)
                    else
                        rankColor = GetRankColor(rank)
                    end
                    surface.SetFont("ZB_InterfaceSmall")
                    surface.SetTextColor(rankColor.r, rankColor.g, rankColor.b, 255)
                    local rankText = string.upper(rank)
                    local _, rankH = surface.GetTextSize(rankText)
                    surface.SetTextPos(w * 0.38, h/2 - rankH/2)
                    surface.DrawText(rankText)
                end

                local karma = math.Round(ply:GetNetVar("Karma", 100))
                local isLocalPlayer = ply == LocalPlayer()
                local karmaHidden = ply:GetNetVar("KarmaHidden", false)

                if karmaHidden and not isLocalPlayer then
                    surface.SetFont("ZB_InterfaceSmall")
                    surface.SetTextColor(100, 100, 100, 255)
                    local _, karmaH = surface.GetTextSize("?")
                    surface.SetTextPos(w * 0.68, h / 2 - karmaH / 2)
                    surface.DrawText("?")
                else
                    local karmaColor
                    if isLocalPlayer and karmaHidden then
                        karmaColor = karma >= 80 and Color(60, 150, 60) or (karma >= 50 and Color(150, 150, 60) or Color(150, 60, 60))
                    else
                        karmaColor = karma >= 80 and Color(100, 255, 100) or (karma >= 50 and Color(255, 255, 100) or Color(255, 100, 100))
                    end
                    
                    surface.SetFont("ZB_InterfaceSmall")
                    surface.SetTextColor(karmaColor.r, karmaColor.g, karmaColor.b, 255)
                    local karmaText = tostring(karma)
                    local _, karmaH = surface.GetTextSize(karmaText)
                    surface.SetTextPos(w * 0.52, h / 2 - karmaH / 2)
                    surface.DrawText(karmaText)
                end

                surface.SetFont("ZB_InterfaceSmall")
                surface.SetTextColor(col.r, col.g, col.b, col.a)
                local pingText = tostring(ply:Ping() or 0)
                local _, pingH = surface.GetTextSize(pingText)
                surface.SetTextPos(w * 0.66, h / 2 - pingH / 2)
                surface.DrawText(pingText)
            else
                local rank = ply:GetUserGroup() or "user"
                if ShouldShowRank(rank) then
                    local rankColor
                    if rank == "superadmin" then
                        rankColor = HSVToColor((CurTime() * 100) % 360, 1, 1)
                    else
                        rankColor = GetRankColor(rank)
                    end
                    surface.SetFont("ZB_InterfaceSmall")
                    surface.SetTextColor(rankColor.r, rankColor.g, rankColor.b, 255)
                    local rankText = string.upper(rank)
                    local _, rankH = surface.GetTextSize(rankText)
                    surface.SetTextPos(w * 0.50, h/2 - rankH/2)
                    surface.DrawText(rankText)
                end

                surface.SetFont("ZB_InterfaceSmall")
                surface.SetTextColor(col.r, col.g, col.b, col.a)
                local pingText = tostring(ply:Ping() or 0)
                local _, pingH = surface.GetTextSize(pingText)
                surface.SetTextPos(w * 0.72, h / 2 - pingH / 2)
                surface.DrawText(pingText)
            end
        end

        function but:DoClick()
            if ply:IsBot() then 
                chat.AddText(Color(255, 0, 0), isSpectator and "That bot." or "no, you can't") 
                return 
            end
            gui.OpenURL("https://steamcommunity.com/profiles/" .. ply:SteamID64())
        end

        function but:DoRightClick()
            local Menu = DermaMenu()
            Menu:AddOption("Account", function()
                zb.Experience.AccountMenu(ply)
            end)
            Menu:AddOption("Copy SteamID", function()
                SetClipboardText(ply:SteamID())
            end)
            Menu:Open()
        end

        return but
    end

    -- Начальное заполнение игроков
    for i, ply in ipairs(player.GetAll()) do
        if ply:Team() == TEAM_SPECTATOR then continue end
        if CurrentRound().name == "fear" and not ply:Alive() then continue end
        if ply:GetNetVar("disappearance", false) then continue end

        local panel = CreatePlayerPanel(ply, DScrollPanelPlayers, false)
        DScrollPanelPlayers:AddItem(panel)
        scoreBoardMenu.PlayerPanels[ply:SteamID()] = panel
    end

    local specsHeader = vgui.Create("DPanel", scoreBoardMenu)
    specsHeader:SetPos(playersWidth + 20, ScreenScaleH(58))
    specsHeader:SetSize(spectatorsWidth, headerHeight)
    specsHeader.Paint = function(self, w, h)
        surface.SetDrawColor(0, 0, 0, 200)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(255, 255, 255, 50)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        
        surface.SetFont("ZB_InterfaceSmall")
        surface.SetTextColor(200, 200, 200, 255)
        
        local _, textH = surface.GetTextSize("Name")
        local textY = h/2 - textH/2
        
        surface.SetTextPos(10, textY)
        surface.DrawText("Name")
        
        surface.SetTextPos(w * 0.50, textY)
        surface.DrawText("Rank")

        surface.SetTextPos(w * 0.66, textY)
        surface.DrawText("Ping")
    end

    local DScrollPanelSpecs = vgui.Create("DScrollPanel", scoreBoardMenu)
    DScrollPanelSpecs:SetPos(playersWidth + 20, panelStartY)
    DScrollPanelSpecs:SetSize(spectatorsWidth, panelHeight)
    
    function DScrollPanelSpecs:Paint(w, h)
        surface.SetDrawColor(0, 0, 0, 150)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(255, 255, 255, 50)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    -- Начальное заполнение зрителей
    for i, ply in ipairs(player.GetAll()) do
        if ply:Team() ~= TEAM_SPECTATOR then continue end
        if CurrentRound().name == "fear" and not ply:Alive() then continue end
        if ply:GetNetVar("disappearance", false) then continue end

        local panel = CreatePlayerPanel(ply, DScrollPanelSpecs, true)
        DScrollPanelSpecs:AddItem(panel)
        scoreBoardMenu.SpectatorPanels[ply:SteamID()] = panel
    end

    -- Функция обновления данных
    scoreBoardMenu.Think = function(self)
        local ct = CurTime()
        if ct - self.LastUpdate < self.UpdateInterval then return end
        self.LastUpdate = ct

        local disappearance = lply:GetNetVar("disappearance", nil)
        local needsRebuild = false

        for i, ply in ipairs(player.GetAll()) do
            if not IsValid(ply) then continue end
            
            local steamID = ply:SteamID()
            local isSpec = ply:Team() == TEAM_SPECTATOR
            local shouldShow = true
            
            if CurrentRound().name == "fear" and not ply:Alive() then 
                shouldShow = false 
            end
            if disappearance and ply == lply then
                shouldShow = false
            end

            if shouldShow then
                local inPlayers = self.PlayerPanels[steamID] ~= nil
                local inSpecs = self.SpectatorPanels[steamID] ~= nil
                
                if (isSpec and inPlayers) or (not isSpec and inSpecs) then
                    needsRebuild = true
                    break
                end

                local panel = isSpec and self.SpectatorPanels[steamID] or self.PlayerPanels[steamID]
                if not panel then
                    needsRebuild = true
                    break
                end

                if IsValid(panel) and panel.PlayerData then
                    local data = panel.PlayerData
                    
                    local currentNick = ply:Name()
                    if data.lastNick ~= currentNick then
                        data.lastNick = currentNick
                        if IsValid(data.avatar) then
                            data.avatar:SetPlayer(ply, 64)
                        end
                    end
                    
                    if IsValid(data.soundButton) then
                        data.soundButton:SetImage(not ply:IsMuted() and "icon16/sound.png" or "icon16/sound_mute.png")
                    end
                end
            else
                if self.PlayerPanels[steamID] or self.SpectatorPanels[steamID] then
                    needsRebuild = true
                    break
                end
            end
        end

        for steamID, panel in pairs(self.PlayerPanels) do
            local ply = player.GetBySteamID(steamID)
            if not IsValid(ply) then
                needsRebuild = true
                break
            end
        end
        
        for steamID, panel in pairs(self.SpectatorPanels) do
            local ply = player.GetBySteamID(steamID)
            if not IsValid(ply) then
                needsRebuild = true
                break
            end
        end

        if needsRebuild then
            for steamID, panel in pairs(self.PlayerPanels) do
                if IsValid(panel) then panel:Remove() end
            end
            for steamID, panel in pairs(self.SpectatorPanels) do
                if IsValid(panel) then panel:Remove() end
            end
            
            self.PlayerPanels = {}
            self.SpectatorPanels = {}
            
            for i, ply in ipairs(player.GetAll()) do
                if ply:Team() == TEAM_SPECTATOR then continue end
                if CurrentRound().name == "fear" and not ply:Alive() then continue end
                if ply:GetNetVar("disappearance", false) then continue end

                local panel = CreatePlayerPanel(ply, DScrollPanelPlayers, false)
                DScrollPanelPlayers:AddItem(panel)
                self.PlayerPanels[ply:SteamID()] = panel
            end

            for i, ply in ipairs(player.GetAll()) do
                if ply:Team() ~= TEAM_SPECTATOR then continue end
                if CurrentRound().name == "fear" and not ply:Alive() then continue end
                if ply:GetNetVar("disappearance", false) then continue end

                local panel = CreatePlayerPanel(ply, DScrollPanelSpecs, true)
                DScrollPanelSpecs:AddItem(panel)
                self.SpectatorPanels[ply:SteamID()] = panel
            end
        end
    end

    return true
end

function GM:ScoreboardHide()
    if IsValid(scoreBoardMenu) then
        scoreBoardMenu:Close()
        scoreBoardMenu = nil
    end
end

local AdminShowVoiceChat = CreateClientConVar("zb_admin_show_voicechat","0",false,false,"Shows voicechat panles",0,1)
hook.Add("PlayerStartVoice", "asd", function(ply)
	if !IsValid(ply) then return end
	if LocalPlayer():IsAdmin() and AdminShowVoiceChat:GetBool() then return end

	local other_alive = (ply:Alive() and LocalPlayer() != ply) or (ply.organism and (ply.organism.otrub or (ply.organism.brain and ply.organism.brain > 0.05)))

	return other_alive or nil
end)

-- свет от молнии
if CLIENT then
	net.Receive("PunishLightningEffect", function()
		local target = net.ReadEntity()
		if not IsValid(target) then return end
		local dlight = DynamicLight(target:EntIndex())
		if dlight then
			dlight.pos = target:GetPos()
			dlight.r = 126
			dlight.g = 139
			dlight.b = 212
			dlight.brightness = 1
			dlight.Decay = 1000
			dlight.Size = 500
			dlight.DieTime = CurTime() + 1
		end
	end)
end

local lightningMaterial = Material("sprites/lgtning")

net.Receive("AnotherLightningEffect", function()
    local target = net.ReadEntity()
	if not IsValid(target) then return end
    local points = {}
    for i = 1, 27 do
        points[i] = target:GetPos() + Vector(0, 0, i * 50) + Vector(math.Rand(-20,20),math.Rand(-20,20),math.Rand(-20,20))
    end
    hook.Add( "PreDrawTranslucentRenderables", "LightningExample", function(isDrawingDepth, isDrawingSkybox)
        if isDrawingDepth or isDrawingSkybox then return end
        local uv = math.Rand(0, 1)
        render.OverrideBlend( true, BLEND_SRC_COLOR, BLEND_SRC_ALPHA, BLENDFUNC_ADD, BLEND_ONE, BLEND_ZERO, BLENDFUNC_ADD )
        render.SetMaterial(lightningMaterial)
        render.StartBeam(27)
        for i = 1, 27 do
            render.AddBeam(points[i], 20, uv * i, Color(255,255,255,255))
        end
        render.EndBeam()
        render.OverrideBlend( false )
    end )
    timer.Simple(0.1, function()
        hook.Remove("PreDrawTranslucentRenderables", "LightningExample")
    end)
end)

function GM:AddHint( name, delay )
	return false
end

local snakeGameOpen = false

concommand.Add("zb_snake", function()
    if snakeGameOpen then
        print("[Snake Game] Игра уже запущена!")
        return
    end

    local frame = vgui.Create("ZFrame")
    frame:SetTitle("Snake Game")
    frame:SetSize(400, 400)
    frame:Center()
    frame:MakePopup()
    frame:SetDeleteOnClose(true)  
    snakeGameOpen = true  

    local gridSize = 20
    local gridWidth = 19  
    local gridHeight = 19  
    local snakePanel = vgui.Create("DPanel", frame)
    snakePanel:SetSize(380, 380)
    snakePanel:SetPos(10, 10)

    frame:SetDraggable(true)
    frame:ShowCloseButton(true)

    local snake = {
        {x = 10, y = 10},
    }
	
    local snakeDirection = "RIGHT"
    local food = nil
    local score = 0
    local gameRunning = true

    local function spawnFood()
        local validPosition = false
        while not validPosition do
            local newFood = {
                x = math.random(0, gridWidth - 1), 
                y = math.random(0, gridHeight - 1)
            }
            validPosition = true

            for _, segment in ipairs(snake) do
                if segment.x == newFood.x and segment.y == newFood.y then
                    validPosition = false
                    break
                end
            end

            if validPosition then
                food = newFood
            end
        end
    end

    local function drawSnake()
        surface.SetDrawColor(0, 255, 0, 255)
        for _, segment in ipairs(snake) do
            surface.DrawRect(segment.x * gridSize, segment.y * gridSize, gridSize - 1, gridSize - 1)
        end
    end

    local function drawFood()
        if food then
            surface.SetDrawColor(255, 0, 0, 255)
            surface.DrawRect(food.x * gridSize, food.y * gridSize, gridSize - 1, gridSize - 1)
        end
    end

    local function moveSnake()
        if not gameRunning then return end

        local head = table.Copy(snake[1])

        if snakeDirection == "UP" then
            head.y = head.y - 1
        elseif snakeDirection == "DOWN" then
            head.y = head.y + 1
        elseif snakeDirection == "LEFT" then
            head.x = head.x - 1
        elseif snakeDirection == "RIGHT" then
            head.x = head.x + 1
        end

        if head.x < 0 or head.x >= gridWidth or head.y < 0 or head.y >= gridHeight then
            gameRunning = false
        end

        for _, segment in ipairs(snake) do
            if segment.x == head.x and segment.y == head.y then
                gameRunning = false
            end
        end

        table.insert(snake, 1, head)

        if food and head.x == food.x and head.y == food.y then
            score = score + 1
            spawnFood()
        else
            table.remove(snake)
        end
    end

    local function resetGame()
        snake = {{x = 10, y = 10}}
        snakeDirection = "RIGHT"
        score = 0
        gameRunning = true
        spawnFood()
    end

    function snakePanel:Paint(w, h)
        surface.SetDrawColor(50, 50, 50, 255)
        surface.DrawRect(0, 0, w, h)

        if gameRunning then
            drawSnake()
            drawFood()
        else
            draw.SimpleText("Game Over! Press R to restart", "DermaDefault", w / 2, h / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        draw.SimpleText("Score: " .. score, "DermaDefault", 10, 10, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    end

    function frame:OnKeyCodePressed(key)
        if key == KEY_W and snakeDirection ~= "DOWN" then
            snakeDirection = "UP"
        elseif key == KEY_S and snakeDirection ~= "UP" then
            snakeDirection = "DOWN"
        elseif key == KEY_A and snakeDirection ~= "RIGHT" then
            snakeDirection = "LEFT"
        elseif key == KEY_D and snakeDirection ~= "LEFT" then
            snakeDirection = "RIGHT"
        elseif key == KEY_R then
            resetGame()
        end
    end

    timer.Create("SnakeGameTimer", 0.2, 0, function()
        if gameRunning then
            moveSnake()
        end
        snakePanel:InvalidateLayout(true)
    end)

    frame.OnClose = function()
        timer.Remove("SnakeGameTimer")
        snakeGameOpen = false
        print("[Snake Game] Игра закрыта.")
    end

    resetGame()
end)

hook.Add("Player Spawn", "GuiltKnown",function(ply)
	if ply == LocalPlayer() then
		system.FlashWindow()
	end
end)