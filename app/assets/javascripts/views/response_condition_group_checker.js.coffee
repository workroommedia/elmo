# Evaluates a single condition in the responses view.
class ELMO.Views.ResponseConditionGroupChecker extends ELMO.Views.ApplicationView

  initialize: (options) ->
    @conditionGroup = options.group
    @checkers = @conditionGroup.members.map (m) =>
      if m.type == "ConditionGroup"
        new ELMO.Views.ResponseConditionGroupChecker(el: @el, refresh: options.refresh, group: m)
      else
        new ELMO.Views.ResponseConditionChecker(el: @el, refresh: options.refresh, condition: m)

    # Unlike the manager and the leaf node checkers, do NOT do anything to initialize here. The manager takes
    # care of that by calling refresh in its initialization.

  # Evaluates the children and returns the result.
  evaluate: ->
    if @conditionGroup.trueIf == 'always'
      @applyNegation(true)
    else if @conditionGroup.trueIf == 'all_met'
      @applyNegation(@childrenAllMet())
    else # any_met
      @applyNegation(@childrenAnyMet())

  childrenAllMet: ->
    results = @results()
    results.indexOf(false) == -1

  childrenAnyMet: ->
    @results().indexOf(true) != -1

  applyNegation: (bool) ->
    if @conditionGroup.negate
      !bool
    else
      bool

  results: ->
    @checkers.map (c) -> c.evaluate()
