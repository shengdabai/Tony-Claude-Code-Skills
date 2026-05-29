function on -d "Create a new note"
    if test (count $argv) -lt 1
        echo "Usage: on 'note name'"
        return 1
    end

    set -l note_name (string collect "$argv")
    set -l note_name (string trim "$note_name")
    set -l note_name (string lower "$note_name")
    set -l note_name (string replace -a -r '\s+' '-' $note_name)
    set -l file_name inbox/(date "+%Y-%m-%d")_$note_name.md
    cd "$HOME/Vaults/Second Brain/" || return 2

    if test -e "$file_name"
        nvim "$file_name"
    else
        touch "$file_name"
        nvim +1 "+ObsidianTemplate note" "+2s/^<!--.*-->.*[\n\r]//" +4 "$file_name"
    end
end
