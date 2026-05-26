include <BOSL2/std.scad>
include <BOSL2/walls.scad>

/* [Hidden] */
$fn = 100;
EPSILON = 0.01;

// -------------------- constants --------------------
BASE_UNIT = 15;
BASE_STRENGTH = 2;
BASE_CHAMFER = 1;

TOLERANCE = 0.2;
PRINTING_LAYER_HEIGHT = 0.2;

STD_UNIT_HEIGHT = 44.45;
STD_WIDTH_19INCH = 482.6;

STD_MOUNT_SURFACE_WIDTH = 15.875;
STD_RACK_BORE_DISTANCE_Z = 15.875;

RACKMOUNT_BORE_WIDTH = 10;

PANEL_PRIMARY_COLOR = "#f7b600"; // HR_YELLOW

// -------------------- device set (fixed) --------------------
DEV1_W = 288;
DEV1_D = 132.1;
DEV1_H = 24.9;

DEV2_W = 113;
DEV2_D = 89;
DEV2_H = 28;

// gap between the two device cutouts/trays (in X)
DEVICE_GAP = 6;   // mm (adjust if you want more plastic between devices)

// Tray-specific fixed config
flange_depth = BASE_UNIT;         // 15
tray_wall_thickness = BASE_STRENGTH; // lightweight_tray=true => fixed 2mm

// -------------------- rack holes + stiffeners --------------------
module rack_bore() {
  bore_h = 6.5;
  cuboid([RACKMOUNT_BORE_WIDTH, BASE_STRENGTH + EPSILON, bore_h],
         rounding=bore_h/2, except=[FRONT,BACK]);
}

module bores_1_hu() {
  zcopies(spacing=STD_RACK_BORE_DISTANCE_Z, n=3) rack_bore();
}

module stiffener_frontpanel(stiffener_width=BASE_UNIT, orient=UP) {
  stiffener_side = BASE_UNIT - BASE_STRENGTH;
  stopper_wedge = [stiffener_width, stiffener_side, stiffener_side];
  wedge_chamfer = BASE_CHAMFER;

  tag_scope("stiffener") diff() wedge(stopper_wedge, orient=orient) {
    tag("remove")
      attach("bot_edge", LEFT+FWD, overlap=BASE_STRENGTH*sqrt(2))
      chamfer_edge_mask(l=stiffener_width, chamfer=BASE_STRENGTH);

    tag("remove")
      attach([BOTTOM+LEFT,BOTTOM+RIGHT,"hypot_left","hypot_right"], LEFT+FWD, overlap=wedge_chamfer*sqrt(2))
      chamfer_edge_mask(l=BASE_UNIT*sqrt(2), chamfer=wedge_chamfer);
  }
}

module rackmount_1u(panel_width, anchor=CENTER, spin=0, orient=UP) {
  dims = [panel_width, BASE_STRENGTH, STD_UNIT_HEIGHT];

  attachable(anchor, spin, orient, size=dims) {
    difference() {
      tag_scope("rackmount_1u") diff()
      cuboid(dims) {
        // remove ear bores
        tag("remove")
          align(CENTER, [LEFT,RIGHT], inside=true,
                inset=(STD_MOUNT_SURFACE_WIDTH - RACKMOUNT_BORE_WIDTH)/2)
          bores_1_hu();

        // rear stiffeners
        tag("keep")
          align(BACK,BOTTOM)
          stiffener_frontpanel(panel_width - (STD_MOUNT_SURFACE_WIDTH + TOLERANCE)*2);

        tag("keep")
          align(BACK,TOP)
          stiffener_frontpanel(panel_width - (STD_MOUNT_SURFACE_WIDTH + TOLERANCE)*2, orient=DOWN);
      }
    }
    children();
  }
}

module rackmount_stack(panel_width, height_units, anchor=CENTER, spin=0, orient=UP) {
  total_h = height_units * STD_UNIT_HEIGHT;
  attachable(anchor, spin, orient, size=[panel_width, BASE_STRENGTH, total_h]) {
    zcopies(spacing=STD_UNIT_HEIGHT, n=height_units) rackmount_1u(panel_width);
    children();
  }
}

// -------------------- cutout + tray --------------------
module device_cutout_tray(device_w_eff, device_h_eff, cutout_depth) {
  // tray version: chamfer always on
  chamfer_edges = [TOP+FRONT, TOP+LEFT, TOP+RIGHT];
  cuboid([device_w_eff, device_h_eff, cutout_depth],
         chamfer=-BASE_CHAMFER, edges=chamfer_edges);
}

module tray(width, depth, height, wall_thickness) {
  tray_width = width;
  tray_depth = depth + TOLERANCE + wall_thickness;
  tray_height = BASE_UNIT;

  stabilizer_height = height - tray_height;
  stabilizer_side = min(stabilizer_height, tray_depth);

  hex_spacing = BASE_UNIT/2;
  hex_strut = BASE_STRENGTH;
  hex_frame = BASE_STRENGTH;

  bottom_hex_frame = (min(width, depth) < BASE_UNIT*3) ? BASE_STRENGTH : BASE_UNIT;

  stabilizer_dims = [[0, 0], [0, stabilizer_side], [stabilizer_side, 0]];

  wedge_h = tray_height - wall_thickness;
  stopper_wedge = [wall_thickness, tray_height, wedge_h];

  wedge_chamfer = BASE_STRENGTH - PRINTING_LAYER_HEIGHT;

  hex_panel([tray_width, tray_depth, wall_thickness],
            strut=hex_strut, spacing=hex_spacing,
            frame=bottom_hex_frame, bevel=[LEFT,RIGHT]) {

    align(TOP, BACK+LEFT)
      tag_scope("tray") diff() wedge(stopper_wedge, spin=-90)
        attach("hypot_right", LEFT+FWD, overlap=wedge_chamfer*sqrt(2))
        chamfer_edge_mask(l=BASE_UNIT*sqrt(2), chamfer=wedge_chamfer);

    align(TOP, BACK+RIGHT)
      tag_scope("tray") diff() wedge(stopper_wedge, spin=90)
        attach("hypot_left", LEFT+FWD, overlap=wedge_chamfer*sqrt(2))
        chamfer_edge_mask(l=BASE_UNIT*sqrt(2), chamfer=wedge_chamfer);

    attach(RIGHT, LEFT)
      hex_panel([tray_height, tray_depth, wall_thickness],
                strut=hex_strut, spacing=hex_spacing,
                frame=hex_frame, bevel=[LEFT]) {
        if (height > BASE_UNIT*2)
          attach(RIGHT, LEFT, align=FWD)
            hex_panel(stabilizer_dims, strut=hex_strut, spacing=hex_spacing,
                      h=wall_thickness, frame=hex_frame);
      }

    attach(LEFT, LEFT)
      hex_panel([tray_height, tray_depth, wall_thickness],
                strut=hex_strut, spacing=hex_spacing,
                frame=hex_frame, bevel=[LEFT]) {
        if (height > BASE_UNIT*2)
          mirror([0,1,0])
            attach(RIGHT, LEFT, align=FWD)
              hex_panel(stabilizer_dims, strut=hex_strut, spacing=hex_spacing,
                        h=wall_thickness, frame=hex_frame);
      }
  }
}

// Builds one “device station”: flange block + tray + subtract cutout
module device_station(device_w, device_d, device_h) {
  device_w_eff = device_w + TOLERANCE;
  device_h_eff = device_h + TOLERANCE;

  flange_w = device_w_eff + tray_wall_thickness*2;
  flange_h = device_h_eff + tray_wall_thickness*2;

  // (2) per request: use flange_depth - BASE_STRENGTH
  cutout_depth = flange_depth - BASE_STRENGTH;

  // flange body
  cuboid([flange_w, flange_depth, flange_h]) {
    // tray behind flange
    align(BACK, BOTTOM)
      tray(flange_w,
           device_d - flange_depth - BASE_STRENGTH,
           flange_h,
           tray_wall_thickness);

    // subtract device cutout
    tag("remove")
      attach(FRONT, TOP, spin=180, inside=true, overlap=BASE_STRENGTH, shiftout=EPSILON)
      device_cutout_tray(device_w_eff, device_h_eff, cutout_depth + BASE_STRENGTH*3);
  }
}

// -------------------- assembly --------------------
module dual_tray_frontpanel_19in() {
  // height must fit the tallest station requirement
  function required_height_for(h) =
    h + TOLERANCE + tray_wall_thickness*2 - BASE_STRENGTH + BASE_STRENGTH; // tray_height_addition

  required_height = max(required_height_for(DEV1_H), required_height_for(DEV2_H));
  height_units = ceil(required_height / STD_UNIT_HEIGHT);

  total_panel_h = height_units * STD_UNIT_HEIGHT;

  // check horizontal fit (rough sanity)
  usable_panel_w = STD_WIDTH_19INCH - 2*STD_MOUNT_SURFACE_WIDTH;
  dev_pair_w =
    (DEV1_W + TOLERANCE + tray_wall_thickness*2) +
    DEVICE_GAP +
    (DEV2_W + TOLERANCE + tray_wall_thickness*2);

  if (dev_pair_w > usable_panel_w)
    echo(str("WARNING: devices+gap (", dev_pair_w, "mm) exceed usable width (", usable_panel_w, "mm)."));

  // Center the pair on the panel in X
  x1 = (dev_pair_w/2) - (DEV1_W + TOLERANCE + tray_wall_thickness*2)/2;
  
  x2 =  -(dev_pair_w/2) + (DEV2_W + TOLERANCE + tray_wall_thickness*2)/2;

  // Build the rack panel centered; stations aligned to vertical middle (Z=0)
  tag_scope("frontpanel") diff()
  rackmount_stack(STD_WIDTH_19INCH, height_units, anchor=CENTER) {

    // stations sit behind panel (towards BACK), and are vertically centered
    // align(BACK, CENTER) means their Z center matches panel Z center (request #4)
    align(BACK, CENTER) {

      // dev1
      translate([x1, 0, 0])
        device_station(DEV1_W, DEV1_D, DEV1_H);

      // dev2
      translate([x2, 0, 0])
        device_station(DEV2_W, DEV2_D, DEV2_H);
    }

    // front chamfer always on
    tag("remove") edge_mask(FRONT) chamfer_edge_mask(chamfer=BASE_CHAMFER);
  }
}

// Render
color(PANEL_PRIMARY_COLOR)
dual_tray_frontpanel_19in();