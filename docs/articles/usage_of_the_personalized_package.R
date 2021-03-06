## ----sim_data_1, message = FALSE, warning = FALSE------------------------
library(personalized)

set.seed(123)
n.obs  <- 1000
n.vars <- 50
x <- matrix(rnorm(n.obs * n.vars, sd = 3), n.obs, n.vars)

# simulate non-randomized treatment
xbetat   <- 0.5 + 0.25 * x[,21] - 0.25 * x[,41]
trt.prob <- exp(xbetat) / (1 + exp(xbetat))
trt      <- rbinom(n.obs, 1, prob = trt.prob)

# simulate delta
delta <- (0.5 + x[,2] - 0.5 * x[,3] - 1 * x[,11] + 1 * x[,1] * x[,12] )

# simulate main effects g(X)
xbeta <- x[,1] + x[,11] - 2 * x[,12]^2 + x[,13] + 0.5 * x[,15] ^ 2
xbeta <- xbeta + delta * (2 * trt - 1)

# simulate continuous outcomes
y <- drop(xbeta) + rnorm(n.obs)

## ----create_propensity---------------------------------------------------
# create function for fitting propensity score model
prop.func <- function(x, trt)
{
 # fit propensity score model
 propens.model <- cv.glmnet(y = trt,
                            x = x, 
                            family = "binomial")
 pi.x <- predict(propens.model, s = "lambda.min",
                 newx = x, type = "response")[,1]
 pi.x
}

## ----plot_overlap--------------------------------------------------------
check.overlap(x, trt, prop.func)

## ----fit_model-----------------------------------------------------------
subgrp.model <- fit.subgroup(x = x, y = y,
                             trt = trt,
                             propensity.func = prop.func,
                             family = "gaussian",
                             loss   = "sq_loss_lasso",
                             nfolds = 10)              # option for cv.glmnet

summary(subgrp.model)

## ----plot_model----------------------------------------------------------
plot(subgrp.model)

## ----plot_model_2--------------------------------------------------------
plot(subgrp.model, type = "interaction")

## ----validate_model------------------------------------------------------
validation <- validate.subgroup(subgrp.model, 
                                B = 25L,  # specify the number of replications
                                method = "training_test_replication",
                                train.fraction = 0.75)

validation

## ----plot_validation-----------------------------------------------------
plot(validation)

## ----plot_validation_2---------------------------------------------------
plot(validation, type = "interaction")

## ----plot_validation_compare---------------------------------------------
plotCompare(subgrp.model, validation, type = "interaction")

## ----binary_example------------------------------------------------------
# create binary outcomes
y.binary <- 1 * (xbeta + rnorm(n.obs, sd = 2) > 0 )


## ----fit_binary_1--------------------------------------------------------
subgrp.bin <- fit.subgroup(x = x, y = y.binary,
                           trt = trt,
                           propensity.func = prop.func,
                           family = "binomial",
                           loss   = "logistic_loss_lasso",
                           nfolds = 10)      # option for cv.glmnet

## ----fit_binary_2, eval = FALSE------------------------------------------
#  subgrp.bin2 <- fit.subgroup(x = x, y = y.binary,
#                              trt = trt,
#                              propensity.func = prop.func,
#                              family = "binomial",
#                              loss = "logistic_loss_gbm",
#                              shrinkage = 0.025,  # options for gbm
#                              n.trees = 1500,
#                              interaction.depth = 3,
#                              cv.folds = 5)

## ----plotcompare_bin-----------------------------------------------------
subgrp.bin

## ----tte_example---------------------------------------------------------
# create time-to-event outcomes
surv.time <- exp(-20 - xbeta + rnorm(n.obs, sd = 1))
cens.time <- exp(rnorm(n.obs, sd = 3))
y.time.to.event  <- pmin(surv.time, cens.time)
status           <- 1 * (surv.time <= cens.time)

## ----tte_model_example---------------------------------------------------
library(survival)
set.seed(123)
subgrp.cox <- fit.subgroup(x = x, y = Surv(y.time.to.event, status),
                           trt = trt,
                           propensity.func = prop.func,
                           method = "weighting",
                           family = "cox",
                           loss   = "cox_loss_lasso",
                           nfolds = 10)      # option for cv.glmnet

## ----print_tte_model-----------------------------------------------------
summary(subgrp.cox)

