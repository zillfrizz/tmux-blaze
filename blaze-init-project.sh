#!/usr/bin/env bash
# blaze-init-projet.sh

session="$1"

DOSSIER_ETAT="$HOME/.local/share/tmux-blaze"
mkdir -p "$DOSSIER_ETAT"
fichier_etat="$DOSSIER_ETAT/$session.state"

surface="default_surface"
concern=$(tmux list-windows -t "$session" -F '#{window_name}')

{
	echo "surface|$surface|concern_actif=$concern"
	echo "concern|$surface|$concern"
} > "$fichier_etat"
