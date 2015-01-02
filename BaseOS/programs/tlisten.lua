--[[
-- TurtleListen listens for and responds to requests from TurtleControl programs
--]]

BaseOS.programs['TListen'] = function(self, ...)
    local TurtleListen = {
        data = {
            running = true,
            connected = false,
            computerID = nil
        },
        commands = {
            ['back'] = function(self, token, ...)
                turtle.back();
            end,
            ['dig'] = function(self, token, ...)
                turtle.dig();
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
                turtle.place();
            end,
            ['drop'] = function(self, token, ...)
                turtle.drop();
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
 --
    TurtleListen:init();
end
