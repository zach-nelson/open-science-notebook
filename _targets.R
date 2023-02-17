# libraries----

library(targets)
library(tidyverse)
library(tarchetypes)
library(DT)
library(here)
library(sf)
library(tmaptools)
library(tmap)
library(ggpmisc)
library(ggpubr)

# source functions----
source("code/R/functions.R")

# target options----
tar_option_set(
  packages = c(
    "tidyverse",
    "stringr"
  )
  # debug = fiverow_ts,
  # cue = tar_cue(mode = "never"),
)

list(
  ## these year parameters drive a lot of action downstream

   # PARAMETER-set current year----
  tar_target(cYear, 2022),

  # set previous year to load previous master database
  tar_target(pYear, 2021),


  # attributes - parcel----
  tar_target(attributes_file, "data/Attributes.csv", format = "file"),
  tar_target(attributes, read.csv(attributes_file)),
  tar_target(attributes_pfix, mult_to_single_parcel_name(x = attributes)),
  tar_target(attributes_reinv, filter(attributes_pfix,reinv == "r")),

  # # depth-to-water----
  tar_target(dtw_file, paste0("data/dtw_",pYear,".csv"), format = "file"),
  tar_target(dtw, read.csv(dtw_file)),
  tar_target(dtw_pfix, mult_to_single_parcel_name(x = dtw)),

  # # remote sensing tabular----
  # preprocessing, aggregating and appending satellite VI timeseries steps
  # can be added here at some point.
  tar_target(rs_file, paste0("data/rs_",pYear,".csv"), format = "file"),
  tar_target(rs, read.csv(rs_file)),
  tar_target(rs_pfix, mult_to_single_parcel_name(x = rs)),

  # gis shapefiles----
  tar_target(parcels_shp_file, "data/gisdata/LA_parcels_rasterizedd.shp", format = 'file'),
  tar_target(parcels_shp, st_read(parcels_shp_file)),

  tar_target(canals_shp_file, "data/gisdata/canals.shp", format = 'file'),
  tar_target(canals_shp, st_read(canals_shp_file, quiet = TRUE)),

  tar_target(monsites_shp_file, "data/gisdata/monsites_icwd_gps.shp", format = 'file'),
  tar_target(monsites_shp, st_read(monsites_shp_file, quiet = TRUE) %>% filter(!is.na(SITENAME))),

  tar_target(or_shp_file, "data/gisdata/OwensRiver.shp", format = 'file'),
  tar_target(or_shp, st_read(or_shp_file, quiet = TRUE)),

  tar_target(laa_shp_file, "data/gisdata/LA_aqueduct_nad83.shp", format = 'file'),
  tar_target(laa_shp, st_read(laa_shp_file, quiet = TRUE)),

  tar_target(lakes_shp_file, "data/gisdata/lakes.shp", format = 'file'),
  tar_target(lakes_shp, st_read(lakes_shp_file, quiet = TRUE)),

  tar_target(streams_shp_file, "data/gisdata/streams.shp", format = 'file'),
  tar_target(streams_shp, st_read(streams_shp_file, quiet = TRUE)),

  # Plant Species attributes linked to data by code. Allows grouping summaries
  # by functional type (shrub, grass), lifecycle (annual, perennial), native status,
  # rarity etc..
  tar_target(species_file, "data/species.csv", format = "file"),
  tar_target(species, read.csv(species_file)),


  # line point data----


  # better the cYear should drive everything input related, so cYear is baked
  # into the input files. so name the new annual update e.g. lpt_ICWD_2021.csv


  ## icwd data----

  tar_target(icwd_file,paste0("data/lpt_ICWD_",cYear,".csv"), format = "file"),
  tar_target(icwd_wide, read.csv(icwd_file)),
  tar_target(icwd_long, pivot_longer_icwd(icwd_wide)),
  tar_target(icwd_processed,
             add_species_agency_plotid(long = icwd_long,cYear,species, entity = "ICWD")),
  tar_target(icwd_output_csv, save_csv_and_return_path(processed = icwd_processed,cYear,entity = "ICWD"),
             format = "file"),

  ## ladwp data----
  # The file loaded depends on the year parameter cYear. The previous master loaded
  # to for updating should depend on the year - 1

  tar_target(ladwp_file, paste0("data/lpt_LADWP_",cYear,".csv"), format = "file"),
  tar_target(ladwp_long, read.csv(ladwp_file)),
  tar_target(ladwp_processed,
             add_species_agency_plotid(long = ladwp_long,cYear,species, entity = "LADWP")),

  tar_target(ladwp_output_csv, save_csv_and_return_path(processed = ladwp_processed,cYear,entity = "LADWP"),
             format = "file"),
  tar_target(icwd_ladwp_bind, bind_rows(icwd_processed, ladwp_processed)),
  # output file name will include the cYear
  tar_target(icwd_ladwp_output_csv, save_csv_and_return_path(processed = icwd_ladwp_bind,cYear,entity = "ICWD_LADWP_merged"),
             format = "file"),

  ## master lpt update---specify relative file path csv
  tar_target(lpt_prev_master_file, paste0("data/lpt_MASTER_",pYear,".csv"), format = "file"),

  ## read in the previous year master file
  tar_target(lpt_prev_master, read.csv(lpt_prev_master_file)),

  ## bind icwd-ladwp current year to master
  tar_target(lpt_updated_master, bind_rows(icwd_ladwp_bind, lpt_prev_master)),

  # this is saved to output, updated master
  tar_target(lpt_updated_master_csv, save_master_csv_and_return_path(processed = lpt_updated_master,cYear,entity = "MASTER"),
             format = "file"),

  ## filter master LELA----
  tar_target(lpt_long_no_lela, filt_lela(data = lpt_updated_master)),
  tar_target(lpt_long_no_lela_pfix, mult_to_single_parcel_name(x = lpt_long_no_lela)),
  tar_target(long_combined_nl_csv, save_csv_and_return_path(processed = lpt_long_no_lela_pfix,cYear,entity = "long_combined_nl"),
             format = "file"),

  ## summary numbers----
  tar_target(n_parcels_all_years, count_parcels_all_years(lpt_updated_master)),
  tar_target(n_parcels_sampled, count_parcels_cyear(n_parcels_all_years, cYear)),
  tar_target(n_transects_sampled, count_transects_cyear(lpt_updated_master,cYear)),

  ## transect functional type----
  tar_target(wvcom_file, "data/wvcom1.csv", format = "file"),
  tar_target(wvcom, read.csv(wvcom_file)),
  tar_target(wvcom_pfix, mult_to_single_parcel_name(x = wvcom)),

  tar_target(transects, summarise_to_transect(x=lpt_long_no_lela_pfix, y=wvcom_pfix)),

  ## parcel summary functional type----
  tar_target(parcels, summarise_to_parcel(x= transects)),
  tar_target(parcels_deltas, add_parcel_deltas(parcels)),
  tar_target(parcels_deltas_yoy, add_parcel_deltas_yoy(parcels, cYear)),

  ### wellfield and control parcels summary ----
  tar_target(wellcont_means, wellfield_control_means(parcels_deltas, attributes_pfix)),
  tar_target(wellcont_means_rarefied, wellfield_control_means_rarefied(parcels_deltas, attributes_pfix)),
  tar_target(plot_wellcontrol, plot_wellfield_control(wellcont_means_rarefied)),
  tar_target(trends.w.c, compute_trend_well_cont(wellcont_means_rarefied)),
  # tar_target(boxplot.w.c, boxplot_wc_pft_year_statcompare(attributes = attributes_pfix,
  #                                                         parcels = parcels,
  #                                                         comparison_year = cYear,
  #                                                         reference_year = "1986")),
  tar_target(boxplot.w.c, boxplot_well_cont(parcels,attributes_pfix,cYear)),


  ## nest transects
  tar_target(parcel_year_meta, nest_transects(transects, attributes_reinv)),

  ## split on baseline n----
  tar_target(parcel_year_meta_2samp,filter(parcel_year_meta, n.y > 4) ),
  tar_target(parcel_year_meta_1samp, filter(parcel_year_meta, n.y <= 4)),

  ## ttests----
  # old
  tar_target(parcel_year_meta_2samp_results, two_sample_ttest(parcel_year_meta_2samp)),
  tar_target(parcel_year_meta_2samp_results_grass, two_sample_ttest_grass(parcel_year_meta_2samp)),
  # new
  # tar_target(parcel_year_meta_2samp_results_grass, two_sample_ttest(parcel_year_meta_2samp, "Grass")),
  # tar_target(parcel_year_meta_2samp_results_cover, two_sample_ttest(parcel_year_meta_2samp, "Cover")),

  tar_target(parcel_year_meta_1samp_results, one_sample_ttest(parcel_year_meta_1samp)),
  tar_target(parcel_year_meta_1samp_results_grass, one_sample_ttest_grass(parcel_year_meta_1samp)),
  # tar_target(parcel_year_meta_1samp_results_grass, one_sample_ttest(parcel_year_meta_1samp, "Grass")),
  # tar_target(parcel_year_meta_1samp_results_cover, one_sample_ttest(parcel_year_meta_1samp, "Cover")),

  ## create indicator, counter, sig.counter----
  # tar_target(parcel_year_meta_combined_results, bindttest_count_sig_runs(parcel_year_meta_2samp_results,parcel_year_meta_1samp_results)),
  tar_target(parcel_year_meta_combined_results, bindttest_count_sig_runs(parcel_year_meta_2samp_results_grass,parcel_year_meta_1samp_results_grass,parcel_year_meta_2samp_results,parcel_year_meta_1samp_results)),

  # n, sum.sig, max.run----
  tar_target(parcel_test_sums, parcel_testadd_sums(parcel_year_meta_combined_results)),

  ## join for summary table----
  tar_target(deltas_ttest_att, join_summaries(parcels_deltas,attributes_pfix, parcel_year_meta_combined_results, parcel_test_sums, cYear)),

  ## datatables----
  tar_target(parcel_datatable, make_parcel_data_table(deltas_ttest_att,cYear)),
  tar_target(parcel_datatable_significant, make_parcel_data_table_significant(deltas_ttest_att,cYear)),
  tar_target(parcel_datatable_chronic, make_parcel_data_table_chronic(deltas_ttest_att,cYear)),
  # maps----
  ## join gis parcels to sig tests
  tar_target(parcels_shp_ttest, left_join(parcels_shp, deltas_ttest_att, by = c("PCL"="Parcel"))),
  # tar_target(parcels_shp_ttest, join_ttest_shapefile(parcels_shp, deltas_ttest_att)),
  ## create map of sig tests----
  tar_target(panel_map_lw, panel_map(cYear, parcels_shp_ttest, "Laws", or_shp,streams_shp,canals_shp,laa_shp,lakes_shp, monsites_shp)),
  tar_target(panel_map_bp, panel_map(cYear, parcels_shp_ttest, "Big Pine", or_shp,streams_shp,canals_shp,laa_shp,lakes_shp, monsites_shp)),
  tar_target(panel_map_ta, panel_map(cYear, parcels_shp_ttest, "Taboose-Aberdeen", or_shp,streams_shp,canals_shp,laa_shp,lakes_shp, monsites_shp)),
  tar_target(panel_map_ts, panel_map(cYear, parcels_shp_ttest, "Thibaut-Sawmill", or_shp,streams_shp,canals_shp,laa_shp,lakes_shp, monsites_shp)),
  tar_target(panel_map_io, panel_map(cYear, parcels_shp_ttest, "Independence-Oak", or_shp,streams_shp,canals_shp,laa_shp,lakes_shp, monsites_shp)),
  tar_target(panel_map_ss, panel_map(cYear, parcels_shp_ttest, "Symmes-Shepherd", or_shp,streams_shp,canals_shp,laa_shp,lakes_shp, monsites_shp)),
  tar_target(panel_map_bg, panel_map(cYear, parcels_shp_ttest, "Bairs-George", or_shp,streams_shp,canals_shp,laa_shp,lakes_shp, monsites_shp))

  # tar_target(panel_map_lw_view, panel_map_view(cYear, parcels_shp_ttest, "Laws", or_shp,streams_shp,canals_shp,laa_shp,lakes_shp, monsites_shp))
  # tar_target(panel_map_lp, panel_map(cYear, parcels_shp_ttest, "Lone Pine", or_shp,streams_shp,canals_shp,laa_shp,lakes_shp, monsites_shp))

  # Parcel time series
  ## select parcels - ts plots----
  # tar_target(parcel_select_1sample, c("IND026")),
  # tar_target(parcel_select_2sample, c("BLK094")),

  ## ts plots----
  # try out patch work to assimilate ndvi, cover, dtw, ppt plots
  # tar_target(plot_2sample_timeseries, plot_2samptest_timeseries(parcel_year_meta_2samp_results,cYear,parcel_select_2sample)),
  # tar_target(plot_1sample_timeseries, plot_1samptest_timeseries(parcel_year_meta_1samp_results,cYear,parcel_select_1sample))

  # tar_target(ts5stack, five_row_timeseries(attributes_pfix,transects, dtw_pfix, rs_pfix,cYear),
             # format = "file")

  # tar_render(report, "report.Rmd")
)

# tar_target(fiverow_ts, five_row_timeseries(attributes_pfix, transects, dtw_pfix, rs_pfix, cYear))
