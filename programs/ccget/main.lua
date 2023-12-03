--[[-
# The ccget package manager.

A simple computercraft package manager!

## Installing ccget

```bash
wget https://github.com/ajh123/Programs-CC/raw/main/programs/ccget/main.lua ccget.lua
```

## Installing a package
```bash
ccget install <package name>
```

## Removing a package
```bash
ccget install <package name>
```

## Searching for packages
```bash
ccget seach <search entry>
```

## Adding your program
See <https://ajh123.github.io/Programs-CC/guide/ccget-adding-package.html> for more details.

@module[kind=program] ccget
]]

local centralRepoUrl = "https://raw.githubusercontent.com/ajh123/Programs-CC/main/"
local packagesListFile = "ccrepo.json"
local packagesDir = "/ccget/packages/"
local manifestFileName = "manifest.json"

-- Function to download a file from the repository
local function downloadFile(url, destination)
    local content = http.get(url)
    if content then
        local file = fs.open(destination, "w")
        file.write(content.readAll())
        file.close()
        content.close()
        return true
    else
        return false
    end
end

-- Function to read a JSON file from the repository
local function readJSONFromRepo(url)
    local content = http.get(url, {
        ["Cache-Control"] = "no-cache"
    })
    if content then
        local data = content.readAll()
        content.close()
        return textutils.unserializeJSON(data)
    else
        return nil
    end
end

-- Function to install a package
local function installPackage(packageName)
    local packagesListUrl = centralRepoUrl .. packagesListFile
    local packagesList = readJSONFromRepo(packagesListUrl)

    if not packagesList then
        term.setTextColour(colours.red)
        print("Failed to retrieve packages list.")
        term.setTextColour(colours.white)
        return
    end

    local manifestUrl = packagesList.packages[packageName]

    if not manifestUrl then
        term.setTextColour(colours.red)
        print("Package " .. packageName .. " not found in the central repository.")
        term.setTextColour(colours.white)
        return
    end

    local manifest = readJSONFromRepo(manifestUrl)

    if not manifest then
        term.setTextColour(colours.red)
        print("Manifest not found for " .. packageName .. ".")
        term.setTextColour(colours.white)
        return
    end

    print("Installing " .. packageName .. "...")
    local success = true

    for fileName, file in pairs(manifest.files) do
        local fileUrl = manifest.files[fileName]
        local destination = packagesDir .. packageName .. "/" .. fileName

        if downloadFile(fileUrl, destination) then
            print("  " .. fileName .. " installed.")
        else
            term.setTextColour(colours.red)
            print("  Failed to install " .. fileName .. ".")
            term.setTextColour(colours.white)
            success = false
            break
        end
    end

    if success then
        term.setTextColour(colours.green)
        print(packageName .. " installed successfully.")
        term.setTextColour(colours.white)
    else
        term.setTextColour(colours.red)
        print(packageName .. " not installed successfully.")
        term.setTextColour(colours.white)
    end
end

-- Function to remove a package
local function removePackage(packageName)
    local packageDir = packagesDir .. packageName

    if fs.exists(packageDir) then
        fs.delete(packageDir)
        term.setTextColour(colours.green)
        print(packageName .. " removed successfully.")
        term.setTextColour(colours.white)
    else
        term.setTextColour(colours.red)
        print("Package " .. packageName .. " not found.")
        term.setTextColour(colours.white)
    end
end

-- Function to search for a package
local function searchPackage(packageName)
    local packagesListUrl = centralRepoUrl .. packagesListFile
    local packagesList = readJSONFromRepo(packagesListUrl)

    if not packagesList then
        term.setTextColour(colours.red)
        print("Failed to retrieve packages list.")
        term.setTextColour(colours.white)
        return
    end

    local found = false
    for name, _ in pairs(packagesList.packages) do
        if string.find(name:lower(), packageName:lower()) then
            print("- "..name)
            found = true
        end
    end

    if not found then
        term.setTextColour(colours.red)
        print("No packages found matching '" .. packageName .. "'.")
        term.setTextColour(colours.white)
    end
end

-- Parse command-line arguments
local args = {...}

if #args == 0 then
    print("Usage: ccget <install|remove|search> <packageName>")
    return
end

local command = args[1]
local packageName = args[2]

-- Perform the requested action
if command == "install" then
    installPackage(packageName)
elseif command == "remove" then
    removePackage(packageName)
elseif command == "search" then
    searchPackage(packageName)
else
    print("Invalid command. Use 'install', 'remove', or 'search'.")
end