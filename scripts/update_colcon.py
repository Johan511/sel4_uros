import json
import os
fw_dir = os.environ['FW_DIR']
meta_path = f'{fw_dir}/mcu_ws/colcon.meta'
with open(meta_path) as f:
    meta = json.load(f)
meta['names']['microxrcedds_client']['cmake-args'] += [
    '-DUCLIENT_PROFILE_UDP=OFF',
    '-DUCLIENT_PROFILE_TCP=OFF',
    '-DUCLIENT_PROFILE_SERIAL=OFF',
    '-DUCLIENT_PROFILE_DISCOVERY=OFF',
    '-DUCLIENT_PROFILE_CUSTOM_TRANSPORT=ON'
]
meta['names']['rmw_microxrcedds']['cmake-args'] += [
    '-DRMW_UXRCE_TRANSPORT=custom'
]

meta['names']['rmw_microxrcedds']['cmake-args'] += [
    '-DRMW_UXRCE_TRANSPORT=custom',
    '-DRMW_UXRCE_MAX_PUBLISHERS=10',
    '-DRMW_UXRCE_MAX_SUBSCRIPTIONS=10',
    '-DRMW_UXRCE_MAX_NODES=2',
]

with open(meta_path, 'w') as f:
    json.dump(meta, f, indent=4)
