function onStepIn(creature, item, position, fromPosition)
	local player = creature:getPlayer()
	if not player then
		return true
	end

	player:teleportTo(Position(1012, 960, 9))
	player:getPosition():sendMagicEffect(CONST_ME_TELEPORT)

	return true
end