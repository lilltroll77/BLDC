# The TARGET variable determines what target system the application is
# compiled for. It either refers to an XN file in the source directories
# or a valid argument for the --target option when compiling
TARGET = XCORE-200-EXPLORER

# The APP_NAME variable determines the name of the final .xe file. It should
# not include the .xe postfix. If left blank the name will default to
# the project name
APP_NAME = BLDC

# The USED_MODULES variable lists other module used by the application.
USED_MODULES = lib_usb

# The flags passed to xcc when building the application
# You can also set the following to override flags for a particular language:
# XCC_XC_FLAGS, XCC_C_FLAGS, XCC_ASM_FLAGS, XCC_CPP_FLAGS
# If the variable XCC_MAP_FLAGS is set it overrides the flags passed to
# xcc for the final link (mapping) stage.
XCC_FLAGS = -Wall -O3 -report -DXUD_SERIES_SUPPORT=XUD_X200_SERIES -g -DUSB_TILE=tile[1]
#XCC_FLAGS = -Wall -O3 -g
# The XCORE_ARM_PROJECT variable, if set to 1, configures this
# project to create both xCORE and ARM binaries.
XCORE_ARM_PROJECT = 0

# The VERBOSE variable, if set to 1, enables verbose output from the make system.
VERBOSE = 1

XMOS_MAKE_PATH ?= ../..
-include $(XMOS_MAKE_PATH)/xcommon/module_xcommon/build/Makefile.common

EXCLUDE_FILES = supervisor.xc
