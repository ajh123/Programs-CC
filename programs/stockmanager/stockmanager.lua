local basalt = require("basalt") -- Requires Basalt 2
basalt.LOGGER.setEnabled(true)
basalt.LOGGER.setLogToFile(true)

local stockTicker = peripheral.find("stockcheckingblock") -- Find the Create mod Stock Ticker peripheral
local redstoneRequester = peripheral.find("redstonerequester") -- Find the Redstone Requester peripheral

rednet.open("bottom")
local SERVICE_NAME = "stockservice"
local SERVICE_ADDRESS = "stocksrv"

rednet.host(SERVICE_NAME, SERVICE_ADDRESS)
basalt.LOGGER.debug("[Rednet] Server host ready")

-- Get the main frame (your window)
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
            if entry.id == id then
                return idx
            end
        end
        return nil
    end

    -- Compare current and last snapshot, return true if different
    local function stockChanged(newSnapshot, oldSnapshot)
        for idx, item in ipairs(newSnapshot) do
            if oldSnapshot[idx] == nil or oldSnapshot[idx].count ~= item.count then
                return true
            end
        end
        for idx, _ in ipairs(oldSnapshot) do
            if newSnapshot[idx] == nil then
                return true
            end
        end
        return false
    end

    stockWin.updateStockList = function ()
        local count = stockTicker.inventorySize()
        local currentSnapshot = {}
        for i = 1, count do
            local item = stockTicker.itemDetails(i)
            table.insert(currentSnapshot, { id = item.id, count = item.count })
        end

        if not stockChanged(currentSnapshot, stockWin.lastStockSnapshot) then
            -- No changes detected, skip UI update
            return
        end

        stockWin.lastStockSnapshot = currentSnapshot

        stockWin.stockList:clear()
        for i = 1, count do
            local item = stockTicker.itemDetails(i)
            stockWin.stockList:addItem({
                text = item.displayName.." (x"..item.count..")",
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
        redstoneRequester.request(stockWin.requestedItems, address)
        stockWin.addressInput:setText("") -- Clear input after sending
        stockWin.requestedItems = {} -- Clear requested items
        stockWin.updateStockList() -- Refresh stock list to reflect changes
    end)

    stockWin:updateStockList()
    stockWin.main:setWidth(35)
    stockWin.main:setHeight(15)

    return stockWin
end)()

local OrderMgr = (function ()
    local oWin = {}
    oWin.orderQueue = {}   -- {...{id, address, items, status}}
    oWin.selectedOrder = nil -- Currently selected order in the order list

    -- Helpers to render an order row
    local function orderRowText(o)
        return string.format("[#%s] %s > %s  (items=%d)",
            o.id, o.address, o.status, #o.items)
    end

    -- Update the list (rebuild it from the queue)
    oWin.updateUI = function ()
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
        order.status = "approved"
        redstoneRequester.request(order.items, order.address)

        -- Remove from queue
        for idx, o in ipairs(oWin.orderQueue) do
            if o.id == order.id then
                table.remove(oWin.orderQueue, idx)
                break
            end
        end
        oWin.selectedOrder = nil -- Clear selection

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
        order.status = "cancelled"
        -- Remove from queue
        for idx, o in ipairs(oWin.orderQueue) do
            if o.id == order.id then
                table.remove(oWin.orderQueue, idx)
                break
            end
        end
        oWin.selectedOrder = nil -- Clear selection
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
    end
end)

nextOrderID = 0
basalt.schedule(function()
    while true do
        -- block until a packet arrives
        local src, msg, proto = rednet.receive()

        if proto ~= SERVICE_NAME then
            basalt.LOGGER.warn("[Rednet] Unknown proto:", proto)
            -- skip to next loop iteration (nothing else to do here)
        else
            if type(msg) ~= "table" then
                basalt.LOGGER.error("[Rednet] Bad msg - not a table")
            else
                if msg.cmd == "query" then
                    -- send back the latest snapshot
                    rednet.send(src, { snapshot = Stock.lastStockSnapshot }, SERVICE_NAME)

                elseif msg.cmd == "order" then
                    -- validate the order packet
                    if type(msg.items) ~= "table" or type(msg.address) ~= "string" then
                        rednet.send(src, { err = "bad format" }, SERVICE_NAME)
                    else
                        -- create queue entry
                        local order = {
                            id      = nextOrderID,
                            address = msg.address,
                            items   = msg.items,
                            status  = "pending"
                        }
                        table.insert(OrderMgr.orderQueue, order)
                        nextOrderID = nextOrderID + 1

                        basalt.LOGGER.debug("[Order] New order: "..order.id)

                        OrderMgr.updateUI()

                        rednet.send(src, { ok = true, orderId = order.id }, SERVICE_NAME)
                    end

                else
                    rednet.send(src, { err = "unknown cmd" }, SERVICE_NAME)
                end
            end
        end
    end
end)

basalt.run()
