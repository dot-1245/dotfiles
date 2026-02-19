#ohmyzsh-zone
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"
plugins=(git)

source $ZSH/oh-my-zsh.sh

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

alias rekitty="source $zshconf"
alias rewaybar="killall waybar&& waybar & disown"

eval "$(starship init zsh)"

fastfetch


