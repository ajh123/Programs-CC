const emptySignal = { r: 0, g: 0, b: 0, glowWidth: 3, glowHeight: 3 } // glow sizes are actually ignored for 0 colour
const redSignal   = { r: 255, g: 0, b: 0, glowWidth: 3, glowHeight: 3 }
const yellowSignal = { r: 255, g: 255, b: 0, glowWidth: 3, glowHeight: 3 }
const greenSignal  = { r: 0, g: 255, b: 0, glowWidth: 3, glowHeight: 3 }

interface NixieTubePeripheral {
    setSignal(this: void, primary: any, secondary: any): void
}

export function initialise(config: { top: string; bottom: string }) {
    if (!config.top || !config.bottom) {
        throw new Error('Nixie tube top or bottom names not configured')
    }

    const top = peripheral.wrap(config.top) as NixieTubePeripheral
    const bottom = peripheral.wrap(config.bottom) as NixieTubePeripheral

    if (!top || !bottom) {
        throw new Error('Nixie tube top or bottom peripherals not found')
    }

    const nixie_tube = {
        top: top,
        bottom: bottom,
    }

    return {
        setState: (state: "clear" | "red" | "red_yellow" | "green" | "yellow") => {
            if (state === "clear") {
                nixie_tube.top.setSignal(emptySignal, emptySignal)
                nixie_tube.bottom.setSignal(emptySignal, emptySignal)
            } else if (state === "red") {
                nixie_tube.top.setSignal(redSignal, emptySignal)
                nixie_tube.bottom.setSignal(emptySignal, emptySignal)
            } else if (state === "red_yellow") {
                nixie_tube.top.setSignal(redSignal, yellowSignal)
                nixie_tube.bottom.setSignal(emptySignal, emptySignal)
            } else if (state === "green") {
                nixie_tube.top.setSignal(emptySignal, emptySignal)
                nixie_tube.bottom.setSignal(greenSignal, emptySignal)
            } else if (state === "yellow") {
                nixie_tube.top.setSignal(emptySignal, yellowSignal)
                nixie_tube.bottom.setSignal(emptySignal, emptySignal)
            }
        }
    }
}
