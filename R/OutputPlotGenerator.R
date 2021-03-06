#' OutputPlotGenerator.create_density_plot
#' Function to plot the true and predicted densities in one plot.
#'
#' @param yValues vector of the true outcome values 
#' @param estimated_probabilities vector of the estimated probabilities
#' @param estimated_y_values vector of the estimated y_values (i.e., sampled values)
#' @param output string with the filename
#' @param dir the directory to plot to
#' @importFrom stats density
#' @importFrom grDevices dev.off pdf
#' @importFrom graphics lines plot
#' @export
OutputPlotGenerator.create_density_plot = function(yValues, estimated_probabilities, estimated_y_values = NULL, output, dir = '~/tmp/osl/') {
  ## plot densitity first:
  vals <- unique(yValues)
  if(length(vals) == 2 ) {
    ## If the outcome is binary, we can see how well it managed to predict the whole distribution
    ## This error term should be small (~ 0.001)
    abs(mean(estimated_probabilities[yValues == vals[1] ]) - mean(yValues == vals[1]))
    abs(mean(estimated_probabilities[yValues == vals[2] ]) - mean(yValues == vals[2]))
  }
  true_density <- density(yValues)

  ## Normalize the density to 1
  ##true_density$y <- diff(true_density$x) * true_density$y

  ## Draw a line by default, instead of dots
  type = "l"

  if (is.null(estimated_y_values)) {
    estimated_y_values <- yValues 
    type = "p"
  }

  ## Normalize to sum to one, to make it an actual density

  ## Save the output in a dir so we can access it later
  date <- format(Sys.time(), "%y%m%d%H%M")
  full_dir <- paste(dir, date, '/', sep ='')
  dir.create(full_dir, showWarnings = FALSE, recursive = TRUE)
  full_file_name <- paste(full_dir,output,'.pdf',sep = '')
  ylim <- c(0,max(c(estimated_probabilities, true_density$y), na.rm=TRUE))

  pdf(full_file_name)
  plot(true_density, ylim=ylim)
  lines(estimated_y_values, estimated_probabilities, type = type, cex = .3, col = "red",
        ylim=c(0,max(estimated_probabilities)+.5))
  dev.off()
  return(full_file_name)
}

#' OutputPlotGenerator.create_convergence_plot
#' Function to plot the convergence to the parameter of interest of both the truth and the estimation.
#'
#' @import ggplot2
#' @import reshape2
#' @importFrom graphics lines plot
#' @importFrom grDevices dev.off pdf
#' @param data the truth  and apporoximations to plot
#' @param output the filename of the output
#' @param dir the directory name of the output
#' @export
OutputPlotGenerator.create_convergence_plot = function(data, output, dir = '~/tmp/osl/convergence') {
  labels = names(data)
  colors <- OutputPlotGenerator.get_colors(length(labels))
  dir.create(dir, showWarnings = FALSE, recursive = TRUE)
  pdf(paste(dir,'/',output,'.pdf',sep = ''))

  data <- lapply(data, function(dat) cumsum(dat)/seq(along=dat)) %>%
    as.data.frame

  data$epoch <- seq(nrow(data))
  data <- melt(data, id.vars='epoch')

  plotje <- ggplot(data,aes(epoch, value, color=variable))+
    geom_line() + 
    scale_color_manual(values = colors[seq_along(labels)])+
    theme(panel.background = element_rect(fill = 'transparent', colour = 'black', size=1))+
    scale_y_continuous(name="")+
    theme(axis.text.y = element_text(colour = "black") ) +
    theme(axis.text.x = element_text(colour = "black") ) +
    theme(axis.title.x = element_text(vjust = -0.5)) +
    theme(legend.title = element_blank())+
    theme(legend.position="bottom")+
    theme(legend.background = element_rect(colour="transparent"))+
    theme(legend.key = element_rect(fill = "transparent", colour = "transparent")) +
    theme(legend.key.size= unit(3,"lines"))

  plot(plotje)
  dev.off()
}


#' OutputPlotGenerator.create_training_curve
#' Function to plot the training curve given the number of iterations used
#'
#' @import ggplot2
#' @import reshape2
#' @importFrom grDevices dev.off pdf
#' @importFrom graphics plot
#' @param historical_cvs the historical CV risks. List of lists of datatables.
#' First list is for each iteration, second for each learner, and the datatable
#' has columns for each random variable.
#' @param randomVariables list of randomvariables to use in the output
#' @param output string the filename to write the pdf to (without .pdf)
#' @param dir string the directory to write the file to
#' @export
OutputPlotGenerator.create_training_curve = function(historical_cvs, randomVariables, output = 'historical_cvs', dir = '~/tmp/osl/') {
  # historical_cvs is a list of lists of datatables
  #                     - each iteration
  #                             - each learner
  #                                      - each RV
  result <- lapply(randomVariables, function(rv){
    lapply (historical_cvs, function(epoch) {
      lapply(epoch, function(algorithm_outcome) algorithm_outcome[, rv$getY, with=FALSE]) %>% unlist
    })
  })

  plots <- lapply(seq_along(result), function(rv_id) {
    rv_result <- result[[rv_id]]
    dt <- as.data.table(rv_result)%>% t

    name_list <- c()
    the_names <- names(rv_result[[1]])
    for (name_id in seq_along(the_names)) {
      name <- the_names[[name_id]]
      name_list <- c(name_list, name_id)
      the_key <- paste('algorithm', name_id, sep='_') 
      OutputPlotGenerator.export_key_value(the_key, name)
    }
    
    colnames(dt) <- name_list
    dt= tryCatch({
      data.table(dt)
    }, error = function(e) {
      browser()
    })
    dt[, id := seq(1, length(rv_result))]

    test_data_long <- reshape2::melt(dt, id='id')
    test_data_long
    names(test_data_long)
    ggplot(data=test_data_long, aes(x=id, y=value, colour=variable)) +
        geom_line()+
        theme(axis.text.y = element_text(colour = "black") ) +
        theme(axis.text.x = element_text(colour = "black") ) +
        theme(axis.title.x = element_text(vjust = -0.5)) +
        theme(legend.title = element_blank())+
        theme(legend.background = element_rect(colour="transparent"))+
        theme(legend.key = element_rect(fill = "transparent", colour = "transparent")) +
        theme(legend.key.size= unit(1,"lines"))

  })
  
  pdf(paste(dir,'/',output,'.pdf',sep = ''))
  lapply(plots, plot)
  dev.off()



  #data <- lapply(data, function(dat) cumsum(dat)/seq(along=dat)) %>%
    #as.data.frame

  #data$epoch <- seq(nrow(data))
  #data <- melt(data, id.vars='epoch')

  #plotje <- ggplot(data,aes(epoch,value,color=variable))+
    #geom_line() + 
    #scale_color_manual(values = colors[seq_along(labels)])+
    #theme(panel.background = element_rect(fill = 'transparent', colour = 'black', size=1))+
    #scale_y_continuous(name="")+

  #plot(plotje)
}


#' OutputPlotGenerator.create_risk_plot
#' Function to create plots similar to the ones in the OSL papers
#' @importFrom stats binomial density terms
#' @importFrom grDevices dev.off pdf
#' @importFrom graphics lines plot
#' @importFrom utils head
#' @param performance a list of list with performances: list 1 the estimators used, list 2 the random variables predicted.
#' @param output string the filename to use for the plot (without .pdf)
#' @param label string the label to use when making a summary plot
#' @param dir string the directory to write to
#' @param make_summary boolean whether or not to sum all error terms to give a summed performance measure
#'
#' @export
OutputPlotGenerator.create_risk_plot = function(performance, output, dir = '~/tmp/osl', make_summary=FALSE, label='total.risk') {
  # Performance should be a list of data.tables:
  # List: the estimator used
  # Datatable: the random variable predicted
  if(make_summary) {
    ## Beware, the unlist is needed, it looks the same but without the unlist the contents are lists instead of numerics
    performance_dt <- lapply(performance,sum) %>% unlist %>% data.table
    colnames(performance_dt) <- label
  } else {
    performance_dt <- performance %>% rbindlist
  }
  ml_names <- names(performance)

  ## Append the names of the algorithms, so ggplot can plot them
  performance_dt[, 'names' :=  ml_names]

  ## Retrieve the names of the outcomes, -1 because the names column does not need a color
  outcomes <- head(colnames(performance_dt), -1)

  dir.create(dir, showWarnings = FALSE, recursive = TRUE)
  pdf(paste(dir, '/', output,'.pdf',sep = ''))
  p <- ggplot(performance_dt)

  colors <- OutputPlotGenerator.get_simple_colors(length(outcomes))

  names(colors) <- outcomes
  for (name in outcomes) {
    p <- p + geom_point(size = 2, aes_string(x=name, y='names'), color=colors[[name]])+
    theme(legend.position="left")
  }

  p <- p +
  scale_linetype(guide = guide_legend(override.aes = list(alpha = 1)), labels = outcomes) + 
  theme(legend.position = c(.75, .25))+
  theme(panel.background = element_rect(fill = 'transparent', colour = 'black', size=1))+
  theme(axis.text.y = element_text(colour = "black") ) +
  theme(axis.title.y=element_blank()) +
  labs(y = '', x = paste(names(colors), colors, sep=': ', collapse = ', '))+
  theme(legend.position="left")+
  theme(legend.background = element_rect(colour="transparent"))+
  theme(legend.key = element_rect(fill = "transparent", colour = "transparent")) +
  theme(legend.key.size= unit(3,"lines"))
  plot(p)
  dev.off()
}

#' OutputPlotGenerator.get_colors
#' Function to return a list of colors, depending on the number of variables / colors needed, uses hex for colors
#' @param number_of_variables the number of colors one requires
#' @return a list of colors
#' @export
OutputPlotGenerator.get_colors = function(number_of_variables) {
  if (number_of_variables > 12 || number_of_variables < 1) {
    return(NULL) 
  }
  list(
    tol1qualitative=c("#4477AA"),
    tol2qualitative=c("#4477AA", "#CC6677"),
    tol3qualitative=c("#4477AA", "#DDCC77", "#CC6677"),
    tol4qualitative=c("#4477AA", "#117733", "#DDCC77", "#CC6677"),
    tol5qualitative=c("#332288", "#88CCEE", "#117733", "#DDCC77", "#CC6677"),
    tol6qualitative=c("#332288", "#88CCEE", "#117733", "#DDCC77", "#CC6677","#AA4499"),
    tol7qualitative=c("#332288", "#88CCEE", "#44AA99", "#117733", "#DDCC77", "#CC6677","#AA4499"),
    tol8qualitative=c("#332288", "#88CCEE", "#44AA99", "#117733", "#999933", "#DDCC77", "#CC6677","#AA4499"),
    tol9qualitative=c("#332288", "#88CCEE", "#44AA99", "#117733", "#999933", "#DDCC77", "#CC6677", "#882255", "#AA4499"),
    tol10qualitative=c("#332288", "#88CCEE", "#44AA99", "#117733", "#999933", "#DDCC77", "#661100", "#CC6677", "#882255", "#AA4499"),
    tol11qualitative=c("#332288", "#6699CC", "#88CCEE", "#44AA99", "#117733", "#999933", "#DDCC77", "#661100", "#CC6677", "#882255", "#AA4499"),
    tol12qualitative=c("#332288", "#6699CC", "#88CCEE", "#44AA99", "#117733", "#999933", "#DDCC77", "#661100", "#CC6677", "#AA4466", "#882255", "#AA4499")
  )[[number_of_variables]]
}

#' OutputPlotGenerator.get_simple_colors
#' Function to return a list of colors, depending on the number of variables / colors needed
#' @importFrom RColorBrewer brewer.pal.info brewer.pal
#' @param number_of_variables the number of colors one requires
#' @return a list of colors
#' @export
OutputPlotGenerator.get_simple_colors = function(number_of_variables) {
  if (number_of_variables < 1) {
    return(NULL)
  }
  number_of_variables <- abs(number_of_variables)
  qual_col_pals = brewer.pal.info[brewer.pal.info$category == 'qual',]
  col_vector = unlist(mapply(brewer.pal, qual_col_pals$maxcolors, rownames(qual_col_pals)))
  sample(col_vector, number_of_variables)
}

#' OutputPlotGenerator.export_key_value 
#' Function to export a key value pair to a file
#'
#' @param key the key to store the value under
#' @param value the value to store
#' @param output string the file
#' @param dir string the dir to write the file to
#' @export
OutputPlotGenerator.export_key_value = function(key, value, output='variables.dat', dir = '~/tmp/osl') {
  if (is.numeric(value)) {
    value <- round(value, 3)
  }
  line <- paste(key,'=',value)
  the_file = paste(dir,output, sep='/')
  if (!file.exists(the_file)) {
    dir.create(dir, showWarnings = FALSE, recursive = TRUE)
    file.create(the_file)
  }

  write(line,file=the_file,append=TRUE)
}

#' OutputPlotGenerator.store_oos_osl_difference
#' Function to store the differences between the truth and osl in a file.
#' @param differences a list of differences with a key for each option
#' @param output the name of the file to write the output to
#' @param oos boolean was oos used 
#' @param configuration (optional) which simulation configuration was used?
#' @export
OutputPlotGenerator.store_oos_osl_difference = function(differences, output, oos, configuration = 0) {
  name <- ifelse(oos, 'post-oos', 'pre-oos')
  for (output_name in names(differences)) {
    key <- paste('cfg', configuration, output_name, name, sep='-')
    OutputPlotGenerator.export_key_value(key, differences[[output_name]], output=output)
  }
}
