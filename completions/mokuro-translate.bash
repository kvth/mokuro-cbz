# bash completion for mokuro-translate; installed as
# /usr/share/bash-completion/completions/mokuro-translate, or try it with
# 'source completions/mokuro-translate.bash'.
# Keep the option list in sync with mokuro-translate.

_mokuro_translate() {
    local cur prev words cword split
    _init_completion -s || return

    case $prev in
        -l | --lang)
            # comma-separated DeepL target languages
            COMPREPLY=($(compgen -W "en de en-gb en-us fr es it ja ko nl pl pt-br pt-pt ru uk zh-hans zh-hant" -- "$cur"))
            return
            ;;
        -h | --help | --version)
            return
            ;;
    esac
    $split && return

    if [[ $cur == -* ]]; then
        COMPREPLY=($(compgen -W "-l --lang -n --dry-run --version -h --help" -- "$cur"))
        return
    fi

    # the CBZs, or folders to search for them
    _filedir '@(cbz|zip)'
} &&
    complete -F _mokuro_translate mokuro-translate
