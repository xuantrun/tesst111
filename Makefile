ARCHS = arm64
TARGET := iphone:clang:latest:14.0
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = BypassLogin

BypassLogin_FILES = BypassLogin.xm
BypassLogin_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk
