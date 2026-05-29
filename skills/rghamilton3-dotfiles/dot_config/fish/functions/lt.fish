function lt --wraps='eza -aT --color=always --group-directories-first --icons' --wraps='eza $EZA_STANDARD_OPTIONS $EZA_LT_OPTIONS' --description 'alias lt eza $EZA_STANDARD_OPTIONS $EZA_LT_OPTIONS'
  eza $EZA_STANDARD_OPTIONS $EZA_LT_OPTIONS $argv
        
end
