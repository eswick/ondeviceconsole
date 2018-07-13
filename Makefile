THEOS_BUILD_DIR = build
DEBUG = 0

include theos/makefiles/common.mk

TOOL_NAME = ondeviceconsole
ondeviceconsole_FILES = main.m

include $(THEOS_MAKE_PATH)/tool.mk


all::

sync: stage
	./jtool --sign --ent ./Entitlements.plist .theos/obj/arm64/ondeviceconsole
	mv out.bin .theos/obj/arm64/ondeviceconsole
	./jtool --sign --ent ./Entitlements.plist .theos/obj/armv7/ondeviceconsole
	mv out.bin .theos/obj/armv7/ondeviceconsole
	lipo -create .theos/obj/arm64/ondeviceconsole .theos/obj/armv7/ondeviceconsole -output .theos/ondeviceconsole
	rsync -e "ssh -p 2222" -avz .theos/ondeviceconsole root@127.0.0.1:/usr/bin/ondeviceconsole
