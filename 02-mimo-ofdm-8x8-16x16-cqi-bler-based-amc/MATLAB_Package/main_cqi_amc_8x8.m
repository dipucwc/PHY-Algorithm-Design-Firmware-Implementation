%{
=========================================================================================================================
 main_cqi_amc_8x8.m — Online CQI-based AMC study at 8x8
=========================================================================================================================

The script runs the complete Project 2 online link-adaptation study for the 8x8 array. It requires the three per-mapping calibration
files mcs_bler_curves_eesm_8x8.csv, mcs_bler_curves_mean_8x8.csv, and mcs_bler_curves_minimum_8x8.csv produced by
generate_mcs_bler_curves with arraySizeToCalibrate = 8. All configuration
lives in create_cqi_amc_config; all processing lives in the shared driver run_cqi_amc_main so that the 8x8 and 16x16
studies execute identical code with the array size as the only changed input.
=========================================================================================================================
%}

run_cqi_amc_main(8);
