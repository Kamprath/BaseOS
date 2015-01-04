BaseOS = {
    config = {

    },
    data = {
        version = '1.2.1',
        requiredCraftOS = 'CraftOS 1.6',
        baseUrl = 'http://johnny.website',
        versionUrl = 'http://johnny.website/src/version.txt',
        updateUrl = 'http://johnny.website/src/BaseOS/update.lua',
        motd = 'Welcome to BaseOS! BaseOS is a platform that provides a better ComputerCraft experience.\n\nType \'help\' for a list of commands.\nType \'program\' for a list of programs.\n',
        peripheralCount = 0,
        running = true,
        promptMode = false,
        term = {
            bgColor = colors.black,
            fgColor = colors.lime,
            width = nil,
            height = nil
        },
        menu = {
            selection = 1,
            key = 'BaseOS',
            message = '',
            columnSize = nil,
            history = {}
        },
        keys = {
            up = 200,
            down = 208,
            enter = 28,
            space = 57,
            ctrl = 29,
            alt = 56,
            tab = 15,
            w = 17,
            a = 30,
            s = 31,
            d = 32,
            f = 33,
            e = 18,
            q = 16
        },
        window = {
            width = nil,
            height = nil
        }
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
    -- store programs loaded from programs directory
    programs = {},
    -- store CraftOS programs
    nativePrograms = {},
    -- store startup commands loaded from startup directory
    startup = {},

    --- Initialize the application
    init = function(self)
        term.clear();
        self.data.window.width, self.data.window.height = term.getSize();
        self.data.menu.columnSize = self.data.window.width / 2;

        if (not self:checkSystem()) then
            print('BaseOS is incompatible with this computer.');
            return false;
        end
        term.setBackgroundColor(self.data.term.bgColor);
        term.setTextColor(self.data.term.fgColor);
        self:checkUpdate();

        term.clear();
        term.setCursorPos(1, 2);

        self:getLibraries();
        self:getPrograms();
        self:getPeripherals();
        self:getComponents();
        self:initRednet();
        if (not self:getConfig()) then self:setup(); end

        self:doStartup();
        self:startLoop();
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
        if (color == nil) then color = self.data.term.fgColor end
        if (term.isColor()) then term.setTextColor(color); end
        print(str);
        if (term.isColor()) then term.setTextColor(self.data.term.fgColor); end
    end,

    --- Writes a string in a specific color
    cwrite = function(self, str, color)
        if (color == nil) then color = self.data.term.fgColor end;
        if (term.isColor()) then term.setTextColor(color); end
        write(str);
        if (term.isColor()) then term.setTextColor(self.data.term.fgColor); end
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
    startLoop = function(self)
        while (self.data.running) do
            self:drawInterface();
            self:handleEvent(os.pullEvent('key'));
        end
    end,

    drawInterface = function(self)
        term.clear();
        self:drawHeader();
        self:drawMenu();
        self:drawMessage();
    end,

    drawHeader = function(self)
        term.setCursorPos(1, 1);
        term.setBackgroundColor(colors.white);

        for i=1, self.data.window.width do
            write(' ');
        end

        term.setCursorPos(3, 1);
        self:cwrite(self.data.menu.key, colors.black);

        term.setBackgroundColor(self.data.term.bgColor);
    end,

    drawMessage = function(self)
        term.setCursorPos(3, self.data.window.height - 1);
        self:cwrite(self.data.menu.message, colors.white);
    end,

    drawMenu = function(self)
        local menu = self.Menus[self.data.menu.key];
        local menuSize = self:tableSize(menu);
        local yStart = 3;

        -- insert 'back'/'exit' menu option
        if (menu[menuSize].name ~= 'Exit' and menu[menuSize].name ~= 'Back') then
            menu[menuSize+1] = {};
            if (#self.data.menu.history > 0) then
                menu[menuSize+1].name = 'Back';
            else
                menu[menuSize+1].name = 'Exit';
            end
            menu[menuSize+1].action = self.previousMenu;
            menuSize = menuSize + 1;
        end

        --[[if ((menuSize * 2) < self.data.window.height) then
            yStart = math.floor((self.data.window.height - (menuSize * 2)) / 2);
        else
            yStart = 1;
        end]]

        term.setCursorPos(1, yStart);

        local column = 0;
        local columns = math.floor(self.data.window.width / self.data.menu.columnSize);
        local i = 1;
        for key, option in ipairs(menu) do
            local x, y = term.getCursorPos();
            if (column < columns) then
                -- if end of terminal has been reached, move to a new column
                if (y >= self.data.window.height) then
                    if ((column + 1) < columns) then
                        column = column + 1;
                        y = yStart;
                    else
                        break;
                    end
                end

                if (column > 0) then
                    x = column * self.data.menu.columnSize;
                end

                term.setCursorPos(x, y);

                -- prefix active menu choice
                if (key == self.data.menu.selection) then
                    self:cwrite(' > ', colors.white);
                else
                    write('   ');
                end

                write(option.name .. '\n\n');
                i = i + 1;
            end
        end
    end,
    useMenu = function(self, key, setHistory)
        if (setHistory == nil) then setHistory = true; end

        if (setHistory) then
            table.insert(self.data.menu.history, self.data.menu.key);
        end

        self.data.menu.key = key;
        self.data.menu.selection = 1;
    end,
    previousMenu = function(self)
        local historySize = #self.data.menu.history;
        local key = self.data.menu.history[historySize];

        if (historySize> 0) then
            table.remove(self.data.menu.history, historySize)
            self:useMenu(key, false);
        else
            term.clear();
            term.setCursorPos(1, 1);
            self.data.running = false;
        end
    end,

    --- Sets a menu message to display on next redraw
    setMessage = function(self, message)
        self.data.menu.message = message;
    end,

    handleEvent = function(self, ...)
        -- remove first argument from arguments table
        local eventType = table.remove(arg, 1);

        if (eventType == 'key') then
            local key = arg[1];
            local menu = self.Menus[self.data.menu.key];
            local selection = self.data.menu.selection;
            local menuSize = self:tableSize(menu);

            -- Move menu selection up
            if ((key == self.data.keys.up or key == self.data.keys.w) and (selection - 1) >= 1) then
                self.data.menu.selection = selection - 1;

            -- Move menu selection down
            elseif ((key == self.data.keys.down or key == self.data.keys.s) and (selection + 1) <= menuSize) then
                self.data.menu.selection = selection + 1;

            -- Choose current menu selection
            elseif (key == self.data.keys.enter or key == self.data.keys.space or key == self.data.keys.e) then
                self.data.menu.message = '';
                menu[self.data.menu.selection].action(self);
            end
        end
    end,

    prompt = function(self)
        term.clear();
        term.setCursorPos(1, 1);
        print('\n' .. self.data.motd);

        while (self.data.promptMode) do
            self:cwrite('[BaseOS]: ', colors.white);
            input = io.read();

            self:parseCommand(input);
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
            self.Commands[command](self, unpack(args));
        else
            self:cprint('Unrecognized command.', colors.red);
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

    --- Stores a new BaseOS menu
    -- @param context       The object/namespace from which the menu originated
    -- @param menuTitle     The title/key of the menu
    -- @param menuOptions   A table representing menu options.
    --                      Tables should maintain the BaseOS menu format of:
    --                      {[1] = {name='Option name', action=function(self) ... end, [2] = ...}
    addMenu = function(self, menuTitle, menuOptions)
        self.Menus[menuTitle] = menuOptions;
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

        if (tbl ~= nil) then
            for key, val in pairs(tbl) do
                count = count + 1;
            end
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
    end
};