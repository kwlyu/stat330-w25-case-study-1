
# Prompt (BLMR)

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

Potential alternative directions: consider diastolic blood pressure or
heart rate as the primary response variable, or even try modeling
emotion rating using a multilevel model.

# Modeling

## Data Wrangling

``` r
nurse <- read.csv("https://math.carleton.edu/kstclair/data/bmlr/nursebp.csv",
                  stringsAsFactors = TRUE) %>% 
  as_tibble %>% 
  select(-c(DIA, HRT, timept)) %>% 
  janitor::clean_names() 
glimpse(nurse)
out<-md.pattern(nurse, rotate.names=T) #missingness pattern

nurse_filtered <- nurse %>% 
  drop_na() %>% 
  mutate(
    snum = as.factor(snum),
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
  mutate(day3 = if_else(day == "W", "Workday", "Non-Workday"))

nurse_bysubject <- nurse_filtered %>% 
  mutate(phase3 = if_else(phase2 == 0, "Follicular", "Luteal"),
         day3 = if_else(day2 == 1, "Workday", "Non-Workday")) %>% 
  group_by(snum) %>% 
  summarize(
    mean_sys = mean(sys),
    phase3 = first(phase3), day3 = first(day3), 
    age2 = first(age), fh123 = first(fh123)
  )
```

## EDA

``` r
ggplot(nurse_bysubject, aes(x = phase3, y = mean_sys)) +
  geom_boxplot() + 
  labs(x = "Menstural Phase",
       y = "Average Systolic Blood Pressure")

ggplot(nurse_bysubject, aes(x = day3, y = mean_sys)) +
  geom_boxplot() + 
  labs(x = "Workday",
       y = "Average Systolic Blood Pressure")

ggplot(nurse_bysubject, aes(x = fh123, y = mean_sys)) +
  geom_boxplot() + 
  labs(x = "Number of Parents with Hypertension",
       y = "Average Systolic Blood Pressure")


ggplot(nurse_bysubject, aes(x = age2, y = mean_sys)) +
  geom_point() +
  geom_smooth() +
  facet_wrap(~ phase3) +
  labs(x = "Age",
       y = "Average Systolic Blood Pressure")

ggplot(nurse_bysubject, aes(x = age2, y = mean_sys)) +
  geom_point() +
  geom_smooth() +
  facet_wrap(~ day3) +
  labs(x = "Age",
       y = "Average Systolic Blood Pressure")

ggplot(nurse_bysubject, aes(x = age2, y = mean_sys)) +
  geom_point() +
  geom_smooth() +
  facet_wrap(~ fh123) +
  labs(x = "Age by Number of Parents with Hypertension",
       y = "Average Systolic Blood Pressure")
```

``` r
ggplot(nurse_filtered, aes(x = sys)) +
  geom_histogram(color="white") +
  labs(x = "Systolic Blood Pressure",
       title = "Level 1 BP Distribution")

ggplot(nurse_filtered, aes(x = fh123, y = sys)) +
  geom_boxplot() + 
  facet_wrap(~ day3) +
  labs(x = "Number of Parents with Hypertension",
       y = "Systolic Blood Pressure",
       title = "Level 1 BP by Workday and Family History")
```

``` r
set.seed(93487303)
nurse_all <- nurse_filtered %>% distinct(snum) %>% pull()
random_snums <- sample(nurse_all, 12)
nurse_small <- nurse_filtered %>% filter(snum %in% random_snums)
ggplot(nurse_small, 
       aes(x = timepass, y = sys)) + 
  geom_point() +
  geom_line() + 
  facet_wrap(~snum)
```

``` r
ggplot()
```
