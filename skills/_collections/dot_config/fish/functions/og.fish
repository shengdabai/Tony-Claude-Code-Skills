function og -d "Organize notes based on tags"
    set -l VAULT_DIR "$HOME/Vaults/Second Brain"
    set -l SRC_DIR zk
    set -l DST_DIR notes

    for file in "$VAULT_DIR/$SRC_DIR/"*.md
        echo "Processing $file"

        # Extract the tag from the file. This assumes the tag is on the line immediately following "tags:"
        set -l tag (awk '/tags:/{getline; print; exit}' "$file" | sed -e 's/^ *- *//' -e 's/^ *//;s/ *$//')

        if test -n "$tag"
            set -l tag_dir "$VAULT_DIR/$DST_DIR/$tag"
            mkdir -p "$tag_dir"

            mv "$file" "$tag_dir/"
            echo "Moved $file to $tag_dir"
        else
            echo "No tag found in $file"
        end
    end
end

echo "Done 🪷"
