ARCHS = arm64 arm64e

THEOS_BUILD_DIR = build

include theos/makefiles/common.mk

TOOL_NAME = ondeviceconsole
ondeviceconsole_FILES = main.m

include $(THEOS_MAKE_PATH)/tool.mk
