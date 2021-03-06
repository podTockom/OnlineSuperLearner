#' CrossValidationRiskCalculator
#' Class that contains various methods for calculating the crossvalidated risk
#' of an estimator.
#'
#' @docType class
#' @importFrom R6 R6Class
#' @import R.utils R.oo
#' @include Evaluation.R
#'
#' @section Methods:
#' \describe{
#'   \item{\code{initialize() }}{
#'     Creates a new cross validated risk calculator.
#'   }
#'
#'   \item{\code{calculate_evaluation(predicted.outcome, observed.outcome, randomVariables, add_evaluation_measure_name=TRUE)}}{
#'     <<description>>
#'     The input data looks as followos:
#'     \code{
#'       normalized
#'       normalized`ML.Local.Speedlm-vanilla.nbins-10_online-FALSE`
#'               W         A         Y
#'       1: 1.94863 0.5234383 0.3501003
#'
#'       normalized`ML.Local.Speedlm-vanilla.nbins-40_online-FALSE`
#'                 W         A         Y
#'       1: 1.818194 0.5234383 0.3501003
#'
#'       denormalized
#'       denormalized`ML.Local.Speedlm-vanilla.nbins-10_online-FALSE`
#'               W         A         Y
#'       1: 10.8308 0.5234383 0.3501003
#'
#'       denormalized`ML.Local.Speedlm-vanilla.nbins-40_online-FALSE`
#'                 W         A         Y
#'       1: 9.889878 0.5234383 0.3501003
#'     }
#'
#'     The output data looks as follows:
#'     \code{
#'      `ML.Local.Speedlm-vanilla.nbins-10_online-FALSE`
#'             #.W        .W2        .W3       .A        .Y
#'      1: 34.53878 0.02225018 -0.0507633 0.545403 -5.335295
#'
#'      `ML.Local.Speedlm-vanilla.nbins-40_online-FALSE`
#'             #.W          .W2         .W3       .A        .Y
#'      1: 34.53878 -0.005705135 -0.03595754 0.545403 -4.499685
#'     }
#'     @param predicted.outcome
#'     @param observed.outcome
#'     @param randomVariables
#'     @param add_evaluation_measure_name
#'   }
#'
#'   \item{\code{calculate_risk(predicted.outcome, observed.outcome, randomVariables}}{
#'     Calculate the CV risk for each of the random variables provided based on
#'     the predicted and observed outcomes.
#'     @param predicted.outcome the outcomes predicted by the algorithms
#'     @param observed.outcome the true outcomes, as empiricaly observed
#'     @param randomVariables the randomvariables for which the distributions have been calculated
#'     @return a list of lists, in which each element is the risk for one estimator. In each list per estimator, each
#'     element corresponds to one of the random variables.
#'   }
#'
#'   \item{\code{update_risk(predicted.outcome, observed.outcome, randomVariables, current_count, current_risk) }}{
#'     
#'     @param predicted.outcome the outcomes predicted by the algorithms
#'     @param observed.outcome the true outcomes, as empiricaly observed
#'     @param randomVariables the randomvariables for which the distributions have been calculated
#'     @param current_count the current number of evaluations performed for calculating the \code{current_risk}.
#'     @param current_risk the previously calculated risk of each of the estimators (calculated over
#'     \code{current_count} number of evaluations).
#'     @return a list of lists with the updated risk for each estimator, and for each estimator an estimate of the risk
#'     for each random variable.
#'   }
#' }
#' @export
CrossValidationRiskCalculator <- R6Class("CrossValidationRiskCalculator",
  public =
    list(
        initialize = function() {
        },

        ## Output is a list of data.tables
        calculate_evaluation = function(predicted.outcome, observed.outcome, randomVariables, add_evaluation_measure_name=TRUE) {
          # predicted.outcome <- Arguments$getInstanceOf(predicted.outcome, 'list')

          ## If there is a normalized field, prefer the normalized outcomes
          if ('normalized' %in% names(predicted.outcome)) predicted.outcome = predicted.outcome$normalized 

          ## Calculate the evaluations
          lapply(predicted.outcome, function(one.outcome) {
            self$evaluate_single_outcome( 
              observed.outcome = observed.outcome,
              predicted.outcome = one.outcome,
              randomVariables = randomVariables,
              add_evaluation_measure_name = add_evaluation_measure_name
            )
          })
        },

        ## Evaluate should receive the outcome of 1 estimator
        evaluate_single_outcome = function(observed.outcome, predicted.outcome, randomVariables, add_evaluation_measure_name) {
          sapply(randomVariables, function(rv) {
            current_outcome <- rv$getY
            lossFn <- Evaluation.get_evaluation_function(family = rv$getFamily, useAsLoss = FALSE)
            result <- lossFn(data.observed = observed.outcome[[current_outcome]],
                              data.predicted = predicted.outcome[[current_outcome]])

            ## Add the name of the evaluation used
            if (add_evaluation_measure_name){
              names(result) <- paste(names(result), current_outcome, sep='.')
            } else {
              names(result) <- current_outcome
            }
            result
          }) %>% t %>% as.data.table
        },

        ## Calculate the CV risk for each of the random variables provided
        ## Output is a list of data.tables
        calculate_risk = function(predicted.outcome, observed.outcome, randomVariables, check=FALSE){
          if ('normalized' %in% names(predicted.outcome)) predicted.outcome = predicted.outcome$normalized
            
          if (check) {
            predicted.outcome <- Arguments$getInstanceOf(predicted.outcome, 'list')
            observed.outcome <- Arguments$getInstanceOf(observed.outcome, 'data.table')
          }

          cv_risk <- lapply(predicted.outcome, function(algorithm_outcome) {
            self$risk_single_outcome(
              observed.outcome = observed.outcome,
              predicted.outcome = algorithm_outcome,
              randomVariables = randomVariables
            )
          })

          return(cv_risk)
        },

        risk_single_outcome = function(observed.outcome, predicted.outcome, randomVariables) {
          result <- lapply(randomVariables, function(rv) {
            current_outcome <- rv$getY
            lossFn <- Evaluation.get_evaluation_function(family = rv$getFamily, useAsLoss = TRUE)
            risk <- lossFn(data.observed = observed.outcome[[current_outcome]],
                           data.predicted = predicted.outcome[[current_outcome]])
            names(risk) <- current_outcome
            risk
          }) 

          ## The unlist t is a hack to flatten the result, but to keep the correct names
          ## that the entries got in the loop.
          as.data.table(t(unlist(result)))
        },

        ## Outcome is a list of datatables
        update_risk = function(predicted.outcome, observed.outcome, randomVariables, current_count, current_risk, check = FALSE) {
          ## Note that we don't need to check whether data is normalized, as we
          ## are passing it to the calculate_risk function, which will pick the
          ## correct one.
          if(check) {
            current_count <- Arguments$getInteger(current_count, c(0, Inf))
            predicted.outcome <- Arguments$getInstanceOf(predicted.outcome, 'list')
            observed.outcome <- Arguments$getInstanceOf(observed.outcome, 'data.table')
            if(is.null(predicted.outcome) || length(predicted.outcome) == 0) throw('Predicted outcome is empty!')
            if(is.null(observed.outcome) || all(dim(observed.outcome) == c(0,0))) throw('Observed outcome is empty!')
          }

          ## Calculate the risk for the current observations / predictions
          updated_risk <- self$calculate_risk(
            predicted.outcome = predicted.outcome,
            observed.outcome = observed.outcome,
            randomVariables = randomVariables
          )

          ## Note that we need to update the risk for every algorithm and every RV
          algorithm_names <- names(updated_risk)

          current_risk <- lapply(algorithm_names, function(algorithm_name) {
            new_risks <- updated_risk[[algorithm_name]]
            old_risk <- current_risk[[algorithm_name]]

            self$update_single_risk(
              old_risk = old_risk, 
              new_risks = new_risks, 
              current_count = current_count, 
              randomVariables = randomVariables
            )
          })

          names(current_risk) <- algorithm_names
          return(current_risk)
        },

        update_single_risk = function(old_risk, new_risks, current_count, randomVariables) {
          lapply(randomVariables, function(rv) {
            current <- rv$getY

            ## The score up to now needs to be calculated current_count times, the other score 1 time.
            ## new_risk <- (1 / (current_count + 1)) * new_risks[[current]]
            new_risk <- new_risks[[current]]

            if(!is.null(old_risk) && is.na(old_risk[[current]])) {
              ## If our previous risk is NA, that means that we had a previous iteration in which we could
              ## not calculate the risk. Most likely because of the initialization of the DOSL. In the next
              ## iteration we can make a prediction, but it is out of sync with the provided count. Therefore,
              ## set the old risk to the new risk and resync with the count.
              old_risk[[current]] <- new_risk
            }

            if(!is.null(old_risk)) {
              new_risk <- (new_risk + (current_count * old_risk[[current]])) / (current_count + 1)
            }

            names(new_risk) <- current
            new_risk
          }) %>% unlist %>% t %>% as.data.table
        }


        ),
  active =
    list(
        ),
  private =
    list(
    )
)
