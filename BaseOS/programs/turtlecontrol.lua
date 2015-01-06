--[[
-- Turtle Control allows control of turtles running TurtleListen
--]]

BaseOS.programs['Turtle Control'] = function(self, ...)
    self.TurtleControl = {
        data = {
            connected = false,
            turtleID = nil
        },

        -- menu actions will be called in the context of BaseOS
        menus = {
            ['main'] = {
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
                },
                [3] = {
                    name = 'Choose Interaction Side',
                    action = function(self)
                        self.TurtleControl:chooseDirection();
                    end
                },
                [4] = {
                    name = 'Disconnect',
                    exit = true,
                    action = function(self)
                        self.TurtleControl:disconnect();
                        BaseOS:previousMenu();
                    end
                }
            },
            ['Choose Interaction Side'] = {
                [1] = {
                    name = 'Up',
                    action = function(self)
                        self.TurtleControl:setDirection('up');
                    end
                },
                [2] = {
                    name = 'Forward',
                    action = function(self)
                        self.TurtleControl:setDirection('forward');
                    end
                },
                [3] = {
                    name = 'Down',
                    action = function(self)
                        self.TurtleControl:setDirection('down');
                    end
                },
                [4] = {
                    name = 'Cancel',
                    exit = true,
                    action = function(self)
                        BaseOS:previousMenu();
                    end
                }
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

        --- Initializes the application
        init = function(self)
            -- establish a connection to the turtle
            self:chooseTurtle();
        end,

        --- Prompts for selection of a turtle to connect to.
        chooseTurtle = function(self)
            -- broadcast identify command
            local responses = BaseOS.Turtle:broadcast({type='identify'});
            local menu = {};

            if (responses ~= nil) then
                -- iterate through responses
                local i = 1;
                for key, response in pairs(responses) do
                    -- create menu of turtle labels. Each menu option's action
                    menu[i] = {};
                    menu[i].name = response.label;
                    menu[i].action = function(self)
                        self.TurtleControl:connect(response.id);
                    end
                    i = i + 1;
                end

                BaseOS:addMenu('Select a Turtle', menu);
                BaseOS:useMenu('Select a Turtle');
            else
                -- set message
                BaseOS:setMessage('No turtles available.');
            end
        end,

        connect = function(self, turtleID)
            local response = BaseOS.Turtle:request(turtleID, {type='connect'});
            if (not response == false) then
                if (response.success == true) then
                    self.data.turtleID = turtleID;
                    self.data.connected = true;
                    BaseOS:setMessage('');

                    local turtle = BaseOS.Turtle:request(turtleID, {type='identify'});
                    local title = turtle.label;
                    BaseOS:addMenu(title, self.menus['main']);
                    BaseOS:useMenu(title);
                else
                    BaseOS:setMessage('Turtle refused connection.');
                end
            else
                BaseOS:setMessage('Turtle not found.');
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
            print('W, A, S, D - move\nSpace - up\nCtrl - down\nE - dig\nQ - place item\nF - drop items\nTab - exit');

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

        --- Populates a menu with inventory data from turtle
        viewInventory = function(self)
            -- send command, get response data
            local data = BaseOS.Turtle:request(self.data.turtleID, {type='command',command='viewinventory'});

            if (data.inventory ~= nil and BaseOS:tableSize(data.inventory) > 0) then
                -- convert response data into menu
                local menu = {};
                local i = 1;
                for key, val in pairs(data.inventory) do
                    local slot = data.inventory[key];

                    -- remove prefix from item name
                    local startPos, endPos = key:find(':');
                    key = key:sub(endPos+1);

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

        --- Activates a menu for selecting the interaction side
        chooseDirection = function(self)
            local menuTitle = 'Choose Interaction Side';
            BaseOS:addMenu(menuTitle, self.menus[menuTitle]);
            BaseOS:useMenu(menuTitle);
        end,

        --- Commands the turtle to use a specific side for interaction
        setDirection = function(self, direction)
            local data = {type='command',command='setdirection',args={direction}};
            BaseOS.Turtle:request(self.data.turtleID, data, false);
            BaseOS:previousMenu();
            BaseOS:setMessage('Set turtle interaction side to ' .. direction);
        end,

        --- Commands the turtle to place an item
        placeItem = function(self)
            BaseOS.Turtle:request(self.data.turtleID, {type='command',command='place'}, false);
        end,

        --- Sends a disconnect message to the turtle and exits
        disconnect = function(self)
            -- send disconnect message to turtle
            BaseOS.Turtle:request(self.data.turtleID, {type='disconnect'}, false);

            self.data.connected = false;
            BaseOS:previousMenu();
        end
    }

    self.TurtleControl:init();
end