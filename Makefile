# -*- makefile -*-

export THEOS=./theos_fork

SDKBINPATH := ${shell echo "/home/`whoami`/.nix-profile/bin"}
SDKTARGET := armv7-apple-darwin11

ME := ${shell echo "`whoami`"}

override _SDK_DIR := /home/${ME}/.nix-profile
override _THEOS_PLATFORM_LIPO := armv7-apple-darwin11-lipo
override THEOS_CURRENT_ARCH := armv7
override FINALPACKAGE := 1

include $(THEOS)/makefiles/common.mk

TOOL_NAME := ondeviceconsole
ondeviceconsole_FILES := main.mm

CFLAGS += -stdlib=libstdc++ -std=c++11 \
-isysroot /home/${ME}/.nix-profile/iPhoneOS9.2.sdk \
-I /home/${ME}/.nix-profile/iPhoneOS9.2.sdk/usr/include/c++/4.2.1 \
-I .

include $(THEOS_MAKE_PATH)/tool.mk
