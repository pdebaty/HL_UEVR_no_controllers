local uevrUtils = require("libs/uevr_utils")
local controllers = require("libs/controllers")

local M = {}

local wandMeshParent = nil
local wandMeshAttachSocketName = nil
local meshComponent = nil
local wandTipOffset = 30.0
local isWandHolstered = false
local maxRetries = 10
local bIsVisible = false
local previousIsVisible = nil

local isDebug = false
local funcCallbacks = {}

local controllerWandPositionOffset = {X=0, Y=0, Z=0}
local controllerWandRotationOffset = {Pitch=-80, Yaw=0, Roll=0}
local socketWandPositionOffset = {X=-2.0, Y=0, Z=3.390}
local socketWandRotationOffset = {Pitch=80, Yaw=0, Roll=0}

local currentLogLevel = LogLevel.Error
function M.setLogLevel(val)
	currentLogLevel = val
end
function M.print(text, logLevel)
	if logLevel == nil then logLevel = LogLevel.Debug end
	if logLevel <= currentLogLevel then
		uevrUtils.print("[wand] " .. text, logLevel)
	end
end

function M.isVisible()
	return bIsVisible
end

function M.isConnected()
	return meshComponent ~= nil
end
function M.reset()
	meshComponent = nil
	bIsVisible = false
	previousIsVisible = nil
end

function detachFromThirdPerson()
	M.print("Detaching wand from player")
	meshComponent = nil
	if uevrUtils.validate_object(pawn) ~= nil and pawn.GetWand ~= nil then
		M.print("Trying to connect wand for pawn " .. pawn:get_full_name())
		local wand = pawn:GetWand()
		if wand ~= nil then
			meshComponent = wand.Mesh -- wand:GetWandMesh()
			if uevrUtils.validate_object(meshComponent) ~= nil then
				wandMeshParent = meshComponent.AttachParent
				wandMeshAttachSocketName = meshComponent.AttachSocketName
				meshComponent:DetachFromParent(false, false)
				meshComponent:SetVisibility(true, true)
				meshComponent:SetHiddenInGame(false, true)
			else
				M.print("Mesh is not valid in wand connect")
				meshComponent = nil
			end
		else
			M.print("Wand is not valid in wand connect")
		end
	else
		M.print("Pawn is not valid in wand connect")
	end
	
	if meshComponent ~= nil then
		M.print("Wand connected")
		return true
	end
	M.print("Wand connect failed")
	return false
end

function M.connectToController(pawn, hand)
	if detachFromThirdPerson() and uevrUtils.validate_object(meshComponent) ~= nil then
		controllers.attachComponentToController(hand, meshComponent)
		uevrUtils.set_component_relative_transform(meshComponent, controllerWandPositionOffset, controllerWandRotationOffset)
		return true
	end
	return false
end

function M.connectToSocket(pawn, handComponent, socketName, offset)
	if detachFromThirdPerson() and uevrUtils.validate_object(meshComponent) ~= nil then
		meshComponent:K2_AttachTo(handComponent, uevrUtils.fname_from_string(socketName), 0, false)
		uevrUtils.set_component_relative_transform(meshComponent, offset ~= nil and offset or socketWandPositionOffset, offset ~= nil and offset or socketWandRotationOffset)		
		return true
	end
	return false
end

function M.connectAltWand(pawn, hand)
	M.print("connectAltWand called")
	if uevrUtils.validate_object(pawn) ~= nil and pawn.GetWand ~= nil then
		M.print("Trying to connect wand for pawn " .. pawn:get_full_name() .. " " .. hand)
		local wand = pawn:GetWand()
		if wand ~= nil then
			--component is the new SK_Wand
			local component = uevrUtils.createSkeletalMeshComponent(wand.SK_Wand.SkeletalMesh:get_full_name(), wand)	
			component:SetVisibility(true, true)
			component:SetHiddenInGame(false, true)
			
			uevrUtils.copyMaterials(wand.SK_Wand, component)
			
			--destroy the existing SK_Wand
			--wand:K2_DestroyComponent(wand.SK_Wand)
			
			if wand.Mesh ~= nil and UEVR_UObjectHook.exists(wand.Mesh) then
				component:K2_AttachTo(wand.Mesh, uevrUtils.fname_from_string(""), 0, false)
				M.print("Attached SK_Wand to Mesh " .. wand.Mesh:get_full_name())
			else
				controllers.attachComponentToController(hand, component)
				uevrUtils.set_component_relative_transform(component, controllerWandPositionOffset, controllerWandRotationOffset)	
				M.print("Attached SK_Wand to Motion Controller")
			end
			
			local oldWand = wand.SK_Wand
			wand.SK_Wand:DetachFromParent(true, false)
			wand.SK_Wand:Deactivate()			
			wand.SK_Wand = component	
			wand:SetWandStyle(wand.WandStyle)
			--destroy the existing SK_Wand
			--without the delay crashes occur
			delay(100, function()
				wand:K2_DestroyComponent(oldWand)
			end)
			
			M.print("Alt wand component created " .. component:get_full_name())
		end
	end
	M.print("connectAltWand finished")
end

function M.disconnect()
	if wandMeshParent ~= nil and wandMeshAttachSocketName ~= nil then
		pcall(function()		
			meshComponent:DetachFromParent(false,false)
			uevrUtils.set_component_relative_transform(meshComponent)			
			if meshComponent.K2_AttachToComponent ~= nil then
				meshComponent:K2_AttachToComponent(wandMeshParent, wandMeshAttachSocketName, 0, 0, 0, false)
			end

			wandMeshParent = nil
			wandMeshAttachSocketName = nil
		end)
		M.print("Reattached wand to parent")
	else
		M.print("Couldnt reattach wand to parent")
	end
end

-- function M.getPosition()
	-- if uevrUtils.validate_object(meshComponent) ~= nil and meshComponent.K2_GetComponentLocation ~= nil then	
		-- return meshComponent:K2_GetComponentLocation()
	-- end
	-- return nil
-- end
-- function M.updateOffsetPosition(handPosition)
	-- if uevrUtils.validate_object(meshComponent) ~= nil and meshComponent.K2_GetComponentLocation ~= nil then	
		-- local wandPosition = M.getPosition()
		-- local deltaX = wandPosition.X - handPosition.X
		-- local deltaY = wandPosition.Y - handPosition.Y
		-- local deltaZ = wandPosition.Z - handPosition.Z
		-- distance = kismet_math_library:Vector_Distance(wandPosition, handPosition)
		-- local factor = 5.75 / distance 
		-- local pos = {X=controllerWandPositionOffset.X * factor, Y=controllerWandPositionOffset.Y * factor, Z=controllerWandPositionOffset.Z * factor}
		-- print("Deltas",distance, factor,"\n")

		-- uevrUtils.set_component_relative_transform(meshComponent, pos, controllerWandRotationOffset)	
	-- end
-- end

function M.getWandTargetLocationAndDirection(useLineTrace)
	if useLineTrace == nil then useLineTrace = false end
	
	local lastLocation = nil
	local lastDirection = nil
	local lastPosition = nil
	if uevrUtils.validate_object(meshComponent) ~= nil and meshComponent.K2_GetComponentLocation ~= nil then	
		lastPosition = meshComponent:K2_GetComponentLocation()
		local forwardVector = meshComponent:GetUpVector()
		lastPosition = lastPosition + (forwardVector * wandTipOffset)
		local endPos = lastPosition + (forwardVector * 8192.0)
		lastLocation = {X=endPos.X, Y=endPos.Y, Z=endPos.Z}		
		lastDirection = {X=forwardVector.X, Y=forwardVector.Y, Z=forwardVector.Z}
		
		--print(useLineTrace,forwardVector.X,forwardVector.Y, forwardVector.Z,"\n")
		if useLineTrace then
			local ignore_actors = {}
			local world = getWorld()
			if world ~= nil then
				local hit = kismet_system_library:LineTraceSingle(world, lastPosition, endPos, 0, true, ignore_actors, 0, reusable_hit_result, true, zero_color, zero_color, 1.0)
				if hit and reusable_hit_result.Distance > 10 then
					lastLocation = {X=reusable_hit_result.Location.X, Y=reusable_hit_result.Location.Y, Z=reusable_hit_result.Location.Z}
				end
			end
		end
	end

	return lastLocation, lastDirection, lastPosition
end

function M.setVisible(pawn, val)
	if uevrUtils.validate_object(pawn) ~= nil and pawn.GetWand ~= nil then
		local wand = pawn:GetWand()
		if wand ~= nil then
			if val then
				wand:ActivateFx()
				bIsVisible = true
			else
				wand:DeactivationFx()
				bIsVisible = false
			end
			--if funcCallbacks["Visible"] ~= nil then funcCallbacks["Visible"](bIsVisible) end

		end
	end

end

function M.updateVisibility(pawn, override)
	if not override and not isWandHolstered then
		M.setVisible(pawn, true)
		-- if pawn ~= nil then --and pawn.EquipWand ~= nil then
			-- --pawn:EquipWand()
			-- local wand = pawn:GetWand()
			-- if wand ~= nil then
				-- wand:ActivateFx()
				-- --wand:DeactivationFx()
				-- -- local meshComponent = pawn:GetWand().Mesh
				-- -- if meshComponent ~= nil then
					-- -- meshComponent:SetVisibility(true, true)
					-- -- meshComponent:SetHiddenInGame(false, true)
				-- -- end
			-- end
		-- end
		-- -- if pawn ~= nil then
			-- -- print("Is wand equipped",pawn:IsWandEquipped(),"\n")
		-- -- end
	end
end

function M.holsterWand(pawn, val)
	isWandHolstered = val
	M.setVisible(pawn, not isWandHolstered)
end

local triggerValue = 100
local gripOn = false
local triggerOn = false
function M.handleInput(pawn, state, isLeftHanded)
	local gripButton = XINPUT_GAMEPAD_RIGHT_SHOULDER
	if isLeftHanded then
		gripButton = XINPUT_GAMEPAD_LEFT_SHOULDER
	end
	if uevrUtils.isButtonPressed(state, gripButton) and not gripOn then
		gripOn = true
		if uevrUtils.validate_object(meshComponent) ~= nil and meshComponent.K2_GetComponentLocation ~= nil then	
			local rotation = meshComponent:K2_GetComponentRotation()
			--print(rotation.Pitch,rotation.Yaw,rotation.Roll,"\n")
			--only holster if the wand is pointing down
			if rotation.Pitch > -20 and rotation.Pitch < 20 then
				M.holsterWand(pawn, true)
			end
		end
	elseif uevrUtils.isButtonNotPressed(state, gripButton) and gripOn then
		gripOn = false
	end

	local triggerButtton = state.Gamepad.bRightTrigger
	if isLeftHanded then
		triggerButtton = state.Gamepad.bLeftTrigger
	end
	if triggerButtton > triggerValue and not triggerOn then
		triggerOn = true
		M.holsterWand(pawn, false)
	elseif triggerButtton <= triggerValue and triggerOn then
		triggerOn = false
	end
end

-- local g_shoulderGripOn = false
-- function M.handleBrokenWand(pawn, state, isLeftHanded)
	-- local gripButton = XINPUT_GAMEPAD_RIGHT_SHOULDER
	-- if isLeftHanded then
		-- gripButton = XINPUT_GAMEPAD_LEFT_SHOULDER
	-- end
	-- if not g_shoulderGripOn and uevrUtils.isButtonPressed(state, gripButton)  then
		-- g_shoulderGripOn = true
		-- local headLocation = controllers.getControllerLocation(2)
		-- local handLocation = controllers.getControllerLocation(isLeftHanded and 0 or 1)
		-- if headLocation ~= nil and handLocation ~= nil then
			-- local distance = kismet_math_library:Vector_Distance(headLocation, handLocation)
			-- --print(distance,"\n")
			-- if distance < 30 then	
				-- M.connectAltWand(pawn, isLeftHanded and 0 or 1)
			-- end
		-- end
	-- elseif g_shoulderGripOn and uevrUtils.isButtonNotPressed(state, gripButton) then
		-- delay(1000, function()
			-- g_shoulderGripOn = false
		-- end)
	-- end

-- end
-- function M.registerCallback(name, func)
	-- funcCallbacks[name] = func
-- end
local function updateCallback(name)
	if name == "Visible" and previousIsVisible ~= bIsVisible then
		if onWandVisibilityChange ~= nil then
			local success, response = pcall(function()		
				onWandVisibilityChange(bIsVisible)
			end)
			-- if success == false then
				-- M.print("[updateCallback] " .. response, LogLevel.Error)
			-- end
		end
		previousIsVisible = bIsVisible
	end
	-- if funcCallbacks[name] ~= nil then
		-- if name == "Visible" and previousIsVisible ~= bIsVisible then
			-- local success, response = pcall(function()
				-- return funcCallbacks[name](bIsVisible)
			-- end)
			-- if success == false then
				-- M.print("[updateCallback] " .. response, LogLevel.Error)
			-- else
				-- previousIsVisible = bIsVisible
			-- end		
		-- end		
	-- end
end
function M.registerHooks()	
	RegisterHook("/Script/Toolset.Tool:ActivateFx", function(self, name)
		--print("ActivateFx called\n")
		bIsVisible = true
		updateCallback("Visible")
	end)
	RegisterHook("/Script/Toolset.Tool:DeactivationFx", function(self, name)
		--print("DeactivationFx called\n")
		bIsVisible = false
		updateCallback("Visible")
	end)

	if isDebug then
		RegisterHook("/Game/Gameplay/ToolSet/Items/Wand/BP_WandTool.BP_WandTool_C:SetWandStyle", function(self, name)
			print("SetWandStyle called ",name:get():ToString(),"\n")
		end)

		RegisterHook("/Script/Phoenix.WandTool:OnActiveSpellToolChanged", function(self, ActivatedSpell, DeactivatedSpell)
			print("OnActiveSpellToolChanged called\n")
			local activatedTool = ActivatedSpell ~= nil and ActivatedSpell:get() or nil
			local deactivatedTool = DeactivatedSpell ~= nil and DeactivatedSpell:get() or nil
			if deactivatedTool ~= nil then
				print("Deactivated", deactivatedTool:GetFullName(),"\n")
			end
			if activatedTool ~= nil then
				print("Activated", activatedTool:GetFullName(),"\n")
			end
		end)
	end
end

function M.registerLateHooks()

	if isDebug then
		RegisterHook("/Game/Gameplay/ToolSet/Items/Wand/BP_WandTool.BP_WandTool_C:ResetLightCombo", function(self)
			print("ResetLightCombo called\n")
		end)
		
		RegisterHook("/Game/Gameplay/ToolSet/Items/Wand/BP_WandTool.BP_WandTool_C:HeavyComboTimerExpired", function(self)
			print("HeavyComboTimerExpired called\n")
		end)

		RegisterHook("/Game/Gameplay/ToolSet/Items/Wand/BP_WandTool.BP_WandTool_C:ComboTimerExpired", function(self)
			print("ComboTimerExpired called\n")
		end)

		RegisterHook("/Game/Gameplay/ToolSet/Items/Wand/BP_WandTool.BP_WandTool_C:CancelComboSplitTimer", function(self)
			print("ComboTimerExpired called\n")
		end)

		RegisterHook("/Game/Gameplay/ToolSet/Items/Wand/BP_WandTool.BP_WandTool_C:StartHeavyComboSplitTimer", function(self, ComboSplitData)
			print("StartHeavyComboSplitTimer called\n")
			local splitTimer = ComboSplitData ~= nil and ComboSplitData:get() or nil
			if splitTimer ~= nil then
				print(splitTimer.SplitFrame, splitTimer.TimeOutFrame, splitTimer.SplitToAbilityBeforeFrame:GetFullName(), splitTimer.SplitToAbilityAfterFrame:GetFullName(), "\n")
			end
		end)

		RegisterHook("/Game/Gameplay/ToolSet/Items/Wand/BP_WandTool.BP_WandTool_C:StartComboSplitTimer", function(self, ComboSplitData)
			print("StartComboSplitTimer called\n")
		end)
	end
end

local g_lastPosition = nil
function M.debugWand(pawn)
	if pawn ~= nil then --and pawn.EquipWand ~= nil then
		print("Have pawn\n")
		local wand = pawn:GetWand()
		if wand ~= nil then
			print("Have wand",wand:get_full_name(),"\n")
			
			local meshComponent = wand.Mesh
			if meshComponent ~= nil then
				print("Have mesh",meshComponent:get_full_name(),"\n")
				--meshComponent:SetVisibility(true, true)
				--meshComponent:SetHiddenInGame(false, true)
			end
			local skWand = wand.SK_Wand
			if skWand ~= nil then
				print("Have skWand",skWand:get_full_name(),"\n")
				local location = wand.SK_Wand:K2_GetComponentLocation()
				--print(location.X, location.Y, location.Z,"\n")
				if g_lastPosition ~= nil and g_lastPosition.X == location.X and g_lastPosition.Y == location.Y and g_lastPosition.Z == location.Z then
					--print("***************Fail\n")
				end
				g_lastPosition = location
			end
		end
	end
	-- if pawn ~= nil then
		-- print("Is wand equipped",pawn:IsWandEquipped(),"\n")
	-- end

end

return M