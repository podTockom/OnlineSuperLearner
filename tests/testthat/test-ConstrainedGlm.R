context("ConstrainedGlm.R")

set.seed(12345)
nobs <- 100
cov1 <- rnorm(nobs, 0, 1)
cov2 <- rnorm(nobs, 1, 1)
cov3 <- ifelse(cov1 > 0, rbinom(nobs,1, 0.999), rbinom(nobs,1, 0.3))
cov4 <- rnorm(nobs, 3, 1)
y <- as.numeric(expit(0.1*cov1 - 0.8*cov2 - 0.1*cov3 + 0.4*cov4 + rnorm(nobs,0,10)) > 0.5)

dat <- data.table(cov1, cov2, cov3, cov4, y)

test_that("it should create a GLM based on the formula, delta, and data, and should respect the boundaries", {

  formula <- y ~ cov1 + cov2 + cov3 + cov4
  for(delta in c(0.05, 0.1, 0.15)) {
    suppressWarnings({
      the_glm <- ConstrainedGlm.fit(formula = formula, delta = delta, data = dat)
      predictions <- predict(the_glm, type='response')
    })
    expect_lte(max(predictions), 1- delta)
    expect_gte(min(predictions), delta)
  }
})


test_that("it should, with a delta of 0, return the same as a normal glm", {
  x <- rep(1/2, 10)
  y <- rbinom(10, size = 1, prob=x)
  dat <- data.frame(x=x, y=y)

  formula <- y ~ x
  fit1 <- glm(formula, family=binomial(), data=dat)
  fit2 <- ConstrainedGlm.fit(formula, delta=0, data=dat)
  expect_equal(coef(fit1), coef(fit2))
})

test_that("it should return the same as a glm with a delta of 0 and more complex data", {
    formula <- y ~ cov1 + cov2 + cov3 + cov4
    fit1 <- glm(formula, family=binomial(), data=dat)
    fit2 <- ConstrainedGlm.fit(formula, delta=0, data=dat)
    expect_equal(coef(fit1), coef(fit2))
})


test_that("it should work with the data from a file", {
  url <- system.file("testdata",'test-fit-glm-and-constrained-glm.csv',package="OnlineSuperLearner")
  read_data <- read.csv(url) %>% as.data.table
  formula <- Delta ~ Y_lag_1

  hide_warning_probabilities_numerically_zero_or_one(
    hide_warning_convergence({
      fit1 <- glm(formula, family=binomial(), data=read_data)
      fit2 <- ConstrainedGlm.fit(formula, delta=0, data=read_data)
    })
  )
  expect_equal(coef(fit1), coef(fit2))
})