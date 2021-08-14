# Break Accuracy in British Parliamentary Debating

This is my attempt to replicate the model employed in [Barnes et al. 2020](https://international-debate.com/2020/03/18/tapered-points/) using the methods and parameters described therein. Its intended use case is as a starting point for researchers interested in British Parliamentary scoring systems, and proposed improvements to the status quo system. By releasing it open source, I hope to encourage continued and transparent discussion on this topic. This break accuracy simulator may also be of interest to tournament convenors and chief adjudicators interested in preserving the accuracy of a tournament's results while contending with logistical constraints.

---
## How to use
Because this was designed to compare scoring systems, I include the `et_sq_sp_compare()` function, which compares the early taper, status quo, and speaker points scoring systems across five break accuracy and order metrics. Below is a visualization of the results of a small sample (N=100) simulation of a WUDC-like tournament, with nine rounds and 360 teams.
![](results-et_sq_sp_compare.png)



## Next steps
Here are some areas in which the current version should be improved:
- **General debugging:** I have no formal training in programming, so there are many places where the code is inefficient, and may lead to incorrect outcomes. I anticipate (as per Cunningham's law) that many errors will be pointed out to me after I release this on the Internet.
- **Larger simulations:** Running simulations with more iterations will increase their precision. I am wary of running these while there are still potential mistakes in my code that would render any results obtained invalid.
- **A more accessible way of interacting with this:** The simplest way to make results accessible would be to run a bunch of simulations across a range of values for the parameters (e.g., number of teams, judge bias, variance in baseline skill, break size) and pop the statistics into an Excel file so that tournament convenors, etc. can get a rough idea of how to make their specific tournaments more accurate without running their own simulations.
- **More scoring systems:** So far, I've included nine-round early taper, status quo, and speaker points scoring systems. The model is designed such that the scoring systems already included can be swapped out for other systems without having to touch other parts of the code. (This is also true of adding new ways of allocating teams and of calculating new accuracy/order metrics.)
