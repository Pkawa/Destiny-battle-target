-- Camera setups — direct port of CreateCameras(), war3map.j 4631-4703. See systems/Cameras.md.
-- All five share FoV 70, FARZ 5000, NEARZ 100, ZOFFSET/ROLL/LOCAL_* 0; only rotation, angle of
-- attack, target distance and destination differ. Consumers: the "-camera" zoom-out command
-- (below) and the Defeat_Silmeria cinematic (deaths.lua); MegaBossZoomOut is for the Megaboss
-- arena (bosses/ ⬜).

cam = {}

-- One camera setup: shared fields + the four that vary.
local function makeCamera(rotation, angleOfAttack, targetDist, destX, destY)
    local c = CreateCameraSetup()
    CameraSetupSetField(c, CAMERA_FIELD_ZOFFSET,         0.0,           0.0)
    CameraSetupSetField(c, CAMERA_FIELD_ROTATION,        rotation,      0.0)
    CameraSetupSetField(c, CAMERA_FIELD_ANGLE_OF_ATTACK, angleOfAttack, 0.0)
    CameraSetupSetField(c, CAMERA_FIELD_TARGET_DISTANCE, targetDist,    0.0)
    CameraSetupSetField(c, CAMERA_FIELD_ROLL,            0.0,           0.0)
    CameraSetupSetField(c, CAMERA_FIELD_FIELD_OF_VIEW,   70.0,          0.0)
    CameraSetupSetField(c, CAMERA_FIELD_FARZ,            5000.0,        0.0)
    CameraSetupSetField(c, CAMERA_FIELD_NEARZ,           100.0,         0.0)
    CameraSetupSetField(c, CAMERA_FIELD_LOCAL_PITCH,     0.0,           0.0)
    CameraSetupSetField(c, CAMERA_FIELD_LOCAL_YAW,       0.0,           0.0)
    CameraSetupSetField(c, CAMERA_FIELD_LOCAL_ROLL,      0.0,           0.0)
    CameraSetupSetDestPosition(c, destX, destY, 0.0)
    return c
end

-- Called from main.lua (after Blizzard init), like CreateAllRegions — NOT in Lua root.
function CreateCameras()
    cam.ZoomOut         = makeCamera( 90.0, 304.0, 2657.3,  -4462.3,  -2585.3)
    cam.DefeatCamera    = makeCamera(224.7, 341.3, 1127.0,   3654.3, -10213.6)
    cam.DeadSil         = makeCamera(270.3, 272.6, 1127.0,   3812.5, -10213.6)
    cam.DeadSilZoomOut  = makeCamera(270.3, 272.6, 4279.7,   3703.7,  -9897.0)
    cam.MegaBossZoomOut = makeCamera( 90.0, 304.0, 3536.9,  10141.1,   4500.3)
end

-- "-camera": apply the town zoom-out, then pan to one of the caster's heroes
-- (war3map.j Camera_Zoomout 10422-10448). Registered for the 8 human slots + Player(10).
function RegisterCameraTriggers()
    local t = CreateTrigger()
    for _, i in ipairs({ 0, 1, 2, 3, 4, 5, 6, 7, 10 }) do
        TriggerRegisterPlayerChatEvent(t, Player(i), "-camera", true)
    end
    TriggerAddAction(t, function()
        local p = GetTriggerPlayer()
        CameraSetupApplyForPlayer(true, cam.ZoomOut, p, 0)
        TriggerSleepAction(0.5)
        local g = GetUnitsOfPlayerMatching(p,
            Condition(function() return IsUnitType(GetFilterUnit(), UNIT_TYPE_HERO) end))
        local hero = GroupPickRandomUnit(g)
        DestroyGroup(g)
        if hero then PanCameraToTimedForPlayer(p, GetUnitX(hero), GetUnitY(hero), 0) end
    end)
end
