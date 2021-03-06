#' Plotting results for fitted subgroup identification models
#'
#' @description Plots results for estimated subgroup treatment effects
#' @seealso \code{\link[personalized]{fit.subgroup}} for function which fits subgroup identification models.
#' @rdname plot
#'
#' @examples
#' library(personalized)
#'
#' set.seed(123)
#' n.obs  <- 1000
#' n.vars <- 50
#' x <- matrix(rnorm(n.obs * n.vars, sd = 3), n.obs, n.vars)
#'
#'
#' # simulate non-randomized treatment
#' xbetat   <- 0.5 + 0.5 * x[,21] - 0.5 * x[,41]
#' trt.prob <- exp(xbetat) / (1 + exp(xbetat))
#' trt01    <- rbinom(n.obs, 1, prob = trt.prob)
#'
#' trt      <- 2 * trt01 - 1
#'
#' # simulate response
#' delta <- 2 * (0.5 + x[,2] - x[,3] - x[,11] + x[,1] * x[,12])
#' xbeta <- x[,1] + x[,11] - 2 * x[,12]^2 + x[,13]
#' xbeta <- xbeta + delta * trt
#'
#' # continuous outcomes
#' y <- drop(xbeta) + rnorm(n.obs, sd = 2)
#'
#' # create function for fitting propensity score model
#' prop.func <- function(x, trt)
#' {
#'     # fit propensity score model
#'     propens.model <- cv.glmnet(y = trt,
#'                                x = x, family = "binomial")
#'     pi.x <- predict(propens.model, s = "lambda.min",
#'                     newx = x, type = "response")[,1]
#'     pi.x
#' }
#'
#' subgrp.model <- fit.subgroup(x = x, y = y,
#'                            trt = trt01,
#'                            propensity.func = prop.func,
#'                            loss   = "sq_loss_lasso",
#'                            nfolds = 5)              # option for cv.glmnet
#'
#' subgrp.model$subgroup.trt.effects
#'
#' plot(subgrp.model)
#'
#' plot(subgrp.model, type = "boxplot")
#'
#' plot(subgrp.model, type = "interaction")
#' @export
plot.subgroup_fitted <- function(x,
                                 type = c("boxplot", "density", "interaction"),
                                 avg.line = TRUE,
                                 ...)
{
    type <- match.arg(type)

    avg.line <- as.logical(avg.line[1])

    avg.res  <- x$subgroup.trt.effects

    if (type != "interaction")
    {
        if (is.null(x$call)) stop("retcall argument must be set to TRUE for fitted model object")

        benefit.scores <- x$benefit.scores
        B <- NROW(benefit.scores)

        res.2.plot <- array(NA, dim = c(B, 3))
        colnames(res.2.plot) <- c("Recommended", "Received", "Value")
        res.2.plot <- data.frame(res.2.plot)

        cutpoint <- x$call$cutpoint
        lb       <- x$call$larger.outcome.better

        trt.rec  <- if (lb) {1 * (benefit.scores > cutpoint)} else
            1 * (benefit.scores < cutpoint)

        res.2.plot[, 1] <- ifelse(trt.rec == 1, "Recommended Trt", "Recommended Ctrl")
        res.2.plot[, 2] <- ifelse(x$call$trt == 1, "Received Trt", "Received Ctrl")

        if (class(x$call$y) == "Surv")
        {
            res.2.plot[, 3] <- log(x$call$y[,1])
        } else
        {
            res.2.plot[, 3] <- x$call$y
        }
    }


    avg.res.2.plot <- data.frame(Recommended = c("Recommended Trt", "Recommended Trt",
                                                 "Recommended Ctrl", "Recommended Ctrl"),
                                 Received    = c("Received Trt", "Received Ctrl",
                                                 "Received Trt", "Received Ctrl"),
                                 Value       = as.vector(avg.res$avg.outcomes))

    Recommended <- Received <- Value <- NULL



    if (type == "density")
    {
        pl.obj <- ggplot(res.2.plot,
                         aes(x = Value, fill = Received)) +
            geom_density(alpha = 0.65) +
            geom_rug(aes(colour = Received), alpha = 0.85) +
            coord_flip() +
            facet_grid( ~ Recommended) +
            theme(legend.position = "bottom") +
            xlab("Outcome") +
            ggtitle("Individual Observations Among Subgroups")
        if (avg.line)
        {
            pl.obj <- pl.obj + geom_vline(data = avg.res.2.plot,
                                          aes(xintercept = Value),
                                          size = 1.25) +
                geom_vline(data = avg.res.2.plot,
                           aes(xintercept = Value, colour = Received))
        }
    } else if (type == "boxplot")
    {
        pl.obj <- ggplot(res.2.plot,
                         aes(x = Received, y = Value)) +
            geom_boxplot(aes(fill = Received)) +
            geom_rug(aes(colour = Received), alpha = 0.85) +
            facet_grid( ~ Recommended) +
            theme(legend.position = "bottom") +
            ylab("Outcome") +
            ggtitle("Individual Observations Among Subgroups")
    } else
    {
        pl.obj <- ggplot(avg.res.2.plot,
                         aes(x = Recommended, y = Value, group = Received)) +
            geom_line(aes(colour = Received), size = 1.25) +
            geom_point(aes(colour = Received), size = 2) +
            theme(legend.position = "bottom") +
            scale_x_discrete(expand = c(0.25, 0.25)) +
            ylab("Average Outcome") +
            ggtitle("Average Outcomes Among Subgroups")
    }
    pl.obj
}

