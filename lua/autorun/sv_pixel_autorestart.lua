
local config = {
    deployHq = {
        emailAddress = "***REMOVED***",
        apiKey = "***REMOVED***",
        apiEndpoint = "***REMOVED***",
        projectId = "***REMOVED***",
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
        avatarUrl = nil
    }
}

local autoRestart = {}

do
    local conf = config.deployHq
    local headers = {
        ["Accept"] = "application/json",
        ["Content-Type"] = "application/json",
        ["Authorization"] = "Basic " .. conf.emailAddress .. ":" .. conf.apiKey
    }

    local function getServerRevision(callback)
        HTTP({
            ["url"] = string.format("%s/project/%s/servers/%s", conf.apiEndpoint, conf.projectId, conf.serverId),
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
            ["url"] = string.format("%s/projects/%s/repository/recent_commits", conf.apiEndpoint, conf.projectId),
            ["method"] = "GET",
            ["headers"] = headers,
            ["body"] = "{\"branch\":\"master\"}",
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
                if not lastRevision then
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
                    ["body"] = string.format("{\"parent_identifier\":\"%s\",\"start_revision\":\"%s\",\"end_revision\":\"%s\"}",
                        conf.serverId, curRevision, newRevision),
                    ["success"] = function(statusCode, body)
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
        ["body"] = "{\"signal\": \"restart\"}",
        ["failed"] = function(reason)
            self:sendDiscordAdminMessage("Failed to reboot the server via Pterodactyl API:\n" .. reason)
        end
    })
end

do
    if pcall(function() require("chttp") end) then
        local conf = config.discord
        local function sendRequest(url, message)
            CHTTP({
                url = url,
                body = string.format("{\"username\":\"%s\",\"avatar_url\":\"%s\",\"content\":\"%s\"}",
                    conf.username, conf.avatarUrl, message),
                method = "POST",
                type = "application/json"
            })
        end

        function autoRestart:sendDiscordMessage(message)
            sendRequest(publicWebhook, message)
        end

        function autoRestart:sendDiscordAdminMessage(message)
            sendRequest(adminWebhook, "@everyone " .. message)
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