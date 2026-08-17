#!/usr/bin/env bash
concern="$2"
case "$1" in
create)
	nameConcernNew="$3"
	mkdir -p "$concern" && {
		printf "nameConcern=%s\n" "$nameConcernNew" > "$concern/this.state"
	}
	;;
kill)
	tmux kill-window -t "$(basename "$concern")" 2>/dev/null
	rm -rf "$concern"
	;;
getName)
	grep "^nameConcern=" "$concern"/this.state | cut -d'=' -f2-
	;;
setName)
	nameNewConcern="$3"
	sed -i "s#^nameConcern=.*#nameConcern=$nameNewConcern#" "$concern"/this.state
	;;
esac
