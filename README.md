
# Prompt ([BLMR](https://bookdown.org/roback/bookdown-BeyondMLR/ch-lon.html#open-ended-exercises-5))

UCLA nurse blood pressure study. A study by Goldstein and Shapiro (2000)
collected information from 203 registered nurses in the Los Angeles area
between 24 and 50 years of age on blood pressure (BP) and potential
factors that contribute to hypertension. This information includes
family history, and whether the subject had one or two hypertensive
parents, as well as a wide range of measures of the physical and
emotional condition of each nurse throughout the day. **Researchers
sought to study the links between BP and family history, personality,
mood changes, working status, and menstrual phase**.

Data from this study provided by Weiss (2005) includes observations
(40-60 per nurse) repeatedly taken on the 203 nurses over the course of
a single day. The first BP measurement was taken half an hour before the
subject’s normal start of work, and BP was then measured approximately
every 20 minutes for the rest of the day. At each BP reading, the nurses
also rate their mood on several dimensions, including how stressed they
feel at the moment the BP is taken. In addition, the activity of each
subject during the 10 minutes before each reading was measured using an
actigraph worn on the waist. Each of the variables in nursebp.csv is
described below:

    SNUM: subject identification number
    SYS: systolic blood pressure (mmHg)
    DIA: diastolic blood pressure (mmHg)
    HRT: heart rate (beats per minute)
    MNACT5: activity level (frequency of movements in 1-minute intervals, over a 10-minute period )
    PHASE: menstrual phase (follicular—beginning with the end of menstruation and ending with ovulation, or luteal—beginning with ovulation and ending with pregnancy or menstruation)
    DAY: workday or non-workday
    POSTURE: position during BP measurement—either sitting, standing, or reclining
    STR, HAP, TIR: self-ratings by each nurse of their level of stress, happiness and tiredness at the time of each BP measurement on a 5-point scale, with 5 being the strongest sensation of that feeling and 1 the weakest
    AGE: age in years
    FH123: coded as either NO (no family history of hypertension), YES (1 hypertensive parent), or YESYES (both parents hypertensive)
    time: in minutes from midnight
    timept: number of the measurement that day (approximately 50 for each subject)
    timepass: time in minutes beginning with 0 at time point 1 

Using **systolic blood pressure as the primary response**, write a short
report detailing factors that are significantly associated with higher
systolic blood pressure. Be sure to support your conclusions with
appropriate exploratory plots and multilevel models. In particular,
**how are work conditions—activity level, mood, and work status—related
to trends in BP levels**? As an appendix to your report, describe your
modeling process—how did you arrive at your final model, which
covariates are Level One or Level Two, what did you learn from
exploratory plots, etc.?

# Modeling

## Data Wrangling

``` r
nurse <- read.csv("https://math.carleton.edu/kstclair/data/bmlr/nursebp.csv",
                  stringsAsFactors = TRUE) %>% 
  as_tibble %>% 
  select(-c(DIA, HRT, timept)) %>% 
  janitor::clean_names() %>% 
  mutate(snum = as.factor(snum))
glimpse(nurse)
out<-md.pattern(nurse, rotate.names=T) #missingness pattern
nurse_complete <- nurse %>% 
  drop_na() %>% 
  mutate(mood = hap - (str + tir)/2,
         standing = case_when(posture == "RECLINE" ~ 0,
                         posture == "SIT" ~ 0,
                         posture == "STAND" ~ 1)) 
# new mood variable

nurse_filtered <- nurse_complete %>% 
  mutate(
    age24 = age-24, 
    phase2 = if_else(phase == "F", 0, 1),
    day2 = if_else(day == "W", 1, 0),
    posture2 = case_when(posture == "RECLINE" ~ 0,
                         posture == "SIT" ~ 1,
                         posture == "STAND" ~ 2),
    fh123 = case_when(fh123 == "NO" ~ 0,
                      fh123 == "YES" ~ 1,
                      fh123 == "YESYES" ~ 2)
         ) %>% 
  mutate(fh123 = as.factor(fh123),
         phase2 = as.factor(phase2),
         day2 = as.factor(day2),
         posture2 = as.factor(posture2)) %>% 
  mutate(day3 = if_else(day == "W", "Workday", "Non-Workday")) %>% 
  mutate(standing = if_else(posture2 == 2, 1, 0),
         fh_yes = if_else(fh123 == 0, 0, 1)) %>% # New standing var
  mutate(standing = as.factor(standing),
         fh_yes = as.factor(fh_yes)) %>% 
  mutate(fh_2 = if_else(fh_yes == 1, "Yes", "No")) %>% 
  drop_na()

nurse_bysubject <- nurse_filtered %>% 
  mutate(phase3 = if_else(phase2 == 0, "Follicular", "Luteal"),
         day3 = if_else(day2 == 1, "Workday", "Non-Workday")) %>% 
  group_by(snum) %>% 
  summarize(
    mean_sys = mean(sys),
    phase3 = first(phase3), day3 = first(day3), 
    age2 = first(age24), fh_2 = first(fh_2), fh123 = first(fh123)
  )
```

## EDA

### Level 1 by Clusters

``` r
# Subset of data to viz bp by time
set.seed(93487303)
nurse_all <- nurse_filtered %>% distinct(snum) %>% pull()
random_snums <- sample(nurse_all, 12)
nurse_small <- nurse_filtered %>% filter(snum %in% random_snums)
ggplot(nurse_small, 
       aes(x = timepass, y = sys)) + 
  geom_point() +
  geom_line() + 
  facet_wrap(~snum) +
  labs(x = "Minutes since first measurement",
       y = "BP")

ggplot(nurse_filtered, aes(x = as.factor(snum), y = sys)) +
  geom_boxplot() +
  labs(x = "Subject ID",
       y = "BP",
       title = "BP by Subjects") +
  theme(axis.text.x = element_text(angle = 90, vjust = 0.5, hjust=1))

ggplot(nurse_filtered, aes(x = timepass, y = sys, color = as.factor(snum))) + 
  geom_point(alpha = 0.3) +
  geom_line(stat = "smooth", method = "lm", se = F, alpha = 0.8) +
    labs(x = "Minutes since first measurement",
       y = "BP",
       title = "BP vs. time passed by Subjects",
       color = "Subject ID") +
  guides(color = "none")

ggplot(nurse_filtered, aes(x = mnact5, y = sys, color = as.factor(snum))) + 
  geom_point(alpha = 0.3) +
  geom_line(stat = "smooth", method = "lm", se = F, alpha = 0.8) +
    labs(x = "Activity Level",
       y = "BP",
       title = "BP vs. Activity Level",
       color = "Subject ID") +
  guides(color = "none")

ggplot(nurse_filtered, aes(x = as.numeric(standing), y = sys, color = as.factor(snum))) + 
  geom_point(alpha = 0.3) +
  geom_line(stat = "smooth", method = "lm", se = F, alpha = 0.8) +
    labs(x = "Standing vs. Not Standing",
       y = "BP",
       title = "BP vs. Posture (2 Levels)",
       color = "Subject ID") +
  guides(color = "none")

ggplot(nurse_filtered, aes(x = mood, y = sys, color = as.factor(snum))) + 
  geom_point(alpha = 0.3) +
  geom_line(stat = "smooth", method = "lm", se = F, alpha = 0.8) +
    labs(x = "Mood",
       y = "BP",
       title = "BP vs. Mood",
       color = "Subject ID") +
  guides(color = "none")
```

### Level 2 Covariates

``` r
## Bivariate
ggplot(nurse_bysubject, aes(x = phase3, y = mean_sys)) +
  geom_boxplot() + 
  labs(x = "Menstural Phase",
       y = "Average Systolic Blood Pressure")

ggplot(nurse_bysubject, aes(x = day3, y = mean_sys)) +
  geom_boxplot() + 
  labs(x = "Workday",
       y = "Average Systolic Blood Pressure")

ggplot(nurse_bysubject, aes(x = fh_2, y = mean_sys)) +
  geom_boxplot() + 
  labs(x = "With Family History",
       y = "Average Systolic Blood Pressure")

ggplot(nurse_bysubject, aes(x = fh123, y = mean_sys)) +
  geom_boxplot() + 
  labs(x = "Number of Parents with Hypertension",
       y = "Average Systolic Blood Pressure")

ggplot(nurse_bysubject, aes(x = as.factor(age2), y = mean_sys)) +
  geom_boxplot(show.legend = F) + 
  geom_smooth(method = "lm", se=TRUE, aes(group=1)) +
  labs(x = "Age",
       y = "Average Systolic Blood Pressure")

## By age
ggplot(nurse_bysubject, aes(x = age2, y = mean_sys)) +
  geom_point() +
  geom_smooth(method = "lm") +
  facet_wrap(~ phase3) +
  labs(x = "Age beyond 24",
       y = "Average Systolic Blood Pressure")

ggplot(nurse_bysubject, aes(x = age2, y = mean_sys)) +
  geom_point() +
  geom_smooth(method = "lm") +
  facet_wrap(~ day3) +
  labs(x = "Age beyond 24",
       y = "Average Systolic Blood Pressure")

ggplot(nurse_bysubject, aes(x = age2, y = mean_sys)) +
  geom_point() +
  geom_smooth(method = "lm") +
  facet_wrap(~ fh_2) +
  labs(x = "Age beyond 24 by Family History",
       y = "Average Systolic Blood Pressure")
```

### Level 1 by Level 2 Covariates

``` r
ggplot(nurse_filtered, aes(x = sys)) +
  geom_histogram(color="white") +
  labs(x = "Systolic Blood Pressure",
       title = "Level 1 BP Distribution")

ggplot(nurse_filtered, aes(x = fh_2, y = sys)) +
  geom_boxplot() + 
  facet_wrap(~ day3) +
  labs(x = "Family History",
       y = "Systolic Blood Pressure",
       title = "Level 1 BP by Workday and Family History")

ggplot(nurse_filtered, aes(x = as.factor(snum), y = sys, fill = day3)) +
  geom_boxplot() +
  labs(x = "Subject ID",
       y = "BP",
       title = "Level 1 BP by Subjects and Workday",
       fill = "Workday") +
  theme(axis.text.x = element_text(angle = 90, vjust = 0.5, hjust=1),
        legend.position = c(0.1, 0.9))

ggplot(nurse_filtered, aes(x = as.factor(snum), y = sys, fill = fh_2)) +
  geom_boxplot() +
  labs(x = "Subject ID",
       y = "BP",
       title = "Level 1 BP by Subjects and Family History",
       fill = "Family History") +
  theme(axis.text.x = element_text(angle = 90, vjust = 0.5, hjust=1),
        legend.position = c(0.1, 0.9))

ggplot(nurse_filtered, aes(x = as.factor(snum), y = sys, fill = as.factor(age24))) +
  geom_boxplot() +
  labs(x = "Subject ID",
       y = "BP",
       title = "Level 1 BP by Subjects and Age",
       fill = "Age") +
  theme(axis.text.x = element_text(angle = 90, vjust = 0.5, hjust=1)) +
  guides(fill = "none")
```

### Spaghetti Plots

``` r
## Time
ggplot(nurse_filtered, aes(x = timepass, y = sys)) +
  geom_line(aes(group = snum), color = "dark grey") +
  geom_smooth(method = "loess", color = "black", se = F, size = 1) +
  facet_wrap(~ day3) +
  labs(x = "Time since first measurement",
       y = "Systolic Blood Pressure")

ggplot(nurse_filtered, aes(x = timepass, y = sys, color = as.factor(day3))) +
  geom_line(aes(group = interaction(snum, day)), alpha = 0.1) +
  geom_smooth(method = "loess", se = FALSE, size = 1) +
  labs(color = "Workday",
       x = "Time since first measurement",
       y = "Systolic Blood Pressure") + theme(legend.position = c(0.2, 0.8))

ggplot(nurse_filtered, aes(x = timepass, y = sys)) +
  geom_line(aes(group = snum), color = "dark grey") +
  geom_smooth(method = "loess", color = "black", se = F, size = 1) +
  facet_wrap(~ fh_2)

ggplot(nurse_filtered, aes(x = timepass, y = sys, color = as.factor(fh_2))) +
  geom_line(aes(group = interaction(snum, day)), alpha = 0.1) +
  geom_smooth(method = "loess", se = FALSE, size = 1) +
  labs(color = "Family History",
       x = "Time since first measurement",
       y = "Systolic Blood Pressure") + theme(legend.position = c(0.2, 0.8))


## Activity level
ggplot(nurse_filtered, aes(x = mnact5, y = sys)) +
  geom_line(aes(group = snum), color = "dark grey") +
  geom_smooth(method = "loess", color = "black", se = F, size = 1) +
  facet_wrap(~ day3)

ggplot(nurse_filtered, aes(x = mnact5, y = sys, color = as.factor(day3))) +
  geom_line(aes(group = interaction(snum, day)), alpha = 0.1) +
  geom_smooth(method = "loess", se = FALSE, size = 1) +
  labs(color = "Workday",
       x = "Activity Level",
       y = "Systolic Blood Pressure") + theme(legend.position = c(0.2, 0.8))

ggplot(nurse_filtered, aes(x = mnact5, y = sys)) +
  geom_line(aes(group = snum), color = "dark grey") +
  geom_smooth(method = "loess", color = "black", se = F, size = 1) +
  facet_wrap(~ fh_2)

ggplot(nurse_filtered, aes(x = mnact5, y = sys, color = as.factor(fh_2))) +
  geom_line(aes(group = interaction(snum, day)), alpha = 0.1) +
  geom_smooth(method = "loess", se = FALSE, size = 1) +
  labs(color = "Family History",
       x = "Activity Level",
       y = "Systolic Blood Pressure") + theme(legend.position = c(0.2, 0.8))


## Posture - 2 levels
ggplot(nurse_filtered, aes(x = standing, y = sys)) +
  geom_boxplot() +
  facet_wrap(~ day3) +
  labs(x = "Standing vs Non Standing",
       y = "Systolic Blood Pressure")

ggplot(nurse_filtered, aes(x = standing, y = sys)) +
  geom_boxplot() +
  facet_wrap(~ fh_2) +
  labs(x = "Standing vs Non Standing",
       y = "Systolic Blood Pressure",
       title = "BP by Standing and Family History") 


## Mood Ratings
ggplot(nurse_filtered, aes(x = mood, y = sys)) +
  geom_line(aes(group = snum), color = "dark grey") +
  geom_smooth(method = "loess", color = "black", se = F, size = 1) +
  facet_wrap(~ day3)

ggplot(nurse_filtered, aes(x = mood, y = sys, color = as.factor(day3))) +
  geom_line(aes(group = interaction(snum, day)), alpha = 0.1) +
  geom_smooth(method = "loess", se = FALSE, size = 1) +
  labs(color = "Workday",
       x = "Mood",
       y = "Systolic Blood Pressure") + theme(legend.position = c(0.2, 0.8))

ggplot(nurse_filtered, aes(x = mood, y = sys)) +
  geom_line(aes(group = snum), color = "dark grey") +
  geom_smooth(method = "loess", color = "black", se = F, size = 1) +
  facet_wrap(~ fh_2)

ggplot(nurse_filtered, aes(x = mood, y = sys, color = fh_2)) +
  geom_line(aes(group = interaction(snum, day)), alpha = 0.1) +
  geom_smooth(method = "loess", se = FALSE, size = 1) +
  labs(color = "Family History",
       x = "Mood",
       y = "Systolic Blood Pressure") + theme(legend.position = c(0.2, 0.8))
```

### Separate MLR

``` r
ls_fits <- group_modify(group_by(nurse_complete, snum), 
                        ~ tidy(lm(sys ~ timepass + mnact5 + standing + mood, 
                                  data =.x))[,1:2])
ls_fits_final <- ls_fits %>%
  pivot_wider(names_from = term, values_from = estimate) %>%
  rename("Intercept"= `(Intercept)`, "Time"= timepass,
         "Activity" = mnact5, "Standing" = standing,
         "Mood" = mood) %>%
  left_join(nurse_bysubject, by = "snum")

## Intercept
ggplot(ls_fits_final, aes(x = day3, y = Intercept)) +
  geom_boxplot() +
  labs(x = "Workday")
ggplot(ls_fits_final, aes(x = fh_2, y = Intercept)) +
  geom_boxplot() +
  labs(x = "Family History")
ggplot(ls_fits_final, aes(x = age2, y = Intercept)) +
  geom_point() +
  geom_smooth(method = "lm", se = F) +
  labs(x = "Age")

## Timepass
ggplot(ls_fits_final, aes(x = day3, y = Time)) +
  geom_boxplot() +
  labs(x = "Workday")
ggplot(ls_fits_final, aes(x = fh_2, y = Time)) +
  geom_boxplot() +
  labs(x = "Family History")
ggplot(ls_fits_final, aes(x = age2, y = Time)) +
  geom_point() +
  geom_smooth(method = "lm", se = F) +
  labs(x = "Age")


## Activity Level
ggplot(ls_fits_final, aes(x = day3, y = Activity)) +
  geom_boxplot() +
  labs(x = "Workday")
ggplot(ls_fits_final, aes(x = fh_2, y = Activity)) +
  geom_boxplot() +
  labs(x = "Family History")
ggplot(ls_fits_final, aes(x = age2, y = Activity)) +
  geom_point() +
  geom_smooth(method = "lm", se = F) +
  labs(x = "Age")


## Standing
ggplot(ls_fits_final, aes(x = day3, y = Standing)) +
  geom_boxplot() +
  labs(x = "Workday")
ggplot(ls_fits_final, aes(x = fh_2, y = Standing)) +
  geom_boxplot() +
  labs(x = "With Family History")
ggplot(ls_fits_final, aes(x = age2, y = Standing)) +
  geom_point() +
  geom_smooth(method = "lm", se = F) +
  labs(x = "Age")


## Mood
ggplot(ls_fits_final, aes(x = day3, y = Mood)) +
  geom_boxplot() +
  labs(x = "Workday")
ggplot(ls_fits_final, aes(x = fh_2, y = Mood)) +
  geom_boxplot() +
  labs(x = "Number of Parents with Hypertension")
ggplot(ls_fits_final, aes(x = age2, y = Mood)) +
  geom_point() +
  geom_smooth(method = "lm", se = F) +
  labs(x = "Age")
```

## Model Selection

### Base Model (Random Intercept)

``` r
nurse_lmm_RI <- lmer(sys ~ timepass + (1 | snum), data = nurse_filtered)
summary(nurse_lmm_RI)

nurse_lm <- lm(sys ~ timepass, data = nurse_filtered)
summary(nurse_lm)


(lrt_RI <- as.numeric(2*(logLik(nurse_lmm_RI, REML = TRUE) - 
                            logLik(nurse_lm, REML = TRUE))))
.5*(1-pchisq(lrt_RI, df = 0))+.5*(1-pchisq(lrt_RI, df = 1))
```

### Random Intercept with Level 1 Covariates

``` r
nurse_lmm_RI_lv1 <- lmer(sys ~ timepass + mnact5 + standing + mood + 
                       (1 | snum), data = nurse_filtered)

summary(nurse_lmm_RI_lv1)
anova(nurse_lmm_RI, nurse_lmm_RI_lv1)

# No mood
nurse_lmm_RI_noMood <- lmer(sys ~ timepass + mnact5 + standing +
                       (1 | snum), data = nurse_filtered)
anova(nurse_lmm_RI_noMood, nurse_lmm_RI_lv1)

# No mood or time
nurse_lmm_RI_noMoodTime <- lmer(sys ~ mnact5 + standing +
                       (1 | snum), data = nurse_filtered) #still use time
anova(nurse_lmm_RI_noMoodTime, nurse_lmm_RI_noMood)
anova(nurse_lmm_RI_noMoodTime, nurse_lmm_RI_lv1)
```

### Random Intercept and Slope

``` r
nurse_lmm_RIS_stand <- lmer(sys ~ timepass + mnact5 + standing + 
                       (1 + standing | snum), 
                       data = nurse_filtered)
summary(nurse_lmm_RIS_stand)

(lrt_RIS_stand <- as.numeric(2*(logLik(nurse_lmm_RIS_stand, REML = TRUE) - 
                            logLik(nurse_lmm_RI, REML = TRUE))))
.5*(1-pchisq(lrt_RIS_stand, df = 1))+.5*(1-pchisq(lrt_RIS_stand, df = 2))
```

### Random Intercept and Slope with Level 2 Covariates

``` r
# Age
nurse_lmm_RIS_age <- lmer(sys ~ timepass + mnact5 + standing * age24 + 
                       (1 + standing | snum),
                       data = nurse_filtered)

summary(nurse_lmm_RIS_age)
anova(nurse_lmm_RIS_stand, nurse_lmm_RIS_age)
```

``` r
# Workday
nurse_lmm_RIS_day <- lmer(sys ~ day2 * (timepass + standing) + mnact5 + 
                       (1 + standing | snum),
                       data = nurse_filtered)

summary(nurse_lmm_RIS_day)
anova(nurse_lmm_RIS_stand, nurse_lmm_RIS_day)

nurse_lmm_RIS_day_nostand <- lmer(sys ~ day2 * (timepass) + standing + mnact5 + 
                       (1 + standing | snum),
                       data = nurse_filtered)
anova(nurse_lmm_RIS_day, nurse_lmm_RIS_day_nostand)
anova(nurse_lmm_RIS_day_nostand, nurse_lmm_RIS_stand)

nurse_lmm_RIS_day_nointer <- lmer(sys ~ day2 + timepass + standing + mnact5 + 
                       (1 + standing | snum),
                       data = nurse_filtered)
anova(nurse_lmm_RIS_day_nostand, nurse_lmm_RIS_day_nointer)
```

``` r
# Family history
nurse_lmm_RIS_day_fh <- lmer(sys ~ (day2 + fh_yes) * timepass + 
                                    standing + mnact5 + 
                       (1 + standing | snum),
                       data = nurse_filtered)
anova(nurse_lmm_RIS_day_fh, nurse_lmm_RIS_day_nostand)
anova(nurse_lmm_RIS_day_fh, nurse_lmm_RIS_stand)
```

``` r
nurse_lmm_RIS_day_fh_nocorr <- lmer(sys ~ (day2 + fh_yes) * timepass + 
                                    standing + mnact5 + 
                       (1 + standing || snum),
                       data = nurse_filtered) #Convergence issue, have corr
anova(nurse_lmm_RIS_day_fh, nurse_lmm_RIS_day_fh_nocorr, refit = FALSE)
```

## Model Diagnostics

### Residual Analysis

``` r
final_model <- nurse_lmm_RIS_day_fh

nurse_resid1 <- hlm_resid(final_model, level = 1, standardize = TRUE)
nurse_resid2 <- hlm_resid(final_model, level = "snum", include.ls = FALSE)
```

#### Marginal Residuals

``` r
ggplot(data = nurse_resid1, aes(x = .mar.fitted, y = .chol.mar.resid)) + 
  geom_point(alpha=0.2) + 
  geom_smooth() +
  labs(x = "Fitted Marginal",
       y = "Marginal Residuals") 
ggplot(data = nurse_resid1, aes(x = timepass, y = .chol.mar.resid)) + 
  geom_point(alpha=0.2) + 
  geom_smooth() +
  labs(x = "Minutes since first measurement",
       y = "Marginal Residuals")
ggplot(data = nurse_resid1, aes(x = as.factor(standing), y = .chol.mar.resid)) + 
  geom_boxplot() + 
  # geom_smooth() +
  labs(x = "Standing vs. Not standing",
       y = "Marginal Residuals")
ggplot(data = nurse_resid1, aes(x = mnact5, y = .chol.mar.resid)) + 
  geom_point(alpha=0.2) + 
  geom_smooth() +
  labs(x = "Activity Level",
       y = "Marginal Residuals")
```

#### Conditional Residuals

``` r
ggplot(data = nurse_resid1, aes(x = .mar.fitted, y = .std.resid)) + 
  geom_point(alpha=0.2) + 
  geom_smooth() +
  labs(x = "Fitted Conditional Means",
       y = "Conditional Residuals") 
ggplot(data = nurse_resid1, aes(x = timepass, y = .std.resid)) + 
  geom_point(alpha=0.2) + 
  geom_smooth() +
  labs(x = "Minutes since first measurement",
       y = "Conditional Residuals")
ggplot(data = nurse_resid1, aes(x = as.factor(standing), y = .std.resid)) + 
  geom_boxplot() + 
  # geom_smooth() +
  labs(x = "Standing vs. Not standing",
       y = "Conditional Residuals")
ggplot(data = nurse_resid1, aes(x = mnact5, y = .std.resid)) + 
  geom_point(alpha=0.2) + 
  geom_smooth() +
  labs(x = "Activity Level",
       y = "Conditional Residuals")

ggplot(nurse_resid1, aes(sample = .std.resid)) +
  stat_qq_line()+ 
  stat_qq()
```

#### Try transformations — Didn’t work

``` r
# Exponential model
nurse_lmm_RIS_logx <- lmer(sys ~ (day2 + fh_yes) * timepass + 
                                    standing + log(mnact5 + 1)  + mood + 
                       (1 + mood + standing | snum),
                       data = nurse_filtered)
nurse_resid1_logx <- hlm_resid(nurse_lmm_RIS_logx, level = 1, standardize = TRUE)

ggplot(data = nurse_resid1_logx, aes(x = .mar.fitted, y = .std.resid)) + 
  geom_point(alpha=0.2) + 
  geom_smooth() +
  labs(x = "Logged Fitted Conditional",
       y = "Conditional Residuals") 
ggplot(data = nurse_resid1_logx, aes(x = `log(mnact5 + 1)`, y = .std.resid)) + 
  geom_point(alpha=0.2) + 
  geom_smooth() +
  labs(x = "Activity Level",
       y = "Conditional Residuals")
```

``` r
# Logarithmic
nurse_lmm_RIS_logy <- lmer(log(sys) ~ (day2 + fh_yes) * timepass + 
                                    standing + mnact5 + mood + 
                       (1 + mood + standing | snum),
                       data = nurse_filtered)
nurse_resid1_logy <- hlm_resid(nurse_lmm_RIS_logy, level = 1, standardize = TRUE)

ggplot(data = nurse_resid1_logy, aes(x = .mar.fitted, y = .std.resid)) + 
  geom_point(alpha=0.2) + 
  geom_smooth() +
  labs(x = "Fitted Conditional",
       y = "Conditional Residuals") 
ggplot(data = nurse_resid1_logy, aes(x = mnact5, y = .std.resid)) + 
  geom_point(alpha=0.2) + 
  geom_smooth() +
  labs(x = "Activity Level",
       y = "Conditional Residuals")
```

``` r
# power
nurse_lmm_RIS_loglog <- lmer(log(sys) ~ (day2 + fh_yes) * timepass + 
                                    standing + log(mnact5 + 1)  + mood + 
                       (1 + mood + standing | snum),
                       data = nurse_filtered)
nurse_resid1_loglog <- hlm_resid(nurse_lmm_RIS_loglog, level = 1, standardize = TRUE)

ggplot(data = nurse_resid1_loglog, aes(x = .mar.fitted, y = .std.resid)) + 
  geom_point(alpha=0.2) + 
  geom_smooth() +
  labs(x = "Fitted Conditional",
       y = "Conditional Residuals") 
ggplot(data = nurse_resid1_loglog, aes(x = `log(mnact5 + 1)`, y = .std.resid)) + 
  geom_point(alpha=0.2) + 
  geom_smooth() +
  labs(x = "Logged Activity Level",
       y = "Conditional Residuals")
```

#### LS Residuals

``` r
ggplot(data = nurse_resid1, aes(x = .mar.fitted, y = .std.ls.resid)) + 
  geom_point(alpha=0.2) + 
  geom_smooth() +
  labs(x = "Fitted Values",
       y = "LS Residuals") 
ggplot(data = nurse_resid1, aes(x = timepass, y = .std.ls.resid)) + 
  geom_point(alpha=0.2) + 
  geom_smooth() +
  labs(x = "Minutes since first measurement",
       y = "LS Residuals")
ggplot(data = nurse_resid1, aes(x = as.factor(standing), y = .std.ls.resid)) + 
  geom_boxplot() + 
  # geom_smooth() +
  labs(x = "Standing vs. Not standing",
       y = "LS Residuals")
ggplot(data = nurse_resid1, aes(x = mnact5, y = .std.ls.resid)) + 
  geom_point(alpha=0.2) + 
  geom_smooth() +
  labs(x = "Activity Level",
       y = "LS Residuals")

ggplot(nurse_resid1, aes(sample = .std.ls.resid)) +
  stat_qq_line()+ 
  stat_qq()
ggplot(nurse_resid1, aes(x = as.factor(snum), y = .std.ls.resid)) +
  geom_boxplot() +
  geom_hline(yintercept = 0) +
  labs(x = "Subject ID",
       y = "LS Residuals") +
  theme(axis.text.x = element_text(angle = 90, vjust = 0.5, hjust=1))
```

#### Lv 2 RE

``` r
ggplot(nurse_resid2, aes(sample = .ranef.intercept)) +
  stat_qq_line()+ 
  stat_qq()
ggplot(nurse_resid2, aes(sample = .ranef.standing1)) +
  stat_qq_line()+ 
  stat_qq()

nurse_age_phase <- nurse_filtered %>% 
  mutate(snum = as.character(snum)) %>% 
  group_by(snum) %>%
  summarize(nurse_age = first(age24),
            nurse_phase = first(phase)) %>% 
  left_join(nurse_resid2, by = "snum")

## Intercept
ggplot(nurse_age_phase, aes(x = as.factor(nurse_age), y = .ranef.intercept)) +
  geom_boxplot() + 
  geom_hline(yintercept = 0) +
  geom_smooth(method = "lm", se=TRUE, aes(group=1)) +
  labs(title = "RE intercept vs Centered Age",
       x = "Centered Age",
       y = " RE Intercept")
ggplot(nurse_age_phase, aes(x = nurse_phase, y = .ranef.intercept)) +
  geom_boxplot() +
  geom_hline(yintercept = 0) +
  labs(title = "RE intercept vs Menstrual Phase",
       x = "Menstrual Phase",
       y = " RE Intercept")
```

### Influential Statistics

``` r
nurse_infl2 <- hlm_influence(final_model, level = "snum", approx = FALSE, 
                             leverage = c("overall", "fixef", "ranef.uc"))
```

#### Cook’s Dist

``` r
dotplot_diag(nurse_infl2$cooksd, name = "cooks.distance", cutoff = "internal")

cd_flagged <- nurse_infl2 %>% 
  arrange(desc(cooksd)) %>% 
  slice(1:3) %>% 
  pull(snum)

ggplot(nurse_filtered, aes(x = timepass, y = sys))+
  geom_point() + 
  geom_point(data = nurse_filtered %>% filter(snum %in% cd_flagged), color = "red") +
  geom_smooth(method = "lm", se = F) +
  facet_grid(rows = vars(day3), cols = vars(fh_2)) +
  labs(x = "Time passed",
       y = "BP")
```

#### RVC

``` r
dotplot_diag(nurse_infl2$rvc.D11, name = "rvc", cutoff = "internal", modify = "boxplot")
dotplot_diag(nurse_infl2$rvc.D22, name = "rvc", cutoff = "internal", modify = "boxplot")

rvc1_flagged <- nurse_infl2 %>%
  arrange(desc(rvc.D11)) %>%
  slice(1) %>%
  pull(snum)
rvc2_flagged <- nurse_infl2 %>%
  arrange(desc(rvc.D22)) %>%
  slice(1:2) %>%
  pull(snum)

ggplot(nurse_filtered, aes(x = timepass, y = sys))+
  geom_point() + 
  geom_point(data = nurse_filtered %>% filter(snum %in% rvc1_flagged), color = "red") +
  geom_smooth(method = "lm", se = F) +
  facet_grid(rows = vars(day3), cols = vars(fh_2)) +
  labs(x = "Time passed",
       y = "BP")
  ggplot(nurse_filtered, aes(x = timepass, y = sys))+
  geom_point() + 
  geom_point(data = nurse_filtered %>% filter(snum %in% rvc2_flagged), color = "red") +
  geom_smooth(method = "lm", se = F) +
  facet_grid(rows = vars(day3), cols = vars(fh_2)) +
  labs(x = "Time passed",
       y = "BP")
```

#### Leverage

``` r
dotplot_diag(nurse_infl2$leverage.overall, name = "leverage", cutoff = "internal", modify = "boxplot")
dotplot_diag(nurse_infl2$leverage.fixef, name = "leverage", cutoff = "internal", modify = "boxplot")
dotplot_diag(nurse_infl2$leverage.ranef.uc, name = "leverage", cutoff = "internal", modify = "boxplot")

lev_flagged <- nurse_infl2 %>%
  arrange(desc(leverage.overall)) %>%
  slice(1:3) %>%
  pull(snum)

ggplot(nurse_filtered, aes(x = timepass, y = sys))+
  geom_point() + 
  geom_point(data = nurse_filtered %>% filter(snum %in% lev_flagged), color = "red") +
  geom_smooth(method = "lm", se = F) +
  facet_grid(rows = vars(day3), cols = vars(fh_2)) +
  labs(x = "Time passed",
       y = "BP")
```

## Effects Interpretation

### Confidence Intervals

``` r
confint(final_model, parm = "beta_", method = "boot") -> boot_ci
kable(boot_ci)
confint(final_model, parm = "beta_") -> ci
kable(ci)
kable(tidy(final_model))
```

``` r
lattice::dotplot(ranef(final_model))
```

### Effects Plots

``` r
timepass_all <- nurse_filtered %>% distinct(timepass) %>% pull()
random_timepass <- sample(timepass_all, 3)
# plot(predictorEffects(final_model, xlevels = list(timepass = random_timepass)))
plot(predictorEffects(final_model, xlevels = 4),
                      axes = list(
                        x = list(rug = F, rotate = 90,
                                 day2 = list(lab = "Workday"), 
                                 fh_yes = list(lab = "Family History"), 
                                 timepass = "Time Passed", 
                                 standing = "Standing",
                                 mnact5 = list(lab = "Activity Level"), 
                                 mood = "Mood"),
                        y = list(ticks=list(at=c(110, 114, 118, 122, 126)),
                                 lab = "Blood Pressure"))
                      )
```

``` r
nurse_filtered <- nurse_filtered %>%
          # predicted means with RE
  mutate(fit_cond = predict(final_model), 
         fit_marg = predict(final_model, re.form = NA))
          # predicted means without RE

ggplot(nurse_filtered, aes(x=timepass, y = sys)) +
  geom_point() +
  geom_line(aes(y = fit_cond, group = snum), color = "darkgrey") +
  geom_line(aes(y = fit_marg), color = "red", size = 1, alpha = 0.5) +
  facet_grid(rows = vars(day3), cols = vars(fh_2)) + 
  labs(title = "Blood Pressure vs Time Passed, by Workday and Family History",
       x = "Minutes since first measurement",
       y = "Systolic Blood Pressure") +
  theme_minimal(base_size = 17)
```
