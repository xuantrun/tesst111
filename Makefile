ARCHS = arm64
TARGET := iphone:clang:latest:14.0
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = BypassLogin

BypassLogin_FILES = BypassLogin.m
BypassLogin_CFLAGS = -fobjc-arc
BypassLogin_LIBRARIES = objc
BypassLogin_FRAMEWORKS = UIKit Foundation Security

include $(THEOS_MAKE_PATH)/tweak.mk
