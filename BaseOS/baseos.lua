BaseOS = {
	-- config data will be loaded from config.lua
	config = {
		rsInputSide = nil,
		rsOutputSide = nil
	},
	data = {
		version = '1.0.2',
		baseUrl = 'http://johnny.website',
		versionUrl = 'http://johnny.website/BaseOS/version.txt',
		updateUrl = 'http://johnny.website/BaseOS/update.lua',
		motd = 'Welcome to BaseOS! BaseOS is a platform that provides a better ComputerCraft experience.\n\nType \'help\' for a list of commands.\nType \'program\' for a list of programs.',
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

	init = function(self)
		term.clear();
		term.setBackgroundColor(self.data.bgColor);
		term.setTextColor(self.data.fgColor);

		self:checkUpdate();
		term.clear();
		term.setCursorPos(1, 2);

		self:getLibraries();
		self:getPrograms();
		self:getPeripherals();

		if (not self:getConfig()) then
			self:setup();
		end

		print('\n' .. self.data.motd);

		self:menu();		
	end,

	-- serializes config data to JSON and writes it to config file
	saveConfig = function(self)
		local json = JSON:encode(self.config);
		local file = fs.open('/BaseOS/config.json', 'w');
		file.write(json);
		file.close();

		return true;
	end,

	-- Load any configuration data from file
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

	-- Loads all programs in the programs directory
	getPrograms = function(self)
		local files = fs.list('/BaseOS/programs');

		for key, val in pairs(files) do
			dofile('/BaseOS/programs/' .. val);
		end
	end,

	getLibraries = function(self)
		local files = fs.list('/BaseOS/libraries');

		for key, val in pairs(files) do
			dofile('/BaseOS/libraries/' .. val);
		end
	end,

	-- Detects peripherals
	getPeripherals = function(self)
		local sides = {'top', 'right', 'bottom', 'left', 'back', 'front'};
		local count = 0;

		for key, val in pairs(sides) do
			local pType = peripheral.getType(val);
			if (pType ~= nil) then
				self.peripherals[pType] = peripheral.wrap(val);
				count = count + 1;
			end
		end

		self.data.peripheralCount = count;
	end,

	cprint = function(self, str, color)
		if (color == nil) then color = self.data.fgColor end;
		term.setTextColor(color);
		print(str);
		term.setTextColor(self.data.fgColor);
	end,
	cwrite = function(self, str, color)
		if (color == nil) then color = self.data.fgColor end;
		term.setTextColor(color);
		write(str);
		term.setTextColor(self.data.fgColor);
	end,

	-- Prompt user for configuration data and save to config.lua
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

	-- Create a menu loop for command input
	menu = function(self)
		local input;
		local exit = false;

		while (exit == false) do
			self:cwrite('\n[BaseOS]: ', colors.white);
			input = io.read();
			print();

			if (self:parseCommand(input) == false) then
				exit = true;
			end
		end
	end,

	-- Parse a string into a command and arguments and call the command
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

		if (self.commands[command] ~= nil) then
			return self.commands[command](self, args); -- if a method returns false, it indicates that the menu prompt loop should end
		else 
			self:cprint('Unrecognized command.', colors.red);
			return true;
		end
	end,

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

	-- Checks the update server for the latest BaseOS version and initiates the update process if current version doesn't match server's version
	checkUpdate = function(self)
		local rqtVersion = http.get(self.data.versionUrl);

		if (rqtVersion ~= nil) then
			local response = rqtVersion.readAll();
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

	-- Downloads and runs the update.lua script
	doUpdate = function(self)
		local rqtDownload = http.get(self.data.updateUrl);
		local code, file;

		if (rqtDownload ~= nil) then
			-- save update.lua contents to a file
			code = rqtDownload.readAll();
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

	-- Command to method mappings --
	commands = {
		help = function(self, args)
			local rowCount = 5;
			local count = 0;
			local x, y = term.getCursorPos();
			y = y + 1;

			print('Commands:');
			for key in pairs(self.commands) do
				if (count >= rowCount) then
					-- set column, set cursor pos 
					x = x + 12;
					y = y - rowCount;
					count = 0;
				else
					count = count + 1;
				end
				
				term.setCursorPos(x, y);
				print(key);
				newX, y = term.getCursorPos();
			end
			print('\n');

			return true;
		end,
		shutdown = function(self, args)
			os.shutdown();
			return false;
		end,
		restart = function(self, args)
			os.reboot();
			return false;
		end,
		exit = function(self, args)
			return false;
		end,
		-- checks if the current application version matches the server. If not, downloads new version
		update = function(self, args)
			return self:checkUpdate();
		end,
		setup = function(self, args)
			return self:setup();
		end,
		info = function(self, args)
			print('Computer label:  ' .. os.getComputerLabel());
			print('Computer ID:     ' .. os.getComputerID());
			print('BaseOS version:  ' .. self.data.version);
			print('Peripherals:     ' .. self.data.peripheralCount);

			return true;
		end,
		program = function(self, args)
			local programName, programArgs;

			if (table.getn(args) > 0) then
				programName = args[1];
				table.remove(args, 1);
				programArgs = args;

				if (self.programs[programName] ~= nil) then
					self.programs[programName](self, args);
				else 
					print('Unrecognized program.');
				end
			else
				local programCount = 0;
				print('Usage: program <program name> [arguments...]\n\nAvailable programs:');

				for key, val in pairs(self.programs) do
					print('* ' .. key);
					programCount = programCount + 1;
				end

				if (programCount == 0) then
					print('None.');
				end
			end

			return true;
		end
	},
	programs = {}
};