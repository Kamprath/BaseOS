BaseOS = {
    -- config data will be loaded from config.lua
    config = {
        rsInputSide = nil,
        rsOutputSide = nil
    },
    data = {
        version = '1.1.2',
        requiredCraftOS = 'CraftOS 1.6',
        baseUrl = 'http://johnny.website',
        versionUrl = 'http://johnny.website/src/version.txt',
        updateUrl = 'http://johnny.website/src/BaseOS/update.lua',
        motd = 'Welcome to BaseOS! BaseOS is a platform that provides a better ComputerCraft experience.\n\nType \'help\' for a list of commands.\nType \'program\' for a list of programs.\n',
        peripheralCount = 0,
        bgColor = colors.black,
        fgColor = colors.lime
    },
    -- Store wrapped peripherals
    peripherals = {
        modem = nil,
        computer = nil,
        turtle = nil,
        drive = nil,
        monitor = nil,
        printer = nil
    },
    programs = {}, -- store programs loaded from programs directory,
    nativePrograms = {},
    startup = {}, -- store startup commands loaded from startup directory

    --- Initialize the application
    init = function(self)
        term.clear();
        if (term.isColor()) then
            term.setBackgroundColor(self.data.bgColor);
            term.setTextColor(self.data.fgColor);
        end

        if (not self:checkSystem()) then
            print('BaseOS is incompatible with this computer.');
            return false;
        end
        self:checkUpdate();
        term.clear();
        term.setCursorPos(1, 2);

        self:getLibraries();
        self:getPrograms();
        self:getPeripherals();
        self:getComponents();
        self:initRednet();
        if (not self:getConfig()) then self:setup(); end

        print('\n' .. self.data.motd);
        self:doStartup();
        self:menu();
    end,

    --- load any components
    getComponents = function(self)
        local files = fs.list('/BaseOS/components');

        for key, val in pairs(files) do
            dofile('/BaseOS/components/' .. val);
        end
    end,

    --- serializes config data to JSON and writes it to config file
    -- @return true
    saveConfig = function(self)
        local json = JSON:encode(self.config);
        local file = fs.open('/BaseOS/config.json', 'w');
        file.write(json);
        file.close();

        return true;
    end,

    --- Load any configuration data from file
    getConfig = function(self)
        if (fs.exists('/BaseOS/config.json')) then
            local file = fs.open('/BaseOS/config.json', 'r');
            local json = file.readAll();
            self.config = JSON:decode(json);

            file.close();
            return true;
        else
            return false;
        end
    end,

    --- Loads all programs in the programs directory
    getPrograms = function(self)
        local files = fs.list('/BaseOS/programs');

        for key, val in pairs(files) do
            dofile('/BaseOS/programs/' .. val);
        end

        -- get CraftOS programs
        local programs = shell.programs();
        for key, val in pairs(programs) do
            -- add function that executes os.run() on the program when called
            self.nativePrograms[val] = function(self, ...)
                shell.run(val, unpack(arg));
            end
        end
    end,

    getLibraries = function(self)
        local files = fs.list('/BaseOS/libraries');

        for key, val in pairs(files) do
            dofile('/BaseOS/libraries/' .. val);
        end
    end,

    --- Detects peripherals and stores their wrappers in the BaseOS.peripherals table
    getPeripherals = function(self)
        local sides = {'top', 'right', 'bottom', 'left', 'back', 'front'};
        local count = 0;

        for key, val in pairs(sides) do
            local pType = peripheral.getType(val);
            if (pType ~= nil) then
                self.peripherals[pType] = peripheral.wrap(val);
                self.peripherals[pType].side = val;
                count = count + 1;
            end
        end

        self.data.peripheralCount = count;
    end,

    --- Prints a string in a specific color
    -- @param str       String to print
    -- @color number    Color value
    cprint = function(self, str, color)
        if (color == nil) then color = self.data.fgColor end
        if (term.isColor()) then term.setTextColor(color); end
        print(str);
        if (term.isColor()) then term.setTextColor(self.data.fgColor); end
    end,

    --- Writes a string in a specific color
    cwrite = function(self, str, color)
        if (color == nil) then color = self.data.fgColor end;
        if (term.isColor()) then term.setTextColor(color); end
        write(str);
        if (term.isColor()) then term.setTextColor(self.data.fgColor); end
    end,

    --- Prompt user for configuration data and save to config.lua
    setup = function(self)
        local label, input;
        term.clear();
        term.setCursorPos(1, 1);
        self:cprint('Computer Setup\n\n', colors.red);

        -- Prompt for computer label
        while (os.getComputerLabel() == nil or label == nil or label == '') do
            self:cprint('Enter a label for this computer (required): ', colors.red);
            label = io.read();

            if (label ~= nil and label ~= '') then
                os.setComputerLabel(label);
            else
                print('Invalid computer label. Please try again.');
            end
        end

        -- Prompt for redstone sides
        print('Enter redstone output side (optional): ');
        input = io.read();
        if (input ~= '') then self.config.rsOutputSide = input end;
        print('Enter redstone input side (optional): ');
        input = io.read();
        if (input ~= '') then self.config.rsInputSide = input end;

        self:saveConfig();

        print('\nSetup is complete! Computer will now restart.');
        os.sleep(2);
        os.reboot();
    end,

    --- Create a menu loop for command input
    menu = function(self)
        local input;
        local exit = false;

        while (exit == false) do
            self:cwrite('[BaseOS]: ', colors.white);
            input = io.read();

            if (self:parseCommand(input) == false) then
                exit = true;
            end
        end
    end,

    --- Parse a string into a command and arguments and call the command
    parseCommand = function(self, input)
        local input = self.split(input, " ");
        local command, args;

        if (type(input) == 'table') then
            command = input[1];
            table.remove(input, 1);
            args = input;
        else
            command = input;
            args = {};
        end

        if (self.Commands[command] ~= nil) then
            return self.Commands[command](self, unpack(args)); -- if a method returns false, it indicates that the menu prompt loop should end
        else
            self:cprint('Unrecognized command.', colors.red);
            return true;
        end
    end,

    --- Parses words from a string into a table
    split = function(str, delim, maxNb)
        -- Eliminate bad cases...
        if string.find(str, delim) == nil then
            return { str }
        end
        if maxNb == nil or maxNb < 1 then
            maxNb = 0    -- No limit
        end
        local result = {}
        local pat = "(.-)" .. delim .. "()"
        local nb = 0
        local lastPos
        for part, pos in string.gmatch(str, pat) do
            nb = nb + 1
            result[nb] = part
            lastPos = pos
            if nb == maxNb then break end
        end
        -- Handle the last field
        if nb ~= maxNb then
            result[nb + 1] = string.sub(str, lastPos)
        end
        return result
    end,

    --- print the keys of a table in a table layout
    printTable = function(self, tbl)
        local keys = {};
        local i = 1;
        for key, val in pairs(tbl) do
            keys[i] = key;
            i = i + 1;
        end
        textutils.pagedTabulate(keys);
    end,

    --- Checks the update server for the latest BaseOS version and initiates the update process if current version doesn't match server's version
    checkUpdate = function(self)
        local rqtVersion = http.get(self.data.versionUrl);

        if (rqtVersion ~= nil) then
            local response = rqtVersion.readAll();
            rqtVersion.close();
            if (self.data.version ~= response) then
                write("A new BaseOS version (" .. response .. ") is available.\n\nUpdate now? (y/n): ");
                if (io.read() == 'y') then
                    self:doUpdate();
                end
            else
                print('BaseOS is up to date (' .. self.data.version .. ').');
            end
        else
            print("Unable to reach update server.");
        end

        return true;
    end,

    --- Checks ComputerCraft version and computer type to determine if application can be run
    -- @return  Returns true if system meets requirements, or false if not
    checkSystem = function(self)
        return (term.isColor() and os.version() == self.data.requiredCraftOS and http);
    end,

    --- Downloads and runs the update.lua script
    doUpdate = function(self)
        local rqtDownload = http.get(self.data.updateUrl);
        local code, file;

        if (rqtDownload ~= nil) then
            -- save update.lua contents to a file
            code = rqtDownload.readAll();
            rqtDownload.close();

            file = fs.open('/BaseOS/update.lua', 'w');
            file.write(code);
            file.close();

            -- run/load the file
            dofile('/BaseOS/update.lua');
            return false;
        else
            print("Unable to reach update server.");
            return true;
        end
    end,

    doStartup = function(self)
        local files = fs.list('/BaseOS/startup');

        -- iterate over files from 'startup' directory. For each:
        for key, val in pairs(files) do
            -- add an element to the 'startup' table using the file name as the key and the file's contents as the value
            local file = fs.open('/BaseOS/startup/' .. val, 'r');
            local contents = file.readAll();
            file.close();

            self.startup[val] = contents;
        end

        -- iterate through 'startup' table
        for key, val in pairs(self.startup) do
            -- pass command string to self:parseCommand(command);
            self:parseCommand(val);
        end
    end,

    addStartup = function(self, command)
        local filename = math.random(999999);
        local file = fs.open('/BaseOS/startup/' .. filename, 'w');
        local success = (file ~= nil);

        if (success) then
            file.write(command);
            file.close();
            self.startup[filename] = command;
        else
            self:cprint('[Error] Failed to write to \'/BaseOS/startup/' .. filename .. '\'.', colors.red);
        end

        return success;
    end,

    removeStartup = function(self, key)
        local path = '/BaseOS/startup/' .. key;

        if (self.startup[key] ~= nil and fs.exists(path)) then
            fs.delete(path);
            if(not fs.exists(path)) then
                print('Removed startup command \'' .. self.startup[key] .. '\'.');
                self.startup[key] = nil;
            else
                self:cprint('[Error] Failed to delete \'' .. path .. '\'.');
                return false;
            end
        else
            self:cprint('No startup command with key ' .. key .. ' exists.', colors.red);
            return false;
        end
    end,

    listStartup = function(self)
        local count = 0;
        -- iterate over 'startup' table
        for key, val in pairs(self.startup) do
            -- output file name and task
            self:cwrite(key, colors.white);
            write(': ' .. val .. '\n');
            count = count + 1;
        end

        if (count == 0) then
            print('No startup commands have been set.');
        end
    end,

    --- Gets the size of a table
    tableSize = function(self, tbl)
        local count = 0;
        for key, val in pairs(tbl) do
            count = count + 1;
        end
        return count;
    end,

    --- Returns the resulting JSON from a request as a table
    getJSON = function(self, url)
        local request = http.get(url);
        local response = request.readAll();

        if (request ~= nil) then
            local response = request.readAll();
            request.close();
            return JSON:decode(response);
        else
            return false;
        end
    end,

    initRednet = function(self)
        if (self.peripherals.modem ~= nil) then
            rednet.open(self.peripherals.modem.side);
            return true;
        else
            return false;
        end
    end,
};