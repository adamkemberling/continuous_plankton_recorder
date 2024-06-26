####  SAHFOS CPR TAXA Key  ####
# Purpose: reduce the number of taxa and their different development stages to match new NOAA CPR data
# Converts  counts per transect to 100 meters cubed to match NOAA data, 
# Then combines traverse and eyecount data for one zooplankton set


####  Packages  ####
library(tidyverse)
library(janitor)


####  Data  ####
mc1_phyto <- read_csv("/Users/akemberling/Box/Climate Change Ecology Lab/Data/Gulf of Maine CPR/2019_data_processing/mc1_phyto_2019.csv")
mc1_eye   <- read_csv("/Users/akemberling/Box/Climate Change Ecology Lab/Data/Gulf of Maine CPR/2019_data_processing/mc1_eyecount_2019.csv")
mc1_trav  <- read_csv("/Users/akemberling/Box/Climate Change Ecology Lab/Data/Gulf of Maine CPR/2019_data_processing/mc1_traverse_2019.csv")
mc1_taxa  <- read_csv("/Users/akemberling/Box/Climate Change Ecology Lab/Data/Gulf of Maine CPR/2019_data_processing/mc1_taxa_key_2019.csv")

mc2_phyto <- read_csv("/Users/akemberling/Box/Climate Change Ecology Lab/Data/Gulf of Maine CPR/2019_data_processing/mc2_phyto_2019.csv")
mc2_eye   <- read_csv("/Users/akemberling/Box/Climate Change Ecology Lab/Data/Gulf of Maine CPR/2019_data_processing/mc2_eyecount_2019.csv")
mc2_trav  <- read_csv("/Users/akemberling/Box/Climate Change Ecology Lab/Data/Gulf of Maine CPR/2019_data_processing/mc2_traverse_2019.csv")
mc2_taxa  <- read_csv("/Users/akemberling/Box/Climate Change Ecology Lab/Data/Gulf of Maine CPR/2019_data_processing/mc2_taxa_key_2019.csv")


#MC1 and MC2 are non-overlapping periods so we can combine into one group
sahfos_trav <- bind_rows(mc1_trav, mc2_trav)
sahfos_eye <- bind_rows(mc1_eye, mc2_eye)
sahfos_phyto <- bind_rows(mc1_phyto, mc2_phyto)

rm(mc1_eye, mc1_phyto, mc1_taxa, mc1_trav)
rm(mc2_eye, mc2_phyto, mc2_taxa, mc2_trav)



####__####

####  1. (100) Meters Cubed Conversion    ####


#Conversions - 

# A. subsample count to full transect

#phyto 1/8000th of transect counted
#traverse 1/40th of transect counted
#eyecount full transect counted

sahfos_trav %>% count(`calanus i-iv`)
sahfos_eye %>% count(`calanus finmarchicus`)


# #Question: are the counts already converted to the number expected for a full transect?
# #ANSWER: Conclusion all three (eye, phyto, traverse) are in numbers per transect

# B. transect to water volume

# 1 transect = 10 nautical miles
# CPR aperture dimensions = 1.27 cm square entrance
# aperture area in square meters = 0.00016129
# 1852 meters in nautical mile * 10
# volume in cubic meters per 10cm silk = 2.987091 meters^3





####  Conversion Rate  ####

# Original calculation to get to # per meters cubed from #/transect
conversion_rate <- 1 / 2.987091

# Multiply that by 100 to get to 100 cubic meters
conversion_rate <- conversion_rate * 100

#Listed by source
sahfos_abundances <- list("traverse" = sahfos_trav   %>% select(11:ncol(sahfos_trav)), 
                          "eyecount" = sahfos_eye    %>% select(11:ncol(sahfos_eye)), 
                          "phyto"    = sahfos_phyto  %>% select(11:ncol(sahfos_phyto)))


# Function to convert units
sahfos_100m3 <-  map(sahfos_abundances, function(x){
  x_meters_cubed <- x * conversion_rate
  return(x_meters_cubed)
})


####__####
####  2. Combine Traverse and eyecount  ####
strav_100m3 <- sahfos_100m3$traverse
seye_100m3  <- sahfos_100m3$eye

# Dataframe comparisons

# #All have the same number of rows, but columns are present in some but not others
# map(sahfos_100m3, dim)
# janitor::compare_df_cols(strav_100m3, seye_100m3)
# janitor::compare_df_cols_same(strav_100m3, seye_100m3)

#Idea, create a dataframe with names found in both, make the values the added contribution from one or both the subsample types
unique_names     <- sort(unique(c(names(strav_100m3), names(seye_100m3))))
new_df           <- data.frame(matrix(0, nrow = nrow(strav_100m3), ncol = length(unique_names)))
colnames(new_df) <- unique_names


#Function to add columns as they appear in either set. 
#Overwrites NA's with zeros
taxa_fill <- function(empty_frame = new_df,  df_1 = strav_100m3, df_2 = seye_100m3) {
  
  #Taxon Names We want for the output
  taxa_names <- colnames(empty_frame)
  
  # 1. Abundances from the traverse subsampling procedure
  
  #Make a list that matches output names
  traverse_counts <- vector(mode = "list", length = length(taxa_names))
  names(traverse_counts) <- taxa_names
  
  # Fill that list with traverse abundances when they match
  traverse_counts <- imap(traverse_counts, function(x,y) {
    #Baseline of 0
    taxa_counts <- rep(0, nrow(df_1))
    
    if(y %in% names(df_1)) {
      taxa_counts <- df_1 %>% select(one_of(y)) %>% pull()
      taxa_counts[is.na(taxa_counts)] <- 0
    }
    
    return(taxa_counts)
  })
  
  #Bind list to a dataframe
  traverse_out <- bind_cols(traverse_counts)
  
  # 2. Abundances from eyecount subsampling procedure
  
  #Make a list that matches output names
  eyecount_counts <- vector(mode = "list", length = length(taxa_names))
  names(eyecount_counts) <- taxa_names
  
  # Fill that list with eyecount abundances
  eyecount_counts <- imap(eyecount_counts, function(x,y) {
    #Baseline of zero
    taxa_counts <- rep(0, nrow(df_2))
    
    if(y %in% names(df_2)) {
      taxa_counts <- df_2 %>% select(one_of(y)) %>% pull()
      taxa_counts[is.na(taxa_counts)] <- 0
    }
    
    return(taxa_counts)
  })
  
  #Bind list to a dataframe
  eyecount_out <- bind_cols(eyecount_counts)
  
  
  #Add the two of them to get combined abundance
  zooplankton_abundances <- traverse_out + eyecount_out
  return(zooplankton_abundances)
  
  
  
  
}



####  Combined Traverse and Eyecounts 
# 1:1 sum of traverse and eyecount abunndances in # per 100 cubic meters
sahfos_zoo <- taxa_fill(empty_frame = new_df, df_1 = strav_100m3, df_2 = seye_100m3)
sahfos_zoo <- bind_cols(sahfos_trav %>% select(1:10), sahfos_zoo)


# Visual Check
sahfos_zoo %>% 
  group_by(year) %>% 
  dplyr::summarise(
    `calanus_v-vi` = sum(`calanus finmarchicus`, na.rm = T),
    `calanus_i-iv` = sum(`calanus i-iv`, na.rm = T)) %>% 
  ggplot() +
  geom_point(aes(year, `calanus_v-vi`, color = "calanus_v-vi")) +
  geom_point(aes(year, `calanus_i-iv`, color = "calanus_i-iv")) +
  scale_y_continuous(labels = scales::comma_format()) +
  labs(y = "Abundance per 100 m3")


#remove unnecesary objects for use when sourcing
rm(new_df, sahfos_abundances, sahfos_eye, sahfos_100m3, sahfos_phyto, sahfos_trav, seye_100m3, strav_100m3)
