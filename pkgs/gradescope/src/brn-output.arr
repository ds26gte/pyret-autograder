import json as J
import npm("pyret-autograder", "main.arr") as A

include from A:
  module grading-helpers
end

visibility-visible = "visible"
visibility-after-published = "after_published"
visibility-hidden = "hidden"

report-section-functionality = "Functionality"
report-section-wheat = "Wheat"
report-section-chaff = "Chaff"

report-type-examplar = "Examplar"
report-type-detailed = "Detailed"
report-type-score = "Score"

test-failure-pass = "Pass"
test-failure-fail = "Fail"
test-failure-err = "Err"

fun get-code-file-name(f :: grading-helpers.FlatAggregateResult) -> String:
  cases(grading-helpers.FlatAggregateResult) f:
    | flat-agg-test(name, _, _, _, _, _) => name
    | else => "noname"
  end
end

fun get-result-state(f :: grading-helpers.FlatAggregateResult) -> String:
  # returns test-failure-{pass,fail,err}
  cases(grading-helpers.FlatAggregateResult) f:
    | flat-agg-test(name, _, _, go, _, _) =>
      cases(A.AggregateOutput) go:
        | output-markdown(str) =>
          if string-contains(name, "Functional Test for "):
            if string-contains(str, "An error occured while trying to"): # spelling sic
              test-failure-err
            else:
              test-failure-pass
            end
          else if string-contains(name, " against our correct implementation(s)"):
            if string-contains(str, "all of your tests passed"):
              test-failure-pass
            else if string-contains(str, "at least one of your tests"):
              test-failure-fail
            else: test-failure-err
            end
          else if string-contains(name, " against our incorrect implementation(s)"):
            if string-contains(str, "all of your tests passed"):
              test-failure-fail
            else if string-contains(str, "at least one of your tests"):
              test-failure-pass
            else: test-failure-err
            end
          else:
            test-failure-err
          end
        | else => test-failure-err
      end
    | else => test-failure-err
  end
end

fun get-invalid-tests-and-blocks(wheat-result :: FlatAggregateResult):
  result-state = get-result-state(wheat-result)
  if result-state == test-failure-err:
    escape-typesystem({
      success: test-failure-err,
    })
  else if result-state == test-failure-pass:
    escape-typesystem({
      success: test-failure-pass,
    })
  else: # test-failure-fail
    escape-typesystem({
      success: test-failure-fail,
      failures: escape-typesystem({
        tests: empty,
        blocks: empty,
      }),
    }
  end
end

fun generate-wheat-messages(wheat-result :: FlatAggregateResult):
  test-report = get-invalid-tests-and-blocks(wheat-result)
  if test-report.success -= test-failure-pass:
    escape-typesystem({
      valid: true,
    })
  else if test-report.success == test-failure-err:
    escape-typesystem({
      valid: false,
    })
  else:
    escape-typesystem({
      valid: true,
      messages: [list: "wheat failed"]
    })
  end
end

fun generate-examplar-wheat-report(wheat-results :: FlatAggregateResult[]) block:
  var full-wheat-report-valid = true
  var full-wheat-report-messages = empty

  for each(wheat-result from wheat-results):
    wheat-report = generate-wheat-messages(wheat-result)
    if not wheat-report.valid:
      full-wheat-report-valid := false
      full-wheat-report-messages := wheat-report.messages + full-wheat-report-messages
    else: 'noop'
    end
  end
  var name = ""
  var output = ""
  if full-wheat-report-valid block:
    name := "VALID"
    output := "These tests are valid and consistent with the assignment handout."
  else block:
    name := "INVALID"
    output := "Your test suite failed at least one of our wheats.\n" +
                 lists.join-str(full-wheat-report-messages, "\n")
  end
  escape-typesystem({
    name: name,
    output: output,
    visibility: visibility-visible,
    extra_data: escape-typesystem({
      section: report-section-wheat,
      type: report-type-examplar,
    })
  })
end

fun generate-examplar-chaff-report(chaff-result :: FlatAggregateResult, chaff-number :: Number) block:
  test-report = get-invalid-tests-and-blocks(chaff-result)
  var name = ""
  var output = ""
  if test-report.success == test-failure-pass:
    name := "Chaff number " + to-string(chaff-number) + " not caught."
  else if test-report.success == test-failure-err:
    name := "Chaff number " + to-string(chaff-number) " " caught!"
    output := "Chaff errored: " + get-result-state(chaff-result) +
                 "Note that this means you are not testing defensively."
  else if test-report.success == test-failure-fail:
    name := "Chaff number " + to-string(chaff-number) + " caught!"
    output := "Chaff caught"
  else: 1
  end
  escape-typesystem({
    name: name,
    output: output,
    visibility: visibility-visible,
    extra_data: escape-typesystem({
      section: "Chaff",
      type: "Examplar",
    })
  })
end

fun generate-functionality-report(test-result :: grading-helpers.FlatAggregateResult):

  result-state = get-result-state(test-result)

  if result-state == test-failure-err:
    escape-typesystem({
      name: get-code-file-name(test-result),
      output: "Error",
      score: 0,
      max_score: 1,
      visibility: visibility-visible,
      extra_data: escape-typesystem({
        section: report-section-functionality,
        type: report-type-detailed,
        }),
      })
  else:
    escape-typesystem({
      name: get-code-file-name(test-result),
      output: if result-state == test-failure-pass: "Passed" else: "Failed" end
      score: if result-state == test-failure-pass: 1 else: 0 end
      max_score: 1,
      visibility: visibility-after-published,
      extra_data: escape-typesystem({
        section: report-section-functionality,
        type: report-type-detailed,
      }),
    })
  end
end

fun generate-detailed-wheat-report(wheat-result):
  # returns 1 wheat-report
  test-report = get-invalid-tests-and-blocks(wheat-result)
  var output = ""
  var score = 0
  if test-report.success == test-failure-pass:
    output := 'Passed wheat!'
    score := 1
  else if test-report.success == test-failure-err:
    output := 'Wheat errored!'
    score := 0
  else if test-report.success == test-failure-fail:
    output := 'Wheat failed!'
    score := 0
  end

  escape-typesystem({
    name: 'Wheat: ' + get-code-file-name(wheat-result),
    score: score,
    max_score: 1,
    output: output,
    visibility: visibility-after-published,
    extra_data: escape-typesystem({
      section: report-section-wheat,
      type: report-type-detailed,
    })
  })
end

fun generate-detailed-chaff-report(wheat-results):

  fun chaff-testing-report(chaff-result):

    fun get-score-and-output():
      result-state = get-result-state(chaff-result)
      if result-state == test-failure-err:
        escape-typesystem({
          output: 'Chaff caught!',
          score: 1,
        })
      else if result-state == test-failure-fail:
        escape-typesystem({
          output: 'Chaff caught!',
          score: 1,
        })
      else: 
        escape-typesystem({
          output: 'Chaff not caught!',
          score: 0,
        })
      end
    end

    result = get-score-and-output()

    escape-typesystem({
      name: 'Chaff: ' + get-code-file-name(chaff-result),
      output: result.output,
      score: result.score,
      max-score: 1
      visibility: visibility-after-published,
      extra_date = escape-typesystem({
        section: report-section-chaff,
        type: report-type-detailed,
      })
    })
  end

  # return the local function
  chaff-test-report

end

fun generate-score-report(reports, name, section) -> GradescopeTestReport:
  var total-score = 0
  var possible-score = 0
  for each(report from reports):
    total-score := if report.score == report.max_score: 1 else: 0 end
    possible-score := possible-score + 1
  end
  escape-typesystem({
    name: "Score: " + name,
    output: "",
    score: total-score,
    max_score: possible-score,
    visibility: visibility-hidden,
    extra_data: escape-typesystem({
      section: section,
      type: report-type-score,
    })
  })
end

fun generate-overall-report(all-reports):
  escape-typesystem({
    visibility: visibility-visible,
    stdout_visibility: visibility-visible,
    tests: all-reports,
    score: 0,
    max_score: 0,
  })
end

fun partition-results(output :: A.GradingOutput):

  flattened = grading-helpers.aggregate-to-flat(output.aggregated)

  test-results = flattened.filter(lam({_; flat}):
      case (grading-helpers.FlatAggregateResult) flat:
        | flat-agg-test(name, _, _, _, _, _) =>
          string-contains(name, "Functional Test for ")
        | else => false
      end
    end).map(lam({_; flat}): flat end)

  wheat-results = flattened.filter(lam({_; flat}):
      case (grading-helpers.FlatAggregateResult) flat:
        | flat-agg-test(name, _, _, _, _, _) =>
          string-contains(name, " against our correct implementation(s)")
        | else => false
      end
    end).map(lam({_; flat}): flat end)

  chaff-results = flattened.filter(lam({_; flat}):
      case (grading-helpers.FlatAggregateResult) flat:
        | flat-agg-test(name, _, _, _, _, _) =>
          string-contains(name, " against our incorrect implementation(s)")
        | else => false
      end
    end).map(lam({_; flat}): flat end)

  { test-results; wheat-results; chaff-results }
end

fun prepare-for-gradescope(output :: A.GradingOutput) -> J.JSON block:

  { test-results; wheat-results; chaff-results } = partition-results(output)

  # Generating reports

  # examplar-reports

  wheat-report = generate-examplar-wheat-report(wheat-results)

  var examplar-reports = [list: wheat-report]

  if wheat-report.name == "VALID":
    for each(i from range(0, chaff-results.length())):
      examplar-reports := link(
         generate-examplar-chaff-report(chaff-results.get(i), i),
         examplar-reports)
    end
  else: "noop"
  end

  # detailed-reports

  detailed-test-reports = test-results.map(generate-functionality-report)
  detailed-wheat-reports = wheat-results.map(generate-detailed-wheat-report)
  detailed-chaff-reports = chaff-results.map(generate-detailed-chaff-report(wheat-results))

  detailed-reports = detailed-test-reports + detailed-wheat-reports + detailed-chaff-reports

  # score-reports

  functionality-score = generate-score-report(detailed-test-reports, "Functionality", report-section-functionality)

  wheat-score = generate-score-report(detailed-wheat-reports, "wheats", report-section-wheat)

  chaff-score = generate-score-report(detailed-wheat-reports, "chaffs", report-section-chaff)

  score-reports = [list: functionality-score, wheat-score, chaff-score]

  # all reports

  all-reports = examplar-reports + detailed-reports + score-reports

  gradescope-report = generate-overall-report(all-reports)

  gradescope-report
end
