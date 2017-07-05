#' ML.Local.Speedlm
#' Class to create speedlm linear models. Uses the speed glm package and can be updated online.
#'
#' @docType class
#' @importFrom speedglm speedlm updateWithMoreData
#' @section Methods:
#' \describe{
#'   \item{\code{initialize()}}{
#'     Initializes a new speedlm estimator. 
#'   }
#' }
#' @export
ML.Local.Speedlm <- R6Class("ML.Local.Speedlm",
  inherit = ML.Base,
  public =
    list(
        fitfunname='speedlm-local',
        lmclass='speedlm',
        initialize = function() { }
        ),
  active =
    list(
        ),
  private =
    list(
        do.fit = function(X_mat, Y_vals) {
          # , maxit=1000
            suppressWarnings(
              m.fit <- speedglm::speedlm.wfit(X = X_mat, y = Y_vals, family = binomial(), 
                                               method='Cholesky')
            )
          m.fit$coef
        },

        do.update = function(m.fit, X_mat, Y_vals) {
          updateWithMoreData(m.fit, X = X_mat, y = Y_vals)
        },

        do.predict = function(X_mat, m.fit) {
          if (any(is.na(m.fit$coef))) {
            return(super$do.predict(X_mat, m.fit))
          } else {
            return(expit(X_mat %*% m.fit$coef))
          }
        }
    )
)
