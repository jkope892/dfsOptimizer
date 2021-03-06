setGeneric('add_additional_constraints', function(object) standardGeneric('add_additional_constraints'))
#' Add additional constraints
#'
#' @param object Optimizer model object
#'
#' @details Adds constraints from object configuration.
#'
#' @return The Optimizer object with an updated model.
#'
#' @aliases add_additional_constraints
#'
#' @export
setMethod('add_additional_constraints', signature = 'optimizer',
          definition = function(object) {

            if (length(object@constraints) > 0) {
              for (CON in object@constraints){
                object@model <- apply_constraint(CON, model = object@model, players = object@players)
              }
            }
            return(object)
          })


#' Including Constraints
#' @param x Optimizer object
#' @param constraint_object an object of constraint class
#' @keywords internal
setGeneric('include_constraint', function(x, constraint_object) standardGeneric('include_constraint'))
setMethod('include_constraint', 'optimizer',
          function(x, constraint_object) {
            # This will add to the list if the field doesn't exist, but
            # replace it if it does. Makes it less likely to add various definitions
            # of the same constraint
            x@constraints[[constraint_object@constraint_name]] <- constraint_object
            return(x)
          })


setGeneric('add_players_from_csv', function(object, filepath, custom = FALSE) standardGeneric('add_players_from_csv'))
#' Add players to optimizer from CSV
#'
#' @param object An optimizer model object
#' @param filepath Filepath location of the CSV
#' @param custom Set to TRUE to use user-generated CSVs with player data; the data will be
#'     parsed using \code{get_players_from_date_frame}
#'
#' @return Optimizer model object with slot \code{players} filled
#'
#' @examples
#' \dontrun{
#' opt <- create_optimizer(site = 'DRAFTKINGS', sport = 'HOCKEY', contest_type = 'CLASSIC')
#' opt <- add_players_from_csv(object = opt, filepath = '/Path/to/file.csv')
#' }
#'
#' @aliases add_players_from_csv
#'
#' @export
setMethod(f = 'add_players_from_csv',
          signature = 'optimizer',
          definition = function(object, filepath, custom = FALSE) {

            # Read in the players and put them in the players slot
            if (custom) {
              dat <- data.table::fread(filepath, stringsAsFactors = FALSE)
              object@players <- get_players_from_data_frame(dat)
            } else {
              object@players <- get_players_from_csv(object, path = filepath)
            }
            return(object)
          })


setGeneric('add_players_from_df', function(object, df) standardGeneric('add_players_from_df'))
#' Add players to optimizer from a data.frame
#'
#' @param object An optimizer model object
#' @param df a data.frame of players to add to the model
#'
#' @return Optimizer model object with slot \code{players} filled
#'
#' @examples
#' \dontrun{
#' opt <- create_optimizer(site = 'DRAFTKINGS', sport = 'HOCKEY', contest_type = 'CLASSIC')
#' dat <- data.frame(first_name = c('Sidney','Alex'),
#'                  last_name = c('Crosby','Ovechkin'),
#'                  fpts = c(18,20),
#'                  team = c('PIT','WAS'),
#'                  position = c('C','W'),
#'                  salary = c(8000,9000),
#'                  game_info = c('this will be','ignored anyway'),
#'                  max_exposure = c(0.3, 0.6))
#' opt <- add_players_from_df(object = opt, df = dat)
#' }
#'
#' @aliases add_players_from_df
#'
#' @export
setMethod(f = 'add_players_from_df',
          signature = 'optimizer',
          definition = function(object, df) {
            # Read in the players and put them in the players slot
            object@players <- get_players_from_data_frame(df = df)
            return(object)
          })


setGeneric('add_team_stack', function(object, positions, opt_positions=NULL, nstacks = 1, within_lines = FALSE) standardGeneric('add_team_stack'))
#' Add a Team Stack
#'
#' @param object An optimizer model object
#' @param positions Positions to stack within same team
#' @param opt_positions A vector of optional positions. Used to build OR-based stacks, such as QB + WR + (TE or RB).
#'     Always selects just one of the optional positions.
#' @param nstacks Number of stacks to include (Default is 1)
#' @param within_lines Logical. Whether Stacks should be built within lines or depth. If 'sport' is not hockey, this is ignored.
#'
#' @return Updated optimizer object
#'
#' @examples
#' \dontrun{
#' opt <- create_optimizer(site = 'DRAFTKINGS', sport = 'HOCKEY', contest_type = 'CLASSIC')
#' opt <- add_players_from_csv(object = opt, filepath = '/Path/to/file.csv')
#'
#' # Add team stack, requiring a Center and Two Wingers from the same team
#' opt <- add_team_stack(object = opt, positions = c('C','W','W'))
#'
#' # Add team stack, with a Center and a Winger, and one of either another center or winger
#' opt <- add_team_stack(object = opt, positions = c('C','W'), opt_positions = c('C','W'))
#' }
#'
#' @aliases add_team_stack
#'
#' @export
setMethod(f = 'add_team_stack',
          signature = 'optimizer',
          definition = function(object, positions, opt_positions = NULL, nstacks = 1, within_lines = FALSE) {

            # Silenty change within_lines to FALSE if sport is not 'HOCKEY'
            if (within_lines && object@sport != 'HOCKEY') {
              within_lines <- FALSE
            }

            # Create constraint
            CON <- .constraintClass(constraint_name = "Team Stack Constraint",
                                    fnc = constr_team_stack,
                                    args = list(positions = positions, opt_positions = opt_positions, nstacks = nstacks, within_lines = within_lines))

            # Add it to the config object
            object <- include_constraint(object, CON)

            return(object)

          })


setGeneric('restrict_opposing_positions', function(object, pos1, pos2) standardGeneric('restrict_opposing_positions'))
#' Restrict Opposing Positions
#'
#' @param object An optimizer object
#' @param pos1 Positions for set one
#' @param pos2 Positions for set two
#'
#' @return Updated optimizer object
#'
#' @details Prevents positions from opposing teams from being included in lineups.
#'
#' @examples
#' \dontrun{
#' opt <- create_optimizer(site = 'DRAFTKINGS', sport = 'HOCKEY', contest_type = 'CLASSIC')
#' opt <- add_players_from_csv(object = opt, filepath = '/Path/to/file.csv')
#'
#' # Restrict lineup from having Skaters and Goalies from opposite teams
#' opt <- restrict_opposing_positions(object = opt, pos1 = c('C','W','D'), pos2 = 'G')
#' }
#'
#' @aliases restrict_opposing_positions
#'
#'@export
setMethod(f = 'restrict_opposing_positions',
          signature = 'optimizer',
          definition = function(object, pos1, pos2) {

            # Create constraint
            CON <- .constraintClass(constraint_name = "Opposing Positions Restriction",
                                    fnc = constr_restrict_opposing_position,
                                    args = list(pos1 = pos1, pos2 = pos2))

            # Add it to the config object
            object <- include_constraint(object, CON)

            return(object)

          })


setGeneric('force_opposing_positions', function(object, pos1, pos2) standardGeneric('force_opposing_positions'))
#' Force Opposing Positions
#'
#' @param object An optimizer object
#' @param pos1 Position for team one
#' @param pos2 Position for opposing team
#'
#' @return Updated optimizer object
#'
#' @details Forces positions from opposing teams from being included in lineups. Currently accepts a maximum
#' of two positions.
#'
#' @examples
#' \dontrun{
#' opt <- create_optimizer(site = 'DRAFTKINGS', sport = 'FOOTBALL', contest_type = 'CLASSIC')
#' opt <- add_players_from_csv(object = opt, filepath = '/Path/to/file.csv')
#'
#' # Force lineup to include a QB and a WR from the opposing team
#' opt <- force_opposing_positions(object = opt, pos1 = 'QB', pos2 = 'WR')
#' }
#'
#' @aliases force_opposing_positions
#'
#'@export
setMethod(f = 'force_opposing_positions',
          signature = 'optimizer',
          definition = function(object, pos1, pos2) {

            # Create constraint
            CON <- .constraintClass(constraint_name = "Force Opposing Restrictions",
                                    fnc = constr_force_opposing,
                                    args = list(pos1 = pos1, pos2 = pos2))

            # Add it to the config object
            object <- include_constraint(object, CON)

            return(object)

          })


setGeneric('set_players_per_team', function(object, players_per_team, exact = FALSE) standardGeneric('set_players_per_team'))
#' Set Number of Players per Team
#'
#' @param object An optimizer object
#' @param players_per_team A named list, where the names are teams, and the values are
#' the number of players to include for each team
#' @param exact Logical. Whether the number in \code{players_per_team} is the maximum
#' number of players to include, or the exact number of players to include.  If scalar,
#' the value of EXACT applies to every team in \code{players_per_team}. This also accepts
#' a vector with length of \code{players_per_team} that can be used to set some teams to
#' EXACT values, and others to MAX values (See examples below).
#'
#' @description Method used to set team specific exposures.  Note, you can set one
#' EXACT and one MAX set of team restrictions per model.
#'
#' @return Updated optimizer object
#'
#' @examples
#' \dontrun{
#' # 'opt' is an optimizer model object
#'
#' # Force the lineup to include a maximum of two players
#' # from BUF, and prevent any CLE players from being
#' # included in the lineup
#' opt <- set_players_per_team(object = opt,
#'        players_per_team = list(BUF = 2, CLE = 0))
#'
#' # Set lineup to include exactly three SF players
#' opt <- set_players_per_team(object = opt, players_per_team = list(SF = 3), exact = TRUE)
#'
#' # Include up to 3 players from NYG, and exactly two players from TEN
#' opt <- set_players_per_team(object = opt,
#'          players_per_team = list(NYG = 3, TEN = 2),
#'          exact = c(FALSE, TRUE))
#' }
#'
#'
#' @aliases set_players_per_team
#'
#' @export
#'
setMethod('set_players_per_team',
          signature = 'optimizer',
          definition = function(object, players_per_team, exact = FALSE) {

            # Calculations for Checks
            if (length(exact) == 1) {
              sum_where_exact <- sum(as.numeric(players_per_team)[rep(exact, length(players_per_team))])
              len_where_exact <- length(players_per_team[rep(exact, length(players_per_team))])
            } else {
              sum_where_exact <- sum(as.numeric(players_per_team)[exact])
              len_where_exact <- length(players_per_team[exact])
            }

            # Make sure we aren't violating the roster size rule
            if (sum_where_exact > roster_size(object@config)) {
              stop("Sum of players per team is greater than the allowed roster size")
            }

            # Check that we have enough teams represented
            # If sum(team_filter == roster_size && length(team_filter) < min_team_req) then stop(...)
            if (sum_where_exact == roster_size(object@config) &&
                len_where_exact < min_team_req(object@config)) {
              stop('Players per team configuration violates minimum team requirement')
            }

            # Build the constraint
            CON <- .constraintClass(constraint_name = "Set Players Per Team",
                                    fnc = constr_players_per_team,
                                    args = list(players_per_team = players_per_team, exact = exact))

            # Add it to the model
            object <- include_constraint(object, CON)

            return(object)

          })


##### Setting Functions #####
setGeneric('set_min_budget', function(object, min_budget) standardGeneric('set_min_budget'))
#' @title Set the minimum budget for the model
#'
#' @param object An optimizer object
#' @param min_budget The minimum budget value
#'
#' @description Used to set a lower-bound budget for all lineups
#'
#' @return Updated optimizer object
#'
#' @examples
#' \dontrun{
#' # Set the minimum budget to 40000
#' opt <- opt %>%
#'   set_min_budget(40000)
#' }
#'
#' @aliases set_min_budget
#'
#' @export
setMethod(f = 'set_min_budget',
          signature = 'optimizer',
          definition = function(object, min_budget) {
            set_min_budget(object@config) <- min_budget
            return(object)
          })


setGeneric('set_max_budget', function(object, max_budget) standardGeneric('set_max_budget'))
#' @title Set the maximium budget for the model
#'
#' @param object An optimizer object
#' @param max_budget The max budget value
#'
#' @description Used to set a upper-bound budget for all lineups
#'
#' @return Updated optimizer object
#'
#' @examples
#' \dontrun{
#' # Set the maximum budget to 45000
#' opt <- opt %>%
#'   set_max_budget(45000)
#' }
#'
#' @aliases set_max_budget
#'
#' @export
setMethod(f = 'set_max_budget',
          signature = 'optimizer',
          definition = function(object, max_budget) {
            set_max_budget(object@config) <- max_budget
            return(object)
          })


setGeneric('set_max_exposure', function(object, exposure) standardGeneric('set_max_exposure'))
#' @title Set the Global Max Exposure
#'
#' @param object An optimizer object
#' @param exposure Value to set the exposure
#'
#' @description Method to set the global max exposure of an optimizer model.
#'
#' @return Updated Optimizer object
#'
#' @aliases set_max_exposure
#'
#' @export
setMethod(f = 'set_max_exposure',
          signature = 'optimizer',
          definition = function(object, exposure) {
            set_max_exposure(object@config) <- exposure
            return(object)
          })


setGeneric('set_max_overlap', function(object, overlap) standardGeneric('set_max_overlap'))
#' @title Set the maximum overlap
#'
#' @param object An optimizer object
#' @param overlap Maximum player overlap across lineups
#'
#' @description Method to set the max overlap of an optimizer model.
#'
#' @return Updated Optimizer object
#'
#' @examples
#' \dontrun{
#' opt <- create_optimizer(site = 'DRAFTKINGS', sport = 'HOCKEY', contest_type = 'CLASSIC')
#' opt <- add_players_from_csv(object = opt, filepath = '/Path/to/file.csv')
#'
#' # update the max overlap
#' opt <- set_max_overlap(object = opt, overlap = 6)
#' }
#'
#' @aliases set_max_overlap
#'
#' @export
setMethod(f = 'set_max_overlap',
          signature = 'optimizer',
          definition = function(object, overlap) {
            set_max_overlap(object@config) <- overlap
            return(object)
          })


setGeneric('set_min_teams', function(object, min_teams) standardGeneric('set_min_teams'))
#' @title Set minimum team requirement
#'
#' @param object An optimizer object
#' @param min_teams The minimum number of teams to include
#'
#' @details WARNING: You can very easily make your lineup ineligible for a site by doing things
#' like \code{set_min_teams(object, min_teams = 1)}
#'
#' @examples
#' \dontrun{
#' # Set minimum number of teams to 6
#' opt <- set_min_teams(opt, min_teams = 6)
#' }
#'
#' @aliases set_min_teams
#'
#' @export
setMethod('set_min_teams',
          signature = 'optimizer',
          definition = function(object, min_teams) {
            set_min_team_req(object@config) <- as.integer(min_teams)
            return(object)
          })


setGeneric('set_max_teams', function(object, max_teams) standardGeneric('set_max_teams'))
#' @title Set minimum team requirement
#'
#' @param object An optimizer object
#' @param max_teams The maximum number of teams to include
#'
#' @details WARNING: You can very easily make your lineup ineligible for a site by doing things
#' like \code{set_max_teams(object, max_teams = 1)}
#'
#' @examples
#' \dontrun{
#' # Set minimum number of teams to 6
#' opt <- set_max_teams(opt, max_teams = 6)
#' }
#'
#' @aliases set_max_teams
#'
#' @export
setMethod('set_max_teams',
          signature = 'optimizer',
          definition = function(object, max_teams) {
            set_max_team_req(object@config) <- as.integer(max_teams)
            return(object)
          })


setGeneric('set_global_variance', function(object, variance) standardGeneric('set_global_variance'))
#' @title Set the Global Variance
#'
#' @param object An optimizer object
#' @param variance Value to set the variance
#'
#' @description Method to set the global variance of an optimizer model.
#'
#' @return Updated Optimizer object
#'
#' @examples
#' \dontrun{
#' # Set Optimizer global variance to 10%
#' opt <- opt %>%
#'    set_global_variance(variance = .10)
#' }
#'
#' @aliases set_global_variance
#'
#' @export
setMethod(f = 'set_global_variance',
          signature = 'optimizer',
          definition = function(object, variance) {
            set_variance(object@config) <- variance
            return(object)
          })


setGeneric('set_flex_positions', function(object, positions) standardGeneric('set_flex_positions'))
#' @title Set the FLEX/UTIL position list
#'
#' @param object An optimizer object
#' @param positions Value to set the roster size (subject to validity checks).
#'
#' @description Method for setting FLEX/UTIL positions. Can be used to limit FLEX/UTIL to a user-specified
#'    set of possible positions (see examples).
#'
#' @return Updated Optimizer object
#'
#' @examples
#' \dontrun{
#' opt <- create_optimizer(site = 'DRAFTKINGs', sport = 'HOCKEY')
#' opt <- add_players_from_csv(object = opt, filepath = '/Path/to/file.csv')
#'
#' # Default FLEX is c('C','W','D') -- here we'll remove D
#' opt <- set_flex_positions(object = opt, positions = c('C','W'))
#' }
#'
#' @aliases set_flex_positions
#'
#' @export
setMethod(f = 'set_flex_positions',
          signature = 'optimizer',
          definition = function(object, positions) {
            flxind <- which(names(roster_key(object@config)) == flex_position(object@config))
            for (i in flxind) {
              object@config@roster_key[[i]]$positions <- positions
            }
            return(object)
          })


setGeneric('set_multiplier_position', function(object, positions) standardGeneric('set_multiplier_position'))
#' @title Set Possible positions for Multiplier slot
#'
#' @param object An optimizer object
#' @param positions Value to set the roster size (subject to validity checks).
#'
#' @description Method for setting positions for Single Game multiplier positions (e.g., CPT in Draftkings Captain-mode).
#'    Can be used to limit the multiplier position to a user-specified set of possible positions (see examples).
#'
#' @return Updated Optimizer object
#'
#' @examples
#' \dontrun{
#' opt <- create_optimizer(site = 'DRAFTKINGS', sport = 'HOCKEY', contest_type = 'SHOWDOWN')
#' opt <- add_players_from_csv(object = opt, filepath = '/Path/to/file.csv')
#'
#' # Default Multiplier-position options are c('C','W','D','G')
#' # Remove D and G
#' opt <- set_multiplier_position(object = opt, positions = c('C','W'))
#' }
#'
#' @aliases set_multiplier_position
#'
#' @export
setMethod(f = 'set_multiplier_position',
          signature = 'SingleGameOptim',
          definition = function(object, positions) {
            ind <- which(names(roster_key(object@config)) == multiplier_name(object@config))
            for (i in ind) {
              object@config@roster_key[[i]]$positions <- positions
            }
            return(object)
          })


#'@keywords internal
setGeneric('apply_global_variance', function(object, varpct) standardGeneric('apply_global_variance'))
setMethod(f = 'apply_global_variance', signature = 'optimizer',
          function(object, varpct) {
            # For any players with NA variance, replace with varpct
            object@players <- lapply(object@players, function(P) {
              # If NA, use global, else, use primary
              if (is.na(variance(P))) {
                P <- set_variance(P, variance(object@config))
              }
              return(P)
            })
            return(object)
          })


#' @keywords internal
setGeneric('apply_variance', function(object) standardGeneric('apply_variance'))
setMethod(f = 'apply_variance',
          signature = 'optimizer',
          definition = function(object) {
            object@players <- lapply(object@players, 'apply_variance')
            return(object)
          })


#### Methods
## Extraction
#' Extracting Fantasy Points from Player objects
#'
#' @param object an optimizer object
#'
#' @keywords internal
setGeneric("extract_player_fpts", function(object) standardGeneric("extract_player_fpts"))
setMethod('extract_player_fpts',
          signature = 'optimizer',
          definition = function(object) {
            if (length(object@players) == 0) {
              message('No Players in optimizer!')
              out <- NULL
            } else {
              out <- sapply(object@players, fpts)
            }
            return(out)
          })


setGeneric('get_player_data', function(object) standardGeneric('get_player_data'))
#' Get Player data from optimizer object
#'
#' @param object An optimizer object
#'
#' @details In addition to the optimizer object, this method can be run on a player object
#' to provide details about that single player.
#'
#' @return Data.table containing information about the players.
#'
#' @aliases get_player_data
#'
#' @export
setMethod('get_player_data', 'optimizer',
          function(object){

            players <- lapply(object@players, get_player_data)
            return(data.table::rbindlist(players))

          })


setGeneric('get_player_id', function(object, name, team, position) standardGeneric('get_player_id'))
#' Get a Player Id
#'
#' @param object Object of class Optimizer
#' @param name Full name of player
#' @param team team abbreviation of player (Optional)
#' @param position position of player (Optional)
#'
#' @details \code{team} and \code{position} can be included to differentiate between two players with the same name, but who play for different teams and/or at different positions.
#'
#' @aliases get_player_id
#'
#' @export
setMethod(f = 'get_player_id',
          signature = 'optimizer',
          definition = function(object, name, team, position) {

            pdata <- get_player_data(object)

            # Go by name
            player <- pdata[fullname == name]

            if (!missing(team)) {
              TM <- team
              player <- player[team == TM]
            }

            if (!missing(position)) {
              POS <- position
              player <- player[position == POS]
            }

            if (nrow(player) == 0) {
              message('Player not found!')
              return(invisible(NULL))
            } else {
              return(as.character(player$id))
            }

          })


##### Lineup Methods #####
setGeneric('new_lineup_object', function(object, num_lineups) standardGeneric('new_lineup_object'))
setMethod('new_lineup_object',
          'ClassicOptim',
          function(object, num_lineups) {
            lc <- new('lineupClassic',
                      num_lineups = num_lineups,
                      lineups = vector('list', num_lineups))
            return(lc)
          })


setMethod('new_lineup_object',
          'SingleGameOptim',
          function(object, num_lineups) {
            lc <- new('lineupSingle',
                      num_lineups = num_lineups,
                      lineups = vector('list', num_lineups))
            return(lc)
          })


setGeneric('format_lineup', function(object, lineup, ...) standardGeneric('format_lineup'))
setMethod('format_lineup', 'ClassicOptim',
          function(object, lineup, ...) {
            # Reorder lineup
            return(reorder_lineup(lineup, object@config))
          })


setMethod('format_lineup', 'SingleGameOptim',
          function(object, lineup, ...) {
            # Reorder lineup
            lineup[, roster_position := flex_position(object@config)]
            if (object@config@multiplier_mode) {
              # Player indeces
              all_player_indx <- which(ompr::get_solution(list(...)$fit_model, players[i])$value==1)
              multiplier_indx <- which(ompr::get_solution(list(...)$fit_model, captain[i])$value==1)
              reorder_indx    <- unique(c(which(multiplier_indx == all_player_indx), order(all_player_indx)))

              lineup <- lineup[reorder_indx, ]
              lineup[1, roster_position := object@config@multiplier_name]
              lineup[1, c('salary','fpts') :=
                       list(salary * 1.5,
                            fpts * 1.5)]
            }

            return(lineup)
          })



#' Toggle Multiplier Mode
#'
#' @param object An object of class Optimizer
#'
#' @details Toggles the Multiplier mode (where a player's salary and fpts are multiplied by a given value, usually 1.5)
#'     for single-game / showdown contest types.  For Classic contest_types, this function has no effect.
#'
#' @aliases toggle_multiplier_mode
#'
#' @export
setGeneric('toggle_multiplier_mode', function(object) standardGeneric('toggle_multiplier_mode'))

#' @inherit toggle_multiplier_mode
setMethod('toggle_multiplier_mode', 'SingleGameOptim', function(object) {
  object@config@multiplier_mode <- !object@config@multiplier_mode
  print(paste0('MULTIPLIER MODE IS ', ifelse(object@config@multiplier_mode, 'ON', 'OFF')))
  return(object)
})


#' @inherit toggle_multiplier_mode
setMethod('toggle_multiplier_mode', 'ClassicOptim', function(object) {
  return(object)
})
