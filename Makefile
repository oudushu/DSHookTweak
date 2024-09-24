ARCHS = arm64
TARGET := iphone:clang:latest:13.0
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = DSHookTweak

FLEX_ROOT = libs/FLEX

# Function to convert /foo/bar to -I/foo/bar
dtoim = $(foreach d,$(1),-I$(d))

# Gather FLEX sources
SOURCES  = $(shell find $(FLEX_ROOT)/Classes -name '*.c')
SOURCES += $(shell find $(FLEX_ROOT)/Classes -name '*.m')
SOURCES += $(shell find $(FLEX_ROOT)/Classes -name '*.mm')
# Gather FLEX headers for search paths
_IMPORTS  = $(shell /bin/ls -d $(FLEX_ROOT)/Classes/*/)
_IMPORTS += $(shell /bin/ls -d $(FLEX_ROOT)/Classes/*/*/)
_IMPORTS += $(shell /bin/ls -d $(FLEX_ROOT)/Classes/*/*/*/)
_IMPORTS += $(shell /bin/ls -d $(FLEX_ROOT)/Classes/*/*/*/*/)
IMPORTS = -I$(FLEX_ROOT)/Classes/ $(call dtoim, $(_IMPORTS))

LookinServer_ROOT = libs/LookinServer

SOURCES += $(shell find $(LookinServer_ROOT) -name '*.m')

_LookinServer_IMPORTS += $(shell /bin/ls -d $(LookinServer_ROOT)/*/)
_LookinServer_IMPORTS += $(shell /bin/ls -d $(LookinServer_ROOT)/*/*/)
_LookinServer_IMPORTS += $(shell /bin/ls -d $(LookinServer_ROOT)/*/*/*/)
_LookinServer_IMPORTS += $(shell /bin/ls -d $(LookinServer_ROOT)/*/*/*/*/)
LookinServer_IMPORTS = -I$(LookinServer_ROOT)/ $(call dtoim, $(_LookinServer_IMPORTS))

CocoaLumberjack_ROOT = libs/CocoaLumberjack

SOURCES += $(shell find $(CocoaLumberjack_ROOT) -name '*.m')

_CocoaLumberjack_IMPORTS += $(shell /bin/ls -d $(CocoaLumberjack_ROOT)/)
CocoaLumberjack_IMPORTS = -I$(CocoaLumberjack_ROOT)/ $(call dtoim, $(_CocoaLumberjack_IMPORTS))

TWEAK_NAME = DSHookTweak
$(TWEAK_NAME)_FILES = Tweak.x $(SOURCES)
$(TWEAK_NAME)_FRAMEWORKS = CoreGraphics UIKit ImageIO QuartzCore AVFoundation Foundation
$(TWEAK_NAME)_LIBRARIES = sqlite3 z
$(TWEAK_NAME)_CFLAGS += -fobjc-arc -Wno-deprecated-declarations -Wno-unused-variable -Wno-unused-but-set-variable -w -Wno-unsupported-availability-guard $(IMPORTS) -g $(LookinServer_IMPORTS) -g
$(TWEAK_NAME)_CFLAGS += $(IMPORTS) -g 
$(TWEAK_NAME)_CFLAGS += $(LookinServer_IMPORTS) -g
$(TWEAK_NAME)_CFLAGS += $(CocoaLumberjack_IMPORTS) -g
$(TWEAK_NAME)_CCFLAGS += -std=gnu++11

# For LookinServer
$(TWEAK_NAME)_CFLAGS += -DSHOULD_COMPILE_LOOKIN_SERVER=1

include $(THEOS_MAKE_PATH)/tweak.mk

# SUBPROJECTS += libflex
# include $(THEOS_MAKE_PATH)/aggregate.mk

before-stage::
	find . -name ".DS_Store" -delete

# For printing variables from the makefile
print-%  : ; @echo $* = $($*)