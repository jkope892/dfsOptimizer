% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/get-players-from-csv.R
\name{get_players_from_csv,DraftkingsOptim-method}
\alias{get_players_from_csv,DraftkingsOptim-method}
\alias{get_players_from_csv}
\title{Create Players from CSV}
\usage{
\S4method{get_players_from_csv}{DraftkingsOptim}(object, path)
}
\arguments{
\item{object}{Optimizer object}

\item{path}{Path to CSV or text file}
}
\description{
Create Players from CSV
}
\details{
Reads a CSV from a specified site, and generates objects of Player class (one per row)
}
