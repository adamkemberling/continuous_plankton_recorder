####  Helper Functions  ####

#Set ggplot theme
ggplot2::theme_set(ggplot2::theme_classic())



#' @title Locate Data Path on Box
#' @description Safely navigate to box path within GMRI in lieu of here function
#'
#' @param box_project_name 
#'
#' @return box_path project directory string for box project data
#' @export
#'
#' @examples
find_box_data <- function(box_project_name) {
  box_project <- as.character(box_project_name)
  box_path <- str_c("/Users/akemberling/Box/Adam Kemberling/Box_Projects/", paste(box_project))
  return(box_path)
}

# # Set the main paths - originals
# cpr_boxpath <- find_box_data("continuous_plankton_recorder")
# ccel_boxpath <- "/Users/akemberling/Box/Climate Change Ecology Lab"

# Change to use gmRi::cs_path()
cpr_boxpath <- gmRi::cs_path("root", "Adam Kemberling/Box_Projects/continuous_plankton_recorder")
ccel_boxpath <- gmRi::cs_path("ccel")



#' Floor Decade
#'
#' @param year_vector Vector of integer years
#' @param return_class String indicating output type for the vector, factor or numeric
#'
#' @return decade_vector returned vector of years rounded down to their decade
#' @export
#'
#' @examples
floor_decade <- function(year_vector, return_class = "factor"){ 
  
  if(class(year_vector) == "numeric") {
    decade_vector <- year_vector - year_vector %% 10
  }
  
  if(class(year_vector) %in% c("factor", "character")) {
    year_vector <- as.numeric(as.character(year_vector))
    decade_vector <- year_vector - year_vector %% 10
  }
  
  if(return_class == "factor") {
    decade_vector <- factor(decade_vector)
    
  }
  
  return(decade_vector)
}

#' @title Apply Principal Component Loadings to Data Matrix
#'
#' @param pca_load The data we wish do apply loadings to. Must have same column dimensions as the PCA dataset.
#' @param pca_rotations Roatations obtained from the PCA object (results from porcomp())
#' @param mode_num The Principal component loading to apply as an integer
#'
#' @return pca_adjusted dataframe containing original values of pca_load adjusted by the selected PCA loading's weights
#' @export
#'
#' @examples
apply_pca_load <- function(pca_load, pca_rotations, mode_num = 1) {
  
  #Pull PCA rotations/loadings
  rotations <- as.data.frame(pca_rotations)
  rotations_t <- t(rotations)
  
  #Principal component whose weights we want to apply
  mode_num <- as.integer(mode_num)
  
  #Copy of the initial values to apply them to
  pca_adjusted <- pca_load[, 2:ncol(pca_load)]
  
  #Multiply the columns by their PCA weights
  for (i in 1:ncol(rotations_t)) {
    pca_adjusted[, i] <- pca_adjusted[, i] * rotations_t[mode_num, i]
    
  }
  
  return(pca_adjusted)
}


 
#' @title Extract Percent Deviance Explained
#' @description Extract % variance explained from PCA object. Useful when
#' plotting PCA modes in situations where you want to show deviance explained
#' and have it update with new pca.
#'
#' @param pca_sdev 
#'
#' @return
#' @export
#'
#' @examples
pull_deviance <- function(pca_sdev) {
  
  eigs <- pca_sdev ^ 2
  
  deviance_df <- rbind(
    SD = sqrt(eigs),
    Proportion = eigs/sum(eigs),
    Cumulative = cumsum(eigs)/sum(eigs))
  
  pca_dev_out <- data.frame(
    "PC1" = str_c(as.character(round(deviance_df[2,1] * 100, 2)), "% of Variance"),
    "PC2" = str_c(as.character(round(deviance_df[2,2] * 100, 2)), "% of Variance"))
  
  return(pca_dev_out)
  
}


####  Corrplot Functions  ####

#' @title Pull Time Periods for Corrplots
#'
#' @param time_period Time period of interest identifying the "period" value to extract
#'
#' @return 
#' @export
#'
#' @examples
pull_period <- function(cpr_long_df = cpr_sst, time_period = annual) {
  
  plankton_ts <- cpr_long_df %>% 
    filter(period %in% c("Annual", "annual")) %>% 
    pivot_wider(names_from = taxa, values_from = anomaly) %>% 
    select(year, one_of(species_05))
  
  temp_ts <- cpr_long_df %>% 
    distinct(year, period, .keep_all = T) %>% 
    pivot_wider(names_from = period, values_from = temp_anomaly) %>% 
    select(year, one_of(time_period)) #%>%  setNames(c("year", "period"))
  
  df_out <- inner_join(plankton_ts, temp_ts, by = "year") %>% drop_na()
  return(df_out)
  
}




#' Extract upper triangle of the correlation matrix
#'
#' @param correlation_matrix Correlation matrix object created by cor()
#'
#' @return correlation_matrix Correlation matrix with NA values substituted for lower-triangle correlations
#' @export
#'
#' @examples
get_upper_tri <- function(correlation_matrix){
  correlation_matrix[lower.tri(correlation_matrix)] <- NA
  return(correlation_matrix)
}





 
#' Pull correlations and p-values for Correlogram
#'
#' @param wide_df 
#'
#' @return
#' @export
#'
#' @examples
corr_plot_setup <- function(wide_df) {
  
  # 1. Pull data used for corellation matrix
  corr_data <- wide_df %>% 
    select(-year#, -period
           )
  
  # 2. Pull the correlation matrix and melt to a dataframe
  corr_mat <- corr_data %>% cor() 
  
  # 2b. Correlation Matrix as a dataframe
  corr_out <- corr_mat %>% reshape2::melt(na.rm = TRUE)
  
  # 2c. Upper Triangle of correlation matrix
  upper_tri <- corr_mat %>% 
    get_upper_tri() %>%
    reshape2::melt() %>% 
    drop_na()
  
  # 3. do it again but pull the p-values
  p_data <- corrplot::cor.mtest(corr_mat)$p 
  
  #Assign the same names as the corr matrix
  dimnames(p_data) <- dimnames(corr_mat)
  
  #reshape to match correlation df
  p_data <- reshape2::melt(p_data, na.rm = T) %>% dplyr::rename(pval = value)
  
  
  #Put the two together
  corr_full <- inner_join(corr_out, p_data, by = c("Var1", "Var2")) %>% 
    #Format levels and labels
    mutate(Var1 = fct_relevel(Var1, sort),
           Var2 = fct_relevel(Var2, sort),
           sig_symbol = if_else(pval <= 0.05 & value > 0, "+", " "),
           sig_symbol = if_else(pval <= 0.05 & value < 0, "-", sig_symbol))
  
  return(corr_full)
}

#Not in Function
`%notin%` <- purrr::negate(`%in%`)


#' CPR Correlogram
#'
#' @param corr_dataframe 
#' @param period 
#' @param plot_style 
#' @param taxa 
#'
#' @return
#' @export
#'
#' @examples
cpr_corr_plot <- function(corr_dataframe, period = "Q1", plot_style = "tall", taxa = NULL){
  
  #Filter Var1 and Var2 to reshape plot
  
  #Taxa
  if(is.null(taxa)) {
    my_taxa <- c("calanus", "calanus1to4", "centropages", "chaetognatha",
                 "euphausiacea", "metridia", "oithona", "para_pseudocalanus",
                 "paraeucheata", "temora")} 
  else{my_taxa = taxa}
  
  # Plot the long corrplot
  long_plot <- corr_dataframe %>% 
    filter(Var1 %notin% my_taxa,
           Var2 %in% my_taxa) %>% 
    mutate(Var2 = factor(Var2, levels = my_taxa))
  
  # plot the tall version
  tall_plot <- corr_dataframe %>% 
    filter(Var1 %in% my_taxa,
           Var2 %notin% my_taxa) %>% 
    mutate(Var1 = factor(Var1, levels = my_taxa))
  
  if(plot_style == "tall") {
    plot_option  <- tall_plot
    leg_position <- "right"
  } else {
    plot_option  <- long_plot
    leg_position <- "bottom"
  }
  
  # Clean it up
  ggplot(plot_option, aes(x = Var1, y = fct_rev(Var2), fill = value)) +
    geom_tile(color = "white") +
    geom_text(aes(label = sig_symbol), 
              color = "black", 
              size = 3) +
    scale_fill_gradient2(low = "blue", 
                         high = "red", 
                         mid = "white", 
                         midpoint = 0, 
                         limit = c(-1,1), 
                         space = "Lab", 
                         name = "Pearson\nCorrelation") +
    labs(x = NULL, 
         y = NULL, 
         title = period) +
    theme(axis.text.x = element_text(angle = 45, vjust = 1, hjust = 1, size = 6),
          axis.text.y = element_text(size = 6),
          legend.position = leg_position,
          axis.text = element_text(color = "black")) +
    coord_fixed() 
  
  
}


