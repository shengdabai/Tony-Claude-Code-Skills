function ons -d "Open notes to search for file"
    cd "$HOME/Vaults/Second Brain/" || return 1
    nvim "+lua Snacks.dashboard.pick('files')"
end
