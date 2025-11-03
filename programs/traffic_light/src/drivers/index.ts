export interface TrafficLightDriver {
    initialise: (config: any) => {
        clear: () => void,
        setRed: () => void,
        setRedYellow: () => void,
        setGreen: () => void,
        setYellow: () => void,
    };
}

export const drivers = {
    "create/nixie_tube": () => { return require('./nixie_tube') as TrafficLightDriver; },
} as { [key: string]: () => TrafficLightDriver | undefined };