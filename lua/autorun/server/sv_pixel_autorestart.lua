
local config = {
    restartChecker = {
        earliestTime = 6 * 3600, --*3600 for hours
        latestTime = 22 * 3600,
        maxPlayers = 1,
        playerCheckFrequency = 1 * 60
    },
    forcedRestart = {
        deployTime = 2.5 * 60,
        restartTime = 5 * 60,
        deployDelayTime = 30
    },
    deployHq = {
        emailAddress = "***REMOVED***",
        apiKey = "***REMOVED***",
        apiEndpoint = "***REMOVED***",
        projectId = "***REMOVED***",
        targetBranch = "master",
        serverId = "***REMOVED***",
        completionCheckInterval = 15,
        completionCheckLimit = 0
    },
    pterodactyl = {
        apiKey = "***REMOVED***",
        apiEndpoint = "***REMOVED***",
        serverId = "***REMOVED***"
    },
    discord = {
        publicWebhook = "***REMOVED***",
        adminWebhook = "***REMOVED***",
        username = "PIXEL Auto-Restart",
        avatarUrl = "***REMOVED***",
        steamJoinLink = "steam://connect/***REMOVED***",
        discordJoinLink = "https://discord.gg/***REMOVED***"
    },
    authed = {
        ["76561198215456356"] = true, --tom
        ***REMOVED***
    }
}

local autoRestart = {}

do
    local conf = config.restartChecker
    function autoRestart.onRestartReady()
        local playerCount = player.GetCount()
        if playerCount <= conf.maxPlayers then
            if playerCount == 0 then autoRestart:startRestart()
            else autoRestart:startForcefulRestart(config.forcedRestart.deployTime, config.forcedRestart.restartTime) end
            return
        end

        autoRestart:sendDiscordAdminMessage("The server is ready for a restart but players are online, waiting for them to leave...")

        local timeLeft = conf.latestTime - conf.earliestTime
        hook.Run("AutoRestart.WaitingForPlayersStarted", timeLeft)
        timer.Create("AutoRestart.WaitForPlayerLeave", conf.playerCheckFrequency, timeLeft / conf.playerCheckFrequency, autoRestart.onPlayerWaitCheck)
    end

    function autoRestart.onPlayerWaitCheck()
        if timer.RepsLeft("AutoRestart.WaitForPlayerLeave") < 1 then
            autoRestart:startForcefulRestart(config.forcedRestart.deployTime, config.forcedRestart.restartTime)
            return
        end

        local playerCount = player.GetCount()
        if playerCount > conf.maxPlayers then return end
        if playerCount == 0 then autoRestart:startRestart()
        else autoRestart:startForcefulRestart(config.forcedRestart.deployTime, config.forcedRestart.restartTime) end
    end

    timer.Create("AutoRestart.RestartReadyChecker", conf.earliestTime, 1, autoRestart.onRestartReady)
end

do
    local conf = config.deployHq
    local headers = {
        ["Accept"] = "application/json",
        ["Content-Type"] = "application/json",
        ["Authorization"] = "Basic " .. string.Replace(util.Base64Encode(conf.emailAddress .. ":" .. conf.apiKey), "\n", "") --What the fuck rubat
    }

    local function getServerRevision(callback)
        HTTP({
            ["url"] = string.format("%s/projects/%s/servers/%s", conf.apiEndpoint, conf.projectId, conf.serverId),
            ["method"] = "GET",
            ["headers"] = headers,
            ["success"] = function(statusCode, body)
                if statusCode ~= 200 then
                    autoRestart:sendDiscordAdminMessage("Failed to get the server's latest revision via DeployHQ API:\nServer returned a non 200 status code.", true)
                    return
                end

                body = util.JSONToTable(body)
                if not body then
                    autoRestart:sendDiscordAdminMessage("Failed to get the server's latest revision via DeployHQ API:\nFailed to parse response body.", true)
                    return
                end

                local lastRevision = body["last_revision"]
                if not lastRevision then
                    autoRestart:sendDiscordAdminMessage("Failed to get the server's latest revision via DeployHQ API:\nResponse doesn't contain a last revision.", true)
                    return
                end

                callback(lastRevision)
            end,
            ["failed"] = function(reason)
                autoRestart:sendDiscordAdminMessage("Failed to get the server's latest revision via DeployHQ API:\n" .. reason, true)
            end
        })
    end

    local function getLatestCommit(callback)
        HTTP({
            ["url"] = string.format("%s/projects/%s/repository/recent_commits/?branch=%s", conf.apiEndpoint, conf.projectId, conf.targetBranch),
            ["method"] = "GET",
            ["headers"] = headers,
            ["success"] = function(statusCode, body)
                if statusCode ~= 200 then
                    autoRestart:sendDiscordAdminMessage("Failed to get the repository's latest revision via DeployHQ API:\nServer returned a non 200 status code.", true)
                    return
                end

                body = util.JSONToTable(body)
                if not body then
                    autoRestart:sendDiscordAdminMessage("Failed to get the repository's latest revision via DeployHQ API:\nFailed to parse response body.", true)
                    return
                end

                local commits = body["commits"]
                if not commits then
                    autoRestart:sendDiscordAdminMessage("Failed to get the repository's latest revision via DeployHQ API:\nResponse doesn't contain a commits list.", true)
                    return
                end

                local latestCommit = commits[1]
                if not latestCommit then
                    autoRestart:sendDiscordAdminMessage("Failed to get the repository's latest revision via DeployHQ API:\nResponse doesn't contain a commits at index 1.", true)
                    return
                end

                local commitId = latestCommit["ref"]
                if not commitId then
                    autoRestart:sendDiscordAdminMessage("Failed to get the repository's latest revision via DeployHQ API:\nResponse doesn't contain a commit ID.", true)
                    return
                end

                callback(commitId)
            end,
            ["failed"] = function(reason)
                autoRestart:sendDiscordAdminMessage("Failed to the latest commit via DeployHQ API:\n" .. reason, true)
            end
        })
    end

    function autoRestart:checkForDeployCompletion(deployId, callback)
        HTTP({
            ["url"] = string.format("%s/projects/%s/deployments/%s", conf.apiEndpoint, conf.projectId, deployId),
            ["method"] = "GET",
            ["headers"] = headers,
            ["success"] = function(statusCode, body)
                if statusCode ~= 200 then
                    self:sendDiscordAdminMessage("Failed to get the server's deploy completion state via DeployHQ API:\nServer returned a non 200 status code.", true)
                    return
                end

                body = util.JSONToTable(body)
                if not body then
                    self:sendDiscordAdminMessage("Failed to get the server's deploy completion state via DeployHQ API:\nFailed to parse response body.", true)
                    return
                end

                callback(body["status"] == "completed")
            end,
            ["failed"] = function(reason)
                self:sendDiscordAdminMessage("Failed to get the server's deploy completion state via DeployHQ API:\n" .. reason, true)
            end
        })
    end

    function autoRestart:waitForDeployCompletion(deployId, callback)
        timer.Create("AutoRestart.WaitForDeployCompletion", conf.completionCheckInterval, conf.completionCheckLimit, function()
            self:checkForDeployCompletion(deployId, function(complete)
                if complete then
                    callback(true)
                    timer.Remove("AutoRestart.WaitForDeployCompletion")
                    return
                end

                if conf.completionCheckLimit == 0 then return end
                if timer.RepsLeft("AutoRestart.WaitForDeployCompletion") > 0 then return end

                self:sendDiscordAdminMessage("The deploy completion checker timed out.", true)
                callback()
            end)
        end)
    end

    function autoRestart:sendDeployRequest(callback)
        getServerRevision(function(curRevision)
            getLatestCommit(function(newRevision)
                HTTP({
                    ["url"] = string.format("%s/projects/%s/deployments", conf.apiEndpoint, conf.projectId),
                    ["method"] = "POST",
                    ["headers"] = headers,
                    ["type"] = "application/json",
                    ["body"] = string.format("{\"deployment\":{\"parent_identifier\":\"%s\",\"start_revision\":\"%s\",\"end_revision\":\"%s\"}}",
                        conf.serverId, curRevision, newRevision),
                    ["success"] = function(statusCode, body)
                        if statusCode ~= 201 then
                            self:sendDiscordAdminMessage("Failed to send a deploy request via DeployHQ API:\nServer returned a non 201 status code.", true)
                            return
                        end

                        body = util.JSONToTable(body)
                        if not body then
                            self:sendDiscordAdminMessage("Failed to get the ongoing deploy ID via DeployHQ API:\nFailed to parse response body.", true)
                            return
                        end

                        local deployId = body["identifier"]
                        if not deployId then
                            self:sendDiscordAdminMessage("Failed to get the ongoing deploy ID via DeployHQ API:\nResponse doesn't contain a deploy ID.", true)
                            return
                        end

                        if callback then self:waitForDeployCompletion(deployId, callback) end
                    end,
                    ["failed"] = function(reason)
                        self:sendDiscordAdminMessage("Failed to send a deploy request via DeployHQ API:\n" .. reason, true)
                    end
                })
            end)
        end)
    end
end

function autoRestart:sendRestartSignal()
    local discordLink = config.discord.discordJoinLink
    for _, ply in ipairs(player.GetAll()) do
        ply:Kick([[The server is running an automated restart, it will be available soon.
Join the Discord for an alert for when it's back online:
]] .. discordLink)
    end

    local conf = config.pterodactyl
    HTTP({
        ["url"] = string.format("%s/client/servers/%s/power", conf.apiEndpoint, conf.serverId),
        ["method"] = "POST",
        ["headers"] = {
            ["Accept"] = "application/json",
            ["Content-Type"] = "application/json",
            ["Authorization"] = "Bearer " .. conf.apiKey
        },
        ["type"] = "application/json",
        ["body"] = "{\"signal\":\"restart\"}",
        ["success"] = function(statusCode, body)
            if statusCode ~= 204 then
                self:sendDiscordAdminMessage("Failed to reboot the server via Pterodactyl API:\nServer returned a non 204 status code.", true)
                return
            end
        end,
        ["failed"] = function(reason)
            self:sendDiscordAdminMessage("Failed to reboot the server via Pterodactyl API:\n" .. reason, true)
        end
    })
end

do
    if pcall(function() require("chttp") end) then
        local conf = config.discord
        local function sendRequest(url, message)
            message = string.Replace(message, "\n", "\\n")

            CHTTP({
                ["url"] = url,
                ["body"] = string.format("{\"username\":\"%s\",\"avatar_url\":\"%s\",\"content\":\"%s\"}", conf.username, conf.avatarUrl, message),
                ["method"] = "POST",
                ["headers"] = {
                    ["Accept"] = "application/json",
                    ["Content-Type"] = "application/json"
                },
                ["success"] = function(statusCode, body)
                    if statusCode == 200 or statusCode == 204 then return end
                    print("Auto Restart: Failed to send Discord message \"" .. message .. "\":\nServer returned a non 200 status code.")
                end,
                ["failed"] = function(reason)
                    print("Auto Restart: Failed to send Discord message \"" .. message .. "\":\n" .. reason)
                end
            })
        end

        function autoRestart:sendDiscordMessage(message)
            sendRequest(conf.publicWebhook, message)
        end

        function autoRestart:sendDiscordAdminMessage(message, mention)
            if mention then message = "@everyone " .. message end
            sendRequest(conf.adminWebhook, message)
        end

        hook.Add("InitPostEntity", "AutoRestart.AlertStarted", function()
            autoRestart:sendDiscordMessage("The server has updated automatically and is now back online.\n" .. conf.steamJoinLink)
        end)
    else
        print("Auto Restart: CHTTP not found, using server chat/console as fallback.")
        function autoRestart:sendDiscordMessage(message)
            message = "Auto Restart: " .. message
            PrintMessage(HUD_PRINTTALK, message)
            print(message)
        end

        function autoRestart:sendDiscordAdminMessage(message)
            print("Auto Restart: " .. message)
        end
    end
end

do
    local conf = config.forcedRestart
    local function cancelTasks()
        timer.Remove("AutoRestart.RestartReadyChecker")
        timer.Remove("AutoRestart.WaitForPlayerLeave")
    end

    function autoRestart:startRestart(forced, ply)
        if forced then
            if not IsValid(ply) then return end
            if not config.authed[ply:SteamID64()] then
                self:sendDiscordAdminMessage("A non-authed user atempted to start a restart " .. ply:Name() .. ":" .. ply:SteamID64())
            return end

            self:sendDiscordAdminMessage(ply:Name() .. " has requested a server restart, running a deploy.")
        end

        cancelTasks()
        hook.Run("AutoRestart.RestartStarted")

        if not forced then
            self:sendDiscordAdminMessage("A non-forceful restart was requested, running a deploy.")
        end

        self:sendDeployRequest(function(complete)
            if not complete then return end

            self:sendDiscordAdminMessage("The deploy has completed successfully, restarting the server.")
            self:sendRestartSignal()
        end)
    end

    function autoRestart:startForcefulRestart(deployTime, restartTime)
        cancelTasks()
        hook.Run("AutoRestart.ForcefulRestartScheduled", deployTime, restartTime)

        self:sendDiscordMessage("The server is about to restart, please wait before joining.")
        self:sendDiscordAdminMessage("A forceful restart was requested.")

        local canRestart
        timer.Create("AutoRestart.ForcefulDeploy", deployTime, 1, function()
            hook.Run("AutoRestart.ForcefulDeployStarted")

            self:sendDeployRequest(function(complete)
                if not complete then return end

                canRestart = true
                self:sendDiscordAdminMessage("The deploy has completed successfully.")
                hook.Run("AutoRestart.ForcefulDeployComplete")
            end)
        end)

        timer.Create("AutoRestart.ForcefulRestart", restartTime, 1, function()
            if canRestart then
                hook.Run("AutoRestart.ForcefulRestartStarted")
                self:sendDiscordAdminMessage("The restart timer has finished, restarting the server.")
                self:sendRestartSignal()

                return
            end

            hook.Run("AutoRestart.ForcefulRestartDelayed")
            self:sendDiscordAdminMessage("The restart has been delayed, waiting for the deploy to finish first.")

            timer.Create("AutoRestart.ForcefulRestartDelay", conf.deployDelayTime, 5, function()
                if canRestart then
                    hook.Run("AutoRestart.ForcefulRestartStarted")
                    self:sendDiscordAdminMessage("The restart timer has finished, restarting the server.")
                    self:sendRestartSignal()
                    return
                end

                if (timer.RepsLeft("AutoRestart.WaitForDeployCompletion") or 1) > 0 then return end
                hook.Run("AutoRestart.ForcefulRestartUnscheduled")
                self:sendDiscordAdminMessage("The deploy took too long to execute and the restart has been unscheduled.", true)
            end)
        end)
    end

    function autoRestart:cancelRestart(ply)
        if not IsValid(ply) then return end
        if not ply:IsSuperAdmin() then return end

        self:sendDiscordAdminMessage("The automated restart was cancelled by " .. ply:Name() .. ".", true)

        timer.Remove("AutoRestart.RestartReadyChecker")
        timer.Remove("AutoRestart.WaitForPlayerLeave")

        timer.Remove("AutoRestart.ForcefulDeploy")
        timer.Remove("AutoRestart.ForcefulRestart")
        timer.Remove("AutoRestart.ForcefulRestartDelay")
    end
end

AutoRestart = {
    ["CancelRestart"] = function(ply) autoRestart:cancelRestart(ply) end,
    ["StartRestart"] = function(ply) autoRestart:startRestart(true, ply) end
}