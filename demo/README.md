# Baylands route-mapping demo

1. From the PX4-Autopilot checkout, start the Baylands world with the
   downward-facing camera:

   ```sh
   make px4_sitl gz_x500_mono_cam_down_baylands
   ```

2. Connect this QGroundControl build to the SITL vehicle. In **Application
   Settings > General**, set **Video Source** to **UDP h.264 Video Stream** and
   use UDP port `5600`.
3. Open Route Mapping and import `BaylandsRouteMapping.plan`.
4. Confirm that **Est. Photo Count** is non-zero, then click **Upload**.
5. Return to Fly View and start the mission.

At the first pattern entry, the mission enables automatic distance-based camera
capture and takes the first image immediately. Capture is stopped at every
inner-transect endpoint and restarted at the next inner-transect entry, so no
photos are taken on turns, connectors, takeoff, or RTL. Each live video frame
is saved under QGroundControl's Photo directory and placed on the Fly View map
at its capture coordinate. The image footprint follows the survey camera
spacing and the nearest flight leg. Camera feedback supplies the exact
coordinates when the vehicle supports it; the same live behavior is maintained
in SITL when that feedback is unavailable.

After RTL has completed and the vehicle has landed/disarmed, the mapping JPEGs
created by that flight are removed automatically from the Photo directory.
Other photos in the directory are not deleted.
