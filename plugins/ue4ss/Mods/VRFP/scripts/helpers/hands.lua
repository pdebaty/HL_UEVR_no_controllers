local uevrUtils = require("libs/uevr_utils")
local controllers = require("libs/controllers")
local animation = require("libs/animation")
local handAnimations = require("helpers/hand_animations")
--[[
	Instructions for getting hand animations
	1) Get a list of all the bones for your skeletal component
		animation.logBoneNames(rightHandComponent)
	2) Create a bonelist by viewing the list from step one. A bonelist is an array of the
		indexes of the knuckle bone of each finger starting from the thumb for each hand
		The list should be length 10, one for each finger
		local handBoneList = {50, 41, 46, 29, 34, 65, 70, 75, 80, 85}
	3) Log the bone rotators for all of the fingers
		animation.logBoneRotators(rightHandComponent, handBoneList)
	4) The printout gives you the default pose angles that can be used in the hand_animations.lua file. These can be
		your resting pose angles if you wish (the "off" values)
	5) Map keypresses to calls to modify bones dynamically as you view them in game. Once you have a hand posed as you like, use the printed values in	
		the hand_animations files(the "on" values)
		example keypress mapping:
			local currentIndex = 1
			local currentFinger = 1
			RegisterKeyBind(Key.NUM_EIGHT, function()
				setFingerAngles(currentFinger, currentIndex, 0, 5)
			end)
			RegisterKeyBind(Key.NUM_TWO, function()
				setFingerAngles(currentFinger, currentIndex, 0, -5)
			end)
			RegisterKeyBind(Key.NUM_SIX, function()
				setFingerAngles(currentFinger, currentIndex, 1, 5)
			end)
			RegisterKeyBind(Key.NUM_FIVE, function() == switch the current finger
				currentFinger = currentFinger + 1
				if currentFinger > 10 then currentFinger = 1 end
				print("Current finger joint", currentFinger, currentIndex)
			end)
			RegisterKeyBind(Key.NUM_FOUR, function()
				setFingerAngles(currentFinger, currentIndex, 1, -5)
			end)
			RegisterKeyBind(Key.NUM_NINE, function()
				setFingerAngles(currentFinger, currentIndex, 2, 5)
			end)
			RegisterKeyBind(Key.NUM_THREE, function()
				setFingerAngles(currentFinger, currentIndex, 2, -5)
			end)
			RegisterKeyBind(Key.NUM_ZERO, function() --switch to the next bone in the current finger
				currentIndex = currentIndex + 1
				if currentIndex > 3 then currentIndex = 1 end
				print("Current finger joint", currentFinger, currentIndex)
			end)

]]--

local M = {}

--for location x is left/right   y is up/down   z is back/forth
local currentRightRotation = {-90, 0, -90}
local currentRightLocation = {-4, 0, -34}
local currentLeftRotation = {90, 0, 90}
local currentLeftLocation = {4, 0, -34}
local currentScale = 1.2

local rightGloveComponent = nil
local leftGloveComponent = nil
local rightHandComponent = nil
local leftHandComponent = nil

local leftJointName = "LeftForeArm"
local rightJointName = "RightForeArm"
local leftShoulderName = "LeftShoulder"
local rightShoulderName = "RightShoulder"
local rootOffset = {X=0, Y=0, Z=0, Pitch=0, Yaw=-90, Roll=0} --if the entire skeletal mesh points a different direction then adjust here first

--some gloves dont have a valid socket reference so handle outliers here
local socketOffsetName = "Reference"
local socketOffsets = {Reference={X=-2.0, Y=0, Z=3.390, Pitch=80, Yaw=0, Roll=0}, Custom={X=-0.84, Y=6.9, Z=4.25, Pitch=0, Yaw=0, Roll=80}}

--used for dev/debugging
local gloveBoneList = {40, 31, 36, 20, 25, 73, 64, 78, 83, 69}
local handBoneList = {50, 41, 46, 29, 34, 65, 70, 75, 80, 85}

function M.print(text)
	uevrUtils.print("[hands] " .. text)
end

function M.reset()
	rightHandComponent = nil
	rightGloveComponent = nil
	leftHandComponent = nil
	leftGloveComponent = nil
end

function M.exists()
	return rightHandComponent ~= nil or rightGloveComponent ~= nil
end

function M.create(pawn)	
	rightHandComponent = M.createComponent(pawn, "Arms", 1)
	rightGloveComponent = M.createComponent(pawn, "Gloves", 1)
	if rightHandComponent ~= nil or rightGloveComponent ~= nil then
		leftHandComponent = M.createComponent(pawn, "Arms", 0)	
		leftGloveComponent = M.createComponent(pawn, "Gloves", 0)
		
		animation.add("right_glove", rightGloveComponent, handAnimations)
		animation.add("right_hand", rightHandComponent, handAnimations)
		animation.add("left_glove", leftGloveComponent, handAnimations)
		animation.add("left_hand", leftHandComponent, handAnimations)
		
		animation.logBoneNames(rightGloveComponent)
		animation.logBoneNames(rightHandComponent)
		-- rotators are not correct when called from here. Get initial rotators from keypresses instead
		-- animation.logBoneRotators(rightGloveComponent, gloveBoneList)
		-- animation.logBoneRotators(rightHandComponent, handBoneList)

		-- delay(500, function()
			-- animation.updateAnimation("right_glove", "right_grip_wand", "on")
			-- animation.updateAnimation("right_hand", "right_grip_wand", "on")
		-- end)
		
	end
end

function M.destroyHands()
	--since we didnt use an existing actor as parent in createComponent(), destroy the owner actor too
	uevrUtils.detachAndDestroyComponent(rightHandComponent, true)	
	uevrUtils.detachAndDestroyComponent(rightGloveComponent, true)	
	uevrUtils.detachAndDestroyComponent(leftHandComponent, true)	
	uevrUtils.detachAndDestroyComponent(leftGloveComponent, true)	
end

--(("head", AddOnMesh'"/Engine/Transient.AddOnMesh_2147452311"'),("Hair", AddOnMesh'"/Engine/Transient.AddOnMesh_2147452297"'),("Arms", AddOnMesh'"/Engine/Transient.AddOnMesh_2147452295"'),("Robe", AddOnMesh'"/Engine/Transient.AddOnMesh_2147452292"'),("Glasses", AddOnMesh'"/Engine/Transient.AddOnMesh_2147452284"'),("Gloves", AddOnMesh'"/Engine/Transient.AddOnMesh_2147452281"'),("Hat", AddOnMesh'"/Engine/Transient.AddOnMesh_2147452278"'),("Scarf", AddOnMesh'"/Engine/Transient.AddOnMesh_2147452276"'),("Upper", AddOnMesh'"/Engine/Transient.AddOnMesh_2147452269"'),("Lower", AddOnMesh'"/Engine/Transient.AddOnMesh_2147452266"'),("Socks", AddOnMesh'"/Engine/Transient.AddOnMesh_2147452258"'),("Shoes", AddOnMesh'"/Engine/Transient.AddOnMesh_2147452255"'))


function M.createComponent(pawn, name, hand)
	local component = nil
	if uevrUtils.validate_object(pawn) ~= nil and uevrUtils.validate_object(pawn.Mesh) ~= nil then
		--not using an existing actor as owner. Mesh affects the hands opacity so its not appropriate
		component = animation.createPoseableComponent(animation.getChildSkeletalMeshComponent(pawn.Mesh, name), nil)
		--component = uevrUtils.createPoseableMeshFromSkeletalMesh(animation.getChildSkeletalMeshComponent(pawn.Mesh, name), nil)
		if component ~= nil then
			--fixes flickering but > 1 causes a perfomance hit with dynamic shadows according to unreal doc
			component.BoundsScale = 8.0
			component.bCastDynamicShadow=false
			
			socketOffsetName = "Reference"
			if not animation.hasBone(component, "SKT_Reference") then
				socketOffsetName = "Custom"
			end
			
			controllers.attachComponentToController(hand, component)
			uevrUtils.set_component_relative_transform(component, rootOffset, rootOffset)	

			local location = hand == 1 and uevrUtils.vector(currentRightLocation[1], currentRightLocation[2], currentRightLocation[3]) or uevrUtils.vector(currentLeftLocation[1], currentLeftLocation[2], currentLeftLocation[3])
			local rotation = hand == 1 and uevrUtils.rotator(currentRightRotation[1], currentRightRotation[2], currentRightRotation[3]) or uevrUtils.rotator(currentLeftRotation[1], currentLeftRotation[2], currentLeftRotation[3])
			animation.initPoseableComponent(component, (hand == 1) and rightJointName or leftJointName, (hand == 1) and rightShoulderName or leftShoulderName, (hand == 1) and leftShoulderName or rightShoulderName, location, rotation, uevrUtils.vector(currentScale, currentScale, currentScale))
		end
	end
	return component
end

function M.getSocketOffset()
	return socketOffsets[socketOffsetName]
end

function M.getHandComponent(hand)
	local component = nil
	if hand == 0 then
		if leftGloveComponent ~= nil then
			component = leftGloveComponent
		else
			component = leftHandComponent
		end
	else
		if rightGloveComponent ~= nil then
			component = rightGloveComponent
		else
			component = rightHandComponent
		end	
	end
	return component
end 

function M.getPosition(hand)
	local component = M.getHandComponent(hand)
	if component ~= nil then
		return component:GetSocketLocation(uevrUtils.fname_from_string("WandSocket")) --component:K2_GetComponentLocation()
	end
end

function M.setFingerAngles(fingerIndex, jointIndex, angleID, angle)
	animation.setFingerAngles(fingerIndex < 6 and leftHandComponent or rightHandComponent, handBoneList, fingerIndex, jointIndex, angleID, angle)
end


function M.handleInput(state, wandVisible)
	local triggerValue = state.Gamepad.bLeftTrigger
	animation.updateAnimation("left_glove", "left_trigger", triggerValue > 100)
	animation.updateAnimation("left_hand", "left_trigger", triggerValue > 100)
	
	animation.updateAnimation("left_glove", "left_grip", uevrUtils.isButtonPressed(state, XINPUT_GAMEPAD_LEFT_SHOULDER))
	animation.updateAnimation("left_hand", "left_grip", uevrUtils.isButtonPressed(state, XINPUT_GAMEPAD_LEFT_SHOULDER))

    local left_controller = uevr.params.vr.get_left_joystick_source()
    local h_left_rest = uevr.params.vr.get_action_handle("/actions/default/in/ThumbrestTouchLeft")    
	animation.updateAnimation("left_glove", "left_thumb", uevr.params.vr.is_action_active(h_left_rest, left_controller))
	animation.updateAnimation("left_hand", "left_thumb", uevr.params.vr.is_action_active(h_left_rest, left_controller))


	local triggerValue = state.Gamepad.bRightTrigger
	animation.updateAnimation("right_glove", wandVisible and "right_trigger_wand" or "right_trigger", triggerValue > 100)
	animation.updateAnimation("right_hand", wandVisible and "right_trigger_wand" or "right_trigger", triggerValue > 100)

	animation.updateAnimation("right_glove", wandVisible and "right_grip_wand" or "right_grip", uevrUtils.isButtonPressed(state, XINPUT_GAMEPAD_RIGHT_SHOULDER))
	animation.updateAnimation("right_hand", wandVisible and "right_grip_wand" or "right_grip", uevrUtils.isButtonPressed(state, XINPUT_GAMEPAD_RIGHT_SHOULDER))

	if not wandVisible then
		local right_controller = uevr.params.vr.get_right_joystick_source()
		local h_right_rest = uevr.params.vr.get_action_handle("/actions/default/in/ThumbrestTouchRight")    
		animation.updateAnimation("right_glove", "right_thumb", uevr.params.vr.is_action_active(h_right_rest, right_controller))
		animation.updateAnimation("right_hand", "right_thumb", uevr.params.vr.is_action_active(h_right_rest, right_controller))
	end

end

function M.adjustRotation(hand, axis, delta)
	local currentLocation = hand == 1 and currentRightLocation or currentLeftLocation
	local currentRotation = hand == 1 and currentRightRotation or currentLeftRotation
	currentRotation[axis] = currentRotation[axis] + delta
	print("Hand: ",hand," Rotation:",currentRotation[1], currentRotation[2], currentRotation[3],"\n")
	local location = uevrUtils.vector(currentLocation[1], currentLocation[2], currentLocation[3])
	local rotation = uevrUtils.rotator(currentRotation[1], currentRotation[2], currentRotation[3])
	animation.initPoseableComponent((hand == 1) and rightGloveComponent or leftGloveComponent, (hand == 1) and rightJointName or leftJointName, (hand == 1) and rightShoulderName or leftShoulderName, (hand == 1) and leftShoulderName or rightShoulderName, location, rotation, uevrUtils.vector(currentScale, currentScale, currentScale))
	animation.initPoseableComponent((hand == 1) and rightHandComponent or leftHandComponent, (hand == 1) and rightJointName or leftJointName, (hand == 1) and rightShoulderName or leftShoulderName, (hand == 1) and leftShoulderName or rightShoulderName, location, rotation, uevrUtils.vector(currentScale, currentScale, currentScale))
end

function M.adjustLocation(hand, axis, delta)
	local currentLocation = hand == 1 and currentRightLocation or currentLeftLocation
	local currentRotation = hand == 1 and currentRightRotation or currentLeftRotation
	currentLocation[axis] = currentLocation[axis] + delta
	print("Hand: ",hand," Location:",currentLocation[1], currentLocation[2], currentLocation[3],"\n")
	local location = uevrUtils.vector(currentLocation[1], currentLocation[2], currentLocation[3])
	local rotation = uevrUtils.rotator(currentRotation[1], currentRotation[2], currentRotation[3])
	animation.initPoseableComponent((hand == 1) and rightGloveComponent or leftGloveComponent, (hand == 1) and rightJointName or leftJointName, (hand == 1) and rightShoulderName or leftShoulderName, (hand == 1) and leftShoulderName or rightShoulderName, location, rotation, uevrUtils.vector(currentScale, currentScale, currentScale))
	animation.initPoseableComponent((hand == 1) and rightHandComponent or leftHandComponent, (hand == 1) and rightJointName or leftJointName, (hand == 1) and rightShoulderName or leftShoulderName, (hand == 1) and leftShoulderName or rightShoulderName, location, rotation, uevrUtils.vector(currentScale, currentScale, currentScale))
end


-- function M.changeGloveMaterials()
	-- local referenceGlove = uevrUtils.getChildComponent(pawn.Mesh, "Gloves")
	-- print("changeGloveMaterials",referenceGlove:get_full_name(),referenceGlove.SkeletalMesh:get_full_name(),"\n")
	-- -- local skeletalMesh = uevrUtils.find_instance_of("Class /Script/Engine.SkeletalMesh", "SkeletalMesh /Game/RiggedObjects/Characters/Human/Clothing/Accessory/Gloves_F/FingerlessGloves/SK_HUM_F_Acc_FingerlessGloves_LongSleeve_Master.SK_HUM_F_Acc_FingerlessGloves_LongSleeve_Master") 
	-- -- if skeletalMesh ~= nil then
		-- -- rightGloveComponent:SetSkeletalMesh(skeletalMesh)
	-- -- else
		-- -- print("Skeletal Mesh not found\n")
	-- -- end

	-- local materials = rightGloveComponent:GetMaterials()
	-- if materials ~= nil then
		-- M.print("Found " .. #materials .. " materials on target component before")
		-- for i, material in ipairs(materials) do				
			-- M.print("Found material " .. material:get_full_name())
		-- end
	-- else
		-- M.print("No materials found")
	-- end

	-- local materials = referenceGlove:GetMaterials()
	-- if materials ~= nil then
		-- M.print("Found " .. #materials .. " materials on reference component")
		-- for i, material in ipairs(materials) do				
			-- rightGloveComponent:SetMaterial(0, material)
			-- M.print("Found material " .. material:get_full_name())
		-- end
	-- else
		-- M.print("No materials found")
	-- end
	
	-- local materials = rightGloveComponent:GetMaterials()
	-- if materials ~= nil then
		-- M.print("Found " .. #materials .. " materials on target component after")
		-- for i, material in ipairs(materials) do				
			-- M.print("Found material " .. material:get_full_name())
		-- end
	-- else
		-- M.print("No materials found")
	-- end
	
	-- -- local materials = referenceGlove.OverrideMaterials
	-- -- if materials ~= nil then
		-- -- M.print("Found " .. #materials .. " override materials on reference component")
		-- -- for i, material in ipairs(materials) do				
			-- -- rightGloveComponent:SetMaterial(i, material)
			-- -- M.print("Found material " .. material:get_full_name())
		-- -- end
	-- -- else
		-- -- M.print("No override materials found")
	-- -- end
	
	-- -- local materials = referenceGlove.SkeletalMesh.Materials
	-- -- if materials ~= nil then
		-- -- uevrUtils.print("Found " .. #materials .. " materials on reference component")
		-- -- for i, material in ipairs(materials) do				
			-- -- rightGloveComponent.SkeletalMesh:SetMaterial(i, material)
		-- -- end
	-- -- else
		-- -- M.print("No materials found")
	-- -- end
-- end

return M

-- [2025-04-15 17:29:54.9339529] [Lua] [animation] 119 bones for PoseableMeshComponent /Game/Levels/Overland/Overland.Overland.PersistentLevel.Actor_2147447039.PoseableMeshComponent_2147447038
-- [2025-04-15 17:29:54.9342273] [Lua] [animation] 1 SKT_FX_Reference2
-- [2025-04-15 17:29:54.9345342] [Lua] [animation] 2 SKT_FX_Reference1
-- [2025-04-15 17:29:54.9347628] [Lua] [animation] 3 IK_Spine3
-- [2025-04-15 17:29:54.9350108] [Lua] [animation] 4 SKT_Reference
-- [2025-04-15 17:29:54.9360224] [Lua] [animation] 5 IK_LeftHand
-- [2025-04-15 17:29:54.9363366] [Lua] [animation] 6 SKT_HeadCamera
-- [2025-04-15 17:29:54.9366196] [Lua] [animation] 7 Hips
-- [2025-04-15 17:29:54.9368640] [Lua] [animation] 8 Spine
-- [2025-04-15 17:29:54.9372325] [Lua] [animation] 9 Spine1
-- [2025-04-15 17:29:54.9374992] [Lua] [animation] 10 Spine2
-- [2025-04-15 17:29:54.9376909] [Lua] [animation] 11 Spine3
-- [2025-04-15 17:29:54.9378526] [Lua] [animation] 12 LeftShoulder
-- [2025-04-15 17:29:54.9380369] [Lua] [animation] 13 LeftArm
-- [2025-04-15 17:29:54.9383183] [Lua] [animation] 14 LeftForeArm
-- [2025-04-15 17:29:54.9385209] [Lua] [animation] 15 LeftForeArmTwist2
-- [2025-04-15 17:29:54.9387009] [Lua] [animation] 16 LeftForeArmTwist3
-- [2025-04-15 17:29:54.9388442] [Lua] [animation] 17 LeftHand
-- [2025-04-15 17:29:54.9389843] [Lua] [animation] 18 SKT_FX_LeftHand
-- [2025-04-15 17:29:54.9391338] [Lua] [animation] 19 LeftInHandRing
-- [2025-04-15 17:29:54.9392773] [Lua] [animation] 20 LeftHandRing1
-- [2025-04-15 17:29:54.9394150] [Lua] [animation] 21 LeftHandRing2
-- [2025-04-15 17:29:54.9396580] [Lua] [animation] 22 LeftHandRing3
-- [2025-04-15 17:29:54.9399806] [Lua] [animation] 23 LeftHandRing4
-- [2025-04-15 17:29:54.9402351] [Lua] [animation] 24 LeftInHandPinky
-- [2025-04-15 17:29:54.9404113] [Lua] [animation] 25 LeftHandPinky1
-- [2025-04-15 17:29:54.9405807] [Lua] [animation] 26 LeftHandPinky2
-- [2025-04-15 17:29:54.9407490] [Lua] [animation] 27 LeftHandPinky3
-- [2025-04-15 17:29:54.9409172] [Lua] [animation] 28 LeftHandPinky4
-- [2025-04-15 17:29:54.9410704] [Lua] [animation] 29 SKT_LeftHand
-- [2025-04-15 17:29:54.9412148] [Lua] [animation] 30 LeftInHandIndex
-- [2025-04-15 17:29:54.9426924] [Lua] [animation] 31 LeftHandIndex1
-- [2025-04-15 17:29:54.9428433] [Lua] [animation] 32 LeftHandIndex2
-- [2025-04-15 17:29:54.9429900] [Lua] [animation] 33 LeftHandIndex3
-- [2025-04-15 17:29:54.9431368] [Lua] [animation] 34 LeftHandIndex4
-- [2025-04-15 17:29:54.9432843] [Lua] [animation] 35 LeftInHandMiddle
-- [2025-04-15 17:29:54.9434347] [Lua] [animation] 36 LeftHandMiddle1
-- [2025-04-15 17:29:54.9435785] [Lua] [animation] 37 LeftHandMiddle2
-- [2025-04-15 17:29:54.9437243] [Lua] [animation] 38 LeftHandMiddle3
-- [2025-04-15 17:29:54.9438756] [Lua] [animation] 39 LeftHandMiddle4
-- [2025-04-15 17:29:54.9440231] [Lua] [animation] 40 LeftHandThumb1
-- [2025-04-15 17:29:54.9441698] [Lua] [animation] 41 LeftHandThumb2
-- [2025-04-15 17:29:54.9443145] [Lua] [animation] 42 LeftHandThumb3
-- [2025-04-15 17:29:54.9444616] [Lua] [animation] 43 LeftHandThumb4
-- [2025-04-15 17:29:54.9446239] [Lua] [animation] 44 LeftForeArmTwist1
-- [2025-04-15 17:29:54.9447708] [Lua] [animation] 45 LeftArmTwist1
-- [2025-04-15 17:29:54.9449163] [Lua] [animation] 46 LeftArmTwist2
-- [2025-04-15 17:29:54.9450594] [Lua] [animation] 47 SKT_Back
-- [2025-04-15 17:29:54.9452059] [Lua] [animation] 48 Neck
-- [2025-04-15 17:29:54.9453495] [Lua] [animation] 49 Neck1
-- [2025-04-15 17:29:54.9454998] [Lua] [animation] 50 head
-- [2025-04-15 17:29:54.9456438] [Lua] [animation] 51 SKT_Head
-- [2025-04-15 17:29:54.9457901] [Lua] [animation] 52 HeadEnd
-- [2025-04-15 17:29:54.9459353] [Lua] [animation] 53 SKT_Chest
-- [2025-04-15 17:29:54.9460805] [Lua] [animation] 54 RightShoulder
-- [2025-04-15 17:29:54.9462264] [Lua] [animation] 55 RightArm
-- [2025-04-15 17:29:54.9463711] [Lua] [animation] 56 RightArmTwist1
-- [2025-04-15 17:29:54.9465161] [Lua] [animation] 57 RightForeArm
-- [2025-04-15 17:29:54.9466599] [Lua] [animation] 58 RightForeArmTwist3
-- [2025-04-15 17:29:54.9468029] [Lua] [animation] 59 RightForeArmTwist2
-- [2025-04-15 17:29:54.9470074] [Lua] [animation] 60 RightForeArmTwist1
-- [2025-04-15 17:29:54.9471525] [Lua] [animation] 61 RightHand
-- [2025-04-15 17:29:54.9473025] [Lua] [animation] 62 SKT_FX_RightHand
-- [2025-04-15 17:29:54.9474493] [Lua] [animation] 63 RightInHandIndex
-- [2025-04-15 17:29:54.9475937] [Lua] [animation] 64 RightHandIndex1
-- [2025-04-15 17:29:54.9477384] [Lua] [animation] 65 RightHandIndex2
-- [2025-04-15 17:29:54.9478831] [Lua] [animation] 66 RightHandIndex3
-- [2025-04-15 17:29:54.9480280] [Lua] [animation] 67 RightHandIndex4
-- [2025-04-15 17:29:54.9481736] [Lua] [animation] 68 RightInHandPinky
-- [2025-04-15 17:29:54.9483200] [Lua] [animation] 69 RightHandPinky1
-- [2025-04-15 17:29:54.9484651] [Lua] [animation] 70 RightHandPinky2
-- [2025-04-15 17:29:54.9486116] [Lua] [animation] 71 RightHandPinky3
-- [2025-04-15 17:29:54.9487578] [Lua] [animation] 72 RightHandPinky4
-- [2025-04-15 17:29:54.9489035] [Lua] [animation] 73 RightHandThumb1
-- [2025-04-15 17:29:54.9490477] [Lua] [animation] 74 RightHandThumb2
-- [2025-04-15 17:29:54.9491926] [Lua] [animation] 75 RightHandThumb3
-- [2025-04-15 17:29:54.9493383] [Lua] [animation] 76 RightHandThumb4
-- [2025-04-15 17:29:54.9494860] [Lua] [animation] 77 RightInHandMiddle
-- [2025-04-15 17:29:54.9496311] [Lua] [animation] 78 RightHandMiddle1
-- [2025-04-15 17:29:54.9498552] [Lua] [animation] 79 RightHandMiddle2
-- [2025-04-15 17:29:54.9500693] [Lua] [animation] 80 RightHandMiddle3
-- [2025-04-15 17:29:54.9502155] [Lua] [animation] 81 RightHandMiddle4
-- [2025-04-15 17:29:54.9503597] [Lua] [animation] 82 RightInHandRing
-- [2025-04-15 17:29:54.9505037] [Lua] [animation] 83 RightHandRing1
-- [2025-04-15 17:29:54.9506496] [Lua] [animation] 84 RightHandRing2
-- [2025-04-15 17:29:54.9507944] [Lua] [animation] 85 RightHandRing3
-- [2025-04-15 17:29:54.9509378] [Lua] [animation] 86 RightHandRing4
-- [2025-04-15 17:29:54.9510804] [Lua] [animation] 87 SKT_RightHand
-- [2025-04-15 17:29:54.9512845] [Lua] [animation] 88 RightArmTwist2
-- [2025-04-15 17:29:54.9514336] [Lua] [animation] 89 RightUpLeg
-- [2025-04-15 17:29:54.9515779] [Lua] [animation] 90 RightUpLegTwist1
-- [2025-04-15 17:29:54.9517304] [Lua] [animation] 91 RightLeg
-- [2025-04-15 17:29:54.9518749] [Lua] [animation] 92 RightLegTwist1
-- [2025-04-15 17:29:54.9520191] [Lua] [animation] 93 RightFoot
-- [2025-04-15 17:29:54.9521631] [Lua] [animation] 94 RightToeBase
-- [2025-04-15 17:29:54.9523081] [Lua] [animation] 95 RightToeBaseEnd
-- [2025-04-15 17:29:54.9524547] [Lua] [animation] 96 RightUpLegTwist2
-- [2025-04-15 17:29:54.9525997] [Lua] [animation] 97 LeftUpLeg
-- [2025-04-15 17:29:54.9527439] [Lua] [animation] 98 LeftUpLegTwist1
-- [2025-04-15 17:29:54.9528899] [Lua] [animation] 99 LeftUpLegTwist2
-- [2025-04-15 17:29:54.9530358] [Lua] [animation] 100 LeftLeg
-- [2025-04-15 17:29:54.9532303] [Lua] [animation] 101 LeftFoot
-- [2025-04-15 17:29:54.9534546] [Lua] [animation] 102 LeftToeBase
-- [2025-04-15 17:29:54.9536759] [Lua] [animation] 103 LeftToeBaseEnd
-- [2025-04-15 17:29:54.9538956] [Lua] [animation] 104 LeftLegTwist1
-- [2025-04-15 17:29:54.9541161] [Lua] [animation] 105 SKT_Hips
-- [2025-04-15 17:29:54.9543365] [Lua] [animation] 106 SKT_FX_Hips
-- [2025-04-15 17:29:54.9544845] [Lua] [animation] 107 IK_RightFoot
-- [2025-04-15 17:29:54.9546351] [Lua] [animation] 108 IK_LeftFoot
-- [2025-04-15 17:29:54.9547797] [Lua] [animation] 109 IK_Hips
-- [2025-04-15 17:29:54.9549237] [Lua] [animation] 110 IK_RightHand
-- [2025-04-15 17:29:54.9550682] [Lua] [animation] 111 IK_Head
-- [2025-04-15 17:29:54.9552900] [Lua] [animation] 112 VB Head_IK_Head
-- [2025-04-15 17:29:54.9554865] [Lua] [animation] 113 VB Spine3_IK_Spine3
-- [2025-04-15 17:29:54.9556724] [Lua] [animation] 114 VB RightHand_IK_RightHand
-- [2025-04-15 17:29:54.9558583] [Lua] [animation] 115 VB LeftHand_IK_LeftHand
-- [2025-04-15 17:29:54.9560507] [Lua] [animation] 116 VB Hips_IK_Hips
-- [2025-04-15 17:29:54.9562335] [Lua] [animation] 117 VB RightFoot_IK_RightFoot
-- [2025-04-15 17:29:54.9564197] [Lua] [animation] 118 VB LeftFoot_IK_LeftFoot
-- [2025-04-15 17:29:54.9566005] [Lua] [animation] 119 None

-- [2025-04-15 17:29:54.9568917] [Lua] [animation] 119 bones for PoseableMeshComponent /Game/Levels/Overland/Overland.Overland.PersistentLevel.Actor_2147447037.PoseableMeshComponent_2147447036
-- [2025-04-15 17:29:54.9571045] [Lua] [animation] 1 SKT_FX_Reference2
-- [2025-04-15 17:29:54.9572864] [Lua] [animation] 2 SKT_FX_Reference1
-- [2025-04-15 17:29:54.9574634] [Lua] [animation] 3 IK_Spine3
-- [2025-04-15 17:29:54.9576406] [Lua] [animation] 4 SKT_Reference
-- [2025-04-15 17:29:54.9578203] [Lua] [animation] 5 IK_LeftHand
-- [2025-04-15 17:29:54.9579984] [Lua] [animation] 6 SKT_HeadCamera
-- [2025-04-15 17:29:54.9581750] [Lua] [animation] 7 IK_RightFoot
-- [2025-04-15 17:29:54.9583573] [Lua] [animation] 8 IK_Hips
-- [2025-04-15 17:29:54.9585334] [Lua] [animation] 9 IK_LeftFoot
-- [2025-04-15 17:29:54.9587160] [Lua] [animation] 10 IK_RightHand
-- [2025-04-15 17:29:54.9588917] [Lua] [animation] 11 IK_Head
-- [2025-04-15 17:29:54.9590523] [Lua] [animation] 12 Hips
-- [2025-04-15 17:29:54.9591954] [Lua] [animation] 13 SKT_Hips
-- [2025-04-15 17:29:54.9593850] [Lua] [animation] 14 SKT_FX_Hips
-- [2025-04-15 17:29:54.9596529] [Lua] [animation] 15 Spine
-- [2025-04-15 17:29:54.9598224] [Lua] [animation] 16 Spine1
-- [2025-04-15 17:29:54.9599688] [Lua] [animation] 17 Spine2
-- [2025-04-15 17:29:54.9601122] [Lua] [animation] 18 Spine3
-- [2025-04-15 17:29:54.9602568] [Lua] [animation] 19 LeftShoulder
-- [2025-04-15 17:29:54.9604023] [Lua] [animation] 20 LeftArm
-- [2025-04-15 17:29:54.9605462] [Lua] [animation] 21 LeftArmTwist1
-- [2025-04-15 17:29:54.9606941] [Lua] [animation] 22 LeftArmTwist2
-- [2025-04-15 17:29:54.9608424] [Lua] [animation] 23 LeftForeArm
-- [2025-04-15 17:29:54.9609874] [Lua] [animation] 24 LeftForeArmTwist1
-- [2025-04-15 17:29:54.9611314] [Lua] [animation] 25 LeftForeArmTwist2
-- [2025-04-15 17:29:54.9612759] [Lua] [animation] 26 LeftForeArmTwist3
-- [2025-04-15 17:29:54.9614181] [Lua] [animation] 27 LeftHand
-- [2025-04-15 17:29:54.9615632] [Lua] [animation] 28 LeftInHandRing
-- [2025-04-15 17:29:54.9617070] [Lua] [animation] 29 LeftHandRing1
-- [2025-04-15 17:29:54.9618518] [Lua] [animation] 30 LeftHandRing2
-- [2025-04-15 17:29:54.9619964] [Lua] [animation] 31 LeftHandRing3
-- [2025-04-15 17:29:54.9621398] [Lua] [animation] 32 LeftHandRing4
-- [2025-04-15 17:29:54.9622844] [Lua] [animation] 33 LeftInHandPinky
-- [2025-04-15 17:29:54.9624688] [Lua] [animation] 34 LeftHandPinky1
-- [2025-04-15 17:29:54.9626203] [Lua] [animation] 35 LeftHandPinky2
-- [2025-04-15 17:29:54.9627652] [Lua] [animation] 36 LeftHandPinky3
-- [2025-04-15 17:29:54.9629098] [Lua] [animation] 37 LeftHandPinky4
-- [2025-04-15 17:29:54.9630527] [Lua] [animation] 38 SKT_FX_LeftHand
-- [2025-04-15 17:29:54.9631970] [Lua] [animation] 39 SKT_LeftHand
-- [2025-04-15 17:29:54.9633430] [Lua] [animation] 40 LeftInHandIndex
-- [2025-04-15 17:29:54.9634865] [Lua] [animation] 41 LeftHandIndex1
-- [2025-04-15 17:29:54.9636319] [Lua] [animation] 42 LeftHandIndex2
-- [2025-04-15 17:29:54.9637749] [Lua] [animation] 43 LeftHandIndex3
-- [2025-04-15 17:29:54.9639220] [Lua] [animation] 44 LeftHandIndex4
-- [2025-04-15 17:29:54.9640657] [Lua] [animation] 45 LeftInHandMiddle
-- [2025-04-15 17:29:54.9642116] [Lua] [animation] 46 LeftHandMiddle1
-- [2025-04-15 17:29:54.9643546] [Lua] [animation] 47 LeftHandMiddle2
-- [2025-04-15 17:29:54.9644992] [Lua] [animation] 48 LeftHandMiddle3
-- [2025-04-15 17:29:54.9646452] [Lua] [animation] 49 LeftHandMiddle4
-- [2025-04-15 17:29:54.9647903] [Lua] [animation] 50 LeftHandThumb1
-- [2025-04-15 17:29:54.9649347] [Lua] [animation] 51 LeftHandThumb2
-- [2025-04-15 17:29:54.9650781] [Lua] [animation] 52 LeftHandThumb3
-- [2025-04-15 17:29:54.9652210] [Lua] [animation] 53 LeftHandThumb4
-- [2025-04-15 17:29:54.9653663] [Lua] [animation] 54 RightShoulder
-- [2025-04-15 17:29:54.9655114] [Lua] [animation] 55 RightArm
-- [2025-04-15 17:29:54.9656580] [Lua] [animation] 56 RightArmTwist1
-- [2025-04-15 17:29:54.9658034] [Lua] [animation] 57 RightArmTwist2
-- [2025-04-15 17:29:54.9659465] [Lua] [animation] 58 RightForeArm
-- [2025-04-15 17:29:54.9660946] [Lua] [animation] 59 RightForeArmTwist1
-- [2025-04-15 17:29:54.9662398] [Lua] [animation] 60 RightForeArmTwist2
-- [2025-04-15 17:29:54.9664411] [Lua] [animation] 61 RightForeArmTwist3
-- [2025-04-15 17:29:54.9672101] [Lua] [animation] 62 RightHand
-- [2025-04-15 17:29:54.9675114] [Lua] [animation] 63 SKT_RightHand
-- [2025-04-15 17:29:54.9679205] [Lua] [animation] 64 SKT_FX_RightHand
-- [2025-04-15 17:29:54.9681482] [Lua] [animation] 65 RightHandThumb1
-- [2025-04-15 17:29:54.9683377] [Lua] [animation] 66 RightHandThumb2
-- [2025-04-15 17:29:54.9685483] [Lua] [animation] 67 RightHandThumb3
-- [2025-04-15 17:29:54.9687285] [Lua] [animation] 68 RightHandThumb4
-- [2025-04-15 17:29:54.9689097] [Lua] [animation] 69 RightInHandIndex
-- [2025-04-15 17:29:54.9690947] [Lua] [animation] 70 RightHandIndex1
-- [2025-04-15 17:29:54.9692571] [Lua] [animation] 71 RightHandIndex2
-- [2025-04-15 17:29:54.9694251] [Lua] [animation] 72 RightHandIndex3
-- [2025-04-15 17:29:54.9695898] [Lua] [animation] 73 RightHandIndex4
-- [2025-04-15 17:29:54.9697527] [Lua] [animation] 74 RightInHandMiddle
-- [2025-04-15 17:29:54.9699576] [Lua] [animation] 75 RightHandMiddle1
-- [2025-04-15 17:29:54.9701340] [Lua] [animation] 76 RightHandMiddle2
-- [2025-04-15 17:29:54.9702974] [Lua] [animation] 77 RightHandMiddle3
-- [2025-04-15 17:29:54.9704975] [Lua] [animation] 78 RightHandMiddle4
-- [2025-04-15 17:29:54.9706621] [Lua] [animation] 79 RightInHandRing
-- [2025-04-15 17:29:54.9708182] [Lua] [animation] 80 RightHandRing1
-- [2025-04-15 17:29:54.9709799] [Lua] [animation] 81 RightHandRing2
-- [2025-04-15 17:29:54.9711494] [Lua] [animation] 82 RightHandRing3
-- [2025-04-15 17:29:54.9712991] [Lua] [animation] 83 RightHandRing4
-- [2025-04-15 17:29:54.9714949] [Lua] [animation] 84 RightInHandPinky
-- [2025-04-15 17:29:54.9716531] [Lua] [animation] 85 RightHandPinky1
-- [2025-04-15 17:29:54.9717967] [Lua] [animation] 86 RightHandPinky2
-- [2025-04-15 17:29:54.9719687] [Lua] [animation] 87 RightHandPinky3
-- [2025-04-15 17:29:54.9721210] [Lua] [animation] 88 RightHandPinky4
-- [2025-04-15 17:29:54.9722634] [Lua] [animation] 89 Neck
-- [2025-04-15 17:29:54.9724138] [Lua] [animation] 90 Neck1
-- [2025-04-15 17:29:54.9725571] [Lua] [animation] 91 head
-- [2025-04-15 17:29:54.9727004] [Lua] [animation] 92 SKT_Head
-- [2025-04-15 17:29:54.9728448] [Lua] [animation] 93 HeadEnd
-- [2025-04-15 17:29:54.9730936] [Lua] [animation] 94 SKT_Chest
-- [2025-04-15 17:29:54.9733279] [Lua] [animation] 95 SKT_Back
-- [2025-04-15 17:29:54.9735617] [Lua] [animation] 96 RightUpLeg
-- [2025-04-15 17:29:54.9738013] [Lua] [animation] 97 RightUpLegTwist1
-- [2025-04-15 17:29:54.9740225] [Lua] [animation] 98 RightUpLegTwist2
-- [2025-04-15 17:29:54.9741711] [Lua] [animation] 99 RightLeg
-- [2025-04-15 17:29:54.9743143] [Lua] [animation] 100 RightLegTwist1
-- [2025-04-15 17:29:54.9744803] [Lua] [animation] 101 RightFoot
-- [2025-04-15 17:29:54.9746338] [Lua] [animation] 102 RightToeBase
-- [2025-04-15 17:29:54.9747780] [Lua] [animation] 103 RightToeBaseEnd
-- [2025-04-15 17:29:54.9749249] [Lua] [animation] 104 LeftUpLeg
-- [2025-04-15 17:29:54.9750675] [Lua] [animation] 105 LeftUpLegTwist1
-- [2025-04-15 17:29:54.9752111] [Lua] [animation] 106 LeftUpLegTwist2
-- [2025-04-15 17:29:54.9753568] [Lua] [animation] 107 LeftLeg
-- [2025-04-15 17:29:54.9755418] [Lua] [animation] 108 LeftLegTwist1
-- [2025-04-15 17:29:54.9756892] [Lua] [animation] 109 LeftFoot
-- [2025-04-15 17:29:54.9758336] [Lua] [animation] 110 LeftToeBase
-- [2025-04-15 17:29:54.9759969] [Lua] [animation] 111 LeftToeBaseEnd
-- [2025-04-15 17:29:54.9761431] [Lua] [animation] 112 VB Head_IK_Head
-- [2025-04-15 17:29:54.9762862] [Lua] [animation] 113 VB Spine3_IK_Spine3
-- [2025-04-15 17:29:54.9764422] [Lua] [animation] 114 VB RightHand_IK_RightHand
-- [2025-04-15 17:29:54.9765874] [Lua] [animation] 115 VB LeftHand_IK_LeftHand
-- [2025-04-15 17:29:54.9767321] [Lua] [animation] 116 VB Hips_IK_Hips
-- [2025-04-15 17:29:54.9768796] [Lua] [animation] 117 VB RightFoot_IK_RightFoot
-- [2025-04-15 17:29:54.9770249] [Lua] [animation] 118 VB LeftFoot_IK_LeftFoot
-- [2025-04-15 17:29:54.9771717] [Lua] [animation] 119 None

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
