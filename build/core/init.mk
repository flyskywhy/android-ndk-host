# Copyright (C) 2009-2010 The Android Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# Initialization of the NDK build system. This file is included by
# several build scripts.
#

# Disable GNU Make implicit rules

# this turns off the suffix rules built into make
.SUFFIXES:

# this turns off the RCS / SCCS implicit rules of GNU Make
% : RCS/%,v
% : RCS/%
% : %,v
% : s.%
% : SCCS/s.%

# If a rule fails, delete $@.
.DELETE_ON_ERROR:


# Define NDK_LOG in your environment to display log traces when
# using the build scripts. See also the definition of ndk_log below.
#
NDK_LOG := $(strip $(NDK_LOG))

# Check that we have at least GNU Make 3.81
# We do this by detecting whether 'lastword' is supported
#
MAKE_TEST := $(lastword a b c d e f)
ifneq ($(MAKE_TEST),f)
    $(error Android NDK: GNU Make version $(MAKE_VERSION) is too low (should be >= 3.81))
endif
ifdef NDK_LOG
    $(info Android NDK: GNU Make version $(MAKE_VERSION) detected)
endif

# NDK_ROOT *must* be defined and point to the root of the NDK installation
NDK_ROOT := $(strip $(NDK_ROOT))
ifndef NDK_ROOT
    $(error ERROR while including init.mk: NDK_ROOT must be defined !)
endif
ifneq ($(words $(NDK_ROOT)),1)
    $(info,The Android NDK installation path contains spaces: '$(NDK_ROOT)')
    $(error,Please fix the problem by reinstalling to a different location.)
endif

# ====================================================================
#
# Define a few useful variables and functions.
# More stuff will follow in definitions.mk.
#
# ====================================================================

# Used to output warnings and error from the library, it's possible to
# disable any warnings or errors by overriding these definitions
# manually or by setting NDK_NO_WARNINGS or NDK_NO_ERRORS

__ndk_name    := Android NDK
__ndk_info     = $(info $(__ndk_name): $1 $2 $3 $4 $5)
__ndk_warning  = $(warning $(__ndk_name): $1 $2 $3 $4 $5)
__ndk_error    = $(error $(__ndk_name): $1 $2 $3 $4 $5)

ifdef NDK_NO_WARNINGS
__ndk_warning :=
endif
ifdef NDK_NO_ERRORS
__ndk_error :=
endif

# -----------------------------------------------------------------------------
# Function : ndk_log
# Arguments: 1: text to print when NDK_LOG is defined
# Returns  : None
# Usage    : $(call ndk_log,<some text>)
# -----------------------------------------------------------------------------
ifdef NDK_LOG
ndk_log = $(info $(__ndk_name): $1)
else
ndk_log :=
endif

# ====================================================================
#
# Host system auto-detection.
#
# ====================================================================

#
# Determine host system and architecture from the environment
#
HOST_OS := $(strip $(HOST_OS))
ifndef HOST_OS
    # On all modern variants of Windows (including Cygwin and Wine)
    # the OS environment variable is defined to 'Windows_NT'
    #
    # The value of PROCESSOR_ARCHITECTURE will be x86 or AMD64
    #
    ifeq ($(OS),Windows_NT)
        HOST_OS := windows
    else
        # For other systems, use the `uname` output
        UNAME := $(shell uname -s)
        ifneq (,$(findstring Linux,$(UNAME)))
            HOST_OS := linux
        endif
        ifneq (,$(findstring Darwin,$(UNAME)))
            HOST_OS := darwin
        endif
        # We should not be there, but just in case !
        ifneq (,$(findstring CYGWIN,$(UNAME)))
            HOST_OS := windows
        endif
        ifeq ($(HOST_OS),)
            $(call __ndk_info,Unable to determine HOST_OS from uname -s: $(UNAME))
            $(call __ndk_info,Please define HOST_OS in your environment.)
            $(call __ndk_error,Aborting.)
        endif
    endif
    $(call ndk_log,Host OS was auto-detected: $(HOST_OS))
else
    $(call ndk_log,Host OS from environment: $(HOST_OS))
endif

# For all systems, we will have HOST_OS_BASE defined as
# $(HOST_OS), except on Cygwin where we will have:
#
#  HOST_OS      == cygwin
#  HOST_OS_BASE == windows
#
# Trying to detect that we're running from Cygwin is tricky
# because we can't use $(OSTYPE): It's a Bash shell variable
# that is not exported to sub-processes, and isn't defined by
# other shells (for those with really weird setups).
#
# Instead, we assume that a program named /bin/uname.exe
# that can be invoked and returns a valid value corresponds
# to a Cygwin installation.
#
HOST_OS_BASE := $(HOST_OS)

ifeq ($(HOST_OS),windows)
    ifneq (,$(strip $(wildcard /bin/uname.exe)))
        $(call ndk_log,Found /bin/uname.exe on Windows host, checking for Cygwin)
        # NOTE: The 2>NUL here is for the case where we're running inside the
        #       native Windows shell. On cygwin, this will create an empty NUL file
        #       that we're going to remove later (see below).
        UNAME := $(shell /bin/uname.exe -s 2>NUL)
        $(call ndk_log,uname -s returned: $(UNAME))
        ifneq (,$(filter CYGWIN%,$(UNAME)))
            $(call ndk_log,Cygwin detected: $(shell uname -a))
            HOST_OS := cygwin
            DUMMY := $(shell rm -f NUL) # Cleaning up
        else
            ifneq (,$(filter MINGW32%,$(UNAME)))
                $(call ndk_log,MSys detected: $(shell uname -a))
                HOST_OS := cygwin
            else
                $(call ndk_log,Cygwin *not* detected!)
            endif
        endif
    endif
endif

ifneq ($(HOST_OS),$(HOST_OS_BASE))
    $(call ndk_log, Host operating system detected: $(HOST_OS), base OS: $(HOST_OS_BASE))
else
    $(call ndk_log, Host operating system detected: $(HOST_OS))
endif

HOST_ARCH := $(strip $(HOST_ARCH))
ifndef HOST_ARCH
    ifeq ($(HOST_OS_BASE),windows)
        HOST_ARCH := $(PROCESSOR_ARCHITECTURE)
        ifeq ($(HOST_ARCH),AMD64)
            HOST_ARCH := x86
        endif
    else # HOST_OS_BASE != windows
        UNAME := $(shell uname -m)
        ifneq (,$(findstring 86,$(UNAME)))
            HOST_ARCH := x86
        endif
        # We should probably should not care at all
        ifneq (,$(findstring Power,$(UNAME)))
            HOST_ARCH := ppc
        endif
        ifeq ($(HOST_ARCH),)
            $(call __ndk_info,Unsupported host architecture: $(UNAME))
            $(call __ndk_error,Aborting)
        endif
    endif # HOST_OS_BASE != windows
    $(call ndk_log,Host CPU was auto-detected: $(HOST_ARCH))
else
    $(call ndk_log,Host CPU from environment: $(HOST_ARCH))
endif

HOST_TAG := $(HOST_OS_BASE)-$(HOST_ARCH)

# The directory separator used on this host
HOST_DIRSEP := :
ifeq ($(HOST_OS),windows)
  HOST_DIRSEP := ;
endif

# The host executable extension
HOST_EXEEXT :=
ifeq ($(HOST_OS),windows)
  HOST_EXEEXT := .exe
endif

# If we are on Windows, we need to check that we are not running
# Cygwin 1.5, which is deprecated and won't run our toolchain
# binaries properly.
#
ifeq ($(HOST_TAG),windows-x86)
    ifeq ($(HOST_OS),cygwin)
        # On cygwin, 'uname -r' returns something like 1.5.23(0.225/5/3)
        # We recognize 1.5. as the prefix to look for then.
        CYGWIN_VERSION := $(shell uname -r)
        ifneq ($(filter XX1.5.%,XX$(CYGWIN_VERSION)),)
            $(call __ndk_info,You seem to be running Cygwin 1.5, which is not supported.)
            $(call __ndk_info,Please upgrade to Cygwin 1.7 or higher.)
            $(call __ndk_error,Aborting.)
        endif
    endif
    # special-case the host-tag
    HOST_TAG := windows
endif

$(call ndk_log,HOST_TAG set to $(HOST_TAG))

# Check for NDK-specific versions of our host tools
HOST_PREBUILT := $(strip $(wildcard $(NDK_ROOT)/prebuilt/$(HOST_TAG)/bin))
ifdef HOST_PREBUILT
    $(call ndk_log,Host tools prebuilt directory: $(HOST_PREBUILT))
    # The windows prebuilt binaries are for ndk-build.cmd
    # On cygwin, we must use the Cygwin version of these tools instead.
    ifneq ($(HOST_OS),cygwin)
        HOST_AWK := $(wildcard $(HOST_PREBUILT)/awk$(HOST_EXEEXT))
        HOST_SED  := $(wildcard $(HOST_PREBUILT)/sed$(HOST_EXEEXT))
        HOST_MAKE := $(wildcard $(HOST_PREBUILT)/make$(HOST_EXEEXT))
    endif
else
    $(call ndk_log,Host tols prebuilt directory not found, using system tools)
endif

HOST_ECHO := $(strip $(HOST_ECHO))
ifndef HOST_ECHO
    HOST_ECHO := $(strip $(wildcard $(NDK_ROOT)/prebuilt/$(HOST_TAG)/bin/echo$(HOST_EXEEXT)))
endif
ifndef HOST_ECHO
    HOST_ECHO := echo
endif
$(call ndk_log,Host 'echo' tool: $(HOST_ECHO))

#
# Verify that the 'awk' tool has the features we need.
# Both Nawk and Gawk do.
#
HOST_AWK := $(strip $(HOST_AWK))
ifndef HOST_AWK
    HOST_AWK := awk
endif
$(call ndk_log,Host 'awk' tool: $(HOST_AWK))

# Location of all awk scripts we use
BUILD_AWK := $(NDK_ROOT)/build/awk

AWK_TEST := $(shell $(HOST_AWK) -f $(BUILD_AWK)/check-awk.awk)
$(call ndk_log,Host 'awk' test returned: $(AWK_TEST))
ifneq ($(AWK_TEST),Pass)
    $(call __ndk_info,Host 'awk' tool is outdated. Please define HOST_AWK to point to Gawk or Nawk !)
    $(call __ndk_error,Aborting.)
endif

#
# On Cygwin, define the 'cygwin-to-host-path' function here depending on the
# environment. The rules are the following:
#
# 1/ If "cygpath' is not in your path, do not use it at all. It looks like
#    this allows to build with the NDK from MSys without problems.
#
# 2/ Since invoking 'cygpath -m' from GNU Make for each source file is
#    _very_ slow, try to generate a Make function that performs the mapping
#    from cygwin to host paths through simple substitutions.
#
# 3/ In case we fail horribly, allow the user to define NDK_USE_CYGPATH to '1'
#    in order to use 'cygpath -m' nonetheless. This is only a backup plan in
#    case our automatic substitution function doesn't work (only likely if you
#    have a very weird cygwin setup).
#
# The function for 2/ is generated by an awk script. It's really a series
# of nested patsubst calls, that look like:
#
#     cygwin-to-host-path = $(patsubst /cygdrive/c/%,c:/%,\
#                             $(patsusbt /cygdrive/d/%,d:/%, \
#                              $1)
#
# except that the actual definition is built from the list of mounted
# drives as reported by "mount" and deals with drive letter cases (i.e.
# '/cygdrive/c' and '/cygdrive/C')
#
ifeq ($(HOST_OS),cygwin)
    CYGPATH := $(strip $(HOST_CYGPATH))
    ifndef CYGPATH
        $(call ndk_log, Probing for 'cygpath' program)
        CYGPATH := $(strip $(shell which cygpath 2>/dev/null))
        ifndef CYGPATH
            $(call ndk_log, 'cygpath' was *not* found in your path)
        else
            $(call ndk_log, 'cygpath' found as: $(CYGPATH))
        endif
    endif
    ifndef CYGPATH
        cygwin-to-host-path = $1
    else
        ifeq ($(NDK_USE_CYGPATH),1)
            $(call ndk_log, Forced usage of 'cygpath -m' through NDK_USE_CYGPATH=1)
            cygwin-to-host-path = $(strip $(shell $(CYGPATH) -m $1))
        else
            # Call an awk script to generate a Makefile fragment used to define a function
            WINDOWS_HOST_PATH_FRAGMENT := $(shell mount | $(HOST_AWK) -f $(BUILD_AWK)/gen-windows-host-path.awk)
            ifeq ($(NDK_LOG),1)
                $(info Using cygwin substitution rules:)
                $(eval $(shell mount | $(HOST_AWK) -f $(BUILD_AWK)/gen-windows-host-path.awk -vVERBOSE=1))
            endif
            $(eval cygwin-to-host-path = $(WINDOWS_HOST_PATH_FRAGMENT))
        endif
    endif
endif # HOST_OS == cygwin

# The location of the build system files
BUILD_SYSTEM := $(NDK_ROOT)/build/core

# Include common definitions
include $(BUILD_SYSTEM)/definitions.mk

# ====================================================================
#
# Read all toolchain-specific configuration files.
#
# Each toolchain must have a corresponding config.mk file located
# in build/toolchains/<name>/ that will be included here.
#
# Each one of these files should define the following variables:
#   TOOLCHAIN_NAME   toolchain name (e.g. arm-linux-androideabi-4.4.3)
#   TOOLCHAIN_ABIS   list of target ABIs supported by the toolchain.
#
# Then, it should include $(ADD_TOOLCHAIN) which will perform
# book-keeping for the build system.
#
# ====================================================================

# the build script to include in each toolchain config.mk
ADD_TOOLCHAIN := $(BUILD_SYSTEM)/add-toolchain.mk

# the list of all toolchains in this NDK
NDK_ALL_TOOLCHAINS :=
NDK_ALL_ABIS       :=
NDK_ALL_ARCHS      :=

TOOLCHAIN_CONFIGS := $(wildcard $(NDK_ROOT)/toolchains/*/config.mk)
$(foreach _config_mk,$(TOOLCHAIN_CONFIGS),\
  $(eval include $(BUILD_SYSTEM)/add-toolchain.mk)\
)

NDK_ALL_TOOLCHAINS   := $(sort $(NDK_ALL_TOOLCHAINS))
NDK_ALL_ABIS         := $(sort $(NDK_ALL_ABIS))
NDK_ALL_ARCHS        := $(sort $(NDK_ALL_ARCHS))

# Check that each ABI has a single architecture definition
$(foreach _abi,$(strip $(NDK_ALL_ABIS)),\
  $(if $(filter-out 1,$(words $(NDK_ABI.$(_abi).arch))),\
    $(call __ndk_info,INTERNAL ERROR: The $(_abi) ABI should have exactly one architecture definitions. Found: '$(NDK_ABI.$(_abi).arch)')\
    $(call __ndk_error,Aborting...)\
  )\
)

# Allow the user to define NDK_TOOLCHAIN to a custom toolchain name.
# This is normally used when the NDK release comes with several toolchains
# for the same architecture (generally for backwards-compatibility).
#
NDK_TOOLCHAIN := $(strip $(NDK_TOOLCHAIN))
ifdef NDK_TOOLCHAIN
    # check that the toolchain name is supported
    $(if $(filter-out $(NDK_ALL_TOOLCHAINS),$(NDK_TOOLCHAIN)),\
      $(call __ndk_info,NDK_TOOLCHAIN is defined to the unsupported value $(NDK_TOOLCHAIN)) \
      $(call __ndk_info,Please use one of the following values: $(NDK_ALL_TOOLCHAINS))\
      $(call __ndk_error,Aborting)\
    ,)
    $(call ndk_log, Using specific toolchain $(NDK_TOOLCHAIN))
endif

$(call ndk_log, This NDK supports the following target architectures and ABIS:)
$(foreach arch,$(NDK_ALL_ARCHS),\
    $(call ndk_log, $(space)$(space)$(arch): $(NDK_ARCH.$(arch).abis))\
)
$(call ndk_log, This NDK supports the following toolchains and target ABIs:)
$(foreach tc,$(NDK_ALL_TOOLCHAINS),\
    $(call ndk_log, $(space)$(space)$(tc):  $(NDK_TOOLCHAIN.$(tc).abis))\
)

# ====================================================================
#
# Read all platform-specific configuration files.
#
# Each platform must be located in build/platforms/android-<apilevel>
# where <apilevel> corresponds to an API level number, with:
#   3 -> Android 1.5
#   4 -> next platform release
#
# ====================================================================

# The platform files were moved in the Android source tree from
# $TOP/ndk/build/platforms to $TOP/development/ndk/platforms. However,
# the official NDK release packages still place them under the old
# location for now, so deal with this here
#
NDK_PLATFORMS_ROOT := $(strip $(NDK_PLATFORMS_ROOT))
ifndef NDK_PLATFORMS_ROOT
    NDK_PLATFORMS_ROOT := $(strip $(wildcard $(NDK_ROOT)/platforms))
    ifndef NDK_PLATFORMS_ROOT
        NDK_PLATFORMS_ROOT := $(strip $(wildcard $(NDK_ROOT)/build/platforms))
    endif

    ifndef NDK_PLATFORMS_ROOT
        $(call __ndk_info,Could not find platform files (headers and libraries))
        $(if $(strip $(wildcard $(NDK_ROOT)/RELEASE.TXT)),\
            $(call __ndk_info,Please define NDK_PLATFORMS_ROOT to point to a valid directory.)\
        ,\
            $(call __ndk_info,Please run build/tools/build-platforms.sh to build the corresponding directory.)\
        )
        $(call __ndk_error,Aborting)
    endif

    $(call ndk_log,Found platform root directory: $(NDK_PLATFORMS_ROOT))
endif
ifeq ($(strip $(wildcard $(NDK_PLATFORMS_ROOT)/android-*)),)
    $(call __ndk_info,Your NDK_PLATFORMS_ROOT points to an invalid directory)
    $(call __ndk_info,Current value: $(NDK_PLATFORMS_ROOT))
    $(call __ndk_error,Aborting)
endif

NDK_ALL_PLATFORMS := $(strip $(notdir $(wildcard $(NDK_PLATFORMS_ROOT)/android-*)))
$(call ndk_log,Found supported platforms: $(NDK_ALL_PLATFORMS))

$(foreach _platform,$(NDK_ALL_PLATFORMS),\
  $(eval include $(BUILD_SYSTEM)/add-platform.mk)\
)

# we're going to find the maximum platform number of the form android-<number>
# ignore others, which could correspond to special and experimental cases
NDK_ALL_PLATFORM_LEVELS := $(filter android-%,$(NDK_ALL_PLATFORMS))
NDK_ALL_PLATFORM_LEVELS := $(patsubst android-%,%,$(NDK_ALL_PLATFORM_LEVELS))
$(call ndk_log,Found stable platform levels: $(NDK_ALL_PLATFORM_LEVELS))

NDK_MAX_PLATFORM_LEVEL := 3
$(foreach level,$(NDK_ALL_PLATFORM_LEVELS),\
  $(eval NDK_MAX_PLATFORM_LEVEL := $$(call max,$$(NDK_MAX_PLATFORM_LEVEL),$$(level)))\
)
$(call ndk_log,Found max platform level: $(NDK_MAX_PLATFORM_LEVEL))

