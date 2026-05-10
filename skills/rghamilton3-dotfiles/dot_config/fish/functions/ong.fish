function ong -d "Organize notes"
    set -l VAULT_DIR "$HOME/Vaults/Second Brain"
    set -l SOURCE_DIR zk
    set -l DEST_DIR notes

    for file in "$VAULT_DIR/$SOURCE_DIR/"*.md
        echo "Processing $file"

        # Extract the tag from the file. This assumes the tag is on the line immediately following "tags:"
        set -l tag (awk '/tag[s]:/{getline; print; exit}' "$file" | sed -e 's/^ *- *#*//' -e 's/^ *//;s/ *$//')

        if test -n $tag
            echo "Found tag $tag"
            set -l TAG_DIR "$VAULT_DIR/$DEST_DIR/$tag"
            mkdir -p "$TAG_DIR"

            mv $file "$TAG_DIR/"
            echo "Moved $file to $TAG_DIR"
        else
            echo "No tag found"
        end
    end

    echo "Done 🪷"
end
