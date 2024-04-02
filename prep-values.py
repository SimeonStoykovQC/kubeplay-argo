import sys
import yaml

import random
import time


APP_COUNT=3
CLASS_COUNT=12

filepath = "values.yaml"

with open(filepath, "r") as yaml_file:
    old_data = yaml.safe_load(yaml_file)

current_time = int(time.time())
random.seed(current_time)
random_number = random.randint(1000000, 9999999)

data = {}
data["redeployApplication"] = random_number
data["redeployRouter"] = random_number

if sys.argv[1] == "shuffle":
    apps = [[] for _ in range(APP_COUNT)]
    for idx in range(CLASS_COUNT):
        served_by = random.randint(0, APP_COUNT-1)
        apps[served_by].append(f"class{idx}")

    data["applications"] = []
    for idx, classes in enumerate(apps):
        if not classes:
            raise Exception("unlucky, try again")
        data["applications"].append({"toLoad": ",".join(classes)})
elif sys.argv[1] == "keep":
    data["applications"] = old_data["applications"]
else:
    raise ValueError(sys.argv)

with open(filepath, "w") as yaml_file:
    yaml.dump(data, yaml_file)
print(data)

