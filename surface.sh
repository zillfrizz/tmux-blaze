#!/usr/bin/env bash
surface="$2"
case "$1" in
create)
	nameSurfaceNew="$3"
	idConcernFirst="$4"
	nameConcernFirst="$5"
	mkdir -p "$surface" && {
		printf "nameSurface=%s\n" "$nameSurfaceNew" > "$surface/this.state"
		printf "widConcernCurrent=%s\n" "$idConcernFirst" >> "$surface/this.state"
		"$modConcern" create "$surface"/concerns/"$idConcernFirst" "$nameConcernFirst"
	}
	;;
kill)
	ls "$surface"/concerns 2>/dev/null | while read -r widConcern; do
		"$modConcern" kill "$surface/concerns/$widConcern"
	done
	rm -rf "$surface"
	;;
getName)
	grep "^nameSurface=" "$surface"/this.state | cut -d'=' -f2-
	;;
getsConcern)
	ls "$surface"/concerns 2>/dev/null
	;;
getConcernCurrent)
	echo "$surface"/concerns/$(grep "^widConcernCurrent=" "$surface/this.state" | cut -d'=' -f2-)
	;;
setName)
	nameNewSurface="$3"
	sed -i "s#^nameSurface=.*#nameSurface=$nameNewSurface#" "$surface/this.state"
	;;
setConcernCurrent)
	concernTogo="$3"
	widConcernTogo=$(basename "$concernTogo")
	[ -d "$surface"/concerns/"$widConcernTogo" ] && sed -i "s#^widConcernCurrent=.*#widConcernCurrent=$widConcernTogo#" "$surface/this.state"
	;;
addConcern)
	widConcernNew="$3"
	nameConcernNew="$4"
	"$modConcern" create "$surface"/concerns/"$widConcernNew" "$nameConcernNew"
	sed -i "s#^widConcernCurrent=.*#widConcernCurrent=$widConcernNew#" "$surface/this.state"
	;;
esac
