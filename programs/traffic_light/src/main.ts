import { drivers, TrafficLightDriver } from "./drivers";

const configuration = (() => {
    const configuration = dofile("config.lua");
    let lanes = [];

    for (const laneConfig of configuration.lanes) {
        let lane = {
            lights: []
        } as { 
            lights: ReturnType<TrafficLightDriver['initialise']>[]
        };

        for (const lightConfig of laneConfig.lights) {
            const type = lightConfig.type;
            const driver = drivers[type];

            if (!driver) {
                throw new Error(`No driver found for type: ${type}`);
            }

            const light = driver().initialise(lightConfig);
            lane.lights.push(light);
        }
        lanes.push(lane);
    }

    return {
        lanes: lanes
    }
})();

function setLaneState(laneIndices: number[], state: "clear" | "red" | "red_yellow" | "green" | "yellow") {
    for (const laneIndex of laneIndices) {
        const lane = configuration.lanes[laneIndex];
        for (const light of lane.lights) {
            switch (state) {
                case "clear":
                    light.clear();
                    break;
                case "red":
                    light.setRed();
                    break;
                case "red_yellow":
                    light.setRedYellow();
                    break;
                case "green":
                    light.setGreen();
                    break;
                case "yellow":
                    light.setYellow();
                    break;
            }
        }
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