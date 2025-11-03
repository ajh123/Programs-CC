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

function setLaneState(laneIndex: number, state: "clear" | "red" | "red_yellow" | "green" | "yellow") {
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


setLaneState(0, "clear");

while (true) {
    setLaneState(0, "red");
    sleep(1);
    setLaneState(0, "red_yellow");
    sleep(1);
    setLaneState(0, "green");
    sleep(1);
    setLaneState(0, "yellow");
    sleep(1);
}