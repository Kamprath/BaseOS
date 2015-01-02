--[[
-- TurtleControl allows control of turtles running TurtleListen
--]]

BaseOS.programs['TControl'] = function(self, ...)

    local TurtleControl = {
        data = {
            connected = false,
            window = {width = nil, height = nil},       -- window information
            turtleID = nil,                             -- ID of the currently-connected turtle
            selection = 1,                              -- Current menu selection,
            activeMenuKey = nil,                        -- The array key of an object in the 'menus' table
            message = ''
        },

        menus = {
            ['main'] = {
                ['Control turtle'] = function(self)
                    self:controlTurtle();
                end,
                ['Select Inventory Item'] = function(self)
                    self:viewInventory();
                end,
                ['Disconnect'] = function(self)
                    self:disconnect();
                end
            }
        },

        --- Sends a command request to the connected turtle
        -- @param command       The command name
        -- @param args          (Optional) An array of command arguments
        -- @param getResponse   (Optional) If true, the method will wait for a response message
        command = function(self, command, args, getResponse)
            args = args or {};
            getResponse = getResponse or false;
            local data = {
                type = 'command',
                command = command
            };
            if (#args > 0) then
                data.args = args;
            end

            local responseData = BaseOS.Turtle:request(self.data.turtleID, data, getResponse);

            if (responseData ~= nil and responseData ~= false) then
                if (responseData.message ~= nil) then
                    self.data.message = responseData.message;
                end

            end
        end,

        init = function(self)
            self.data.window.width, self.data.window.height = term.getSize();

            term.clear();
            term.setCursorPos(1, 1);

            while (not self.data.connected) do
                -- establish a connection to the turtle
                BaseOS:cwrite('Specify turtle ID to connect to: ', colors.white);
                self.data.turtleID = io.read();

                if (self.data.turtleID ~= '') then
                    self.data.turtleID = tonumber(self.data.turtleID);
                else
                    break;
                end

                local response = BaseOS.Turtle:request(self.data.turtleID, {type='connect'});
                if (not response == false) then
                    if (response.success == true) then
                        self.data.activeMenuKey = 'main';
                        self.data.connected = true;
                    else
                        BaseOS:cprint('Turtle refused connection.', colors.red);
                    end
                else
                    BaseOS:cprint('Turtle not found.', colors.red);
                end
            end

            self:startLoop();
        end,

        --- Main loop to run the program
        startLoop = function(self)
            while (self.data.connected) do
                -- draw the interface
                self:drawInterface();

                -- wait for event
                self:handleEvent(os.pullEvent('key'));
            end
        end,

        --- Calls methods that correspond to certain event types
        handleEvent = function(self, ...)
            -- remove first argument from arguments table
            local eventType = table.remove(arg, 1);

            if (eventType == 'key') then
                local key = arg[1];
                local selection = self.data.selection;
                local menuSize = BaseOS:tableSize(self.menus[self.data.activeMenuKey]);

                if ((key == BaseOS.data.keys.up or key == BaseOS.data.keys.w) and (selection - 1) >= 1) then
                    self.data.selection = selection - 1;
                elseif ((key == BaseOS.data.keys.down or key == BaseOS.data.keys.s) and (selection + 1) <= menuSize) then
                    self.data.selection = selection + 1;
                elseif (key == BaseOS.data.keys.enter or key == BaseOS.data.keys.space or key == BaseOS.data.keys.e) then
                    self:doMenuAction(self.menus[self.data.activeMenuKey], self.data.selection);
                end
            end
        end,

        doMenuAction = function(self, menu, optionNum)
            self.data.message = '';
            local i = 1;
            for key, val in pairs(menu) do
                if (optionNum == i) then
                    val(self);
                    return true;
                end

                i = i + 1;
            end
            return false;
        end,

        --- Draws a menu to the terminal
        drawMenu = function(self, menu, selection)
            local menuSize = BaseOS:tableSize(menu);
            term.setCursorPos(1, math.floor((self.data.window.height - (menuSize * 2)) / 2));

            local i = 1;
            for key, val in pairs(menu) do
                -- prefix active menu choice
                if (i == selection) then
                    BaseOS:cwrite(' >  ', colors.white);
                else
                    write('    ');
                end

                i = i + 1;
                write(key .. '\n\n');
            end
        end,

        --- Calls methods that draw things to the terminal
        drawInterface = function(self)
            term.clear();

            -- draw self.data.activeMenu as menu
            self:drawMenu(self.menus[self.data.activeMenuKey], self.data.selection);

            -- write message (if any) to bottom of screen
            term.setCursorPos(1, self.data.window.height - 1);
            BaseOS:cprint(self.data.message, colors.white);
        end,

        -- Menu functions

        --- Listens for key press events and sends corresponding commands to turtle
        controlTurtle = function(self)
            -- bindings[<key code>] = <command name>
            local bindings = {
                [BaseOS.data.keys.w] = 'forward',
                [BaseOS.data.keys.s] = 'back',
                [BaseOS.data.keys.a] = 'left',
                [BaseOS.data.keys.d] = 'right',
                [BaseOS.data.keys.ctrl] = 'down',
                [BaseOS.data.keys.space] = 'up',
                [BaseOS.data.keys.e] = 'dig',
                [BaseOS.data.keys.f] = 'drop'
            };

            term.clear();
            term.setCursorPos(1, 1);
            print('Use W, A, S, D, Space, and Ctrl to move around.\n\nPress E to dig and Q to place an item from the turtle\'s current slot.\nPress F to drop an item from the current slot.\n\nPress Tab to exit direct control mode.');

            while (true) do
                local e, key = os.pullEvent('key');

                if (bindings[key] ~= nil) then
                    self:command(bindings[key]);
                elseif (key == BaseOS.data.keys.q) then
                    self:placeItem();
                elseif (key == BaseOS.data.keys.tab) then
                    break;
                end
            end
        end,

        viewInventory = function(self)
            -- send viewinventory command, turtle should respond with data
            local data = BaseOS.Turtle:request(self.data.turtleID, {type='command',command='viewinventory'});

            if (data.inventory ~= nil and data.activeSlot ~= nil) then
                self.menus['inventory'] = data.inventory;
                self.data.activeMenuKey = 'inventory';

                for key, val in pairs(self.menus['inventory']) do
                    -- initially, the array key points to the slot number of the inventory item
                    local slot = self.menus['inventory'][key];
                    -- the array key is then reassigned a closure that will execute when the menu choice is selected
                    self.menus['inventory'][key] = function(self)
                        BaseOS.Turtle:request(self.data.turtleID, {type='command',command='selectslot',args={slot}, false});
                        self.data.activeMenuKey = 'main';
                        self.data.message = 'Set active turtle slot to item \'' .. key .. '\'';
                    end
                end
            end
        end,

        placeItem = function(self)
            BaseOS.Turtle:request(self.data.turtleID, {type='command',command='place'}, false);
        end,

        disconnect = function(self)
            term.clear();
            term.setCursorPos(1, 1);
            self.data.connected = false;

            -- send disconnect message to turtle
            BaseOS.Turtle:request(self.data.turtleID, {type='disconnect'}, false);
        end
    }

    -- start the program
    TurtleControl:init();
end