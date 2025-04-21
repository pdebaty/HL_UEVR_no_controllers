local UEHelpers = require("UEHelpers")
local Json = require("jsonStorage")
require("config")
local uevrUtils = require("libs/uevr_utils")
local debugModule = require("libs/uevr_debug")
local controllers = require("libs/controllers")
local hands = require("helpers/hands")
local flickerFixer = require("libs/flicker_fixer")
local wand = require("helpers/wand")
local mounts = require("helpers/mounts")
local decoupledYaw = require("helpers/decoupledyaw")
local input = require("helpers/input")
local gesturesModule = require("gestures/gestures")
local animation = require("libs/animation")

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

function assetLoadedCallback(object)
	print("here")
end

function doLoadAsset()

--ObjectProperty NavCollision=(NavCollision /Engine/BasicShapes/Cube.Cube.NavCollision_1)


	--local fSoftObjectPath = kismet_system_library:MakeSoftObjectPath(path)
	-- LoadAsset("StaticMesh /Game/Environment/Hogwarts/Meshes/Statues/SM_HW_Armor_Sword.SM_HW_Armor_Sword")
	-- LoadAsset("/Game/Environment/Hogwarts/Meshes/Statues/SM_HW_Armor_Sword.SM_HW_Armor_Sword")
	-- LoadAsset("/Game/Environment/Hogwarts/Meshes/Statues/SM_HW_Armor_Sword")
	--local latentInfo = uevrUtils.get_struct_object("ScriptStruct /Script/Engine.LatentActionInfo") 
	-- latentInfo.CallbackTarget = *myObjectWithDerivesFromUObject
	-- latentInfo.ExecutionFunction = "myFunctionToCall"
	-- latentInfo.UUID = 1
	-- latentInfo.Linkage = 0
	
	--kismet_system_library:OnAssetLoaded__DelegateSignature(class UObject* Loaded)
	--kismet_system_library:LoadAsset(uevrUtils.get_world(), fSoftObjectPath, assetLoadedCallback, latentInfo)
	-- path = "/Game/Environment/Hogwarts/Meshes/Statues/SM_HW_Armor_Sword"
	-- kismet_system_library:LoadAsset(uevrUtils.get_world(), kismet_system_library:MakeSoftObjectPath(path), assetLoadedCallback, latentInfo)
	-- path = "StaticMesh /Game/Environment/Hogwarts/Meshes/Statues/SM_HW_Armor_Sword.SM_HW_Armor_Sword"
	-- kismet_system_library:LoadAsset(uevrUtils.get_world(), kismet_system_library:MakeSoftObjectPath(path), assetLoadedCallback, latentInfo)
	-- print("Before")
	
	-- -- FSoftObjectPath MakeSoftObjectPath(FString PathString)
	-- -- TSoftObjectPtr<UObject> Conv_SoftObjPathToSoftObjRef(const FSoftObjectPath& SoftObjectPath)
	-- -- class UObject* LoadAsset_Blocking(TSoftObjectPtr<UObject> Asset)
	-- local pathStr = "/Game/Environment/Hogwarts/Meshes/Statues/SM_HW_Armor_Sword.SM_HW_Armor_Sword"
	-- local path = kismet_system_library:MakeSoftObjectPath(pathStr)
	-- local ptr = kismet_system_library:Conv_SoftObjPathToSoftObjRef(path)
	-- local object = kismet_system_library:LoadAsset_Blocking(ptr)
	-- print(pathStr,path.AssetPathName,path.SubPathString,ptr,object,"\n")
	
	-- pathStr = "/Engine/BasicShapes/Cube"
	-- path = kismet_system_library:MakeSoftObjectPath(pathStr)
	-- path.SubPathString = "Cube"
	-- debugModule.dump(path)
	-- ptr = kismet_system_library:Conv_SoftObjPathToSoftObjRef(path)
	-- object = kismet_system_library:LoadAsset_Blocking(ptr)
	-- --This is insane, setting SubPathString here fails and is nil in the following debug statements
	-- path.SubPathString = "Cube"
	-- debugModule.dump(path)
	-- print("The path is ",path.SubPathString,"\n")
	-- print(pathStr,path,path.AssetPathName,path.SubPathString,ptr,object,"\n")
	
	-- pathStr = "/Game/Environment/Hogwarts/Meshes/Statues/SM_HW_Armor_Sword"
	-- path = kismet_system_library:MakeSoftObjectPath(pathStr)
	-- ptr = kismet_system_library:Conv_SoftObjPathToSoftObjRef(path)
	-- object = kismet_system_library:LoadAsset_Blocking(ptr)
	-- print(pathStr,path,ptr,object,"\n")
	
	-- pathStr = "SM_HW_Armor_Sword.SM_HW_Armor_Sword"
	-- path = kismet_system_library:MakeSoftObjectPath(pathStr)
	-- ptr = kismet_system_library:Conv_SoftObjPathToSoftObjRef(path)
	-- object = kismet_system_library:LoadAsset_Blocking(ptr)
	-- print(pathStr,path,ptr,object,"\n")
	
	-- pathStr = "SM_HW_Armor_Sword"
	-- path = kismet_system_library:MakeSoftObjectPath(pathStr)
	-- ptr = kismet_system_library:Conv_SoftObjPathToSoftObjRef(path)
	-- object = kismet_system_library:LoadAsset_Blocking(ptr)
	-- print(pathStr,path,ptr,object,"\n")
	
	-- pathStr = "StaticMesh /Game/Environment/Hogwarts/Meshes/Statues/SM_HW_Armor_Sword.SM_HW_Armor_Sword"
	-- path = kismet_system_library:MakeSoftObjectPath(pathStr)
	-- ptr = kismet_system_library:Conv_SoftObjPathToSoftObjRef(path)
	-- object = kismet_system_library:LoadAsset_Blocking(ptr)
	-- print(pathStr,path,ptr,object,"\n")
	
print("1\n")
	local assetRegistryHelper = uevrUtils.find_first_of("Class /Script/AssetRegistry.AssetRegistryHelpers",  true)
print("2\n")
	debugModule.dump(assetRegistryHelper)
print("3\n")
	local assetRegistry = assetRegistryHelper:GetAssetRegistry()
print("4\n")
	debugModule.dump(assetRegistry)
print("5\n")

	local leftComponent = uevrUtils.createStaticMeshComponent("StaticMesh /Engine/BasicShapes/Cube.Cube")
	local fAssetData = assetRegistryHelper:CreateAssetData(leftComponent.StaticMesh, true)
	debugModule.dump(fAssetData)
	fAssetData.ObjectPath = uevrUtils.fname_from_string("/Game/Environment/Hogwarts/Meshes/Statues/SM_HW_Armor_Sword.SM_HW_Armor_Sword")
	fAssetData.PackageName = uevrUtils.fname_from_string("/Game/Environment/Hogwarts/Meshes/Statues/SM_HW_Armor_Sword")
	fAssetData.PackagePath = uevrUtils.fname_from_string("/Game/Environment/Hogwarts/Meshes/Statues")
	fAssetData.AssetName = uevrUtils.fname_from_string("SM_HW_Armor_Sword")
	fAssetData.AssetClass = uevrUtils.fname_from_string("StaticMesh")
	debugModule.dump(fAssetData)
	print("\nGetting Info\n")
	print(assetRegistryHelper:IsValid(fAssetData),"\n")
	print(assetRegistryHelper:IsUAsset(fAssetData),"\n")
	print(assetRegistryHelper:IsRedirector(fAssetData),"\n")
	print(assetRegistryHelper:IsAssetLoaded(fAssetData),"\n")
	-- bool IsValid(const FAssetData& InAssetData);
    -- bool IsUAsset(const FAssetData& InAssetData);
    -- bool IsRedirector(const FAssetData& InAssetData);
    -- bool IsAssetLoaded(const FAssetData& InAssetData);

    local fSoftObjectPath = assetRegistryHelper:ToSoftObjectPath(fAssetData);
	print("Soft Object Path",fSoftObjectPath,"\n")
	debugModule.dump(fSoftObjectPath)
	local asset1 = kismet_system_library:LoadAsset_Blocking(fSoftObjectPath)
	print(asset1, "\n")
	--local asset2 = kismet_system_library:LoadAsset_Blocking(kismet_system_library:Conv_SoftObjPathToSoftObjRef(fSoftObjectPath))
	--print(asset2, "\n")

	print("Getting asset\n")
	local object = assetRegistryHelper:GetAsset(fAssetData) --crashes when assetRegistryHelper:IsAssetLoaded(fAssetData) is false
	print("Got asset\n")
	print(object,"\n")
	print("Debug print\n")
	debugModule.dump(object)
	print("Done printing\n")
	-- local leftComponent = uevrUtils.createStaticMeshComponent("StaticMesh /Game/Environment/Hogwarts/Meshes/Statues/SM_HW_Armor_Sword.SM_HW_Armor_Sword")
	-- local fAssetData = assetRegistryHelper:CreateAssetData(leftComponent.StaticMesh, true)
	-- debugModule.dump(fAssetData)

	local component = uevrUtils.create_component_of_class("Class /Script/Engine.StaticMeshComponent")
	if component ~= nil then
		local staticMesh = object
		if staticMesh ~= nil then
			component:SetStaticMesh(staticMesh)				
		else
			print("Static Mesh not found\n")
		end
		local leftConnected = controllers.attachComponentToController(0, component)
	else
		print("StaticMeshComponent not created\n")
	end
	

-- struct FAssetData
-- {
    -- FName ObjectPath;                                                                 // 0x0000 (size: 0x8)
    -- FName PackageName;                                                                // 0x0008 (size: 0x8)
    -- FName PackagePath;                                                                // 0x0010 (size: 0x8)
    -- FName AssetName;                                                                  // 0x0018 (size: 0x8)
    -- FName AssetClass;                                                                 // 0x0020 (size: 0x8)

-- }; // Size: 0x60

	-- NameProperty ObjectPath=/Game/Environment/Hogwarts/Meshes/Statues/SM_HW_Armor_Sword.SM_HW_Armor_Sword
	-- NameProperty PackageName=/Game/Environment/Hogwarts/Meshes/Statues/SM_HW_Armor_Sword
	-- NameProperty PackagePath=/Game/Environment/Hogwarts/Meshes/Statues
	-- NameProperty AssetName=SM_HW_Armor_Sword
	-- NameProperty AssetClass=StaticMesh
	
	-- NameProperty ObjectPath=/Engine/BasicShapes/Cube.Cube
	-- NameProperty PackageName=/Engine/BasicShapes/Cube
	-- NameProperty PackagePath=/Engine/BasicShapes
	-- NameProperty AssetName=Cube
	-- NameProperty AssetClass=StaticMesh
	--const UClass* Class = UStaticMesh::StaticClass();
	-- local smClass = uevrUtils.get_class("Class /Script/Engine.StaticMesh")
	-- local assetData = {}
	-- print("before\n")
	-- assetRegistry:GetAssetsByClass(uevrUtils.fname_from_string("Class /Script/Engine.StaticMesh"), assetData, true)
	-- print("after\n")
	-- print(#assetData,"\n")
	-- local assetRegistry = uevrUtils.find_first_of("Class /Script/AssetRegistry.AssetRegistry",  true)
	-- print(assetRegistry,"\n")
	-- local array = {}
	-- local assetData = assetRegistry:GetAssetByObjectPath(uevrUtils.fname_from_string("/Game/Environment/Hogwarts/Meshes/Statues/SM_HW_Armor_Sword.SM_HW_Armor_Sword"), false)
	-- print("Here",assetData,"\n")
	-- assetRegistry:GetAllAssets(array, false)
	-- print(array, #array,"\n")
	
	--"Class /Script/AssetRegistry.AssetRegistry"
	-- local object = kismet_system_library:LoadAsset_Blocking(kismet_system_library:MakeSoftObjectPath("/Game/Environment/Hogwarts/Meshes/Statues/SM_HW_Armor_Sword.SM_HW_Armor_Sword"))
	-- print(object)
	-- object = kismet_system_library:LoadAsset_Blocking(kismet_system_library:MakeSoftObjectPath("/Game/Environment/Hogwarts/Meshes/Statues/SM_HW_Armor_Sword"))
	-- print(object)
	-- object = kismet_system_library:LoadAsset_Blocking(kismet_system_library:MakeSoftObjectPath("StaticMesh /Game/Environment/Hogwarts/Meshes/Statues/SM_HW_Armor_Sword.SM_HW_Armor_Sword"))
	-- print(object)
end



function connectCube(hand)
	--doLoadAsset()
	local staticMesh = uevrUtils.getLoadedAsset("StaticMesh /Game/Environment/Hogwarts/Meshes/Statues/SM_HW_Armor_Sword.SM_HW_Armor_Sword")
	--local staticMesh = uevrUtils.getLoadedAsset("StaticMesh /Engine/BasicShapes/Cube.Cube")
	
--debugModule.dump(staticMesh)	

	local leftComponent = uevrUtils.createStaticMeshComponent("StaticMesh /Game/Environment/Hogwarts/Meshes/Statues/SM_HW_Armor_Sword.SM_HW_Armor_Sword")--"StaticMesh /Engine/BasicShapes/Cube.Cube")
	local leftConnected = controllers.attachComponentToController(0, leftComponent)
	
	-- --LoadAsset("/Game/Environment/Hogwarts/Meshes/Statues/SM_HW_Armor_Sword.SM_HW_Armor_Sword")
	-- --delay(3000, function()
	-- local leftComponent = uevrUtils.createStaticMeshComponent("StaticMesh /Game/Environment/Hogwarts/Meshes/Statues/SM_HW_Armor_Sword.SM_HW_Armor_Sword")--"StaticMesh /Engine/BasicShapes/Cube.Cube")
	-- local leftConnected = controllers.attachComponentToController(hand, leftComponent)
	-- --uevrUtils.set_component_relative_transform(leftComponent, nil, nil, {X=0.03, Y=0.03, Z=0.03})
	-- uevrUtils.set_component_relative_transform(leftComponent, nil, {Pitch=90, Yaw=0, Roll=0}, {X=0.8, Y=0.8, Z=0.8})
	-- leftComponent:SetCollisionEnabled(3, true)
	-- --end)
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
	hands.reset()
	--connectCube(0)
	
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
	connectWand()
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

function connectWand()
	if showHands and hands.exists() then
		wand.connectToSocket(mounts.getMountPawn(pawn), hands.getHandComponent(isLeftHanded and 0 or 1), "WandSocket", hands.getSocketOffset())		
	else
		wand.connectToController(mounts.getMountPawn(pawn), isLeftHanded and 0 or 1)
	end
end

local g_shoulderGripOn = false
function handleBrokenControllers(pawn, state, isLeftHanded)
	local gripButton = XINPUT_GAMEPAD_RIGHT_SHOULDER
	if isLeftHanded then
		gripButton = XINPUT_GAMEPAD_LEFT_SHOULDER
	end
	if not g_shoulderGripOn and uevrUtils.isButtonPressed(state, gripButton)  then
		g_shoulderGripOn = true
		local headLocation = controllers.getControllerLocation(2)
		local handLocation = controllers.getControllerLocation(isLeftHanded and 0 or 1)
		if headLocation ~= nil and handLocation ~= nil then
			local distance = kismet_math_library:Vector_Distance(headLocation, handLocation)
			--print(distance,"\n")
			if distance < 30 then	
				wand.connectAltWand(pawn, isLeftHanded and 0 or 1)
				if showHands then
					wand.disconnect()
					wand.reset()
					hands.destroyHands()
					hands.reset()
				end
			end
		end
	elseif g_shoulderGripOn and uevrUtils.isButtonNotPressed(state, gripButton) then
		delay(1000, function()
			g_shoulderGripOn = false
		end)
	end

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
	
	if showHands and not hands.exists() then
		hands.create(pawn)
	end

	if not wand.isConnected() then
		connectWand()
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
	
	-- local wandPosition = wand.getPosition()
	-- local handPosition = hands.getPosition(1)
	-- if wandPosition ~= nil and handPosition ~= nil then
		-- distance = kismet_math_library:Vector_Distance(wandPosition, handPosition)
		-- print("Distance is",distance,"\n")
		-- wand.updateOffsetPosition(handPosition)
	-- end

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
		
		if showHands then
			hands.handleInput(state, wand.isVisible())	
		end
		
		handleBrokenControllers(mounts.getMountPawn(pawn), state, g_isLeftHanded)	
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
	--always updating hands here until we can find a specific call for glove changes
	if showHands then
		wand.disconnect()
		wand.reset()
		hands.destroyHands()
		hands.reset()
	end
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


-- function overrideCharacterOpacity()
	-- if uevrUtils.validate_object(pawn) and uevrUtils.validate_object(pawn.Mesh) then
		-- local propertyName = "FINALOPACITY"
		-- local propertyFName = uevrUtils.fname_from_string(propertyName)	
		-- local value = 1.0
		-- local materials = pawn.Mesh.OverrideMaterials
		-- for i, material in ipairs(materials) do
			-- --local oldValue = material:K2_GetScalarParameterValue(propertyFName)
			-- material:SetScalarParameterValue(propertyFName, value)
-- --			material.Parent:SetScalarParameterValue(propertyFName, value)
			-- --local newValue = material:K2_GetScalarParameterValue(propertyFName)
			-- --print("Child Material:",i, material:get_full_name(), oldValue, newValue,"\n")
		-- end
		
			-- -- children = pawn.Mesh.AttachChildren
			-- -- if children ~= nil then
				-- -- for i, child in ipairs(children) do
					-- -- --if child:is_a(static_mesh_component_c) then
						-- -- local materials = child.OverrideMaterials
						-- -- for i, material in ipairs(materials) do
							-- -- --local oldValue = material:K2_GetScalarParameterValue(propertyFName)
							-- -- material:SetScalarParameterValue(propertyFName, value)
							-- -- --local newValue = material:K2_GetScalarParameterValue(propertyFName)
							-- -- --print("Child Material:",i, material:get_full_name(), oldValue, newValue,"\n")
						-- -- end
					-- -- --end
					
				-- -- end
			-- -- end

	-- end
-- end



RegisterKeyBind(Key.F1, function()
    print("F1 pressed. First Person mode = ",not isFP,"\n")
	
    isFP = not isFP
	updatePlayer()
	if isFP then
		connectWand()
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
		--connectCube(0)
		uevrUtils.print(animation.getRootBoneOfBone(hands.getHandComponent(1), "RightForeArm"):to_string())
		animation.getHierarchyForBone(hands.getHandComponent(1), "RightForeArm")
	end)

	-- ExecuteInGameThread( function()
		-- hands.changeGloveMaterials()
	-- end)
	-- ExecuteInGameThread( function()
		-- --vrBody = uevrUtils.createStaticMeshComponent("StaticMesh /Engine/EngineMeshes/Sphere.Sphere")
		-- rightGlovesComponent = animation.createPoseableComponent(animation.getChildSkeletalMeshComponent(pawn.Mesh, "Gloves"))
		-- controllers.attachComponentToController(1, rightGlovesComponent)
		-- uevrUtils.set_component_relative_transform(rightGlovesComponent, {X=0, Y=0, Z=0}, {Pitch=0, Yaw=-90, Roll=0})		

		-- armsComponent = createPoseableComponent(getChildSkeletalMeshComponent(pawn.Mesh, "Arms"))
		-- animation.createSkeletalVisualization(glovesComponent)
	-- end)
	
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


local currentHand = 1
local currentIndex = 1
local currentFinger = 1
RegisterKeyBind(Key.NUM_EIGHT, function()
    print("NUM8 pressed\n")
	hands.adjustRotation(currentHand, 3, 90)
	--hands.adjustLocation(currentHand, 3, 2)
	--ExecuteInGameThread( function() hands.setFingerAngles(currentFinger, currentIndex, 0, 5) end)
end)

RegisterKeyBind(Key.NUM_TWO, function()
    print("NUM2 pressed\n")
	hands.adjustRotation(currentHand, 3, -90)
	--hands.adjustLocation(currentHand, 3, -2)
	--ExecuteInGameThread( function() hands.setFingerAngles(currentFinger, currentIndex, 0, -5) end)
	-- setVisualSkeletonBoneScale(glovesComponent, boneIndex, 0.003)
	-- boneIndex = boneIndex - 1
	-- if boneIndex < 1 then boneIndex = 1 end
	-- setVisualSkeletonBoneScale(glovesComponent, boneIndex, 0.006)
end)

RegisterKeyBind(Key.NUM_SIX, function()
    print("NUM6 pressed\n")
	hands.adjustRotation(currentHand, 1, 90)
	--hands.adjustLocation(currentHand, 1, 2)
	--ExecuteInGameThread( function() hands.setFingerAngles(currentFinger, currentIndex, 1, 5) end)
end)
RegisterKeyBind(Key.NUM_FIVE, function()
    print("NUM6 pressed\n")
	currentHand = (currentHand + 1) % 2
	-- currentFinger = currentFinger + 1
	-- if currentFinger > 10 then currentFinger = 1 end
	-- print("Current finger joint", currentFinger, currentIndex)
end)
RegisterKeyBind(Key.NUM_FOUR, function()
    print("NUM6 pressed\n")
	hands.adjustRotation(currentHand, 1, -90)
	--hands.adjustLocation(currentHand, 1, -2)
	--ExecuteInGameThread( function() hands.setFingerAngles(currentFinger, currentIndex, 1, -5) end)
end)
RegisterKeyBind(Key.NUM_NINE, function()
    print("NUM6 pressed\n")
	hands.adjustRotation(currentHand, 2, 90)
	--hands.adjustLocation(currentHand, 2, 2)
	--ExecuteInGameThread( function() hands.setFingerAngles(currentFinger, currentIndex, 2, 5) end)
end)
RegisterKeyBind(Key.NUM_THREE, function()
    print("NUM6 pressed\n")
	hands.adjustRotation(currentHand, 2, -90)
	--hands.adjustLocation(currentHand, 2, -2)
	--ExecuteInGameThread( function() hands.setFingerAngles(currentFinger, currentIndex, 2, -5) end)
end)
RegisterKeyBind(Key.NUM_ONE, function()
    print("NUM0 pressed\n")
	currentIndex = currentIndex + 1
	if currentIndex > 3 then currentIndex = 1 end
	print("Current finger joint", currentFinger, currentIndex)
end)


-- *** Property dump for object 'StaticMesh /Engine/BasicShapes/Cube.Cube ***

-- (Class /Script/Engine.StaticMesh)
-- StructProperty MinLOD=
	-- IntProperty Default=0
-- IntProperty ShadowMinLOD=-1
-- BoolProperty bCastShadowAsBackfacedMinLOD=false
-- FloatProperty LpvBiasMultiplier=1.0
-- ArrayProperty StaticMaterials=nil
-- FloatProperty LightmapUVDensity=356.39279174805
-- IntProperty LightMapResolution=64
-- IntProperty LightMapCoordinateIndex=1
-- FloatProperty DistanceFieldSelfShadowBias=0.0
-- ObjectProperty BodySetup=(BodySetup /Engine/BasicShapes/Cube.Cube.BodySetup_1)
-- IntProperty LODForCollision=0
-- BoolProperty bGenerateMeshDistanceField=false
-- BoolProperty bStripComplexCollisionForConsole=false
-- BoolProperty bHasNavigationData=true
-- BoolProperty bSupportUniformlyDistributedSampling=false
-- BoolProperty bSupportPhysicalMaterialMasks=false
-- BoolProperty bSupportRayTracing=true
-- BoolProperty bIsBuiltAtRuntime=false
-- BoolProperty bAllowCPUAccess=false
-- BoolProperty bSupportGpuUniformlyDistributedSampling=false
-- ArrayProperty Sockets=nil
-- StructProperty PositiveBoundsExtension=<0.0, 0.0, 0.0>
-- StructProperty NegativeBoundsExtension=<0.0, 0.0, 0.0>
-- StructProperty ExtendedBounds=
	-- StructProperty Origin=<0.0, 0.0, 0.0>
	-- StructProperty BoxExtent=<50.0, 50.0, 50.0>
	-- FloatProperty SphereRadius=86.6025390625
-- IntProperty ElementToIgnoreForTexFactor=-1
-- ArrayProperty AssetUserData=nil
-- ObjectProperty EditableMesh=nil
-- ObjectProperty NavCollision=(NavCollision /Engine/BasicShapes/Cube.Cube.NavCollision_1)

-- (Class /Script/Engine.StreamableRenderAsset)
-- DoubleProperty ForceMipLevelsToBeResidentTimestamp=UNHANDLED_VALUE
-- IntProperty NumCinematicMipLevels=0
-- IntProperty StreamingIndex=-1
-- IntProperty CachedCombinedLODBias=0
-- BoolProperty NeverStream=false
-- BoolProperty bGlobalForceMipLevelsToBeResident=false
-- BoolProperty bHasStreamingUpdatePending=false
-- BoolProperty bForceMiplevelsToBeResident=false
-- BoolProperty bIgnoreStreamingMipBias=false
-- BoolProperty bUseCinematicMipLevels=false

-- (Class /Script/CoreUObject.Object)
