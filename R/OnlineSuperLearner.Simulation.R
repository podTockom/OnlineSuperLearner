#' OnlineSuperLearner.Simulation runs different simulations on the superlearner object.
#' You can run an example using:
#' suppressWarnings(devtools::load_all()); OnlineSuperLearner.Simulation$new()
#'
#' @docType class
#' @importFrom R6 R6Class
#' @importFrom doParallel registerDoParallel
#' @importFrom foreach foreach
#' @include RandomVariable.R
#' @include OutputPlotGenerator.R
#' @include OneStepEstimator.R
#' @include SMGFactory.R
#' @include SMG.Latest.Entry.R
#' @include SMG.Lag.R
#' @include SMG.Transformation.R
#' @include InterventionEffectCalculator.R
#' @export
OnlineSuperLearner.Simulation <- R6Class("OnlineSuperLearner.Simulation",
  public =
    list(
        initialize = function(configuration = NULL) {
          tic <- Sys.time()
          cat('Starting calculation with ', parallel::detectCores(),' cores\n')
          doParallel::registerDoParallel(cores = parallel::detectCores())

          options(warn=1)
          private$sim  <- Simulator.GAD$new()
          private$training_set_size <- 1e4

          OutputPlotGenerator.export_key_value('training-set-size', private$training_set_size)
          private$cv_risk_calculator <- CrossValidationRiskCalculator$new()
          private$test_set_size <- 1000
          private$log <- Arguments$getVerbose(-1, timestamp=TRUE)
          #private$log <- FALSE
          #algos <- list(list(description='ML.H2O.randomForest-1tree',
                                  #algorithm = 'ML.H2O.randomForest',
                                  #params = list(ntrees = 1)))

          #algos <- append(algos, list(list(description='ML.H2O.randomForest-50trees',
                                  #algorithm = 'ML.H2O.randomForest',
                                  #params = list(ntrees = 50))))

          #algos <- append(algos, list(list(description='ML.H2O.gbm',
                                  #algorithm = 'ML.H2O.gbm')))
          nbins <- c(40, 100, 1000)
          algos <- list()


          alphas <- runif(3,0,1)
          alphas <- c(0, alphas)
          alphas <- c(0, 0.961941410787404, 0.523852014588192, 0.193227538373321)

          #lambdas <- runif(3,0,1)
          algos <- append(algos, list(list(algorithm = 'ML.XGBoost',
                                  algorithm_params = list(alpha = alphas), 
                                  params = list(nbins = nbins, online = FALSE))))

          #algos <- append(algos, list(list(algorithm = 'ML.H2O.gbm',
                                  #algorithm_params = list(ntrees=c(10,20), min_rows=1),
                                  #params = list(nbins = c(6), online = TRUE))))

          #algos <- append(algos, list(list(algorithm = 'ML.H2O.randomForest',
                                  #algorithm_params = list(ntrees=c(10,20)),
                                  #params = list(nbins = nbins, online = TRUE))))

          #algos <- append(algos, list(list(algorithm = 'ML.SVM',
                                  ##algorithm_params = list(),
                                  #params = list(nbins = nbins, online = FALSE))))

          #algos <- append(algos, list(list(algorithm = 'ML.NeuralNet',
                                  ###algorithm_params = list(),
                                  #params = list(nbins = nbins, online = TRUE))))

          #algos <- append(algos, list(list(algorithm = 'ML.randomForest',
                                  #algorithm_params = list(ntrees=c(500,1000)),
                                  #params = list(nbins = nbins, online = FALSE))))

          algos <- append(algos, list(list(algorithm = 'ML.Local.Speedlm',
                                  #algorithm_params = list(),
                                  params = list(nbins = nbins, online = FALSE))))

          #algos <- append(algos, list(list(algorithm = 'ML.GLMnet',
                                  ##algorithm_params = list(alpha = alphas),
                                  #params = list(nbins = nbins, online = FALSE))))

          #algos <- append(algos, list(list(algorithm = 'condensier::glmR6',
                                  ##algorithm_params = list(),
                                  #params = list(nbins = c(39, 40), online = FALSE))))

          private$SL.library.definition <- algos


          # Run the simulations
          if(is.null(configuration)) {
            self$configuration2(2)
          } else {
            id = configuration
            configuration = (as.numeric(configuration) - 1) %% 4 + 1 
            if (configuration == 1) {
              self$configuration1(id)
            } else if (configuration == 2) {
              self$configuration2(id)
            } else if (configuration == 3) {
              self$configuration3(id)
            } else {
              self$configuration4(id)
            }
          }

          toc <- Sys.time()
          time.taken <- toc - tic
          print(time.taken)
        },

        configuration1 = function(id) {
          set.seed(12345)

          # Generate the true data generating distributions
          llW <- list(stochMech=function(numberOfBlocks) {
              rnorm(numberOfBlocks, 0, 1)
            },
            param=c(1),
            rgen=identity
          )

          llA <- list(
            stochMech=function(ww) {
              rbinom(length(ww), 1, expit(ww))
            },
            param=c(0.5),
            rgen=function(xx, delta=0.05){
              probability <- delta+(1-2*delta)*expit(xx)
              rbinom(length(xx), 1, probability)
            }
          )

          llY <- list(rgen={function(AW){
              aa <- AW[, "A"]
              ww <- AW[, grep("[^A]", colnames(AW))]
              mu <- aa*(0.9) + (1-aa)*(0.3) + rnorm(length(aa), 0, 1)
              mu <- lapply(mu, function(x) max(min(x, 1),0)) %>% unlist
              rbinom(length(aa), 1, mu)
            }}
          )

          # We'd like to use the following features in our estimation:
          W <- RandomVariable$new(formula = W ~ Y_lag_1 + A_lag_1 +  W_lag_1 + Y_lag_2, family = 'gaussian')
          A <- RandomVariable$new(formula = A ~ W + Y_lag_1 + A_lag_1 + W_lag_1, family = 'binomial')
          Y <- RandomVariable$new(formula = Y ~ A + W, family = 'binomial')
          randomVariables <- c(W, A, Y)

          # Generate a dataset we will use for testing.
          # Create the measures we'd like to include in our model
          # In this simulation we will include 2 lags and the latest data (non lagged)
          # Define the variables in the initial dataset we'd like to use
          #private$train(data.test, data.train, bounds, randomVariables, 2)
          intervention <- list(variable = 'A',
                               when = c(3), 
                               what = c(1))
          control <- list(variable = 'A',
                               when = c(3), 
                               what = c(0))


          private$train(intervention = intervention,
                        control = control,
                        randomVariables, Y,  max_iterations = 100,
                        llW = llW,
                        llA = llA, 
                        llY = llY,
                        configuration = id)
        },

        configuration2 = function(id) {
          set.seed(12345)

          ######################################
          # Generate observations for training #
          #####################################
          llW <- list(
            list(stochMech = function(numberOfBlocks) {
                rnorm(numberOfBlocks, 0, 10)
              },
              param=c(1),
              rgen=identity),
            list(stochMech = function(numberOfBlocks) {
                runif(numberOfBlocks, 0, 1)
              },
              param=c(1),
              rgen = identity),
            list(stochMech = function(numberOfBlocks) {
                runif(numberOfBlocks, 0, 1)
              },
              param=c(1),
              rgen = identity)
          )

          llA <- list(
            stochMech=function(ww) {
                rbinom(length(ww), 1, expit(ww))
            },
            #param=c(-0.1, 0.1, 0.3, 0.7),
            param=c(0.5),
            rgen=function(xx, delta=0.05){
              probability <- delta+(1-2*delta)*expit(xx)
              rbinom(length(xx), 1, probability)
            }
          )

          llY <- list(rgen={function(AW){
              aa <- AW[, "A"]
              ww <- AW[, grep("[^A]", colnames(AW))]
              mu <- aa*(0.9) + (1-aa)*(0.3) + rnorm(length(aa), 0, 0.01)
              mu <- lapply(mu, function(x) max(min(x, 1),0)) %>% unlist
            }}
          )

          llY <- list(rgen={function(AW){
            aa <- AW[, "A"]
            ww <- AW[, grep("[^A]", colnames(AW))]
            mu <- 0.5 * ww + 0.3 * (1-aa) + 0.9 * aa 
            42 + rnorm(length(mu), mu, sd=1)
            }}
          )

          # We'd like to use the following features in our estimation:
          W  <- RandomVariable$new(family = 'gaussian', formula = W  ~ Y_lag_1 + W2_lag_1 + A_lag_1 +  W_lag_1 + Y_lag_2)
          W2 <- RandomVariable$new(family = 'gaussian', formula = W2 ~ W_lag_1)
          W3 <- RandomVariable$new(family = 'gaussian', formula = W3 ~ Y_lag_1)
          A  <- RandomVariable$new(family = 'binomial', formula = A  ~ W + Y_lag_1 + A_lag_1 + W_lag_1)
          Y  <- RandomVariable$new(family = 'gaussian', formula = Y  ~ A + W + Y_lag_1 + A_lag_1 + W_lag_1)
          randomVariables <- c(W, W2, W3, A, Y)

          # Create the measures we'd like to include in our model
          # In this simulation we will include 2 lags and the latest data (non lagged)
          # Define the variables in the initial dataset we'd like to use

          # Create the measures we'd like to include in our model
          # In this simulation we will include 2 lags and the latest data (non lagged)
          # Define the variables in the initial dataset we'd like to use
          intervention <- list(variable = 'A',
                               when = c(3), 
                               what = c(1))

          control <- list(variable = 'A',
                               when = c(3), 
                               what = c(0))

          private$train(intervention = intervention,
                        control = control,
                        randomVariables, 
                        Y,
                        max_iterations = 10, llW, llA, llY,
                        configuration = id)
        },

        configuration3 = function(id) {
          set.seed(12345)

          # Generate the true data generating distributions
          llW <- list(stochMech=function(numberOfBlocks) {
              rnorm(numberOfBlocks, 0, 1)
            },
            param=c(0, 0.5, -0.25, 0.1),
            rgen=identity
          )

          llA <- list(
            stochMech=function(ww) {
              rbinom(length(ww), 1, expit(ww))
            },
            param=c(-0.1, 0.1, 0.25),
            rgen=function(xx, delta=0.05){
              probability <- delta+(1-2*delta)*expit(xx)
              rbinom(length(xx), 1, probability)
            }
          )

          llY <- list(rgen={function(AW){
              aa <- AW[, "A"]
              ww <- AW[, grep("[^A]", colnames(AW))]
              mu <- aa*(0.9) + (1-aa)*(0.3) + rnorm(length(aa), 0, 1)
              mu <- lapply(mu, function(x) max(min(x, 1),0)) %>% unlist
              rbinom(length(aa), 1, mu)
            }}
          )

          # We'd like to use the following features in our estimation:
          W <- RandomVariable$new(formula = W ~ Y_lag_1 + A_lag_1 +  W_lag_1 + Y_lag_2, family = 'gaussian')
          A <- RandomVariable$new(formula = A ~ W + Y_lag_1 + A_lag_1 + W_lag_1, family = 'binomial')
          Y <- RandomVariable$new(formula = Y ~ A + W, family = 'binomial')
          randomVariables <- c(W, A, Y)

          # Create the measures we'd like to include in our model
          # In this simulation we will include 2 lags and the latest data (non lagged)
          # Define the variables in the initial dataset we'd like to use
          #private$train(data.test, data.train, bounds, randomVariables, 2)
          intervention <- list(variable = 'A',
                               when = c(2), 
                               what = c(1))

          control <- list(variable = 'A',
                               when = c(2), 
                               what = c(0))

          private$train(intervention = intervention,
                        control = control,
                        randomVariables,
                        Y,  max_iterations = 100,
                        llW = llW,
                        llA = llA, 
                        llY = llY,
                        configuration = id)
        },

        configuration4 = function(id) {
          set.seed(12345)

          ######################################
          # Generate observations for training #
          #####################################
          llW <- list(
            list(stochMech = function(numberOfBlocks) {
                rnorm(numberOfBlocks, 0, 10)
              },
              param=c(0, 0.5, -0.25, 0.1),
              rgen=identity),
            list(stochMech = function(numberOfBlocks) {
                runif(numberOfBlocks, 0, 1)
              },
              param=c(0, 0.5, -0.25, 0.1),
              rgen = identity),
            list(stochMech = function(numberOfBlocks) {
                runif(numberOfBlocks, 0, 1)
              },
              param=c(0, 0.5, -0.25, 0.1),
              rgen = identity)
          )

          llA <- list(
            stochMech=function(ww) {
                rbinom(length(ww), 1, expit(ww))
            },
            param=c(-0.1, 0.1, 0.3, 0.7),
            rgen=function(xx, delta=0.05){
              probability <- delta+(1-2*delta)*expit(xx)
              rbinom(length(xx), 1, probability)
            }
          )

          llY <- list(rgen={function(AW){
              aa <- AW[, "A"]
              ww <- AW[, grep("[^A]", colnames(AW))]
              mu <- aa*(0.9) + (1-aa)*(0.3) + rnorm(length(aa), 0, 0.01)
              mu <- lapply(mu, function(x) max(min(x, 1),0)) %>% unlist
            }}
          )

          llY <- list(rgen={function(AW){
            aa <- AW[, "A"]
            ww <- AW[, grep("[^A]", colnames(AW))]
            mu <- 0.5 * ww + 0.3 * (1-aa) + 0.9 * aa 
            42 + rnorm(length(mu), mu, sd=1)
            }}
          )

          # Create the measures we'd like to include in our model
          # In this simulation we will include 2 lags and the latest data (non lagged)
          # Define the variables in the initial dataset we'd like to use
          # We'd like to use the following features in our estimation:
          W  <- RandomVariable$new(family = 'gaussian', formula = W  ~ Y_lag_1 + W2_lag_1 + A_lag_1 +  W_lag_1 + Y_lag_2)
          W2 <- RandomVariable$new(family = 'gaussian', formula = W2 ~ W_lag_1)
          W3 <- RandomVariable$new(family = 'gaussian', formula = W3 ~ Y_lag_1)
          A  <- RandomVariable$new(family = 'binomial', formula = A  ~ W + Y_lag_1 + A_lag_1 + W_lag_1)
          Y  <- RandomVariable$new(family = 'gaussian', formula = Y  ~ A + W + Y_lag_1 + A_lag_1 + W_lag_1)
          randomVariables <- c(W, W2, W3, A, Y)


          # Create the measures we'd like to include in our model
          # In this simulation we will include 2 lags and the latest data (non lagged)
          # Define the variables in the initial dataset we'd like to use

          intervention <- list(variable = 'A',
                               when = c(2), 
                               what = c(1))

          control <- list(variable = 'A',
                               when = c(2), 
                               what = c(0))

          private$train(intervention = intervention,
                        control = control,
                        randomVariables, 
                        Y,
                        max_iterations = 100, llW, llA, llY,
                        configuration = id)
        },

        configuration5 = function() {
        }
  ),
  private =
    list(
        sim = NULL,
        training_set_size = NULL,
        test_set_size = NULL,
        log = NULL,
        SL.library.definition = NULL,
        cv_risk_calculator = NULL,

        train = function(intervention, control, randomVariables, variable_of_interest, max_iterations, llW, llA, llY, configuration) {

          tic <- Sys.time()

          # Initialize variables
          tau <- 3
          B <- 100
          B_oos <- 50
          N <- 10 
          margin <- 100

          result.dosl.mean                 <- -1
          result.dosl_control.mean         <- -1
          result.dosl.mean.updated         <- -1
          result.dosl_control.mean.updated <- -1
          result.osl.mean                  <- -1
          result.osl_control.mean          <- -1
          result.osl.mean.updated          <- -1
          result.osl_control.mean.updated  <- -1
          result.approx.mean               <- -1
          result.approx_control.mean       <- -1
          result.dosl                      <- rep(0.5, B)
          result.dosl_control              <- rep(0.5, B)
          result.osl                       <- rep(0.5, B)
          result.osl_control               <- rep(0.5, B)
          osl_options <- c('nothing')
          oos_options <- c('nothing')

          # Generate a dataset we will use for testing.
          # We add a margin so we don't have to worry about the presence of enough history
          data.test <- private$sim$simulateWAY(private$test_set_size + margin, qw=llW, ga=llA, Qy=llY, verbose=private$log)
          data.train <- private$sim$simulateWAY(private$training_set_size + margin, qw=llW, ga=llA, Qy=llY, verbose=private$log)

          # Create the bounds
          bounds <- PreProcessor.generate_bounds(data.train)

          outcome.variables <- sapply(randomVariables, function(rv) rv$getY)
          smg_factory <- SMGFactory$new()

          pre_processor <- PreProcessor$new(bounds = bounds)
          summaryMeasureGenerator <- smg_factory$fabricate(randomVariables, pre_processor = pre_processor)

          Data.Static$new(dataset = data.test) %>%
            summaryMeasureGenerator$setData(.)
          data.test <- summaryMeasureGenerator$getNext(private$test_set_size)

          data.train <- Data.Static$new(dataset = data.train)

          private$log && cat(private$log, 'Initializing OSL')
          osl <- OnlineSuperLearner$new(private$SL.library.definition,
                                        summaryMeasureGenerator = summaryMeasureGenerator,
                                        pre_processor = pre_processor,
                                        verbose = private$log)

          private$log && cat(private$log, 'Running OSL')

          initial_training_set_size <- floor(private$training_set_size / 2)
          mini_batch_size <- max((private$training_set_size / 2) / max_iterations, 1)
          mini_batch_size <- ifelse(is.na(mini_batch_size) || is.infinite(mini_batch_size), 1, floor(mini_batch_size))

          # Store the configuration
          key_output = paste('variables_', configuration,'.dat', sep='')
          OutputPlotGenerator.export_key_value('initial-training-set-size', initial_training_set_size, output=key_output)
          OutputPlotGenerator.export_key_value('minibatch-size', mini_batch_size, output=key_output)
          OutputPlotGenerator.export_key_value('max-iterations', max_iterations, output=key_output)
          OutputPlotGenerator.export_key_value('total-iterations', max_iterations+1, output=key_output)

          # Divide by two here just so the initial size is a lot larger then each iteration, not really important
          risk <- osl$fit(data.train, randomVariables = randomVariables,
                                initial_data_size = initial_training_set_size,
                                max_iterations = max_iterations,
                                mini_batch_size = mini_batch_size) %T>% print


          private$log && cat(private$log, 'Predicting using all estimators')

          # Calculate prediction quality
          observed.outcome <- data.test[, outcome.variables, with=FALSE]
          predicted.outcome <- osl$predict(data = copy(data.test), randomVariables, plot= TRUE, sample=FALSE)$normalized
          sampled.outcome <- osl$predict(data = copy(data.test), randomVariables, plot= TRUE, sample=TRUE)$normalized

          Evaluation.log_loss(data.predicted = predicted.outcome$osl.estimator$Y, data.observed = observed.outcome$A)
          Evaluation.log_loss(data.predicted = predicted.outcome$dosl.estimator$Y, data.observed = observed.outcome$A)

          performance <- 
            private$cv_risk_calculator$calculate_evaluation(predicted.outcome = predicted.outcome,
                                                            observed.outcome = observed.outcome,
                                                            randomVariables = randomVariables) 

          key_performance = paste('performance_cfg_', configuration, sep='')
          OutputPlotGenerator.create_risk_plot(performance=performance, output=key_performance)

          key_performance = paste('risk_cv_cfg_', configuration, sep='')
          OutputPlotGenerator.create_risk_plot(performance=osl$get_cv_risk(), output=key_performance)

          key_performance = paste('performance_summary_cfg_', configuration, sep='')
          OutputPlotGenerator.create_risk_plot(performance=performance, output=key_performance, make_summary=TRUE, label='total.evaluation')

          key_performance = paste('risk_cv_summary_cfg_', configuration, sep='')
          OutputPlotGenerator.create_risk_plot(performance=osl$get_cv_risk(), output=key_performance, make_summary=TRUE, label='total.risk')

          OutputPlotGenerator.create_training_curve(osl$get_historical_cv_risk, 
                                                    randomVariables = randomVariables,
                                                    output = paste('curve',configuration, sep='_'))

          toc <- Sys.time()
          time.taken <- toc - tic
          print(time.taken)

          key <- paste('cfg', configuration, 'time-taken-training', sep='-')
          key <- paste('cfg', configuration, 'time-taken-training', sep='-')
          OutputPlotGenerator.export_key_value(key, output=key_output, time.taken)

          tic <- Sys.time()
          data.train$reset
          summaryMeasureGenerator$setData(data.train)
          data.train.set <- summaryMeasureGenerator$getNext(private$training_set_size)

          OutputPlotGenerator.export_key_value(output=key_output, 'iterations', B)
          OutputPlotGenerator.export_key_value(output=key_output, 'simulation-number-of-observations', N)

          intervention_effect_caluculator = InterventionEffectCalculator$new(bootstrap_iterations = B, 
                                                                             randomVariables = randomVariables, 
                                                                             outcome_variable = variable_of_interest$getY,
                                                                             verbose = private$log,
                                                                             parallel = TRUE)
          
          pre <- options('warn')$warn
          options(warn=-1)

          data.aisset <- copy(data.train.set)

          cat('Approximating truth...\n')
          result.approx <- foreach(i=seq(B)) %dopar% {
            cat('Approximating truth in iteration (under intervention): ', i, '\n')
            data.int <- private$sim$simulateWAY(tau, qw = llW, ga = llA, Qy = llY,
                                              intervention = intervention, verbose = FALSE)
            data.int$Y[tau]
          } %>% unlist

          result.approx_control <- foreach(i=seq(B)) %dopar% {
            cat('Approximating truth in iteration (under control): ', i, '\n')
            data.int <- private$sim$simulateWAY(tau, qw = llW, ga = llA, Qy = llY,
                                              intervention = control, verbose = FALSE)
            data.int$Y[tau]
          } %>% unlist

          interventions <- list(intervention = intervention,
                                control = control)

          #osl_options <- c('dosl', 'osl')
          osl_options <- c('dosl')
          #osl_options <- c('osl')

          if('dosl' %in% osl_options) {
            result.dosl.full <- intervention_effect_caluculator$calculate_intervention_effect(
              osl = osl,
              interventions = interventions, 
              discrete = TRUE, 
              initial_data = data.train.set[1,],
              tau = tau
            )

            result.dosl <- result.dosl.full$intervention          
            result.dosl_control <- result.dosl.full$control
          }

          if('osl' %in% osl_options) {
            result.osl.full <- intervention_effect_caluculator$calculate_intervention_effect(
              osl = osl,
              interventions = interventions, 
              discrete = FALSE, 
              initial_data = data.train.set[1,],
              tau = tau
            )

            result.osl <- result.osl.full$intervention          
            result.osl_control <- result.osl.full$control
          } 

          ## Plot the convergence
          data <- list(truth = result.approx, dosl = result.dosl, osl = result.osl)
          OutputPlotGenerator.create_convergence_plot(data = data,
                                                      output = paste('convergence_configuration',configuration,sep='_'))

          data <- list(truth = result.approx_control, dosl = result.dosl_control, osl = result.osl_control)
          OutputPlotGenerator.create_convergence_plot(data = data,
                                                      output = paste('convergence_configuration_control',configuration,sep='_'))

          options(warn=pre)

          result.approx.mean <- result.approx %>% mean
          result.approx_control.mean <- result.approx_control %>% mean

          result.dosl.mean <- result.dosl %>% mean
          result.dosl_control.mean <- result.dosl_control %>% mean

          result.osl.mean <- result.osl %>% mean
          result.osl_control.mean <- result.osl_control %>% mean

          osl$info

          ## Retrieve the minimal number of blocks needed before we have truly updating relevant history
          minimal_measurements_needed <- osl$get_summary_measure_generator$get_minimal_measurements_needed
          print(time.taken)

          private$log && cat(private$log, 'Initial estimates!')
          print(result.approx.mean)
          print(result.approx_control.mean)
          print(result.dosl.mean)
          print(result.dosl_control.mean)
          print(result.osl.mean)
          print(result.osl_control.mean)

          private$log && cat(private$log, 'Starting OOS!')
          #oos_options <- c('dosl', 'dosl_control', 'osl', 'osl_control')
          #oos_options <- c('dosl', 'dosl_control')
          # Now, the final step is to apply the OneStepEstimator

          ## DOSL Intervention
          if('dosl' %in% (oos_options)) {
            OOS.intervention <- OneStepEstimator$new(
              osl = osl, 
              randomVariables = randomVariables, 
              discrete = TRUE,
              N = N, 
              B = B_oos,
              tau = tau,
              intervention = intervention,
              variable_of_interest = variable_of_interest,
              pre_processor = pre_processor,
              minimal_measurements_needed = minimal_measurements_needed
            )

            result.dosl.mean.updated <- OOS.intervention$perform(
              initial_estimate = result.dosl.mean,
              data = data.train.set,
              truth = result.approx.mean
            )$oos_estimate
          }

          ## DOSL Control
          if('dosl_control' %in% (oos_options)) {
            OOS.control <- OneStepEstimator$new(
							osl = osl, 
							randomVariables = randomVariables, 
							discrete = TRUE,
							N = N, 
							B = B_oos,
							tau = tau,
							intervention = control,
							variable_of_interest = variable_of_interest,
							pre_processor = pre_processor,
              minimal_measurements_needed = minimal_measurements_needed
						)

            result.dosl_control.mean.updated <- OOS.control$perform(
							initial_estimate = result.dosl_control.mean,
							data = data.train.set,
							truth = result.approx_control.mean
            )$oos_estimate
          }

          ## OSL Intervention
          if('osl' %in% (oos_options)) {
            OOS.control <- OneStepEstimator$new(
							osl = osl, 
							randomVariables = randomVariables, 
							discrete = FALSE,
							N = N, 
							B = B_oos,
							tau = tau,
							intervention = intervention,
							variable_of_interest = variable_of_interest,
							pre_processor = pre_processor,
              minimal_measurements_needed = minimal_measurements_needed
						)

            result.osl.mean.updated <- OOS.control$perform(
							initial_estimate = result.osl.mean,
							data = data.train.set,
							truth = result.approx.mean
            )$oos_estimate
          }

          ## OSL Control
          if('osl_control' %in% (oos_options)) {
            OOS.control <- OneStepEstimator$new(
							osl = osl, 
							randomVariables = randomVariables, 
							discrete = FALSE,
							N = N, 
							B = B_oos,
							tau = tau,
							intervention = control,
							variable_of_interest = variable_of_interest,
							pre_processor = pre_processor,
              minimal_measurements_needed = minimal_measurements_needed
						)

            result.osl_control.mean.updated <- OOS.control$perform(
							initial_estimate = result.osl_control.mean,
							data = data.train.set,
							truth = result.approx_control.mean
            )$oos_estimate
          }

          estimates <- list(
            dosl             = result.dosl.mean,
            dosl_control     = result.dosl_control.mean,
            dosl_oos         = result.dosl.mean.updated,
            dosl_oos_control = result.dosl_control.mean.updated,

            osl              = result.osl.mean,
            osl_control      = result.osl_control.mean,
            osl_oos          = result.osl.mean.updated,
            osl_oos_control  = result.osl_control.mean.updated,

            approx           = result.approx.mean,
            approx_control   = result.approx_control.mean
          )

          ## Calculate the time it took
          time.taken <- toc - tic
          key <- paste('cfg', configuration, 'time-taken-oos', sep='-')
          OutputPlotGenerator.export_key_value(key, output=key_output, time.taken)
          print(estimates)

          ## Export the estimates
          lapply(names(estimates), function(entry) {
            key <- paste('cfg', configuration, 'entry', entry, sep='-')
            OutputPlotGenerator.export_key_value(key, output=key_output, estimates[[entry]])
          })

          estimates
        }
    )
)

