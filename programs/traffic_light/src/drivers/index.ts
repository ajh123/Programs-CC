export type LightState = "clear" | "red" | "red_yellow" | "green" | "yellow";

export interface TrafficLight {
    setState: (state: LightState) => void,
}

export interface TrafficLightDriver {
    initialise: (config: any) => TrafficLight;
}

export const drivers = {
    "create/nixie_tube": () => { return require('./nixie_tube') as TrafficLightDriver; },
} as { [key: string]: () => TrafficLightDriver | undefined };