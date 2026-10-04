# bash completion for mokuro-cbz; installed as
# /usr/share/bash-completion/completions/mokuro-cbz, or try it with
# 'source completions/mokuro-cbz.bash'.
# Keep the option list in sync with mokuro-cbz.

_mokuro_cbz() {
    local cur prev words cword split
    _init_completion -s || return

    case $prev in
        -o | --output-dir)
            _filedir -d
            return
            ;;
        --model)
            # a Hugging Face model name or a local model folder
            _filedir -d
            return
            ;;
        -h | --help | --version)
            return
            ;;
    esac
    $split && return

    if [[ $cur == -* ]]; then
        COMPREPLY=($(compgen -W "-o --output-dir --force-cpu --no-cache --model --version -h --help" -- "$cur"))
        return
    fi

    # the volume folders
    _filedir -d
} &&
    complete -F _mokuro_cbz mokuro-cbz
