#' SMG.Mean
#'
#' @docType class
#' @importFrom R6 R6Class
SMG.Mean <- R6Class("SMG.Mean",
  public =
    list(
      initialize = function(colnames.to.mean) {
        private$colnames.to.mean <- colnames.to.mean
        private$colnames.mean.affix <- paste(colnames.to.mean, 'mean', sep = "_")

        private$mean.current <- rep(0,length(colnames.to.mean))
        names(private$mean.current) <- colnames.to.mean
      },

      process = function(data.current){
        nobs <- nrow(data.current)
        if(nobs < self$minimalObservations){
          stop(paste('At least', self$minimalObservations, 'observations required'))
        }
        sums <- colSums(data.current[,private$colnames.to.mean, with=FALSE])

        ## TODO: Super naive implementation, fix it
        private$mean.current <- setNames(mapply('+',
                                                sums[private$colnames.to.mean],
                                                private$mean.current[private$colnames.to.mean] * private$nobs
                                                ),
                                          private$colnames.to.mean)

        private$nobs <- private$nobs + nobs
        private$mean.current <- private$mean.current / private$nobs

        temp <- copy(private$mean.current)
        names(temp) <- private$colnames.mean.affix
        temp
      },

      update = function(data.current) {
        ## The update procedure is essentially the same as the process function
        ## for the mean 
        ## TODO: Do we only need to return the last mean? Or should we also
        ## update the existing mean?
        return(self$process(data.current) %>% unlist)
      }
    ),
  active = 
    list(
      minimalObservations = function() {
        return(private$theMinimalObservations)
      }
    ),
  private =
    list(
      theMinimalObservations = 1,
      mean.current = 0,
      nobs = 0,
      colnames.to.mean = NULL,
      colnames.mean.affix = NULL
    )
)
