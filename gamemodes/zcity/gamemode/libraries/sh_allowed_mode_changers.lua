
zb.AllowedModeChangers = {
    ["STEAM_0:0:396467765"] = true,
    ["STEAM_0:1:924110558"] = true, -- Example
    -- Add more SteamIDs here
}

function zb.CanChangeMode(ply)
    if not IsValid(ply) then return false end
    -- Check if SteamID is in the allowed list
    if zb.AllowedModeChangers[ply:SteamID()] then return true end
    
    return false
end
