local uevrUtils = require("libs/uevr_utils")
local controllers = require("libs/controllers")
local animation = require("libs/animation")

local M = {}

local currentRightRotation = {-90,0,-90}
local currentRightLocation = {-4,0,-38}
local currentLeftRotation = {90,0,90}
local currentLeftLocation = {4,0,-38}
local currentScale = 1.2

local rightGlovesComponent = nil
local leftGlovesComponent = nil
local rightHandsComponent = nil
local leftHandsComponent = nil

local leftJointName = "LeftForeArm"
local rightJointName = "RightForeArm"
local leftShoulderName = "LeftShoulder"
local rightShoulderName = "RightShoulder"

function M.create(pawn)
	rightGlovesComponent = M.createComponent(pawn, "Gloves", 1)
	rightHandsComponent = M.createComponent(pawn, "Arms", 1)
	leftGlovesComponent = M.createComponent(pawn, "Gloves", 0)
	leftHandsComponent = M.createComponent(pawn, "Arms", 0)	
end

--x is left/right   y is up/down   z is back/forth
function M.createComponent(pawn, name, hand)
	local component = animation.createPoseableComponent(animation.getChildSkeletalMeshComponent(pawn.Mesh, name, hand))
	if component ~= nil then
		controllers.attachComponentToController(hand, component)
		uevrUtils.set_component_relative_transform(component, {X=0, Y=0, Z=0}, {Pitch=0, Yaw=-90, Roll=0})	
		local location = hand == 1 and uevrUtils.vector(currentRightLocation[1], currentRightLocation[2], currentRightLocation[3]) or uevrUtils.vector(currentLeftLocation[1], currentLeftLocation[2], currentLeftLocation[3])
		local rotation = hand == 1 and uevrUtils.rotator(currentRightRotation[1], currentRightRotation[2], currentRightRotation[3]) or uevrUtils.rotator(currentLeftRotation[1], currentLeftRotation[2], currentLeftRotation[3])
		animation.initPoseableComponent(component, (hand == 1) and rightJointName or leftJointName, (hand == 1) and leftShoulderName or rightShoulderName, location, rotation, uevrUtils.vector(currentScale, currentScale, currentScale))
	end
	return component
end

function M.adjustRotation(hand, axis, delta)
	local currentLocation = hand == 1 and currentRightLocation or currentLeftLocation
	local currentRotation = hand == 1 and currentRightRotation or currentLeftRotation
	currentRotation[axis] = currentRotation[axis] + delta
	print("Hand: ",hand," Rotation:",currentRotation[1], currentRotation[2], currentRotation[3],"\n")
	local location = uevrUtils.vector(currentLocation[1], currentLocation[2], currentLocation[3])
	local rotation = uevrUtils.rotator(currentRotation[1], currentRotation[2], currentRotation[3])
	animation.initPoseableComponent((hand == 1) and rightGlovesComponent or leftGlovesComponent, (hand == 1) and rightJointName or leftJointName, (hand == 1) and leftShoulderName or rightShoulderName, location, rotation, uevrUtils.vector(currentScale, currentScale, currentScale))
	animation.initPoseableComponent((hand == 1) and rightHandsComponent or leftHandsComponent, (hand == 1) and rightJointName or leftJointName, (hand == 1) and leftShoulderName or rightShoulderName, location, rotation, uevrUtils.vector(currentScale, currentScale, currentScale))
end

function M.adjustLocation(hand, axis, delta)
	local currentLocation = hand == 1 and currentRightLocation or currentLeftLocation
	local currentRotation = hand == 1 and currentRightRotation or currentLeftRotation
	currentLocation[axis] = currentLocation[axis] + delta
	print("Hand: ",hand," Location:",currentLocation[1], currentLocation[2], currentLocation[3],"\n")
	local location = uevrUtils.vector(currentLocation[1], currentLocation[2], currentLocation[3])
	local rotation = uevrUtils.rotator(currentRotation[1], currentRotation[2], currentRotation[3])
	animation.initPoseableComponent((hand == 1) and rightGlovesComponent or leftGlovesComponent, (hand == 1) and rightJointName or leftJointName, (hand == 1) and leftShoulderName or rightShoulderName, location, rotation, uevrUtils.vector(currentScale, currentScale, currentScale))
	animation.initPoseableComponent((hand == 1) and rightHandsComponent or leftHandsComponent, (hand == 1) and rightJointName or leftJointName, (hand == 1) and leftShoulderName or rightShoulderName, location, rotation, uevrUtils.vector(currentScale, currentScale, currentScale))
end

return M