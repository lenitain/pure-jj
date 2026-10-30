function _pure_jj_repo_root --description 'Print the nearest ancestor directory containing .jj'
    set --local dir $PWD
    while true
        if test -e "$dir/.jj"
            echo $dir
            return 0
        end
        set --local parent (path dirname $dir)
        if test "$parent" = "$dir"
            return 1
        end
        set dir $parent
    end
end
