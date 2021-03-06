#' Reorder lineups
#'
#' @param lineup the lineup output
#' @param config The config slot of the current optimizer. Used to determine the order, and eligible positions.
#'
#' @keywords internal
reorder_lineup <- function(lineup, config) {

  # Use roster_key to get order
  new_order <- get_roster_order(config)

  # Get eligible positions for each
  eligible_positions <- lapply(config@roster_key, function(rk) rk$positions)

  # add a column for inserting values
  lineup$posindex <- NA
  for (i in seq_along(new_order)) {
    O <- new_order[i]

    # Get indeces
    order_index  <- i
    elig_posits  <- eligible_positions[[O]]
    lineup_index <- make_position_indicator(posvec = lineup$position, target = elig_posits)

    # Gets rid of the positions already filled
    lineup_index <- setdiff(lineup_index, which(!is.na(lineup$posindex)))
    lineup$posindex[lineup_index[1]] <- order_index
  }

  # There will be NAs for UTIL/FLEX
  # So it may behave a little funny in the multi-position circumstances
  na_loc <- setdiff(1:length(new_order), lineup$posindex)
  lineup$posindex[is.na(lineup$posindex)] <- na_loc

  lineup <- lineup[order(posindex)]
  lineup$posindex <- NULL
  lineup$roster_position <- new_order

  return(lineup)
}


#' Parse roster key item
#'
#' @param rk Roster key from configuration object
#'
#' @details This function will take all single and multiplayer slots from the roster key, and
#'     build a table containing mins/maxes for each position.  These are then used to set the
#'     value of how many of each position is allowable in a lineup.
#'
#' @keywords internal
parse_roster_key <- function(rk) {

  # lapply through roster key
  by_row <- lapply(rk, function(i) {
    if (length(i$positions)==1) {
      # Set max and min to the number of players for that position
      out <- data.frame(pos = i$positions, min = i$num, max = i$num, stringsAsFactors = FALSE)
    } else if (length(i$positions > 1)) {
      # Set max to the number of players for those positions leaving min as 0
      out <- data.frame(pos = i$positions, min = 0, max = i$num, stringsAsFactors = FALSE)
    } else {
      # Break because it means there was no position
      stop("Length of 'positions' is less than 1!")
    }
  })

  # Sum the mins and maxes up by position
  sum_table <- data.table::rbindlist(by_row)[, list(min = sum(min), max = sum(max)), by = pos]

  return(sum_table)
}


#' Calculate Player percentages across lineups
#'
#' @param lineups a list of lineups
#'
#' @keywords internal
get_player_summary <- function(lineups) {
  Percent <- NULL
  num_comp_lineups <- sum(!sapply(lineups, is.null))
  all_lineups <- data.table::rbindlist(lineups)
  freq <- all_lineups[,
                      list(Lineups = .N, Percent = .N/num_comp_lineups * 100),
                      by = 'fullname'][order(-Percent)]
  freq <- data.table::setnames(freq, 'fullname','Player')
  return(freq)
}


#' Calculate Team percentages across lineups
#'
#' @param lineups a list of lineups
#'
#' @keywords internal
get_team_summary <- function(lineups) {
  num_comp_lineups <- sum(!sapply(lineups, is.null))
  all_lineups <- data.table::rbindlist(lineups)
  return(table(all_lineups$team))
}


#' Calculate a 'similarity measure'
#'
#' @param lineups a list of lineups
#'
#' @keywords internal
calc_jaccard_distance <- function(lineups) {
  # Mean Jaccard distance
  pair_jaccard <- numeric(0)

  if (length(lineups) <= 1) {
    return(NA)
  }

  for (i in 1:(length(lineups) - 1)) {
    for (j in (i + 1):length(lineups)) {
      list1 <- lineups[[i]]$id
      list2 <- lineups[[j]]$id
      pair_jaccard <- c(pair_jaccard,
                       length(intersect(list1, list2)) / length(union(list1, list2)))
    }
  }
  return(1 - mean(pair_jaccard))
}
