#!/usr/bin/env bash
project="$2"
case "$1" in
create)
	nameProjectNew="$3"
	nameSurfaceFirst="$4"
	idConcernFirst="$5"
	nameConcernFirst="$6"
	mkdir -p "$project" && {
		printf "nameProject=%s\n" "$nameProjectNew" > "$project/this.state"
		printf "nameSurfaceCurrent=%s\n" "$nameSurfaceFirst" >> "$project/this.state"
		"$modSurface" create "$project/surfaces/$nameSurfaceFirst" "$nameSurfaceFirst" "$idConcernFirst" "$nameConcernFirst"
	}
	;;
kill)
	ls "$project"/surfaces 2>/dev/null | while read -r nameSurface; do
		"$modSurface" kill "$project/surfaces/$nameSurface"
	done
	tmux kill-session -t "$(basename "$project")" 2>/dev/null
	rm -rf "$project"
	;;
getName)
	grep "^nameProject=" "$project"/this.state | cut -d'=' -f2-
	;;
getsSurface)
	ls "$project"/surfaces 2>/dev/null
	;;
getSurfaceCurrent)
	echo "$project"/surfaces/$(grep "^nameSurfaceCurrent=" "$project"/this.state | cut -d'=' -f2-)
	;;
setName)
	nameNewProject="$3"
	sed -i "s#^nameProject=.*#nameProject=$nameNewProject#" "$project/this.state"
	;;
setSurfaceCurrent)
	surfaceTogo="$3"
	nameSurfaceTogo=$(basename "$surfaceTogo")
	[ -d "$project"/surfaces/"$nameSurfaceTogo" ] && sed -i "s#^nameSurfaceCurrent=.*#nameSurfaceCurrent=$nameSurfaceTogo#" "$project/this.state"
	;;
addSurface)
	nameSurfaceNew="$3"
	idConcernFirst="$4"
	nameConcernFirst="$5"
	"$modSurface" create "$project/surfaces/$nameSurfaceNew" "$nameSurfaceNew" "$idConcernFirst" "$nameConcernFirst"
	sed -i "s#^nameSurfaceCurrent=.*#nameSurfaceCurrent=$nameSurfaceNew#" "$project/this.state"
	;;
renameSurface)
	nameSurfaceOld="$3"
	nameSurfaceNewName="$4"
	mv "$project/surfaces/$nameSurfaceOld" "$project/surfaces/$nameSurfaceNewName"
	"$modSurface" setName "$project/surfaces/$nameSurfaceNewName" "$nameSurfaceNewName"
	grep -q "^nameSurfaceCurrent=$nameSurfaceOld\$" "$project/this.state" 2>/dev/null && \
		sed -i "s#^nameSurfaceCurrent=.*#nameSurfaceCurrent=$nameSurfaceNewName#" "$project/this.state"
	;;
esac
