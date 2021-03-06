% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/base-model.R
\name{add_unique_id_constraint}
\alias{add_unique_id_constraint}
\title{Unique ID constraint}
\usage{
add_unique_id_constraint(model, players)
}
\description{
On sites with multi-position eligibility, players will show up once for every
position they are eligible. We want to ensure a player is not selected more than
once on the same lineup
}
\keyword{internal}
