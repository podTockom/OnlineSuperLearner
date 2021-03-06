#' DataSplitter
#' Splits data into train and test set.
#'
#' @section Methods: 
#' \describe{  
#'   \item{\code{initialize() }}{ 
#'     Creates a new datasplitter
#'   } 
#' 
#'   \item{\code{split(data)}}{ 
#'     Splits the data in a train and test set. It will always use the last observation as the test set observation.
#'     @param data the data to spit 
#'     @return list with two entries: \code{train} and \code{test}. Each containing the correct dataframe.
#'   } 
#' }  
#' @docType class
#' @importFrom R6 R6Class
DataSplitter <- R6Class("DataSplitter",
  public =
    list(
      initialize = function() { },

      split = function(data){
        if (is.null(private$data.previous) && nrow(data) < 2) throw('At least 2 rows of data are needed, 1 train and 1 test')

        ## Use the last observation as test set
        test <- tail(data, 1)

        ## use the rest of the observations as trainingset
        train <- head(data, nrow(data) - 1)

        if(!is.null(private$data.previous)){
          ## Use the rest of the observations as trainingset, including the previous testset
          ## Note, rbind or rbindlist doesnt matter here in timings,
          ## https://gist.github.com/frbl/ef64fe8d5c935ddf9af7fddecf01a600
          train <- rbind(private$data.previous, train)
        }
        private$data.previous <- test
        return(list(train = train, test = test))
      }
    ),
  private =
    list(
      data.previous = NULL
    )
)
