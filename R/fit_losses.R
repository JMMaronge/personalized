
#' @import glmnet
fit_sq_loss_lasso <- function(x, y, wts, family, ...)
{
    # this function must return a fitted model
    # in addition to a function which takes in
    # a design matrix and outputs estimated benefit scores

    ###################################################################
    ##
    ## IMPORTANT NOTE: the name of this function *must*
    ##                 begin with "fit_" and end with
    ##                 the text string to associated with
    ##                 this function in the options for the
    ##                 'loss' argument of the fit.subgrp()
    ##                 function
    ##
    ###################################################################

    # fit a model with a lasso
    # penalty and desired loss
    model <- cv.glmnet(x = x,  y = y,
                       weights   = wts,
                       family    = family,
                       intercept = FALSE, ...)

    # define a function which inputs a design matrix
    # and outputs estimated benefit scores: one score
    # for each row in the design matrix
    pred.func <- function(x)
    {
        drop(predict(model, newx = cbind(1, x), type = "link", s = "lambda.min"))
    }

    list(predict = pred.func,
         model   = model)
}


fit_logistic_loss_lasso <- fit_sq_loss_lasso

#' @import survival
fit_cox_loss_lasso <- function(x, y, wts, family, ...)
{
    model <- cv.glmnet(x = x,  y = y,
                       weights   = wts,
                       family    = "cox",
                       ...)

    pred.func <- function(x)
    {
        -drop(predict(model, newx = cbind(1, x), type = "link", s = "lambda.min"))
    }

    list(predict = pred.func,
         model   = model)
}



#' @import mgcv
#' @importFrom stats as.formula binomial gaussian
fit_sq_loss_lasso_gam <- function(x, y, wts, family, ...)
{
    # this function must return a fitted model
    # in addition to a function which takes in
    # a design matrix and outputs estimated benefit scores

    ###################################################################
    ##
    ## IMPORTANT NOTE: the name of this function *must*
    ##                 begin with "fit_" and end with
    ##                 the text string to associated with
    ##                 this function in the options for the
    ##                 'loss' argument of the fit.subgrp()
    ##                 function
    ##
    ###################################################################

    # need to inspect the dots to extract
    # the arguments supplied to cv.glmnet
    # and those supplied to gam
    list.dots <- list(...)
    glmnet.argnames <- union(names(formals(cv.glmnet)), names(formals(glmnet)))
    gam.argnames    <- names(formals(gam))

    dot.names <- names(list.dots)

    # since 'method' is an argument of 'fit.subgrp',
    # let the user change the gam 'method' arg by supplying
    # 'method.gam' arg instead of 'method'
    dot.names[dot.names == "method.gam"] <- "method"
    names(list.dots)[names(list.dots) == "method.gam"] <- "method"

    # find the arguments relevent for each
    # possible ...-supplied function
    dots.idx.glmnet <- match(glmnet.argnames, dot.names)
    dots.idx.gam    <- match(gam.argnames, dot.names)

    dots.idx.glmnet <- dots.idx.glmnet[!is.na(dots.idx.glmnet)]
    dots.idx.gam    <- dots.idx.gam[!is.na(dots.idx.gam)]

    # fit a model with a lasso
    # penalty and desired loss:
    # only add in dots calls if they exist
    if (length(dots.idx.glmnet) > 0)
    {
        sel.model <- do.call(cv.glmnet, c(list(x = x, y = y, weights = wts, family = family,
                                               intercept = FALSE), list.dots[dots.idx.glmnet]))
    } else
    {
        sel.model <- do.call(cv.glmnet, list(x = x, y = y, weights = wts, family = family,
                                             intercept = FALSE))
    }

    vnames <- colnames(x)

    sel.idx <- drop(predict(sel.model, type = "nonzero", s = "lambda.min")[[1]])

    # always include treatment main effect
    sel.idx <- union(1L, sel.idx)

    # names of selected variables
    sel.vnames <- vnames[sel.idx]

    # find which variables are binary
    var.levels <- numeric(length(sel.idx))
    for (v in 1:length(sel.idx))
    {
        var.levels[v] <- length(unique(x[,sel.idx[v]]))
    }

    contin.vars <- sel.vnames[var.levels > 2]
    binary.vars <- sel.vnames[var.levels == 2]

    # create formula for gam
    contin.formula <- binary.formula <- NULL

    # don't create smoother for binary vars
    if (length(binary.vars) > 0)
    {
        binary.formula <- paste(binary.vars, collapse = "+")
    }

    # create smoother for each continuous var
    if (length(contin.vars) > 0)
    {
        form.cur <- paste0("s(", contin.vars, ")")
        contin.formula <- paste(form.cur, collapse = "+")
    }

    family.func <- gaussian()

    if (family == "cox")
    {
        rhs.formula <- paste(c(binary.formula, contin.formula), collapse = "+")
        family.func <- cox.ph()
    } else
    {
        rhs.formula <- paste("-1 +", paste(c(binary.formula, contin.formula), collapse = "+"))
        if (family == "binomial")
        {
            family.func <- binomial()
            y <- as.integer(y)
        }
    }
    gam.formula <- as.formula(paste("y ~", rhs.formula))

    # create data frame
    df <- data.frame(y = y, x = x[,sel.idx])
    colnames(df) <- c("y", sel.vnames)

    # fit gam model:
    # only add in dots calls if they exist
    if (length(dots.idx.glmnet) > 0)
    {
        model <- do.call(gam, c(list(formula = gam.formula, data = df,
                                     weights = wts, family = family.func,
                                     drop.intercept = TRUE),
                                     list.dots[dots.idx.gam]))
    } else
    {
        model <- do.call(gam, list(formula = gam.formula, data = df,
                                   weights = wts, family = family.func,
                                   drop.intercept = TRUE))
    }

    # define a function which inputs a design matrix
    # and outputs estimated benefit scores: one score
    # for each row in the design matrix
    pred.func <- function(x)
    {
        df.pred <- data.frame(cbind(1, x[,sel.idx[-1] - 1]))
        colnames(df.pred) <- colnames(df)[-1] # take out 'y' column name
        drop(predict(model, newdata = df.pred, type = "link"))
    }

    list(predict = pred.func,
         model   = model)
}

fit_logistic_loss_lasso_gam <- fit_sq_loss_lasso_gam
fit_cox_loss_lasso_gam      <- fit_sq_loss_lasso_gam




fit_sq_loss_gam <- function(x, y, wts, family, ...)
{
    # this function must return a fitted model
    # in addition to a function which takes in
    # a design matrix and outputs estimated benefit scores

    ###################################################################
    ##
    ## IMPORTANT NOTE: the name of this function *must*
    ##                 begin with "fit_" and end with
    ##                 the text string to associated with
    ##                 this function in the options for the
    ##                 'loss' argument of the fit.subgrp()
    ##                 function
    ##
    ###################################################################


    list.dots <- list(...)

    # since 'method' is an argument of 'fit.subgrp',
    # let the user change the gam 'method' arg by supplying
    # 'method.gam' arg instead of 'method'
    names(list.dots)[names(list.dots) == "method.gam"] <- "method"

    vnames  <- colnames(x)
    sel.idx <- seq_len(ncol(x))

    # names of selected variables
    sel.vnames <- vnames[sel.idx]

    # find which variables are binary
    var.levels <- numeric(length(sel.idx))
    for (v in 1:length(sel.idx))
    {
        var.levels[v] <- length(unique(x[,sel.idx[v]]))
    }

    contin.vars <- sel.vnames[var.levels > 2]
    binary.vars <- sel.vnames[var.levels == 2]

    # create formula for gam
    contin.formula <- binary.formula <- NULL

    # don't create smoother for binary vars
    if (length(binary.vars) > 0)
    {
        binary.formula <- paste(binary.vars, collapse = "+")
    }

    # create smoother for each continuous var
    if (length(contin.vars) > 0)
    {
        form.cur <- paste0("s(", contin.vars, ")")
        contin.formula <- paste(form.cur, collapse = "+")
    }

    family.func <- gaussian()

    if (family == "cox")
    {
        rhs.formula <- paste(c(binary.formula, contin.formula), collapse = "+")
        family.func <- cox.ph()
    } else
    {
        rhs.formula <- paste("-1 +", paste(c(binary.formula, contin.formula), collapse = "+"))
        if (family == "binomial")
        {
            family.func <- binomial()
            y <- as.integer(y)
        }
    }
    gam.formula <- as.formula(paste("y ~", rhs.formula))

    # create data frame
    df <- data.frame(y = y, x = x[,sel.idx])
    colnames(df) <- c("y", sel.vnames)

    # fit gam model:
    # only add in dots calls if they exist
    if (length(list.dots) > 0)
    {
        model <- do.call(gam, c(list(formula = gam.formula, data = df,
                                     weights = wts, family = family.func,
                                     drop.intercept = TRUE),
                                list.dots))
    } else
    {
        model <- do.call(gam, list(formula = gam.formula, data = df,
                                   weights = wts, family = family.func,
                                   drop.intercept = TRUE))
    }


    # define a function which inputs a design matrix
    # and outputs estimated benefit scores: one score
    # for each row in the design matrix
    pred.func <- function(x)
    {
        df.pred <- data.frame(cbind(1, x[,sel.idx[-1] - 1]))
        colnames(df.pred) <- colnames(df)[-1] # take out 'y' column name
        drop(predict(model, newdata = df.pred, type = "link"))
    }

    list(predict = pred.func,
         model   = model)
}

fit_logistic_loss_gam <- fit_sq_loss_gam
fit_cox_loss_gam      <- fit_sq_loss_gam



#' @import gbm
fit_sq_loss_gbm <- function(x, y, wts, family, ...)
{
    # this function must return a fitted model
    # in addition to a function which takes in
    # a design matrix and outputs estimated benefit scores

    ###################################################################
    ##
    ## IMPORTANT NOTE: the name of this function *must*
    ##                 begin with "fit_" and end with
    ##                 the text string to associated with
    ##                 this function in the options for the
    ##                 'loss' argument of the fit.subgrp()
    ##                 function
    ##
    ###################################################################

    list.dots <- list(...)

    dot.names <- names(list.dots)
    if ("cv.folds" %in% dot.names)
    {
        cv.folds <- list.dots["cv.folds"]
        if (cv.folds < 2)
        {
            cv.folds <- 2L
            list.dots$cv.folds <- cv.folds
            warning("cv.folds must be at least 2")
        }

    } else
    {
        list.dots$cv.folds <- 5L
    }


    df <- data.frame(y = y, x)

    formula.gbm <- as.formula("y ~ . - 1")

    # fit a model with a lasso
    # penalty and desired loss
    model <- do.call(gbm, c(list(formula.gbm, data = df,
                                 weights = wts,
                                 distribution = "gaussian"),
                                 list.dots))

    best.iter <- gbm.perf(model, method = "cv")

    vnames <- colnames(x)

    # define a function which inputs a design matrix
    # and outputs estimated benefit scores: one score
    # for each row in the design matrix
    pred.func <- function(x)
    {
        df.x <- data.frame(cbind(1, x))
        colnames(df.x) <- vnames

        drop(predict(model, newdata = df.x, n.trees = best.iter, type = "link"))
    }

    list(predict = pred.func,
         model   = model)
}


fit_abs_loss_gbm <- function(x, y, wts, family, ...)
{
    # this function must return a fitted model
    # in addition to a function which takes in
    # a design matrix and outputs estimated benefit scores

    ###################################################################
    ##
    ## IMPORTANT NOTE: the name of this function *must*
    ##                 begin with "fit_" and end with
    ##                 the text string to associated with
    ##                 this function in the options for the
    ##                 'loss' argument of the fit.subgrp()
    ##                 function
    ##
    ###################################################################

    list.dots <- list(...)

    dot.names <- names(list.dots)
    if ("cv.folds" %in% dot.names)
    {
        cv.folds <- list.dots["cv.folds"]
        if (cv.folds < 2)
        {
            cv.folds <- 2L
            list.dots$cv.folds <- cv.folds
            warning("cv.folds must be at least 2")
        }

    } else
    {
        list.dots$cv.folds <- 5L
    }


    df <- data.frame(y = y, x)

    formula.gbm <- as.formula("y ~ . - 1")

    # fit a model with a lasso
    # penalty and desired loss
    model <- do.call(gbm, c(list(formula.gbm, data = df,
                                 weights = wts,
                                 distribution = "laplace"),
                            list.dots))

    best.iter <- gbm.perf(model, method = "cv")

    vnames <- colnames(x)

    # define a function which inputs a design matrix
    # and outputs estimated benefit scores: one score
    # for each row in the design matrix
    pred.func <- function(x)
    {
        df.x <- data.frame(cbind(1, x))
        colnames(df.x) <- vnames

        drop(predict(model, newdata = df.x, n.trees = best.iter, type = "link"))
    }

    list(predict = pred.func,
         model   = model)
}


fit_logistic_loss_gbm <- function(x, y, wts, family, ...)
{
    # this function must return a fitted model
    # in addition to a function which takes in
    # a design matrix and outputs estimated benefit scores

    ###################################################################
    ##
    ## IMPORTANT NOTE: the name of this function *must*
    ##                 begin with "fit_" and end with
    ##                 the text string to associated with
    ##                 this function in the options for the
    ##                 'loss' argument of the fit.subgrp()
    ##                 function
    ##
    ###################################################################

    list.dots <- list(...)

    dot.names <- names(list.dots)
    if ("cv.folds" %in% dot.names)
    {
        cv.folds <- list.dots["cv.folds"]
        if (cv.folds < 2)
        {
            cv.folds <- 2L
            list.dots$cv.folds <- cv.folds
            warning("cv.folds must be at least 2")
        }

    } else
    {
        list.dots$cv.folds <- 5L
    }


    df <- data.frame(y = y, x)

    formula.gbm <- as.formula("y ~ . - 1")

    # fit a model with a lasso
    # penalty and desired loss
    model <- do.call(gbm, c(list(formula.gbm, data = df,
                                 weights = wts,
                                 distribution = "bernoulli"),
                            list.dots))

    best.iter <- gbm.perf(model, method = "cv")

    vnames <- colnames(x)

    # define a function which inputs a design matrix
    # and outputs estimated benefit scores: one score
    # for each row in the design matrix
    pred.func <- function(x)
    {
        df.x <- data.frame(cbind(1, x))
        colnames(df.x) <- vnames

        drop(predict(model, newdata = df.x, n.trees = best.iter, type = "link"))
    }

    list(predict = pred.func,
         model   = model)
}


fit_huberized_loss_gbm <- function(x, y, wts, family, ...)
{
    # this function must return a fitted model
    # in addition to a function which takes in
    # a design matrix and outputs estimated benefit scores

    ###################################################################
    ##
    ## IMPORTANT NOTE: the name of this function *must*
    ##                 begin with "fit_" and end with
    ##                 the text string to associated with
    ##                 this function in the options for the
    ##                 'loss' argument of the fit.subgrp()
    ##                 function
    ##
    ###################################################################

    list.dots <- list(...)

    dot.names <- names(list.dots)
    if ("cv.folds" %in% dot.names)
    {
        cv.folds <- list.dots["cv.folds"]
        if (cv.folds < 2)
        {
            cv.folds <- 2L
            list.dots$cv.folds <- cv.folds
            warning("cv.folds must be at least 2")
        }

    } else
    {
        list.dots$cv.folds <- 5L
    }


    df <- data.frame(y = y, x)

    formula.gbm <- as.formula("y ~ . - 1")

    # fit a model with a lasso
    # penalty and desired loss
    model <- do.call(gbm, c(list(formula.gbm, data = df,
                                 weights = wts,
                                 distribution = "huberized"),
                            list.dots))

    best.iter <- gbm.perf(model, method = "cv")

    vnames <- colnames(x)

    # define a function which inputs a design matrix
    # and outputs estimated benefit scores: one score
    # for each row in the design matrix
    pred.func <- function(x)
    {
        df.x <- data.frame(cbind(1, x))
        colnames(df.x) <- vnames

        drop(predict(model, newdata = df.x, n.trees = best.iter, type = "link"))
    }

    list(predict = pred.func,
         model   = model)
}


fit_cox_loss_gbm <- function(x, y, wts, family, ...)
{
    # this function must return a fitted model
    # in addition to a function which takes in
    # a design matrix and outputs estimated benefit scores

    ###################################################################
    ##
    ## IMPORTANT NOTE: the name of this function *must*
    ##                 begin with "fit_" and end with
    ##                 the text string to associated with
    ##                 this function in the options for the
    ##                 'loss' argument of the fit.subgrp()
    ##                 function
    ##
    ###################################################################

    list.dots <- list(...)

    dot.names <- names(list.dots)
    if ("cv.folds" %in% dot.names)
    {
        cv.folds <- list.dots["cv.folds"]
        if (cv.folds < 2)
        {
            cv.folds <- 2L
            list.dots$cv.folds <- cv.folds
            warning("cv.folds must be at least 2")
        }

    } else
    {
        list.dots$cv.folds <- 5L
    }

    surv.vnames <- colnames(y)

    time.idx   <- which(surv.vnames == "time")
    status.idx <- which(surv.vnames == "status")

    df <- data.frame(cox_gbm_time = y[,time.idx], cox_gbm_status = y[,status.idx], x)

    formula.gbm <- as.formula("Surv(cox_gbm_time, cox_gbm_status) ~ . - 1")

    # fit a model with a lasso
    # penalty and desired loss
    model <- do.call(gbm, c(list(formula.gbm, data = df,
                                 weights = wts,
                                 distribution = "coxph"),
                            list.dots))

    best.iter <- gbm.perf(model, method = "cv")

    vnames <- colnames(x)

    # define a function which inputs a design matrix
    # and outputs estimated benefit scores: one score
    # for each row in the design matrix
    pred.func <- function(x)
    {
        df.x <- data.frame(cbind(1, x))
        colnames(df.x) <- vnames

        drop(predict(model, newdata = df.x, n.trees = best.iter, type = "link"))
    }

    list(predict = pred.func,
         model   = model)
}



