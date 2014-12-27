local baseUrl = 'http://johnny.website/src';
local files = {};
local newFileCount = 0;
local continue = true;

-- specify file to URL mappings. Table key represents path on local computer, value represents URL path on website
files['/startup'] = baseUrl .. '/startup';
files['/BaseOS/baseos.lua'] = baseUrl .. '/BaseOS/baseos.lua';
files['/BaseOS/libraries/JSON.lua'] = baseUrl .. '/BaseOS/libraries/JSON.lua';

term.clear();
term.setCursorPos(2, 1);

-- Loop through files table and save remote files to computer
for key, val in pairs(files) do
	write('\nDownloading ' .. key .. '... ');
	local request = http.get(val);

	-- determine if request responded. If not, break loop and display error message
	if (request ~= nil) then
		local response = request.readAll();
		local file = fs.open(key, 'w');
		file.write(response);
		file.close();

		write('Done');
		newFileCount = newFileCount + 1;
	else
		print('[Error] Failed to download update files.');
		continue = false;
		break;
	end	
end
print('\n' .. newFileCount .. ' files updated.');

-- Create any essential directories that don't already exist
if (not fs.exists('/BaseOS/programs')) then fs.makeDir('/BaseOS/programs') end;
if (not fs.exists('/BasOS/startup')) then fs.makeDir('/BaseOS/startup') end;

-- Display result message, prompt for any further action
if (continue and newFileCount > 0) then
	print('\nBaseOS has been updated successfully.\n\nPress Enter to reboot.');
	io.read();

	-- eject any disks (incase update.lua was run from a disk)
	disk.eject('top');
	disk.eject('right');
	disk.eject('bottom');
	disk.eject('left');
	disk.eject('back');

	os.reboot();
else
	print('Failed to update BaseOS.');
end