local basalt = require("basalt") -- Requires Basalt 2

basalt.LOGGER.setEnabled(true)
basalt.LOGGER.setLogToFile(true)

rednet.open("bottom")
local SERVICE_NAME = "stockservice"
local SERVER_ID = rednet.lookup(SERVICE_NAME)
if not SERVER_ID then
    error("Could not find stockservice on the network. Is it running?")
end
basalt.LOGGER.debug("[Rednet] GUI client ready, server ID: "..tostring(SERVER_ID))

local main = basalt.getMainFrame()

function buildWindow(title)
    local _main = main:addFrame({
        draggable = true,
        visible = false,
        x = 2,
        y = 2,
        width = 20,
        height = 10,
        background = colors.black,
        foreground = colors.white,
    })

    _main.draggingMap = {{
        x = 1,
        y = 1,
        width = function ()
            return _main:getWidth() - 1
        end, -- leave space for close button, also we cannot use a string formula here
        height = 1,
    }}

    _main:addButton({
        text = "X",
        x = "{parent.width}",
        y = 1,
        width = 1,
        height = 1,
        foreground = colors.white,
        background = colors.red,
    }):onClick(function()
        _main:setVisible(false)
    end)

    _main:addLabel({
        text = title,
        x = 2,
        y = 1,
        width = "{parent.width - 2}",
        height = 1,
        foreground = colors.white,
        background = colors.black,
    })

    local content = _main:addFrame({
        draggable = false,
        visible = true,
        x = 1,
        y = 2,
        width = "{parent.width}",
        height = "{parent.height - 1}",
        background = colors.gray,
        foreground = colors.white,
    })

    return {
        main = _main,
        content = content
    }
end

local Stock = (function ()
    local stockWin = {}

    stockWin.requestedItems = {}
    stockWin.lastStockSnapshot = {}

    -- Helper to find item index in requestedItems by id
    local function findRequestedIndex(id)
        for idx, entry in ipairs(stockWin.requestedItems) do
            if entry.id == id then return idx end
        end
        return nil
    end

    local function fetchStockSnapshot()
        rednet.send(SERVER_ID, { cmd = "query" }, SERVICE_NAME)
        local src, msg, proto = rednet.receive(SERVICE_NAME, 2)
        if proto == SERVICE_NAME and src == SERVER_ID and type(msg) == "table" and msg.snapshot then
            return msg.snapshot
        end
        return {}
    end

    local function stockChanged(newSnapshot, oldSnapshot)
        for idx, item in ipairs(newSnapshot) do
            if not oldSnapshot[idx] or oldSnapshot[idx].count ~= item.count then
                return true
            end
        end
        for idx, _ in ipairs(oldSnapshot) do
            if not newSnapshot[idx] then return true end
        end
        return false
    end

    stockWin.updateStockList = function ()
        local currentSnapshot = fetchStockSnapshot()
        if not currentSnapshot or #currentSnapshot == 0 then return end

        if not stockChanged(currentSnapshot, stockWin.lastStockSnapshot) then return end
        stockWin.lastStockSnapshot = currentSnapshot

        stockWin.stockList:clear()
        for _, item in ipairs(currentSnapshot) do
            stockWin.stockList:addItem({
                text = (item.displayName or item.id).." (x"..item.count..")",
                callback = function()
                    local idx = findRequestedIndex(item.id)
                    if idx then
                        table.remove(stockWin.requestedItems, idx)
                    else
                        table.insert(stockWin.requestedItems, { id = item.id, count = 1 })
                    end
                end
            })
        end
    end

    local inventoryWin = buildWindow("Stock")

    stockWin.main = inventoryWin.main
    stockWin.content = inventoryWin.content

    stockWin.subtitle = stockWin.content:addLabel({
        text = "Current Stock",
        x = 1,
        y = 1,
        width = "{parent.width - 2}",
        height = 1,
        background = colors.gray,
        foreground = colors.white,
    })

    stockWin.stockList = stockWin.content:addList({
        x = 2,
        y = 2,
        width = "{parent.width - 2}",
        height = "{parent.height - 3}",
        multiSelection = true,
    })

    stockWin.addressInput = stockWin.content:addInput({
        x = 2,
        y = "{parent.height - 1}",
        width = "{parent.width - 10}",
        height = 1,
        placeholder = "Package address",
    })

    stockWin.submitButton = stockWin.content:addButton({
        text = "Send",
        x = "{parent.width - 8}",
        y = "{parent.height - 1}",
        width = 8,
        height = 1,
    }):onClick(function()
        basalt.LOGGER.debug("Requested items: "..textutils.serialise(stockWin.requestedItems))
        if #stockWin.requestedItems == 0 then
            return
        end

        local address = stockWin.addressInput:getText()
        rednet.send(SERVER_ID, { cmd = "manual_request", items = stockWin.requestedItems, address = address }, SERVICE_NAME)
        stockWin.addressInput:setText("")
        stockWin.requestedItems = {}
        -- Clear the stock list entirely, then force a rebuild
        stockWin.stockList:clear()
        stockWin.lastStockSnapshot = {} -- force updateStockList to rebuild
        stockWin.updateStockList()
    end)

    stockWin:updateStockList()
    stockWin.main:setWidth(35)
    stockWin.main:setHeight(15)

    return stockWin
end)()

local OrderMgr = (function ()
    local oWin = {}
    oWin.orderQueue = {}
    oWin.selectedOrder = nil

    -- Helpers to render an order row
    local function orderRowText(o)
        return string.format("[#%s] %s > %s  (items=%d)", o.id, o.address, o.status, #o.items)
    end

    local function fetchOrderQueue()
        rednet.send(SERVER_ID, { cmd = "orders" }, SERVICE_NAME)
        local src, msg, proto = rednet.receive(SERVICE_NAME, 2)
        if proto == SERVICE_NAME and src == SERVER_ID and type(msg) == "table" and msg.orders then
            return msg.orders
        end
        return {}
    end

    oWin.updateUI = function ()
        oWin.orderQueue = fetchOrderQueue() or {}
        oWin.orderList:clear()
        for _,o in ipairs(oWin.orderQueue) do
            oWin.orderList:addItem{
                text = orderRowText(o),
                callback = function()
                    oWin.selectedOrder = o
                    basalt.LOGGER.debug("Selected order: "..textutils.serialise(o))
                end
            }
        end
    end

    -- Window layout
    local win = buildWindow("Order Manager")
    oWin.main = win.main
    oWin.content = win.content

    -- List of pending orders
    oWin.orderList = oWin.content:addList{
        x = 2,
        y = 2,
        width  = "{parent.width-2}",
        height = "{parent.height-4}",
        multiSelection = false
    }

    -- Approve button
    oWin.approveBtn = oWin.content:addButton{
        text = "Approve",
        x = 2,
        y = "{parent.height-1}",
        width = 9,
        height = 1
    }:onClick(function()
        local order = oWin.selectedOrder
        if not order then
            return
        end
        rednet.send(SERVER_ID, { cmd = "approve", orderId = order.id }, SERVICE_NAME)
        oWin.selectedOrder = nil
        oWin.updateUI()
    end)

    -- Cancel button
    oWin.cancelBtn = oWin.content:addButton{
        text = "Cancel",
        x = 13,
        y = "{parent.height-1}",
        width = 9,
        height = 1
    }:onClick(function()
        local order = oWin.selectedOrder
        if not order then
            return
        end
        rednet.send(SERVER_ID, { cmd = "cancel", orderId = order.id }, SERVICE_NAME)
        oWin.selectedOrder = nil
        oWin.updateUI()
    end)

    oWin.main:setWidth(35)
    oWin.main:setHeight(15)

    return oWin
end)()

local buttons = {
    Stock = function()
        if Stock.main.visible == true then
            Stock.main:setVisible(false)
            return
        end
        Stock.main:setVisible(true)
    end,
    Orders = function()
        if OrderMgr.main.visible == true then
            OrderMgr.main:setVisible(false)
            return
        end
        OrderMgr.main:setVisible(true)
    end,
}

local index = 0
local buttonWidth = 7
local buttonHeight = 5 -- 5x7 is actually a square not a rectangle as pixels are not square
local buttonSpacing = 1
for name, callback in pairs(buttons) do
    main:addButton()
        :setText(name)
        :setPosition(4 + (index * (buttonWidth + buttonSpacing)), 3)
        :setWidth(buttonWidth)
        :setHeight(buttonHeight)
        :onClick(callback)
    index = index + 1
end

-- Schedule periodic stock updates every second (adjust as needed)
basalt.schedule(function()
    while true do
        sleep(1)
        Stock:updateStockList()
        OrderMgr:updateUI()
    end
end)

basalt.run()
