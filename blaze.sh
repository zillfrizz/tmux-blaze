#!/usr/bin/env bash

# ---------------------------------------------------------------------------
# Accessors
# ---------------------------------------------------------------------------
_getProjectCurrent() {
    # Le projet courant EST la session tmux attachée : pas de pointeur sur
    # disque à maintenir, donc pas de désync possible avec la réalité tmux.
    echo "$rootState/projects/$(tmux display-message -p '#{session_id}')"
}
_getSurfaceCurrent() {
    "$modProject" getSurfaceCurrent "$(_getProjectCurrent)"
}
_getConcernCurrent() {
    "$modSurface" getConcernCurrent "$(_getSurfaceCurrent)"
}

# ---------------------------------------------------------------------------
# Toute invocation via tmux run-shell part d'un shell tmux frais qui n'hérite
# pas forcément des exports de ce process-ci : on resource modGlobals dans
# la commande elle-même, jamais en comptant sur l'environnement ambiant.
# ---------------------------------------------------------------------------
_runShell() {
    printf 'source '\''%s'\''; '\''%s'\'' %s' "$modGlobals" "$modBlaze" "$*"
}

# ---------------------------------------------------------------------------
# Specs déclaratives : une entrée = un prompt. L'ordre = l'ordre des arguments
# passés à _createX / _renameX. Ajouter une entité = ajouter une ligne ici,
# rien d'autre.
# ---------------------------------------------------------------------------
declare -A _wizardPrompts=(
    [Project]="New project name:|First surface name:|First concern name:"
    [Surface]="New surface name:|First concern name:"
    [Concern]="New concern name:"
    [RenameProject]="New project name:"
    [RenameSurface]="New surface name:"
    [RenameConcern]="New concern name:"
)

# Séparateur improbable dans un nom saisi par l'utilisateur
_wizardSep=$'\x1f'

# ---------------------------------------------------------------------------
# Moteur générique du wizard
# ---------------------------------------------------------------------------
_wizardStart() {
    local entity="$1"
    tmux set-option -gu "@blazeWizard_$entity" 2>/dev/null
    "$modBlaze" _wizardStep "$entity" 0
}

_wizardStep() {
    local entity="$1" stepIndex="$2"
    IFS='|' read -r -a prompts <<< "${_wizardPrompts[$entity]}"

    if (( stepIndex >= ${#prompts[@]} )); then
        "$modBlaze" _wizardFinish "$entity"
        return
    fi

    local label="${prompts[$stepIndex]}"
    # Un seul niveau d'échappement, toujours : "%1" est le SEUL placeholder tmux
    # de cette string, jamais de command-prompt imbriqué dans la string elle-même.
    tmux command-prompt -p "$label" \
        "run-shell \"$(_runShell _wizardAnswer "$entity" "$stepIndex" "'%1'")\""
}

_wizardAnswer() {
    local entity="$1" stepIndex="$2" answer="$3"
    local current
    current="$(tmux show-options -gv "@blazeWizard_$entity" 2>/dev/null)"
    tmux set-option -g "@blazeWizard_$entity" "${current}${answer}${_wizardSep}"
    "$modBlaze" _wizardStep "$entity" "$((stepIndex + 1))"
}

_wizardFinish() {
    local entity="$1"
    local raw
    raw="$(tmux show-options -gv "@blazeWizard_$entity" 2>/dev/null)"
    tmux set-option -gu "@blazeWizard_$entity" 2>/dev/null

    local -a answers
    IFS="$_wizardSep" read -r -a answers <<< "$raw"

    case "$entity" in
    Project) "$modBlaze" _createProject "${answers[@]}" ;;
    Surface) "$modBlaze" _createSurface "${answers[@]}" ;;
    Concern) "$modBlaze" _createConcern "${answers[@]}" ;;
    RenameProject) "$modBlaze" _renameProject "${answers[@]}" ;;
    RenameSurface) "$modBlaze" _renameSurface "${answers[@]}" ;;
    RenameConcern) "$modBlaze" _renameConcern "${answers[@]}" ;;
    esac
}

# ---------------------------------------------------------------------------
# Création
# ---------------------------------------------------------------------------
_createProject() {
    local nameProject="$1" nameSurfaceFirst="$2" nameConcernFirst="$3"
    local sidProjectNew
    sidProjectNew=$(tmux new-session -d -n "$nameConcernFirst" -P -F '#{session_id}')
    local widConcernFirst
    widConcernFirst=$(tmux list-windows -t "$sidProjectNew" -F '#{window_id}' | head -n1)
    "$modProject" create "$rootState/projects/$sidProjectNew" "$nameProject" \
        "$nameSurfaceFirst" "$widConcernFirst" "$nameConcernFirst"
}

_createSurface() {
    local nameSurfaceNew="$1" nameConcernFirst="$2"
    local projectCurrent
    projectCurrent="$(_getProjectCurrent)"
    local idConcernFirst
    idConcernFirst=$(tmux new-window -t "$(basename "$projectCurrent")" -n "$nameConcernFirst" -P -F '#{window_id}')
    "$modProject" addSurface "$projectCurrent" "$nameSurfaceNew" "$idConcernFirst" "$nameConcernFirst"
}

_createConcern() {
    local nameConcernNew="$1"
    local projectCurrent
    projectCurrent="$(_getProjectCurrent)"
    local idConcernNew
    idConcernNew=$(tmux new-window -t "$(basename "$projectCurrent")" -n "$nameConcernNew" -P -F '#{window_id}')
    "$modSurface" addConcern "$(_getSurfaceCurrent)" "$idConcernNew" "$nameConcernNew"
}

# ---------------------------------------------------------------------------
# Renommage : concern/project sont indexés par id tmux (window_id/session_id),
# renommer ne bouge donc rien sur disque à part le champ name + le nom tmux.
# Surface est indexée par nom -> renommer déplace le dossier (mv), géré dans
# project.sh (renameSurface) qui connaît le chemin des deux côtés.
# ---------------------------------------------------------------------------
_renameConcern() {
    local newName="$1"
    local concernCurrent
    concernCurrent="$(_getConcernCurrent)"
    "$modConcern" setName "$concernCurrent" "$newName"
    tmux rename-window -t "$(basename "$concernCurrent")" "$newName"
}

_renameSurface() {
    local newName="$1"
    local projectCurrent surfaceCurrent nameOld
    projectCurrent="$(_getProjectCurrent)"
    surfaceCurrent="$(_getSurfaceCurrent)"
    nameOld="$(basename "$surfaceCurrent")"
    "$modProject" renameSurface "$projectCurrent" "$nameOld" "$newName"
}

_renameProject() {
    local newName="$1"
    local projectCurrent
    projectCurrent="$(_getProjectCurrent)"
    "$modProject" setName "$projectCurrent" "$newName"
    tmux rename-session -t "$(basename "$projectCurrent")" "$newName"
}

# ---------------------------------------------------------------------------
# Suppression : cascade vers le haut quand on vide une surface/un projet, en
# miroir du comportement natif de tmux (une session sans fenêtre disparaît).
# ---------------------------------------------------------------------------
_afterSurfaceRemoved() {
    local projectCurrent="$1"
    local remainingSurface
    remainingSurface="$("$modProject" getsSurface "$projectCurrent" | head -n1)"
    if [ -n "$remainingSurface" ]; then
        "$modProject" setSurfaceCurrent "$projectCurrent" "$remainingSurface"
        local concernTogo
        concernTogo="$("$modSurface" getConcernCurrent "$projectCurrent/surfaces/$remainingSurface")"
        tmux select-window -t "$(basename "$concernTogo")" 2>/dev/null
    else
        "$modProject" kill "$projectCurrent"
    fi
}

_killConcern() {
    local concernCurrent surfaceCurrent projectCurrent
    concernCurrent="$(_getConcernCurrent)"
    surfaceCurrent="$(_getSurfaceCurrent)"
    projectCurrent="$(_getProjectCurrent)"
    "$modConcern" kill "$concernCurrent"

    local remainingConcern
    remainingConcern="$("$modSurface" getsConcern "$surfaceCurrent" | head -n1)"
    if [ -n "$remainingConcern" ]; then
        "$modSurface" setConcernCurrent "$surfaceCurrent" "$remainingConcern"
        tmux select-window -t "$remainingConcern" 2>/dev/null
    else
        rm -rf "$surfaceCurrent"
        "$modBlaze" _afterSurfaceRemoved "$projectCurrent"
    fi
}

_killSurface() {
    local surfaceCurrent projectCurrent
    surfaceCurrent="$(_getSurfaceCurrent)"
    projectCurrent="$(_getProjectCurrent)"
    "$modSurface" kill "$surfaceCurrent"
    "$modBlaze" _afterSurfaceRemoved "$projectCurrent"
}

_killProject() {
    "$modProject" kill "$(_getProjectCurrent)"
}

# ---------------------------------------------------------------------------
# Changement de contexte : sélection via tmux display-menu (liste native).
# ---------------------------------------------------------------------------
_changeConcern() {
    local wid="$1"
    "$modSurface" setConcernCurrent "$(_getSurfaceCurrent)" "$wid"
    tmux select-window -t "$wid"
}

_changeSurface() {
    local name="$1"
    local projectCurrent surfacePath concernTogo
    projectCurrent="$(_getProjectCurrent)"
    surfacePath="$projectCurrent/surfaces/$name"
    "$modProject" setSurfaceCurrent "$projectCurrent" "$name"
    concernTogo="$("$modSurface" getConcernCurrent "$surfacePath")"
    tmux select-window -t "$(basename "$concernTogo")"
}

_changeProject() {
    local sid="$1"
    tmux switch-client -t "$sid"
}

# ---------------------------------------------------------------------------
# Cleanup : réconcilie l'état disque avec la réalité tmux. Ne touche jamais
# une session/fenêtre tmux qui n'est pas gérée par blaze (pas de dossier
# correspondant) : on ne supprime que ce que le disque prétend exister alors
# que tmux dit le contraire.
# ---------------------------------------------------------------------------
_cleanup() {
    local projectDir sid surfaceDir nameSurface concernDir wid widCurrent remaining
    for projectDir in "$rootState"/projects/*/; do
        [ -d "$projectDir" ] || continue
        sid="$(basename "$projectDir")"

        if ! tmux has-session -t "$sid" 2>/dev/null; then
            rm -rf "$projectDir"
            continue
        fi

        for surfaceDir in "$projectDir"surfaces/*/; do
            [ -d "$surfaceDir" ] || continue

            for concernDir in "$surfaceDir"concerns/*/; do
                [ -d "$concernDir" ] || continue
                wid="$(basename "$concernDir")"
                tmux list-windows -t "$sid" -F '#{window_id}' 2>/dev/null | grep -qx "$wid" \
                    || rm -rf "$concernDir"
            done

            if [ -d "$surfaceDir" ]; then
                widCurrent="$(grep '^widConcernCurrent=' "$surfaceDir/this.state" 2>/dev/null | cut -d'=' -f2-)"
                if [ -n "$widCurrent" ] && [ ! -d "$surfaceDir/concerns/$widCurrent" ]; then
                    remaining="$(ls "$surfaceDir"concerns 2>/dev/null | head -n1)"
                    [ -n "$remaining" ] && sed -i "s#^widConcernCurrent=.*#widConcernCurrent=$remaining#" "$surfaceDir/this.state"
                fi
            fi

            if [ -z "$(ls -A "$surfaceDir"concerns 2>/dev/null)" ]; then
                nameSurface="$(basename "$surfaceDir")"
                rm -rf "$surfaceDir"
                if grep -q "^nameSurfaceCurrent=$nameSurface\$" "$projectDir/this.state" 2>/dev/null; then
                    remaining="$(ls "$projectDir"surfaces 2>/dev/null | head -n1)"
                    [ -n "$remaining" ] && sed -i "s#^nameSurfaceCurrent=.*#nameSurfaceCurrent=$remaining#" "$projectDir/this.state"
                fi
            fi
        done
    done
}

# ---------------------------------------------------------------------------
# Dispatch
# ---------------------------------------------------------------------------
case "$1" in
_wizardStart|_wizardStep|_wizardAnswer|_wizardFinish|\
_createProject|_createSurface|_createConcern|\
_renameProject|_renameSurface|_renameConcern|\
_killConcern|_killSurface|_killProject|_afterSurfaceRemoved|\
_changeConcern|_changeSurface|_changeProject|_cleanup)
    "$@"
    ;;
createProject) "$modBlaze" _wizardStart Project ;;
createSurface) "$modBlaze" _wizardStart Surface ;;
createConcern) "$modBlaze" _wizardStart Concern ;;

killConcern)
    nameConcern="$("$modConcern" getName "$(_getConcernCurrent)")"
    tmux confirm-before -p "Kill concern '$nameConcern'? (y/n)" \
        "run-shell \"$(_runShell _killConcern)\""
    ;;
killSurface)
    nameSurface="$("$modSurface" getName "$(_getSurfaceCurrent)")"
    tmux confirm-before -p "Kill surface '$nameSurface' and all its concerns? (y/n)" \
        "run-shell \"$(_runShell _killSurface)\""
    ;;
killProject)
    nameProject="$("$modProject" getName "$(_getProjectCurrent)")"
    tmux confirm-before -p "Kill project '$nameProject' and everything in it? (y/n)" \
        "run-shell \"$(_runShell _killProject)\""
    ;;

renameConcern) "$modBlaze" _wizardStart RenameConcern ;;
renameSurface) "$modBlaze" _wizardStart RenameSurface ;;
renameProject) "$modBlaze" _wizardStart RenameProject ;;

changeConcern)
    surfaceCurrent="$(_getSurfaceCurrent)"
    args=(-T "Change concern")
    while read -r wid; do
        [ -z "$wid" ] && continue
        name="$("$modConcern" getName "$surfaceCurrent/concerns/$wid")"
        args+=("$name" "" "run-shell \"$(_runShell _changeConcern "'$wid'")\"")
    done < <("$modSurface" getsConcern "$surfaceCurrent")
    tmux display-menu "${args[@]}"
    ;;
changeSurface)
    projectCurrent="$(_getProjectCurrent)"
    args=(-T "Change surface")
    while read -r nameSurface; do
        [ -z "$nameSurface" ] && continue
        args+=("$nameSurface" "" "run-shell \"$(_runShell _changeSurface "'$nameSurface'")\"")
    done < <("$modProject" getsSurface "$projectCurrent")
    tmux display-menu "${args[@]}"
    ;;
changeProject)
    args=(-T "Change project")
    while read -r sid; do
        [ -z "$sid" ] && continue
        name="$("$modProject" getName "$rootState/projects/$sid")"
        args+=("$name" "" "run-shell \"$(_runShell _changeProject "'$sid'")\"")
    done < <(ls "$rootState/projects" 2>/dev/null)
    tmux display-menu "${args[@]}"
    ;;

cleanup) "$modBlaze" _cleanup ;;

reloadConfig) "$modConfig" ;;
esac
