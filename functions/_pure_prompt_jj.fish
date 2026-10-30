function _pure_prompt_jj \
    --description 'Print jj repository information: change id, nearest bookmark, working-copy state, upstream sync'

    command --search --quiet jj; or return 1
    test -n (_pure_jj_repo_root); or return 1

    set --local depth 20
    if set --query pure_jj_search_depth; and test (count $pure_jj_search_depth) -eq 1
        set depth $pure_jj_search_depth
    end
    if not string match --quiet --regex '^[0-9]+$' -- $depth
        set depth 20
    end
    if test $depth -gt 100
        set depth 100
    end
    set --local bookmark_walk (math $depth + 1)
    # Two extra commits let trunk distance tell "exactly at the limit" from
    # "beyond the limit" after excluding an empty working-copy commit.
    set --local trunk_walk (math $depth + 2)

    set --local trunk_label $pure_jj_trunk_label
    test -n "$trunk_label"; or set trunk_label trunk

    set --local description_width 40
    if set --query pure_jj_description_max_length; and test (count $pure_jj_description_max_length) -eq 1
        set description_width $pure_jj_description_max_length
    end
    if not string match --quiet --regex '^[0-9]+$' -- $description_width
        set description_width 40
    end

    # A single jj log answers three questions:
    #   - which commit is @ and what is its state
    #   - which local bookmark is the nearest useful reference, and how far away
    #   - how far @ is from trunk when no bookmark is available
    set --local ancestor_ref "latest(heads(ancestors(@, $bookmark_walk) & bookmarks()))"
    set --local descendant_ref "latest(roots(descendants(@, $bookmark_walk) & bookmarks()))"
    set --local ancestor_path "$ancestor_ref::@"
    set --local descendant_path "@::$descendant_ref"
    set --local trunk_ahead "ancestors(@, $trunk_walk) & trunk()..@"
    set --local trunk_behind "ancestors(trunk(), $trunk_walk) & (::trunk() & ~::@)"
    set --local revset "@ | ($ancestor_path) | ($descendant_path) | ($trunk_ahead) | ($trunk_behind) | trunk()"

    set --local diff_statuses_expression '""'
    if test "$pure_jj_show_statistics" = true
        set diff_statuses_expression 'self.diff().files().map(|f| f.status_char()).join("")'
    end

    set --local template (string join '' \
        'concat(' \
        'if(self.contained_in("@"), "@", ""), ' \
        'if(self.contained_in("'$ancestor_path'"), "P", ""), ' \
        'if(self.contained_in("'$ancestor_ref'"), "p", ""), ' \
        'if(self.contained_in("'$descendant_path'"), "Q", ""), ' \
        'if(self.contained_in("'$descendant_ref'"), "q", ""), ' \
        'if(self.contained_in("trunk()"), "T", ""), ' \
        'if(self.contained_in("root()"), "Z", ""), ' \
        'if(self.contained_in("'$trunk_ahead'"), "a", ""), ' \
        'if(self.contained_in("'$trunk_behind'"), "b", ""), ' \
        '"\t", change_id.shortest(), ' \
        '"\t", commit_id.shortest(), ' \
        '"\t", local_bookmarks.map(|b| b.name()).join("\x1f"), ' \
        '"\t", if(empty, "1", "0"), ' \
        '"\t", if(conflict, "1", "0"), ' \
        '"\t", if(divergent, "1", "0"), ' \
        '"\t", if(immutable, "1", "0"), ' \
        '"\t", if(self.contained_in("@"), description.first_line().replace("\e", "").replace("\t", " ").replace("\x1f", " ").replace("\r", " "), ""), ' \
        '"\t", if(self.contained_in("@"), '$diff_statuses_expression', ""), ' \
        '"\t", if(self.contained_in("trunk()"), self.bookmarks().map(|b| b.name()).join("\x1f"), ""), ' \
        '"\n")'
    )

    set --local lines (command jj --no-pager log --ignore-working-copy --color=never --no-graph \
        --template $template --revisions $revset 2>/dev/null)
    set --local log_status $status
    test $log_status -eq 0; and test (count $lines) -gt 0; or return 1

    set --local at_change_id
    set --local at_commit_id
    set --local at_bookmarks
    set --local at_empty 0
    set --local at_conflict 0
    set --local at_divergent 0
    set --local at_immutable 0
    set --local at_description
    set --local diff_statuses
    set --local at_at_trunk false
    set --local ancestor_lines 0
    set --local descendant_lines 0
    set --local ancestor_names
    set --local descendant_names
    set --local ancestor_at_trunk false
    set --local descendant_at_trunk false
    set --local ahead_lines 0
    set --local behind_lines 0
    set --local trunk_seen false
    set --local trunk_is_root false
    set --local trunk_names
    set --local trunk_local_names

    for line in $lines
        set --local field (string split -- \t $line)
        test (count $field) -ge 11; or continue
        set --local flags $field[1]

        if string match --quiet '*@*' -- $flags
            set at_change_id $field[2]
            set at_commit_id $field[3]
            set at_bookmarks $field[4]
            set at_empty $field[5]
            set at_conflict $field[6]
            set at_divergent $field[7]
            set at_immutable $field[8]
            set at_description $field[9]
            set diff_statuses $field[10]
            set at_at_trunk false
            string match --quiet '*T*' -- $flags; and set at_at_trunk true
        end

        if string match --quiet '*P*' -- $flags
            set ancestor_lines (math $ancestor_lines + 1)
        end
        if string match --quiet '*p*' -- $flags
            set ancestor_names $field[4]
            set ancestor_at_trunk false
            string match --quiet '*T*' -- $flags; and set ancestor_at_trunk true
        end
        if string match --quiet '*Q*' -- $flags
            set descendant_lines (math $descendant_lines + 1)
        end
        if string match --quiet '*q*' -- $flags
            set descendant_names $field[4]
            set descendant_at_trunk false
            string match --quiet '*T*' -- $flags; and set descendant_at_trunk true
        end

        if string match --quiet '*T*' -- $flags
            set trunk_seen true
            set trunk_names $field[11]
            set trunk_local_names $field[4]
            string match --quiet '*Z*' -- $flags; and set trunk_is_root true
        end

        if string match --quiet '*a*' -- $flags
            set ahead_lines (math $ahead_lines + 1)
        end
        if string match --quiet '*b*' -- $flags
            set behind_lines (math $behind_lines + 1)
        end
    end

    test -n "$at_change_id"; or return 1

    set --local at_empty_flag false
    test "$at_empty" = 1; and set at_empty_flag true

    set --local ancestor_distance (math $ancestor_lines - 1)
    test $ancestor_distance -lt 0; and set ancestor_distance 0
    if test $at_empty_flag = true; and test $ancestor_distance -gt 0
        set ancestor_distance (math $ancestor_distance - 1)
    end

    set --local descendant_distance (math $descendant_lines - 1)
    test $descendant_distance -lt 0; and set descendant_distance 0

    # A bookmark on @ is always the best reference, even if the nearest-bookmark
    # walk picked another branch head on a timestamp tie.
    if test -n "$at_bookmarks"
        set ancestor_names $at_bookmarks
        set ancestor_distance 0
        set ancestor_at_trunk $at_at_trunk
    end

    set --local candidate_direction
    set --local candidate_distance
    set --local candidate_names
    set --local candidate_at_trunk
    set --local has_ancestor false
    test -n "$ancestor_names"; and set has_ancestor true
    set --local has_descendant false
    test -n "$descendant_names"; and set has_descendant true

    if test $has_ancestor = true; and test $has_descendant = true
        if test $ancestor_distance -eq 0; and test $descendant_distance -eq 0
            set --append candidate_direction ancestor
            set --append candidate_distance $ancestor_distance
            set --append candidate_names $ancestor_names
            set --append candidate_at_trunk $ancestor_at_trunk
        else if test $ancestor_distance -lt $descendant_distance
            set --append candidate_direction ancestor
            set --append candidate_distance $ancestor_distance
            set --append candidate_names $ancestor_names
            set --append candidate_at_trunk $ancestor_at_trunk
        else if test $descendant_distance -lt $ancestor_distance
            set --append candidate_direction descendant
            set --append candidate_distance $descendant_distance
            set --append candidate_names $descendant_names
            set --append candidate_at_trunk $descendant_at_trunk
        else
            set --append candidate_direction ancestor descendant
            set --append candidate_distance $ancestor_distance $descendant_distance
            set --append candidate_names $ancestor_names $descendant_names
            set --append candidate_at_trunk $ancestor_at_trunk $descendant_at_trunk
        end
    else if test $has_ancestor = true
        set --append candidate_direction ancestor
        set --append candidate_distance $ancestor_distance
        set --append candidate_names $ancestor_names
        set --append candidate_at_trunk $ancestor_at_trunk
    else if test $has_descendant = true
        set --append candidate_direction descendant
        set --append candidate_distance $descendant_distance
        set --append candidate_names $descendant_names
        set --append candidate_at_trunk $descendant_at_trunk
    end

    # Trunk distance walks a couple of commits beyond the limit so a distance
    # at the boundary is exact and one beyond it becomes "20+".
    set --local ahead_text
    set --local behind_text
    set --local ahead_count $ahead_lines
    if test $at_empty_flag = true; and test $ahead_count -gt 0
        set ahead_count (math $ahead_count - 1)
    end
    if test $ahead_count -gt $depth
        set ahead_text "$ahead_count+"
    else if test $ahead_count -gt 0
        set ahead_text $ahead_count
    end
    if test $behind_lines -gt $depth
        set behind_text "$behind_lines+"
    else if test $behind_lines -gt 0
        set behind_text $behind_lines
    end

    set --local bookmark_template (string join '' \
        'name ++ "\t" ++ ' \
        'if(remote, remote, "-") ++ "\t" ++ ' \
        'if(remote, if(self.tracked(), "1", "0"), "0") ++ "\t" ++ ' \
        'if(remote, if(self.tracking_present(), "1", "0"), "0") ++ "\t" ++ ' \
        'self.synced() ++ "\t" ++ ' \
        'try(self.tracking_ahead_count().exact(), "") ++ "\t" ++ ' \
        'try(self.tracking_ahead_count().lower(), "") ++ "\t" ++ ' \
        'try(self.tracking_behind_count().exact(), "") ++ "\t" ++ ' \
        'try(self.tracking_behind_count().lower(), "") ++ "\t" ++ ' \
        'self.conflict() ++ "\n"'
    )

    set --local bookmark_rows
    if test "$pure_jj_show_bookmarks" = true
        if test "$pure_jj_show_bookmark_sync" = true; or test "$pure_jj_show_bookmark_conflict" = true
            if test (count $candidate_direction) -gt 0; or test -n "$trunk_local_names"
                set bookmark_rows (command jj --no-pager bookmark list --ignore-working-copy --color=never \
                    --all-remotes -r @ -r $ancestor_ref -r $descendant_ref -r 'trunk()' \
                    --template $bookmark_template 2>/dev/null)
            end
        end
    end

    set --local reference_parts
    set --local reference_at_trunk false
    if test "$pure_jj_show_bookmarks" = true
        set --local candidate_index 0
        for direction in $candidate_direction
            set candidate_index (math $candidate_index + 1)
            set --local distance $candidate_distance[$candidate_index]
            set --local names_field $candidate_names[$candidate_index]
            test "$candidate_at_trunk[$candidate_index]" = true; and set reference_at_trunk true

            for name in (string split -- \x1f $names_field)
                test -n "$name"; or continue
                set --local part (_pure_set_color $pure_color_jj_bookmark)$name
                if test "$pure_jj_show_bookmark_distance" = true; and test $distance -gt 0
                    if test "$direction" = ancestor
                        set part "$part$pure_symbol_jj_ancestor$distance"
                    else
                        set part "$part$pure_symbol_jj_descendant$distance"
                    end
                end
                if test "$pure_jj_show_bookmark_sync" = true; or test "$pure_jj_show_bookmark_conflict" = true
                    set --local suffix (_pure_jj_bookmark_suffix $name $bookmark_rows)
                    test -n "$suffix"; and set part "$part$suffix"
                end
                test -n "$part"; and set --append reference_parts $part
            end
        end

        if test (count $reference_parts) -eq 0; and test $trunk_seen = true; and test $trunk_is_root = false
            set --local names
            for name in (string split -- \x1f $trunk_names)
                test -n "$name"; or continue
                contains -- $name $names; or set --append names $name
            end
            test (count $names) -gt 0; or set names $trunk_label

            for name in $names
                set --local part (_pure_set_color $pure_color_jj_bookmark)$name
                if test "$pure_jj_show_bookmark_distance" = true
                    if test -n "$ahead_text"; and test -n "$behind_text"
                        set part "$part$pure_symbol_jj_ancestor$ahead_text$pure_symbol_jj_descendant$behind_text"
                    else if test -n "$ahead_text"
                        set part "$part$pure_symbol_jj_ancestor$ahead_text"
                    else if test -n "$behind_text"
                        set part "$part$pure_symbol_jj_descendant$behind_text"
                    end
                end
                if test "$pure_jj_show_bookmark_sync" = true; or test "$pure_jj_show_bookmark_conflict" = true
                    set --local suffix (_pure_jj_bookmark_suffix $name $bookmark_rows)
                    test -n "$suffix"; and set part "$part$suffix"
                end
                test -n "$part"; and set --append reference_parts $part
            end
        end
    end
    set --local reference (string join ',' $reference_parts)

    set --local head (_pure_set_color $pure_color_jj_change_id)$at_change_id
    if test "$pure_jj_show_commit_id" = true
        set head "$head "(_pure_set_color $pure_color_jj_commit_id)$at_commit_id
    end
    if test -n "$reference"
        set head "$head $reference"
    end
    if test $at_empty_flag = true; and test "$pure_jj_show_empty" = true; and test -n "$pure_symbol_jj_empty"
        set head "$head "(_pure_set_color $pure_color_jj_empty)$pure_symbol_jj_empty
    else if test $at_empty_flag = false; and test "$pure_jj_show_dirty" = true; and test -n "$pure_symbol_jj_dirty"
        set head "$head"(_pure_set_color $pure_color_jj_dirty)$pure_symbol_jj_dirty
    end

    set --local status_parts
    if test $at_conflict = 1; and test "$pure_jj_show_conflict" = true
        set --local conflict_marker (_pure_set_color $pure_color_jj_conflict)$pure_symbol_jj_conflict
        test -n "$conflict_marker"; and set --append status_parts $conflict_marker
    end
    if test $at_divergent = 1; and test "$pure_jj_show_divergent" = true
        set --local divergent_marker (_pure_set_color $pure_color_jj_divergent)$pure_symbol_jj_divergent
        test -n "$divergent_marker"; and set --append status_parts $divergent_marker
    end
    if test $at_immutable = 1; and test "$pure_jj_show_immutable" = true
        set --local immutable_marker (_pure_set_color $pure_color_jj_immutable)$pure_symbol_jj_immutable
        test -n "$immutable_marker"; and set --append status_parts $immutable_marker
    end

    if test "$pure_jj_show_bookmarks" = true; and test "$pure_jj_show_trunk_distance" = true; and test $trunk_seen = true; and test $trunk_is_root = false; and test $reference_at_trunk = false; and test (count $candidate_direction) -gt 0
        set --local trunk_distance_parts
        if test -n "$ahead_text"
            set --append trunk_distance_parts (_pure_set_color $pure_color_jj_trunk_ahead)$pure_symbol_jj_trunk_ahead$ahead_text
        end
        if test -n "$behind_text"
            set --append trunk_distance_parts (_pure_set_color $pure_color_jj_trunk_behind)$pure_symbol_jj_trunk_behind$behind_text
        end
        if test (count $trunk_distance_parts) -gt 0
            set --append status_parts (string join ' ' $trunk_distance_parts)
        end
    end

    if test "$pure_jj_show_statistics" = true; and test -n "$diff_statuses"
        set --local added 0
        set --local removed 0
        set --local modified 0
        for status_char in (string split '' $diff_statuses)
            switch $status_char
                case A C
                    set added (math $added + 1)
                case D
                    set removed (math $removed + 1)
                case M R
                    set modified (math $modified + 1)
            end
        end
        set --local statistic_parts
        if test $added -gt 0
            set --append statistic_parts (_pure_set_color $pure_color_jj_stats_added)$pure_symbol_jj_stats_added$added
        end
        if test $removed -gt 0
            set --append statistic_parts (_pure_set_color $pure_color_jj_stats_removed)$pure_symbol_jj_stats_removed$removed
        end
        if test $modified -gt 0
            set --append statistic_parts (_pure_set_color $pure_color_jj_stats_modified)$pure_symbol_jj_stats_modified$modified
        end
        if test (count $statistic_parts) -gt 0
            set --append status_parts (string join ' ' $statistic_parts)
        end
    end

    if test "$pure_jj_show_description" = true; and test -n "$at_description"
        set --local text $at_description
        if test $description_width -gt 0; and test (string length -- $text) -gt $description_width
            set text (string sub --length $description_width -- $text)"…"
        end
        set --append status_parts (_pure_set_color $pure_color_jj_description)$text
    else if test "$pure_jj_show_no_description" = true; and test $at_empty_flag = false; and test -z "$at_description"
        set --append status_parts (_pure_set_color $pure_color_jj_no_description)$pure_symbol_jj_no_description
    end

    set --local segment $head
    if test (count $status_parts) -gt 0
        set segment "$segment "(string join ' ' $status_parts)
    end

    printf '%s\n' $segment
end
