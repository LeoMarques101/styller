local deathListEnabled = true
local maxDeathRecords = 5

function onDeath(player, corpse, killer, mostDamageKiller, lastHitUnjustified, mostDamageUnjustified)
	local playerId = player:getId()
	if nextUseStaminaTime[playerId] then
		nextUseStaminaTime[playerId] = nil
	end

	player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You are dead.")
	if not deathListEnabled then
		return
	end

	local byPlayer = 0
	local killerName
	if killer then
		if killer:isPlayer() then
			byPlayer = 1
		else
			local master = killer:getMaster()
			if master and master ~= killer and master:isPlayer() then
				killer = master
				byPlayer = 1
			end
		end
		killerName = killer:getName()
	else
		killerName = "field item"
	end

	local byPlayerMostDamage = 0
	local mostDamageKillerName
	if mostDamageKiller then
		if mostDamageKiller:isPlayer() then
			byPlayerMostDamage = 1
		else
			local master = mostDamageKiller:getMaster()
			if master and master ~= mostDamageKiller and master:isPlayer() then
				mostDamageKiller = master
				byPlayerMostDamage = 1
			end
		end
		mostDamageName = mostDamageKiller:getName()
	else
		mostDamageName = "field item"
	end

	local playerGuid = player:getGuid()
	db.query("INSERT INTO `player_deaths` (`player_id`, `time`, `level`, `killed_by`, `is_player`, `mostdamage_by`, `mostdamage_is_player`, `unjustified`, `mostdamage_unjustified`) VALUES (" .. playerGuid .. ", " .. os.time() .. ", " .. player:getLevel() .. ", " .. db.escapeString(killerName) .. ", " .. byPlayer .. ", " .. db.escapeString(mostDamageName) .. ", " .. byPlayerMostDamage .. ", " .. (lastHitUnjustified and 1 or 0) .. ", " .. (mostDamageUnjustified and 1 or 0) .. ")")
	local resultId = db.storeQuery("SELECT `player_id` FROM `player_deaths` WHERE `player_id` = " .. playerGuid)

	local deathRecords = 0
	local tmpResultId = resultId
	while tmpResultId ~= false do
		tmpResultId = result.next(resultId)
		deathRecords = deathRecords + 1
	end

	if resultId ~= false then
		result.free(resultId)
	end

	local limit = deathRecords - maxDeathRecords
	if limit > 0 then
		db.asyncQuery("DELETE FROM `player_deaths` WHERE `player_id` = " .. playerGuid .. " ORDER BY `time` LIMIT " .. limit)
	end

	if byPlayer == 1 then
		local targetGuild = player:getGuild()
		targetGuild = targetGuild and targetGuild:getId() or 0
		if targetGuild ~= 0 then
			local killerGuild = killer:getGuild()
			killerGuild = killerGuild and killerGuild:getId() or 0
			if killerGuild ~= 0 and targetGuild ~= killerGuild and isInWar(playerId, killer:getId()) then
				local warId = false
				resultId = db.storeQuery("SELECT `id` FROM `guild_wars` WHERE `status` = 1 AND ((`guild1` = " .. killerGuild .. " AND `guild2` = " .. targetGuild .. ") OR (`guild1` = " .. targetGuild .. " AND `guild2` = " .. killerGuild .. "))")
				if resultId ~= false then
					warId = result.getNumber(resultId, "id")
					result.free(resultId)
				end

				if warId ~= false then
					local playerName = player:getName()
					db.asyncQuery("INSERT INTO `guildwar_kills` (`killer`, `target`, `killerguild`, `targetguild`, `time`, `warid`) VALUES (" .. db.escapeString(killerName) .. ", " .. db.escapeString(playerName) .. ", " .. killerGuild .. ", " .. targetGuild .. ", " .. os.time() .. ", " .. warId .. ")")

					local resultId = db.storeQuery("SELECT `guild_wars`.`id`, (SELECT `limit` FROM `znote_guild_wars` WHERE `znote_guild_wars`.`id` = `guild_wars`.`id`) AS `limit`, (SELECT COUNT(1) FROM `guildwar_kills` WHERE `guildwar_kills`.`warid` = `guild_wars`.`id` AND `guildwar_kills`.`killerguild` = `guild_wars`.`guild1`) guild1_kills, (SELECT COUNT(1) FROM `guildwar_kills` WHERE `guildwar_kills`.`warid` = `guild_wars`.`id` AND `guildwar_kills`.`killerguild` = `guild_wars`.`guild2`) guild2_kills FROM `guild_wars` WHERE (`guild1` = " .. killerGuild .. " OR `guild2` = " .. killerGuild .. ") AND `status` = 1 AND `id` = " .. warId)
					if resultId then

						local guild1_kills = result.getNumber(resultId, "guild1_kills")
						local guild2_kills = result.getNumber(resultId, "guild2_kills")
						local limit = result.getNumber(resultId, "limit")
						result.free(resultId)

						local killerGuildWar = killer:getGuild()
						local members = killerGuildWar:getMembersOnline()
						for i = 1, #members do
							members[i]:sendChannelMessage("", string.format("%s was killed by %s. The new score is %d:%d frags (limit: %d)", playerName, killerName, guild1_kills, guild2_kills, limit), TALKTYPE_CHANNEL_R1, CHANNEL_GUILD)
						end

						local targetGuildWar = player:getGuild()
						local enemyMembers = targetGuildWar:getMembersOnline()
						for i = 1, #enemyMembers do
							enemyMembers[i]:sendChannelMessage("", string.format("%s was killed by %s. The new score is %d:%d frags (limit: %d)", playerName, killerName, guild1_kills, guild2_kills, limit), TALKTYPE_CHANNEL_R1, CHANNEL_GUILD)
						end

						if guild1_kills >= limit or guild2_kills >= limit then
							db.query("UPDATE `guild_wars` SET `status` = 4, `ended` = " .. os.time() .. " WHERE `status` = 1 AND `id` = " .. warId)
							Game.broadcastMessage(string.format("%s has just won the war against %s.", killerGuildWar:getName(), targetGuildWar:getName()), MESSAGE_EVENT_ADVANCE)
						end
					end
				end
			end
		end
	end
end
