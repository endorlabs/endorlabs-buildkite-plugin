include "annotation-filter";

# Table row helpers for annotation HTML. Requires:
#   include "annotation-filter" (via -L lib)
#   --argjson filter
#   --arg table_mode  (dependencies | secrets | sast | ai-sast | container | generic)
#   --arg base
#   --argjson limit

def dismissed_filter_encoded:
  {"findingExceptions":{"comparator":"NOT_EQUAL","key":"spec.dismiss","value":true}}
  | tojson
  | @uri;

def resource_detail_encoded($ns; $fuuid):
  {"findingUuid": $fuuid, "findingNamespace": $ns}
  | tojson
  | @uri;

def version_findings_url($ns; $pu; $cid):
  "\($base)/t/\($ns|@uri)/projects/\($pu)/versions/\($cid|@uri)/findings?filter.values=\(dismissed_filter_encoded)";

def pr_findings_url($ns; $pu; $prid):
  "\($base)/t/\($ns|@uri)/projects/\($pu)/pr-runs/\($prid|@uri)/findings?filter.values=\(dismissed_filter_encoded)";

def finding_endor_url:
  (.tenant_meta.namespace // "") as $ns |
  (.spec.project_uuid // "") as $pu |
  (.context.id // "default") as $cid |
  (.context.type // "") as $ctype |
  (.uuid // "") as $fuuid |
  if ($ns | length) == 0 or ($fuuid | length) == 0 or ($pu | length) == 0 then
    ""
  elif $ctype == "CONTEXT_TYPE_CI_RUN" then
    pr_findings_url($ns; $pu; $cid) + "&resourceDetail=" + resource_detail_encoded($ns; $fuuid)
  elif $ctype == "CONTEXT_TYPE_REF" or $ctype == "CONTEXT_TYPE_MAIN" then
    version_findings_url($ns; $pu; $cid) + "&resourceDetail=" + resource_detail_encoded($ns; $fuuid)
  else
    ""
  end;

def rank($l):
  if ($l | test("CRITICAL")) then 0
  elif ($l | test("HIGH")) then 1
  elif ($l | test("MEDIUM")) then 2
  elif ($l | test("LOW")) then 3
  else 4 end;

def truncate_title:
  (.meta.description // .meta.name // "Finding")
  | gsub("\\s+"; " ")
  | if length > 100 then .[0:97] + "…" else . end;

def dependency_reachability_label:
  (.spec.finding_tags // []) as $tags |
  if any($tags[]?; . == "FINDING_TAGS_REACHABLE_DEPENDENCY") then "Reachable Dependency"
  elif any($tags[]?; . == "FINDING_TAGS_POTENTIALLY_REACHABLE_DEPENDENCY") then "Potentially Reachable Dependency"
  elif any($tags[]?; . == "FINDING_TAGS_UNREACHABLE_DEPENDENCY") then "Unreachable Dependency"
  else "—"
  end;

def function_reachability_label:
  (.spec.finding_tags // []) as $tags |
  if any($tags[]?; . == "FINDING_TAGS_REACHABLE_FUNCTION") then "Reachable Function"
  elif any($tags[]?; . == "FINDING_TAGS_POTENTIALLY_REACHABLE_FUNCTION") then "Potentially Reachable Function"
  elif any($tags[]?; . == "FINDING_TAGS_UNREACHABLE_FUNCTION") then "Unreachable Function"
  else ""
  end;

def sast_cwe_ids:
  (.spec.finding_metadata.custom.cwes // []) as $cwes |
  if ($cwes | length) == 0 then "—"
  else
    [$cwes[] | split(":")[0] | gsub("^\\s+|\\s+$"; "")]
    | unique
    | join(", ")
  end;

def code_location_url:
  (.spec.finding_metadata.custom.location // "") as $custom |
  if (($custom | length) > 0) and ($custom | startswith("http")) then $custom
  else (.spec.location_urls // {} | to_entries | .[0].value // empty)
  end;

def code_location_detail:
  (.spec.finding_metadata.custom.location // "") as $loc |
  if ($loc | startswith("http")) then
    ($loc | split("/") | last | gsub("#L"; ":"))
  else
    ((.spec.location_urls // {}) | keys[0]
     // .spec.dependency_file_paths[0]
     // "—")
  end;

def deps_location_detail:
  if ((.spec.dependency_file_paths // []) | length) > 0 then
    (.spec.dependency_file_paths | join(", "))
  else
    ((.spec.location_urls // {}) | keys[0] // "—")
  end;

def deps_package_name:
  .spec.target_dependency_name // "—";

def row_badges:
  (.spec.finding_tags // []) as $tags |
  [
    if any($tags[]?; . == "FINDING_TAGS_CI_BLOCKER") then "🛑 Blocker" else empty end,
    if any($tags[]?; . == "FINDING_TAGS_CI_WARNING") then "⚠️ Warning" else empty end,
    if any($tags[]?; . == "FINDING_TAGS_FIX_AVAILABLE") then "🩹 Fix available" else empty end,
    if any($tags[]?; . == "FINDING_TAGS_EXPLOITED") then "🔥 Exploited" else empty end,
    if any($tags[]?; . == "FINDING_TAGS_MALWARE") then "☣️ Malware" else empty end,
    if any($tags[]?; . == "FINDING_TAGS_AI") then "🤖 AI" else empty end,
    if any($tags[]?; . == "FINDING_TAGS_VALID_SECRET") then "✅ Valid secret" else empty end,
    if any($tags[]?; . == "FINDING_TAGS_INVALID_SECRET") then "❌ Invalid secret" else empty end
  ] | .[0:3] | join(" · ");

def row_for_mode:
  {
    level: (.spec.level // "FINDING_LEVEL_UNKNOWN"),
    title: truncate_title,
    badges: row_badges,
    endor_url: finding_endor_url,
    url: (
      if $table_mode == "dependencies" then
        (.spec.location_urls // {} | to_entries | .[0].value // "")
      else
        (code_location_url // "")
      end
    ),
    detail: (
      if $table_mode == "dependencies" then deps_location_detail
      else code_location_detail
      end
    ),
    package: (if $table_mode == "dependencies" then deps_package_name else "" end),
    reach_dep: (if $table_mode == "dependencies" then dependency_reachability_label else "" end),
    reach_fn: (if $table_mode == "dependencies" then function_reachability_label else "" end),
    cwe: (
      if $table_mode == "sast" or $table_mode == "ai-sast" then sast_cwe_ids
      else ""
      end
    )
  };

def is_critical_or_high($level):
  ($level | test("CRITICAL|HIGH"));

def sorted_table_rows:
  [filtered_all_findings[]? | row_for_mode]
  | sort_by(rank(.level));

def selected_table_rows:
  sorted_table_rows as $sorted |
  if ($limit | type) != "number" then $sorted
  elif $limit < 0 then ($sorted | map(select(is_critical_or_high(.level))))
  else
    ($sorted | map(select(is_critical_or_high(.level)))) as $priority |
    ($sorted | map(select(is_critical_or_high(.level) | not))) as $rest |
    $priority + ($rest | .[0:$limit])
  end;

def table_selection_summary:
  sorted_table_rows as $sorted |
  selected_table_rows as $selected |
  {
    shown: ($selected | length),
    total: ($sorted | length),
    critical_high: ($sorted | map(select(is_critical_or_high(.level))) | length),
    omitted: (($sorted | length) - ($selected | length))
  };

def filtered_table_rows:
  selected_table_rows;
