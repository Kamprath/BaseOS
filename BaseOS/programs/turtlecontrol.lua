--[[
-- Turtle Control allows control of turtles running TurtleListen
--]]

BaseOS.programs['Turtle Control'] = function(self, ...)
    self.TurtleControl = {
        data = {
            connected = false,
            turtleID = nil                             -- ID of the currently-connected turtle
        },

        -- menu actions will be called in the context of BaseOS
        menu = {
            [1] = {
                name = 'Control turtle',
                action = function(self)
                    self.TurtleControl:controlTurtle();
                end
            },
            [2] = {
                name = 'Select Inventory Item',
                action = function(self)
                    self.TurtleControl:viewInventory();
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
            -- establish a connection to the turtle
            BaseOS:cwrite('Specify turtle ID to connect to: ', colors.white);
            self.data.turtleID = io.read();

            if (self.data.turtleID ~= '' and tonumber(self.data.turtleID)) then
                self.data.turtleID = tonumber(self.data.turtleID);

                local response = BaseOS.Turtle:request(self.data.turtleID, {type='connect'});
                if (not response == false) then
                    if (response.success == true) then
                        self.data.connected = true;
                        BaseOS:setMessage('');
                        BaseOS:addMenu('Turtle Control', self.menu);
                        BaseOS:useMenu('Turtle Control');
                    else
                        BaseOS:setMessage('Turtle refused connection.');
                    end
                else
                    BaseOS:setMessage('Turtle not found.');
                end
            end
        end,

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
            -- send command, get response data
            local data = BaseOS.Turtle:request(self.data.turtleID, {type='command',command='viewinventory'});

            if (data.inventory ~= nil and BaseOS:tableSize(data.inventory) > 0) then
                -- convert response data into menu
                local menu = {};
                local i = 1;
                for key, val in pairs(data.inventory) do
                    local slot = data.inventory[key];
                    menu[i] = {};
                    menu[i].name = key;
                    menu[i].action = function(self)
                        BaseOS.Turtle:request(self.TurtleControl.data.turtleID, {type='command',command='selectslot',args={slot}, false});
                        BaseOS:previousMenu();
                        BaseOS:setMessage('Set active turtle slot to item \'' .. key .. '\'');
                    end
                    i = i + 1;
                end
                BaseOS:addMenu('Turtle Inventory', menu);
                BaseOS:useMenu('Turtle Inventory');
            else
                BaseOS:setMessage('Turtle inventory is empty.');
            end
        end,

        placeItem = function(self)
            BaseOS.Turtle:request(self.data.turtleID, {type='command',command='place'}, false);
        end,

        disconnect = function(self)
            -- send disconnect message to turtle
            BaseOS.Turtle:request(self.data.turtleID, {type='disconnect'}, false);

            self.data.connected = false;
            BaseOS:previousMenu();
        end
    }

    -- start the program
    self.TurtleControl:init();
end