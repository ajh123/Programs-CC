import { drivers, TrafficLight, LightState } from "./drivers";


interface Configuration {
    lanes: {
        lights: TrafficLight[];
    }[];
}

const configuration = (() => {
    const configuration = dofile("config.lua");
    let lanes = [];

    for (const laneConfig of configuration.lanes) {
        let lights = [];

        for (const lightConfig of laneConfig.lights) {
            const type = lightConfig.type;
            const driver = drivers[type];

            if (!driver) {
                throw new Error(`No driver found for type: ${type}`);
            }

            const light = driver().initialise(lightConfig);
            lights.push(light);
        }
        lanes.push({
            lights: lights
        });
    }

    return {
        lanes: lanes
    } as Configuration;
})();

function setLaneState(
  laneIndices: number[],
  state: LightState
) {
    const lightsToUpdate: TrafficLight[] = [];
    for (let i = 0; i < laneIndices.length; i++) {
        const lane = configuration.lanes[laneIndices[i]];
        lightsToUpdate.push(...lane.lights);
    }

    for (let i = 0; i < lightsToUpdate.length; i++) {
        lightsToUpdate[i].setState(state);
    }
}

const allLaneIndices = configuration.lanes.map((_, index) => index);

setLaneState(allLaneIndices, "clear");

while (true) {
    setLaneState(allLaneIndices, "red");
    sleep(1);
    setLaneState(allLaneIndices, "red_yellow");
    sleep(1);
    setLaneState(allLaneIndices, "green");
    sleep(1);
    setLaneState(allLaneIndices, "yellow");
    sleep(1);
}