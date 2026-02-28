--[[
Server Name: [RU] RUTKA TEAM HOMI-BLOODSHED-Z CITY 21+
Server IP:   46.174.53.43:2466
File Path:   addons/rasta/lua/homigrad/hud/cl_voice.lua
		 __        __              __             ____     _                ____                __             __         
   _____/ /_____  / /__  ____     / /_  __  __   / __/____(_)__  ____  ____/ / /_  __     _____/ /____  ____ _/ /__  _____
  / ___/ __/ __ \/ / _ \/ __ \   / __ \/ / / /  / /_/ ___/ / _ \/ __ \/ __  / / / / /    / ___/ __/ _ \/ __ `/ / _ \/ ___/
 (__  ) /_/ /_/ / /  __/ / / /  / /_/ / /_/ /  / __/ /  / /  __/ / / / /_/ / / /_/ /    (__  ) /_/  __/ /_/ / /  __/ /    
/____/\__/\____/_/\___/_/ /_/  /_.___/\__, /  /_/ /_/  /_/\___/_/ /_/\__,_/_/\__, /____/____/\__/\___/\__,_/_/\___/_/     
                                     /____/                                 /____/_____/                                  
--]]

local VOICE_MAT = Material("hud/voice/mic.png")
local VOICE_WIDGET_MAT = Material("hud/voice/mic_mover.png", "smooth mips")
local RADIO_VOICE_MAT = Material("hud/voice/radio.png")
local RADIO_VOICE_WIDGET_MAT = Material("hud/voice/radio_mover.png", "smooth mips")

local playerVoiceAlpha = {}

local function IsPlayerTalkingInRadio(ply)
    return ply:GetNWBool("Radio.MainSpeaking", false)
end

-- Voice icons above players removed
-- hook.Add("PostDrawTranslucentRenderables", "TalkIcons_Draw", function() ... end)

hook.Add("PlayerDisconnected", "TalkIcons_Cleanup", function(ply)
    if playerVoiceAlpha[ply] then
        playerVoiceAlpha[ply] = nil
    end
end)
