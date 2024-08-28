# Case-Control Matching

match_controls <- function(study_data, control_data,
                           match_cols, id_col, num_controls = 2) {

  # Create a copy of the control data to avoid modifying the original
  control_data_copy <- control_data

  # Initialize columns for control IDs in the study dataset.
  for (n in 1:num_controls) {
    study_data[[paste0("Control.", n, ".ID")]] <- NA
  }

  # Loop through each row in the study dataset
  for (i in 1:nrow(study_data)) {
    # Create a logical vector to match on the specified columns
    matches <- rep(TRUE, nrow(control_data_copy))

    for (col in match_cols) {
      matches <- matches & (control_data_copy[[col]] == study_data[[col]][i])
    }

    # Filter the control data for rows that match cases on all specified columns
    matching_controls <- control_data_copy[matches, ]

    if (nrow(matching_controls) >= num_controls) {
      picks <- sample(matching_controls[[id_col]], num_controls)

      # Store the sampled IDs in the study dataset
      for (n in 1:num_controls) {
        study_data[[paste0("Control.", n, ".ID")]][i] <- picks[n]
      }
      
      # Remove the selected controls from the control dataset to avoid reuse
      control_data_copy <- control_data_copy[
        !control_data_copy[[id_col]] %in% picks, ]
    } else {
      
      # If not enough controls are available, set "No controls available"
      for (n in 1:num_controls) {
        study_data[[paste0("Control.", n, ".ID")]][i] <- "No controls available"
      }
    }
  }
  return(study_data)
}