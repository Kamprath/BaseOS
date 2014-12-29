--[[
-- TurtleControl provides an interface for remotely controlling a turtle
--
-- Requirements:
--   * Turtle component
--   * BaseOS v1.1 or newer
--]]

-- register program with BaseOS
BaseOS.programs['TControl'] = function(self, ...)
    -- define the program
    local TurtleControl = {
        data = {
            running = true,
            window = {width = nil, height = nil},       -- window information
            keys = {                                    -- key codes
                up = 200,
                down = 208,
                enter = 28,
                space = 57,
                ctrl = 29,
                alt = 56,
                w = 17,
                a = 30,
                s = 31,
                d = 32
            },
            turtleID = nil,                             -- ID of the currently-connected turtle
            selection = 1,                              -- Current menu selection,
            activeMenuKey = nil                         -- The array key of an object in the 'menus' table
        },
        menus = {
            ['main'] = {
                ['Enter direct control mode'] = function(self)
                    term.clear();
                    term.setCursorPos(1, 1);
                    print('Use W, A, S, D, Space, and Ctrl to move around.\n\nPress Enter to dig.\n\nPress Alt to exit direct control mode.');

                    while (true) do
                        local e, key = os.pullEvent('key');

                        if (key == self.data.keys.w) then
                            self.commands['forward'](self);
                        elseif (key == self.data.keys.s) then
                            self.commands['back'](self);
                        elseif (key == self.data.keys.a) then
                            self.commands['left'](self);
                        elseif (key == self.data.keys.d) then
                            self.commands['right'](self);
                        elseif (key == self.data.keys.ctrl) then
                            self.commands['down'](self);
                        elseif (key == self.data.keys.space) then
                            self.commands['up'](self);
                        elseif (key == self.data.keys.enter) then
                            self.commands['dig'](self);
                        elseif (key == self.data.keys.alt) then
                            break;
                        end
                    end
                end,
                ['Dump inventory'] = function(self)
                    BaseOS.Turtle:request(self.data.turtleID, {type='command',command='dump'}, false);
                end,
                ['Get fuel level'] = function(self)

                end,
                ['Exit'] = function(self)
                    term.clear();
                    term.setCursorPos(1, 1);
                    self.data.running = false;
                end
            }
        },
        commands = {
            ['forward'] = function(self)
                BaseOS.Turtle:request(self.data.turtleID, {['type']='command',['command']='forward'}, false);
            end,
            ['right'] = function(self)
                BaseOS.Turtle:request(self.data.turtleID, {['type']='command',['command']='right'}, false);
            end,
            ['back'] = function(self)
                BaseOS.Turtle:request(self.data.turtleID, {['type']='command',['command']='back'}, false);
            end,
            ['left'] = function(self)
                BaseOS.Turtle:request(self.data.turtleID, {['type']='command',['command']='left'}, false);
            end,
            ['up'] = function(self)
                BaseOS.Turtle:request(self.data.turtleID, {['type']='command',['command']='up'}, false);
            end,
            ['down'] = function(self)
                BaseOS.Turtle:request(self.data.turtleID, {['type']='command',['command']='down'}, false);
            end,
            ['dig'] = function(self)
                BaseOS.Turtle:request(self.data.turtleID, {['type']='command',['command']='dig'}, false)
            end
        },

        init = function(self)
            self.data.window.width, self.data.window.height = term.getSize();

            -- establish a connection to the turtle
            BaseOS:cwrite('Specify turtle ID to connect to: ', colors.white);
            self.data.turtleID = tonumber(io.read());
            -- todo: send 'connect' message to turtle

            -- set the menu that should be displayed. This should change based on what you want this program to do
            self.data.activeMenuKey = 'main';

            -- run the event-listening loop
            self:startLoop();
        end,

        --- Main loop to run the program
        startLoop = function(self)
            while (self.data.running) do
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

                if ((key == self.data.keys.up or key == self.data.keys.w) and (selection - 1) >= 1) then
                    self.data.selection = selection - 1;
                elseif ((key == self.data.keys.down or key == self.data.keys.s) and (selection + 1) <= menuSize) then
                    self.data.selection = selection + 1;
                elseif (key == self.data.keys.enter) then
                    self:doMenuAction(self.menus[self.data.activeMenuKey], self.data.selection);
                end
            end
        end,

        doMenuAction = function(self, menu, optionNum)
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

        -- draws a menu to the terminal
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
        end
    }

    -- start the program
    TurtleControl:init();
end