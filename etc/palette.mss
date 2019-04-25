/* ****************************************************************** */
/* OSM SMARTRAK for Imposm                                            */
/* ****************************************************************** */

/* For basic style customization you can simply edit the colors and
 * fonts defined in this file. For more detailed / advanced
 * adjustments explore the other files.
 *
 * GENERAL NOTES
 *
 * There is a slight performance cost in rendering line-caps.  An
 * effort has been made to restrict line-cap definitions to styles
 * where the results will be visible (lines at least 2 pixels thick).
 */

/* ================================================================== */
/* FONTS
/* ================================================================== */

/* directory to load fonts from in addition to the system directories */
Map { font-directory: url(./fonts); }

/* set up font sets for various weights and styles */
@sans_lt:           "Ubuntu Regular","Arial Regular","DejaVu Sans Book";
@sans_lt_italic:    "Ubuntu Italic","DejaVu Sans Italic","unifont Medium";
@sans:              "Ubuntu Regular","Arial Regular","DejaVu Sans Book";
@sans_italic:       "Ubuntu Semibold Italic","DejaVu Sans Italic","unifont Medium";
@sans_bold:         "Ubuntu Bold","DejaVu Sans Bold","unifont Medium";
@sans_bold_italic:  "Ubuntu Bold Italic","DejaVu Sans Bold Italic","unifont Medium";

/* Some fonts are larger or smaller than others. Use this variable to
   globally increase or decrease the font sizes. */
/* Note this is only implemented for certain things so far */
@text_adjust: 0;

/* ================================================================== */
/* LANDUSE & LANDCOVER COLORS
/* ================================================================== */

@land:              #f4f3f0;
@land_low: 			#f0ede5;
@water:             #c6deec;
@grass:             #b9d37f;
@beach:             #FFEEC7;
@park:              #b9d37f;
@cemetery:          #dfdbd4;
@wooded:            #b9d37f;
@agriculture:       #F2E8B6;

@building:          #e2ded2;
@building_case:     #d3d1c8;
@building3d:        #f0ede5;
@hospital:          #ebe3da;
@school:            #f0ead6;
@sports:            #b9d37f;

@residential:       #f0ede5;
@commercial:        @residential * 0.97;
@industrial:        @residential * 0.96;
@parking:           #e5e4df;

/* ================================================================== */
/* ROAD COLORS
/* ================================================================== */

/* For each class of road there are three color variables:
 * - line: for lower zoomlevels when the road is represented by a
 *         single solid line.
 * - case: for higher zoomlevels, this color is for the road's
 *         casing (outline).
 * - fill: for higher zoomlevels, this color is for the road's
 *         inner fill (inline).
 */

@motorway_line:     #ffffff;
@motorway_fill:     #ffffff;
@motorway_case:     #e9e9e9;

@trunk_line:        darken(#ffffff,5);
@trunk_fill:        #ffffff;
@trunk_case:        #e9e9e9;

/* What are these, do we need to deferentiate them? */
@primary_line:      @trunk_line;
@primary_fill:      @trunk_fill;
@primary_case:      @trunk_case;

@secondary_line:    #ffffff;
@secondary_fill:    #ffffff;
@secondary_case:    #e9e9e9;

@standard_line:     #ffffff;
@standard_fill:     #fff;
@standard_case:     #e9e9e9;

@service_line:      #ffffff;
@service_fill:      #ffffff;
@service_case:      #e9e9e9;

@pedestrian_line:   #ffffff;
@pedestrian_fill:   #ffffff;
@pedestrian_case:   #e9e9e9;

@cycle_line:        @standard_line;
@cycle_fill:        #ffffff;
@cycle_case:        @land;

@rail_line:         #dad9d9;
@rail_fill:         #dad9d9;
@rail_case:         #e9e9e9;

@aeroway:           #ddd;

@ferry_line:        darken(@water, 20);

/* ================================================================== */
/* BOUNDARY COLORS
/* ================================================================== */

@admin_2:           #7a98b7;

/* ================================================================== */
/* LABEL COLORS
/* ================================================================== */

/* We set up a default halo color for places so you can edit them all
   at once or override each individually. */
@place_halo:        fadeout(#fff,34%);

@country_text:      #222;
@country_halo:      @place_halo;

@state_text:        #333;
@state_halo:        @place_halo;

@city_text:         #333;
@city_halo:         @place_halo;

@town_text:         #3a3a3a;
@town_halo:         @place_halo;

@poi_text:          #444;

@motorway_text:     spin(darken(@motorway_fill,50),-15);
@motorway_halo:     lighten(@motorway_fill,15);
@trunk_text:        spin(darken(@trunk_fill,50),-15);
@trunk_halo:        lighten(@trunk_fill,15);
@primary_text:      spin(darken(@primary_fill,50),-15);
@primary_halo:      lighten(@primary_fill,15);
@secondary_text:    spin(darken(@secondary_fill,50),-15);
@secondary_halo:    lighten(@secondary_fill,15);
@standard_text:     spin(darken(@standard_fill,60),-15);
@standard_halo:     lighten(@standard_fill,15);

@road_text:         #777;
@road_halo:         #fff;

@other_text:        #666;
@other_halo:        @place_halo;

@locality_text:     #888;
@locality_halo:     @land;

/* Also used for other small places: hamlets, suburbs, localities */
@village_text:      #888;
@village_halo:      @place_halo;

@address_text:      rgba(136,133,127,0.75);
@address_halo:      rgba(255,255,255,0.5);

@ferry_text:        #566b82;
@ferry_halo:        rgba(191,213,238,0.66);

/* ****************************************************************** */



