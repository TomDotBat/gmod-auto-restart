
if PIXEL_DEV_MODE then return end

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