import { drivers, TrafficLight } from "./drivers";


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
  state: "clear" | "red" | "red_yellow" | "green" | "yellow"
) {
    const lightsToUpdate: TrafficLight[] = [];
    for (let i = 0; i < laneIndices.length; i++) {
        const lane = configuration.lanes[laneIndices[i]];
        lightsToUpdate.push(...lane.lights);
    }

    let fn: (light: TrafficLight) => void;
    switch (state) {
        case "clear":
            fn = (light) => light.clear();
            break;
        case "red":
            fn = (light) => light.setRed();
            break;
        case "red_yellow":
            fn = (light) => light.setRedYellow();
            break;
        case "green":
            fn = (light) => light.setGreen();
            break;
        case "yellow":
            fn = (light) => light.setYellow();
            break;
    }

    for (let i = 0; i < lightsToUpdate.length; i++) {
        fn(lightsToUpdate[i]);
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