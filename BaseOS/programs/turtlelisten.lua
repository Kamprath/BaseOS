--[[
-- Turtle Listen listens for and responds to requests from Turtle Control programs
--]]

BaseOS.programs['Turtle Listen'] = function(self, ...)
    self.TurtleListen = {
        data = {
            running = true,
            connected = false,
            computerID = nil,
            direction = 'forward'
        },
        commands = {
            ['back'] = function(self, token, ...)
                turtle.back();
            end,
            ['dig'] = function(self, token, ...)
                if (self.data.direction == 'up') then
                    turtle.digUp();
                elseif (self.data.direction == 'down') then
                    turtle.digDown();
                else
                    turtle.dig();
                end
            end,
            ['down'] = function(self, token, ...)
                turtle.down();
            end,
            ['forward'] = function(self, token, ...)
                turtle.forward();
            end,
            ['left'] = function(self, token, ...)
                turtle.turnLeft();
            end,
            ['right'] = function(self, token, ...)
                turtle.turnRight();
            end,
            ['up'] = function(self, token, ...)
                turtle.up();
            end,
            ['viewinventory'] = function(self, token, ...)
                local data = {
                    success = true,
                    inventory = {},
                    activeSlot = turtle.getSelectedSlot()
                }
                for i=1,16 do
                    local item = turtle.getItemDetail(i);
                    if (item) then
                        data.inventory[item.name] = i;
                    end
                end

                BaseOS.Turtle:request(self.data.computerID, data, false, token);
            end,
            ['selectslot'] = function(self, token, ...)
                turtle.select(arg[1]);
            end,
            ['place'] = function(self, token, ...)
                if (self.data.direction == 'up') then
                    turtle.placeUp();
                elseif (self.data.direction == 'down') then
                    turtle.placeDown();
                else
                    turtle.place();
                end
            end,
            ['drop'] = function(self, token, ...)
                if (self.data.direction == 'up') then
                    turtle.dropUp();
                elseif (self.data.direction == 'down') then
                    turtle.dropDown();
                else
                    turtle.drop();
                end
            end,
            ['setdirection'] = function(self, token, ...)
                if (arg[1] == 'forward' or arg[1] == 'down' or arg[1] == 'up') then
                    self.data.direction = arg[1];
                end
            end
        },

        init = function(self)
            term.clear();
            term.setCursorPos(1, 1);
            print('Waiting for a connection...');
            self:startLoop();
        end,

        startLoop = function(self)
            while (self.data.running) do
                local senderID, message, protocol = rednet.receive('turtle');
                local request = JSON:decode(message);

                self:handleRequest(senderID, request);
            end
        end,

        handleRequest = function(self, senderID, requestData)
            local sendResponse = true;
            local responseData = {};
            local getResponse = false;

            -- handle 'identify' request by returning computer label
            if (requestData.type == 'identify') then
                self:log('Identity requested by computer ' .. senderID);
                responseData.label = os.getComputerLabel();
                responseData.id = os.getComputerID();
                responseData.success = true;

            -- handle 'connect' request
            elseif (requestData.type == 'connect') then
                self:log('Connection accepted from computer ' .. senderID);
                self.data.computerID = senderID;
                self.data.connected = true;
                responseData.success = true;

            -- handle 'command' request
            elseif (requestData.type == 'command') then
                -- ensure that turtle is receiving request from connected computer
                if (self.data.connected and self.data.computerID == senderID) then
                    -- check if command exists
                    if (self.commands[requestData.command] ~= nil) then
                        -- concatenate arguments into string for message output
                        local argsString = '';
                        if (requestData.args ~= nil) then
                            for key, val in pairs(requestData.args) do
                                argsString = argsString .. ' ' .. val;
                            end
                        end
                        self:log(requestData.command .. argsString);

                        local args = requestData.args or {};
                        self.commands[requestData.command](self, requestData.token, unpack(args));
                    else
                        responseData.success = false;
                        responseData.message = 'Unrecognized command.';
                    end
                else
                    sendResponse = false;
                end

            -- handle 'disconnect' request
            elseif (requestData.type == 'disconnect') then
                if (self.data.connected and self.data.computerID == senderID) then
                    self:log('Computer ' .. senderID .. ' disconnected.');
                    print('Waiting for a connection...');
                    self.data.connected = false;
                    responseData.success = true;
                end
            else
                responseData.success = false;
                responseData.message = 'Invalid request type.';
            end

            if (sendResponse) then
                BaseOS.Turtle:request(senderID, responseData, getResponse, requestData.token);
            end
        end,

        log = function(self, message)
            BaseOS:cwrite('[' .. textutils.formatTime(os.time(), true) .. '] ', colors.white);
            BaseOS:cwrite(message .. '\n', colors.yellow);
        end
    };

    self.TurtleListen:init();
end
