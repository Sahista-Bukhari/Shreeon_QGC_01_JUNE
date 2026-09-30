# Baylands route-mapping demo

1. From the PX4-Autopilot checkout, start the Baylands world with the
   downward-facing camera:

   ```sh
   make px4_sitl gz_x500_mono_cam_down_baylands
   ```

2. Connect this QGroundControl build to the SITL vehicle. In **Application
   Settings > General**, set **Video Source** to **UDP h.264 Video Stream** and
   use UDP port `5600`.
3. Open **Route Mapping**, import `BaylandsRouteMapping.plan`, and choose the
   resolution preset. High uses a 6 m trigger interval; Low uses 9 m.
4. Confirm **Est. Photo Count**, then click **Upload**.
5. Return to Fly View and start the mission.

At every survey-transect entry, the mission enables distance-based triggering
and requests the first image immediately. QGC sends the corresponding capture
request to `shreeon@10.5.0.2`, receives preview/full-resolution JPEGs by SCP,
and shows each image footprint on the Fly View map. Images, JSON metadata, and
an ODM-compatible `geo.txt` are stored under the timestamped
`Photo/RouteMapping/Mission_*` directory.

After the mission ends and all images have arrived, the progress panel changes
the reconstruction state to **Ready**. Click **Start ODM Stitching** to run the
`opendronemap/odm` Docker image; the orthophoto is written below that same
mission directory.
