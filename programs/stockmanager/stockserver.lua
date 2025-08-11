-- stockserver.lua
-- Dedicated backend server for stock management, order processing, and peripheral operations
-- Communicates with GUI clients via rednet

local stockTicker = peripheral.find("stockcheckingblock")
local redstoneRequester = peripheral.find("redstonerequester")

rednet.open("bottom")
local SERVICE_NAME = "stockservice"
local SERVICE_ADDRESS = "stocksrv"

rednet.host(SERVICE_NAME, SERVICE_ADDRESS)

local orderQueue = {}
local nextOrderID = 0

-- Helper: Take a snapshot of current stock
local function getStockSnapshot()
    local count = stockTicker.inventorySize()
    local snapshot = {}
    for i = 1, count do
        local item = stockTicker.itemDetails(i)
        table.insert(snapshot, { id = item.id, count = item.count })
    end
    return snapshot
end

-- Main server loop
while true do
    local src, msg, proto = rednet.receive()
    if proto ~= SERVICE_NAME then
        -- Unknown protocol, ignore
    else
        if type(msg) ~= "table" then
            rednet.send(src, { err = "bad msg format" }, SERVICE_NAME)
        else
            if msg.cmd == "query" then
                -- Return latest stock snapshot
                local snapshot = getStockSnapshot()
                rednet.send(src, { snapshot = snapshot }, SERVICE_NAME)
            elseif msg.cmd == "order" then
                if type(msg.items) ~= "table" or type(msg.address) ~= "string" then
                    rednet.send(src, { err = "bad format" }, SERVICE_NAME)
                else
                    local order = {
                        id = nextOrderID,
                        address = msg.address,
                        items = msg.items,
                        status = "pending"
                    }
                    table.insert(orderQueue, order)
                    nextOrderID = nextOrderID + 1
                    rednet.send(src, { ok = true, orderId = order.id }, SERVICE_NAME)
                end
            elseif msg.cmd == "approve" then
                -- Approve and process an order
                local orderId = msg.orderId
                for idx, o in ipairs(orderQueue) do
                    if o.id == orderId then
                        o.status = "approved"
                        redstoneRequester.request(o.items, o.address)
                        table.remove(orderQueue, idx)
                        rednet.send(src, { ok = true }, SERVICE_NAME)
                        break
                    end
                end
            elseif msg.cmd == "cancel" then
                -- Cancel an order
                local orderId = msg.orderId
                for idx, o in ipairs(orderQueue) do
                    if o.id == orderId then
                        o.status = "cancelled"
                        table.remove(orderQueue, idx)
                        rednet.send(src, { ok = true }, SERVICE_NAME)
                        break
                    end
                end
            elseif msg.cmd == "orders" then
                -- Return current order queue
                rednet.send(src, { orders = orderQueue }, SERVICE_NAME)
            elseif msg.cmd == "manual_request" then
                -- Manual request from GUI
                if type(msg.items) == "table" and type(msg.address) == "string" then
                    redstoneRequester.request(msg.items, msg.address)
                    rednet.send(src, { ok = true }, SERVICE_NAME)
                else
                    rednet.send(src, { err = "bad format" }, SERVICE_NAME)
                end
            else
                rednet.send(src, { err = "unknown cmd" }, SERVICE_NAME)
            end
        end
    end
end
