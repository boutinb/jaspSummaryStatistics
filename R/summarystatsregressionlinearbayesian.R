#
# Copyright (C) 2013-2018 University of Amsterdam
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

SummaryStatsRegressionLinearBayesian <- function(jaspResults, dataset = NULL, options, ...) {

  # NOTE: the qml settings are set up such that this analysis is always "ready". If a user enters incorrect settings,
  # an error is thrown.

  # Error checking
  .summarystatsRegressionCheckErrors(options)

  # get the main container with all dependencies
  mainContainer <- .summaryStatsRegressionMainContainer(jaspResults)
  # Compute the results
  summaryStatsRegressionResults <- .summaryStatsRegressionComputeResults(mainContainer, options)

  # # Output tables and plots
  .summaryStatsRegressionTableMain(     mainContainer, options, summaryStatsRegressionResults)
  .summaryStatsRegressionRobustnessPlot(mainContainer, options, summaryStatsRegressionResults)

  return()
}

# Results functions ----
.summaryStatsRegressionComputeResults <- function(mainContainer, options) {


  # Take results from state if possible
  if (!is.null(mainContainer[["stateSummaryStatsRegressionResults"]]))
    return(mainContainer[["stateSummaryStatsRegressionResults"]]$object)

  # This will be the object that we fill with results
  results <- list(tableInfo                = list(),
                  regressionTable          = list(),
                  regressionRobustnessPlot = list())

  # Run linear regression
  N             <- options$sampleSize
  rScale        <- options$priorRScale
  nCovariatesH0 <- options$nullNumberOfCovariates
  rSquaredH0    <- options$nullUnadjustedRSquared
  nCovariatesH1 <- options$alternativeNumberOfCovariates
  rSquaredH1    <- options$alternativeUnadjustedRSquared

  # Extract relevant information
  tableInfo          <- .tableInfoSummaryStatsRegression(options)
  nullModelSpecified <- tableInfo$nullModelSpecified

  # Conduct Bayesian linear regression for H1
  regressionResultsH1 <- BayesFactor::linearReg.R2stat(N = N, p = nCovariatesH1, R2 = rSquaredH1, rscale = rScale)
  LogBF10_H1          <- regressionResultsH1$bf

  # Add results to results object
  results[["tableInfo"]]       <- tableInfo

  # If specified: conduct Bayesian linear regression for H0
  if(nullModelSpecified) {

    regressionResultsH0 <- BayesFactor::linearReg.R2stat(N = N, p = nCovariatesH0, R2 = rSquaredH0, rscale = rScale)
    LogBF10_H0          <- regressionResultsH0$bf

    # Adjust Bayes factor lists for Allow Model Comparison
    LogBF10             <- LogBF10_H1 - LogBF10_H0
    BFlist_H1           <- list(BF10    = exp(LogBF10),
                                BF01    = 1/exp(LogBF10),
                                LogBF10 = LogBF10)

    # Add results to results object
    results[["regressionTable"]] <- data.frame(
      sampleSize        = c("Null model"                        , "Alternative model"),
      nCovariates       = c(nCovariatesH0                       , nCovariatesH1),
      R2                = c(rSquaredH0                          , rSquaredH1),
      BF                = c(BFlist_H1[["BF01"]]                 , BFlist_H1[["BF10"]]),
      error             = c(regressionResultsH0[["properror"]]  , regressionResultsH1[["properror"]])
    )

    # if user selects LogBF10, log the values in the table
    if(options$bayesFactorType == "LogBF10"){
      results[["regressionTable"]][["BF"]] <- log(results[["regressionTable"]][["BF"]])
    }

  } else {
    # null model is not specified
    BFlist_H1           <- list(BF10    = exp(LogBF10_H1),
                                BF01    = 1/exp(LogBF10_H1),
                                LogBF10 = LogBF10_H1)
    results[["regressionTable"]] <- list(
      sampleSize        = N,
      nCovariates       = nCovariatesH1,
      R2                = rSquaredH1,
      BF                = BFlist_H1[[options$bayesFactorType]],
      error             = regressionResultsH1[["properror"]]
    )
  }

  results[["BFlist"]] <- BFlist_H1

  # Save results to state
  mainContainer[["stateSummaryStatsRegressionResults"]] <- createJaspState(results)

  # Return results object
  return(results)
}

# Main container----
.summaryStatsRegressionMainContainer <- function(jaspResults) {

  mainContainer <- jaspResults[["mainContainer"]]
  if (is.null(mainContainer)) {
    mainContainer <- createJaspContainer(dependencies = c(
      "priorRScale", "bayesFactorType", "sampleSize",
      "nullUnadjustedRSquared"       , "nullNumberOfCovariates",
      "alternativeUnadjustedRSquared", "alternativeNumberOfCovariates"
    ))
    jaspResults[["mainContainer"]] <- mainContainer
  }
  return(mainContainer)
}

# Main table ----
.summaryStatsRegressionTableMain <- function(mainContainer, options, summaryStatsRegressionResults){
  if (!is.null(mainContainer[["regressionTable"]])) return()

  tableResults    <- summaryStatsRegressionResults[["regressionTable"]]

  # extract important parameters
  tableInfo        <- summaryStatsRegressionResults[["tableInfo"]]
  mainResultsTitle <- tableInfo$mainResultsTitle

  # create table and state dependencies
  regressionTable <- createJaspTable(mainResultsTitle)
  regressionTable$position <- 1

  # set title for different Bayes factor types
  sampleSizeTitle    <- tableInfo$sampleSizeTitle
  sampleSizeCellType <- tableInfo$sampleSizeCellType
  bfTitle            <- tableInfo$bfTitle

  # display "BF" instead of "BF10" or "BF01" for Model Comparison
  if(mainResultsTitle == gettext("Model Comparison") && bfTitle != "Log(\u0042\u0046\u2081\u2080)"){
      bfTitle <- "BF"
    }

  # set table citations and footnote message for different hypothesis types
  regressionTable$addCitation(.summaryStatsCitations[c("LiangEtAl2008", "RounderMoreyInPress")])


  message <- tableInfo[["message"]]
  if (!is.null(message)) regressionTable$addFootnote(message)

  regressionTable$addColumnInfo(name = "sampleSize" , title = sampleSizeTitle                , type = sampleSizeCellType)
  regressionTable$addColumnInfo(name = "nCovariates", title = gettext("Number of covariates"), type = "integer")
  regressionTable$addColumnInfo(name = "R2"         , title = gettextf("R%s", "\u00B2")      , type = "number", format = "dp:3")
  regressionTable$addColumnInfo(name = "BF"         , title = bfTitle                        , type = "number")
  regressionTable$addColumnInfo(name = "error"      , title = gettextf("error %%")             , type = "number")

  mainContainer[["regressionTable"]] <- regressionTable

  # extract rows from tableResults
  regressionTable$addRows(tableResults)
}

# # Robustness plot ----
.summaryStatsRegressionRobustnessPlot <- function(mainContainer, options, summaryStatsRegressionResults) {

  # createJaspPlot...
  if (!options[["bfRobustnessPlot"]] || !is.null(mainContainer[["bfRobustnessPlot"]]))
    return()

  plot <- createJaspPlot(title = gettext("Robustness Plot"), width = 530, height = 400)
  plot$dependOn(c("bfRobustnessPlot", "bfRobustnessPlotAdditionalInfo"))
  mainContainer[["bfRobustnessPlot"]] <- plot
  if (mainContainer$getError())
    return()

  p <- try(.summaryStatsRegressionCreateRobustnessPlot(options, summaryStatsRegressionResults))
  if (isTryError(p)) {
    errorMessage <- gettextf("Plotting not possible: %s", .extractErrorMessage(p))
    plot$setError(errorMessage)
  } else {
    plot$plotObject <- p
  }
}

.summaryStatsRegressionCreateRobustnessPlot <- function(options, summaryStatsRegressionResults) {

  rscale         <- options[["priorRScale"]]
  additionalInfo <- options[["bfRobustnessPlotAdditionalInfo"]]
  BFH1H0         <- options[["bayesFactorType"]] != "BF01"

  tableInfo <- summaryStatsRegressionResults[["tableInfo"]]
  nullModelSpecified    <- tableInfo[["nullModelSpecified"]]

  #### get BFs ###
  if(rscale > 1.5) {
    rValues <- seq(0.0005, 2, length.out = 535)
  } else {
    rValues <- seq(0.0005, 1.5, length.out = 400)
  }

  if(nullModelSpecified) {
    computeBF <- function(options, rscale) {
      sampleSize                    <- options[["sampleSize"]]
      nullNumberOfCovariates        <- options[["nullNumberOfCovariates"]]
      alternativeNumberOfCovariates <- options[["alternativeNumberOfCovariates"]]
      nullUnadjustedRSquared        <- options[["nullUnadjustedRSquared"]]
      alternativeUnadjustedRSquared <- options[["alternativeUnadjustedRSquared"]]
      BFNull <- BayesFactor::linearReg.R2stat(N = sampleSize, p = nullNumberOfCovariates, R2 = nullUnadjustedRSquared, rscale = rscale)
      BFAlternative <- BayesFactor::linearReg.R2stat(N = sampleSize, p=alternativeNumberOfCovariates, R2=alternativeUnadjustedRSquared, rscale = rscale)

      return(.clean(exp(BFAlternative[["bf"]] - BFNull[["bf"]])))
    }
  } else {
    computeBF <- function(options, rscale) {
      sampleSize                    <- options[["sampleSize"]]
      alternativeNumberOfCovariates <- options[["alternativeNumberOfCovariates"]]
      alternativeUnadjustedRSquared <- options[["alternativeUnadjustedRSquared"]]

      BF <- BayesFactor::linearReg.R2stat(N = sampleSize, p=alternativeNumberOfCovariates, R2=alternativeUnadjustedRSquared, rscale = rscale)
      return(.clean(exp(BF[["bf"]])))
    }
  }

  BF10 <- numeric(length(rValues))
  for (i in seq_along(rValues))
    BF10[i] <- computeBF(options, rValues[i])

  # get BF for "medium", "wide", and "ultrawide" prior
  BF10m     <- computeBF(options, sqrt(2) / 2)
  BF10w     <- computeBF(options, 1)
  BF10ultra <- computeBF(options, sqrt(2))

  maxBF10 <- max(BF10)
  maxBFrVal <- rValues[which.max(BF10)]

  dfLines <- data.frame(
    x = rValues,
    y = log(BF10)
  )

  if (BFH1H0) {
    bfType <- "BF10"
    BF10user <- summaryStatsRegressionResults[["BFlist"]][["BF10"]]
  } else {
    bfType <- "BF01"
    dfLines$y <- -dfLines$y
    BF10user  <- summaryStatsRegressionResults[["BFlist"]][["BF01"]]
    maxBF10   <- max(1/BF10)
    maxBFrVal <- rValues[which.max(1/BF10)]
    BF10w     <- 1 / BF10w
    BF10ultra <- 1 / BF10ultra
  }

  BFsubscript <-  jaspTTests::.ttestBayesianGetBFnamePlots(BFH1H0, c(-Inf, Inf), subscriptsOnly = TRUE)

  label1 <- c(
    gettextf("max BF%s", BFsubscript),
    gettext("user prior"),
    gettext("wide prior"),
    gettext("ultrawide prior")
  )
  # some failsafes to parse translations as expressions
  label1[1] <- gsub(pattern = "\\s+", "~", label1[1])
  label1[-1] <- paste0("\"", label1[-1], "\"")
  label1 <- paste0("paste(", label1, ", ':')")

  BFandSubscript <- gettextf("BF%s", BFsubscript)
  BFandSubscript <- gsub(pattern = "\\s+", "~", BFandSubscript)
  label2 <- c(
    gettextf("%1$s at r==%2$s",      format(maxBF10,  digits = 4), format(maxBFrVal, digits = 4)),
    paste0(BFandSubscript, "==", format(BF10user, digits = 4)),
    paste0(BFandSubscript, "==", format(BF10w,    digits = 4)),
    paste0(BFandSubscript, "==", format(BF10ultra,digits = 4))
  )
  label2[1L] <- gsub(pattern = "\\s+", "~", label2[1])

  if (additionalInfo) {
  dfPoints <- data.frame(
    x = c(maxBFrVal, rscale, 1, sqrt(2)),
    y = log(c(maxBF10, BF10user, BF10w, BF10ultra)),
    g = label1,
    label1 = jaspGraphs::parseThis(label1),
    label2 = jaspGraphs::parseThis(label2),
    stringsAsFactors = FALSE
  )
  } else {
    dfPoints <- NULL
  }

  plot <- jaspGraphs::PlotRobustnessSequential(
    dfLines      = dfLines,
    dfPoints     = dfPoints,
    pointLegend  = additionalInfo,
    xName        = gettext("r scale"),
    hypothesis   = "equal",
    bfType       = bfType
  )

  return(plot)

}


# helper functions
.tableInfoSummaryStatsRegression <- function(options) {

  # set footnote message and Bayes factor title
  message      <- gettextf("r scale used is: %s.", options$priorRScale)
  bfTitle      <- .getBayesfactorTitleSummaryStats(options$bayesFactorType, alternative = 'twoSided')

  # determine title for main results table
  nullModelSpecified <- TRUE
  if(options$nullNumberOfCovariates==0 && options$nullUnadjustedRSquared==0) nullModelSpecified <- FALSE

  if(nullModelSpecified) {

    mainResultsTitle   <- gettext("Model Comparison")
    sampleSizeTitle    <- gettextf("n = %i", options$sampleSize)
    sampleSizeCellType <- "string"


  } else {

    mainResultsTitle   <- gettext("Bayesian Linear Regression")
    sampleSizeTitle    <- gettext("n")
    sampleSizeCellType <- "integer"

  }

  return(list(message            = message,
              bfTitle            = bfTitle,
              mainResultsTitle   = mainResultsTitle,
              sampleSizeTitle    = sampleSizeTitle,
              sampleSizeCellType = sampleSizeCellType,
              nullModelSpecified = nullModelSpecified)
  )
}
.summarystatsRegressionCheckErrors <- function(options){

  # check if number of covariates is correct in H1
  if(options$alternativeNumberOfCovariates!=0 && options$sampleSize!=0 && ((options$sampleSize - options$alternativeNumberOfCovariates) < 2)) {

    .quitAnalysis(gettext("Number of Covariates must be less than N-1 (sample size minus 1)"))

  }

  # check if number of covariates is correct in H0
  if(options$nullNumberOfCovariates!=0 && options$sampleSize!=0 && ((options$sampleSize - options$nullNumberOfCovariates) < 2)) {

    .quitAnalysis(gettext("Number of Covariates must be less than N-1 (sample size minus 1)"))

  }

  # check if R squared input is correct
  if((options$alternativeNumberOfCovariates > options$nullNumberOfCovariates) && (options$alternativeUnadjustedRSquared < options$nullUnadjustedRSquared)) {

    .quitAnalysis(gettextf("Input: When number of covariates for Alternative hypothesis is greater than that of Null hypothesis, the R%s has to be higher under Alternative than under Null hypothesis","\u00B2"))
  }

}
