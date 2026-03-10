#ohmyzsh-zone
#export ZSH="$HOME/.oh-my-zsh"
#ZSH_THEME="robbyrussell"
#plugins=(git)

#source $ZSH/oh-my-zsh.sh

export hyprconf="$HOME/.config/hypr/hyprland.conf"
export zshconf="$HOME/.config/zsh/.zshrc"
export waybarconf="$HOME/.config/waybar/config.jsonc"
export waybarcss="$HOME/.config/waybar/style.css"
export kittyconf="$HOME/.config/kitty/kitty.conf"
export starshipconf="$HOME/.config/starship.toml"
export hyprlockconf="$HOME/.config/hypr/hyprlock.conf"
export wlogoutconf="$HOME/.config/wlogout/layout"
export wlogoutcss="$HOME/.config/wlogout/style.css"
export fastfetchconf="$HOME/.config/fastfetch/config.jsonc"
export cavaconf="$HOME/.config/cava/config"
export nanoconf="$HOME/.config/nano/nanorc"
export makoconf="$HOME/.config/mako/config"
export woficonf="$HOME/.config/wofi/config"
export woficss="$HOME/.config/wofi/style.css"
export fuzzelconf="$HOME/.config/fuzzel/fuzzel.ini"
export starshipconf="$HOME/.config/starship.toml"
export matugenconf="$HOME/.config/matugen/config.toml"
export agsconf="$HOME/.config/ags/app.ts"
export agsstyle="$HOME/.config/ags/style.scss"
export agswidget="$HOME/.config/ags/widget"
export mpvconf="$HOME/.config/mpv/mpv.conf"
export mpvinput="$HOME/.config/mpv/input.conf"
export starshipconf="$HOME/.config/starship.toml"

export PATH="$HOME/.local/bin:$PATH"

alias dotman="~/.config/scripts/dotman.sh"
alias rekitty="source $zshconf"
alias rewaybar="killall waybar 2>/dev/null; waybar > /dev/null 2>&1 & disown"
alias musictui="/home/dot1245/.config/scripts/show_music.sh"
alias clocktui="tty-clock -sc"
alias cbonsaitui="cbonsai -lit 0.01"
alias sptui="sh $HOME/.config/scripts/spotify-tui.sh"
alias yttui="sh $HOME/.config/scripts/yttui.sh"
alias daily="yap --editor inbuilt /mnt/hdd/daily"

eval "$(starship init zsh)"

fastfetch --config os
