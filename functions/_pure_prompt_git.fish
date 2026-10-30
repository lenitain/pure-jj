function _pure_prompt_git \
    --description 'Print repository information: jj change id in jj repositories, git branch/dirty/upstream otherwise'

    set --local ABORT_FEATURE 2

    if set --query pure_enable_git; and test "$pure_enable_git" != true
        return
    end

    # jj wins over git in colocated repositories: the change id and its nearest
    # bookmark are the useful navigation identity there, not git's detached
    # `jj/keep/...` ref.
    if not set --query pure_enable_jj; or test "$pure_enable_jj" = true
        _pure_prompt_jj
        and return
    end

    # Keep pure's git pipeline intact by reusing its per-field helpers. Only
    # this dispatcher is duplicated, so upstream changes to branch/dirty/stash
    # and pending-commit rendering still apply.
    if not type -q --no-functions git
        return $ABORT_FEATURE
    end

    set --local is_git_repository (command git rev-parse --is-inside-work-tree 2>/dev/null)
    if test -n "$is_git_repository"
        set --local git_prompt (_pure_prompt_git_branch)(_pure_prompt_git_dirty)(_pure_prompt_git_stash)
        set --local git_pending_commits (_pure_prompt_git_pending_commits)

        if test (_pure_string_width $git_pending_commits) -ne 0
            set --append git_prompt $git_pending_commits
        end

        echo $git_prompt
    end
end
