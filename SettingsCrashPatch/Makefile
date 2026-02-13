DEBUG=0
FINALPACKAGE=1
ARCHS = arm64
TARGET := iphone:clang:16.5:13.0
PACKAGE_VERSION = 1.0.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = ZZYTLiteFix
ZZYTLiteFix_FILES = ZZYTLiteFix.x
ZZYTLiteFix_FRAMEWORKS = UIKit Foundation
ZZYTLiteFix_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk
