function _pure_jj_bookmark_suffix \
    --description 'Print a jj bookmark suffix: upstream ahead/behind, no-upstream marker, bookmark conflict'

    test (count $argv) -ge 1; or return 1
    set --local name $argv[1]
    set --local rows $argv[2..-1]

    set --local has_local false
    set --local has_tracked false
    set --local has_untracked false
    set --local conflict false
    set --local ahead 0
    set --local behind 0
    set --local ahead_plus false
    set --local behind_plus false

    for row in $rows
        set --local field (string split -- \t $row)
        test (count $field) -ge 10; or continue
        test "$field[1]" = "$name"; or continue

        if test "$field[2]" = '-'
            set has_local true
            test "$field[10]" = true; and set conflict true
            continue
        end

        test "$field[2]" = git; and continue

        if test "$field[3]" != 1; or test "$field[4]" != 1
            set has_untracked true
            continue
        end
        set has_tracked true

        set --local remote_ahead 0
        set --local remote_behind 0
        set --local ahead_is_lower false
        set --local behind_is_lower false

        if test -n "$field[6]"
            set remote_ahead $field[6]
        else if test -n "$field[7]"
            set remote_ahead $field[7]
            set ahead_is_lower true
        end

        if test -n "$field[8]"
            set remote_behind $field[8]
        else if test -n "$field[9]"
            set remote_behind $field[9]
            set behind_is_lower true
        end

        # A remote ref ahead of the local bookmark means the local one is behind.
        if test $remote_ahead -gt $behind
            set behind $remote_ahead
            set behind_plus $ahead_is_lower
        else if test $remote_ahead -eq $behind
            test $ahead_is_lower = true; and set behind_plus true
        end

        # A remote ref behind the local bookmark means the local one is ahead.
        if test $remote_behind -gt $ahead
            set ahead $remote_behind
            set ahead_plus $behind_is_lower
        else if test $remote_behind -eq $ahead
            test $behind_is_lower = true; and set ahead_plus true
        end
    end

    test $has_local = true; or return 0

    set --local suffix
    if test "$pure_jj_show_bookmark_sync" = true
        if test $has_tracked = true
            if test $ahead -gt 0
                set suffix "$suffix"(_pure_set_color $pure_color_jj_ahead)$pure_symbol_jj_ahead
                if test "$pure_show_numbered_git_indicator" = true
                    set suffix "$suffix$ahead"
                    test $ahead_plus = true; and set suffix "$suffix+"
                end
            end
            if test $behind -gt 0
                set suffix "$suffix"(_pure_set_color $pure_color_jj_behind)$pure_symbol_jj_behind
                if test "$pure_show_numbered_git_indicator" = true
                    set suffix "$suffix$behind"
                    test $behind_plus = true; and set suffix "$suffix+"
                end
            end
            if test $has_untracked = true
                set suffix "$suffix"(_pure_set_color $pure_color_jj_no_upstream)$pure_symbol_jj_no_upstream
            end
        else
            set suffix (_pure_set_color $pure_color_jj_no_upstream)$pure_symbol_jj_no_upstream
        end
    end

    if test "$pure_jj_show_bookmark_conflict" = true; and test $conflict = true
        set suffix "$suffix"(_pure_set_color $pure_color_jj_bookmark_conflict)$pure_symbol_jj_bookmark_conflict
    end

    printf '%s' $suffix
end
