default:	build

CMDS:=build install clean

$(CMDS):	FORCE
	make -C apps $@

.PHONY:	FORCE
