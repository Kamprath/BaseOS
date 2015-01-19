BaseOS.Commands = {
    help = function(self, ...)
        self:printTable(self.Commands);
    end,
    shutdown = function(self, ...)
        os.shutdown();
    end,
    restart = function(self, ...)
        os.reboot();
    end,
    exit = function(self, ...)
        -- exit prompt mode if active or quit application
        self:stopPrompt();
        term.clear();
        term.setCursorPos(1, 1);
    end,
    update = function(self, ...)
        self:checkUpdate();
    end,
    info = function(self, ...)
        print('Computer label:  ' .. os.getComputerLabel());
        print('Computer ID:     ' .. os.getComputerID());
        print('BaseOS version:  ' .. self.data.version);
        print('Peripherals:     ' .. self.data.peripheralCount);
    end,
    program = function(self, ...)
        local programName, programArgs;
        local arg = arg or {};

        if (table.getn(arg) > 0) then
            programName = arg[1];
            table.remove(arg, 1);
            programArgs = arg;

            if (self.programs[programName] ~= nil) then
                self:stopPrompt();
                self.programs[programName](self, unpack(programArgs));
            else
                print('Unrecognized program.');
            end
        else
            self:cwrite('Usage: ', colors.white);
            write('program <program name> [arguments...]\n');
            self:cprint('\nBaseOS Programs:', colors.white);
            self:printTable(self.programs);
        end
    end,
    startup = function(self, ...)
        local arg = arg or {};
        if (table.getn(arg) >= 1) then
            local action = arg[1];
            if (action == 'add') then
                if (arg[2] ~= nil) then
                    local command = arg[2];
                    table.remove(arg, 2);
                    table.remove(arg, 1);

                    -- add any arguments to the string
                    for key, val in pairs(arg) do
                        if (key ~= 'n') then
                            command = command .. ' ' .. val;
                        end
                    end

                    if (self:addStartup(command)) then
                        print('Startup command added.');
                    end
                else
                    self:cprint('Usage: startup add <command> [arg1, ...]', colors.red);
                end
            elseif (action == 'remove') then
                if (arg[2] ~= nil) then
                    self:removeStartup(arg[2]);
                else
                    self:cprint('Usage: startup remove <key>', colors.red);
                end
            elseif (action == 'list') then
                self:listStartup();
            end
        else
            self:cprint('Usage: startup <add ... | remove <key> | list>', colors.red);
        end
    end,
    clear = function(self, ...)
        term.clear();
        term.setCursorPos(1, 1);
    end
}