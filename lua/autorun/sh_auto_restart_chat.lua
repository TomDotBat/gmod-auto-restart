
--[[
       Copyright 2021 Thomas (Tom.bat) O'Sullivan

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
]]

AddCSLuaFile()

if CLIENT then
    local chatTagCol = Color(49, 137, 238)
    local chatMessageCol = Color(255, 255, 255)

    net.Receive("AutoRestart.ChatMessage", function()
        chat.AddText(chatTagCol, "[AutoRestart] ", chatMessageCol, net.ReadString())
        chat.PlaySound()
    end)
else
    util.AddNetworkString("AutoRestart.ChatMessage")
    local function broadcastMessage(msg)
        net.Start("AutoRestart.ChatMessage")
         net.WriteString(msg)
        net.Broadcast()
    end

    local floor, format = math.floor, string.format
    local function formatTime(val)
        local tmp = val
        local s = tmp % 60
        tmp = floor(tmp / 60)
        local m = tmp % 60
        tmp = floor(tmp / 60)
        local h = tmp % 24
        tmp = floor(tmp / 24)
        local d = tmp % 7
        local w = floor(tmp / 7)

        if w ~= 0 then
            return format("%02i weeks, %i days, %02i hours, %02i minutes and %02i seconds", w, d, h, m, s)
        elseif d ~= 0 then
            return format("%i days, %02i hours, %02i minutes and %02i seconds", d, h, m, s)
        elseif h ~= 0 then
            if m == 0 and s == 0 then return format("%02i hours", h)
            elseif s == 0 then return format("%02i hours and %02i minutes", h, m)
            else return format("%02i hours, %02i minutes and %02i seconds", h, m, s) end
        elseif m ~= 0 then
            if s == 0 then return format("%02i minutes", m)
            else return format("%02i minutes and %02i seconds", m, s) end
        end

        return format("%02i seconds", s)
    end

    hook.Add("AutoRestart.WaitingForPlayersStarted", "AutoRestart.AlertRestartTime", function(timeLeft)
        broadcastMessage(string.format("A restart will automatically run in %s from now, or once everyone has left.",
            formatTime(timeLeft)))
    end)


    hook.Add("AutoRestart.ForcefulRestartScheduled", "AutoRestart.AlertRestartScheduled", function(deployTime, restartTime)
        broadcastMessage(string.format("A restart has been scheduled for %s from now, an auto-deploy will run in %s.",
            formatTime(restartTime), formatTime(deployTime)))
    end)

    hook.Add("AutoRestart.ForcefulRestartUnscheduled", "AutoRestart.AlertRestartUnscheduled", function()
        broadcastMessage("The restart was unscheduled due to a deployment problem, the owner has been contacted automatically.")
    end)

    hook.Add("AutoRestart.ForcefulDeployStarted", "AutoRestart.AlertDeployStarted", function()
        broadcastMessage("The auto-deploy request was sent, expect to see server lag and errors.")
    end)

    hook.Add("AutoRestart.ForcefulDeployComplete", "AutoRestart.AlertDeployComplete", function()
        broadcastMessage("The auto-deploy completed successfully, the server will restart soon.")
    end)

    hook.Add("AutoRestart.ForcefulRestartDelayed", "AutoRestart.AlertRestartDelayed", function()
        broadcastMessage("The restart was delayed by the deployment system.")
    end)

    hook.Add("AutoRestart.ForcefulRestartStarted", "AutoRestart.AlertRestartStarted", function()
        broadcastMessage("The restart request was sent, the server will be back online shortly.")
    end)
end