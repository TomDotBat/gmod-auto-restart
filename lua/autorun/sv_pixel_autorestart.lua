
local config = {
    deployHq = {

    },
    pterodactyl = {
        apiKey = "***REMOVED***",
        apiEndpoint = "***REMOVED***",
        serverId = "27c2b5b6" --"1a7ce997"
    },
    discord = {
        publicWebhook = "",
        adminWebhook = "",
        username = "PIXEL Auto-Restart",
        avatarUrl = nil
    }
}

local autoRestart = {}

do
    function autoRestart:sendDeployRequest()
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
            sendRequest(adminWebhook, message)
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