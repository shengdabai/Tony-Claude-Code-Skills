function onz -d "Open notes to grep text"
    cd "$HOME/Vaults/Second Brain/" || return 1
    nvim "+lua Snacks.dashboard.pick('live_grep')"
end
