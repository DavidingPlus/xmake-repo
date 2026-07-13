-- Find all directories in the current list directory
local dirs = os.dirs("*")

-- Iterate over directories and check if xmake.lua and .buildme exist
for _, dir in ipairs (dirs) do
    if os.isdir(dir) then
        includes (dir)    
    end
end
