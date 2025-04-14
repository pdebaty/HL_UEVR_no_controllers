local UEHelpers = require("UEHelpers")
local Json = require("jsonStorage")
require("config")
local uevrUtils = require("libs/uevr_utils")
local debugModule = require("libs/uevr_debug")
local controllers = require("libs/controllers")
local animation = require("libs/animation")
local flickerFixer = require("libs/flicker_fixer")
local wand = require("helpers/wand")
local mounts = require("helpers/mounts")
local decoupledYaw = require("helpers/decoupledyaw")
local input = require("helpers/input")
local gesturesModule = require("gestures/gestures")

uevrUtils.enableDebug(true)

RegisterHook("/Script/Engine.PlayerController:SendToConsole", function(self, msg)	
	if msg:get():ToString() == "UEVR" then
		uevrUtils.initUEVR()
	end
end)

local masterPoseableComponent = nil
local masterGlovePoseableComponent = nil

local isInCinematic = false
local isInAlohomora = true
local isFP = true
local isInMenu = false
local enableVRCameraOffset = true

--decoupled yaw variables
local isDecoupledYawDisabled = true
local decoupledYawCurrentRot = 0
local alphaDiff = 0
local snapAngle = 30
local useSnapTurn = true

local lastHMDDirection = nil
local lastHMDPosition = nil
local lastHMDRotation = nil

local lastWandTargetLocation = nil
local lastWandTargetDirection = nil
local lastWandPosition = nil

local phoenixCameraSettings = nil
local currentMediaPlayers = nil
local uiManager = nil

local debugHands = false
local cameraStackVal = true

local hideActorForNextCinematic = false

local g_isLeftHanded = false
local g_lastVolumetricFog = nil
local g_isPregame = true
local g_eulaClicked = false
local g_isShowingStartPageIntro = false

local armsComponent = nil
local glovesComponent = nil
local vrBody = nil

function UEVRReady(instance)
	print("UEVR is now ready\n")

	uevr.params.vr.recenter_view()
		
	loadSettings()
	initLevel()	
	preGameStateCheck()
	hookLateFunctions()
	setLocomotionMode(locomotionMode)
	checkStartPageIntro()
	
	if useCrossHair then
		createCrosshair()
	end
	
	if pawn.InCinematic == true then
		isInCinematic = true -- This makes the avatar in the intro screen be at the right position
	else
		--if injected in a game rather than at the loading screen
		updatePlayer()
	end
	
	--this has to be done here. When done with utils callback the function params dont get changed
	local prevRotation = {}
	uevr.params.sdk.callbacks.on_early_calculate_stereo_view_offset(function(device, view_index, world_to_meters, position, rotation, is_double)	
		--print("Pre angle",view_index, rotation.x, rotation.y, rotation.z,"\n")
		--Fix for UEVR broken in Intro
		if rotation ~= nil and rotation.x == -90 and rotation.y == 90 and rotation.z == -90 and prevRotation.X ~= nil and prevRotation.Y ~= nil and prevRotation.Z ~= nil then
			rotation.x = prevRotation.X
			rotation.y = prevRotation.Y
			rotation.z = prevRotation.Z
		end
		prevRotation = {X=rotation.x, Y=rotation.y, Z=rotation.z}
		--End fix
		
		if isFP and not isInCinematic and enableVRCameraOffset then
			local mountPawn = mounts.getMountPawn(pawn)
			if uevrUtils.validate_object(mountPawn) ~= nil and mountPawn.RootComponent ~= nil then
				if not isDecoupledYawDisabled then
					rotation.y = decoupledYawCurrentRot
				end
							
				local currentOffset = mounts.getMountOffset()
				temp_vec3f:set(currentOffset.X, currentOffset.Y, currentOffset.Z) -- the vector representing the offset adjustment
				temp_vec3:set(0, 0, 1) --the axis to rotate around
				local forwardVector = kismet_math_library:RotateAngleAxis(temp_vec3f, rotation.y, temp_vec3)
				local pawnPos = mountPawn.RootComponent:K2_GetComponentLocation()					
				position.x = pawnPos.x + forwardVector.X
				position.y = pawnPos.y + forwardVector.Y
				position.z = pawnPos.z + forwardVector.Z
			end
		end

	end)
end

function connectCube(hand)
	local leftComponent = uevrUtils.createStaticMeshComponent("StaticMesh /Engine/BasicShapes/Cube.Cube")
	local leftConnected = controllers.attachComponentToController(hand, leftComponent)
	uevrUtils.set_component_relative_transform(leftComponent, nil, nil, {X=0.003, Y=0.003, Z=0.003})
end

function initLevel()
	phoenixCameraSettings = nil
	currentMediaPlayers = nil
	uiManager = nil
	
	controllers.onLevelChange()
	controllers.createController(0)
	controllers.createController(1)
	controllers.createController(2) 
	
	wand.reset()
--	connectCube(1)
	
	flickerFixer.create()
end

function loadSettings()
    if Json.loadTable("VRFPSettings.json", "locomotionMode") == nil then
		--create a new settings file:close		
		print("Creating save file\n")
        Json.saveTable(locomotionMode, "VRFPSettings.json", "locomotionMode")
        Json.saveTable(controlMode, "VRFPSettings.json", "controlMode")
        Json.saveTable(gestureMode, "VRFPSettings.json", "gestureMode")
        Json.saveTable(useCrossHair, "VRFPSettings.json", "useCrossHair")
        Json.saveTable(targetingMode, "VRFPSettings.json", "targetingMode")
        Json.saveTable(locomotionMode, "VRFPSettings.json", "locomotionModeSaved")
        Json.saveTable(controlMode, "VRFPSettings.json", "controlModeSaved")
        Json.saveTable(gestureMode, "VRFPSettings.json", "gestureModeSaved")
        Json.saveTable(useCrossHair, "VRFPSettings.json", "useCrossHairSaved")
        Json.saveTable(targetingMode, "VRFPSettings.json", "targetingModeSaved")
    end
	
	if locomotionMode == Json.loadTable("VRFPSettings.json", "locomotionMode") then
		locomotionMode = Json.loadTable("VRFPSettings.json", "locomotionModeSaved")
	else
		Json.saveTable(locomotionMode, "VRFPSettings.json", "locomotionMode")
		Json.saveTable(locomotionMode, "VRFPSettings.json", "locomotionModeSaved")
	end
	if controlMode == Json.loadTable("VRFPSettings.json", "controlMode") then
		controlMode = Json.loadTable("VRFPSettings.json", "controlModeSaved")
	else
		Json.saveTable(controlMode, "VRFPSettings.json", "controlMode")
		Json.saveTable(controlMode, "VRFPSettings.json", "controlModeSaved")
	end
	if gestureMode == Json.loadTable("VRFPSettings.json", "gestureMode") then
		gestureMode = Json.loadTable("VRFPSettings.json", "gestureModeSaved")
	else
		Json.saveTable(gestureMode, "VRFPSettings.json", "gestureMode")
		Json.saveTable(gestureMode, "VRFPSettings.json", "gestureModeSaved")
	end
	if useCrossHair == Json.loadTable("VRFPSettings.json", "useCrossHair") then
		useCrossHair = Json.loadTable("VRFPSettings.json", "useCrossHairSaved")
	else
		Json.saveTable(useCrossHair, "VRFPSettings.json", "useCrossHair")
		Json.saveTable(useCrossHair, "VRFPSettings.json", "useCrossHairSaved")
	end
	if targetingMode == Json.loadTable("VRFPSettings.json", "targetingMode") then
		targetingMode = Json.loadTable("VRFPSettings.json", "targetingModeSaved")
	else
		Json.saveTable(targetingMode, "VRFPSettings.json", "targetingMode")
		Json.saveTable(targetingMode, "VRFPSettings.json", "targetingModeSaved")
	end
	print("Locomotion Mode:", locomotionMode, "\n")
	print("Targeting Mode:", targetingMode, "\n")
	print("Gesture Mode:", gestureMode, "\n")
	print("Control Mode:", controlMode, "\n")
	print("Crosshair visible:", useCrossHair, "\n")

end

function updatePlayer()
	setCharacterInFPSView(isFP) 
	hidePlayer(isFP)
end

function hidePlayer(state, force)
	if force == nil then force = false end
	--print("hidePlayer:  ", state,pawn,isInCinematic,"\n")
	if (not isInCinematic) or force then	
		local mountPawn = mounts.getMountPawn(pawn)			
		if uevrUtils.validate_object(mountPawn) ~= nil then
			local characterMesh = mountPawn.Mesh
			if uevrUtils.validate_object(characterMesh) ~= nil and characterMesh.SetVisibility ~= nil then
				characterMesh:SetVisibility(not state, true)
			else
				print("hidePlayer: Character mesh not valid\n")
			end
		else
			print("hidePlayer: Pawn not valid\n")
		end
	end
end


function setCameraStackDisabled(cameraStack, state)
    if cameraStack ~= nil then
        for index, stack in pairs(cameraStack) do
            if stack:IsValid() then
				ExecuteInGameThread( function()
					stack:SetDisabled(state, true)
				end)
            else
                print("Not valid CameraStack\n")
            end
        end
    end
end

function setCharacterInFPSView(val)
    PitchToTransformCurves = FindAllOf("BP_PitchToTransformCurves_Default_C")
    AmbientCamAnim_Idle = FindAllOf("BP_AmbientCamAnim_Idle_C")
    AmbientCamAnim_Jog = FindAllOf("BP_AmbientCamAnim_Jog_C")
    AmbientCamAnim_Sprint = FindAllOf("BP_AmbientCamAnim_Sprint_C")
    CameraStackBehaviorCollisionPrediction = FindAllOf("CameraStackBehaviorCollisionPrediction")
    OpenSpaceCameraStacks = FindAllOf("BP_AddCameraSpaceTranslation_OpenSpace_C")
	LookAtCameraStacks = FindAllOf("BP_AddCameraSpaceTranslation_LookAt_C")
	CombatCameraStacks = FindAllOf("BP_AddCameraSpaceTranslation_Combat_C")
	MountChargeCameraStacks = FindAllOf("BP_AddCameraSpaceTranslation_MountCharge_C")
	SwimmingCameraStacks = FindAllOf("BP_AddCameraSpaceTranslation_Swimming_OpenSpace_C")
	BroomCameraStacks = FindAllOf("BP_AddCameraSpaceTranslation_Broom_Boost_New_C")
	--DefaultCameraStacks = FindAllOf("BP_AddCameraSpaceTranslation_Default_C")

    setCameraStackDisabled(PitchToTransformCurves, val)
    setCameraStackDisabled(AmbientCamAnim_Idle, val)
    setCameraStackDisabled(AmbientCamAnim_Jog, val)
    setCameraStackDisabled(AmbientCamAnim_Sprint, val)
    setCameraStackDisabled(CameraStackBehaviorCollisionPrediction, val)
    setCameraStackDisabled(OpenSpaceCameraStacks, val)
    setCameraStackDisabled(LookAtCameraStacks, val)
    setCameraStackDisabled(CombatCameraStacks, val)
    setCameraStackDisabled(MountChargeCameraStacks, val)
    setCameraStackDisabled(SwimmingCameraStacks, val)
    setCameraStackDisabled(BroomCameraStacks, val)
    --setCameraStackDisabled(DefaultCameraStacks, val)
end

function checkStartPageIntro()
	local startPageWidget = uevrUtils.find_first_of("Class /Script/Phoenix.StartPageWidget") 
	if startPageWidget ~= nil and startPageWidget:IsVisible() then
		g_isShowingStartPageIntro = true
	end
	print("Is showing page intro",g_isShowingStartPageIntro,"\n")
	if g_isShowingStartPageIntro then
		uevrUtils.fadeCamera(1.0, true, false, true, true)
	end
end

function toggleDecoupledYaw()
	disableDecoupledYaw(not isDecoupledYawDisabled)
end

local g_wasSnapTurnEnabled = nil
function disableDecoupledYaw(val)
	isDecoupledYawDisabled =  val
	if isDecoupledYawDisabled then
		print("Disabling decoupled Yaw\n")
		if g_wasSnapTurnEnabled == nil then
			g_wasSnapTurnEnabled = uevr.params.vr.is_snap_turn_enabled()
		end
		uevr.params.vr.set_snap_turn_enabled(false)		
	else
		print("Enabling decoupled Yaw\n")
		if g_wasSnapTurnEnabled ~= nil then
			uevr.params.vr.set_snap_turn_enabled(g_wasSnapTurnEnabled)
		end
		g_wasSnapTurnEnabled = nil
	end
end

function onHandednessChanged(isLeftHanded)
	print("Is Left handed",isLeftHanded,"\n")
	wand.disconnect()
	wand.connect(mounts.getMountPawn(pawn), isLeftHanded and 0 or 1)
end

function handednessCheck()
	if phoenixCameraSettings ~= nil then
		local val = getIsLeftHanded()
		if val ~= g_isLeftHanded then
			g_isLeftHanded = val
			onHandednessChanged(val)
		end
	end
end

function getIsLeftHanded()
	if phoenixCameraSettings == nil then
		phoenixCameraSettings = uevrUtils.find_first_of("Class /Script/Phoenix.PhoenixCameraSettings")
	end
	if phoenixCameraSettings ~= nil then
		return phoenixCameraSettings:GetGamepadSouthpaw()
	end
	return false
end

function setLocomotionMode(mode)
	locomotionMode = mode
	print("Locomotion mode = ",locomotionMode,"\n")
	disableDecoupledYaw(locomotionMode == 0)
end

function preGameStateCheck()
	if uiManager == nil then 
		uiManager = uevrUtils.find_first_of("Class /Script/Phoenix.UIManager") 
	end
	g_isPregame = uiManager ~= nil and UEVR_UObjectHook.exists(uiManager) and uiManager.IsInPreGameplayState ~= nil and uiManager:IsInPreGameplayState()
end

function inPauseMode()
	if uiManager == nil then 
		uiManager = uevrUtils.find_first_of("Class /Script/Phoenix.UIManager") 
	end
	return uevrUtils.validate_object(uiManager) ~= nil and uiManager.InPauseMode ~= nil and uiManager:InPauseMode()
end

function inMenuMode()
	if uiManager == nil then 
		uiManager = uevrUtils.find_first_of("Class /Script/Phoenix.UIManager") 
	end
	return uevrUtils.validate_object(uiManager) ~= nil and uiManager.GetIsUIShown ~= nil and uiManager:GetIsUIShown()
end

function solveAstronomyMinigame()
	pawn:CHEAT_SolveMinigame()
end

local g_mediaPlayerFadeLock = false
function mediaPlayerCheck()
	--print("mediaPlayerCheck called\n")
	local doUpdateMediaPlayers = false
	local mediaIsPlaying = false
	local spellUrlStr = ""
	local urlStr = ""
	if currentMediaPlayers == nil then
		--print("No instances of 'BinkMediaPlayer' were found\n")
	else
		for Index, mp in pairs(currentMediaPlayers) do
			--print(mp)
			if mp ~= nil and mp:IsValid() then
				--print(mp.URL:ToString())
				--print(mp.isPlaying())
				local isPlaying = mp.isPlaying()
				urlStr = mp.URL:ToString()
				if isPlaying and isValidMedia(urlStr) then
					mediaIsPlaying = true
					--setProgressSpecificSettings(urlStr)
					print(urlStr, "\n")
				end
				if gestureMode == 1 and isPlaying and string.match(urlStr, "SpellPreviews") then
					spellUrlStr = urlStr
				end
			else
				doUpdateMediaPlayers = true
			end
		end
	end

	if mediaIsPlaying and not g_mediaPlayerFadeLock then
		isPlayingMovie = true
		print("Media started\n")
		g_mediaPlayerFadeLock = true
		uevrUtils.fadeCamera(fadeDuration, true)
	end
	if not mediaIsPlaying and g_mediaPlayerFadeLock then
		isPlayingMovie = false
		print("Media stopped\n")
		g_mediaPlayerFadeLock = false
		uevrUtils.fadeCamera(fadeDuration, false,false,true)
	end
	
	if gestureMode == 1 then
		handleSpellMedia(spellUrlStr)
	end
	
	if doUpdateMediaPlayers then updateMediaPlayers() end

end

--if the function returns false then this url should not trigger a camera fade
function isValidMedia(url)
	local isValid = true
	if string.match(url, "FMV_ArrestoMomentum" ) or string.match(url, "ATL_Tapestry_Ogre_1" ) or string.match(url, "ATL_DailyProphet" ) or string.match(url, "ATL_Portrait" ) or string.match(url, "SpellPreviews") or string.match(url, "FMV_Aim_Mode_1") or string.match(url, "FMV_AM_Finisher") or string.match(url, "FMV_AutoTargeting") or string.match(url, "FMV_AMPickUps_ComboMeter")  or string.match(url, "FMV_Talent_Core_StupefyStun") then
		isValid = false
	end
	return isValid
end

function updateMediaPlayers()
	currentMediaPlayers = FindAllOf("BinkMediaPlayer")
end

local lastSpellMediaFileName = ""
function handleSpellMedia(fileName)
	if lastSpellMediaFileName ~= fileName then
		if fileName ~= "" then
			local spellName = getSpellNameFromFileName(fileName)
			if pawn ~= nil and UEVR_UObjectHook.exists(pawn) then
				gesturesModule.showGlyphForSpell(spellName, lastHMDDirection, pawn:K2_GetActorLocation())
			end
		else
			gesturesModule.hideGlyphs()
		end
		lastSpellMediaFileName = fileName
	end 
end

function getSpellNameFromFileName(fileName)
	local name = ""
	local tokens = uevrUtils.splitStr(fileName, "/")
	if #tokens > 0 then
		tokens = uevrUtils.splitStr(tokens[#tokens], ".")
		if #tokens > 0 then
			name = tokens[1]
			tokens = uevrUtils.splitStr(name, "_")
			if #tokens > 1 then
				name = tokens[2]
				if name == "BeastTool" then
					name = tokens[2] .. "_" .. tokens[3]
				end
			end
		end
	end
	return name
end

	

local g_lastTabIndex = nil
function handleFieldGuidePageChange(currentTabIndex)
	--When viewing the map in the field guide we need to turn off the VR camera hook so that the map can be shown correctly
	--delays are needed to make transitions smoother
	if currentTabIndex == 6 then
		delay(1300, function()
			enableVRCameraOffset = false
			uevrUtils.set_2D_mode(true)
		end)
	elseif currentTabIndex == 1 then
		--when on the gear screen dont offset the camera so that the avatar appears
		enableVRCameraOffset = false
		delay(300, function()
			uevrUtils.set_2D_mode(false)
		end)
	else
		if g_lastTabIndex == 1 then
			delay(500, function()
				enableVRCameraOffset = true
			end)
		else
			enableVRCameraOffset = true
		end
		delay(300, function()
			uevrUtils.set_2D_mode(false)
		end)
	end

	g_lastTabIndex = currentTabIndex

end

function on_lazy_poll()
	snapAngle = uevrUtils.PositiveIntegerMask(uevr.params.vr:get_mod_value("VR_SnapturnTurnAngle"))
	useSnapTurn = uevr.params.vr.is_snap_turn_enabled()
	
	local MovementOrientation =  uevrUtils.PositiveIntegerMask(uevr.params.vr:get_mod_value("VR_MovementOrientation"))				
	if MovementOrientation == "1" then
		setLocomotionMode(1)
		Json.saveTable(locomotionMode, "VRFPSettings.json", "locomotionModeSaved")
		uevr.params.vr.set_mod_value("VR_MovementOrientation","0")
	elseif MovementOrientation == "2" then
		setLocomotionMode(2)
		Json.saveTable(locomotionMode, "VRFPSettings.json", "locomotionModeSaved")
		uevr.params.vr.set_mod_value("VR_MovementOrientation","0")	
	end	
	
	preGameStateCheck()
	mediaPlayerCheck()
	handednessCheck()
	if not wand.isConnected() then
		wand.connect(mounts.getMountPawn(pawn), isLeftHanded and 0 or 1)
	end
	if manualHideWand then
		wand.updateVisibility(mounts.getMountPawn(pawn), g_isPregame or isInMenu or isInCinematic or not mounts.isWalking() )
	end
	
	
	if useVolumetricFog ~= nil and g_lastVolumetricFog ~= useVolumetricFog then 
		if useVolumetricFog then
			uevrUtils.set_cvar_int("r.VolumetricFog",1)
		else
			uevrUtils.set_cvar_int("r.VolumetricFog",0)
		end
	end
	g_lastVolumetricFog = useVolumetricFog

	local pc = uevr.api:get_player_controller(0)
	if targetingMode == 0 and pc ~= nil then
		pc:ActivateAutoTargetSense(false, true)
	end
end

function on_level_change(level)
	print("Level changed\n")
	initLevel()
end

function on_pre_engine_tick(engine, delta)
	local newLocomotionMode = mounts.updateMountLocomotionMode(pawn, locomotionMode)
	if newLocomotionMode ~= nil then 
		setLocomotionMode(newLocomotionMode)
	end
	
	isInMenu = inMenuMode()
		
	lastWandTargetLocation, lastWandTargetDirection, lastWandPosition = wand.getWandTargetLocationAndDirection(useCrossHair and not g_isPregame)

	if isFP and not isInCinematic and uevrUtils.validate_object(pawn) ~= nil then			
		if gestureMode == 1 and (not (g_isPregame or isInMenu or isInCinematic or not mounts.isWalking())) then
			--print("Is wand equipped",pawn:IsWandEquipped(),"\n")
			gesturesModule.handleGestures(pawn, gestureMode, lastWandTargetDirection, lastWandPosition, delta)
		end
		
		if not isDecoupledYawDisabled then
			alphaDiff = decoupledYaw.handleDecoupledYaw(pawn, alphaDiff, lastWandTargetDirection, lastHMDDirection, locomotionMode)
		end
		
		local mountPawn = mounts.getMountPawn(pawn)
		if uevrUtils.validate_object(mountPawn) ~= nil and uevrUtils.validate_object(mountPawn.Mesh) ~= nil and mountPawn.Mesh.bVisible == true then 
			--print("Hiding mesh from tick\n")
			hidePlayer(isFP)
		end
		
		if useCrossHair then
			updateCrosshair(lastWandTargetDirection, lastWandTargetLocation)
		end
	end
	
end

--callback for on_post_calculate_stereo_view_offset
function on_post_calculate_stereo_view_offset(device, view_index, world_to_meters, position, rotation, is_double)
	if view_index == 1 then
		lastHMDDirection = kismet_math_library:GetForwardVector(rotation)
		if lastHMDDirection.Y ~= lastHMDDirection.Y then
			print("NAN error",rotation.x, rotation.y, rotation.z,"\n")
			lastHMDDirection = nil
		end
		lastHMDPosition = position
		lastHMDRotation = rotation
		
	end
	-- if vrBody ~= nil then 
		-- --vrBody:K2_SetWorldLocationAndRotation(position, rotation, false, reusable_hit_result, false) 
		-- vrBody:K2_SetWorldLocation(position, false, reusable_hit_result, false) 
	-- end
	updateHands()

end
	
function on_xinput_get_state(retval, user_index, state)
	if isFP and not isInCinematic then
		local disableStickOverride = g_isPregame or isInMenu or isInCinematic or mounts.isOnBroom() or (gestureMode == 1 and gesturesModule.isCastingSpell(pawn, "Spell_Wingardium"))
		decoupledYawCurrentRot = input.handleInput(state, decoupledYawCurrentRot, isDecoupledYawDisabled, locomotionMode, controlMode, g_isLeftHanded, snapAngle, useSnapTurn, alphaDiff, disableStickOverride)
		
		if gestureMode == 1 then
			gesturesModule.handleInput(state, g_isLeftHanded)
		end
		
		if manualHideWand and mounts.isWalking() then
			wand.handleInput(pawn, state, g_isLeftHanded)
		end
		
		wand.handleBrokenWand(mounts.getMountPawn(pawn), state, g_isLeftHanded)		
	end
end

-- only do this once 
local g_isLateHooked = false
function hookLateFunctions()
	if not g_isLateHooked then		
		--print("isFP " .. (isFP and "First Person Mode" or "Not First Person Mode") .. "\n")
		
		RegisterHook("/Game/Pawn/Shared/StateTree/BTT_Biped_Cinematic.BTT_Biped_Cinematic_C:ReceiveExecute", function(self)
			print("Cinematic started\n")
			if hideActorForNextCinematic then
				hidePlayer(isFP)
				hideActorForNextCinematic = false
			else
				delay( 200, function()
					--print("Showing player after delay\n"))
					--ExecuteInGameThread( function()					
						hidePlayer(false, true)
					--end)
				end)
			end
			isInCinematic = true
			if manualHideWand then wand.setVisible(pawn, false) end
			--skipCinematicIfSkippable()
		end)

		RegisterHook("/Game/Pawn/Shared/StateTree/BTT_Biped_Cinematic.BTT_Biped_Cinematic_C:ExitTask", function(self)
			print("Cinematic exited\n")
			isInCinematic = false
		end)
				
        RegisterHook("/Game/UI/LoadingScreen/UI_BP_NewLoadingScreen.UI_BP_NewLoadingScreen_C:OnCurtainRaised", function()
			print("OnCurtainRaised called for UI_BP_NewLoadingScreen_C\n")
			updatePlayer()
        end)

		RegisterHook("/Game/UI/LoadingScreen/UI_BP_NewLoadingScreen.UI_BP_NewLoadingScreen_C:OnIntroStarted", function(self)
			print("UI_BP_NewLoadingScreen_C:OnIntroStarted\n")
			uevrUtils.fadeCamera(0.1, true, false, true, true)
		end)
		
		RegisterHook("/Game/UI/LoadingScreen/UI_BP_NewLoadingScreen.UI_BP_NewLoadingScreen_C:OnOutroEnded", function(self)
			print("UI_BP_NewLoadingScreen_C:OnOutroEnded\n")
			if not g_isShowingStartPageIntro and not isInFadeIn then
				uevrUtils.fadeCamera(0.1, false, false, true, false)
			end
		end)
				
		RegisterHook("/Game/UI/Menus/FieldGuide/UI_BP_FieldGuide.UI_BP_FieldGuide_C:ChangeActivePage", function(fieldGuide, NewPage)	
			print("Field guide page changed to ", fieldGuide and fieldGuide:get().CurrentTabIndex, "\n")
			handleFieldGuidePageChange(fieldGuide:get().CurrentTabIndex)	
		end)
		
		--this works. Need to look into disabling decoupled pitch when this triggers
		RegisterHook("/Game/Pawn/Shared/StateTree/BTT_Biped_PotionStation.BTT_Biped_PotionStation_C:SetDesiredRotation", function(self)	
			--print("BTT_Biped_PotionStation_C:SetDesiredRotation\n")
		end)

		RegisterHook("/Game/Pawn/Shared/StateTree/BTT_Biped_PuzzleMiniGame.BTT_Biped_PuzzleMiniGame_C:ReceiveExecute", function(self)	
			print("PuzzleMiniGame_C:ReceiveExecute\n")
			isInAlohomora = true
			disableDecoupledYaw(true)
			isInCinematic = true
			if manualHideWand then wand.setVisible(pawn, false) end
		end)

		RegisterHook("/Game/Pawn/Shared/StateTree/BTT_Biped_PuzzleMiniGame.BTT_Biped_PuzzleMiniGame_C:ExitTask", function(self)	
			print("PuzzleMiniGame_C:ExitTask\n")
			isInAlohomora = false
			setLocomotionMode(locomotionMode)
			isInCinematic = false
		end)

		RegisterHook("/Game/UI/Actor/UI_BP_Astronomy_minigame.UI_BP_Astronomy_minigame_C:ConstellationImageLoaded", function(self)	
			print("Astronomy MiniGame ConstellationImageLoaded\n")
			uevrUtils.set_2D_mode(true)
			disableDecoupledYaw(true)
			isInCinematic = true
			if manualHideWand then wand.setVisible(pawn, false) end
			
			--auto solve game unless we can find a solution for UEVR FOV locking
			self:get():Solved()
			delay(3000, function()
				solveAstronomyMinigame()
			end)
		end)
		
		RegisterHook("/Game/UI/Actor/UI_BP_Astronomy_minigame.UI_BP_Astronomy_minigame_C:OnOutroEnded", function(self)	
			print("Astronomy MiniGame OnOutroEnded\n")
			setLocomotionMode(locomotionMode)
			uevrUtils.set_2D_mode(false)
			isInCinematic = false
		end)

		RegisterHook("/Game/Pawn/Player/BP_Biped_Player.BP_Biped_Player_C:ReceiveBeginPlay", function(self)
			print("ReceiveBeginPlay called\n")
		end)
				
		wand.registerLateHooks()
				
		if g_isPregame then
			RegisterHook("/Game/UI/HYDRA/UI_BP_EULA.UI_BP_EULA_C:AcceptClicked", function(self)
				print("UI_BP_EULA.UI_BP_EULA_C:AcceptClicked called\n")
				g_eulaClicked = true
				
			end)			
			--using this to show a smooth transition between creating your avatar and starting the game
			RegisterHook("/Game/Levels/RootLevel.RootLevel_C:UnloadAvatarCreatorLevel", function(self)	
				print("RootLevel_C:UnloadAvatarCreatorLevel\n")
				setLocomotionMode(locomotionMode)
			end)
		end

		g_isLateHooked = true
	end

end

wand.registerHooks()

RegisterHook("/Script/Engine.PlayerController:ClientRestart", function(self, NewPawn)
   	print("ClientRestart called\n")
	g_isShowingStartPageIntro = false
end)

RegisterHook("/Script/Phoenix.Biped_Character:GetTargetDestination", function(self)	
--print("GetTargetDestination\n")
	if isFP then
		local target = lastWandTargetLocation 
		if target ~= nil then
			return target 
		end
		return {X=0,Y=0,Z=0}
	end
end)


--called when X is pressed
RegisterHook("/Script/Phoenix.Biped_Player:PauseMenuStart", function(self)	
	print("PauseMenuStart\n")
end)

RegisterHook("/Script/Phoenix.Biped_Player:InteractingWithActor", function(self)	
	print("InteractingWithActor\n")
end)

--must have this one for smooth transition for normal field guide displays
RegisterHook("/Script/Phoenix.UIManager:FieldGuideMenuStart", function(self)	
	print("UIManager:FieldGuideMenuStart\n")
	uevrUtils.fadeCamera(1.0)
	enableVRCameraOffset = true
	disableDecoupledYaw(true)
end)

--doing this to catch the case where FieldGuideMenuStart isnt called during tutorials
RegisterHook("/Script/Phoenix.UIManager:IsDirectlyEnteringSubMenu", function(self)	
	print("UIManager:IsDirectlyEnteringSubMenu\n")
	enableVRCameraOffset = true
	disableDecoupledYaw(true)
end) 

RegisterHook("/Script/Phoenix.UIManager:ExitFieldGuideWithReason", function(self, ExitReason, SkipFadeScreen, CharacterID, Filename, FastTravelName)
	--next line crashes game during Load Game
	--print("UIManager:ExitFieldGuideWithReason", ExitReason:get(), " ", SkipFadeScreen:get(), " ", CharacterID:get(), " " , FastTravelName:get():ToString(), "\n")--, Filename:get(), FastTravelName:get(), "\n")
	print("UIManager:ExitFieldGuideWithReason\n")
	uevrUtils.set_2D_mode(false)
	setLocomotionMode(locomotionMode)
	enableVRCameraOffset = true
end)

RegisterHook("/Script/Phoenix.UIManager:MissionFailScreenLoaded", function(self)	
	print("UIManager:MissionFailScreenLoaded\n")
	uevrUtils.fadeCamera(1.0, true)
end)

--The start screen that appears before anything else and when you exit to Main Menu
RegisterHook("/Script/Phoenix.StartPageWidget:OnStartPageIntroStarted", function(self)	
	print("StartPageWidget:OnStartPageIntroStarted\n")
	if not g_eulaClicked then
		g_isShowingStartPageIntro = true
		uevrUtils.fadeCamera(0.1, true, false, true, true)
	end
	g_eulaClicked = false
end)

RegisterHook("/Script/Phoenix.StartPageWidget:OnStartPageOutroEnded", function(self)	
	print("StartPageWidget:OnStartPageOutroEnded\n")
	g_isShowingStartPageIntro = false
	uevrUtils.fadeCamera(0.1, false, false, true, false)
end)

--Creating a new character. It is too late for the fade to be effective
RegisterHook("/Script/Phoenix.PhoenixGameInstance:NewGame", function(self)	
	print("NewGame\n")
	g_isShowingStartPageIntro = false
	disableDecoupledYaw(true)
	enableVRCameraOffset = true
	uevrUtils.fadeCamera(1.0, false, false, true)
end)

RegisterHook("/Script/Phoenix.UIManager:OnFadeInBegin", function(self)	
	--print("UIManager:OnFadeInBegin\n")
	uevrUtils.fadeCamera(0.1, true, false)
	isInFadeIn = true
end)

RegisterHook("/Script/Phoenix.UIManager:OnFadeInComplete", function(self)	
	--print("UIManager:OnFadeInComplete",g_isShowingStartPageIntro,"\n")
	if not g_isShowingStartPageIntro and not isPlayingMovie then
		uevrUtils.fadeCamera(1.0, false, false, true)
	end
	hidePlayer(isFP)
	isInFadeIn = false
end)

RegisterHook("/Script/Phoenix.UIManager:OnFadeOutBegin", function(self)	
	--print("UIManager:OnFadeOutBegin\n")
	uevrUtils.fadeCamera(0.1, true, false)
end)
RegisterHook("/Script/Phoenix.UIManager:OnFadeOutComplete", function(self)	
	--print("UIManager:OnFadeOutComplete\n")
	if not g_isShowingStartPageIntro and not isPlayingMovie and not isInFadeIn then
		uevrUtils.fadeCamera(1.2, false, false, true)
	end
	hidePlayer(isFP)
end)

local tutorialInstance = nil
RegisterHook("/Script/Phoenix.TutorialSystem:StartTutorial", function(self, TutorialName)	
	tutorialInstance = self:get()
	--if we do it immediately then CurrentTutorialStepData still points to the previous tutorial
	delay(100, function() 
		print("TutorialName 1=",tutorialInstance.CurrentTutorialStepData.Title,"\n")
		print("TutorialName 2=",tutorialInstance.CurrentTutorialStepData.Title:ToString(),"\n")
		print("TutorialName 3=",tutorialInstance.CurrentTutorialStepData.Alias:ToString(),"\n")
		print("TutorialName 4=",tutorialInstance.CurrentTutorialStepData.Body:ToString(),"\n")
		print("TutorialName 5=",tutorialInstance.CurrentTutorialStepData.BodyPC:ToString(),"\n")
		print("StartTutorial modal=",tutorialInstance.CurrentTutorialStepData.Modal,"\n")
		print("StartTutorial PausesTheGame=",tutorialInstance.CurrentTutorialStepData.PausesTheGame,"\n")
		if tutorialInstance.CurrentTutorialStepData.Alias:ToString() == "MovementAlias" then
			--bypassTargetCall = true
			fadeDuration = defaultFadeDuration
			setCharacterInFPSView(isFP) --need to do this in case we come directly from the dragon biting scene
			if manualHideWand then wand.holsterWand(pawn, true) end
		end
		
		if tutorialInstance.CurrentTutorialStepData.Body:ToString() == "TUT_display_AutoTargetConsole2_desc" then
			hideActorForNextCinematic = true
			if manualHideWand then wand.holsterWand(pawn, false) end
		end
		
		
		if tutorialInstance.CurrentTutorialStepData.PausesTheGame then
			uevrUtils.fadeCamera(0.3, true)
		end
		
		--tutorialInstance.CurrentTutorialStepData.Alias:ToString() == "Controls"
		if tutorialInstance.CurrentTutorialStepData.Body:ToString() == "TUT_Display_SpellMiniGameAdvanced_desc" then
			hidePlayer(isFP)
		end
		
		--unhide robe hidden sometime during intro combat
		if tutorialInstance.CurrentTutorialStepData.Alias:ToString() == "SprintingTutorialStep1" then
			hidePlayer(false)
		end
		
		if tutorialInstance.CurrentTutorialStepData.Alias:ToString() == "LookAround" then
			--loadGringottsHooks()
		end
				
		-- if tutorialInstance.CurrentTutorialStepData.Alias:ToString() == "UseCabbage" then
			-- disableDecoupledYaw(true)
		-- end


	end)

end)

-- when spells teaching is finished
RegisterHook("/Script/Phoenix.TutorialSystem:OnCurrentScreenOutroEnded", function(self, tutorialName)	
	print("TutorialSystem:OnCurrentScreenOutroEnded\n")
	if uevrUtils.isFadeHardLocked() then
		uevrUtils.fadeCamera(0.1, false, false, true)
	end
	hidePlayer(isFP)
end)


NotifyOnNewObject("/Script/BinkMediaPlayer.BinkMediaPlayer", function(context)	
	print("Media Player created\n")
	updateMediaPlayers()
end)


RegisterHook("/Script/Phoenix.Biped_Player:OnCharacterLoadComplete", function(self)
   	print("OnCharacterLoadComplete called\n")
	--reset relevant globals
	isInCinematic = false
end)

RegisterHook("/Script/Phoenix.IntroBlueprintFunctionLibrary:IntroStart", function(self)
	print("IntroBlueprintFunctionLibrary:IntroStart called\n")
	g_isShowingStartPageIntro = false
end)

--this gets called
RegisterHook("/Script/Phoenix.BrewingSite:BeginBrewingPotion", function(self)
	print("BrewingSite:BeginBrewingPotion called\n")
end)


function overrideCharacterOpacity()
	if uevrUtils.validate_object(pawn) and uevrUtils.validate_object(pawn.Mesh) then
		local propertyName = "FINALOPACITY"
		local propertyFName = uevrUtils.fname_from_string(propertyName)	
		local value = 1.0
		local materials = pawn.Mesh.OverrideMaterials
		for i, material in ipairs(materials) do
			--local oldValue = material:K2_GetScalarParameterValue(propertyFName)
			material:SetScalarParameterValue(propertyFName, value)
--			material.Parent:SetScalarParameterValue(propertyFName, value)
			--local newValue = material:K2_GetScalarParameterValue(propertyFName)
			--print("Child Material:",i, material:get_full_name(), oldValue, newValue,"\n")
		end
		
			-- children = pawn.Mesh.AttachChildren
			-- if children ~= nil then
				-- for i, child in ipairs(children) do
					-- --if child:is_a(static_mesh_component_c) then
						-- local materials = child.OverrideMaterials
						-- for i, material in ipairs(materials) do
							-- --local oldValue = material:K2_GetScalarParameterValue(propertyFName)
							-- material:SetScalarParameterValue(propertyFName, value)
							-- --local newValue = material:K2_GetScalarParameterValue(propertyFName)
							-- --print("Child Material:",i, material:get_full_name(), oldValue, newValue,"\n")
						-- end
					-- --end
					
				-- end
			-- end

	end
end

function getBoneSpaceLocalRotator(component, boneFName, boneSpace)
	if component ~= nil and boneFName ~= nil then
		if boneSpace == nil then boneSpace = 0 end
		local pTransform = component:GetBoneTransformByName(component:GetParentBone(boneFName), boneSpace)
		local wTranform = component:GetBoneTransformByName(boneFName, boneSpace)
		local localTransform = kismet_math_library:ComposeTransforms(wTranform, kismet_math_library:InvertTransform(pTransform))
		local localRotator = uevrUtils.rotator(0, 0, 0)
		kismet_math_library:BreakTransform(localTransform,temp_vec3, localRotator, temp_vec3)
		return localRotator, pTransform
	end
	return nil, nil
end
--if you know the parent transform then pass it in to save a step
function setBoneSpaceLocalRotator(component, boneFName, localRotator, boneSpace, pTransform)
	if component ~= nil and boneFName ~= nil then
		if boneSpace == nil then boneSpace = 0 end
		if pTransform == nil then pTransform = component:GetBoneTransformByName(component:GetParentBone(boneFName), boneSpace) end
		local wRotator = kismet_math_library:TransformRotation(pTransform, localRotator);
		component:SetBoneRotationByName(boneFName, wRotator, boneSpace)
	end
end

function setBoneSpaceLocalTransform(component, boneFName, localTransform, boneSpace, pTransform)
	if component ~= nil and boneFName ~= nil then
		if boneSpace == nil then boneSpace = 0 end
		if pTransform == nil then pTransform = component:GetBoneTransformByName(component:GetParentBone(boneFName), boneSpace) end
		local wTransform = kismet_math_library:ComposeTransforms(localTransform, pTransform)
		component:SetBoneTransformByName(boneFName, wTransform, boneSpace)
	end
end

function getChildSkeletalMeshComponent(parent, name)
	local skeletalMeshComponent = nil
	local children = parent.AttachChildren
    for i, child in ipairs(children) do
		if  string.find(child:get_full_name(), name) then
			skeletalMeshComponent = child
		end
	end
	return skeletalMeshComponent
end

function createPoseableComponent(skeletalMeshComponent)
	local poseableComponent = nil
	if skeletalMeshComponent ~= nil then
		poseableComponent = uevrUtils.createPoseableMeshFromSkeletalMesh(skeletalMeshComponent)
		--poseableComponent:K2_AttachTo(vrBody, uevrUtils.fname_from_string(""), 0, false)
		controllers.attachComponentToController(1, poseableComponent)
		uevrUtils.set_component_relative_transform(poseableComponent, {X=0, Y=0, Z=0}, {Pitch=0, Yaw=-90, Roll=0})		
		poseableComponent:SetVisibility(false, true)
		poseableComponent:SetHiddenInGame(true, true)
		--delay(1000, function() 
			poseableComponent:SetVisibility(true, true) 
			poseableComponent:SetHiddenInGame(false, true)
		--end)
		--poseableComponent:SetHiddenInGame(false,true)
		--skeletalMeshComponent:SetMasterPoseComponent(poseableComponent, true)
		--poseableComponent.bUseAttachParentBound = true
		
		--fixes flickering but > 1 causes a pefromance hit with dynamic shadows
		poseableComponent.BoundsScale = 8.0
		poseableComponent.bCastDynamicShadow=false
		
		delay(500,function()
			local materials = skeletalMeshComponent:GetMaterials()
			uevrUtils.print("Found " .. #materials .. " materials on skeletalMeshComponent")
			for i, material in ipairs(materials) do				
				poseableComponent:SetMaterial(i, material)
			end
		end)
	else
		print("SkeletalMeshComponent was not valid\n")
	end
	updatePoseableComponent(poseableComponent)
	return poseableComponent
end

local boneVisualizers = {}
function createVisualSkeleton(skeletalMeshComponent)
	boneVisualizers = {}
	local count = skeletalMeshComponent:GetNumBones()
	print(count, "bones")
	for index = 1 , count do
		uevrUtils.print(index .. " " .. skeletalMeshComponent:GetBoneName(index):to_string())
		boneVisualizers[index] = uevrUtils.createStaticMeshComponent("StaticMesh /Engine/EngineMeshes/Sphere.Sphere")
		uevrUtils.set_component_relative_transform(boneVisualizers[index], nil, nil, {X=0.003, Y=0.003, Z=0.003})
	end

end

function updateVisualSkeleton(skeletalMeshComponent)
	local count = skeletalMeshComponent:GetNumBones()
	local boneSpace = 0
	for index = 1 , count do
		local location = skeletalMeshComponent:GetBoneLocationByName(skeletalMeshComponent:GetBoneName(index), boneSpace)
		boneVisualizers[index]:K2_SetWorldLocation(location, false, reusable_hit_result, false)
	end

end

function setVisualSkeletonBoneScale(skeletalMeshComponent, index, scale)
	if skeletalMeshComponent ~= nil then
		if index < 1 then index = 1 end
		if index > skeletalMeshComponent:GetNumBones() then index = skeletalMeshComponent:GetNumBones() end
		uevrUtils.print("Visualizing " .. index .. " " .. skeletalMeshComponent:GetBoneName(index):to_string())
		local component = boneVisualizers[index]
		component.RelativeScale3D.X = scale
		component.RelativeScale3D.Y = scale
		component.RelativeScale3D.Z = scale
	end
end

function updateHands()
	-- if armsComponent ~= nil then
		-- updatePoseableComponent(armsComponent)
	-- end
	if glovesComponent ~= nil then
		--updatePoseableComponent(glovesComponent)
		--updateVisualSkeleton(glovesComponent)
	end
end

function updatePoseableComponent(poseableComponent)
	if poseableComponent ~= nil then
		local boneSpace = 0
		
		local boneFName = uevrUtils.fname_from_string("RightHand")		
		local location = controllers.getControllerLocation(1)
		local rotation = controllers.getControllerRotation(1)		
		rotation.Pitch = -rotation.Pitch 
		rotation.Yaw = rotation.Yaw + 180 
		rotation.Roll = -rotation.Roll
		local forwardVector = kismet_math_library:GetForwardVector(rotation)
		location = location + forwardVector * 6

		location = poseableComponent:GetBoneLocationByName(poseableComponent:GetBoneName(1), boneSpace);

		--poseableComponent:SetBoneLocationByName(boneFName, location, boneSpace)
		--poseableComponent:SetBoneRotationByName(boneFName, rotation, boneSpace)
	

		-- poseableComponent:SetBoneLocationByName(uevrUtils.fname_from_string("RightShoulder"), location, boneSpace);
		-- poseableComponent:SetBoneLocationByName(uevrUtils.fname_from_string("RightArm"), location, boneSpace);
		poseableComponent:SetBoneLocationByName(uevrUtils.fname_from_string("RightForeArm"), location, boneSpace);

		local pTransform = poseableComponent:GetBoneTransformByName(poseableComponent:GetBoneName(1), boneSpace)
		--x is left/right   y is up/down   z is back/forth
		local cTransform = kismet_math_library:MakeTransform(uevrUtils.vector(0, 0, -30), uevrUtils.rotator(-90, 0, -90), uevrUtils.vector(1.2, 1.2, 1.2))
		setBoneSpaceLocalTransform(poseableComponent, uevrUtils.fname_from_string("RightForeArm"), cTransform, boneSpace, pTransform)
		--setBoneSpaceLocalRotator(poseableComponent, uevrUtils.fname_from_string("RightForeArm"), uevrUtils.rotator(-90, 0, 0), boneSpace, pTransform)
		-- local miniScale = 0.0001
-- --		poseableComponent:SetBoneScaleByName(poseableComponent:GetBoneName(1), vector_3f(miniScale, miniScale, miniScale), boneSpace);
-- --		poseableComponent:SetBoneScaleByName(uevrUtils.fname_from_string("RightShoulder"), vector_3f(miniScale, miniScale, miniScale), boneSpace);
		-- -- poseableComponent:SetBoneScaleByName(uevrUtils.fname_from_string("RightArm"), vector_3f(miniScale, miniScale, miniScale), boneSpace);
		-- -- poseableComponent:SetBoneScaleByName(uevrUtils.fname_from_string("RightForeArm"), vector_3f(miniScale, miniScale, miniScale), boneSpace);
		-- poseableComponent:SetBoneScaleByName(boneFName, vector_3f(1.2, 1.2, 1.2), boneSpace);		
	
	
	
		-- boneFName = uevrUtils.fname_from_string("LeftHand")		
		-- location = controllers.getControllerLocation(0)
		-- rotation = controllers.getControllerRotation(0)		
		-- rotation.Roll = rotation.Roll + 180 
		
		-- location = poseableComponent:GetBoneLocationByName(poseableComponent:GetBoneName(1), boneSpace);

		-- poseableComponent:SetBoneLocationByName(boneFName, location, boneSpace)
		-- --poseableComponent:SetBoneRotationByName(boneFName, rotation, boneSpace)
		
		-- poseableComponent:SetBoneLocationByName(uevrUtils.fname_from_string("LeftShoulder"), location, boneSpace);
		-- poseableComponent:SetBoneLocationByName(uevrUtils.fname_from_string("LeftArm"), location, boneSpace);
		-- -- poseableComponent:SetBoneLocationByName(uevrUtils.fname_from_string("LeftForeArm"), location, boneSpace);

		poseableComponent:SetBoneScaleByName(uevrUtils.fname_from_string("LeftShoulder"), vector_3f(0, 0, 0), boneSpace);		

	end
end

-- function updatePoseableComponent(poseableComponent)
	-- if poseableComponent ~= nil then
		-- local boneSpace = 0
		
		-- local boneFName = uevrUtils.fname_from_string("RightHand")		
		-- local location = controllers.getControllerLocation(1)
		-- local rotation = controllers.getControllerRotation(1)		
		-- rotation.Pitch = -rotation.Pitch 
		-- rotation.Yaw = rotation.Yaw + 180 
		-- rotation.Roll = -rotation.Roll
		-- local forwardVector = kismet_math_library:GetForwardVector(rotation)
		-- location = location + forwardVector * 6
		-- poseableComponent:SetBoneLocationByName(boneFName, location, boneSpace)
		-- poseableComponent:SetBoneRotationByName(boneFName, rotation, boneSpace)
	
		-- poseableComponent:SetBoneLocationByName(uevrUtils.fname_from_string("RightShoulder"), location, boneSpace);
		-- poseableComponent:SetBoneLocationByName(uevrUtils.fname_from_string("RightArm"), location, boneSpace);
		-- poseableComponent:SetBoneLocationByName(uevrUtils.fname_from_string("RightForeArm"), location, boneSpace);

		-- local miniScale = 0.0001
-- --		poseableComponent:SetBoneScaleByName(poseableComponent:GetBoneName(1), vector_3f(miniScale, miniScale, miniScale), boneSpace);
		-- poseableComponent:SetBoneScaleByName(uevrUtils.fname_from_string("RightShoulder"), vector_3f(miniScale, miniScale, miniScale), boneSpace);
		-- poseableComponent:SetBoneScaleByName(uevrUtils.fname_from_string("RightArm"), vector_3f(miniScale, miniScale, miniScale), boneSpace);
		-- poseableComponent:SetBoneScaleByName(uevrUtils.fname_from_string("RightForeArm"), vector_3f(miniScale, miniScale, miniScale), boneSpace);
		-- poseableComponent:SetBoneScaleByName(boneFName, vector_3f(1.2, 1.2, 1.2), boneSpace);		
	
		-- boneFName = uevrUtils.fname_from_string("LeftHand")		
		-- location = controllers.getControllerLocation(0)
		-- rotation = controllers.getControllerRotation(0)		
		-- rotation.Roll = rotation.Roll + 180 
		-- poseableComponent:SetBoneLocationByName(boneFName, location, boneSpace)
		-- poseableComponent:SetBoneRotationByName(boneFName, rotation, boneSpace)
		
		-- -- poseableComponent:SetBoneLocationByName(uevrUtils.fname_from_string("LeftShoulder"), location, boneSpace);
		-- -- poseableComponent:SetBoneLocationByName(uevrUtils.fname_from_string("LeftArm"), location, boneSpace);
		-- -- poseableComponent:SetBoneLocationByName(uevrUtils.fname_from_string("LeftForeArm"), location, boneSpace);

	-- end
-- end


function createPoseableHands()
	--local skeletalMeshComponent = uevrUtils.find_instance_of("Class /Script/Engine.SkeletalMeshComponent", "Gloves")
	local skeletalMeshComponent = nil
	local children = pawn.Mesh.AttachChildren
    for i, child in ipairs(children) do
		if  string.find(child:get_full_name(), "Gloves") then
			skeletalMeshComponent = child
		end
	end

	local poseableComponent = nil
	if skeletalMeshComponent ~= nil then
		poseableComponent = uevrUtils.createPoseableMeshFromSkeletalMesh(skeletalMeshComponent)
		--poseableComponent = copyPoseableMeshFromSkeletalMesh(skeletalMeshComponent)
		poseableComponent:K2_AttachTo(skeletalMeshComponent, uevrUtils.fname_from_string(""), 0, false)
		poseableComponent:SetVisibility(false,true)
	--controllers.attachComponentToController(0, poseableComponent)
		--uevrUtils.set_component_relative_transform(meshComponent, {X=10, Y=10, Z=10})			

		--skeletalMeshComponent:SetMasterPoseComponent(poseableComponent, true)
	end
	return poseableComponent
end

function updatePoseableComponent_old(poseableComponent)
	if poseableComponent ~= nil then
		local boneSpace = 0
		
		local boneFName = uevrUtils.fname_from_string("RightHand")		
		local location = controllers.getControllerLocation(1)
		local rotation = controllers.getControllerRotation(1)		
		rotation.Pitch = -rotation.Pitch 
		rotation.Yaw = rotation.Yaw + 180 
		rotation.Roll = -rotation.Roll
		poseableComponent:SetBoneLocationByName(boneFName, location, boneSpace)
		poseableComponent:SetBoneRotationByName(boneFName, rotation, boneSpace)
		
		poseableComponent:SetBoneLocationByName(uevrUtils.fname_from_string("RightShoulder"), location, boneSpace);
		poseableComponent:SetBoneLocationByName(uevrUtils.fname_from_string("RightArm"), location, boneSpace);
		poseableComponent:SetBoneLocationByName(uevrUtils.fname_from_string("RightForeArm"), location, boneSpace);

		local miniScale = 0.0001
		poseableComponent:SetBoneScaleByName(poseableComponent:GetBoneName(1), vector_3f(miniScale, miniScale, miniScale), boneSpace);
		poseableComponent:SetBoneScaleByName(boneFName, vector_3f(1, 1, 1), boneSpace);		

		if debugHands then
			print(location.X,location.Y,location.Z,"\n")
		end
		
		boneFName = uevrUtils.fname_from_string("LeftHand")		
		location = controllers.getControllerLocation(0)
		rotation = controllers.getControllerRotation(0)		
		rotation.Roll = rotation.Roll + 180 
		poseableComponent:SetBoneLocationByName(boneFName, location, boneSpace)
		poseableComponent:SetBoneRotationByName(boneFName, rotation, boneSpace)
	end
end

function logMeshComponentChildren(meshComponent)
	local children = meshComponent.AttachChildren
    for i, child in ipairs(children) do
		uevrUtils.print(child:get_full_name())
	end

end




RegisterKeyBind(Key.F1, function()
    print("F1 pressed. First Person mode = ",not isFP,"\n")
	
    isFP = not isFP
	updatePlayer()
	if isFP then
		wand.connect(mounts.getMountPawn(pawn), g_isLeftHanded and 0 or 1)
		setLocomotionMode(locomotionMode)
	else
		wand.disconnect()
		disableDecoupledYaw(true)
	end
end)

local inNativeMode = true
RegisterKeyBind(Key.F2, function()
    print("F2 pressed\n")
	ExecuteInGameThread( function()
		--vrBody = uevrUtils.createStaticMeshComponent("StaticMesh /Engine/EngineMeshes/Sphere.Sphere")
		glovesComponent = createPoseableComponent(getChildSkeletalMeshComponent(pawn.Mesh, "Gloves"))
		armsComponent = createPoseableComponent(getChildSkeletalMeshComponent(pawn.Mesh, "Arms"))
		createVisualSkeleton(glovesComponent)
	end)
	
	-- print(
	-- pawn:IsPlayerControlled(),
    -- pawn:IsPawnControlled(),
    -- pawn:IsMoveInputIgnored(),
    -- pawn:IsLocallyControlled(),
    -- pawn:IsControlled(),
    -- pawn:IsBotControlled(),
	-- Statics:IsGamePaused(uevrUtils.get_world()),
	-- uiManager:InPauseMode(),
	-- uiManager:GetIsUIShown(),
	-- "\n")

	-- ExecuteInGameThread( function()
		-- print("1\n")
		-- connectCube(1)
		-- print("2\n")
		-- wand.connectAltWand(mounts.getMountPawn(pawn), g_isLeftHanded and 0 or 1)
		-- print("3\n")
	-- end)
	
	--wand.debugWand(pawn)
	--altConnectWandToController(isLeftHanded)
	
	-- local DevMenu = FindFirstOf("UI_BP_FrontEnd_Menu_C")

	-- if DevMenu:IsValid() then
		-- DevMenu:DevMenuButton()
	-- end

	-- inNativeMode = not inNativeMode
	-- if inNativeMode then
		-- uevr.params.vr.set_mod_value("VR_GhostingFix","false")
		-- uevr.params.vr.set_mod_value("VR_NativeStereoFix","true")
		-- uevr.params.vr.set_mod_value("VR_RenderingMethod","0")
	-- else
		-- uevr.params.vr.set_mod_value("VR_GhostingFix","true")
		-- uevr.params.vr.set_mod_value("VR_NativeStereoFix","false")
		-- uevr.params.vr.set_mod_value("VR_RenderingMethod","1")
	-- end

end)
local boneIndex = 1

RegisterKeyBind(Key.F3, function()
    print("F3 pressed\n")
	locomotionMode = locomotionMode + 1
	if locomotionMode > 2 then
		locomotionMode = 0
	end
	setLocomotionMode(locomotionMode)
	print("Locomotion Mode changed to ", locomotionMode, "\n")
	Json.saveTable(locomotionMode, "VRFPSettings.json", "locomotionModeSaved")
end)

RegisterKeyBind(Key.F4, function()
    print("F4 pressed\n")
	if useVolumetricFog ~= nil then
		useVolumetricFog = not useVolumetricFog
	else
		useVolumetricFog = false
	end
	print("Use fog ", useVolumetricFog, "\n")
end)

RegisterKeyBind(Key.F5, function()
    print("F5 pressed\n")
	toggle2DScreen()
end)


RegisterKeyBind(Key.F6, function()
    print("F6 pressed\n")
	controlMode = controlMode + 1
	if controlMode > 1 then
		controlMode = 0
	end
	print("Control Mode changed to ", controlMode, "\n")
	Json.saveTable(controlMode, "VRFPSettings.json", "controlModeSaved")

end)

RegisterKeyBind(Key.F7, function()
    print("F7 pressed\n")
	gestureMode = gestureMode + 1
	if gestureMode > 1 then
		gestureMode = 0
	end
	print("Gesture Mode changed to ", gestureMode, "\n")
	Json.saveTable(gestureMode, "VRFPSettings.json", "gestureModeSaved")
end)

RegisterKeyBind(Key.F8, function()
    print("F8 pressed\n")
	useCrossHair = not useCrossHair
	if useCrossHair then
		createCrosshair()
	end

	print("Use crosshair ", useCrossHair, "\n")
	Json.saveTable(useCrossHair, "VRFPSettings.json", "useCrossHairSaved")
end)

RegisterKeyBind(Key.F9, function()
    print("F9 pressed\n")
	targetingMode = targetingMode + 1
	if targetingMode > 1 then
		targetingMode = 0
	end
	print("Targeting Mode changed to ", targetingMode, "\n")
	UEHelpers:GetPlayerController():ActivateAutoTargetSense(targetingMode == 1, true)
	Json.saveTable(targetingMode, "VRFPSettings.json", "targetingModeSaved")
end)

RegisterKeyBind(Key.NUM_EIGHT, function()
    print("NUM8 pressed\n")
	setVisualSkeletonBoneScale(glovesComponent, boneIndex, 0.003)
	boneIndex = boneIndex + 1
	setVisualSkeletonBoneScale(glovesComponent, boneIndex, 0.006)
end)

RegisterKeyBind(Key.NUM_TWO, function()
    print("NUM2 pressed\n")
	setVisualSkeletonBoneScale(glovesComponent, boneIndex, 0.003)
	boneIndex = boneIndex - 1
	if boneIndex < 1 then boneIndex = 1 end
	setVisualSkeletonBoneScale(glovesComponent, boneIndex, 0.006)
end)

-- [2025-03-28 16:47:53.7592097] [Lua] SkeletalMeshComponent /Game/Levels/Overland/Overland.Overland.PersistentLevel.BP_Biped_Player_C_2147460116.Customization.Hair
-- [2025-03-28 16:47:53.7592190] [Lua] SkeletalMeshComponent /Game/Levels/Overland/Overland.Overland.PersistentLevel.BP_Biped_Player_C_2147460116.Customization.Arms
-- [2025-03-28 16:47:53.7592277] [Lua] SkeletalMeshComponent /Game/Levels/Overland/Overland.Overland.PersistentLevel.BP_Biped_Player_C_2147460116.Customization.Robe
-- [2025-03-28 16:47:53.7592361] [Lua] SkeletalMeshComponent /Game/Levels/Overland/Overland.Overland.PersistentLevel.BP_Biped_Player_C_2147460116.Customization.Glasses
-- [2025-03-28 16:47:53.7592433] [Lua] SkeletalMeshComponent /Game/Levels/Overland/Overland.Overland.PersistentLevel.BP_Biped_Player_C_2147460116.Customization.Gloves
-- [2025-03-28 16:47:53.7592510] [Lua] SkeletalMeshComponent /Game/Levels/Overland/Overland.Overland.PersistentLevel.BP_Biped_Player_C_2147460116.Customization.Hat
-- [2025-03-28 16:47:53.7592585] [Lua] SkeletalMeshComponent /Game/Levels/Overland/Overland.Overland.PersistentLevel.BP_Biped_Player_C_2147460116.Customization.Scarf
-- [2025-03-28 16:47:53.7592657] [Lua] SkeletalMeshComponent /Game/Levels/Overland/Overland.Overland.PersistentLevel.BP_Biped_Player_C_2147460116.Customization.Upper
-- [2025-03-28 16:47:53.7592732] [Lua] SkeletalMeshComponent /Game/Levels/Overland/Overland.Overland.PersistentLevel.BP_Biped_Player_C_2147460116.Customization.Lower
-- [2025-03-28 16:47:53.7592802] [Lua] SkeletalMeshComponent /Game/Levels/Overland/Overland.Overland.PersistentLevel.BP_Biped_Player_C_2147460116.Customization.Socks
-- [2025-03-28 16:47:53.7592869] [Lua] SkeletalMeshComponent /Game/Levels/Overland/Overland.Overland.PersistentLevel.BP_Biped_Player_C_2147460116.Customization.Shoes

-- [2025-03-29 18:07:12.0525646] [Lua] 147		bones[2025-03-29 18:07:12.0526139] [Lua] 1		IK_Spine3		
-- [2025-03-29 18:07:12.0526545] [Lua] 2		IK_RightHand		
-- [2025-03-29 18:07:12.0526843] [Lua] 3		SKT_FX_Reference2		
-- [2025-03-29 18:07:12.0527124] [Lua] 4		SKT_FX_Reference1		
-- [2025-03-29 18:07:12.0527392] [Lua] 5		SKT_Reference		
-- [2025-03-29 18:07:12.0527685] [Lua] 6		IK_LeftHand		
-- [2025-03-29 18:07:12.0528061] [Lua] 7		SKT_HeadCamera		
-- [2025-03-29 18:07:12.0528345] [Lua] 8		Hips		
-- [2025-03-29 18:07:12.0528616] [Lua] 9		RightUpLeg		
-- [2025-03-29 18:07:12.0528885] [Lua] 10		RightLeg		
-- [2025-03-29 18:07:12.0529341] [Lua] 11		RightLegTwist1		
-- [2025-03-29 18:07:12.0529859] [Lua] 12		RightFoot		
-- [2025-03-29 18:07:12.0530407] [Lua] 13		RightToeBase		
-- [2025-03-29 18:07:12.0530942] [Lua] 14		RightToeBaseEnd		
-- [2025-03-29 18:07:12.0531405] [Lua] 15		RightUpLegTwist1		
-- [2025-03-29 18:07:12.0531805] [Lua] 16		RightUpLegTwist2		
-- [2025-03-29 18:07:12.0532100] [Lua] 17		SKT_FX_Hips		
-- [2025-03-29 18:07:12.0532385] [Lua] 18		Spine		
-- [2025-03-29 18:07:12.0532666] [Lua] 19		Spine1		
-- [2025-03-29 18:07:12.0532933] [Lua] 20		Spine2		
-- [2025-03-29 18:07:12.0533205] [Lua] 21		Spine3		
-- [2025-03-29 18:07:12.0533484] [Lua] 22		SKT_Back		
-- [2025-03-29 18:07:12.0533754] [Lua] 23		SKT_Chest		
-- [2025-03-29 18:07:12.0534020] [Lua] 24		LeftShoulder		
-- [2025-03-29 18:07:12.0534331] [Lua] 25		LeftArm		
-- [2025-03-29 18:07:12.0534619] [Lua] 26		LeftForeArm		
-- [2025-03-29 18:07:12.0534936] [Lua] 27		LeftForeArmTwist3		
-- [2025-03-29 18:07:12.0535399] [Lua] 28		LeftForeArmTwist1		
-- [2025-03-29 18:07:12.0535829] [Lua] 29		LeftHand		
-- [2025-03-29 18:07:12.0536144] [Lua] 30		LeftInHandPinky		
-- [2025-03-29 18:07:12.0536414] [Lua] 31		LeftHandPinky1		
-- [2025-03-29 18:07:12.0536671] [Lua] 32		LeftHandPinky2		
-- [2025-03-29 18:07:12.0536933] [Lua] 33		LeftHandPinky3		
-- [2025-03-29 18:07:12.0537202] [Lua] 34		LeftHandPinky4		
-- [2025-03-29 18:07:12.0537462] [Lua] 35		SKT_LeftHand		
-- [2025-03-29 18:07:12.0537736] [Lua] 36		LeftInHandIndex		
-- [2025-03-29 18:07:12.0538005] [Lua] 37		LeftHandIndex1		
-- [2025-03-29 18:07:12.0538267] [Lua] 38		LeftHandIndex2		
-- [2025-03-29 18:07:12.0538576] [Lua] 39		LeftHandIndex3		
-- [2025-03-29 18:07:12.0538834] [Lua] 40		LeftHandIndex4		
-- [2025-03-29 18:07:12.0539091] [Lua] 41		LeftInHandRing		
-- [2025-03-29 18:07:12.0539352] [Lua] 42		LeftHandRing1		
-- [2025-03-29 18:07:12.0539613] [Lua] 43		LeftHandRing2		
-- [2025-03-29 18:07:12.0539869] [Lua] 44		LeftHandRing3		
-- [2025-03-29 18:07:12.0540123] [Lua] 45		LeftHandRing4		
-- [2025-03-29 18:07:12.0540387] [Lua] 46		SKT_FX_LeftHand		
-- [2025-03-29 18:07:12.0540646] [Lua] 47		LeftHandThumb1		
-- [2025-03-29 18:07:12.0540903] [Lua] 48		LeftHandThumb2		
-- [2025-03-29 18:07:12.0541157] [Lua] 49		LeftHandThumb3		
-- [2025-03-29 18:07:12.0541412] [Lua] 50		LeftHandThumb4		
-- [2025-03-29 18:07:12.0541673] [Lua] 51		LeftInHandMiddle		
-- [2025-03-29 18:07:12.0541928] [Lua] 52		LeftHandMiddle1		
-- [2025-03-29 18:07:12.0542187] [Lua] 53		LeftHandMiddle2		
-- [2025-03-29 18:07:12.0542460] [Lua] 54		LeftHandMiddle3		
-- [2025-03-29 18:07:12.0542724] [Lua] 55		LeftHandMiddle4		
-- [2025-03-29 18:07:12.0542980] [Lua] 56		LeftForeArmTwist2		
-- [2025-03-29 18:07:12.0543235] [Lua] 57		LeftArmTwist1		
-- [2025-03-29 18:07:12.0543498] [Lua] 58		LeftArmTwist2		
-- [2025-03-29 18:07:12.0543760] [Lua] 59		Neck		
-- [2025-03-29 18:07:12.0544011] [Lua] 60		Neck1		
-- [2025-03-29 18:07:12.0544272] [Lua] 61		head		
-- [2025-03-29 18:07:12.0544541] [Lua] 62		SKT_Head		
-- [2025-03-29 18:07:12.0544795] [Lua] 63		HeadEnd		
-- [2025-03-29 18:07:12.0545053] [Lua] 64		face		
-- [2025-03-29 18:07:12.0545310] [Lua] 65		eye_left		
-- [2025-03-29 18:07:12.0545564] [Lua] 66		nose		
-- [2025-03-29 18:07:12.0545859] [Lua] 67		jaw		
-- [2025-03-29 18:07:12.0546125] [Lua] 68		lip_corners		
-- [2025-03-29 18:07:12.0546378] [Lua] 69		lip_upper		
-- [2025-03-29 18:07:12.0546642] [Lua] 70		lip_lower		
-- [2025-03-29 18:07:12.0546894] [Lua] 71		eye_lid_right		
-- [2025-03-29 18:07:12.0547150] [Lua] 72		eye_lid_in_right		
-- [2025-03-29 18:07:12.0547574] [Lua] 73		eye_lid_out_right		
-- [2025-03-29 18:07:12.0547865] [Lua] 74		mouth_bag		
-- [2025-03-29 18:07:12.0548155] [Lua] 75		tongue_jaw		
-- [2025-03-29 18:07:12.0548423] [Lua] 76		tongue_01		
-- [2025-03-29 18:07:12.0548686] [Lua] 77		tongue_02		
-- [2025-03-29 18:07:12.0548944] [Lua] 78		tongue_03		
-- [2025-03-29 18:07:12.0549274] [Lua] 79		tongue_04		
-- [2025-03-29 18:07:12.0549731] [Lua] 80		tongue_05		
-- [2025-03-29 18:07:12.0550247] [Lua] 81		tongue_06		
-- [2025-03-29 18:07:12.0550699] [Lua] 82		teeth_lwr		
-- [2025-03-29 18:07:12.0551106] [Lua] 83		teeth_upr		
-- [2025-03-29 18:07:12.0551577] [Lua] 84		eye_right		
-- [2025-03-29 18:07:12.0551849] [Lua] 85		eye_lid_left		
-- [2025-03-29 18:07:12.0552123] [Lua] 86		eye_lid_in_left		
-- [2025-03-29 18:07:12.0552390] [Lua] 87		eye_lid_out_left		
-- [2025-03-29 18:07:12.0552655] [Lua] 88		RightShoulder		
-- [2025-03-29 18:07:12.0552917] [Lua] 89		RightArm		
-- [2025-03-29 18:07:12.0553178] [Lua] 90		RightArmTwist1		
-- [2025-03-29 18:07:12.0553459] [Lua] 91		RightForeArm		
-- [2025-03-29 18:07:12.0553781] [Lua] 92		RightHand		
-- [2025-03-29 18:07:12.0554060] [Lua] 93		SKT_FX_RightHand		
-- [2025-03-29 18:07:12.0554319] [Lua] 94		RightHandThumb1		
-- [2025-03-29 18:07:12.0554584] [Lua] 95		RightHandThumb2		
-- [2025-03-29 18:07:12.0554877] [Lua] 96		RightHandThumb3		
-- [2025-03-29 18:07:12.0555147] [Lua] 97		RightHandThumb4		
-- [2025-03-29 18:07:12.0555406] [Lua] 98		RightInHandMiddle		
-- [2025-03-29 18:07:12.0555664] [Lua] 99		RightHandMiddle1		
-- [2025-03-29 18:07:12.0555920] [Lua] 100		RightHandMiddle2		
-- [2025-03-29 18:07:12.0556186] [Lua] 101		RightHandMiddle3		
-- [2025-03-29 18:07:12.0556447] [Lua] 102		RightHandMiddle4		
-- [2025-03-29 18:07:12.0556720] [Lua] 103		SKT_RightHand		
-- [2025-03-29 18:07:12.0556979] [Lua] 104		RightInHandIndex		
-- [2025-03-29 18:07:12.0557239] [Lua] 105		RightHandIndex1		
-- [2025-03-29 18:07:12.0557501] [Lua] 106		RightHandIndex2		
-- [2025-03-29 18:07:12.0557762] [Lua] 107		RightHandIndex3		
-- [2025-03-29 18:07:12.0558038] [Lua] 108		RightHandIndex4		
-- [2025-03-29 18:07:12.0558303] [Lua] 109		RightInHandPinky		
-- [2025-03-29 18:07:12.0558733] [Lua] 110		RightHandPinky1		
-- [2025-03-29 18:07:12.0559030] [Lua] 111		RightHandPinky2		
-- [2025-03-29 18:07:12.0559298] [Lua] 112		RightHandPinky3		
-- [2025-03-29 18:07:12.0559578] [Lua] 113		RightHandPinky4		
-- [2025-03-29 18:07:12.0559860] [Lua] 114		RightInHandRing		
-- [2025-03-29 18:07:12.0560129] [Lua] 115		RightHandRing1		
-- [2025-03-29 18:07:12.0560408] [Lua] 116		RightHandRing2		
-- [2025-03-29 18:07:12.0560734] [Lua] 117		RightHandRing3		
-- [2025-03-29 18:07:12.0561136] [Lua] 118		RightHandRing4		
-- [2025-03-29 18:07:12.0561415] [Lua] 119		RightForeArmTwist3		
-- [2025-03-29 18:07:12.0561683] [Lua] 120		RightForeArmTwist2		
-- [2025-03-29 18:07:12.0561961] [Lua] 121		RightForeArmTwist1		
-- [2025-03-29 18:07:12.0562660] [Lua] 122		RightArmTwist2		
-- [2025-03-29 18:07:12.0562938] [Lua] 123		LeftUpLeg		
-- [2025-03-29 18:07:12.0563213] [Lua] 124		LeftLeg		
-- [2025-03-29 18:07:12.0563485] [Lua] 125		LeftLegTwist1		
-- [2025-03-29 18:07:12.0563762] [Lua] 126		LeftFoot		
-- [2025-03-29 18:07:12.0564032] [Lua] 127		LeftToeBase		
-- [2025-03-29 18:07:12.0564296] [Lua] 128		LeftToeBaseEnd		
-- [2025-03-29 18:07:12.0564558] [Lua] 129		LeftUpLegTwist1		
-- [2025-03-29 18:07:12.0564820] [Lua] 130		LeftUpLegTwist2		
-- [2025-03-29 18:07:12.0565122] [Lua] 131		SKT_Hips		
-- [2025-03-29 18:07:12.0565376] [Lua] 132		IK_Hips		
-- [2025-03-29 18:07:12.0565645] [Lua] 133		IK_LeftFoot		
-- [2025-03-29 18:07:12.0565917] [Lua] 134		IK_RightFoot		
-- [2025-03-29 18:07:12.0566384] [Lua] 135		IK_Head		
-- [2025-03-29 18:07:12.0566938] [Lua] 136		SKT_World1		
-- [2025-03-29 18:07:12.0567474] [Lua] 137		SKT_World2		
-- [2025-03-29 18:07:12.0568023] [Lua] 138		SKT_BroomCollision		
-- [2025-03-29 18:07:12.0568539] [Lua] 139		SKT_BeastCollision		
-- [2025-03-29 18:07:12.0569394] [Lua] 140		VB Head_IK_Head		
-- [2025-03-29 18:07:12.0569726] [Lua] 141		VB Spine3_IK_Spine3		
-- [2025-03-29 18:07:12.0570005] [Lua] 142		VB RightHand_IK_RightHand		
-- [2025-03-29 18:07:12.0570274] [Lua] 143		VB LeftHand_IK_LeftHand		
-- [2025-03-29 18:07:12.0570528] [Lua] 144		VB Hips_IK_Hips		
-- [2025-03-29 18:07:12.0570803] [Lua] 145		VB RightFoot_IK_RightFoot		
-- [2025-03-29 18:07:12.0571069] [Lua] 146		VB LeftFoot_IK_LeftFoot		
-- [2025-03-29 18:07:12.0571331] [Lua] 147		None		
