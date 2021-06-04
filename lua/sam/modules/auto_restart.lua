
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

sam.command.new("cancelrestart")
    :SetCategory("PIXEL AutoRestart")
    :Help("Cancels a forced restart.")
    :SetPermission("cancelrestart", "superadmin")

    :OnExecute(function(caller)
        if not AutoRestart then return end
        AutoRestart.CancelRestart(caller)
        timer.Remove("PIXEL.AutoRestart.RebootTimer")
        timer.Remove("PIXEL.AutoRestart.ChatTimer")

        sam.player.send_message(nil, "{A} cancelled the restart.", {A = caller})
    end)
:End()

sam.command.new("restart")
    :SetCategory("PIXEL AutoRestart")
    :Help("Start a restart")
    :SetPermission("restart", "superadmin")

    :OnExecute(function(caller)
        if not AutoRestart then return end
        AutoRestart.StartRestart(caller)

        sam.player.send_message(nil, "{A} started a restart.", {A = caller})
    end)
:End()

sam.command.new("queuerestart")
    :SetCategory("PIXEL AutoRestart")
    :Help("Start a restart after the provided minutes")
    :SetPermission("restart", "superadmin")
    :AddArg("length", {optional = false, default = 5})

    :OnExecute(function(caller, length)
        if not AutoRestart then return end
        local timeUntilRestart = length * 60

        timer.Create("PIXEL.AutoRestart.RebootTimer", timeUntilRestart, 1, function()
            AutoRestart.StartRestart(caller)
        end)

        local timeLeft = length
        timer.Create("PIXEL.AutoRestart.ChatTimer", 60, length, function()
            timeLeft = timeLeft - 1
            for _, ply in ipairs(player.GetAll()) do
                ply:ChatPrint("The server will be restarting in " .. timeLeft .. " minutes")
            end
        end)

        for _, ply in ipairs(player.GetAll()) do
            ply:ChatPrint("The server will be restarting in " .. length .. " minutes")
        end

        sam.player.send_message(nil, "{A} started a restart for " .. length .. " minutes from now.", {A = caller})
    end)
:End()