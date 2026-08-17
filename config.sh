#!/usr/bin/env bash
keymaps="$rootState"/keymaps.sh
xargs -r -I{} tmux unbind-key {} < "$keymaps"
: > "$keymaps"
_add_keymap() {
	local nameKeymap="$1" scriptKeymap="$2" keymapBase="$3"
	local keymap="$(tmux show-option -gqv "@blaze-$nameKeymap")"
	[ -z "$keymap" ] && keymap="$keymapBase"
	[ -z "$keymap" ] && return
	tmux bind-key "$keymap" run-shell "source \"$modGlobals\"; \"$modBlaze\" $scriptKeymap"
	echo "$keymap" >> "$keymaps"
}
_add_keymap new-concern createConcern  
_add_keymap new-surface createSurface
_add_keymap new-project createProject
_add_keymap kill-concern killConcern
_add_keymap kill-surface killSurface
_add_keymap kill-project killProject
_add_keymap rename-concern renameConcern
_add_keymap rename-surface renameSurface
_add_keymap rename-project renameProject
_add_keymap change-concern changeConcern
_add_keymap change-surface changeSurface
_add_keymap change-project changeProject
_add_keymap cleanup cleanup 
_add_keymap reload-config reloadConfig
