local id = rednet.lookup("stockservice")

print("Found stockservice with ID: " .. id)

rednet.open("bottom")

rednet.send(id, {
    cmd = "query"
}, "stockservice")

local src, msg, proto = rednet.receive("stockservice")
local snapshot = msg.snapshot

print("Received from stockservice: " .. textutils.serialize(snapshot))

local item1 = snapshot[1]

local orderItems = {
    {
        id = item1.id,
        count = 1
    }
}

rednet.send(id, {
    cmd = "order",
    items = orderItems,
    address = "test"
}, "stockservice")

local src, msg, proto = rednet.receive("stockservice")
print("Received from stockservice: " .. textutils.serialize(msg))