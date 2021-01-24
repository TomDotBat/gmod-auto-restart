
local config = {
    deployHq = {
        emailAddress = "***REMOVED***",
        apiKey = "***REMOVED***",
        apiEndpoint = "***REMOVED***",
        projectId = "***REMOVED***",
        targetBranch = "master",
        serverId = "981bf713-1966-4dc7-813f-221fc09a3e82" --"***REMOVED***"
    },
    pterodactyl = {
        apiKey = "***REMOVED***",
        apiEndpoint = "***REMOVED***",
        serverId = "27c2b5b6" --"1a7ce997"
    },
    discord = {
        publicWebhook = "",
        adminWebhook = "***REMOVED***",
        username = "PIXEL Auto-Restart",
        avatarUrl = "***REMOVED***"
    }
}

local autoRestart = {}

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
                    autoRestart:sendDiscordAdminMessage("Failed to get the server's latest revision via DeployHQ API:\nServer returned a non 200 status code.")
                    return
                end

                body = util.JSONToTable(body)
                if not body then
                    autoRestart:sendDiscordAdminMessage("Failed to get the server's latest revision via DeployHQ API:\nFailed to parse response body.")
                    return
                end

                local lastRevision = body["last_revision"]
                if not lastRevision then
                    autoRestart:sendDiscordAdminMessage("Failed to get the server's latest revision via DeployHQ API:\nResponse doesn't contain a last revision.")
                    return
                end

                callback(lastRevision)
            end,
            ["failed"] = function(reason)
                autoRestart:sendDiscordAdminMessage("Failed to get the server's latest revision via DeployHQ API:\n" .. reason)
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
                    autoRestart:sendDiscordAdminMessage("Failed to get the repository's latest revision via DeployHQ API:\nServer returned a non 200 status code.")
                    return
                end

                body = util.JSONToTable(body)
                if not body then
                    autoRestart:sendDiscordAdminMessage("Failed to get the repository's latest revision via DeployHQ API:\nFailed to parse response body.")
                    return
                end

                local commits = body["commits"]
                if not commits then
                    autoRestart:sendDiscordAdminMessage("Failed to get the repository's latest revision via DeployHQ API:\nResponse doesn't contain a commits list.")
                    return
                end

                local latestCommit = commits[1]
                if not latestCommit then
                    autoRestart:sendDiscordAdminMessage("Failed to get the repository's latest revision via DeployHQ API:\nResponse doesn't contain a commits at index 1.")
                    return
                end

                local commitId = latestCommit["ref"]
                if not commitId then
                    autoRestart:sendDiscordAdminMessage("Failed to get the repository's latest revision via DeployHQ API:\nResponse doesn't contain a commit ID.")
                    return
                end

                callback(commitId)
            end,
            ["failed"] = function(reason)
                autoRestart:sendDiscordAdminMessage("Failed to the latest commit via DeployHQ API:\n" .. reason)
            end
        })
    end

    function autoRestart:sendDeployRequest()
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
                            self:sendDiscordAdminMessage("Failed to send a deploy request via DeployHQ API:\nServer returned a non 201 status code.")
                            return
                        end
                    end,
                    ["failed"] = function(reason)
                        self:sendDiscordAdminMessage("Failed to send a deploy request via DeployHQ API:\n" .. reason)
                    end
                })
            end)
        end)
    end
end

function autoRestart:sendRestartSignal()
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
                self:sendDiscordAdminMessage("Failed to reboot the server via Pterodactyl API:\nServer returned a non 204 status code.")
                return
            end
        end,
        ["failed"] = function(reason)
            self:sendDiscordAdminMessage("Failed to reboot the server via Pterodactyl API:\n" .. reason)
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
                ["body"] = string.format("{\"username\":\"%s\",\"avatar_url\":\"%s\",\"content\":\"%s\"}",
                    conf.username, conf.avatarUrl, message),
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

        function autoRestart:sendDiscordAdminMessage(message)
            sendRequest(conf.adminWebhook, "@noteveryone " .. message)
        end
    else
        print("Auto Restart: CHTTP not found, server chat/console as fallback.")
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