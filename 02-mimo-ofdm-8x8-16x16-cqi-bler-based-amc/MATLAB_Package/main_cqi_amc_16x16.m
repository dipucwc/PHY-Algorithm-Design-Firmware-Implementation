%{
=========================================================================================================================
 main_cqi_amc_16x16.m — Online CQI-based AMC study at 16x16
=========================================================================================================================

The script runs the complete Project 2 online link-adaptation study for the 16x16 array. It requires the three per-mapping calibration
files mcs_bler_curves_eesm_16x16.csv, mcs_bler_curves_mean_16x16.csv, and mcs_bler_curves_minimum_16x16.csv produced by
generate_mcs_bler_curves with arraySizeToCalibrate = 16. All configuration
lives in create_cqi_amc_config; all processing lives in the shared driver run_cqi_amc_main so that the 8x8 and 16x16
studies execute identical code with the array size as the only changed input.
=========================================================================================================================
%}

run_cqi_amc_main(16);
