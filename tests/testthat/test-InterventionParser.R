context("InterventionParser.R")

context(" InterventionParser.parse_intervention")
#==========================================================
test_that("it should parse the intervention and return the correct elements in a list", {
  intervention <- list()
  intervention$variable <- c('A','B','C','A')
  intervention$when <- rep(2, length(intervention$variable))
  intervention$what <- c(1,0,0,1)
  t = 0
  current_outcome = 'A'
  result <- InterventionParser.parse_intervention(intervention, 
                                                  current_time= t,
                                                  current_outcome = current_outcome)
  expect_true(is(result, 'list'))
  expect_equal(length(result), 3) 
  expect_named(result, c('when', 'what', 'should_intervene')) 
})

test_that("it should return true if the current time and variable is an intervention time/variable", {
  intervention <- list()
  intervention$variable <- c('A','B','C','A')
  intervention$when <- rep(2, length(intervention$variable))
  intervention$what <- c(1,0,0,1)
  t = 2
  current_outcome = 'A'
  result <- InterventionParser.parse_intervention(intervention, 
                                                  current_time= t,
                                                  current_outcome = current_outcome)
  expect_true(result$should_intervene)
})

test_that("it should return false if the current time or variable is not an intervention time/variable", {
  intervention <- list()
  intervention$variable <- c('A','B','C','A')
  intervention$when <- rep(2, length(intervention$variable))
  intervention$what <- c(1,0,0,1)
  t = 2
  current_outcome = 'D'
  result <- InterventionParser.parse_intervention(intervention, 
                                                  current_time= t,
                                                  current_outcome = current_outcome)
  expect_false(result$should_intervene)
  expect_equal(result$when, -1)
  expect_equal(result$what, -1)

  t = 1
  current_outcome = 'A'
  result <- InterventionParser.parse_intervention(intervention, 
                                                  current_time= t,
                                                  current_outcome = current_outcome)
  expect_false(result$should_intervene)
  expect_equal(result$when, -1)
  expect_equal(result$what, -1)
})

test_that("it should return the correct what and when", {
  intervention <- list()
  intervention$variable <- c('A','B','C','A')
  intervention$when <- c(2,2,2,3)
  intervention$what <- c(1,0,0,0)
  t = 2
  current_outcome = 'A'
  result <- InterventionParser.parse_intervention(intervention, 
                                                  current_time= t,
                                                  current_outcome = current_outcome)
  expect_equal(result$when, 2)
  expect_equal(result$what, 1)

  current_outcome = 'B'
  result <- InterventionParser.parse_intervention(intervention, 
                                                  current_time= t,
                                                  current_outcome = current_outcome)
  expect_equal(result$when, 2)
  expect_equal(result$what, 0)

  t = 3
  current_outcome = 'A'
  result <- InterventionParser.parse_intervention(intervention, 
                                                  current_time= t,
                                                  current_outcome = current_outcome)
  expect_equal(result$when, 3)
  expect_equal(result$what, 0)
})

test_that("it should work with the old style interventions", {
  intervention <- list(variable = 'A',when = c(2), what = c(1))
  t = 1
  current_outcome = 'A'
  result <- InterventionParser.parse_intervention(intervention, 
                                                  current_time= t,
                                                  current_outcome = current_outcome)
  expect_false(result$should_intervene)
  expect_equal(result$when, -1)
  expect_equal(result$what, -1)

  t = 2
  current_outcome = 'A'
  result <- InterventionParser.parse_intervention(intervention, 
                                                  current_time= t,
                                                  current_outcome = current_outcome)
  expect_true(result$should_intervene)
  expect_equal(result$when, 2)
  expect_equal(result$what, 1)
})

test_that("it should return a list and should not intervene if the intervention is null", {
  result <- InterventionParser.parse_intervention(NULL, 
                                                  current_time= 100,
                                                  current_outcome = 'A')
  expect_false(result$should_intervene)
  expect_equal(result$when, -1)
  expect_equal(result$what, -1)
})

test_that("it should raise if the provided intervention is not a list and check is true", {
  expect_error(InterventionParser.parse_intervention(
      intervention = 'not a list!', 
      current_time= 100,
      current_outcome = 'A',
      check = TRUE
    ), "Argument 'intervention' is neither of nor inherits class list: character",
    fixed = TRUE)
})

test_that("it should raise if the provided current_time is not an integer and check is true", {
  expect_error(InterventionParser.parse_intervention(
      intervention = list(), 
      current_time = list(),
      current_outcome = 'A',
      check = TRUE
    ), "Argument 'current_time' should be a single value not 0 values.", fixed = TRUE)
})

test_that("it should raise if the provided current_outcome is not a character and check is true", {
  expect_error(InterventionParser.parse_intervention(
    intervention = list(), 
    current_time= 100,
    current_outcome = glm,
    check = TRUE), "cannot coerce type 'closure' to vector of type 'character'", fixed = TRUE)
})

context(" InterventionParser.valid_intervention")
#==========================================================
test_that("it should return -1 if no intervention is provided", {
  result <- InterventionParser.first_intervention(NULL)

  expect_named(result, 'when')
  expect_equivalent(result, -1)
})

test_that("it should should find the first intervention in the list and return the timestamp", {
  intervention <- list(variable = 'A',when = c(10,20,20,20), what = c(0,1,1,1))
  result <- InterventionParser.first_intervention(intervention)

  expect_named(result, 'when')
  expect_equivalent(result, 10)
  
})

context(' InterventionParser.valid_intervention')
#==========================================================
test_that("it should return true when an intervention is valid", {
  intervention <- list(variable = 'A',when = c(2), what = c(1))
  expect_true(InterventionParser.valid_intervention(intervention))

  intervention <- list(variable = 'A',when = c(2,2,2,2), what = c(0,1,1,1))
  expect_true(InterventionParser.valid_intervention(intervention))
})

test_that("it should return false when the intervention is not a list", {
  interventions <- c(NULL, 'wrong', TRUE)
  for (intervention in interventions) {
    expect_false(InterventionParser.valid_intervention(intervention))
  }
})

test_that("it should return false when the intervention length of whens is not equal to the whats", {
  intervention <- list(variable = 'A',when = c(2,2,2), what = c(0,1,1,1))
  expect_false(InterventionParser.valid_intervention(intervention))
  intervention <- list(variable = 'A',when = c(1,2,2,2), what = c(1,1,1))
  expect_false(InterventionParser.valid_intervention(intervention))
})

test_that("it should return false if any of the keys is missing", {
  intervention <- list(variable = 'A',when = c(2))
  expect_false(InterventionParser.valid_intervention(intervention))
  intervention <- list(variable = 'A', what = c(1))
  expect_false(InterventionParser.valid_intervention(intervention))
  intervention <- list(when = c(2), what = c(1))
  expect_false(InterventionParser.valid_intervention(intervention))
})

context(" InterventionParser.generate_intervention")
#==========================================================
test_that("it should generate an intervention based on the provided when and what for one of the variables", {
  variables <- c('A', 'B', 'C')
  variable_intervened <- 'A'
  when <- 1
  what <- 1
  result <- InterventionParser.generate_intervention(variables = variables,
                                                     variable_intervened= variable_intervened,
                                                     when = when, what = what)
  expect_true(InterventionParser.valid_intervention(result))
  expected <- list(variable = variables,
                   when = rep(when, length(variables)),
                   what = c(1,0,0)) 
  expect_equal(expected, result)
})

context(" InterventionParser.is_current_node_treatment")
#==========================================================
test_that("it should return true if the current node is a treatment node", {
  intervention <- list(variable = 'A',when = c(2))
  result <- InterventionParser.is_current_node_treatment(current_time=2, 
                                                         intervention = intervention,
                                                         current_rv_output = 'A') 
  expect_true(result)
})

test_that("it should return false if the current node is not a treatment node (the time is incorrect)", {
  intervention <- list(variable = 'A',when = c(2))
  result <- InterventionParser.is_current_node_treatment(current_time=1, 
                                                         intervention = intervention,
                                                         current_rv_output = 'A') 
  expect_false(result)
})

test_that("it should return false if the current node is not a treatment node (the variable is incorrect)", {
  intervention <- list(variable = 'A',when = c(2))
  result <- InterventionParser.is_current_node_treatment(current_time=2, 
                                                         intervention = intervention,
                                                         current_rv_output = 'W') 
  expect_false(result)
})
