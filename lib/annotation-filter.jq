# Shared jq helpers for annotation HTML. Expect --argjson filter with:
#   categories: ["FINDING_CATEGORY_SCA", ...]
#   require_ai: bool
#   exclude_ai: bool
#   admission_patterns: ["Vulnerabilit", "SAST", ...]  # substring match, case-insensitive

def finding_matches_step:
  (.spec.finding_categories // []) as $cats |
  if ($filter.categories | length) == 0 then
    true
  else
    (any($cats[]?; . as $c | ($filter.categories | index($c))))
  end and
  if $filter.require_ai then
    any(.spec.finding_tags[]?; . == "FINDING_TAGS_AI")
  else
    true
  end and
  if $filter.exclude_ai then
    (any(.spec.finding_tags[]?; . == "FINDING_TAGS_AI") | not)
  else
    true
  end;

def admission_matches_step:
  . as $msg |
  (($filter.admission_patterns | length) > 0) and
  any($filter.admission_patterns[]?; . as $p | ($msg | test($p; "i")));

def filtered_all_findings:
  [.all_findings[]? | select(finding_matches_step)];

def filtered_blocking_findings:
  [.blocking_findings[]?
    | select(type == "object" and (.spec != null) and (.spec != {}))
    | select(finding_matches_step)];

def filtered_warning_findings:
  [.warning_findings[]?
    | select(type == "object" and (.spec != null) and (.spec != {}))
    | select(finding_matches_step)];

def filtered_admission_warnings:
  [.warnings[]? | strings | select(admission_matches_step)];
