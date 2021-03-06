% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/InterventionEffectCalculator.R
\docType{class}
\name{InterventionEffectCalculator}
\alias{InterventionEffectCalculator}
\title{InterventionEffectCalculator}
\format{An object of class \code{R6ClassGenerator} of length 24.}
\usage{
InterventionEffectCalculator
}
\description{
InterventionEffectCalculator
}
\section{Methods}{

\describe{
  \item{\code{perform_initial_estimation(data, intervention, tau) }}{ 
    This function can be used to generate an initial estimation, calculated using the plain OSL. This method then
    returns a value given the provided data, tau, and intervention.
    @param data the data to seed the sampling procedure.
    @param intervention the intervention itself, see \code{InterventionParser} for more details
    @param tau the time at which we want to evaluate the intervention
  } 
}
}

\keyword{datasets}
