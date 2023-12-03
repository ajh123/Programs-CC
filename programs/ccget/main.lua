--[[-
The ccget package manager

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
        print("Failed to retrieve packages list.")
        return
    end

    local manifestUrl = packagesList.packages[packageName]

    if not manifestUrl then
        print("Package " .. packageName .. " not found in the central repository.")
        return
    end

    local manifest = readJSONFromRepo(manifestUrl)

    if not manifest then
        print("Manifest not found for " .. packageName .. ".")
        return
    end

    print("Installing " .. packageName .. "...")

    for fileName, file in pairs(manifest.files) do
        local fileUrl = manifest.files[fileName]
        local destination = packagesDir .. packageName .. "/" .. fileName

        if downloadFile(fileUrl, destination) then
            print("  " .. fileName .. " installed.")
        else
            print("  Failed to install " .. fileName .. ".")
        end
    end

    print(packageName .. " installed successfully.")
end


installPackage("ajh123/ccget")
