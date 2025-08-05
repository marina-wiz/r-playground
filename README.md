# r-playground

## Description

Welcome to r-playground, a collection of various R functions and scripts developed for data wrangling, statistical analysis, and visualization. This repository serves as a sandbox where I explore new ideas, test different approaches, and store useful snippets that may not fit neatly into a formal analysis or package.

## Content

- **`match_controls()`** – This function performs case-control matching by taking a dataset of cases and matching each case with observations from a dataset of potential controls. You can specify how many controls to match per case and which characteristics to match on (e.g., age, sex). Each control is used only once. If no suitable match is found, "No controls available" is returned.
- **`group-maps/`** – Generates choropleth maps of racial/ethnic composition and dissimilarity across U.S. metro areas (see its own [README](R/group-maps/README.md)).

More scripts may be added over time as the repository evolves.

## Installation

Clone this repository to your local machine using:

```bash
git clone https://github.com/marina-wiz/r-playground.git
```

Alternatively, you can download the files directly from the GitHub interface.

## Loading the Script

Each script in this repository is self-contained and can be sourced into your R environment as needed. 

```r
source("path/to/script.R")
```

## Usage

### 1. `match_controls()`

```r
# Set seed for reproducibility
set.seed(123)

# Create example dataset for the case group with 100 observations
study_dat <- data.frame(
  ID = 1:100,
  age = sample(20:60, 100, replace = TRUE),
  sex = sample(c("Male", "Female"), 100, replace = TRUE)
)

# Create example dataset for control group with 1000 observations
control_dat <- data.frame(
  ID = 1:1000 + 100,  # IDs start from 101 to avoid overlap with study_dat
  age = sample(20:60, 1000, replace = TRUE),
  sex = sample(c("Male", "Female"), 1000, replace = TRUE)
)

# Match 2 controls to each case based on age and sex variables
matched <- match_controls(study_dat, control_dat,
                          match_cols = c("age", "sex"),
                          id_col = "ID", num_controls = 2)
```



Feel free to explore, adapt, or contribute!
