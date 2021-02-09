
if PIXEL_DEV_MODE then return end

sam.command.new("cancelrestart")
    :SetCategory("PIXEL AutoRestart")
    :Help("Cancels a forced restart.")
    :SetPermission("cancelrestart", "superadmin")

    :OnExecute(function(caller)
        if not AutoRestart then return end
        AutoRestart.CancelRestart(caller)

        sam.player.send_message(nil, "{A} cancelled the restart.", {A = caller})
    end)
:End()